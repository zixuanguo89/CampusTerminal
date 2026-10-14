// Signed offset and Q4 contrast, with saturation. Neutral values: 128 and 16.
module rgb_adjust(input clk,rst,input [23:0] source,input de,sof,eol,
 input [7:0] brightness,input [5:0] contrast,output reg [23:0] result,
 output reg out_de,out_sof,out_eol);
reg signed [16:0] r,g,b;reg [2:0] sync;
function [7:0] clamp;input signed [16:0] value;
begin if(value<0)clamp=0;else if(value>255)clamp=255;else clamp=value[7:0];end endfunction
always @(posedge clk)begin
 if(rst)begin r<=0;g<=0;b<=0;sync<=0;result<=0;out_de<=0;out_sof<=0;out_eol<=0;end
 else begin
 r<=((($signed({1'b0,source[23:16]})-17'sd128)*$signed({1'b0,contrast}))>>>4)+$signed({1'b0,brightness});
 g<=((($signed({1'b0,source[15:8]})-17'sd128)*$signed({1'b0,contrast}))>>>4)+$signed({1'b0,brightness});
 b<=((($signed({1'b0,source[7:0]})-17'sd128)*$signed({1'b0,contrast}))>>>4)+$signed({1'b0,brightness});
 sync<={de,sof,eol};out_de<=sync[2];out_sof<=sync[1];out_eol<=sync[0];
 result<=sync[2]?{clamp(r),clamp(g),clamp(b)}:24'd0;
 end
end
endmodule
