module predictor(
    input [15:0] PC_input,
    input clk,
    input rst,

    output jump_enable,
    output [15:0] jump_address,

    input update_enable,
    input [15:0] PC_update,
    input branch_order,
    input [15:0] actual_address,
    input actual_jump
);

    localparam PRED_BITS = 5;
    localparam PRED_ENTRIES = (1 << PRED_BITS);

    reg [1:0] bht [0:PRED_ENTRIES-1];
    reg [15:0] btb [0:PRED_ENTRIES-1];
    reg tag_pc5 [0:PRED_ENTRIES-1];
    reg valid [0:PRED_ENTRIES-1];

    wire [PRED_BITS-1:0] read_index = PC_input[PRED_BITS-1:0];
    wire read_tag = PC_input[5];

    wire [PRED_BITS-1:0] update_index = PC_update[PRED_BITS-1:0];
    wire update_tag = PC_update[5];

    integer i;

    wire hit = valid[read_index] && (tag_pc5[read_index] == read_tag);

    assign jump_enable  = hit && bht[read_index][1];
    assign jump_address = btb[read_index];

    always @(posedge clk or negedge rst) begin
        if (~rst) begin
            for (i = 0; i < PRED_ENTRIES; i = i + 1) begin
                bht[i] <= 2'b01;      // weakly not taken
                btb[i] <= 16'd0;
                tag_pc5[i] <= 1'b0;
                valid[i] <= 1'b0;
            end
        end else if (update_enable && branch_order) begin
            valid[update_index] <= 1'b1;
            tag_pc5[update_index] <= update_tag;

            if (actual_jump) begin
                btb[update_index] <= actual_address;

                if (bht[update_index] != 2'b11) begin
                    bht[update_index] <= bht[update_index] + 1'b1;
                end
            end else begin
                if (bht[update_index] != 2'b00) begin
                    bht[update_index] <= bht[update_index] - 1'b1;
                end
            end
        end
    end

endmodule
