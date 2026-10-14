module pcm_clock #(parameter CLOCK_HZ=25000000,parameter RATE=48000)
(input clk,rst,output reg sample_tick,acr_tick);
reg [25:0] accumulator;reg [5:0] samples;
always @(posedge clk)begin
 if(rst)begin accumulator<=0;samples<=0;sample_tick<=0;acr_tick<=0;end
 else begin
 sample_tick<=0;acr_tick<=0;
 if(accumulator>=CLOCK_HZ-RATE)begin
 accumulator<=accumulator+RATE-CLOCK_HZ;sample_tick<=1;
 if(samples==47)begin samples<=0;acr_tick<=1;end else samples<=samples+1'b1;
 end else accumulator<=accumulator+RATE;
 end
end
endmodule
