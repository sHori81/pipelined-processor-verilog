module main_seg_display (
    input  wire        clk,
    input  wire        rst,
    input  wire [15:0] data,
    input  wire        snapshot_toggle,
    output wire [7:0]  seg_a_out,
    output wire [7:0]  seg_b_out,
    output wire [7:0]  seg_sel
);

localparam [14:0] BLANK_COUNT = 15'd200;
localparam [14:0] ON_COUNT = 15'd20_000;
localparam [14:0] PHASE_LAST = BLANK_COUNT + ON_COUNT - 15'd1;

reg [14:0] phase_cnt;
reg [2:0] digit_idx;
reg snapshot_toggle_sync0;
reg snapshot_toggle_sync1;
reg snapshot_toggle_seen;
reg snapshot_pending;
reg [15:0] data_shadow;

wire [2:0] physical_digit_idx = 3'd7 - digit_idx;
wire blank_digit = (phase_cnt < BLANK_COUNT);

wire [31:0] decimal_digits;
wire [7:0] decimal_minus;
wire [7:0] decimal_blank;

reg [3:0] digit_data;
reg       digit_minus;
reg       digit_blank;

signed_decimal_8digits decimal_inst (
    .value(data_shadow),
    .digits(decimal_digits),
    .minus_mask(decimal_minus),
    .blank_mask(decimal_blank)
);

always @(posedge clk or negedge rst) begin
    if (~rst) begin
        phase_cnt <= 15'd0;
        digit_idx <= 3'd0;
        snapshot_toggle_sync0 <= 1'b0;
        snapshot_toggle_sync1 <= 1'b0;
        snapshot_toggle_seen <= 1'b0;
        snapshot_pending <= 1'b0;
        data_shadow <= 16'd0;
    end else begin
        snapshot_toggle_sync0 <= snapshot_toggle;
        snapshot_toggle_sync1 <= snapshot_toggle_sync0;

        if (snapshot_toggle_sync1 != snapshot_toggle_seen) begin
            snapshot_pending <= 1'b1;
        end

        if (phase_cnt == PHASE_LAST) begin
            phase_cnt <= 15'd0;
            digit_idx <= digit_idx + 3'd1;
        end else begin
            phase_cnt <= phase_cnt + 15'd1;
        end

        if ((phase_cnt == 15'd0) && snapshot_pending) begin
            data_shadow <= data;
            snapshot_toggle_seen <= snapshot_toggle_sync1;
            snapshot_pending <= 1'b0;
        end
    end
end

always @(*) begin
    case (digit_idx)
        3'd0: digit_data = decimal_digits[3:0];
        3'd1: digit_data = decimal_digits[7:4];
        3'd2: digit_data = decimal_digits[11:8];
        3'd3: digit_data = decimal_digits[15:12];
        3'd4: digit_data = decimal_digits[19:16];
        3'd5: digit_data = decimal_digits[23:20];
        3'd6: digit_data = decimal_digits[27:24];
        default: digit_data = decimal_digits[31:28];
    endcase

    digit_minus = decimal_minus[digit_idx];
    digit_blank = decimal_blank[digit_idx];
end

wire [7:0] digit_seg;

seg7decoder digit_decoder (
    .a(digit_data),
    .minus(digit_minus),
    .blank(digit_blank),
    .out(digit_seg),
    .sel()
);

assign seg_a_out = (physical_digit_idx < 3'd4) ? digit_seg : 8'b0000_0000;
assign seg_b_out = (physical_digit_idx >= 3'd4) ? digit_seg : 8'b0000_0000;
assign seg_sel = blank_digit ? 8'b1111_1111 : ~(8'b0000_0001 << physical_digit_idx);

endmodule
