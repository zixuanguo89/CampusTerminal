// Iterate a fitted destination rectangle. Rational accumulators implement
// floor(dst*src/dst_size) exactly; no per-pixel divide or CPU preprocessing.
module scale_iterator(input clk,rst,start,input [10:0] source_width,source_height,
 input [9:0] dest_width,dest_height,input advance,
 output reg valid,done,output reg [10:0] source_x,source_y,
 output reg [9:0] dest_x,dest_y,output wire [20:0] source_address);
reg [21:0] x_remainder,y_remainder;
reg [1:0] state;
assign source_address=source_y*source_width+source_x;
always @(posedge clk)begin
 if(rst)begin valid<=0;done<=0;source_x<=0;source_y<=0;dest_x<=0;dest_y<=0;x_remainder<=0;y_remainder<=0;state<=0;end
 else begin
 done<=0;
 if(start)begin
 source_x<=0;source_y<=0;dest_x<=0;dest_y<=0;x_remainder<=0;y_remainder<=0;
 state<=0;
 valid<=source_width!=0 && source_height!=0 && dest_width!=0 && dest_height!=0;
 end else if(valid && advance)begin
 valid<=0;
 if(dest_x==dest_width-1)begin
 dest_x<=0;source_x<=0;x_remainder<=0;
 if(dest_y==dest_height-1)begin valid<=0;done<=1;end
 else begin dest_y<=dest_y+1'b1;y_remainder<=y_remainder+source_height;state<=2;end
 end else begin dest_x<=dest_x+1'b1;x_remainder<=x_remainder+source_width;state<=1;end
 end else if(state==1)begin
 if(x_remainder>=dest_width)begin x_remainder<=x_remainder-dest_width;source_x<=source_x+1'b1;end
 else begin valid<=1;state<=0;end
 end else if(state==2)begin
 if(y_remainder>=dest_height)begin y_remainder<=y_remainder-dest_height;source_y<=source_y+1'b1;end
 else begin valid<=1;state<=0;end
 end
 end
end
endmodule
