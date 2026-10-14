module fallback_audio(input clk,rst,sample_tick,output reg signed [15:0] pcm);
reg [31:0] phase;
function signed [15:0] sine;input [3:0] address;begin case(address)
0,8:sine=0;1,7:sine=459;2,6:sine=849;3,5:sine=1109;4:sine=1200;
9,15:sine=-459;10,14:sine=-849;11,13:sine=-1109;default:sine=-1200;
endcase end endfunction
always @(posedge clk)begin
 if(rst)begin phase<=0;pcm<=0;end
 else if(sample_tick)begin phase<=phase+32'd89478485;pcm<=sine(phase[31:28]);end
end
endmodule
