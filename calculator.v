module calculator (
    input [15:0] data_a, data_b,// 16-bit inputs
    input [3:0] op3, // 4-bit operation code
    input sel_shifter, // シフタ選択信号    
    input [3:0] diff_4bit, // 4-bit shift amount for shifter
    output [15:0] data_output, // 16-bit result
    output [15:0] alu_pure_output, 
    output [3:0] data_szcv // 4-bit flags (S: Sign, Z: Zero, C: Carry, V: Overflow)
);
    wire [15:0] alu_output;
    wire [3:0] alu_szcv;
    wire [15:0] shifter_output;
    wire [3:0] shifter_szcv;

    // ALUとシフタのインスタンス化
    alu alu_inst (
        .data_a(data_a),
        .data_b(data_b),
        .op3(op3),
        .data_output(alu_output),
        .data_szcv(alu_szcv)
    );

    shifter shifter_inst (
        .data_b(data_b),
        .op3(op3),
        .diff(diff_4bit),
        .data_output(shifter_output),
        .data_szcv(shifter_szcv)
    );

    assign alu_pure_output = alu_output;

    // sel_shifterに基づいて出力を選択
    assign data_output = sel_shifter ? shifter_output : alu_output;
    assign data_szcv = sel_shifter ? shifter_szcv : alu_szcv;
endmodule