


`define   DATA_WIDTH                        32
`define   ADDR_WIDTH                        21
`define   DM_WIDTH                          4

`define   ROW_WIDTH                        11
`define   BA_WIDTH                        2

// Public controller configuration: 31.25 MHz (32 ns), refresh every 976
// clocks, less than 64 ms / 2048 rows. Sized constants also support ModelSim 10.1.
`define	  SDR_CLK_PERIOD				32'd32
`define   SELF_REFRESH_INTERVAL			32'd976

