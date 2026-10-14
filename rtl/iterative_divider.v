module iterative_divider(input clk,rst,start,input [31:0] numerator,input [15:0] denominator,
output reg busy,done,output reg [31:0] quotient);
reg [31:0] n,q;reg [16:0] remainder;reg [15:0] d;reg [5:0] count;
wire [16:0] shifted={remainder[15:0],n[31]};
wire subtract=shifted>={1'b0,d};
wire [31:0] next_q={q[30:0],subtract};
always @(posedge clk)begin
 if(rst)begin busy<=0;done<=0;quotient<=0;n<=0;q<=0;remainder<=0;d<=0;count<=0;end
 else begin
 done<=0;
 if(start && !busy)begin
 if(denominator==0)begin quotient<=0;done<=1;end
 else begin busy<=1;n<=numerator;d<=denominator;q<=0;remainder<=0;count<=0;end
 end else if(busy)begin
 n<=n<<1;q<=next_q;remainder<=subtract?shifted-d:shifted;
 if(count==31)begin busy<=0;done<=1;quotient<=next_q;end else count<=count+1'b1;
 end
 end
end
endmodule
