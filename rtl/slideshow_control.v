module slideshow_control(input clk,rst,enabled,initialized,frame_tick,second_tick,
input auto_play,alarm,next,previous,input [7:0] interval_s,image_count,input [1:0] effect,
input loader_busy,loader_done,input [7:0] loader_error,
output reg loader_start,output reg [6:0] image_index,output reg [20:0] destination_base,
output reg shown,output reg [1:0] current_bank,target_bank,
output reg [8:0] progress,output reg transitioning,output reg [6:0] current_index,
output reg [7:0] failed_images,input [1:0] duration);
reg [6:0] indices[0:2];reg [2:0] cached;reg [127:0] bad;
reg pending,job_active;reg [6:0] wanted,job_index;reg [1:0] job_bank;reg [2:0] job_delay;
reg [7:0] seconds;reg [6:0] transition_frames;reg [8:0] transition_sum;reg [1:0] frame_effect;
wire [6:0] frame_total=duration==0?7'd30:duration==1?7'd60:7'd119;
integer i,match,wanted_bank,next_bank,previous_bank,free_bank;
reg schedule;reg [6:0] schedule_index;
function [6:0] following;input [6:0] n;
begin following=(n==image_count-1)?7'd0:n+1'b1;end endfunction
function [6:0] preceding;input [6:0] n;
begin preceding=n==0?image_count-1:n-1'b1;end endfunction
function [20:0] base;input [1:0] bank;
begin case(bank)0:base=0;1:base=153600;default:base=307200;endcase end endfunction
always @* begin
 wanted_bank=-1;next_bank=-1;previous_bank=-1;free_bank=-1;schedule=0;schedule_index=0;
 for(i=0;i<3;i=i+1)begin
 if(cached[i] && indices[i]==wanted)wanted_bank=i;
 if(cached[i] && indices[i]==following(current_index))next_bank=i;
 if(cached[i] && indices[i]==preceding(current_index))previous_bank=i;
 if(!cached[i] && (!shown || i!=current_bank) && (!transitioning || i!=target_bank))free_bank=i;
 end
 if(free_bank<0)for(i=0;i<3;i=i+1)begin
 if((!shown || i!=current_bank) && (!transitioning || i!=target_bank) &&
 (!shown || (indices[i]!=following(current_index) && indices[i]!=preceding(current_index))))free_bank=i;
 end
 if(enabled && initialized && !job_active && !loader_busy && free_bank>=0)begin
 if(pending && wanted_bank<0 && !bad[wanted])begin schedule=1;schedule_index=wanted;end
 else if(shown && next_bank<0 && !bad[following(current_index)])begin schedule=1;schedule_index=following(current_index);end
 else if(shown && previous_bank<0 && !bad[preceding(current_index)])begin schedule=1;schedule_index=preceding(current_index);end
 end
end
always @(posedge clk)begin
 if(rst)begin
 for(i=0;i<3;i=i+1)indices[i]<=0;
 cached<=0;bad<=0;pending<=1;wanted<=0;job_active<=0;job_delay<=0;job_bank<=0;job_index<=0;
 loader_start<=0;image_index<=0;destination_base<=0;shown<=0;current_bank<=0;target_bank<=0;progress<=256;
 transitioning<=0;current_index<=0;seconds<=0;failed_images<=0;transition_frames<=0;transition_sum<=0;frame_effect<=0;
 end else begin
 loader_start<=0;
 if(schedule)begin job_active<=1;job_delay<=3;job_index<=schedule_index;job_bank<=free_bank;
 image_index<=schedule_index;destination_base<=base(free_bank);cached[free_bank]<=0;end
 if(job_delay!=0)begin job_delay<=job_delay-1'b1;if(job_delay==1)loader_start<=1;end
 if(job_active && job_delay==0 && !loader_start)begin
 if(loader_done)begin cached[job_bank]<=1;indices[job_bank]<=job_index;job_active<=0;end
 if(loader_error!=0)begin job_active<=0;bad[job_index]<=1;if(failed_images<255)failed_images<=failed_images+1'b1;end
 end
 if(pending && bad[wanted])wanted<=following(wanted);
 if(shown && !alarm && !transitioning && !pending)begin
 if(next || previous)begin wanted<=next?following(current_index):preceding(current_index);pending<=1;seconds<=0;end
 else if(second_tick && auto_play)begin
 if(seconds+1>=interval_s)begin wanted<=following(current_index);pending<=1;seconds<=0;end else seconds<=seconds+1'b1;
 end
 end
 if(frame_tick && !alarm)begin
 if(pending && wanted_bank>=0 && !transitioning)begin
 if(!shown || effect==0)begin shown<=1;current_bank<=wanted_bank;target_bank<=wanted_bank;current_index<=wanted;pending<=0;progress<=256;seconds<=0;end
 else begin target_bank<=wanted_bank;progress<=0;transitioning<=1;transition_frames<=0;transition_sum<=0;frame_effect<=effect;end
 end else if(transitioning)begin
 if(transition_frames==frame_total-1)begin progress<=256;current_bank<=target_bank;current_index<=wanted;transitioning<=0;pending<=0;seconds<=0;end
 else begin
 transition_frames<=transition_frames+1'b1;
 // Bresenham progress steps sum to 256 without a variable divider.
 case(duration)
 0:begin if(transition_sum+16>=30)begin progress<=progress+9;transition_sum<=transition_sum+16-30;end else begin progress<=progress+8;transition_sum<=transition_sum+16;end end
 1:begin if(transition_sum+16>=60)begin progress<=progress+5;transition_sum<=transition_sum+16-60;end else begin progress<=progress+4;transition_sum<=transition_sum+16;end end
 default:begin if(transition_sum+18>=119)begin progress<=progress+3;transition_sum<=transition_sum+18-119;end else begin progress<=progress+2;transition_sum<=transition_sum+18;end end
 endcase end
 end
 end
 end
end
endmodule
