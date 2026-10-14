// Read-only FAT32 geometry and sector/cluster service. No write commands exist.
// Supports MBR partition 1 or an unpartitioned FAT32 volume, 512-byte sectors.
module fat32_volume #(parameter CLOCK_HZ=100000000)
(input clk,rst,sd_ready,output reg sd_read,output reg [31:0] sd_lba,
 input sd_valid,input [7:0] sd_data,input sd_end,
 output reg mounted,output reg [7:0] error,
 output reg [31:0] data_lba,fat_lba,root_cluster,cluster_count,
 output reg [7:0] sectors_per_cluster,
 input request,input next_request,input [31:0] address,output wire ready,
 output wire data_valid,output wire [7:0] data,output reg done,
 output reg next_valid,output reg [27:0] next_cluster);
localparam WAIT=0,BOOT=1,VALIDATE=2,IDLE=3,RAW=4,FAT=5,FAILED=6;
reg [2:0] state;reg [9:0] offset;reg [26:0] timeout;
reg [31:0] volume_start,partition_start,total_sectors,fat_size;
reg [15:0] bytes_per_sector,reserved_sectors,root_entries,fat16,signature,extended_flags;
reg [7:0] fat_count,partition_type,bpb_cluster;
reg [31:0] bpb_root;reg partition_boot;reg [8:0] fat_offset;
wire cluster_power_two=bpb_cluster!=0 && (bpb_cluster&(bpb_cluster-1'b1))==0;
wire [31:0] overhead=reserved_sectors+(fat_count==2?(fat_size<<1):fat_size);
reg [2:0] cluster_shift;
always @* case(bpb_cluster)1:cluster_shift=0;2:cluster_shift=1;4:cluster_shift=2;8:cluster_shift=3;
16:cluster_shift=4;32:cluster_shift=5;64:cluster_shift=6;default:cluster_shift=7;endcase
wire [31:0] derived_clusters=(total_sectors-overhead)>>cluster_shift;
wire valid_bpb=bytes_per_sector==512 && cluster_power_two && bpb_cluster<=128 &&
 reserved_sectors!=0 && (fat_count==1 || fat_count==2) && root_entries==0 && fat16==0 && fat_size!=0 &&
 signature==16'haa55 && total_sectors>overhead && fat_size<(total_sectors>>1) &&
 derived_clusters>=65525 && derived_clusters<28'hffffff0 && (fat_size>>25)==0 &&
 derived_clusters+2<=(fat_size<<7) && bpb_root>=2 && bpb_root<derived_clusters+2 &&
 !extended_flags[7] && volume_start+total_sectors>=volume_start;
assign ready=state==IDLE;
assign data_valid=state==RAW && sd_valid;
assign data=sd_data;
always @(posedge clk)begin
 if(rst)begin
 state<=WAIT;sd_read<=0;sd_lba<=0;mounted<=0;error<=0;offset<=0;timeout<=0;done<=0;next_valid<=0;next_cluster<=0;
 volume_start<=0;partition_boot<=0;partition_start<=0;partition_type<=0;
 bytes_per_sector<=0;reserved_sectors<=0;root_entries<=0;fat16<=0;signature<=0;extended_flags<=0;
 fat_count<=0;bpb_cluster<=0;total_sectors<=0;fat_size<=0;bpb_root<=0;
 data_lba<=0;fat_lba<=0;root_cluster<=0;cluster_count<=0;sectors_per_cluster<=0;fat_offset<=0;
 end else begin
 sd_read<=0;done<=0;next_valid<=0;
 if(state==BOOT || state==RAW || state==FAT)begin
 if(timeout==CLOCK_HZ/2-1)begin state<=FAILED;error<=8'd1;mounted<=0;done<=1;end
 else timeout<=timeout+1'b1;
 if(sd_valid)begin offset<=offset+1'b1;timeout<=0;end
 end else timeout<=0;
 case(state)
 WAIT:if(sd_ready)begin sd_read<=1;sd_lba<=0;offset<=0;state<=BOOT;end
 BOOT:begin
 if(sd_valid)case(offset)
 11:bytes_per_sector[7:0]<=sd_data;12:bytes_per_sector[15:8]<=sd_data;
 13:bpb_cluster<=sd_data;14:reserved_sectors[7:0]<=sd_data;15:reserved_sectors[15:8]<=sd_data;
 16:fat_count<=sd_data;17:root_entries[7:0]<=sd_data;18:root_entries[15:8]<=sd_data;
 22:fat16[7:0]<=sd_data;23:fat16[15:8]<=sd_data;
 32:total_sectors[7:0]<=sd_data;33:total_sectors[15:8]<=sd_data;34:total_sectors[23:16]<=sd_data;35:total_sectors[31:24]<=sd_data;
 36:fat_size[7:0]<=sd_data;37:fat_size[15:8]<=sd_data;38:fat_size[23:16]<=sd_data;39:fat_size[31:24]<=sd_data;
 40:extended_flags[7:0]<=sd_data;41:extended_flags[15:8]<=sd_data;
 44:bpb_root[7:0]<=sd_data;45:bpb_root[15:8]<=sd_data;46:bpb_root[23:16]<=sd_data;47:bpb_root[31:24]<=sd_data;
 450:partition_type<=sd_data;454:partition_start[7:0]<=sd_data;455:partition_start[15:8]<=sd_data;
 456:partition_start[23:16]<=sd_data;457:partition_start[31:24]<=sd_data;
 510:signature[7:0]<=sd_data;511:signature[15:8]<=sd_data;
 endcase
 if(sd_end)begin if(offset!=512)begin error<=2;state<=FAILED;end else state<=VALIDATE;end
 end
 VALIDATE:begin
 if(valid_bpb)begin
 sectors_per_cluster<=bpb_cluster;fat_lba<=volume_start+reserved_sectors;data_lba<=volume_start+overhead;
 root_cluster<=bpb_root;cluster_count<=derived_clusters;
 mounted<=1;state<=IDLE;
 end else if(!partition_boot && signature==16'haa55 && (partition_type==8'h0b || partition_type==8'h0c) && partition_start!=0)begin
 partition_boot<=1;volume_start<=partition_start;sd_lba<=partition_start;sd_read<=1;offset<=0;state<=BOOT;
 end else begin error<=3;state<=FAILED;end
 end
 IDLE:if(request)begin
 offset<=0;
 if(next_request)begin
 if(address<2 || address>=cluster_count+2)begin error<=4;done<=1;end
 else begin sd_lba<=fat_lba+(address>>7);fat_offset<={address[6:0],2'b00};sd_read<=1;next_cluster<=0;state<=FAT;end
 end else begin sd_lba<=address;sd_read<=1;state<=RAW;end
 end
 RAW:if(sd_end)begin done<=1;if(offset!=512)error<=2;state<=IDLE;end
 FAT:begin
 if(sd_valid)begin
 if(offset==fat_offset)next_cluster[7:0]<=sd_data;
 if(offset==fat_offset+1)next_cluster[15:8]<=sd_data;
 if(offset==fat_offset+2)next_cluster[23:16]<=sd_data;
 if(offset==fat_offset+3)next_cluster[27:24]<=sd_data[3:0];
 end
 if(sd_end)begin done<=1;next_valid<=1;state<=IDLE;if(offset!=512)error<=2;end
 end
 FAILED:mounted<=0;
 default:state<=FAILED;
 endcase
 end
end
endmodule
