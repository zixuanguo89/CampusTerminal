module image_loader(input clk,rst,start,initialized,input [31:0] first_cluster,file_size,
input [20:0] destination_base,input [31:0] data_lba,cluster_count,input [7:0] sectors_per_cluster,
output request,next_request,output [31:0] address,input service_ready,
input data_valid,input [7:0] data,input service_done,next_valid,input [27:0] next_cluster,input [7:0] service_error,output want,
output wire write,output wire [56:0] write_packet,input write_full,input [6:0] write_level,
output wire source_request,output wire [20:0] source_address,input source_full,
input source_empty,input [31:0] source_data,output wire source_pop,
output reg busy,done,output reg [7:0] error);
localparam SOURCE_BASE=21'd460800;
reg [3:0] state;reg [20:0] frame_base,clear_index;
reg file_start,parser_start,packer_start,scale_start,divide_start;
reg reader_cancel;
wire local_reset=rst || (start && !busy);
wire byte_valid,byte_ready,file_busy,file_eof;wire [7:0] byte_data,file_error;wire [31:0] current,remaining;wire [7:0] sector;
fat_file_reader reader(clk,local_reset || reader_cancel,file_start,first_cluster,file_size,data_lba,cluster_count,sectors_per_cluster,
request,next_request,address,service_ready,data_valid,data,service_done,next_valid,next_cluster,
byte_valid,byte_data,byte_ready,file_busy,file_eof,file_error,current,remaining,sector,service_error,want);
wire pixel_valid,metadata_valid,bitmap_done,packer_ready,packer_idle;wire [15:0] source_pixel;
wire [10:0] source_x,source_y,width,height;wire [7:0] bitmap_error;
bmp_decoder bitmap(clk,local_reset,parser_start,byte_valid,byte_data,byte_ready,state==4 && packer_ready,
pixel_valid,source_pixel,source_x,source_y,width,height,metadata_valid,bitmap_done,bitmap_error);
reg [9:0] fit_width,fit_height,x_offset,y_offset;
reg [31:0] numerator;reg [15:0] denominator;reg fit_wide;
wire divide_busy,divide_done;wire [31:0] quotient;
iterative_divider divider(clk,rst,divide_start,numerator,denominator,divide_busy,divide_done,quotient);
wire scale_valid,scale_done,advance;wire [10:0] sx,sy;wire [9:0] dx,dy;wire [20:0] unused_address;
scale_iterator iterator(clk,rst,scale_start,width,height,fit_width,fit_height,advance,scale_valid,scale_done,sx,sy,dx,dy,unused_address);
wire [10:0] source_stride=((width+11'd7)>>3)<<2;
wire [20:0] wanted_word=SOURCE_BASE+sy*source_stride+(sx>>1);
reg [31:0] cache[0:3];reg [18:0] cache_tag,waiting_tag;reg cache_valid;reg [1:0] received;
wire cache_hit=cache_valid && cache_tag==wanted_word[20:2];
wire [31:0] cache_word=cache[wanted_word[1:0]];
wire [15:0] scaled_pixel=sx[0]?cache_word[31:16]:cache_word[15:0];
assign source_request=state==9 && scale_valid && !cache_hit && !source_full;
assign source_address={wanted_word[20:2],2'b00};
assign source_pop=state==10 && !source_empty;
assign advance=state==9 && scale_valid && cache_hit && packer_ready;
wire packed_write;wire [56:0] packed_packet;
wire packing_source=state==4;
wire packed_valid=packing_source?pixel_valid:(state==9 && scale_valid && cache_hit);
wire [10:0] packed_x=packing_source?source_x:({1'b0,dx}+x_offset);
wire [10:0] packed_y=packing_source?source_y:({1'b0,dy}+y_offset);
pixel_writer packer(clk,rst,packer_start,packing_source?SOURCE_BASE:frame_base,
packing_source?source_stride:11'd320,packing_source?width:({1'b0,x_offset}+fit_width),
packed_valid,packed_x,packed_y,packing_source?source_pixel:scaled_pixel,packer_ready,
packed_write,packed_packet,write_full,packer_idle);
assign write=state==1?!write_full:packed_write;
assign write_packet=state==1?{4'b0000,frame_base+clear_index,32'd0}:packed_packet;
reg [5:0] drain_wait;
wire drained=write_level==0 && packer_idle;
always @(posedge clk)begin
 if(rst)begin state<=0;frame_base<=0;clear_index<=0;file_start<=0;parser_start<=0;packer_start<=0;
 scale_start<=0;divide_start<=0;fit_width<=0;fit_height<=0;x_offset<=0;y_offset<=0;
 numerator<=0;denominator<=0;fit_wide<=0;cache_valid<=0;cache_tag<=0;waiting_tag<=0;received<=0;
 drain_wait<=0;busy<=0;done<=0;error<=0;reader_cancel<=0;end
 else begin
 done<=0;file_start<=0;parser_start<=0;packer_start<=0;scale_start<=0;divide_start<=0;reader_cancel<=0;
 if(drained)begin if(drain_wait<32)drain_wait<=drain_wait+1'b1;end else drain_wait<=0;
 case(state)
 0,12:if(start && initialized)begin
 frame_base<=destination_base;clear_index<=0;busy<=1;error<=0;cache_valid<=0;packer_start<=1;state<=1;end
 1:if(write)begin if(clear_index==153599)begin state<=2;drain_wait<=0;end else clear_index<=clear_index+1'b1;end
 2:if(drain_wait==32)state<=3;
 3:begin file_start<=1;parser_start<=1;packer_start<=1;state<=4;end
 4:if(bitmap_done)begin state<=5;drain_wait<=0;reader_cancel<=1;end
 5:if(drain_wait==32)begin
 if(width*22'd480>height*22'd640)begin fit_wide<=1;numerator<=height*32'd640;denominator<=width;end
 else begin fit_wide<=0;numerator<=width*32'd480;denominator<=height;end
 state<=6;
 end
 6:begin divide_start<=1;state<=7;end
 7:if(divide_done)begin
 if(fit_wide)begin fit_width<=640;fit_height<=quotient==0?10'd1:quotient[9:0];x_offset<=0;y_offset<=((480-(quotient==0?10'd1:quotient[9:0]))>>1);end
 else begin fit_width<=quotient==0?10'd1:quotient[9:0];fit_height<=480;x_offset<=(640-(quotient==0?10'd1:quotient[9:0]))>>1;y_offset<=0;end
 state<=8;
 end
 8:begin scale_start<=1;packer_start<=1;cache_valid<=0;state<=9;end
 9:begin
 if(source_request)begin waiting_tag<=wanted_word[20:2];received<=0;state<=10;end
 if(scale_done)begin state<=11;drain_wait<=0;end
 end
 10:if(source_pop)begin
 cache[received]<=source_data;
 if(received==3)begin cache_tag<=waiting_tag;cache_valid<=1;state<=9;end else received<=received+1'b1;
 end
 11:if(drain_wait==32)begin busy<=0;done<=1;state<=0;end
 endcase
 if(busy && (file_error!=0 || bitmap_error!=0 || service_error!=0))begin busy<=0;error<=1;state<=12;end
 if(state==4 && file_eof && !bitmap_done)begin busy<=0;error<=2;state<=12;reader_cancel<=1;end
 end
end
endmodule
