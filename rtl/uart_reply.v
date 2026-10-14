module uart_reply #(parameter DIVISOR=217)(input clk,rst,accepted,rejected,output wire tx);
reg [9:0] shift;reg [7:0] timer;reg [3:0] bits;reg pending;reg [7:0] code;
assign tx=bits==0?1'b1:shift[0];
always @(posedge clk)begin
 if(rst)begin shift<=10'h3ff;timer<=0;bits<=0;pending<=0;code<=0;end
 else begin
 if(accepted || rejected)begin pending<=1;code<=accepted?8'h06:8'h15;end
 if(bits==0 && pending)begin shift<={1'b1,code,1'b0};bits<=10;timer<=DIVISOR-1;pending<=0;end
 else if(bits!=0)begin if(timer==0)begin shift<={1'b1,shift[9:1]};bits<=bits-1'b1;timer<=DIVISOR-1;end else timer<=timer-1'b1;end
 end
end
endmodule
