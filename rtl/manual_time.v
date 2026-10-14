// Board editor feeds the same validated date packet as the optional UART.
// Draft is independent of the running clock; only KEY3 commits it.
module manual_time(input clk,rst,input panel,alarm,input [3:0] field,press,
 input calibrated,input [6:0] year,input [3:0] month,input [5:0] day,
 input [4:0] hour,input [5:0] minute,second,
 output editing,output busy,output reg byte_valid,output reg [7:0] byte_data,
 output reg [6:0] draft_year,output reg [3:0] draft_month,output reg [5:0] draft_day,
 output reg [4:0] draft_hour,output reg [5:0] draft_minute,draft_second);
reg was_editing;reg [3:0] tx;
wire active=panel && !alarm && field>=7 && field<=12;
assign editing=active;assign busy=tx!=0 || byte_valid;
function [5:0] month_days;input [6:0] yy;input [3:0] mm;
begin case(mm)2:month_days=yy[1:0]==0?29:28;4,6,9,11:month_days=30;default:month_days=31;endcase end endfunction
reg [6:0] ny;reg [3:0] nm;reg [5:0] nd;
always @* begin
 ny=draft_year;nm=draft_month;nd=draft_day;
 if(press[0])case(field)
 7:ny=draft_year==0?99:draft_year-1'b1;
 8:nm=draft_month==1?12:draft_month-1'b1;
 9:nd=draft_day==1?month_days(draft_year,draft_month):draft_day-1'b1;
 endcase
 else if(press[1])case(field)
 7:ny=draft_year==99?0:draft_year+1'b1;
 8:nm=draft_month==12?1:draft_month+1'b1;
 9:nd=draft_day==month_days(draft_year,draft_month)?1:draft_day+1'b1;
 endcase
 if(nd>month_days(ny,nm))nd=month_days(ny,nm);
end
wire [7:0] checksum=8'd1^{1'b0,draft_year}^{4'd0,draft_month}^{2'd0,draft_day}^{3'd0,draft_hour}^{2'd0,draft_minute}^{2'd0,draft_second};
always @(posedge clk)begin
 if(rst)begin was_editing<=0;tx<=0;byte_valid<=0;byte_data<=0;
 draft_year<=26;draft_month<=1;draft_day<=1;draft_hour<=0;draft_minute<=0;draft_second<=0;end
 else begin
 was_editing<=active;byte_valid<=0;
 if(tx!=0)begin
 byte_valid<=1;
 case(tx)
 1:byte_data<=8'ha5;2:byte_data<=8'h5a;3:byte_data<=1;
 4:byte_data<={1'b0,draft_year};5:byte_data<={4'd0,draft_month};6:byte_data<={2'd0,draft_day};
 7:byte_data<={3'd0,draft_hour};8:byte_data<={2'd0,draft_minute};9:byte_data<={2'd0,draft_second};10:byte_data<=checksum;
 endcase
 tx<=tx==10?0:tx+1'b1;
 end else if(active)begin
 if(!was_editing)begin
 draft_year<=calibrated?year:7'd26;draft_month<=calibrated?month:4'd1;draft_day<=calibrated?day:6'd1;
 draft_hour<=calibrated?hour:5'd0;draft_minute<=calibrated?minute:6'd0;draft_second<=calibrated?second:6'd0;
 end else if(press[2])tx<=1;
 else begin
 draft_year<=ny;draft_month<=nm;draft_day<=nd;
 if(press[0])case(field)
 10:draft_hour<=draft_hour==0?23:draft_hour-1'b1;
 11:draft_minute<=draft_minute==0?59:draft_minute-1'b1;
 12:draft_second<=draft_second==0?59:draft_second-1'b1;
 endcase
 else if(press[1])case(field)
 10:draft_hour<=draft_hour==23?0:draft_hour+1'b1;
 11:draft_minute<=draft_minute==59?0:draft_minute+1'b1;
 12:draft_second<=draft_second==59?0:draft_second+1'b1;
 endcase
 end end
 end
end
endmodule
