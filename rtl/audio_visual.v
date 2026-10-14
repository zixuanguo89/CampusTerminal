// 24kHz PCM history and logarithmic Goertzel bars. Separate capture/display
// banks keep all 352 waveform columns stable for a complete displayed frame.
module audio_visual(input clk,rst,sample_tick,frame_tick,input signed [15:0] pcm,
input block_valid,input [255:0] energies,input [9:0] x,
output wire [8:0] waveform_y,output reg [63:0] heights,peaks);
reg [8:0] head,display_head;reg decimate,write_bank,display_bank;
reg [9:0] filled;reg display_ready;
reg [63:0] pending;integer i,b;reg [4:0] highest;reg [31:0] value;reg [7:0] height;
wire [8:0] address=display_head-9'd352+(x-24);
wire [7:0] history_data;
wire history_write=sample_tick && decimate && !frame_tick && !rst;
// Widen before multiplying: all signed 16-bit PCM inputs fit in 18 bits.
wire signed [17:0] tripled_pcm=$signed(pcm)*18'sd3;
wire signed [17:0] scaled_pcm=tripled_pcm>>>7;
// Three times the previous display gain (24 times the initial gain),
// saturated inside the plot so the waveform cannot overlap the spectrum.
// The audio PCM itself is unchanged.
wire signed [15:0] bounded_pcm=scaled_pcm>44?16'sd44:scaled_pcm< -44?-16'sd44:scaled_pcm;
wire [7:0] waveform_sample=16'sd48-bounded_pcm;
wave_memory history(clk,history_write,{write_bank,head},waveform_sample,{display_bank,address},history_data);
assign waveform_y=display_ready?9'd178+history_data:9'd226;
always @(posedge clk)begin
 if(rst)begin head<=0;display_head<=0;decimate<=0;pending<=0;heights<=0;peaks<=0;filled<=0;
 write_bank<=0;display_bank<=1;display_ready<=0;end
 else begin
 if(!frame_tick && sample_tick)begin decimate<=!decimate;if(decimate)begin
 head<=head+1'b1;if(filled<512)filled<=filled+1'b1;end end
 if(block_valid)for(i=0;i<8;i=i+1)begin
 value=energies[i*32 +:32];highest=0;
 for(b=0;b<32;b=b+1)if(value[b])highest=b;
 pending[i*8 +:8]<=value==0?8'd0:({3'b0,highest}<<1)+{3'b0,highest};
 end
 if(frame_tick)begin display_head<=head;display_bank<=write_bank;display_ready<=filled>=352;
 write_bank<=!write_bank;head<=0;filled<=0;decimate<=0;heights<=pending;
 for(i=0;i<8;i=i+1)begin height=pending[i*8 +:8];
 if(height>=peaks[i*8 +:8])peaks[i*8 +:8]<=height;
 else if(peaks[i*8 +:8]!=0)peaks[i*8 +:8]<=peaks[i*8 +:8]-1'b1;
 end end
 end
end
endmodule
