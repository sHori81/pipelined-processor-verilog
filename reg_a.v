module reg_a(
	input clk, rst, write_enable,
	input [15:0] data_a_in,
	output reg [15:0] data_a_out);
	
	always @(posedge clk or negedge rst) begin
		if (~rst) begin
			data_a_out <= 16'd0;
		end else if (write_enable) begin
			data_a_out <= data_a_in;	
		end
	end
endmodule