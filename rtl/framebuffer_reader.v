module framebuffer_reader(input pixel_clk,pixel_rst,memory_clk,memory_rst,enabled,
input [9:0] x,y,input de,sof,eol,input [1:0] old_frame,new_frame,effect,input [8:0] progress,
output wire request,output wire [20:0] address,output wire [8:0] length,input accept,
input valid,input [31:0] data,input done,
output wire [15:0] old_pixel,new_pixel,output reg [9:0] aligned_x,aligned_y,
output reg aligned_de,aligned_sof,aligned_eol,output reg [31:0] underruns);
function [20:0] frame_base;input [1:0] frame;
begin case(frame)0:frame_base=0;1:frame_base=153600;default:frame_base=307200;endcase end endfunction
reg read_bank,line_ok;reg [1:0] state;reg [8:0] line;reg [1:0] fa,fb;
reg target_bank,same,second_pass;reg [8:0] count;
reg completed_toggle,completed_bank;reg [8:0] completed_line;
(* preserve="true" *)reg complete1,complete2;
reg seen;reg available;reg [8:0] ready_line;reg ready_bank;
// Start fetching into the other line bank near the start of the visible line.
// Waiting until horizontal blanking gives only 6.4 us, too little for two images.
wire command_we=enabled && ((x==8 && y<479) || (x==32 && y==480));
wire [8:0] wanted_line=y==480?9'd0:y[8:0]+1'b1;
wire [13:0] command_data={old_frame,new_frame,!read_bank,wanted_line};
wire [13:0] command;wire command_full,command_empty,command_pop;wire [2:0] wl,rl;
async_fifo #(.WIDTH(14),.ADDR(2)) commands(pixel_clk,pixel_rst,command_we,command_data,command_full,wl,
memory_clk,memory_rst,command_pop,command,command_empty,rl);
assign command_pop=state==0 && !command_empty;
assign request=state==1;
assign address=frame_base(fa)+({12'd0,line}<<8)+({12'd0,line}<<6);
assign length=320;
wire write_a=valid && state==2 && !second_pass;
wire write_b=valid && state==2 && (second_pass || same);
wire [9:0] wa={target_bank,count};
wire [17:0] slide=({9'd0,progress}<<9)+({9'd0,progress}<<7);
wire [10:0] shifted=x+slide[17:8];
wire [9:0] rx=(effect==2)?(shifted>=640?shifted-640:shifted):x;
wire effective_bank=(x==0 && y<480 && available && ready_line==y)?ready_bank:read_bank;
wire effective_ok=(x==0 && y<480)?(enabled && available && ready_line==y):line_ok;
wire [9:0] ra={effective_bank,rx[9:1]};
wire [31:0] qa,qb;reg parity,valid_line;
line_memory old_line(memory_clk,write_a,wa,data,pixel_clk,ra,qa);
line_memory new_line(memory_clk,write_b,wa,data,pixel_clk,ra,qb);
assign old_pixel=valid_line?(parity?qa[31:16]:qa[15:0]):16'd0;
assign new_pixel=valid_line?(parity?qb[31:16]:qb[15:0]):16'd0;
always @(posedge pixel_clk)begin
 if(pixel_rst)begin complete1<=0;complete2<=0;seen<=0;available<=0;ready_line<=0;ready_bank<=0;
 read_bank<=0;line_ok<=0;valid_line<=0;parity<=0;aligned_x<=0;aligned_y<=0;aligned_de<=0;aligned_sof<=0;aligned_eol<=0;underruns<=0;end
 else begin
 complete1<=completed_toggle;complete2<=complete1;
 if(complete2!=seen)begin seen<=complete2;available<=1;ready_line<=completed_line;ready_bank<=completed_bank;end
 if(x==0 && y<480)begin
 line_ok<=effective_ok;if(effective_ok)read_bank<=ready_bank;
 else if(enabled && underruns!=32'hffffffff)underruns<=underruns+1'b1;
 end
 if(command_we && command_full && underruns!=32'hffffffff)underruns<=underruns+1'b1;
 valid_line<=effective_ok;parity<=rx[0];aligned_x<=x;aligned_y<=y;aligned_de<=de;aligned_sof<=sof;aligned_eol<=eol;
 end
end
always @(posedge memory_clk)begin
 if(memory_rst)begin state<=0;line<=0;fa<=0;fb<=0;target_bank<=0;same<=0;second_pass<=0;count<=0;
 completed_toggle<=0;completed_bank<=0;completed_line<=0;end
 else begin
 case(state)
 0:if(command_pop)begin fa<=command[13:12];fb<=command[11:10];target_bank<=command[9];line<=command[8:0];
 same<=command[13:12]==command[11:10];second_pass<=0;state<=1;count<=0;end
 1:if(accept)state<=2;
 2:begin
 if(valid)count<=count+1'b1;
 if(done)begin
 if(same || second_pass)begin completed_line<=line;completed_bank<=target_bank;completed_toggle<=~completed_toggle;state<=0;end
 else begin fa<=fb;state<=1;count<=0;second_pass<=1;end
 end
 end
 endcase
 end
end
endmodule
