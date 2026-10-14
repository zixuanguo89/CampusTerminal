module top(input clk,input [3:0] key_n,sw_n,input uart_rx,output uart_tx,
 input sd_miso,output sd_ncs,sd_dclk,sd_mosi,output [3:0] led,
 output HDMI_CLK_P,HDMI_D0_P,HDMI_D1_P,HDMI_D2_P,HDMI_DDC_SCL,inout HDMI_DDC_SDA);
wire pixel_clk,serial_clk,locked;
video_pll clocks(.refclk(clk),.reset(1'b0),.clk0_out(pixel_clk),.clk1_out(serial_clk),.locked(locked));
wire memory_clk,memory_shift_clk,memory_locked,unused_clk100;
sys_pll media_clocks(.refclk(clk),.reset(1'b0),.clk0_out(unused_clk100),.clk1_out(memory_clk),.clk2_out(memory_shift_clk),.locked(memory_locked));
reg [23:0] startup=0;
always @(posedge pixel_clk or negedge locked)if(!locked)startup<=0;else if(startup<12500000)startup<=startup+1'b1;
wire pixel_rst,serial_rst;
reg startup_wait=1;
always @(posedge pixel_clk or negedge locked)if(!locked)startup_wait<=1;else startup_wait<=startup<12500000;
wire startup_rst=!locked || startup_wait;
reset_sync pr(.clk(pixel_clk),.async_rst(startup_rst),.rst(pixel_rst));
reset_sync sr(.clk(serial_clk),.async_rst(startup_rst),.rst(serial_rst));
wire memory_rst;
wire media_reset;wire [15:0] media_retries;
reset_sync mr(.clk(memory_clk),.async_rst(startup_rst || !memory_locked || media_reset),.rst(memory_rst));
wire file_clk=pixel_clk;
wire file_rst=pixel_rst || media_reset;
media_watchdog watchdog(pixel_clk,pixel_rst,cat_done && cat_error==0 && fs_error==0 && init2,
fs_error!=0 || cat_error!=0 || memory_fault_pixel || music_error!=0,media_reset,media_retries);
wire sd_ready,sector_read,sector_valid,sector_end;wire [31:0] sector_lba;wire [7:0] sector_data;
wire mounted,service_ready,service_valid,service_done,next_valid;wire [7:0] fs_error,service_data,sectors_per_cluster;
wire [31:0] data_lba,fat_lba,root_cluster,cluster_count;wire [27:0] next_cluster;
wire cat_request,cat_next_request,cat_done,cat_want;wire [31:0] cat_address,bgm_cluster,bgm_size,alarm_cluster,alarm_size;
wire [7:0] cat_error,image_count;wire [31:0] image_cluster,image_size;wire image_exists;
wire music_request,music_next,music_want,fat_request,fat_next;wire [31:0] music_address,fat_address;
wire image_request,image_next,image_want;wire [31:0] image_address;wire [6:0] image_index;
wire [2:0] client_readies,client_valids,client_dones,client_next_valids;
wire [12:0] music_level;wire [31:0] audio_underruns;wire [7:0] music_error;
wire signed [15:0] music_left,music_right;
fat_service_mux fs_mux(file_clk,file_rst,!cat_done && cat_error==0,music_level<2048,
{music_want,image_want,cat_want},{music_request,image_request,cat_request},{music_next,image_next,cat_next_request},
{music_address,image_address,cat_address},client_readies,client_valids,client_dones,client_next_valids,
service_ready,service_valid,service_done,next_valid,fat_request,fat_next,fat_address);
sd_card_top #(.SPI_LOW_SPEED_DIV(30),.SPI_HIGH_SPEED_DIV(0)) card(
.clk(file_clk),.rst(file_rst),.SD_nCS(sd_ncs),.SD_DCLK(sd_dclk),.SD_MOSI(sd_mosi),.SD_MISO(sd_miso),
.sd_init_done(sd_ready),.sd_sec_read(sector_read),.sd_sec_read_addr(sector_lba),.sd_sec_read_data(sector_data),.sd_sec_read_data_valid(sector_valid),.sd_sec_read_end(sector_end),
.sd_sec_write(1'b0),.sd_sec_write_addr(32'd0),.sd_sec_write_data(8'd0),.sd_sec_write_data_req(),.sd_sec_write_end());
fat32_volume #(.CLOCK_HZ(25000000)) filesystem(file_clk,file_rst,sd_ready,sector_read,sector_lba,sector_valid,sector_data,sector_end,
mounted,fs_error,data_lba,fat_lba,root_cluster,cluster_count,sectors_per_cluster,
fat_request,fat_next,fat_address,service_ready,service_valid,service_data,service_done,next_valid,next_cluster);
media_catalog catalog(file_clk,file_rst,mounted,root_cluster,data_lba,cluster_count,sectors_per_cluster,
cat_request,cat_next_request,cat_address,client_readies[0],client_valids[0],service_data,client_dones[0],client_next_valids[0],next_cluster,fs_error,
cat_done,cat_error,image_count,bgm_cluster,bgm_size,alarm_cluster,alarm_size,image_index,image_cluster,image_size,image_exists,cat_want,album_applied);
wire [9:0] x,y;wire de,hs,vs,sof,eol,frame_tick;
video_timing timing(pixel_clk,pixel_rst,x,y,de,hs,vs,sof,eol,frame_tick);
wire [3:0] press,switches;wire alarm,ack;
input_control controls(pixel_clk,pixel_rst,key_n,sw_n,switches[2],press,switches,alarm,ack);
wire byte_valid,framing_error;wire [7:0] byte_data;
uart_rx receiver(pixel_clk,pixel_rst,uart_rx,byte_valid,byte_data,framing_error);
wire calibrated,accepted,rejected;wire [6:0] year;wire [3:0] month;wire [5:0] day,minute,second;
wire [4:0] hour;wire [2:0] weekday;
wire time_editing,time_busy,manual_byte_valid;wire [7:0] manual_byte_data;
calendar_clock rtc(pixel_clk,pixel_rst,manual_byte_valid || (byte_valid && !time_editing && !time_busy),manual_byte_valid?manual_byte_data:byte_data,calibrated,accepted,rejected,year,month,day,hour,minute,second,weekday);
reg auto_play;reg [7:0] brightness,contrast,interval_s,volume;reg [3:0] field;reg panel_previous;
reg [1:0] transition_mode,duration,album,album_applied;reg album_change;
wire [6:0] draft_year;wire [3:0] draft_month;wire [5:0] draft_day,draft_minute,draft_second;wire [4:0] draft_hour;
manual_time board_time(pixel_clk,pixel_rst,switches[2],alarm,field,press,calibrated,year,month,day,hour,minute,second,
time_editing,time_busy,manual_byte_valid,manual_byte_data,draft_year,draft_month,draft_day,draft_hour,draft_minute,draft_second);

always @(posedge pixel_clk)begin
 if(pixel_rst)begin album_applied<=1;album_change<=0;end
 else begin album_change<=0;if(album!=album_applied && !loader_busy && !transitioning)begin album_applied<=album;album_change<=1;end end
end
always @(posedge pixel_clk)begin
 if(pixel_rst)begin auto_play<=1;brightness<=128;contrast<=16;interval_s<=8;field<=0;panel_previous<=0;transition_mode<=1;volume<=75;duration<=0;album<=1;end
 else begin
 panel_previous<=switches[2];
 if(press[2] && !switches[2] && !alarm)auto_play<=~auto_play;
 if(press[3] && !switches[2] && !alarm && !transitioning)transition_mode<=transition_mode+1'b1;
 if(!switches[2] || alarm)field<=0;
 if(switches[2] && !alarm && !time_busy)begin
 if(press[3])field<=field==12?0:field+1'b1;
 if(press[2] && field>=7)field<=0;
 if(!panel_previous && !calibrated)field<=7;
 if(press[0])case(field)0:if(brightness!=0)brightness<=brightness-1'b1;1:if(contrast!=0)contrast<=contrast-1'b1;2:if(interval_s>1)interval_s<=interval_s-1'b1;
 3:if(volume>0)volume<=volume-1'b1;4:if(!transitioning)transition_mode<=transition_mode-1'b1;5:if(!transitioning)duration<=duration==0?2:duration-1'b1;6:album<=album==0?2:album-1'b1;endcase
 if(press[1])case(field)0:if(brightness!=255)brightness<=brightness+1'b1;1:if(contrast<32)contrast<=contrast+1'b1;2:if(interval_s<60)interval_s<=interval_s+1'b1;
 3:if(volume<100)volume<=volume+1'b1;4:if(!transitioning)transition_mode<=transition_mode+1'b1;5:if(!transitioning)duration<=duration==2?0:duration+1'b1;6:album<=album==2?0:album+1'b1;endcase
 end end
end
wire sample_tick,acr_tick;pcm_clock sample_clock(pixel_clk,pixel_rst,sample_tick,acr_tick);
wire [15:0] volume_product=({8'd0,volume}<<8)-volume;
wire [7:0] music_gain=volume_product/100;
music_player music(file_clk,file_rst,cat_done && cat_error==0,bgm_cluster,bgm_size,data_lba,cluster_count,sectors_per_cluster,
music_request,music_next,music_address,client_readies[2],client_valids[2],service_data,client_dones[2],client_next_valids[2],next_cluster,fs_error,music_want,
sample_tick,alarm,switches[0],music_gain,music_left,music_right,music_level,audio_underruns,music_error);
wire signed [15:0] alarm_pcm;
alarm_audio emergency_audio(pixel_clk,pixel_rst,alarm,sample_tick,alarm_pcm);
wire signed [15:0] fallback_pcm;
fallback_audio test_sound(pixel_clk,pixel_rst,sample_tick,fallback_pcm);
wire fallback_mode=fs_error!=0 || cat_error!=0 || music_error!=0 || (media_retries!=0 && !cat_done);
wire signed [15:0] pcm=alarm?alarm_pcm:fallback_mode?(switches[0]?16'sd0:fallback_pcm):music_left;
wire signed [15:0] pcm_right=alarm?alarm_pcm:fallback_mode?(switches[0]?16'sd0:fallback_pcm):music_right;
wire ram_initialized,ram_refresh,ram_busy,ram_rd_valid;wire [31:0] ram_rd_data;
wire app_wr,app_rd;wire [20:0] app_wr_addr,app_rd_addr;wire [3:0] app_mask;wire [31:0] app_wr_data;
sdram_device ram(memory_clk,memory_shift_clk,memory_rst,ram_initialized,ram_refresh,ram_busy,
app_wr,app_wr_addr,app_mask,app_wr_data,app_rd,app_rd_addr,ram_rd_valid,ram_rd_data);
reg init1,init2;always @(posedge pixel_clk)begin if(file_rst)begin init1<=0;init2<=0;end else begin init1<=ram_initialized;init2<=init1;end end
reg [15:0] seconds_samples;reg second_tick;
always @(posedge pixel_clk)begin
 if(pixel_rst)begin seconds_samples<=0;second_tick<=0;end
 else begin second_tick<=0;if(sample_tick)begin if(seconds_samples==47999)begin seconds_samples<=0;second_tick<=1;end else seconds_samples<=seconds_samples+1'b1;end end
end
wire loader_start,loader_busy,loader_done,shown,transitioning;wire [7:0] loader_error,failed_images;
wire [20:0] destination_base;wire [1:0] current_bank,target_bank;wire [8:0] progress;wire [6:0] current_index;
slideshow_control slides(pixel_clk,file_rst||album_change,cat_done && cat_error==0 && album_applied==album,init2,frame_tick,second_tick,auto_play,alarm,
press[1]&&!switches[2],press[0]&&!switches[2],interval_s,image_count,transition_mode,loader_busy,loader_done,loader_error,
loader_start,image_index,destination_base,shown,current_bank,target_bank,progress,transitioning,current_index,failed_images,duration);
wire write_request,write_full,write_empty,write_pop;wire [56:0] write_packet,write_head;wire [6:0] write_level,read_level;
wire source_request,source_full,source_empty,source_pop;wire [20:0] source_address,source_command;
wire source_command_empty,source_accept,source_valid,source_done;wire [31:0] source_data,source_response;
wire response_full;wire [2:0] source_wlevel,source_rlevel;wire [4:0] response_wlevel,response_rlevel;
image_loader loader(pixel_clk,file_rst,loader_start,init2,image_exists?image_cluster:32'd0,image_exists?image_size:32'd0,destination_base,data_lba,cluster_count,sectors_per_cluster,
image_request,image_next,image_address,client_readies[1],client_valids[1],service_data,client_dones[1],client_next_valids[1],next_cluster,fs_error,image_want,
write_request,write_packet,write_full,write_level,source_request,source_address,source_full,source_empty,source_data,source_pop,loader_busy,loader_done,loader_error);
async_fifo writes(pixel_clk,file_rst,write_request,write_packet,write_full,write_level,memory_clk,memory_rst,write_pop,write_head,write_empty,read_level);
async_fifo #(.WIDTH(21),.ADDR(2)) source_commands(pixel_clk,file_rst,source_request,source_address,source_full,source_wlevel,
memory_clk,memory_rst,source_accept,source_command,source_command_empty,source_rlevel);
async_fifo #(.WIDTH(32),.ADDR(4)) source_responses(memory_clk,memory_rst,source_valid,source_response,response_full,response_wlevel,
pixel_clk,file_rst,source_pop,source_data,source_empty,response_rlevel);
wire display_request,display_accept,display_valid,display_done;wire [20:0] display_address;wire [8:0] display_length;
wire [31:0] display_data,video_underruns;wire memory_idle,memory_fault;
(* preserve="true" *)reg memory_fault_sync,memory_fault_pixel;
always @(posedge pixel_clk)begin
 if(file_rst)begin memory_fault_sync<=0;memory_fault_pixel<=0;end
 else begin memory_fault_sync<=memory_fault;memory_fault_pixel<=memory_fault_sync;end
end
memory_service memory(.clk(memory_clk),.rst(memory_rst),.initialized(ram_initialized),.refresh(ram_refresh),.ram_busy(ram_busy),
.write_available(!write_empty),.write_packet(write_head),.write_pop(write_pop),.write_level(read_level),
.display_request(display_request),.display_address(display_address),.display_length(display_length),.display_accept(display_accept),.display_valid(display_valid),.display_data(display_data),.display_done(display_done),
.source_request(!source_command_empty),.source_address(source_command),.source_accept(source_accept),.source_valid(source_valid),.source_data(source_response),.source_done(source_done),
.app_wr(app_wr),.app_wr_addr(app_wr_addr),.app_mask(app_mask),.app_wr_data(app_wr_data),.app_rd(app_rd),.app_rd_addr(app_rd_addr),.ram_valid(ram_rd_valid),.ram_data(ram_rd_data),.idle(memory_idle),.fault(memory_fault));
wire [15:0] old_pixel,new_pixel,transition_pixel;wire [9:0] ax,ay;wire ad,asof,aeol;
wire [1:0] active_effect=transitioning?transition_mode:2'd0;
framebuffer_reader fetch(pixel_clk,file_rst,memory_clk,memory_rst,shown,x,y,de,sof,eol,current_bank,
transitioning?target_bank:current_bank,active_effect,progress,display_request,display_address,display_length,display_accept,display_valid,display_data,display_done,
old_pixel,new_pixel,ax,ay,ad,asof,aeol,video_underruns);
frame_transition blend(pixel_clk,pixel_rst,old_pixel,new_pixel,ax,ay,progress,active_effect,transition_pixel);
reg [9:0] bx,by,cx,cy,dx,dy;reg bd,bsof,beol;
always @(posedge pixel_clk)begin bx<=ax;by<=ay;bd<=ad;bsof<=asof;beol<=aeol;cx<=bx;cy<=by;dx<=cx;dy<=cy;end
wire [23:0] blended_rgb={transition_pixel[15:11],transition_pixel[15:13],transition_pixel[10:5],transition_pixel[10:9],transition_pixel[4:0],transition_pixel[4:2]};
wire [23:0] adjusted_rgb;wire adjusted_de,adjusted_sof,adjusted_eol;
rgb_adjust adjust(pixel_clk,pixel_rst,shown?blended_rgb:24'h181c24,bd,bsof,beol,brightness,contrast[5:0],adjusted_rgb,adjusted_de,adjusted_sof,adjusted_eol);
wire axis_valid,axis_user,axis_last;wire [23:0] axis_rgb;
wire energy_valid,energy_overrun;wire [255:0] energies;wire [8:0] waveform_y;wire [63:0] heights,peaks;
audio_energy energy_meter(pixel_clk,pixel_rst,sample_tick,pcm,energy_valid,energies,energy_overrun);
// The history RAM read cycle matches the existing cx-to-dx coordinate delay.
audio_visual visualizer(pixel_clk,pixel_rst,sample_tick,frame_tick,pcm,energy_valid,energies,cx,waveform_y,heights,peaks);
wire [7:0] status=memory_fault_pixel?8'd40:fs_error!=0?8'd10+fs_error:cat_error!=0?8'd20+cat_error:music_error!=0?8'd30+music_error:!cat_done?(media_retries!=0?8'd3:8'd1):!shown?8'd2:8'd0;
wire [159:0] parameter_bcd;
parameter_digits decimal_parameters(pixel_clk,pixel_rst,frame_tick,brightness,contrast,interval_s,volume,
transition_mode,duration,album_applied,current_index,status,audio_underruns,parameter_bcd,time_editing,
{2'd0,draft_second,2'd0,draft_minute,3'd0,draft_hour,2'd0,draft_day,4'd0,draft_month,1'b0,draft_year});
display_overlay overlay(pixel_clk,pixel_rst,dx,dy,adjusted_de,adjusted_sof,adjusted_eol,frame_tick,alarm,calibrated||time_editing,switches[2],switches[1],auto_play,
time_editing?draft_year:year,time_editing?draft_month:month,time_editing?draft_day:day,
time_editing?draft_hour:hour,time_editing?draft_minute:minute,time_editing?draft_second:second,weekday,brightness,contrast,interval_s,adjusted_rgb,pcm,axis_valid,axis_user,axis_last,axis_rgb,
field,volume,transition_mode,duration,album_applied,current_index,status,audio_underruns,waveform_y,heights,peaks,parameter_bcd,shown);
wire [9:0] t0,t1,t2,tc;wire ready,video_locked;
reg [17:0] edid_count;wire edid_trig=edid_count==100000;
always @(posedge pixel_clk)if(pixel_rst)edid_count<=0;else if(edid_count<100001)edid_count<=edid_count+1'b1;
hdmi_1_4b_transmitter_core_wrapper #(.DEVICE("EG"),.HTOTAL(800),.HSA(96),.HFP(16),.HBP(48),.HACTIVE(640),
.VTOTAL(525),.VSA(2),.VFP(10),.VBP(33),.VACTIVE(480),.VIDEO_VIC(1),.VIDEO_TPG("Disable"),.VIDEO_FORMAT("RGB"),.AUDIO_SAMPLE_RATE("48K"),.IIC_SCL_DIV(250)) hdmi(
.I_pixel_clk(pixel_clk),.I_rst(pixel_rst),.I_edid_read_trig(edid_trig),.O_edid_read_valid(),.O_edid_read_data(),
.I_axis_s_user(axis_user),.I_axis_s_valid(axis_valid),.I_axis_s_last(axis_last),.I_axis_s_data(axis_rgb),.O_axis_s_ready(ready),
.I_audio_valid(sample_tick),.I_audio_left_data({pcm,8'b0}),.I_audio_right_data({pcm_right,8'b0}),
.I_acr_valid(acr_tick),.I_acr_cts(20'd25000),.I_acr_n(20'd6144),.O_video_locked(video_locked),
.O_ddc_scl(HDMI_DDC_SCL),.IO_ddc_sda(HDMI_DDC_SDA),.O_ch0_tmds_data(t0),.O_ch1_tmds_data(t1),.O_ch2_tmds_data(t2),.O_clk_tmds_data(tc));
hdmi_phy_wrapper phy(pixel_clk,serial_clk,serial_rst,t0,t1,t2,tc,HDMI_D0_P,HDMI_D1_P,HDMI_D2_P,HDMI_CLK_P);
uart_reply reply(pixel_clk,pixel_rst,accepted,rejected,uart_tx);
assign led=~{alarm,calibrated,video_locked,locked};
endmodule
