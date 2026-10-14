// 8.3 directory walker. Deleted entries, LFN and volume labels are skipped.
// The backing reader can follow fragmented directory cluster chains.
module fat_directory(input clk,rst,start,input [31:0] first_cluster,
 input [31:0] data_lba,cluster_count,input [7:0] sectors_per_cluster,
 output request,next_request,output [31:0] address,input service_ready,
 input data_valid,input [7:0] data,input service_done,next_valid,input [27:0] next_cluster,
 output reg entry_valid,input entry_ready,output reg [87:0] name,
 output reg [7:0] attributes,output reg [31:0] cluster,size,
 output reg busy,done,output reg [7:0] error,input [7:0] service_error,output wire want);
reg reader_start,reader_stop;wire byte_valid;wire [7:0] byte_data,reader_error;
wire reader_busy,reader_eof;wire [31:0] current,remaining;wire [7:0] sector;
wire consume=busy && !entry_valid && !reader_stop;
fat_file_reader reader(clk,rst||reader_stop,reader_start,first_cluster,32'h00400000,
data_lba,cluster_count,sectors_per_cluster,request,next_request,address,service_ready,
data_valid,data,service_done,next_valid,next_cluster,byte_valid,byte_data,consume,
reader_busy,reader_eof,reader_error,current,remaining,sector,service_error,want);
reg [4:0] offset;reg deleted;reg [87:0] name_temp;reg [7:0] attr_temp;reg [31:0] cluster_temp,size_temp;
reg starting;
always @(posedge clk)begin
 if(rst)begin reader_start<=0;reader_stop<=1;offset<=0;deleted<=0;name_temp<=0;attr_temp<=0;cluster_temp<=0;size_temp<=0;
 entry_valid<=0;name<=0;attributes<=0;cluster<=0;size<=0;busy<=0;done<=0;error<=0;starting<=0;end
 else begin
 reader_start<=0;done<=0;
 if(entry_valid && entry_ready)entry_valid<=0;
 if(start && !busy)begin
 reader_stop<=0;starting<=1;busy<=1;error<=0;entry_valid<=0;offset<=0;name_temp<=0;cluster_temp<=0;size_temp<=0;
 end
 if(starting)begin reader_start<=1;starting<=0;end
 if(busy && reader_error!=0 && !reader_stop)begin
 // EOC before a zero entry is legal for a completely full directory.
 reader_stop<=1;busy<=0;done<=1;if(reader_error!=5)error<=reader_error;
 end
 if(byte_valid && consume)begin
 offset<=offset+1'b1;
 if(offset==0)begin
 deleted<=byte_data==8'he5 || byte_data==8'h2e;
 if(byte_data==0)begin reader_stop<=1;busy<=0;done<=1;end
 end
 if(offset<11)name_temp<={name_temp[79:0],byte_data};
 case(offset)
 11:attr_temp<=byte_data;
 20:cluster_temp[23:16]<=byte_data;21:cluster_temp[31:24]<=byte_data;
 26:cluster_temp[7:0]<=byte_data;27:cluster_temp[15:8]<=byte_data;
 28:size_temp[7:0]<=byte_data;29:size_temp[15:8]<=byte_data;30:size_temp[23:16]<=byte_data;31:size_temp[31:24]<=byte_data;
 endcase
 if(offset==31 && !deleted && attr_temp!=8'h0f && !attr_temp[3])begin
 entry_valid<=1;name<=name_temp;attributes<=attr_temp;cluster<=cluster_temp;size<={byte_data,size_temp[23:0]};
 end
 end
 end
end
endmodule
