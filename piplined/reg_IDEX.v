module reg_idex(
    input clk, rst, flush, write_enable,
    input reg_write_enable_input, is_st_input, is_alu_input, is_ld_input, is_in_input, is_out_input, is_halt_input,
    input szcv_update_enable_input,
    //control signals, is_st_input: whether the instruction is ST, is_alu_input: whether the instruction uses ALU, is_ld_input: whether the instruction is LD, is_in_input: whether the instruction is IN, is_out_input: whether the instruction is OUT    

    input sel_shifter_input,
    input [3:0] op3_input, 
    input [15:0] data_a_input, data_b_input, 
    input [2:0] address_write_to_reg_file_input,
    input [15:0] data_write_to_main_memory_input,    
    input [3:0] diff_4bit_input, //即値演算のときの4ビットの即値
    input [2:0] sel_out_input,

    output sel_shifter_output,
    output [3:0] op3_output, 
    output [15:0] data_a_output, data_b_output,
    output reg_write_enable_output, is_st_output, is_alu_output, is_ld_output, is_in_output, is_out_output, is_halt_output,
    output szcv_update_enable_output,
    output [2:0] address_write_to_reg_file_output,
    output [15:0] data_write_to_main_memory_output,
    output [3:0] diff_4bit_output, //即値演算のときの4ビットの即値
    output [2:0] sel_out_output
);

reg sel_shifter_reg;
reg [3:0] op3_reg;
reg [15:0] data_a_reg, data_b_reg;
reg [2:0] address_write_to_reg_file_reg;
reg reg_write_enable_reg, is_st_reg, is_alu_reg, is_ld_reg, is_in_reg, is_out_reg, is_halt_reg;
reg szcv_update_enable_reg;
reg [15:0] data_write_to_main_memory_reg;
reg [3:0] diff_4bit_reg;
reg [2:0] sel_out_reg;

always @(posedge clk or negedge rst) begin
    if (~rst) begin
        sel_shifter_reg <= 1'b0;
        op3_reg <= 4'd0;
        data_a_reg <= 16'd0;
        data_b_reg <= 16'd0;
        address_write_to_reg_file_reg <= 3'd0;
        reg_write_enable_reg <= 1'b0;
        is_st_reg <= 1'b0;
        is_alu_reg <= 1'b0;
        is_ld_reg <= 1'b0;
        is_in_reg <= 1'b0;
        is_out_reg <= 1'b0;
        is_halt_reg <= 1'b0;
        szcv_update_enable_reg <= 1'b0;
        data_write_to_main_memory_reg <= 16'd0;
        diff_4bit_reg <= 4'd0;
        sel_out_reg <= 3'd0;
    end else if (write_enable) begin
        // データ系は常に入力を保持
        op3_reg <= op3_input;
        data_a_reg <= data_a_input;
        data_b_reg <= data_b_input;
        address_write_to_reg_file_reg <= address_write_to_reg_file_input;
        data_write_to_main_memory_reg <= data_write_to_main_memory_input;
        diff_4bit_reg <= diff_4bit_input;
        sel_out_reg <= sel_out_input;

        // 制御系だけflushで0化
        reg_write_enable_reg <= flush ? 1'b0 : reg_write_enable_input;
        is_st_reg <= flush ? 1'b0 : is_st_input;
        is_alu_reg <= flush ? 1'b0 : is_alu_input;
        is_ld_reg <= flush ? 1'b0 : is_ld_input;
        is_in_reg <= flush ? 1'b0 : is_in_input;
        is_out_reg <= flush ? 1'b0 : is_out_input;
        is_halt_reg <= flush ? 1'b0 : is_halt_input;
        szcv_update_enable_reg <= flush ? 1'b0 : szcv_update_enable_input;
        sel_shifter_reg <= flush ? 1'b0 : sel_shifter_input;
    end
end

assign sel_shifter_output = sel_shifter_reg;
assign op3_output = op3_reg;
assign data_a_output = data_a_reg;
assign data_b_output = data_b_reg;
assign reg_write_enable_output = reg_write_enable_reg;
assign is_st_output = is_st_reg;
assign is_alu_output = is_alu_reg;
assign is_ld_output = is_ld_reg;
assign is_in_output = is_in_reg;
assign is_out_output = is_out_reg;
assign is_halt_output = is_halt_reg;
assign szcv_update_enable_output = szcv_update_enable_reg;
assign address_write_to_reg_file_output = address_write_to_reg_file_reg;
assign data_write_to_main_memory_output = data_write_to_main_memory_reg;
assign diff_4bit_output = diff_4bit_reg;
assign sel_out_output = sel_out_reg;

endmodule
