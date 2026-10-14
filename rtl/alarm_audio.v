module alarm_audio(input clk,rst,alarm,sample_tick,output reg signed [15:0] pcm);
`include "rtl/voice_tables.vh"
`include "rtl/resource_paths.vh"
wire [7:0] byte_q;reg [14:0] voice_position;reg [18:0] position;
resource_rom #(.WIDTH(8),.ADDR(14),.DEPTH(VOICE_BYTES),.HEX("assets/voice_ima.hex"),.MIF(`VOICE_MIF)) voice_rom(clk,voice_position[14:1],byte_q);
reg [2:0] sub_sample;reg signed [15:0] predictor;reg [6:0] step_index;
reg alarm_q;reg [31:0] phase;reg [15:0] siren_count;
wire [3:0] code=voice_position[0]?byte_q[7:4]:byte_q[3:0];
wire [15:0] step=ima_step(step_index);
wire [16:0] delta=(step>>3)+(code[2]?{1'b0,step}:17'd0)+(code[1]?{1'b0,step>>1}:17'd0)+(code[0]?{1'b0,step>>2}:17'd0);
wire signed [17:0] next_prediction=$signed(predictor)+(code[3]?-$signed({1'b0,delta}):$signed({1'b0,delta}));
reg signed [8:0] index_delta;
wire signed [8:0] next_index=$signed({2'b0,step_index})+index_delta;
wire speech=position>=96000 && position<96000+VOICE_SAMPLES*6;
wire signed [16:0] mixed=$signed(predictor)+(phase[31]?-17'sd900:17'sd900);
always @* case(code[2:0])0,1,2,3:index_delta=-1;4:index_delta=2;5:index_delta=4;6:index_delta=6;default:index_delta=8;endcase
always @(posedge clk)begin
 alarm_q<=alarm;
 if(rst || !alarm || !alarm_q)begin
 position<=0;voice_position<=0;sub_sample<=0;predictor<=0;step_index<=0;phase<=0;pcm<=0;siren_count<=0;
 end else if(sample_tick)begin
 phase<=phase+(siren_count<24000?32'd62634940:32'd89478485);
 if(siren_count==47999)siren_count<=0;else siren_count<=siren_count+1'b1;
 if(position==383999)begin position<=0;voice_position<=0;sub_sample<=0;predictor<=0;step_index<=0;end
 else position<=position+1'b1;
 if(speech)begin
 if(sub_sample==0)begin
 if(next_prediction>32767)predictor<=32767;else if(next_prediction< -32768)predictor<=-32768;else predictor<=next_prediction[15:0];
 if(next_index<0)step_index<=0;else if(next_index>88)step_index<=88;else step_index<=next_index[6:0];
 if(voice_position<VOICE_SAMPLES-1)voice_position<=voice_position+1'b1;
 end
 if(sub_sample==5)sub_sample<=0;else sub_sample<=sub_sample+1'b1;
 if(mixed>32767)pcm<=32767;else if(mixed< -32768)pcm<=-32768;else pcm<=mixed[15:0];
 end else pcm<=phase[31]?-16'sd6000:16'sd6000;
 end
end
endmodule
