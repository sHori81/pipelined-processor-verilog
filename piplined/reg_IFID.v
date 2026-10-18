module reg_ifid(
    input clk,
    input rst,
    input write_enable,

    input [15:0] ir_input,
    input [15:0] pc_input,
    input valid_input,

    input pred_en_input,
    input [15:0] pred_pc_input,

    output [15:0] ir_output,
    output [15:0] pc_output,
    output valid_output,

    output pred_en_output,
    output [15:0] pred_pc_output
);

    reg [15:0] ir_reg;
    reg [15:0] pc_reg;
    reg valid_reg;
    reg pred_en_reg;
    reg [15:0] pred_pc_reg;

    always @(posedge clk or negedge rst) begin
        if (~rst) begin
            ir_reg <= 16'h0000;     // 内部bubble表示用。正式NOP化は後回しでOK
            pc_reg <= 16'd0;
            valid_reg <= 1'b0;
            pred_en_reg <= 1'b0;
            pred_pc_reg <= 16'd0;
        end else if (write_enable) begin
            ir_reg <= ir_input;
            pc_reg <= pc_input;
            valid_reg <= valid_input;
            pred_en_reg <= valid_input ? pred_en_input : 1'b0;
            pred_pc_reg <= pred_pc_input;
        end
    end

    assign ir_output = ir_reg;
    assign pc_output = pc_reg;
    assign valid_output = valid_reg;
    assign pred_en_output = pred_en_reg;
    assign pred_pc_output = pred_pc_reg;

endmodule