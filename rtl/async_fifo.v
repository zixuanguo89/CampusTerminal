module async_fifo #(parameter WIDTH=57,ADDR=6)
(input wclk,wrst,we,input [WIDTH-1:0] data,output reg full,output wire [ADDR:0] wlevel,
input rclk,rrst,re,output wire [WIDTH-1:0] q,output reg empty,output wire [ADDR:0] rlevel);
reg [WIDTH-1:0] memory[0:(1<<ADDR)-1];
reg [ADDR:0] wp,rp,wgray,rgray;
(* preserve="true" *)reg [ADDR:0] rg1,rg2,wg1,wg2;
wire [ADDR:0] wn=wp+(we&&!full),rn=rp+(re&&!empty);
wire [ADDR:0] wgn=(wn>>1)^wn,rgn=(rn>>1)^rn;
function [ADDR:0] binary;input [ADDR:0] gray;integer j;
begin binary[ADDR]=gray[ADDR];for(j=ADDR-1;j>=0;j=j-1)binary[j]=binary[j+1]^gray[j];end endfunction
assign wlevel=wp-binary(rg2);assign rlevel=binary(wg2)-rp;assign q=memory[rp[ADDR-1:0]];
always @(posedge wclk)begin
 if(wrst)begin wp<=0;wgray<=0;rg1<=0;rg2<=0;full<=0;end
 else begin
 rg1<=rgray;rg2<=rg1;wp<=wn;wgray<=wgn;
 full<=wgn=={~rg2[ADDR:ADDR-1],rg2[ADDR-2:0]};
 if(we&&!full)memory[wp[ADDR-1:0]]<=data;
 end
end
always @(posedge rclk)begin
 if(rrst)begin rp<=0;rgray<=0;wg1<=0;wg2<=0;empty<=1;end
 else begin wg1<=wgray;wg2<=wg1;rp<=rn;rgray<=rgn;empty<=rgn==wg2;end
end
endmodule
