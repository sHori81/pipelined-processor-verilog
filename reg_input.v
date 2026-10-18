module reg_input(
	input clk, rst, write_enable,
	input [15:0] data_input,
	output reg [1:0] op1,
	output reg [2:0] address_a, address_b, op2, cond,
	output reg [3:0] op3, dif4,
	output reg [7:0] dif8);
	
	always @(posedge clk or negedge rst) begin
		if (~rst) begin
			op1 <= 2'd0;
			address_a <= 3'd0;
			address_b <= 3'd0;
			op2 <= 3'd0;
			cond <= 3'd0;
			op3 <= 4'd0;
			dif4 <= 4'd0;
			dif8 <= 8'd0;
		end else if (write_enable) begin
			op1 <= data_input[15:14];	
			address_a <= data_input[13:11];
			op2 <= data_input[13:11];
			address_b <= data_input[10:8];
			cond <= data_input[10:8];
			op3 <= data_input[7:4];
			dif8 <= data_input[7:0];
			dif4 <= data_input[3:0];
		end
	end
endmodule