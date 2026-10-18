module top_module(
    input clk,
    input sel_clk,
    input rst,
    input exec,
    input [12:0] keypad_keys,
    input input_enter,
    output wait_for_input,
    output [7:0] main_seg_a_out,
    output [7:0] main_seg_b_out,
    output [7:0] main_seg_sel,
    output [7:0] seg_a_out,
    output [7:0] seg_b_out,
    output [7:0] seg_c_out,
    output [7:0] seg_d_out,
    output [7:0] seg_e_out,
    output [7:0] seg_f_out,
    output [7:0] seg_g_out,
    output [7:0] seg_h_out,
    output [8:0] seg_sel
);

wire [15:0] external_output_value;
wire [15:0] external_input_value;
wire [15:0] pc_output_value;
wire [31:0] cycle_count;


keypad_decimal_input keypad_input_inst (
    .clk(sel_clk),
    .rst(rst),
    .keys(keypad_keys),
    .value(external_input_value)
);

reg [14:0] display_snap_cnt;
reg        display_snap_toggle;
reg [15:0] external_output_snapshot;
reg [15:0] external_input_snapshot;
reg [15:0] pc_output_snapshot;
reg [31:0] cycle_count_snapshot;

always @(posedge clk or negedge rst) begin
    if (~rst) begin
        display_snap_cnt <= 15'd0;
        display_snap_toggle <= 1'b0;
        external_output_snapshot <= 16'd0;
        external_input_snapshot <= 16'd0;
        pc_output_snapshot <= 16'd0;
        cycle_count_snapshot <= 32'd0;
    end else begin
        display_snap_cnt <= display_snap_cnt + 1'b1;

        if (display_snap_cnt == 15'h7fff) begin
            display_snap_cnt <= 15'd0;
            display_snap_toggle <= ~display_snap_toggle;
            external_output_snapshot <= external_output_value;
            external_input_snapshot <= external_input_value;
            pc_output_snapshot <= pc_output_value;
            cycle_count_snapshot <= cycle_count;
        end
    end
end

pipelined_processor_top processor_inst (
    .clk_20m(clk),
    .rst_n(rst),
    .exec(exec),
    .external_input(external_input_value),
    .input_enter(input_enter),
    .external_output(external_output_value),
    .wait_for_input(wait_for_input),
    .pc_output(pc_output_value),
    .cycle_count(cycle_count)
);

seg7_reg_display reg_display_inst (
    .clk(sel_clk),
    .rst(rst),
    .snapshot_toggle(display_snap_toggle),
    .pc_val(pc_output_snapshot),
    .cycle_count_val(cycle_count_snapshot),
    .input_val(external_input_snapshot),
    .seg_a_out(seg_a_out),
    .seg_b_out(seg_b_out),
    .seg_c_out(seg_c_out),
    .seg_d_out(seg_d_out),
    .seg_e_out(seg_e_out),
    .seg_f_out(seg_f_out),
    .seg_g_out(seg_g_out),
    .seg_h_out(seg_h_out),
    .seg_sel(seg_sel)
);

main_seg_display out_display_inst (
    .clk(sel_clk),
    .rst(rst),
    .snapshot_toggle(display_snap_toggle),
    .data(external_output_snapshot),
    .seg_a_out(main_seg_a_out),
    .seg_b_out(main_seg_b_out),
    .seg_sel(main_seg_sel)
);

endmodule
