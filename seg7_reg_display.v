module seg7_reg_display (
    input  wire        clk,
    input  wire        rst,
    input  wire        snapshot_toggle,

    input  wire [15:0] pc_val,
    input  wire [31:0] cycle_count_val,
    input  wire [15:0] input_val,

    output wire [7:0]  seg_a_out,
    output wire [7:0]  seg_b_out,
    output wire [7:0]  seg_c_out,
    output wire [7:0]  seg_d_out,
    output wire [7:0]  seg_e_out,
    output wire [7:0]  seg_f_out,
    output wire [7:0]  seg_g_out,
    output wire [7:0]  seg_h_out,
    output wire [8:0]  seg_sel
);

localparam [14:0] BLANK_COUNT = 15'd400;
localparam [14:0] ON_COUNT = 15'd20_000;
localparam [14:0] PHASE_LAST = BLANK_COUNT + ON_COUNT - 15'd1;

reg [14:0] phase_cnt;
reg [2:0] row_idx;
reg snapshot_toggle_sync0;
reg snapshot_toggle_sync1;
reg snapshot_toggle_seen;
reg snapshot_pending;
reg [15:0] pc_val_shadow;
reg [31:0] cycle_count_val_shadow;
reg [15:0] input_val_shadow;

wire blank_row = (phase_cnt < BLANK_COUNT);
wire show_input_row = (row_idx == 3'd7);

reg [15:0] left_value;
reg [15:0] right_value;
reg [7:0] hex_blank_mask;

wire [31:0] input_decimal_digits;
wire [7:0] input_decimal_minus;
wire [7:0] input_decimal_blank;

signed_decimal_8digits input_decimal_inst (
    .value(input_val_shadow),
    .digits(input_decimal_digits),
    .minus_mask(input_decimal_minus),
    .blank_mask(input_decimal_blank)
);

always @(posedge clk or negedge rst) begin
    if (~rst) begin
        phase_cnt <= 15'd0;
        row_idx <= 3'd0;
        snapshot_toggle_sync0 <= 1'b0;
        snapshot_toggle_sync1 <= 1'b0;
        snapshot_toggle_seen <= 1'b0;
        snapshot_pending <= 1'b0;
        pc_val_shadow <= 16'd0;
        cycle_count_val_shadow <= 31'd0;
        input_val_shadow <= 16'd0;
    end else begin
        snapshot_toggle_sync0 <= snapshot_toggle;
        snapshot_toggle_sync1 <= snapshot_toggle_sync0;

        if (snapshot_toggle_sync1 != snapshot_toggle_seen) begin
            snapshot_pending <= 1'b1;
        end

        if (phase_cnt == PHASE_LAST) begin
            phase_cnt <= 15'd0;
            row_idx <= row_idx + 3'd1;
        end else begin
            phase_cnt <= phase_cnt + 15'd1;
        end

        if ((phase_cnt == 15'd0) && snapshot_pending) begin
            pc_val_shadow <= pc_val;
            cycle_count_val_shadow <= cycle_count_val;
            input_val_shadow <= input_val;
            snapshot_toggle_seen <= snapshot_toggle_sync1;
            snapshot_pending <= 1'b0;
        end
    end
end

always @(*) begin
    left_value  = 16'h0000;
    right_value = 16'h0000;
    hex_blank_mask = 8'hff;

    case (row_idx)
        3'd4: begin
            left_value = cycle_count_val_shadow[31:16];
            right_value = cycle_count_val_shadow[15:0];
            hex_blank_mask = 8'h00;
        end
        3'd6: begin
            right_value = pc_val_shadow;
            hex_blank_mask = 8'hf0;
        end
        default: begin
            left_value = 16'h0000;
            right_value = 16'h0000;
            hex_blank_mask = 8'hff;
        end
    endcase
end

wire [7:0] hex_a_out;
wire [7:0] hex_b_out;
wire [7:0] hex_c_out;
wire [7:0] hex_d_out;
wire [7:0] hex_e_out;
wire [7:0] hex_f_out;
wire [7:0] hex_g_out;
wire [7:0] hex_h_out;

wire [7:0] dec_a_out;
wire [7:0] dec_b_out;
wire [7:0] dec_c_out;
wire [7:0] dec_d_out;
wire [7:0] dec_e_out;
wire [7:0] dec_f_out;
wire [7:0] dec_g_out;
wire [7:0] dec_h_out;

seg7decoder hex_a_decoder (.a(left_value[15:12]),  .minus(1'b0), .blank(hex_blank_mask[7]), .out(hex_a_out), .sel());
seg7decoder hex_b_decoder (.a(left_value[11:8]),   .minus(1'b0), .blank(hex_blank_mask[6]), .out(hex_b_out), .sel());
seg7decoder hex_c_decoder (.a(left_value[7:4]),    .minus(1'b0), .blank(hex_blank_mask[5]), .out(hex_c_out), .sel());
seg7decoder hex_d_decoder (.a(left_value[3:0]),    .minus(1'b0), .blank(hex_blank_mask[4]), .out(hex_d_out), .sel());
seg7decoder hex_e_decoder (.a(right_value[15:12]), .minus(1'b0), .blank(hex_blank_mask[3]), .out(hex_e_out), .sel());
seg7decoder hex_f_decoder (.a(right_value[11:8]),  .minus(1'b0), .blank(hex_blank_mask[2]), .out(hex_f_out), .sel());
seg7decoder hex_g_decoder (.a(right_value[7:4]),   .minus(1'b0), .blank(hex_blank_mask[1]), .out(hex_g_out), .sel());
seg7decoder hex_h_decoder (.a(right_value[3:0]),   .minus(1'b0), .blank(hex_blank_mask[0]), .out(hex_h_out), .sel());

seg7decoder dec_a_decoder (.a(input_decimal_digits[31:28]), .minus(input_decimal_minus[7]), .blank(input_decimal_blank[7]), .out(dec_a_out), .sel());
seg7decoder dec_b_decoder (.a(input_decimal_digits[27:24]), .minus(input_decimal_minus[6]), .blank(input_decimal_blank[6]), .out(dec_b_out), .sel());
seg7decoder dec_c_decoder (.a(input_decimal_digits[23:20]), .minus(input_decimal_minus[5]), .blank(input_decimal_blank[5]), .out(dec_c_out), .sel());
seg7decoder dec_d_decoder (.a(input_decimal_digits[19:16]), .minus(input_decimal_minus[4]), .blank(input_decimal_blank[4]), .out(dec_d_out), .sel());
seg7decoder dec_e_decoder (.a(input_decimal_digits[15:12]), .minus(input_decimal_minus[3]), .blank(input_decimal_blank[3]), .out(dec_e_out), .sel());
seg7decoder dec_f_decoder (.a(input_decimal_digits[11:8]),  .minus(input_decimal_minus[2]), .blank(input_decimal_blank[2]), .out(dec_f_out), .sel());
seg7decoder dec_g_decoder (.a(input_decimal_digits[7:4]),   .minus(input_decimal_minus[1]), .blank(input_decimal_blank[1]), .out(dec_g_out), .sel());
seg7decoder dec_h_decoder (.a(input_decimal_digits[3:0]),   .minus(input_decimal_minus[0]), .blank(input_decimal_blank[0]), .out(dec_h_out), .sel());

assign seg_a_out = show_input_row ? dec_a_out : hex_a_out;
assign seg_b_out = show_input_row ? dec_b_out : hex_b_out;
assign seg_c_out = show_input_row ? dec_c_out : hex_c_out;
assign seg_d_out = show_input_row ? dec_d_out : hex_d_out;
assign seg_e_out = show_input_row ? dec_e_out : hex_e_out;
assign seg_f_out = show_input_row ? dec_f_out : hex_f_out;
assign seg_g_out = show_input_row ? dec_g_out : hex_g_out;
assign seg_h_out = show_input_row ? dec_h_out : hex_h_out;

assign seg_sel[7:0] = blank_row ? 8'b0000_0000 : (8'b0000_0001 << row_idx);
assign seg_sel[8] = 1'b0;

endmodule
