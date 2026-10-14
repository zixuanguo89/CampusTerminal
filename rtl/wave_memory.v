module wave_memory(input clk,write,input [9:0] wa,input [7:0] data,input [9:0] ra,output [7:0] q);
`ifdef SIMULATION
reg [7:0] memory[0:1023];reg [7:0] result;
always @(posedge clk)begin if(write)memory[wa]<=data;result<=memory[ra];end
assign q=result;
`else
EG_LOGIC_BRAM #(.DATA_WIDTH_A(8),.ADDR_WIDTH_A(10),.DATA_DEPTH_A(1024),
.DATA_WIDTH_B(8),.ADDR_WIDTH_B(10),.DATA_DEPTH_B(1024),.MODE("DP"),
.REGMODE_A("NOREG"),.REGMODE_B("NOREG"),.IMPLEMENT("9K"),.DEBUGGABLE("NO"),.PACKABLE("NO"),.INIT_FILE("")) memory(
.dia(data),.dib(8'd0),.addra(wa),.addrb(ra),.cea(1'b1),.ceb(1'b1),.ocea(1'b1),.oceb(1'b1),
.clka(clk),.clkb(clk),.wea(write),.web(1'b0),.bea(1'b0),.beb(1'b0),.rsta(1'b0),.rstb(1'b0),.doa(),.dob(q));
`endif
endmodule
