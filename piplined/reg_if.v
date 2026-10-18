module reg_if(
    input clk,
    input rst,
    input write_enable,

    input [15:0] pc_input,
    input valid_input,

    output [15:0] pc_output,
    output valid_output
);

    reg [15:0] pc_reg;
    reg valid_reg;

    always @(posedge clk or negedge rst) begin
        if (~rst) begin
            pc_reg <= 16'd0;
            valid_reg <= 1'b0;
        end else if (write_enable) begin
            pc_reg <= pc_input;
            valid_reg <= valid_input;
        end
    end

    assign pc_output = pc_reg;
    assign valid_output = valid_reg;

endmodule