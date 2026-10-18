module reg_exmem (
    input clk, rst, flush, write_enable,
    input reg_write_enable_input, is_st_input, is_ld_input, is_in_input, is_halt_input,
    input szcv_update_enable_input,
    input [15:0] alu_result_input,
    input [3:0] alu_szcv_input,
    input [2:0] address_write_to_reg_file_input,
    input [15:0] data_write_to_main_memory_input,

    output reg_write_enable_output, is_st_output, is_ld_output, is_in_output, is_halt_output,
    output [15:0] alu_result_output,
    output [3:0] alu_szcv_output,
    output [2:0] address_write_to_reg_file_output,
    output [15:0] data_write_to_main_memory_output
);

reg reg_write_enable_reg, is_st_reg, is_ld_reg, is_in_reg, is_halt_reg;

reg [15:0] alu_result_reg;
reg [3:0] alu_szcv_reg;
reg [2:0] address_write_to_reg_file_reg;
reg [15:0] data_write_to_main_memory_reg;

always @(posedge clk or negedge rst) begin
    if (~rst) begin
        reg_write_enable_reg <= 1'b0;
        is_st_reg <= 1'b0;
        is_ld_reg <= 1'b0;
        is_in_reg <= 1'b0;
        is_halt_reg <= 1'b0;
        alu_result_reg <= 16'd0;
        alu_szcv_reg <= 4'd0;
        address_write_to_reg_file_reg <= 3'd0;
        data_write_to_main_memory_reg <= 16'd0;
    end else if (flush) begin
        reg_write_enable_reg <= 1'b0;
        is_st_reg <= 1'b0;
        is_ld_reg <= 1'b0;
        is_in_reg <= 1'b0;
        is_halt_reg <= 1'b0;
        alu_result_reg <= 16'd0;
        address_write_to_reg_file_reg <= 3'd0;
        data_write_to_main_memory_reg <= 16'd0;
    end else if (write_enable) begin
        reg_write_enable_reg <= reg_write_enable_input;
        is_st_reg <= is_st_input;
        is_ld_reg <= is_ld_input;
        is_in_reg <= is_in_input;
        is_halt_reg <= is_halt_input;
        alu_result_reg <= alu_result_input;
        if (szcv_update_enable_input) begin
            alu_szcv_reg <= alu_szcv_input;
        end
        address_write_to_reg_file_reg <= address_write_to_reg_file_input;
        data_write_to_main_memory_reg <= data_write_to_main_memory_input;
    end
end

assign reg_write_enable_output = reg_write_enable_reg;
assign is_st_output = is_st_reg;
assign is_ld_output = is_ld_reg;
assign is_in_output = is_in_reg;
assign is_halt_output = is_halt_reg;
assign alu_result_output = alu_result_reg;
assign alu_szcv_output = alu_szcv_reg;
assign address_write_to_reg_file_output = address_write_to_reg_file_reg;
assign data_write_to_main_memory_output = data_write_to_main_memory_reg;

endmodule
