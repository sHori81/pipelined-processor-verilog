module id (
    input [15:0] instruction,
    input clk, rst, flush, 
    input [15:0] write_back_data,
    input write_back_enable, //MEM/WB レジスタからの信号、レジスタファイルに書き込むための信号,
    input [2:0] write_back_address, //MEM/WB レジスタからの信号、レジスタファイルに書き込むときのアドレス
    input [15:0] pc_now, //PCの値を入力（分岐命令のときに使用）
    input [3:0] data_szcv_in, //EX/MEMレジスタからの信号、分岐命令の条件判定に使用するフラグ(S,Z,C,V)
    
    output [3:0] op3_output, //ALUとシフタの操作コード
    output sel_shifter,
    output [15:0] data_a, data_b, //ALUに入力するデータA,データB
    output [15:0] data_write_to_main_memory, //ストア命令でメインメモリに書き込むデータ
    output [3:0] diff_4bit, //即値演算のときの4ビットの即値

    output [15:0] pc_jump,
    output jump_enable,

    output [2:0] address_write_to_reg_file, //レジスタファイルに書き込むときのアドレス
    output reg_write_enable_output, is_st, is_alu, is_ld, is_in, is_out, is_halt,
    output szcv_update_enable,

    //フォワーディング処理
    input [15:0] forwarded_data_a, forwarded_data_b, 
    output [15:0] data_a_raw, data_b_raw, //フォワーディングユニットに送るための信号
    output [2:0] address_a_out, address_b_out, //フォワーディングユニットに送るための信号

    //動的分岐予測のための信号
    output is_branch //この命令が分岐命令かどうかを示すフラグ
    
);

    wire is_imm;
    wire is_cal;
    wire [15:0] data_a_from_reg_file, data_b_from_reg_file;
    
    wire [1:0] op1 = instruction[15:14];	
    wire [2:0] address_a = instruction[13:11];
    wire [2:0] op2 = instruction[13:11];
    wire [2:0] address_b = instruction[10:8];
    wire [2:0] cond = instruction[10:8];
    wire [3:0] op3 = instruction[7:4];
    wire [7:0] diff_8bit = instruction[7:0];
    assign diff_4bit = instruction[3:0];

    wire is_nop = (instruction == 16'h0000); // NOP命令の判定

    // --- 命令デコードフラグ ---
    assign is_st   = (op1 == 2'b01) && !is_nop;
    assign is_ld   = (op1 == 2'b00) && !is_nop;
    assign is_cal  = (op1 == 2'b11) && !is_nop; // ALU演算のときはop1が2'b11のとき。ただしNOP命令は除く。
    assign is_alu  = (is_cal && op3[3] == 1'b0) ; // ALU操作はop1が2'b11で、かつop3の最上位ビットが0のとき
    assign is_in   = (is_cal && op3 == 4'b1100); 
    assign is_out  = (is_cal && op3 == 4'b1101);
    assign is_halt = (is_cal && op3 == 4'b1111);

    // op1 == 2'b10 (即値ロード / 分岐形式) の拡張命令 
    wire is_li        = (op1 == 2'b10 && op2 == 3'b000); // LI 
    wire is_addi      = (op1 == 2'b10 && op2 == 3'b001); // ADDI
    wire is_subi      = (op1 == 2'b10 && op2 == 3'b010); // SUBI
    wire is_cmpi      = (op1 == 2'b10 && op2 == 3'b011); // CMPI
    wire is_andi      = (op1 == 2'b10 && op2 == 3'b101); // ANDI
    wire is_lui       = (op1 == 2'b10 && op2 == 3'b110); // LUI
    wire is_imm_arith = is_addi || is_subi || is_cmpi || is_andi;
    assign is_branch = (op1 == 2'b10 && (op2 == 3'b100 || op2 == 3'b111)); // 無条件/条件分岐
    assign szcv_update_enable = ((is_cal && !is_in && !is_out && !is_halt) || is_imm_arith) && !is_nop;
    
    
    assign reg_write_enable_output = (
        is_ld || is_li || is_lui || 
        (is_imm_arith && !is_cmpi) || 
        (is_cal && op3 != 4'b1101 && op3 != 4'b1111 && op3 != 4'b0101) // CMP/OUT/HALT以外の算術論理演算
    ) && (!is_nop); // NOP命令のときはレジスタファイルに書き込まない

    assign address_write_to_reg_file = (is_ld) ? address_a : address_b;
    
    reg_file reg_file_inst (
        .clk(clk),
        .rst(rst),
        .write_enable(write_back_enable), //レジスタファイルに命令を読み込むための信号
        .address_a(address_a), //命令のaddress_aフィールドを入力
        .address_b(address_b), //命令のaddress_bフィールドを入力
        .address_write(write_back_address), //レジスタファイルに書き込むときのアドレス
        .data_write(write_back_data), //ALUからの計算結果を入力（この段階ではまだ計算していないのでダミーの値）
        .data_a(data_a_from_reg_file), //レジスタファイルからのdata_aを出力
        .data_b(data_b_from_reg_file) //レジスタファイルからのdata_bを出力
    );


    assign data_a_raw = (write_back_enable && (write_back_address == address_a)) ? 
                        write_back_data : data_a_from_reg_file;

    assign data_b_raw = (write_back_enable && (write_back_address == address_b)) ? 
                        write_back_data : data_b_from_reg_file;
                        
    assign address_a_out = address_a;
    assign address_b_out = address_b;


    //ここから下は、decoderモジュールへの入力を生成するためのコード

    wire [15:0] diff_16bit_from_8bit = {{8{diff_8bit[7]}}, diff_8bit}; // 8-bit diffを16-bitに符号拡張
    wire [15:0] diff_16bit_upper = {diff_8bit, 8'h00};

    // op1に基づいて入力を選択
    assign data_a = 
        (is_lui) ? diff_16bit_upper : // LUI命令はupper 8-bitを用いる
        (is_cal) ? forwarded_data_a : // 演算のときはフォワーディングユニットからのデータを使用
        diff_16bit_from_8bit;

    assign data_b = 
            (is_li || is_lui) ? 16'd0 : // 即値ロード(LI/LUI)のときはdata_bを0にする
            forwarded_data_b;

    assign op3_output = 
        (is_cal)  ? op3 :      // 通常の ALU 演算 (op1=11)
        (is_addi) ? 4'b0000 :  // ADDI -> ADD (0000) 
        (is_subi) ? 4'b0001 :  // SUBI -> SUB (0001) 
        (is_cmpi) ? 4'b0101 :  // CMPI -> CMP (0101) 
        (is_andi) ? 4'b0010 :  // ANDI -> AND (0010) 
        (is_li || is_lui) ? 4'b0110 : // LI/LUI -> MOV (0110) 
        4'b0000;
        
    wire is_shift =
    is_cal &&
    (
        op3 == 4'b1000 ||
        op3 == 4'b1001 ||
        op3 == 4'b1010 ||
        op3 == 4'b1011
    );

    assign sel_shifter = is_shift;

    assign data_write_to_main_memory = (is_st) ? forwarded_data_a : 16'b0; //ストア命令のときはレジスタファイルからのdata_aをメインメモリに書き込むデータとして出力。それ以外のときは0を出力。


    //分岐命令の計算
    wire slt = data_szcv_in[3] ^ data_szcv_in[0]; // SLT命令のためのS^Vフラグ
    wire branch_met = (cond == 3'b000) ? data_szcv_in[2] :                       // BE (Z=1)
                    (cond == 3'b001) ? slt :    // BLT (S^V=1)
                    (cond == 3'b010) ? (data_szcv_in[2] || slt) : // BLE (Z|(S^V)=1)
                    (cond == 3'b011) ? (~data_szcv_in[2]) :                    // BNE (Z=0)
                    1'b0;
        
    assign jump_enable = (op1 == 2'b10 && op2 == 3'b111) ? branch_met: // 条件分岐命令で、条件が満たされている場合はジャンプを有効にする。
                        (op1 == 2'b10 && op2 == 3'b100) ? 1 : // 無条件分岐命令は常にジャンプを有効にする。
                        0; // それ以外の命令はジャンプを無効にする。

    assign pc_jump = pc_now + diff_16bit_from_8bit + 16'd1; // ジャンプ先のアドレスを計算（PC+1にdiffを加算）

endmodule
