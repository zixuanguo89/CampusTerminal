module fat_service_mux(input clk,rst,catalog_active,audio_priority,
 input [2:0] wants,requests,next_requests,input [95:0] addresses,
 output reg [2:0] readies,output wire [2:0] valids,dones,next_valids,
 input service_ready,service_valid,service_done,service_next_valid,
 output wire request,next_request,output wire [31:0] address);
reg [1:0] state,owner;reg last_owner;
assign request=state==1 && requests[owner];
assign next_request=next_requests[owner];
assign address=addresses[owner*32 +:32];
assign valids=(state==2 && service_valid)?(3'b001<<owner):3'b000;
assign dones=(state==2 && service_done)?(3'b001<<owner):3'b000;
assign next_valids=(state==2 && service_next_valid)?(3'b001<<owner):3'b000;
always @* begin readies=0;if(state==1 && service_ready)readies[owner]=1;end
always @(posedge clk)begin
 if(rst)begin state<=0;owner<=0;last_owner<=1;end
 else case(state)
 // Directory parsing uses buffered sectors. Reserve the bus only when the
 // directory reader actually wants another sector; otherwise the final
 // buffered sector can leave an idle catalog grant blocking playback forever.
 0:if(catalog_active && wants[0])begin owner<=0;state<=1;end
 else if(wants[2] && (audio_priority || !wants[1] || last_owner==0))begin owner<=2;state<=1;last_owner<=1;end
 else if(wants[1])begin owner<=1;state<=1;last_owner<=0;end
 1:if(service_ready && requests[owner])state<=2;
 else if(!wants[owner] && !requests[owner])state<=0;
 2:if(service_done)state<=0;
 default:state<=0;
 endcase
end
endmodule
