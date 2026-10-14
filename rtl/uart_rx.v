module uart_rx #(parameter CLOCK_HZ=25000000,parameter BAUD=115200)
(input clk,rst,rx,output reg valid,output reg [7:0] data,output reg framing_error);
localparam DIV=CLOCK_HZ/BAUD;
reg r1,r2;reg [15:0] count;reg [3:0] bit_index;reg [7:0] shift;reg [1:0] state;
always @(posedge clk)begin
 if(rst)begin r1<=1;r2<=1;count<=0;state<=0;bit_index<=0;shift<=0;valid<=0;data<=0;framing_error<=0;end
 else begin
 r1<=rx;r2<=r1;valid<=0;framing_error<=0;
 case(state)
 0:if(!r2)begin count<=DIV/2-1;state<=1;end
 1:if(count!=0)count<=count-1'b1;else if(r2)state<=0;else begin count<=DIV-1;bit_index<=0;state<=2;end
 2:if(count!=0)count<=count-1'b1;else begin
 shift[bit_index]<=r2;count<=DIV-1;
 if(bit_index==7)state<=3;else bit_index<=bit_index+1'b1;end
 3:if(count!=0)count<=count-1'b1;else begin
 state<=0;if(r2)begin data<=shift;valid<=1;end else framing_error<=1;end
 endcase
 end
end
endmodule
