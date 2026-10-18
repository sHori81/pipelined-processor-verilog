module reg_output(
    input [15:0] data_output_in, // 16-bit input data from the control module
    input clk, // Clock signal for synchronizing data updates
    input rst, // Reset signal to clear the output register
    input write_enable, // Control signal to enable data updates
    output reg [15:0] data_output_out // 16-bit output data
);
    always @(posedge clk or negedge rst) begin
        if (!rst)
            data_output_out <= 16'h0000; // リセット時は0にクリア
        else if (write_enable)
            data_output_out <= data_output_in;
        else
            data_output_out <= data_output_out; // データを保持
    end
endmodule