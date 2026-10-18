module processor_top(
    input clk,sel_clk, rst, exec,
    input [15:0] external_input,
    input input_enter,
    output [15:0] external_output,
    output wait_for_input,
    //デバッグ用出力
    output [15:0] data_reg_0,
    output [15:0] data_reg_1,
    output [15:0] data_reg_2,
    output [15:0] data_reg_3,
    output [15:0] data_reg_4,
    output [15:0] data_reg_5,
    output [15:0] data_reg_6,
    output [15:0] data_reg_7,
	output [15:0] debug_data_from_i_main_memory,
    output [15:0] debug_data_from_d_main_memory,
    output [4:0] debug_phase,
    output [15:0] debug_pc,
    output [3:0] debug_szcv,
    //7セグ表示用
    output [7:0] seg_a_out,
    output [7:0] seg_b_out,
    output [7:0] seg_c_out,
    output [7:0] seg_d_out,
    output [7:0] seg_e_out,
    output [7:0] seg_f_out,
    output [7:0] seg_g_out,
    output [7:0] seg_h_out,
    output [7:0] seg_sel
    //ここまで
);

//命令主記憶装置用データバス
wire [15:0] i_data_bus;
wire [15:0] i_address_bus;

//データ用主記憶装置用データバス
wire [15:0] d_data_bus;
wire [15:0] d_address_bus;

//common control signals
wire reg_file_write_enable; //レジスタファイルへの書き込みを制御する信号
wire mem_write_enable; //メインメモリへの書き込みを制御する信号
wire jump_enable; //分岐命令でジャンプするかどうかを制御する信号

//Phase Counter
wire p1, p2, p3, p4, p5;

//Main Memory
wire [15:0] data_from_i_main_memory; //メインメモリからのデータ出力;
wire [15:0] data_from_d_main_memory; //メインメモリからのデータ出力;

//PC counter
wire [15:0] pc_now; //現在のPCの値を出力するワイヤ
wire [15:0] pc_next; //次のPCの値を出力するワイヤ

//Output from IR(reg_input)
wire [1:0] op1;
wire [2:0] address_a, address_b, op2, cond;
wire [3:0] op3, dif4;
wire [7:0] dif8;

//Output from reg_file
wire [15:0] data_a_from_reg_file, data_b_from_reg_file;

//Input to reg_file
wire [2:0] address_write_to_reg_file; //書き込む先のアドレス

//Output from each Register (reg_a, reg_b)
wire [15:0] data_a_from_reg_a, data_b_from_reg_b;

//Output from ALU(decoder)
wire [15:0] alu_result;
wire [3:0] alu_szcv;

//Output from reg_output
wire [15:0] data_output_from_reg_output;

//Output from reg_szcv
wire [3:0] szcv_output_from_reg_szcv;

//Input to reg_memory
wire [15:0] data_to_reg_memory;

//Output from reg_memory
wire [15:0] data_from_reg_memory;

//Resturn values
wire [15:0] data; //reg_output/reg_memoryからの計算結果を格納するワイヤ


//Phase Counterのインスタンス化
phase_counter phase_counter_inst (
    .clk(clk),
    .rst(rst),
    .exec(exec),
    .input_enter(input_enter),
    .wait_for_input(wait_for_input),
    .p1(p1),
    .p2(p2),
    .p3(p3),
    .p4(p4),
    .p5(p5)
);

//命令用主記憶装置のインスタンス化

/*
main_memory #(
    .INIT_FILE("simple_inst.mif")  // 命令用のmifを指定
) i_main_memory_inst (
    .clk(clk),
    .write_enable(1'b0),
    .address_bus(i_address_bus),
    .data_input(16'h0000),
    .data_output(data_from_i_main_memory)
);
*/

