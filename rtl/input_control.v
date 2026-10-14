module input_control #(parameter DEBOUNCE=250000,parameter HOLD=50000000)
(input clk,rst,input [3:0] key_n,sw_n,input osd,
output reg [3:0] press,output reg [3:0] switches,output reg alarm,
output reg acknowledge);
reg [3:0] k1,k2,s1,s2,stable;
reg [18:0] count[0:3];reg [25:0] hold_count;reg hold_sent;
integer i;
always @(posedge clk) begin
 if(rst) begin k1<=15;k2<=15;s1<=15;s2<=15;stable<=15;switches<=0;
 press<=0;alarm<=0;acknowledge<=0;hold_count<=0;hold_sent<=0;
 for(i=0;i<4;i=i+1)count[i]<=0;end
 else begin
 k1<=key_n;k2<=k1;s1<=sw_n;s2<=s1; switches<=~s2;
 press<=0;acknowledge<=0;
 for(i=0;i<4;i=i+1)begin
 if(k2[i]==stable[i])count[i]<=0;
 else if(count[i]==DEBOUNCE-1)begin
 stable[i]<=k2[i];count[i]<=0;if(!k2[i])press[i]<=1;end
 else count[i]<=count[i]+1'b1;
 end
 if(!stable[3])begin
 if(hold_count<HOLD)hold_count<=hold_count+1'b1;
 if(hold_count==HOLD-1 && !hold_sent)begin
 hold_sent<=1;if(!switches[3])begin alarm<=0;acknowledge<=1;end end
 end else begin hold_count<=0;hold_sent<=0;end
 if(switches[3])alarm<=1;
 end
end
endmodule
