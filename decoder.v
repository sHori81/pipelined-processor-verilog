module decoder(
    input [15:0] data_a_input, data_b_input, // 16-bit inputs
    input [3:0] op3, // 4-bit operation code for ALU and shifter
    input [3:0] data_szcv_in, // 4-bit input flags (S: Sign, Z: Zero, C: Carry, V: Overflow)
    input [2:0] cond, // 3-bit condition code for conditional branch
    input sel_shifter, // 1-bit signal to select shifter operation
    output [15:0] data_output, // 16-bit result
    output [3:0] data_szcv_out, // 4-bit flags (S: Sign, Z: Zero, C: Carry, V: Overflow)
    output jump_enable //分岐命令でジャンプ可能かどうかを示すフラグ
);
    wire [3:0] op3_input;
    wire [15:0] diff_16bit_upper = {diff_8bit, 8'h00};
    wire [15:0] diff_16bit_from_8bit = {{8{diff_8bit[7]}}, diff_8bit}; // 8-bit diffを16-bitに符号拡張
    wire [15:0] diff_16bit_from_4bit = {{12{1'b0}}, diff_4bit}; // 4-bit diffを16-bitに符号拡張
    wire [15:0] calc_output;
    
    // op1に基づいて入力を選択
    assign data_a_input = (op1 == 2'b11) ? (op3[3]) ? diff_16bit_from_4bit : data_a : diff_16bit_from_8bit; // 算術演算の時はdata_aを使用。それ以外(シフト・ロードストア・条件分岐)の時はdiff_16bitを使用。
    
    assign data_b_input =   (op1 == 2'b10) ? (op2 == 3'b100 || op2 == 3'b111) ? pc_in : data_b : data_b; // 即値ロード・条件分岐の際、PC+1をdata_bに入力。それ以外は通常のdata_b

    assign op3_input =  (op1[1]== 0) ? 4'b0000 : // ロードストア用のALU操作コード(ベースレジスタと変位の加算)
                        (op1[0] == 1) ? op3 : // ALU用/シフタのop3
                        (op2 == 3'b001 || op2 == 3'b000) ? 4'b0000 :
                        (op2 == 3'b010 || op2 == 3'b011) ? 4'b0001 : 
                        (op2 == 3'b101) ? 4'b0010 :
                        (op2 == 3'b011) ? 4'b0000 :// 即値ロード、無条件分岐用のALU操作コード(すべて加算)
                        0; // デフォルトケース

    assign sel_shifter = (op1 == 2'b11 ) && (op3[3] == 1'b1) ? 1 : 0; // ALU用

    // calculatorモジュールのインスタンス化
    calculator calc_inst (
        .data_a(data_a_input),
        .data_b(data_b_input),
        .op3(op3),
        .sel_shifter(sel_shifter),
        .diff_4bit(diff_4bit),
        .data_output(data_output),
        .data_szcv(data_szcv_out)
    );

    wire slt = data_szcv_in[3] ^ data_szcv_in[0]; // SLT命令のためのS^Vフラグ
    wire branch_met = (cond == 3'b000) ? data_szcv_in[2] :                       // BE (Z=1)
                    (cond == 3'b001) ? slt :    // BLT (S^V=1)
                    (cond == 3'b010) ? (data_szcv_in[2] || slt) : // BLE (Z|(S^V)=1)
                    (cond == 3'b011) ? (~data_szcv_in[2]) :                    // BNE (Z=0)
                    1'b0;

    // data_outputの選択を整理
    assign data_output = 
        (op1 == 2'b10) ? (
            (op2 == 3'b111) ? (branch_met ? calc_output : pc_in) : // 条件分岐
            (op2 == 3'b110) ? diff_16bit_upper :                   // LUI命令 (上位8ビットを直接出力)
            (op2 == 3'b000) ? diff_16bit_from_8bit :               // 【追加】LI命令 (ALUをバイパスし、符号拡張即値を直接出力)
            calc_output                                            // ADDI, SUBI, CMPI, ANDI などの演算はALU結果を使う
        ) :
        (op3 == 4'b1100 || op3 == 4'b1101) ? data_a :              // IN/OUT
        calc_output;

    assign jump_enable = (op1 == 2'b10 && op2 == 3'b111) ? branch_met: // 条件分岐命令で、条件が満たされている場合はジャンプを有効にする。
                        (op1 == 2'b10 && op2 == 3'b100) ? 1 : // 無条件分岐命令は常にジャンプを有効にする。
                        0; // それ以外の命令はジャンプを無効にする。

endmodule