inst_main_memory inst_main_memory_inst (
    .clock(~clk),
    .address(i_address_bus[13:0]),
    .data(16'h0000),  
    .wren(1'b0),
    .q(data_from_i_main_memory)
);

//データ用主記憶装置のインスタンス化

/*
main_memory #(
    .INIT_FILE("simple_data.mif")  // データ用のmifを指定
) d_main_memory_inst (
    .clk(clk),
    .write_enable(mem_write_enable),
    .address_bus(d_address_bus),
    .data_input(d_data_bus),
    .data_output(data_from_d_main_memory)
);
*/

data_main_memory data_main_memory_inst (
    .clock(~clk),
    .address(d_address_bus[13:0]),
    .data(d_data_bus),  
    .wren(mem_write_enable),
    .q(data_from_d_main_memory)
);


//Phase 1: Instruction Fetch
PC pc_inst (
    .clk(clk),
    .rst(rst),
    .jump_enable(jump_enable), //分岐命令でジャンプするかどうかを制御する信号
    .p1(p1), //Phase 1でPCを更新するための信号
    .p5(p5), //Phase 5でPCを更新するための信号
    .pc_input(data), //分岐先アドレス
    .pc_output(pc_next) //PCの値をアドレスバスに出力
    //**PCの出力を現在と次のに分けなければならない**//
);

reg_input reg_input_inst (
    .clk(clk),
    .rst(rst),
    .write_enable(p1), //Phase 1でレジスタファイルに命令を読み込むための信号
    .data_input(data_from_i_main_memory), //命令用メインメモリからの命令を入力
    .op1(op1), //命令のop1フィールドを出力
    .address_a(address_a), //命令のaddress_aフィールドを出力
    .address_b(address_b), //命令のaddress_bフィールドを出力
    .op2(op2), //命令のop2フィールドを出力
    .cond(cond), //命令のcondフィールドを出力
    .op3(op3), //命令のop3フィールドを出力
    .dif4(dif4), //命令のdif4フィールドを出力
    .dif8(dif8) //命令のdif8フィールドを出力
);


//Phase 2: Register Read
reg_file reg_file_inst (
    .clk(clk),
    .rst(rst),
    .write_enable(reg_file_write_enable), //Phase 5でレジスタファイルに計算結果を書き込むための信号
    .address_a(address_a), //reg_inputからのaddress_aを入力
    .address_b(address_b), //reg_inputからのaddress_bを入力
    .address_write(address_write_to_reg_file), //reg_inputからのaddress_aを入力
    .data_write(data), //calculatorからの計算結果を入力
    .data_a(data_a_from_reg_file), //レジスタファイルからのdata_aを出力
    .data_b(data_b_from_reg_file), //レジスタファイルからのdata_bを出力
    .data_reg_0(data_reg_0),
    .data_reg_1(data_reg_1),
    .data_reg_2(data_reg_2),
    .data_reg_3(data_reg_3),
    .data_reg_4(data_reg_4),
    .data_reg_5(data_reg_5),
    .data_reg_6(data_reg_6),
    .data_reg_7(data_reg_7)
);

wire [15:0] debug_r0 = data_reg_0;
wire [15:0] debug_r1 = data_reg_1;
wire [15:0] debug_r2 = data_reg_2;
wire [15:0] debug_r3 = data_reg_3;
wire [15:0] debug_r4 = data_reg_4;
wire [15:0] debug_r5 = data_reg_5;
wire [15:0] debug_r6 = data_reg_6;
wire [15:0] debug_r7 = data_reg_7;

reg_a reg_a_inst (
    .clk(clk),
    .rst(rst),
    .write_enable(p2), //Phase 2でreg_aにdata_a_from_reg_fileを書き込むための信号
    .data_a_in(data_a_from_reg_file), //reg_fileからのdata_aを入力
    .data_a_out(data_a_from_reg_a) //ALUに接続するための出力
);

reg_b reg_b_inst (
    .clk(clk),
    .rst(rst),
    .write_enable(p2), //Phase 2でreg_bにdata_b_from_reg_fileを書き込むための信号
    .data_b_in(data_b_from_reg_file), //reg_fileからのdata_bを入力
    .data_b_out(data_b_from_reg_b) //ALUに接続するための出力
);

//Phase 3: ALU Operation
decoder decoder_inst (
    .data_a(data_a_from_reg_a), //reg_aからのdata_aを入力
    .data_b(data_b_from_reg_b), //reg_bからのdata_bを入力
    .op1(op1), //reg_inputからのop1を入力
    .op2(op2), //reg_inputからのop2を入力
    .op3(op3), //reg_inputからのop3を入力
    .diff_4bit(dif4), //reg_inputからのdif4を入力
    .diff_8bit(dif8), //reg_inputからのdif8を入力
    .pc_in(pc_next), //PCの値を入力（分岐命令の計算に使用）
    .data_szcv_in(szcv_output_from_reg_szcv), //フラグレジスタからのSZCVフラグを入力
    .cond(cond), //reg_inputからのcondを入力
    .data_output(alu_result), //ALUの計算結果を出力
    .data_szcv_out(alu_szcv), //ALUの計算結果に基づくSZCVフラグを出力
    .jump_enable(jump_enable) //分岐命令でジャンプ可能かどうかを示すフラグを出力
);

reg_output reg_output_inst (
    .clk(clk),
    .rst(rst),
    .write_enable(p3), //Phase 3でreg_outputにALUの計算結果を書き込むための信号
    .data_output_in(alu_result), //ALUの計算結果を入力
    .data_output_out(data_output_from_reg_output) //外部出力に接続するための出力
);

wire szcv_write_enable = p3 && ((op1 == 2'b11) || (op1 == 2'b10 && (op2 == 3'b001 || op2 == 3'b010 || op2 == 3'b011 || op2 == 3'b101)));  //ALUのSZCVフラグをreg_szcvに書き込むための信号。ALUの計算結果が確定するPhase 3で、かつALUを使用する命令のときに有効になるようにする。

reg_szcv reg_szcv_inst (
    .clk(clk),
    .rst(rst),
    .write_enable(szcv_write_enable), //Phase 3でreg_szcvにALUのSZCVフラグを書き込むための信号
    .data_szcv_in(alu_szcv), //ALUのSZCVフラグを入力
    .data_szcv_out(szcv_output_from_reg_szcv) //フラグレジスタに接続するための出力
);

//Phase 4: Main Memory Write Back And External Input
reg_memory reg_memory_inst (
    .data_memory_in(data_to_reg_memory), //外部入力またはメモリからの入力
    .clk(clk),
    .rst(rst),
    .write_enable(p4), //Phase 4でMDRにデータを書き込むための信号
    .data_memory_out(data_from_reg_memory) //MDRからのデータを出力（必要に応じてdecoderに接続）
);


//Phase 5: Register Write Back And PC Update

assign reg_file_write_enable = p5 && ((op1 == 2'b00)  || (op1 == 2'b10 && ((op2 == 3'b000) || (op2 == 3'b001) || (op2 == 3'b010) || (op2 == 3'b101) || (op2 == 3'b110))) || (op1 == 2'b11 && (op3 == 4'b1100 || op3[3:2] != 2'b11) && op3 != 4'b0101)); //Phase 5でレジスタファイルに計算結果を書き込むための信号
assign data = ((op1 == 2'b00) || (op1 == 2'b11 && op3 == 4'b1100))  ? data_from_reg_memory : //LD命令のときはメインメモリからのデータをレジスタファイルに書き込むための入力
            data_output_from_reg_output; //それ以外の命令のときはALUの計算結果をレジスタファイルに書き込むための入力
            



//Assignements for buses and control signals
assign i_address_bus = pc_next; //命令用メモリに現在のPCを渡す

assign d_address_bus = (p3) ? alu_result : data_output_from_reg_output ; //DRの出力をデータ用メモリのアドレスに渡す。
assign d_data_bus = (p4 && op1 == 2'b01) ? data_a_from_reg_a : 16'h0000; //ストア命令用、データ用メモリにRAの中身を渡す


//外部出力
assign external_output_enable = (op1 ==  2'b11 && op3 == 4'b1101) ? 1 : 0; //OUT命令のときに外部出力を有効にする

reg [15:0] persistent_out_reg;

always @(posedge clk or negedge rst) begin
    if (~rst) begin
        persistent_out_reg <= 16'h0000;
    end else if (p3 && external_output_enable) begin
        // p3のタイミングで、確定した計算結果をラッチする
        persistent_out_reg <= data_a_from_reg_a; //OUT命令のときは、レジスタaの値を外部出力として保持する
    end
end
assign external_output = persistent_out_reg;


assign wait_for_input = (op1 == 2'b11 && op3 == 4'b1100);

assign data_to_reg_memory = (op1 == 2'b11 && op3 == 4'b1100) ? external_input : data_from_d_main_memory; //IN命令の時は外部入力、その他の時はメインメモリからのデータを保存

assign mem_write_enable = (p4 && op1 == 2'b01); //ST命令のときにメインメモリへの書き込みを有効にする信号

assign address_write_to_reg_file = (op1 == 2'b00 ) ? address_a : address_b; //算術演算のときはaddress_aを、即値ロード・条件分岐のときはaddress_bをレジスタファイルへの書き込み先アドレスとして使用

// processor_top.v の末尾 (endmoduleの直前) に追記
seg7_reg_display reg_display_inst (
    .clk(sel_clk),
    .rst(rst),
    .snapshot_toggle(p1),
    .pc_val(debug_pc),
    .cycle_count_val(32'd0),
    .input_val(external_input),

    // 外部ピンへの出力
    .seg_a_out(seg_a_out), .seg_b_out(seg_b_out),
    .seg_c_out(seg_c_out), .seg_d_out(seg_d_out),
    .seg_e_out(seg_e_out), .seg_f_out(seg_f_out),
    .seg_g_out(seg_g_out), .seg_h_out(seg_h_out),
    .seg_sel(seg_sel)
);

//デバッグ用配線   
assign debug_data_from_i_main_memory = data_from_i_main_memory;
assign debug_data_from_d_main_memory = data_from_d_main_memory;
assign debug_phase = {p1, p2, p3, p4, p5};
assign debug_pc = pc_next;
assign debug_szcv = alu_szcv;
endmodule



