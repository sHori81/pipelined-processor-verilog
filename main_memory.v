module main_memory#(
    parameter INIT_FILE = "simple.hex" // デフォルトのファイル名
)(
    input clk, write_enable, read_enable,
    input [15:0] address_bus,
    input [15:0] data_input,
    output reg [15:0] data_output
);

	initial begin
		$readmemh(INIT_FILE, memory);
	end
	
    (* ram_init_file = INIT_FILE *) 
    (* ramstyle = "MLAB" *)
    reg [15:0] memory [0:8191]; //15ビット幅のメモリを8192個用意する.\

    always @(posedge clk) begin
        if (write_enable) begin
            memory[address_bus] <= data_input;
        end 
        if (read_enable) begin
            data_output <= memory[address_bus];
        end
    end
endmodule
