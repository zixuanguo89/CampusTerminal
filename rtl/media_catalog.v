module media_catalog(input clk,rst,mounted,input [31:0] root_cluster,data_lba,cluster_count,
 input [7:0] sectors_per_cluster,
 output request,next_request,output [31:0] address,input service_ready,
 input data_valid,input [7:0] data,input service_done,next_valid,input [27:0] next_cluster,input [7:0] service_error,
 output reg scan_done,output reg [7:0] error,image_count,
 output reg [31:0] bgm_cluster,bgm_size,alarm_cluster,alarm_size,
 input [6:0] image_index,output reg [31:0] image_cluster,image_size,output wire image_exists,output wire want,input [1:0] album);
reg [31:0] clusters[0:127];reg [31:0] sizes[0:127];reg [127:0] found;
reg dir_start;reg [31:0] dir_cluster;wire dir_busy,dir_done,entry_valid;
wire [87:0] name;wire [7:0] attr,dir_error;wire [31:0] first,size;
fat_directory directory(clk,rst,dir_start,dir_cluster,data_lba,cluster_count,sectors_per_cluster,
request,next_request,address,service_ready,data_valid,data,service_done,next_valid,next_cluster,
entry_valid,1'b1,name,attr,first,size,dir_busy,dir_done,dir_error,service_error,want);
reg [3:0] state;reg [31:0] media_dir,image_dir,audio_dir;reg [1:0] scanned_album;
wire [87:0] directory_name=album==1?"ORIG       ":album==2?"TEST       ":"IMG        ";
wire [7:0] prefix=album==1?"O":album==2?"T":"S";
wire digits=name[79:72]>=48 && name[79:72]<=57 && name[71:64]>=48 && name[71:64]<=57 &&
 name[63:56]>=48 && name[63:56]<=57 && name[55:48]>=48 && name[55:48]<=57;
wire [15:0] number=(name[79:72]-16'd48)*16'd1000+(name[71:64]-16'd48)*16'd100+(name[63:56]-16'd48)*16'd10+(name[55:48]-16'd48);
wire excluded=album==1 && (number==2 || number==19 || (number>=23 && number<=25));
wire [7:0] slot=number-1-(album==1?((number>2)+(number>19)+(number>23)+(number>24)+(number>25)):0);
assign image_exists=found[image_index];
always @(posedge clk)begin image_cluster<=clusters[image_index];image_size<=sizes[image_index];end
always @(posedge clk)begin
 if(rst)begin
 state<=0;dir_start<=0;dir_cluster<=0;media_dir<=0;image_dir<=0;audio_dir<=0;
 scan_done<=0;error<=0;image_count<=0;bgm_cluster<=0;bgm_size<=0;alarm_cluster<=0;alarm_size<=0;found<=0;scanned_album<=0;
 end else begin
 dir_start<=0;
 case(state)
 0:if(mounted)begin dir_cluster<=root_cluster;dir_start<=1;state<=1;scanned_album<=album;end
 1:begin
 if(entry_valid && attr[4] && name=="MEDIA      ")media_dir<=first;
 if(dir_done)begin if(media_dir<2)begin error<=1;state<=9;end else begin dir_cluster<=media_dir;dir_start<=1;state<=2;end end
 end
 2:begin
 if(entry_valid && attr[4])begin if(name==directory_name)image_dir<=first;if(name=="AUD        ")audio_dir<=first;end
 if(dir_done)begin
 if(image_dir<2 || audio_dir<2)begin error<=2;state<=9;end
 else begin dir_cluster<=audio_dir;dir_start<=1;state<=3;end end
 end
 3:begin
 if(entry_valid && !attr[4])begin
 if(name=="BGM     WAV")begin bgm_cluster<=first;bgm_size<=size;end
 if(name=="ALARM   WAV")begin alarm_cluster<=first;alarm_size<=size;end
 end
 if(dir_done)begin dir_cluster<=image_dir;dir_start<=1;state<=4;end
 end
 4:begin
 if(entry_valid && !attr[4] && name[87:80]==prefix && name[47:24]=="   " && name[23:0]=="BMP" && digits && number>=1 && number<=128 && !excluded)begin
 clusters[slot]<=first;sizes[slot]<=size;found[slot]<=1;
 if(slot+1>image_count)image_count<=slot+1'b1;
 end
 if(dir_done)begin if(image_count==0 || bgm_cluster<2)error<=3;scan_done<=1;state<=8;end
 end
 8:if(scanned_album!=album)begin state<=0;scan_done<=0;image_count<=0;found<=0;media_dir<=0;image_dir<=0;audio_dir<=0;end
 endcase
 if(dir_error!=0 || service_error!=0)begin error<=4;state<=9;end
 end
end
endmodule
