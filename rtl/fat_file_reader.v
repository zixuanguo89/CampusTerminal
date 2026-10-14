// Single streaming file context; scheduler can suspend it at sector boundaries.
// Sector buffered before delivery, so consumer backpressure cannot lose SPI bytes.
module fat_file_reader(input clk,rst,start,input [31:0] first_cluster,file_size,
 input [31:0] data_lba,cluster_count,input [7:0] sectors_per_cluster,
 output reg request,next_request,output reg [31:0] address,input service_ready,
 input data_valid,input [7:0] data,input service_done,next_valid,input [27:0] next_cluster,
 output reg valid,output reg [7:0] byte_data,input consume,
 output reg busy,eof,output reg [7:0] error,
 output reg [31:0] current_cluster,remaining,output reg [7:0] cluster_sector,input [7:0] service_error,output wire want);
localparam IDLE=0,REQUEST=1,FILL=2,PREPARE=3,DELIVER=4,ADVANCE=5,CHAIN_REQ=6,CHAIN_WAIT=7;
reg [2:0] state;reg [9:0] write_pos,read_pos,sector_bytes;reg [31:0] hops;reg prepare_wait;
wire [7:0] buffer_data;
sector_memory buffer(clk,state==FILL && data_valid && write_pos<512,write_pos[8:0],data,read_pos[8:0],buffer_data);
reg [31:0] cycle_checkpoint,cycle_length,cycle_power;
reg [2:0] cluster_shift;
always @* case(sectors_per_cluster)1:cluster_shift=0;2:cluster_shift=1;4:cluster_shift=2;8:cluster_shift=3;
16:cluster_shift=4;32:cluster_shift=5;64:cluster_shift=6;default:cluster_shift=7;endcase
assign want=state==REQUEST || state==CHAIN_REQ;
always @(posedge clk)begin
 if(rst)begin state<=IDLE;request<=0;next_request<=0;address<=0;valid<=0;byte_data<=0;
 busy<=0;eof<=0;error<=0;current_cluster<=0;remaining<=0;cluster_sector<=0;write_pos<=0;read_pos<=0;sector_bytes<=0;hops<=0;
 cycle_checkpoint<=0;cycle_length<=0;cycle_power<=1;prepare_wait<=0;end
 else begin
 request<=0;eof<=0;
 case(state)
 IDLE:if(start)begin
 if(first_cluster<2 || first_cluster>=cluster_count+2 || file_size==0)begin error<=1;eof<=1;end
 else begin current_cluster<=first_cluster;remaining<=file_size;cluster_sector<=0;hops<=0;busy<=1;error<=0;state<=REQUEST;
 cycle_checkpoint<=first_cluster;cycle_length<=0;cycle_power<=1;end
 end
 REQUEST:if(service_ready)begin
 address<=data_lba+((current_cluster-2)<<cluster_shift)+cluster_sector;
 request<=1;next_request<=0;write_pos<=0;state<=FILL;end
 FILL:begin
 if(data_valid && write_pos<512)write_pos<=write_pos+1'b1;
 if(service_done)begin
 if(write_pos!=512)begin error<=2;busy<=0;state<=IDLE;end
 else begin read_pos<=0;sector_bytes<=remaining<512?remaining[9:0]:10'd512;state<=PREPARE;prepare_wait<=1;end
 end end
 PREPARE:if(prepare_wait)prepare_wait<=0;else begin byte_data<=buffer_data;valid<=1;state<=DELIVER;end
 DELIVER:if(consume)begin
 valid<=0;remaining<=remaining-1'b1;
 if(read_pos==sector_bytes-1)begin
 if(remaining==1)begin busy<=0;eof<=1;state<=IDLE;end
 else state<=ADVANCE;
 end else begin read_pos<=read_pos+1'b1;state<=PREPARE;prepare_wait<=1;end
 end
 ADVANCE:if(cluster_sector+1<sectors_per_cluster)begin cluster_sector<=cluster_sector+1'b1;state<=REQUEST;end
 else state<=CHAIN_REQ;
 CHAIN_REQ:if(service_ready)begin request<=1;next_request<=1;address<=current_cluster;state<=CHAIN_WAIT;end
 CHAIN_WAIT:if(next_valid)begin
 if(next_cluster>=28'hffffff8)begin error<=5;busy<=0;state<=IDLE;end
 else if(next_cluster<2 || next_cluster>=cluster_count+2 || next_cluster>=28'hffffff0 || hops>=cluster_count || next_cluster==current_cluster || next_cluster==cycle_checkpoint)begin
 error<=3;busy<=0;state<=IDLE;end
 else begin current_cluster<={4'b0,next_cluster};cluster_sector<=0;hops<=hops+1'b1;state<=REQUEST;
 if(cycle_length+1==cycle_power)begin cycle_checkpoint<={4'b0,next_cluster};cycle_power<=cycle_power<<1;cycle_length<=0;end
 else cycle_length<=cycle_length+1'b1;end
 end
 default:state<=IDLE;
 endcase
 if(busy && service_error!=0)begin error<=4;busy<=0;valid<=0;state<=IDLE;end
 end
end
endmodule
