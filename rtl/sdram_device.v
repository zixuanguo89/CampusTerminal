// Match the reference wrapper's public configuration for its protected core.
`define DEBUG
module sdram_device(input clk,shift_clk,rst,output initialized,refresh,busy,
input wr,input [20:0] wr_addr,input [3:0] mask,input [31:0] wr_data,
input rd,input [20:0] rd_addr,output rd_valid,output reg [31:0] rd_data);
wire ram_clk,ras,cas,we;wire [1:0] bank;wire [10:0] address;wire [3:0] dm;wire [31:0] dq;
wire [31:0] raw_read_data;
wire core_refresh;reg [9:0] refresh_timer;reg refresh_request,refresh_sent;reg [4:0] quiet;reg [6:0] refresh_hold;
wire refresh_due=refresh_timer>=512;
assign refresh=core_refresh || refresh_due || refresh_hold!=0;
// Reserve refresh at burst boundaries. The reference automatic refresher can
// interrupt a four-word app burst; manual requests preserve every queued word.
// 512 clocks + a maximum 320-word burst + drain is below the 31.25 us row limit.
always @(posedge clk)begin
 if(rst || !initialized)begin refresh_timer<=0;refresh_request<=0;refresh_sent<=0;quiet<=0;refresh_hold<=0;end
 else begin
 if(refresh_hold!=0)refresh_hold<=refresh_hold-1'b1;
 if(wr || rd || rd_valid)quiet<=0;else if(quiet<31)quiet<=quiet+1'b1;
 refresh_request<=0;
 if(core_refresh)begin refresh_timer<=0;refresh_sent<=0;end
 else begin
 if(refresh_timer<1023)refresh_timer<=refresh_timer+1'b1;
 if(refresh_due && !refresh_sent && !busy && quiet>=24 && !wr && !rd)begin refresh_request<=1;refresh_sent<=1;refresh_hold<=64;end
 end end
end
// The protected core's valid strobe is one app clock later than its captured
// DQ word. Align the public app payload to that strobe, including the last word.
always @(posedge clk)rd_data<=raw_read_data;
sdr_as_ram #(.self_refresh_open(0)) controller(.Sdr_clk(clk),.Sdr_clk_sft(shift_clk),.Rst(rst),
.Sdr_init_done(initialized),.Sdr_init_ref_vld(core_refresh),.Sdr_busy(busy),.App_ref_req(refresh_request),
.App_wr_en(wr),.App_wr_addr(wr_addr),.App_wr_dm(mask),.App_wr_din(wr_data),
.App_rd_en(rd),.App_rd_addr(rd_addr),.Sdr_rd_en(rd_valid),.Sdr_rd_dout(raw_read_data),
.SDRAM_CLK(ram_clk),.SDR_RAS(ras),.SDR_CAS(cas),.SDR_WE(we),.SDR_BA(bank),.SDR_ADDR(address),.SDR_DM(dm),.SDR_DQ(dq));
EG_PHY_SDRAM_2M_32 device(.clk(ram_clk),.ras_n(ras),.cas_n(cas),.we_n(we),.addr(address),.ba(bank),.dq(dq),
.cs_n(1'b0),.dm0(dm[0]),.dm1(dm[1]),.dm2(dm[2]),.dm3(dm[3]),.cke(1'b1));
endmodule
