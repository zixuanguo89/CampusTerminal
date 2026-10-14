module video_timing(input clk,input rst,output reg [9:0] x,y,
 output wire de,hs,vs,sof,eol,frame_tick);
assign de=x<640 && y<480;
assign hs=!(x>=656 && x<752);
assign vs=!(y>=490 && y<492);
assign sof=de && x==0 && y==0;
assign eol=de && x==639;
assign frame_tick=x==0 && y==480;
always @(posedge clk) begin
 if(rst) begin x<=0;y<=0;end
 else if(x==799) begin x<=0; if(y==524)y<=0;else y<=y+1'b1;end
 else x<=x+1'b1;
end
endmodule
