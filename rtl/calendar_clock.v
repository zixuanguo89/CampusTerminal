// UART frame: A5 5A 01 YY MM DD hh mm ss XOR(01..ss). YY=0..99 means 2000..2099.
module calendar_clock #(parameter CLOCK_HZ=25000000)
(input clk,rst,input byte_valid,input [7:0] byte_data,
output reg calibrated,output reg accepted,rejected,
output reg [6:0] year,output reg [3:0] month,output reg [5:0] day,
output reg [4:0] hour,output reg [5:0] minute,second,output wire [2:0] weekday);
reg [24:0] divider;reg [3:0] index;reg [7:0] checksum;
reg [7:0] packet[0:6];reg [21:0] timeout;
function [5:0] days_in_month;
input [6:0] yy;input [3:0] mm;
begin case(mm)
 2:days_in_month=(yy[1:0]==0)?29:28;
 4,6,9,11:days_in_month=30;
 default:days_in_month=31;
endcase end endfunction
// Sakamoto calendar formula; Sunday=0. Every century in this design is 2000.
function [4:0] month_offset;input [3:0] mm;
begin case(mm)
1:month_offset=0;2:month_offset=3;3:month_offset=2;4:month_offset=5;
5:month_offset=0;6:month_offset=3;7:month_offset=5;8:month_offset=1;
9:month_offset=4;10:month_offset=6;11:month_offset=2;default:month_offset=4;
endcase end endfunction
wire [11:0] adjusted_year=12'd2000+year-(month<3?12'd1:12'd0);
wire [12:0] weekday_sum=adjusted_year+adjusted_year/4-adjusted_year/100+adjusted_year/400+month_offset(month)+day;
assign weekday=weekday_sum%7;
always @(posedge clk)begin
 if(rst)begin divider<=0;year<=0;month<=1;day<=1;hour<=0;minute<=0;second<=0;
 calibrated<=0;accepted<=0;rejected<=0;index<=0;checksum<=0;timeout<=0;end
 else begin
 accepted<=0;rejected<=0;
 if(index!=0)begin
 if(timeout==CLOCK_HZ/10-1)begin index<=0;timeout<=0;rejected<=1;end else timeout<=timeout+1'b1;
 end else timeout<=0;
 if(divider==CLOCK_HZ-1)begin
 divider<=0;
 if(calibrated)begin
 if(second<59)second<=second+1'b1;else begin second<=0;
 if(minute<59)minute<=minute+1'b1;else begin minute<=0;
 if(hour<23)hour<=hour+1'b1;else begin hour<=0;
 if(day<days_in_month(year,month))day<=day+1'b1;
 else begin day<=1;if(month<12)month<=month+1'b1;else begin month<=1;if(year==99)year<=0;else year<=year+1'b1;end end
 end end end end
 end else divider<=divider+1'b1;
 if(byte_valid)begin
 timeout<=0;
 case(index)
 0:if(byte_data==8'ha5)index<=1;
 1:if(byte_data==8'h5a)begin index<=2;checksum<=0;end else if(byte_data!=8'ha5)index<=0;
 2,3,4,5,6,7,8:begin packet[index-2]<=byte_data;checksum<=checksum^byte_data;index<=index+1'b1;end
 9:begin
 index<=0;
 if(byte_data==checksum && packet[0]==1 && packet[1]<100 && packet[2]>=1 && packet[2]<=12 &&
 packet[3]>=1 && packet[3]<=days_in_month(packet[1][6:0],packet[2][3:0]) && packet[4]<24 && packet[5]<60 && packet[6]<60)begin
 year<=packet[1][6:0];month<=packet[2][3:0];day<=packet[3][5:0];hour<=packet[4][4:0];minute<=packet[5][5:0];second<=packet[6][5:0];
 divider<=0;calibrated<=1;accepted<=1;
 end else rejected<=1;
 end
 default:index<=0;
 endcase
 end
 end
end
endmodule
