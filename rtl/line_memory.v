module line_memory(input write_clk,write,input [9:0] write_address,input [31:0] data,
input read_clk,input [9:0] read_address,output [31:0] q);
`ifdef SIMULATION
reg [31:0] memory[0:1023];reg [31:0] result;
always @(posedge write_clk)if(write)memory[write_address]<=data;
always @(posedge read_clk)result<=memory[read_address];
assign q=result;
`else
EG_LOGIC_BRAM #(.DATA_WIDTH_A(32),.ADDR_WIDTH_A(10),.DATA_DEPTH_A(1024),
.DATA_WIDTH_B(32),.ADDR_WIDTH_B(10),.DATA_DEPTH_B(1024),.MODE("DP"),
.REGMODE_A("NOREG"),.REGMODE_B("NOREG"),.IMPLEMENT("9K"),.DEBUGGABLE("NO"),.PACKABLE("NO"),.INIT_FILE("")) memory(
.dia(data),.dib(32'd0),.addra(write_address),.addrb(read_address),.cea(1'b1),.ceb(1'b1),.ocea(1'b1),.oceb(1'b1),
.clka(write_clk),.clkb(read_clk),.wea(write),.web(1'b0),.bea(1'b0),.beb(1'b0),.rsta(1'b0),.rstb(1'b0),.doa(),.dob(q));
`endif
endmodule
