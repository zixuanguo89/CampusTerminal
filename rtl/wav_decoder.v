// Walk RIFF chunks, including odd padding; fmt must precede data.
// Accepts PCM signed16, 48kHz stereo; never assumes a 44-byte header.
module wav_decoder(input clk,rst,start,input valid,input [7:0] data,output wire ready,
 input sample_ready,output reg sample_valid,output reg signed [15:0] left,right,
 output reg metadata_valid,done,output reg [7:0] error,output reg [31:0] data_bytes);
localparam RIFF=0,CHUNK_HEADER=1,FMT=2,SKIP=3,PCM=4,PAD=5,STOP=6;
reg [2:0] state;reg running,fmt_ok;reg [31:0] position,chunk_id,chunk_size,chunk_pos;
reg [31:0] riff_id,wave_id,sample_rate,byte_rate;
reg [15:0] encoding,channels,align,bits;reg [7:0] lo;reg [1:0] component;
wire [31:0] completed_size={data,chunk_size[31:8]};
assign ready=running && (!sample_valid || sample_ready);
always @(posedge clk)begin
 if(rst || start)begin
 state<=RIFF;running<=start;fmt_ok<=0;position<=0;chunk_id<=0;chunk_size<=0;chunk_pos<=0;
 riff_id<=0;wave_id<=0;sample_rate<=0;byte_rate<=0;encoding<=0;channels<=0;align<=0;bits<=0;
 component<=0;lo<=0;sample_valid<=0;left<=0;right<=0;metadata_valid<=0;done<=0;error<=0;data_bytes<=0;
 end else begin
 metadata_valid<=0;done<=0;if(sample_valid && sample_ready)sample_valid<=0;
 if(valid && ready)case(state)
 RIFF:begin
 if(position<4)riff_id<= {data,riff_id[31:8]};
 if(position>=8)wave_id<={data,wave_id[31:8]};
 if(position==11)begin
 if(riff_id!=32'h46464952 || {data,wave_id[31:8]}!=32'h45564157)begin error<=1;running<=0;state<=STOP;end
 else begin state<=CHUNK_HEADER;position<=0;end
 end else position<=position+1'b1;
 end
 CHUNK_HEADER:begin
 if(position<4)chunk_id<={data,chunk_id[31:8]};else chunk_size<={data,chunk_size[31:8]};
 if(position==7)begin
 position<=0;chunk_pos<=0;
 if({data,chunk_size[31:8]}==0)begin state<=CHUNK_HEADER;end
 else if(chunk_id==32'h20746d66)begin
 if({data,chunk_size[31:8]}<16)begin error<=2;running<=0;state<=STOP;end else state<=FMT;
 end else if(chunk_id==32'h61746164)begin
 if(!fmt_ok || completed_size[1:0]!=0)begin error<=3;running<=0;state<=STOP;end
 else begin state<=PCM;data_bytes<={data,chunk_size[31:8]};metadata_valid<=1;end
 end else state<=SKIP;
 end else position<=position+1'b1;
 end
 FMT:begin
 case(chunk_pos)
 0:encoding[7:0]<=data;1:encoding[15:8]<=data;2:channels[7:0]<=data;3:channels[15:8]<=data;
 4:sample_rate[7:0]<=data;5:sample_rate[15:8]<=data;6:sample_rate[23:16]<=data;7:sample_rate[31:24]<=data;
 8:byte_rate[7:0]<=data;9:byte_rate[15:8]<=data;10:byte_rate[23:16]<=data;11:byte_rate[31:24]<=data;
 12:align[7:0]<=data;13:align[15:8]<=data;14:bits[7:0]<=data;15:bits[15:8]<=data;
 endcase
 if(chunk_pos==15)begin
 if(encoding!=1 || channels!=2 || sample_rate!=48000 || byte_rate!=192000 || align!=4 || {data,bits[7:0]}!=16)begin
 error<=4;running<=0;state<=STOP;end else fmt_ok<=1;
 end
 if(chunk_pos==chunk_size-1)begin state<=chunk_size[0]?PAD:CHUNK_HEADER;position<=0;end
 chunk_pos<=chunk_pos+1'b1;
 end
 SKIP:begin
 if(chunk_pos==chunk_size-1)begin state<=chunk_size[0]?PAD:CHUNK_HEADER;position<=0;end
 chunk_pos<=chunk_pos+1'b1;
 end
 PAD:begin state<=CHUNK_HEADER;position<=0;end
 PCM:begin
 case(component)
 0:lo<=data;1:left<={data,lo};2:lo<=data;3:begin right<={data,lo};sample_valid<=1;end
 endcase
 component<=component+1'b1;chunk_pos<=chunk_pos+1'b1;
 if(chunk_pos==chunk_size-1)begin running<=0;done<=1;state<=STOP;end
 end
 endcase
 end
end
endmodule
