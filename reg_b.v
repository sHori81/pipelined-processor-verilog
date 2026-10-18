module reg_b(
	input clk, rst, write_enable,
	input [15:0] data_b_in,
	output reg [15:0] data_b_out);
	
	always @(posedge clk or negedge rst) begin
		if (~rst) begin
			data_b_out <= 16'd0;
		end else if (write_enable) begin
			data_b_out <= data_b_in;	
		end
	end
	
endmodule