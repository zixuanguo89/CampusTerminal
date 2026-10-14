// One shared serial double-dabble converter replaces ten pixel-rate dividers.
module parameter_digits(input clk,rst,frame_tick,input [7:0] brightness,contrast,interval_s,volume,
input [1:0] effect,duration,album,input [6:0] image_index,input [7:0] status,input [31:0] underruns,
output reg [159:0] digits,input time_mode,input [47:0] time_values);
reg [3:0] row,count;reg active;reg [11:0] binary;reg [15:0] bcd,adjusted;
reg [11:0] values[0:9];integer i;
always @*begin adjusted=bcd;for(i=0;i<4;i=i+1)if(bcd[i*4 +:4]>=5)adjusted[i*4 +:4]=bcd[i*4 +:4]+4'd3;end
always @(posedge clk)begin
 if(rst)begin digits<=0;active<=0;row<=0;count<=0;binary<=0;bcd<=0;
 for(i=0;i<10;i=i+1)values[i]<=0;end
 else if(frame_tick && !active)begin
 values[0]<=time_mode?12'd2000+time_values[7:0]:{4'd0,brightness};
 values[1]<=time_mode?time_values[15:8]:contrast;values[2]<=time_mode?time_values[23:16]:interval_s;
 values[3]<=time_mode?time_values[31:24]:volume;
 values[4]<=time_mode?time_values[39:32]:{6'd0,effect};values[5]<=time_mode?{4'd0,time_values[47:40]}:duration==0?12'd500:duration==1?12'd1000:12'd2000;
 values[6]<=time_mode?12'd3:{10'd0,album};values[7]<=time_mode?12'd4:{5'd0,image_index}+12'd1;values[8]<=time_mode?12'd0:{4'd0,status};values[9]<=time_mode?12'd0:underruns>999?12'd999:underruns[11:0];
 active<=1;row<=0;count<=0;binary<=time_mode?12'd2000+time_values[7:0]:{4'd0,brightness};bcd<=0;
 end else if(active)begin
 if(count==12)begin
 digits[row*16 +:16]<=bcd;
 if(row==9)active<=0;
 else begin row<=row+1'b1;binary<=values[row+1'b1];count<=0;bcd<=0;end
 end else begin bcd<={adjusted[14:0],binary[11]};binary<={binary[10:0],1'b0};count<=count+1'b1;end
 end
end
endmodule
