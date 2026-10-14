`include "rtl/resource_paths.vh"
module resource_rom #(parameter WIDTH=2,ADDR=17,DEPTH=72960,
parameter HEX="assets/font24.hex",MIF=`FONT_MIF)
(input clk,input [ADDR-1:0] address,output [WIDTH-1:0] q);
`ifdef SIMULATION
reg [WIDTH-1:0] memory[0:DEPTH-1];reg [WIDTH-1:0] result;
initial $readmemh(HEX,memory);
always @(posedge clk)result<=memory[address];
assign q=result;
`else
EG_LOGIC_BRAM #(.DATA_WIDTH_A(WIDTH),.ADDR_WIDTH_A(ADDR),.DATA_DEPTH_A(DEPTH),
.DATA_WIDTH_B(WIDTH),.ADDR_WIDTH_B(ADDR),.DATA_DEPTH_B(DEPTH),.MODE("SP"),
.REGMODE_A("NOREG"),.IMPLEMENT("32K"),.DEBUGGABLE("NO"),.PACKABLE("NO"),
.INIT_FILE(MIF),.FILL_ALL("NONE")) memory(
.dia({WIDTH{1'b0}}),.dib({WIDTH{1'b0}}),.addra(address),.addrb({ADDR{1'b0}}),
.cea(1'b1),.ceb(1'b0),.ocea(1'b1),.oceb(1'b0),.clka(clk),.clkb(1'b0),
.wea(1'b0),.web(1'b0),.bea(1'b0),.beb(1'b0),.rsta(1'b0),.rstb(1'b0),.doa(q),.dob());
`endif
endmodule
