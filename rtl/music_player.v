module music_player(input clk,rst,enabled,input [31:0] first_cluster,file_size,
input [31:0] data_lba,cluster_count,input [7:0] sectors_per_cluster,
output request,next_request,output [31:0] address,input service_ready,
input data_valid,input [7:0] data,input service_done,next_valid,input [27:0] next_cluster,input [7:0] service_error,output want,
input sample_tick,alarm,mute,input [7:0] volume,
output wire signed [15:0] left,right,output wire [12:0] level,output reg [31:0] underruns,output reg [7:0] error);
reg file_start;reg local_reset;reg [2:0] state;reg loop_pending,active;
wire byte_valid,byte_ready,file_busy,file_eof;wire [7:0] byte_data,file_error;wire [31:0] current,remaining;wire [7:0] sector;
fat_file_reader reader(clk,rst||local_reset,file_start,first_cluster,file_size,data_lba,cluster_count,sectors_per_cluster,
request,next_request,address,service_ready,data_valid,data,service_done,next_valid,next_cluster,
byte_valid,byte_data,byte_ready,file_busy,file_eof,file_error,current,remaining,sector,service_error,want);
wire sample_valid,metadata_valid,decoder_done;wire [7:0] decoder_error;wire [31:0] data_bytes;
wire signed [15:0] decoded_left,decoded_right;
wire full,empty;wire [31:0] head;
wav_decoder decoder(clk,rst||local_reset,file_start,byte_valid,byte_data,byte_ready,
!full,sample_valid,decoded_left,decoded_right,metadata_valid,decoder_done,decoder_error,data_bytes);
wire push=sample_valid && !full;
wire pop=sample_tick && !alarm && !empty;
pcm_fifo fifo(clk,rst,push,{decoded_right,decoded_left},pop,head,empty,full,level);
wire signed [24:0] scaled_left=$signed(head[15:0])*$signed({1'b0,volume});
wire signed [24:0] scaled_right=$signed(head[31:16])*$signed({1'b0,volume});
assign left=(!active || empty || alarm || mute)?16'sd0:(scaled_left>>>8);
assign right=(!active || empty || alarm || mute)?16'sd0:(scaled_right>>>8);
always @(posedge clk)begin
 if(rst)begin file_start<=0;local_reset<=1;state<=0;loop_pending<=0;active<=0;underruns<=0;error<=0;end
 else begin
 file_start<=0;local_reset<=0;
 if(metadata_valid)active<=1;
 if(decoder_done)loop_pending<=1;
 if(active && sample_tick && !alarm && empty && underruns!=32'hffffffff)underruns<=underruns+1'b1;
 case(state)
 0:if(enabled && first_cluster>=2 && file_size>0)begin state<=1;end
 1:begin file_start<=1;state<=2;loop_pending<=0;end
 2:if(loop_pending && !sample_valid)begin local_reset<=1;state<=3;end
 3:begin state<=1;end
 endcase
 if(file_error!=0 || decoder_error!=0 || service_error!=0)begin error<=1;active<=0;state<=4;end
 if(state==2 && file_eof && !decoder_done && !loop_pending)begin error<=2;active<=0;state<=4;end
 end
end
endmodule
