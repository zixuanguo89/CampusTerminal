// BI_RGB 24-bit BMP parser. RGB565 pixels retain full source coordinates.
// Handles both signed-height orientations, arbitrary pixel offset and row padding.
module bmp_decoder(input clk,rst,start,input valid,input [7:0] data,output wire ready,
 input pixel_ready,output reg pixel_valid,output reg [15:0] pixel,
 output reg [10:0] pixel_x,pixel_y,width,height,
 output reg metadata_valid,done,output reg [7:0] error);
reg [31:0] offset,pixel_offset,dib_size,raw_width,raw_height,compression;
reg [15:0] signature,planes,bits;
reg [7:0] blue,green;reg [1:0] component,padding_left;
reg [10:0] col,row;reg top_down;reg running,parsed;
wire [31:0] absolute_height=raw_height[31]?-raw_height:raw_height;
wire [1:0] pad_bytes=-(raw_width[1:0]*2'd3);
assign ready=running && (!pixel_valid || pixel_ready);
always @(posedge clk)begin
 if(rst || start)begin offset<=0;pixel_offset<=0;dib_size<=0;raw_width<=0;raw_height<=0;compression<=0;signature<=0;planes<=0;bits<=0;
 blue<=0;green<=0;component<=0;padding_left<=0;col<=0;row<=0;top_down<=0;running<=start;parsed<=0;
 pixel_valid<=0;pixel<=0;pixel_x<=0;pixel_y<=0;width<=0;height<=0;metadata_valid<=0;done<=0;error<=0;end
 else begin
 metadata_valid<=0;done<=0;
 if(pixel_valid && pixel_ready)pixel_valid<=0;
 if(valid && ready)begin
 offset<=offset+1'b1;
 if(offset<54)begin
 case(offset)
 0:signature[7:0]<=data;1:signature[15:8]<=data;
 10:pixel_offset[7:0]<=data;11:pixel_offset[15:8]<=data;12:pixel_offset[23:16]<=data;13:pixel_offset[31:24]<=data;
 14:dib_size[7:0]<=data;15:dib_size[15:8]<=data;16:dib_size[23:16]<=data;17:dib_size[31:24]<=data;
 18:raw_width[7:0]<=data;19:raw_width[15:8]<=data;20:raw_width[23:16]<=data;21:raw_width[31:24]<=data;
 22:raw_height[7:0]<=data;23:raw_height[15:8]<=data;24:raw_height[23:16]<=data;25:raw_height[31:24]<=data;
 26:planes[7:0]<=data;27:planes[15:8]<=data;28:bits[7:0]<=data;29:bits[15:8]<=data;
 30:compression[7:0]<=data;31:compression[15:8]<=data;32:compression[23:16]<=data;33:compression[31:24]<=data;
 endcase
 if(offset==53)begin
 if(signature!=16'h4d42 || dib_size<40 || pixel_offset<54 || raw_width==0 || raw_width>1280 || absolute_height==0 || absolute_height>720 || planes!=1 || bits!=24 || compression!=0)begin
 error<=1;running<=0;
 end else begin width<=raw_width[10:0];height<=absolute_height[10:0];top_down<=raw_height[31];parsed<=1;metadata_valid<=1;end
 end
 end else if(parsed && offset>=pixel_offset)begin
 if(padding_left!=0)begin
 padding_left<=padding_left-1'b1;
 if(padding_left==1 && row==height)begin running<=0;done<=1;end
 end else case(component)
 0:begin blue<=data;component<=1;end
 1:begin green<=data;component<=2;end
 2:begin
 pixel<={data[7:3],green[7:2],blue[7:3]};pixel_x<=col;pixel_y<=top_down?row:height-row-1'b1;
 pixel_valid<=1;component<=0;
 if(col==width-1)begin
 col<=0;row<=row+1'b1;padding_left<=pad_bytes;
 if(row==height-1 && pad_bytes==0)begin running<=0;done<=1;end
 end else col<=col+1'b1;
 end
 endcase
 end
 end
 end
end
endmodule
