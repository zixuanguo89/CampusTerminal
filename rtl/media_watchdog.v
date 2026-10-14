module media_watchdog #(parameter CLOCK_HZ=25000000)(input clk,rst,ready,failed,
output wire reset_media,output reg [15:0] retries);
reg [28:0] elapsed;reg [4:0] reset_count;
assign reset_media=reset_count!=0;
always @(posedge clk)begin
 if(rst)begin elapsed<=0;reset_count<=0;retries<=0;end
 else if(reset_count!=0)begin reset_count<=reset_count-1'b1;elapsed<=0;end
 else if(ready && !failed)elapsed<=0;
 else if(elapsed==(failed?CLOCK_HZ*4:CLOCK_HZ*10)-1)begin
 reset_count<=16;elapsed<=0;if(retries!=65535)retries<=retries+1'b1;
 end else elapsed<=elapsed+1'b1;
end
endmodule
