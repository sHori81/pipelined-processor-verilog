module alu (
    input [15:0] data_a, data_b,  // 16-bit inputs
    input [3:0] op3,     // 4-bit operation code
    output [15:0] data_output, // 16-bit result
    output [3:0] data_szcv   // 4-bit flags (S: Sign, Z: Zero, C: Carry, V: Overflow)
);
    assign data_output = (op3 == 4'b0000) ? data_b + data_a : // ADD
                         (op3 == 4'b0001) ? data_b - data_a : // SUB
                         (op3 == 4'b0010) ? data_b & data_a : // AND
                         (op3 == 4'b0011) ? data_b | data_a : // OR
                         (op3 == 4'b0100) ? data_b ^ data_a : // XOR
                         (op3 == 4'b0101) ? data_b - data_a : // CMP
                         (op3 == 4'b0110) ? data_a : // MOV
                         0; // Default case
    wire sign = data_output[15]; // Sign flag
    wire zero = (data_output == 16'b0); // Zero flag
    wire carry = (op3 == 4'b0000) ? (({1'b0, data_b} + {1'b0, data_a}) > 17'h0FFFF) : // Carry for ADD
                 (op3 == 4'b0001 || op3 == 4'b0101) ? (data_b < data_a) : // Carry for SUB
                 0; // No carry for other operations
    wire overflow = (op3 == 4'b0000) ? ((data_a[15] == data_b[15]) && (data_output[15] != data_a[15])) : // Overflow for ADD
                    (op3 == 4'b0001 || op3 == 4'b0101) ? ((data_a[15] != data_b[15]) && (data_output[15] == data_a[15])) : // Overflow for SUB
                    0; // No overflow for other operations

    assign data_szcv = {sign, zero, carry, overflow}; // Combine flags into szcv output
endmodule