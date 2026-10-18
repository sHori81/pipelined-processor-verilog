module sort_performance_counter (
    input  wire        clk,
    input  wire        rst,
    input  wire        run_state,
    input  wire        halt,
    output reg  [31:0] cycle_count
);

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            cycle_count <= 32'd0;
        end else if (run_state && !halt) begin
            cycle_count <= cycle_count + 32'd1;
        end
    end

endmodule
