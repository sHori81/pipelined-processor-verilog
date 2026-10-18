module reg_file (
	input clk,rst, write_enable,
	input [2:0] address_a, address_b, address_write,
	input [15:0] data_write,
	output [15:0] data_a, data_b
	);
	
	integer i;
	//8bit * 16 registers
	reg [15:0] regs [7:0];
	
	//data read
	assign data_a = regs[address_a];
	assign data_b = regs[address_b];
	
	//data write
	always @(posedge clk or negedge rst) begin
		if (~rst) begin
			for (i = 0; i < 8; i = i + 1) begin
				regs[i] <= 16'd0;
			end
		end else if (write_enable) begin
				regs[address_write] <= data_write;  
			
		end
	end
endmodule