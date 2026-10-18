module reg_szcv(
    input [3:0] data_szcv_in, // 4-bit input flags (S: Sign, Z: Zero, C: Carry, V: Overflow)
    input clk, // Clock signal for synchronizing flag updates
    input rst, // Reset signal to clear flags
    input write_enable, // Control signal to enable flag updates
    output reg [3:0] data_szcv_out // 4-bit output flags (S: Sign, Z: Zero, C: Carry, V: Overflow)
);
    always @(posedge clk or negedge rst) begin
        if (!rst)
            data_szcv_out <= 4'b0000;
        else if (write_enable)
            data_szcv_out <= data_szcv_in;
        else
            data_szcv_out <= data_szcv_out; // フラグを保持
    end
endmodule