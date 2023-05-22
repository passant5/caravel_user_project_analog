// SPDX-FileCopyrightText: 2020 Efabless Corporation
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// SPDX-License-Identifier: Apache-2.0

`default_nettype none

/*
 *-------------------------------------------------------------
 *
 * user_analog_project_wrapper
 *
 * This wrapper enumerates all of the pins available to the
 * user for the user analog project.
 *
 *-------------------------------------------------------------
 */

module user_analog_project_wrapper (
`ifdef USE_POWER_PINS
    inout vdda1,	// User area 1 3.3V supply
    inout vdda2,	// User area 2 3.3V supply
    inout vssa1,	// User area 1 analog ground
    inout vssa2,	// User area 2 analog ground
    inout vccd1,	// User area 1 1.8V supply
    inout vccd2,	// User area 2 1.8v supply
    inout vssd1,	// User area 1 digital ground
    inout vssd2,	// User area 2 digital ground
`endif

    // Wishbone Slave ports (WB MI A)
    input wb_clk_i,
    input wb_rst_i,
    input wbs_stb_i,
    input wbs_cyc_i,
    input wbs_we_i,
    input [3:0] wbs_sel_i,
    input [31:0] wbs_dat_i,
    input [31:0] wbs_adr_i,
    output wbs_ack_o,
    output [31:0] wbs_dat_o,

    // Logic Analyzer Signals
    input  [127:0] la_data_in,
    output [127:0] la_data_out,
    input  [127:0] la_oenb,

    /* GPIOs.  There are 27 GPIOs, on either side of the analog.
     * These have the following mapping to the GPIO padframe pins
     * and memory-mapped registers, since the numbering remains the
     * same as caravel but skips over the analog I/O:
     *
     * io_in/out/oeb/in_3v3 [26:14]  <--->  mprj_io[37:25]
     * io_in/out/oeb/in_3v3 [13:0]   <--->  mprj_io[13:0]	
     *
     * When the GPIOs are configured by the Management SoC for
     * user use, they have three basic bidirectional controls:
     * in, out, and oeb (output enable, sense inverted).  For
     * analog projects, a 3.3V copy of the signal input is
     * available.  out and oeb must be 1.8V signals.
     */

    input  [`MPRJ_IO_PADS-`ANALOG_PADS-1:0] io_in,
    input  [`MPRJ_IO_PADS-`ANALOG_PADS-1:0] io_in_3v3,
    output [`MPRJ_IO_PADS-`ANALOG_PADS-1:0] io_out,
    output [`MPRJ_IO_PADS-`ANALOG_PADS-1:0] io_oeb,

    /* Analog (direct connection to GPIO pad---not for high voltage or
     * high frequency use).  The management SoC must turn off both
     * input and output buffers on these GPIOs to allow analog access.
     * These signals may drive a voltage up to the value of VDDIO
     * (3.3V typical, 5.5V maximum).
     * 
     * Note that analog I/O is not available on the 7 lowest-numbered
     * GPIO pads, and so the analog_io indexing is offset from the
     * GPIO indexing by 7, as follows:
     *
     * gpio_analog/noesd [17:7]  <--->  mprj_io[35:25]
     * gpio_analog/noesd [6:0]   <--->  mprj_io[13:7]	
     *
     */
    
    inout [`MPRJ_IO_PADS-`ANALOG_PADS-10:0] gpio_analog,
    inout [`MPRJ_IO_PADS-`ANALOG_PADS-10:0] gpio_noesd,

    /* Analog signals, direct through to pad.  These have no ESD at all,
     * so ESD protection is the responsibility of the designer.
     *
     * user_analog[10:0]  <--->  mprj_io[24:14]
     *
     */
    inout [`ANALOG_PADS-1:0] io_analog,

    /* Additional power supply ESD clamps, one per analog pad.  The
     * high side should be connected to a 3.3-5.5V power supply.
     * The low side should be connected to ground.
     *
     * clamp_high[2:0]   <--->  mprj_io[20:18]
     * clamp_low[2:0]    <--->  mprj_io[20:18]
     *
     */
    inout [2:0] io_clamp_high,
    inout [2:0] io_clamp_low,

    // Independent clock (on independent integer divider)
    input   user_clock2,

    // User maskable interrupt signals
    output [2:0] user_irq
);

