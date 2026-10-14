create_clock -period 20.000 -name sys_ref [get_ports {clk}]
derive_clocks
# Independent PLL domains. All crossings use Gray-pointer FIFOs, two-stage
# synchronizers, or a stable payload qualified by a synchronized completion toggle.
# Keep the 31.25 MHz SDRAM clock and its 180-degree shift in the same group so
# the physical SDRAM interface still receives both setup and hold checks.
set_clock_groups -asynchronous -group [get_clocks {clocks/pll_inst.clkc*}] -group [get_clocks {media_clocks/pll_inst.clkc*}]
set_false_path -from [get_ports {key_n[*] sw_n[*] uart_rx}]
