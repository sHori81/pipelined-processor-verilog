module keypad_decimal_input (
    input clk,
    input rst,
    input [12:0] keys,
    output reg [15:0] value
);

`ifdef SYNTHESIS
    localparam [18:0] COOLDOWN_COUNT = 19'd400_000;
    localparam [20:0] KEY_DEBOUNCE_COUNT = 21'd400_000;
`else
    localparam [18:0] COOLDOWN_COUNT = 19'd10;
    localparam [20:0] KEY_DEBOUNCE_COUNT = 21'd10;
`endif

    wire [12:0] keys_clean;
    reg [12:0] keys_sync_0;
    reg [12:0] keys_sync_1;
    reg [12:0] keys_prev;
    reg [18:0] cooldown;

    reg [3:0] digit0;
    reg [3:0] digit1;
    reg [3:0] digit2;
    reg [3:0] digit3;
    reg [3:0] digit4;
    reg [2:0] digit_count;
    reg negative;

    wire [12:0] key_rise = keys_sync_1 & ~keys_prev;

    genvar key_index;
    generate
        for (key_index = 0; key_index < 13; key_index = key_index + 1) begin : key_debouncers
            debouncer #(
                .WAIT_COUNT(KEY_DEBOUNCE_COUNT)
            ) key_debouncer_inst (
                .clk(clk),
                .rst(rst),
                .btn_in(~keys[key_index]),
                .btn_out(keys_clean[key_index])
            );
        end
    endgenerate

    function [17:0] bcd_to_bin;
        input [3:0] d0;
        input [3:0] d1;
        input [3:0] d2;
        input [3:0] d3;
        input [3:0] d4;
        begin
            bcd_to_bin =
                {14'd0, d0} +
                ({14'd0, d1} << 3) + ({14'd0, d1} << 1) +
                ({14'd0, d2} << 6) + ({14'd0, d2} << 5) + ({14'd0, d2} << 2) +
                ({14'd0, d3} << 9) + ({14'd0, d3} << 8) + ({14'd0, d3} << 7) +
                ({14'd0, d3} << 6) + ({14'd0, d3} << 5) + ({14'd0, d3} << 3) +
                ({14'd0, d4} << 13) + ({14'd0, d4} << 10) + ({14'd0, d4} << 9) +
                ({14'd0, d4} << 8) + ({14'd0, d4} << 4);
        end
    endfunction

    function [15:0] signed_from_mag;
        input [17:0] mag;
        input neg;
        begin
            signed_from_mag = (neg && (mag != 18'd0)) ? (~mag[15:0] + 16'd1) : mag[15:0];
        end
    endfunction

    wire has_digit_key = key_rise[0] | key_rise[1] | key_rise[2] |
                         key_rise[4] | key_rise[5] | key_rise[6] |
                         key_rise[8] | key_rise[9] | key_rise[10] |
                         key_rise[12];

    wire [3:0] append_digit =
        key_rise[0]  ? 4'd7 :
        key_rise[1]  ? 4'd8 :
        key_rise[2]  ? 4'd9 :
        key_rise[4]  ? 4'd4 :
        key_rise[5]  ? 4'd5 :
        key_rise[6]  ? 4'd6 :
        key_rise[8]  ? 4'd1 :
        key_rise[9]  ? 4'd2 :
        key_rise[10] ? 4'd3 :
                       4'd0;

    wire [17:0] magnitude = bcd_to_bin(digit0, digit1, digit2, digit3, digit4);
    wire [17:0] append_magnitude = bcd_to_bin(append_digit, digit0, digit1, digit2, digit3);
    wire [17:0] delete_magnitude = bcd_to_bin(digit1, digit2, digit3, digit4, 4'd0);
    wire append_ok = (digit_count < 3'd5) &&
                     (negative ? (append_magnitude <= 18'd32768) :
                                 (append_magnitude <= 18'd32767));
    wire sign_toggle_ok = !(negative && (magnitude > 18'd32767));

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            keys_sync_0 <= 13'd0;
            keys_sync_1 <= 13'd0;
            keys_prev <= 13'd0;
        end else begin
            keys_sync_0 <= keys_clean;
            keys_sync_1 <= keys_sync_0;
            keys_prev <= keys_sync_1;
        end
    end

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            cooldown <= 19'd0;
            digit0 <= 4'd0;
            digit1 <= 4'd0;
            digit2 <= 4'd0;
            digit3 <= 4'd0;
            digit4 <= 4'd0;
            digit_count <= 3'd0;
            negative <= 1'b0;
            value <= 16'd0;
        end else begin
            if (cooldown != 19'd0) begin
                cooldown <= cooldown - 19'd1;
            end else if (|key_rise) begin
                cooldown <= COOLDOWN_COUNT;

                if (key_rise[7]) begin
                    digit0 <= 4'd0;
                    digit1 <= 4'd0;
                    digit2 <= 4'd0;
                    digit3 <= 4'd0;
                    digit4 <= 4'd0;
                    digit_count <= 3'd0;
                    negative <= 1'b0;
                    value <= 16'd0;
                end else if (key_rise[3]) begin
                    if (digit_count > 3'd1) begin
                        digit0 <= digit1;
                        digit1 <= digit2;
                        digit2 <= digit3;
                        digit3 <= digit4;
                        digit4 <= 4'd0;
                        digit_count <= digit_count - 3'd1;
                        value <= signed_from_mag(delete_magnitude, negative);
                    end else begin
                        digit0 <= 4'd0;
                        digit1 <= 4'd0;
                        digit2 <= 4'd0;
                        digit3 <= 4'd0;
                        digit4 <= 4'd0;
                        digit_count <= 3'd0;
                        negative <= 1'b0;
                        value <= 16'd0;
                    end
                end else if (key_rise[11]) begin
                    if (sign_toggle_ok) begin
                        negative <= ~negative;
                        value <= signed_from_mag(magnitude, ~negative);
                    end
                end else if (has_digit_key && append_ok) begin
                    digit0 <= append_digit;
                    digit1 <= digit0;
                    digit2 <= digit1;
                    digit3 <= digit2;
                    digit4 <= digit3;
                    digit_count <= digit_count + 3'd1;
                    value <= signed_from_mag(append_magnitude, negative);
                end
            end
        end
    end

endmodule
