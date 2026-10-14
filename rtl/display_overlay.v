module display_overlay(input clk,rst,input [9:0] x,y,input de,sof,eol,frame_tick,
 input alarm,calibrated,show_parameters,show_visual,auto_play,
 input [6:0] year,input [3:0] month,input [5:0] day,input [4:0] hour,
 input [5:0] minute,second,input [2:0] weekday,input [7:0] brightness,contrast,interval_s,
 input [23:0] background,input signed [15:0] pcm,
 output reg valid,user,last,output reg [23:0] rgb,
 input [3:0] field,input [7:0] volume,input [1:0] effect,duration,album,input [6:0] image_index,
 input [7:0] status,input [31:0] audio_underruns,input [8:0] waveform_y,input [63:0] heights,peaks,
 input [159:0] parameter_bcd,input media_shown);
`include "rtl/font_tables.vh"
reg [15:0] scroll;reg [7:0] glyph;reg [4:0] gx,gy;
// The synchronous history supplies consecutive columns on consecutive clocks.
// Bridge their full vertical interval to avoid gaps between steep samples.
reg [8:0] previous_wave_y;
wire [8:0] wave_low=x>24 && previous_wave_y<waveform_y?previous_wave_y:waveform_y;
wire [8:0] wave_high=x>24 && previous_wave_y>waveform_y?previous_wave_y:waveform_y;
always @(posedge clk)begin if(rst)previous_wave_y<=226;else previous_wave_y<=waveform_y;end
reg text_active;reg [23:0] base_color,text_color;
wire [1:0] coverage;reg [16:0] font_address;
wire [7:0] font_byte;reg [1:0] coverage_index;
resource_rom #(.WIDTH(8),.ADDR(15),.DEPTH((FONT_SIZE+3)/4),.HEX("assets/font24_packed.hex")) font_memory(clk,font_address[16:2],font_byte);
assign coverage=font_byte[coverage_index*2 +:2];
always @(posedge clk)coverage_index<=font_address[1:0];
reg [23:0] base_q,fg_q,base_r,fg_r;reg text_q,de_q,sof_q,eol_q,text_r,de_r,sof_r,eol_r;
integer char_index,local_x,sx,sy,i,row,band;reg [11:0] parameter_value;
function [7:0] digit;input [7:0] n;begin digit=n;end endfunction
function [7:0] time_glyph;input [7:0] n;
begin case(n)
0:time_glyph=2;1:time_glyph=0;2:time_glyph=year/10;3:time_glyph=year%10;
4,7:time_glyph=10;5:time_glyph=month/10;6:time_glyph=month%10;
8:time_glyph=day/10;9:time_glyph=day%10;10:time_glyph=12;
11:time_glyph=field>=7 && show_parameters?12:GLYPH_WEEK;12:time_glyph=field>=7 && show_parameters?12:GLYPH_PERIOD;13:time_glyph=field>=7 && show_parameters?12:weekday_glyph(weekday);
14:time_glyph=12;15:time_glyph=hour/10;16:time_glyph=hour%10;
17,20:time_glyph=11;18:time_glyph=minute/10;19:time_glyph=minute%10;
21:time_glyph=second/10;22:time_glyph=second%10;default:time_glyph=12;
endcase end endfunction
always @(posedge clk)begin
 if(rst)scroll<=0;
 else if(frame_tick)begin if(scroll==SLOGAN_LENGTH*24-1)scroll<=0;else scroll<=scroll+1'b1;end
end
always @* begin
 base_color=background;text_color=24'hffffff;text_active=0;glyph=0;gx=0;gy=0;
 char_index=0;local_x=0;sx=0;sy=0;row=0;band=0;parameter_value=0;
 // Full-page slide remains visible behind time and ticker.
 if(y<60 || y>=420)text_color=({2'd0,background[23:16]}+{2'd0,background[15:8]}+{2'd0,background[7:0]})>=384?24'h000000:24'hffffff;
 if(alarm)begin
 text_color=24'hffffff;
 base_color=24'h981818;
 // Left arrow, designed directly in the FPGA, independent of card resources.
 if((x>=150 && x<490 && y>=175 && y<255) ||
 (x>=70 && x<210 && y>=115 && y<315 && (x-70)>((y>215)?y-215:215-y)))base_color=24'hffffff;
 if(y>=340 && y<404 && x>=152 && x<488)begin
 sx=(x-152)>>1;sy=(y-340)>>1;glyph=alarm_glyph(sx/24);gx=sx%24;gy=sy;text_active=1;end
 end else begin
 if(y>=14 && y<46)begin
 if(calibrated && x>=44 && x<596)begin char_index=(x-44)/24;gx=(x-44)%24;gy=y-14;glyph=time_glyph(char_index);text_active=1;end
 if(!calibrated && x>=44 && x<596)begin char_index=(x-44)/24;gx=(x-44)%24;gy=y-14;glyph=uncal_glyph(char_index);text_active=char_index<UNCAL_LENGTH;end
 end
 if(y>=436 && y<468)begin
 sx=x+scroll;if(sx>=SLOGAN_LENGTH*24)sx=sx-SLOGAN_LENGTH*24;
 if(sx>=0 && sx<SLOGAN_LENGTH*24)begin glyph=slogan_glyph(sx/24);gx=sx%24;gy=y-436;text_active=1;end
 end
 // Diagnostic placeholder is replaced by the SDRAM media canvas at integration.
 if(y>=205 && y<237 && x>=176 && x<464 && !media_shown && status<=2)begin
 glyph=placeholder_glyph((x-176)/24);gx=(x-176)%24;gy=y-205;text_active=1;end
 if(y>=205 && y<237 && x>=188 && x<452 && !media_shown && status>2)begin
 glyph=fault_glyph((x-188)/24);gx=(x-188)%24;gy=y-205;text_active=1;end
 if(show_visual && y>=180 && y<412 && x>=16 && x<384)begin
 base_color=24'h102030;
 if(x>=24 && x<376 && y<272 && (y==226 || (y+1>=wave_low && y<=wave_high+1)))base_color=y==226?24'h406070:24'h40ff90;
 if(x>=32 && x<352)begin
 band=(x-32)/40;
 if((x-32)%40>=4 && (x-32)%40<34 && y>=288 && y<384 && 384-y<=heights[band*8 +:8])base_color=24'h40ff90;
 if(y>=288 && y<384 && 384-y==peaks[band*8 +:8])base_color=24'hffcc40;
 if(y>=390 && y<406 && (x-32)%40<36)begin
 glyph=frequency_label(band*3+((x-32)%40)/12);gx=(((x-32)%40)%12)*2;gy=(y-390)*2;text_active=1;
 end end
 end
 if(show_parameters && x>=400 && y>=70 && y<410)begin
 base_color=24'h102838;
 row=(y-70)/34;
 if((field<7 && row==field) || (field>=7 && row+7==field && row<6))base_color=24'h503c10;
 if(x>=408 && x<624)begin
 char_index=(x-408)/24;gx=(x-408)%24;gy=(y-70)%34;
 if(gy<32 && (field<7 || row<8))begin
 text_active=1;
 end
 if(char_index<3)glyph=field>=7?time_label(row*3+char_index):parameter_label(row*3+char_index);
 else if(char_index==3)glyph=12;
 else if(char_index>=4 && char_index<=7)glyph=parameter_bcd[row*16+(7-char_index)*4 +:4];
 else glyph=12;
 end end
 end
 if(alarm && y>=14 && y<46 && x>=44 && x<596)begin
 char_index=(x-44)/24;gx=(x-44)%24;gy=y-14;
 glyph=calibrated?time_glyph(char_index):uncal_glyph(char_index);
 text_active=calibrated || char_index<UNCAL_LENGTH;
 end
 if(!de)base_color=0;
end
// Address, synchronous ROM and blending: three aligned stages.
always @(posedge clk)begin
 if(rst)begin font_address<=0;base_q<=0;fg_q<=0;text_q<=0;de_q<=0;sof_q<=0;eol_q<=0;
 base_r<=0;fg_r<=0;text_r<=0;de_r<=0;sof_r<=0;eol_r<=0;
 valid<=0;user<=0;last<=0;rgb<=0;end
 else begin
 font_address<=({9'd0,glyph}<<9)+({9'd0,glyph}<<8)+({12'd0,gy}<<4)+({12'd0,gy}<<3)+gx;base_q<=base_color;fg_q<=text_color;text_q<=text_active;
 de_q<=de;sof_q<=sof;eol_q<=eol;
 base_r<=base_q;fg_r<=fg_q;text_r<=text_q;de_r<=de_q;sof_r<=sof_q;eol_r<=eol_q;
 valid<=de_r;user<=sof_r;last<=eol_r;
 if(!de_r)rgb<=0;
 else if(text_r)case(coverage)
 0:rgb<=base_r;1:rgb<={(base_r[23:16]>>1)+(fg_r[23:16]>>1),(base_r[15:8]>>1)+(fg_r[15:8]>>1),(base_r[7:0]>>1)+(fg_r[7:0]>>1)};
 2:rgb<=fg_r;default:rgb<=fg_r;endcase
 else rgb<=base_r;
 end
end
endmodule
