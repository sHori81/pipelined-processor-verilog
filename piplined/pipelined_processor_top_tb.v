`timescale 1ns / 1ps

module pipelined_processor_top_tb;

    // 125MHz clock: 8ns period.
    // sel_clk: 50MHz clock: 20ns period.
    localparam CLK_HALF_NS = 4;
    localparam SEL_CLK_HALF_NS = 10;
    localparam INPUT_WAIT_CYCLES = 50;
    localparam INPUT_TIMEOUT_CYCLES = 200000;
    localparam EXEC_PULSE_NS = 2000;
    localparam ENTER_PULSE_NS = 100;
    localparam MAX_INPUTS = 256;

    reg clk;
    reg rst;
    reg exec;
    reg [12:0] keypad_keys;
    reg input_enter;
    reg sel_clk;

    wire [15:0] external_output;
    wire wait_for_input;

    wire [15:0] pc_output;

    wire [7:0] seg_a_out, seg_b_out, seg_c_out, seg_d_out, seg_e_out, seg_f_out, seg_g_out, seg_h_out;
    wire [8:0] seg_sel;
    wire [7:0] main_seg_a_out;
    wire [7:0] main_seg_b_out;
    wire [7:0] main_seg_sel;

    reg [15:0] input_values [0:MAX_INPUTS-1];
    reg [1023:0] input_file;
    integer input_count;
    integer input_index;

    top_module dut (
        .clk(clk),
        .sel_clk(sel_clk),
        .rst(rst),
        .exec(exec),
        .keypad_keys(keypad_keys),
        .input_enter(input_enter),
        .wait_for_input(wait_for_input),
        .main_seg_a_out(main_seg_a_out),
        .main_seg_b_out(main_seg_b_out),
        .main_seg_sel(main_seg_sel),
        .seg_a_out(seg_a_out), .seg_b_out(seg_b_out), .seg_c_out(seg_c_out), .seg_d_out(seg_d_out),
        .seg_e_out(seg_e_out), .seg_f_out(seg_f_out), .seg_g_out(seg_g_out), .seg_h_out(seg_h_out), .seg_sel(seg_sel)

    );

    assign external_output = dut.external_output_value;
    assign pc_output = dut.pc_output_value;

    always #CLK_HALF_NS clk = ~clk;
    always #SEL_CLK_HALF_NS sel_clk = ~sel_clk;

    task load_default_inputs;
    begin
        input_count = 3;
        input_values[0] = 16'd5;
        input_values[1] = 16'd11;
        input_values[2] = 16'd0;

    end
    endtask

    task load_inputs;
    begin
        load_default_inputs;

        if ($value$plusargs("INPUT_FILE=%s", input_file)) begin
            if (!$value$plusargs("INPUT_COUNT=%d", input_count)) begin
                $display("[%0t] ERROR: +INPUT_FILE needs +INPUT_COUNT.", $time);
                $finish;
            end

            if (input_count < 0 || input_count > MAX_INPUTS) begin
                $display("[%0t] ERROR: INPUT_COUNT=%0d is out of range 0..%0d.",
                         $time, input_count, MAX_INPUTS);
                $finish;
            end

            if (input_count > 0) begin
                $readmemh(input_file, input_values, 0, input_count - 1);
            end
            $display("[%0t] Loaded %0d inputs from %0s.", $time, input_count, input_file);
        end else begin
            $display("[%0t] Using default inputs embedded in the testbench.", $time);
        end
    end
    endtask

    task press_key;
        input integer key_index;
    begin
        keypad_keys[key_index] = 1'b0;
        repeat (20) @(posedge sel_clk);
        keypad_keys[key_index] = 1'b1;
        repeat (20) @(posedge sel_clk);
    end
    endtask

    task press_digit;
        input integer digit;
    begin
        case (digit)
            0: press_key(12);
            1: press_key(8);
            2: press_key(9);
            3: press_key(10);
            4: press_key(4);
            5: press_key(5);
            6: press_key(6);
            7: press_key(0);
            8: press_key(1);
            9: press_key(2);
            default: ;
        endcase
    end
    endtask

    task type_decimal_input;
        input [15:0] value;
        integer signed_value;
        integer magnitude;
        integer divisor;
        integer digit;
        integer started;
    begin
        press_key(7);

        signed_value = $signed(value);
        if (signed_value < 0) begin
            press_key(11);
            magnitude = -signed_value;
        end else begin
            magnitude = signed_value;
        end

        if (magnitude == 0) begin
            press_digit(0);
        end else begin
            divisor = 10000;
            started = 0;
            while (divisor > 0) begin
                digit = magnitude / divisor;
                if (digit != 0 || started != 0) begin
                    press_digit(digit);
                    started = 1;
                end
                magnitude = magnitude % divisor;
                divisor = divisor / 10;
            end
        end
    end
    endtask

    task pulse_exec;
    begin
        exec = 1'b0;
        #EXEC_PULSE_NS;
        exec = 1'b1;
        repeat (5) @(posedge clk);
        $display("[%0t] exec pulse done.", $time);
    end
    endtask

    task send_one_input;
        input [15:0] value;
        input integer index;
        integer wait_cycles;
    begin
        wait_cycles = 0;
        while (wait_for_input !== 1'b1 && wait_cycles < INPUT_TIMEOUT_CYCLES) begin
            @(posedge clk);
            wait_cycles = wait_cycles + 1;
        end

        if (wait_for_input !== 1'b1) begin
            $display("[%0t] ERROR: timeout waiting for wait_for_input before input[%0d]. pc=%0d",
                     $time, index, pc_output);
            $finish;
        end

        repeat (INPUT_WAIT_CYCLES) @(posedge clk);

        type_decimal_input(value);

        $display("[%0t] input[%0d] = %0d (0x%04h)", $time, index, value, value);
        input_enter = 1'b0;
        #ENTER_PULSE_NS;
        input_enter = 1'b1;

        wait_cycles = 0;
        while (wait_for_input !== 1'b0 && wait_cycles < INPUT_TIMEOUT_CYCLES) begin
            @(posedge clk);
            wait_cycles = wait_cycles + 1;
        end

        if (wait_for_input !== 1'b0) begin
            $display("[%0t] ERROR: timeout waiting for wait_for_input to clear after input[%0d]. pc=%0d",
                     $time, index, pc_output);
            $finish;
        end
    end
    endtask

    initial begin
        clk = 1'b0;
        rst = 1'b0;
        exec = 1'b1;
        input_enter = 1'b1;
        keypad_keys = 13'h1fff;

        load_inputs;

        #20 rst = 1'b1;
        repeat (5) @(posedge clk);

        pulse_exec;

        for (input_index = 0; input_index < input_count; input_index = input_index + 1) begin
            send_one_input(input_values[input_index], input_index);
        end

        repeat (250) @(posedge clk);
        $display("[%0t] finished. external_output=%0d (0x%04h), pc=%0d",
                 $time, external_output, external_output, pc_output);
        $finish;
    end

endmodule
