// All RAM app operations use aligned four-word bursts. Reads may span 4..320
// words. The caller must accept every response; priority belongs to display DMA.
module memory_service(input clk,rst,initialized,refresh,ram_busy,
input write_available,input [56:0] write_packet,output wire write_pop,input [6:0] write_level,
input display_request,input [20:0] display_address,input [8:0] display_length,
output reg display_accept,output wire display_valid,output wire [31:0] display_data,output reg display_done,
input source_request,input [20:0] source_address,output reg source_accept,
output wire source_valid,output wire [31:0] source_data,output reg source_done,
output wire app_wr,output wire [20:0] app_wr_addr,output wire [3:0] app_mask,output wire [31:0] app_wr_data,
output wire app_rd,output wire [20:0] app_rd_addr,input ram_valid,input [31:0] ram_data,
output wire idle,output reg fault);
localparam IDLE=0,WR=1,WR_DRAIN=2,RD=3,RD_DRAIN=4;
reg [2:0] state;reg [8:0] sent,received,length;reg [20:0] base;reg owner;reg [7:0] timer;
assign idle=state==IDLE;
assign app_wr=state==WR && write_available;
assign write_pop=app_wr;
assign app_wr_addr=write_packet[52:32];assign app_mask=write_packet[56:53];assign app_wr_data=write_packet[31:0];
assign app_rd=state==RD;assign app_rd_addr=base+sent;
assign display_valid=(state==RD || state==RD_DRAIN) && !owner && ram_valid;
assign source_valid=(state==RD || state==RD_DRAIN) && owner && ram_valid;
assign display_data=ram_data;assign source_data=ram_data;
always @(posedge clk)begin
 if(rst)begin state<=IDLE;sent<=0;received<=0;length<=0;base<=0;owner<=0;timer<=0;
 display_accept<=0;source_accept<=0;display_done<=0;source_done<=0;fault<=0;end
 else begin
 display_accept<=0;source_accept<=0;display_done<=0;source_done<=0;
 if(ram_valid && (state==RD || state==RD_DRAIN))received<=received+1'b1;
 case(state)
 IDLE:if(initialized && !refresh && !ram_busy)begin
 sent<=0;received<=0;timer<=0;
 if(display_request)begin
 if(display_address[1:0]!=0 || display_length==0 || display_length>320 || display_length[1:0]!=0)fault<=1;
 else begin base<=display_address;length<=display_length;owner<=0;display_accept<=1;state<=RD;end
 end else if(source_request)begin base<=source_address;length<=4;owner<=1;source_accept<=1;state<=RD;
 if(source_address[1:0]!=0)fault<=1;
 end else if(write_level>=4 && write_available)begin state<=WR;length<=4;end
 end
 WR:begin
 if(!write_available)begin fault<=1;state<=WR_DRAIN;timer<=0;end
 else if(sent==3)begin state<=WR_DRAIN;timer<=0;end else sent<=sent+1'b1;
 end
 WR_DRAIN:if(timer==15)state<=IDLE;else timer<=timer+1'b1;
 RD:begin
 if(sent==length-1)begin state<=RD_DRAIN;timer<=0;end else sent<=sent+1'b1;
 end
 RD_DRAIN:begin
 timer<=timer+1'b1;
 if(received==length)begin
 if(owner)source_done<=1;else display_done<=1;state<=IDLE;
 end else if(timer==255)begin fault<=1;state<=IDLE;end
 end
 endcase
 end
end
endmodule
