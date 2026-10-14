// Pack arbitrary RGB565 rows into masked, aligned four-word SDRAM bursts.
// Coordinates may start/end within an eight-pixel group (letterbox boundaries).
module pixel_writer(input clk,rst,start,input [20:0] base,input [10:0] stride_words,right_edge,
input valid,input [10:0] x,y,input [15:0] pixel,output wire ready,
output wire write,output wire [56:0] packet,input full,output wire idle);
reg [31:0] words[0:3];reg [3:0] masks[0:3];reg flushing;reg [1:0] index;reg [20:0] group_addr;
integer i;
assign ready=!flushing;assign write=flushing&&!full;assign idle=!flushing;
assign packet={masks[index],group_addr+index,words[index]};
always @(posedge clk)begin
 if(rst || start)begin flushing<=0;index<=0;group_addr<=0;
 for(i=0;i<4;i=i+1)begin words[i]<=0;masks[i]<=15;end end
 else begin
 if(valid && ready)begin
 group_addr<=base+y*stride_words+((x>>3)<<2);
 if(!x[0])begin words[x[2:1]][15:0]<=pixel;masks[x[2:1]][1:0]<=0;end
 else begin words[x[2:1]][31:16]<=pixel;masks[x[2:1]][3:2]<=0;end
 if(x[2:0]==7 || x==right_edge-1)begin flushing<=1;index<=0;end
 end
 if(write)begin
 if(index==3)begin flushing<=0;index<=0;for(i=0;i<4;i=i+1)begin words[i]<=0;masks[i]<=15;end end
 else index<=index+1'b1;
 end
 end
end
endmodule