/*--------------------------------------*/
/* User project is instantiated  here   */
/*--------------------------------------*/
    wire [228:0] o_const, const_zero;
    wire [353:0] buf_i, buf_i_q;
    wire clk, user_clk2, rst;

    assign {clk,user_clk2} = {wb_clk_i,user_clock2};
    assign {rst, buf_i} = {wb_rst_i, wbs_cyc_i, wbs_stb_i, wbs_we_i, wbs_sel_i, io_in, la_data_in, la_oenb, wbs_adr_i, wbs_dat_i};

    // input transition
(* keep *)    sky130_fd_sc_hd__dfrtp_1 i_FF[353:0] (
        `ifdef USE_POWER_PINS
			.VGND(vssd1),
			.VNB(vssd1),
			.VPB(vccd1),
			.VPWR(vccd1),
		`endif
        .CLK(clk),
        .D(buf_i),
        .Q(buf_i_q),
        .RESET_B(rst)
    );

    wire user_clk2_test, user_clk2_test_q;
    assign user_clk2_test = wbs_we_i;
(* keep *)    sky130_fd_sc_hd__dfrtp_1 user_clk2_FF (
        `ifdef USE_POWER_PINS
			.VGND(vssd1),
			.VNB(vssd1),
			.VPB(vccd1),
			.VPWR(vccd1),
		`endif
        .CLK(user_clk2),
        .D(user_clk2_test),
        .Q(user_clk2_test_q),
        .RESET_B(rst)
    );

    // output transition
    assign const_zero=229'b0;

(* keep *)    sky130_fd_sc_hd__dfrtp_1 o_FF[228:0] (
        `ifdef USE_POWER_PINS
			.VGND(vssd1),
			.VNB(vssd1),
			.VPB(vccd1),
			.VPWR(vccd1),
		`endif
        .CLK(clk),
        .D(const_zero),
        .Q(o_const),
        .RESET_B(rst)
    );

    assign {wbs_ack_o, io_oeb, io_out, user_irq, la_data_out, wbs_dat_o} = o_const;

    // wire isupply;	// Independent 3.3V supply
    // wire io16, io15, io12, io11;

    // assign io_out[12:11] = {io12, io11};
    // assign io_oeb[12:11] = {vssd1, vssd1};

    // assign io_out[16:15] = {io16, io15};
    // assign io_oeb[16:15] = {vssd1, vssd1};

    // // Instantiate the POR.  Connect the digital power to user area 1
    // // VCCD, and connect the analog power to user area 1 VDDA.

    // // Monitor the 3.3V output with mprj_io[10] = gpio_analog[3]
    // // Monitor the 1.8V outputs with mprj_io[11,12] = io_out[11,12]

    // example_por por1 (
	// `ifdef USE_POWER_PINS
	//     .vdd3v3(vdda1),
	//     .vdd1v8(vccd1),
	//     .vss(vssa1),
	// `endif
	// .porb_h(gpio_analog[3]),	// 3.3V domain output
	// .porb_l(io11),			// 1.8V domain output
	// .por_l(io12)			// 1.8V domain output
    // );

    // // Instantiate 2nd POR with the analog power supply on one of the
    // // analog pins.  NOTE:  io_analog[4] = mproj_io[18] and is the same
    // // pad with io_clamp_high/low[0].

    // `ifdef USE_POWER_PINS
    //     assign isupply = io_analog[4];
    // 	assign io_clamp_high[0] = isupply;
    // 	assign io_clamp_low[0] = vssa1;

	// // Tie off remaining clamps
    // 	assign io_clamp_high[2:1] = vssa1;
    // 	assign io_clamp_low[2:1] = vssa1;
    // `endif

    // // Monitor the 3.3V output with mprj_io[25] = gpio_analog[7]
    // // Monitor the 1.8V outputs with mprj_io[26,27] = io_out[15,16]

    // example_por por2 (
	// `ifdef USE_POWER_PINS
	//     .vdd3v3(isupply),
	//     .vdd1v8(vccd1),
	//     .vss(vssa1),
	// `endif
	// .porb_h(gpio_analog[7]),	// 3.3V domain output
	// .porb_l(io15),			// 1.8V domain output
	// .por_l(io16)			// 1.8V domain output
    // );

endmodule	// user_analog_project_wrapper

`default_nettype wire
