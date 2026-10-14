// Eight Goertzel frequency probes, one shared multiplier, 1024-sample blocks.
// Input is scaled by 1/16. Energies are divided by 4096 and saturated to uint32.
// This is frequency energy, not an FFT or a full-band spectrum.
module audio_energy(input clk,rst,sample_tick,input signed [15:0] pcm,
 output reg block_valid,output reg [255:0] energies,output reg overrun);
reg signed [27:0] q1[0:7],q2[0:7];reg signed [27:0] a,b,previous,current,input_sample;
wire signed [55:0] product=$signed(a)*$signed(b);
reg signed [57:0] power_sum;reg [3:0] state;reg [2:0] band;reg [9:0] sample_count;
wire signed [57:0] recurrence=($signed(product)>>>14)-$signed(q2[band])+$signed(input_sample);
wire signed [57:0] energy=power_sum-$signed(product);
function signed [27:0] coefficient;input [2:0] i;
begin case(i)
0:coefficient=32764;1:coefficient=32750;2:coefficient=32698;3:coefficient=32488;
4:coefficient=31651;5:coefficient=28378;6:coefficient=16384;default:coefficient=0;
endcase end endfunction
integer j;
always @(posedge clk)begin
 if(rst)begin
 for(j=0;j<8;j=j+1)begin q1[j]<=0;q2[j]<=0;end
 a<=0;b<=0;previous<=0;current<=0;input_sample<=0;power_sum<=0;state<=0;band<=0;sample_count<=0;
 block_valid<=0;energies<=0;overrun<=0;
 end else begin
 block_valid<=0;if(sample_tick && state!=0)overrun<=1;
 case(state)
 0:if(sample_tick)begin input_sample<=$signed(pcm)>>>4;band<=0;a<=coefficient(0);b<=q1[0];state<=1;end
 1:begin
 current<=recurrence[27:0];previous<=q1[band];q2[band]<=q1[band];q1[band]<=recurrence[27:0];
 if(recurrence>134217727 || recurrence< -134217728)overrun<=1;
 if(sample_count==1023)begin a<=recurrence[27:0];b<=recurrence[27:0];state<=2;end else state<=6;
 end
 2:begin power_sum<=product;a<=previous;b<=previous;state<=3;end
 3:begin power_sum<=power_sum+$signed(product);a<=coefficient(band);b<=current;state<=4;end
 4:begin a<=$signed(product)>>>14;b<=previous;state<=5;end
 5:begin
 if(energy<0)energies[band*32 +:32]<=0;
 else if((energy>>>12)>32'hffffffff)energies[band*32 +:32]<=32'hffffffff;
 else energies[band*32 +:32]<=energy[43:12];
 q1[band]<=0;q2[band]<=0;state<=6;
 end
 6:if(band==7)begin
 state<=0;if(sample_count==1023)begin sample_count<=0;block_valid<=1;end else sample_count<=sample_count+1'b1;
 end else begin band<=band+1'b1;a<=coefficient(band+1'b1);b<=q1[band+1'b1];state<=1;end
 default:state<=0;
 endcase
 end
end
endmodule
