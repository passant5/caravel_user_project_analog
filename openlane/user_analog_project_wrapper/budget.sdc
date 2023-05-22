### User project wrapper budgetting constraints
### Rev 1
### Date: 6/2/2023
### budget the user project wrapper timing paths to a factor of the clock period
set usr_pct 0.4

## Clock constraints
# Clock network
if {[info exists ::env(CLOCK_PORT)] && $::env(CLOCK_PORT) != ""} {
    set clk_input $::env(CLOCK_PORT)
    create_clock [get_ports $clk_input]  -name clk  -period $::env(CLOCK_PERIOD) 
    puts "\[INFO\]: Creating clock {clk} for port $clk_input with period: $::env(CLOCK_PERIOD)"
} else {
    set clk_input __VIRTUAL_CLK__
    create_clock -name clk -period $::env(CLOCK_PERIOD)
    puts "\[INFO\]: Creating virtual clock with period: $::env(CLOCK_PERIOD)"
}
if { ![info exists ::env(SYNTH_CLK_DRIVING_CELL)] } {
    set ::env(SYNTH_CLK_DRIVING_CELL) $::env(SYNTH_DRIVING_CELL)
}
if { ![info exists ::env(SYNTH_CLK_DRIVING_CELL_PIN)] } {
    set ::env(SYNTH_CLK_DRIVING_CELL_PIN) $::env(SYNTH_DRIVING_CELL_PIN)
}
set_propagated_clock [get_clocks {clk}]

# Clock non-idealities
set_clock_uncertainty $::env(SYNTH_CLOCK_UNCERTAINTY) [get_clocks {clk}]
puts "\[INFO\]: Setting clock uncertainity to: $::env(SYNTH_CLOCK_UNCERTAINTY)"


# Clock transition
set_clock_transition $::env(SYNTH_CLOCK_TRANSITION) [get_clocks {clk}]
puts "\[INFO\]: Setting clock transition to: $::env(SYNTH_CLOCK_TRANSITION)"

## Data paths Constraints
# Maximum transition time of the design nets 
set_max_transition $::env(SYNTH_MAX_TRAN) [current_design]

# Maximum fanout 
set_max_fanout $::env(SYNTH_MAX_FANOUT) [current_design]
puts "\[INFO\]: Setting maximum fanout to: $::env(SYNTH_MAX_FANOUT)"

# Timing paths delays derate
set_timing_derate -early [expr {1-$::env(SYNTH_TIMING_DERATE)}]
set_timing_derate -late [expr {1+$::env(SYNTH_TIMING_DERATE)}]
puts "\[INFO\]: Setting timing derate to: [expr {$::env(SYNTH_TIMING_DERATE) * 100}] %"

# Input/Output delay budget
set_input_delay [expr 2 - $::env(CLOCK_PERIOD) * $usr_pct] -clock [get_clocks {clk}] [all_inputs]
set_input_delay 0 -clock [get_clocks {clk}] {wb_clk_i}
set_input_delay 0 -clock [get_clocks {clk}] {user_clock2}
set_input_delay 0 -clock [get_clocks {clk}] {wb_rst_i}
set_output_delay [expr 2 - $::env(CLOCK_PERIOD) * $usr_pct] -clock [get_clocks {clk}] [all_outputs]

set_load 0.03 [all_outputs]