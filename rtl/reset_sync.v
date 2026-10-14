module reset_sync(input clk,input async_rst,output rst);
(* preserve = "true" *) reg [2:0] pipe=3'b111;
always @(posedge clk or posedge async_rst)
 if(async_rst) pipe<=3'b111; else pipe<={pipe[1:0],1'b0};
assign rst=pipe[2];
endmodule
