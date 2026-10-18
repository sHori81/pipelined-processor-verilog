module signed_decimal_8digits (
    input  wire [15:0] value,
    output wire [31:0] digits,
    output wire [7:0]  minus_mask,
    output wire [7:0]  blank_mask
);

wire negative = value[15];
wire [15:0] magnitude = negative ? (~value + 16'd1) : value;
wire [19:0] bcd = bin_to_bcd5(magnitude);

wire [3:0] d0 = bcd[3:0];
wire [3:0] d1 = bcd[7:4];
wire [3:0] d2 = bcd[11:8];
wire [3:0] d3 = bcd[15:12];
wire [3:0] d4 = bcd[19:16];

wire [2:0] digit_count =
    (|d4) ? 3'd5 :
    (|d3) ? 3'd4 :
    (|d2) ? 3'd3 :
    (|d1) ? 3'd2 :
             3'd1;

assign digits = {12'h000, d4, d3, d2, d1, d0};

assign minus_mask = negative ? (8'b0000_0001 << digit_count) : 8'b0000_0000;

assign blank_mask[0] = 1'b0;
assign blank_mask[1] = (digit_count < 3'd2) && !minus_mask[1];
assign blank_mask[2] = (digit_count < 3'd3) && !minus_mask[2];
assign blank_mask[3] = (digit_count < 3'd4) && !minus_mask[3];
assign blank_mask[4] = (digit_count < 3'd5) && !minus_mask[4];
assign blank_mask[5] = !minus_mask[5];
assign blank_mask[6] = !minus_mask[6];
assign blank_mask[7] = !minus_mask[7];

function [19:0] bin_to_bcd5;
    input [15:0] bin;
    integer i;
    reg [35:0] shift;
    begin
        shift = 36'd0;
        shift[15:0] = bin;

        for (i = 0; i < 16; i = i + 1) begin
            if (shift[19:16] >= 4'd5) shift[19:16] = shift[19:16] + 4'd3;
            if (shift[23:20] >= 4'd5) shift[23:20] = shift[23:20] + 4'd3;
            if (shift[27:24] >= 4'd5) shift[27:24] = shift[27:24] + 4'd3;
            if (shift[31:28] >= 4'd5) shift[31:28] = shift[31:28] + 4'd3;
            if (shift[35:32] >= 4'd5) shift[35:32] = shift[35:32] + 4'd3;
            shift = shift << 1;
        end

        bin_to_bcd5 = shift[35:16];
    end
endfunction

endmodule
