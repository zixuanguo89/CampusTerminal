module pcm_fifo(input clk,rst,input write,input [31:0] data,input read,
output [31:0] q,output empty,full,output [12:0] level);
`ifdef SIMULATION
reg [31:0] memory[0:4095];reg [11:0] wp,rp;reg [12:0] count;
assign empty=count==0;assign full=count==4096;assign level=count;assign q=memory[rp];
always @(posedge clk)begin
 if(rst)begin wp<=0;rp<=0;count<=0;end
 else begin
 if(write && !full)begin memory[wp]<=data;wp<=wp+1'b1;end
 if(read && !empty)rp<=rp+1'b1;
 case({write&&!full,read&&!empty})2'b10:count<=count+1'b1;2'b01:count<=count-1'b1;endcase
 end
end
`else
EG_LOGIC_RAMFIFO #(.DATA_WIDTH(32),.ADDR_WIDTH(12),.SHOWAHEAD(1),.IMPLEMENT("9K")) fifo(
.rst(rst),.di(data),.clk(clk),.re(read),.we(write),.do(q),.empty_flag(empty),.full_flag(full),.rdusedw(level),.wrusedw());
`endif
endmodule
