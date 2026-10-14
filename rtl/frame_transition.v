// progress 0..256; update only during vertical blanking in the controller.
module frame_transition(input clk,rst,input [15:0] old_pixel,new_pixel,
 input [9:0] x,y,input [8:0] progress,input [1:0] effect,
 output reg [15:0] pixel);
wire [8:0] inverse=9'd256-progress;
wire [14:0] red_sum=old_pixel[15:11]*inverse+new_pixel[15:11]*progress;
wire [15:0] green_sum=old_pixel[10:5]*inverse+new_pixel[10:5]*progress;
wire [14:0] blue_sum=old_pixel[4:0]*inverse+new_pixel[4:0]*progress;
wire [17:0] wide_progress={9'd0,progress},wide_inverse={9'd0,inverse};
wire [17:0] wipe_position=(wide_progress<<9)-(wide_progress<<5);
wire [17:0] slide_position=(wide_inverse<<9)+(wide_inverse<<7);
wire [17:0] scaled_x={x,8'b0};
always @(posedge clk)begin
 if(rst)pixel<=0;
 else case(effect)
 0:pixel<=progress==256?new_pixel:old_pixel;
 1:pixel<={red_sum[12:8],green_sum[13:8],blue_sum[12:8]};
 // Horizontal translation uses two offset line fetches in the framebuffer DMA.
 2:pixel<=scaled_x >= slide_position ? new_pixel : old_pixel;
 3:pixel<=y*9'd256 < wipe_position?new_pixel:old_pixel;
 endcase
end
endmodule
