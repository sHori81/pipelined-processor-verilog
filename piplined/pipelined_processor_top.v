module pipelined_processor_top(
    input clk_20m, rst_n, exec,
    input [15:0] external_input,
    input input_enter,
    output [15:0] external_output,
    output wait_for_input,
    output [15:0] pc_output,
    output [31:0] cycle_count
);

//pll
wire clk;
wire pll_locked;


my_pll pll_inst (
    .inclk0(clk_20m),
    .areset(~rst_n),
    .c0(clk),
    .locked(pll_locked)
);


wire rst_async_n = rst_n & pll_locked;
reg [3:0] rst_release_sync;

always @(posedge clk or negedge rst_async_n) begin
    if (!rst_async_n) begin
        rst_release_sync <= 4'b0000;
    end else begin
        rst_release_sync <= {rst_release_sync[2:0], 1'b1};
    end
end

wire rst = rst_release_sync[3];

//信号の定義　
//制御信号
wire halt_draining;
wire exec_run_state; //プロセッサ全体の実行状態を保持する信号
wire flush; //分岐命令でジャンプするときにパイプラインをフラッシュするための信号
wire stall; //ハザード検出ユニットからのストール信号
wire run_state_pc   = exec_run_state && !stall && !halt_draining; //ストール時やハルトドレイン中はPCを更新しない
wire run_state_ifid = exec_run_state && !stall; // ストール時はIF/IDを保持
wire run_state_if   = exec_run_state && !stall; // ストール時はBRAMからの読み出しも保持
wire run_state_idex = exec_run_state; //IDEXレジスタを更新するかどうかを制御する信号
wire run_state_exmem = exec_run_state; //EXMEMレジスタを更新するかどうかを制御する信号
wire run_state_memwb = exec_run_state; //MEMWBレジスタを更新するかどうかを制御する信号

//IF段で使う信号
wire [15:0] instruction_address_bus; //命令用主記憶装置のアドレスバス
wire [15:0] data_from_instruction_memory; //命令用主記憶装置からのデータ出力
wire [15:0] pc_now; //IF段のPCの値を出力するワイヤ
wire [15:0] pc_in; //PCに入力する値を決定するワイヤ
wire [15:0] pc_if; //IF段のPCの値をID段に渡すワイヤ
wire valid_if; //IF段の命令が有効かどうかを示すワイヤ

reg pred_en_if;
reg [15:0] pred_pc_if;



//ID段で使う信号
wire [15:0] instruction_id; 
wire [15:0] write_back_data;
wire write_back_enable;
wire [2:0] write_back_address;
wire valid_id;

wire [3:0] op3_id;
wire [15:0] data_a_id, data_b_id;
wire [2:0] address_write_to_reg_file_id;
wire reg_write_enable_id, is_st_id, is_alu_id, is_ld_id, is_in_id, is_out_id, is_halt_id;
wire szcv_update_enable_id;
wire sel_shifter_id;
wire [3:0] diff_4bit_id;
wire [15:0] data_write_to_main_memory_id;

wire jump_enable_id; //ID段で分岐命令の条件が満たされているかどうかを示すフラグ
wire [15:0] pc_id;
wire [15:0] pc_jump_id; //ID段で計算されたジャンプ先アドレス

//フォワーディング処理用
wire [2:0] address_a_id, address_b_id;
wire [15:0] data_a_raw_id, data_b_raw_id;
wire [15:0] forwarded_data_a_id, forwarded_data_b_id;

//外部出力のための信号
wire [2:0] sel_out_id; 

//動的分岐予測のための信号
wire is_branch_id; // id_inst から受け取る
wire pred_en_id;
wire misprediction; //予測が外れたときに1になるフラグ
wire [15:0] pred_pc_id;


//EX段で使う信号
wire [15:0] data_a_ex, data_b_ex;
wire [2:0] address_write_to_reg_file_ex;
wire [3:0] op3_ex;
wire reg_write_enable_ex, is_st_ex, is_alu_ex, is_ld_ex, is_in_ex, is_out_ex, is_halt_ex;
wire szcv_update_enable_ex;
wire sel_shifter_ex;
wire [3:0] diff_4bit_ex;
wire [15:0] data_write_to_main_memory_ex;

wire [15:0] alu_result_ex;
wire [3:0] alu_szcv_ex;
wire [15:0] alu_pure_result_ex; 

//外部出力
wire [2:0] sel_out_ex;
reg [2:0] persistent_sel_out;
reg [15:0] persistent_external_output;

//MEM段で使う信号
wire [15:0] alu_result_mem;
wire [3:0] alu_szcv_mem;
wire [2:0] address_write_to_reg_file_mem;
wire is_st_mem, is_ld_mem, is_in_mem, is_halt_mem, reg_write_enable_mem;
wire [15:0] data_write_to_main_memory_mem;
wire [15:0] data_from_data_memory;
wire [15:0] datamem_address_bus; //データ用主記憶装置のアドレスバス
wire [15:0] memory_data_mem; //メインメモリからのデータを一時的に保持するワイヤ;

//WB部分で使う信号
wire [15:0] alu_result_wb; 
wire [15:0] memory_data_wb;
wire is_ld_wb, is_in_wb, is_halt_wb, reg_write_enable_wb;

// HALT制御
// HLTをID段で見つけたら、それ以降の若い命令を殺しつつ、
// HLT自身はWB段まで流してからrun_state_moduleで停止させる。
wire halt_request = valid_id && is_halt_id;
wire halt_commit  = is_halt_wb;

reg halt_pending;

always @(posedge clk or negedge rst) begin
    if (!rst) begin
        halt_pending <= 1'b0;
    end else if (halt_commit) begin
        halt_pending <= 1'b0;
    end else if (halt_request) begin
        halt_pending <= 1'b1;
    end
end

assign halt_draining = halt_pending | halt_request;


// --- 物理ボタンのチャタリング防止 ＆ 同期化 ---
wire exec_pressed;
wire input_enter_pressed;
reg exec_pressed_prev;
reg input_enter_pressed_prev;

debouncer debouncer_exec (
    .clk(clk),
    .rst(rst),
    .btn_in(~exec),
    .btn_out(exec_pressed)
);

debouncer debouncer_enter (
    .clk(clk),
    .rst(rst),
    .btn_in(~input_enter),
    .btn_out(input_enter_pressed)
);

always @(posedge clk or negedge rst) begin
    if (!rst) begin
        exec_pressed_prev <= 1'b0;
        input_enter_pressed_prev <= 1'b0;
    end else begin
        exec_pressed_prev <= exec_pressed;
        input_enter_pressed_prev <= input_enter_pressed;
    end
end

wire exec_pulse = exec_pressed & ~exec_pressed_prev;
wire input_enter_pulse = input_enter_pressed & ~input_enter_pressed_prev;

// --- 制御部分 ---
run_state_module run_state_module_inst(
    .clk(clk),
    .rst(rst),
    .exec(exec_pulse),
    .wait_for_input(wait_for_input),
    .input_enter(input_enter_pulse),
    .is_halt(is_halt_wb),
    .run_state(exec_run_state)
);

assign wait_for_input = is_in_ex || (valid_id && is_in_id); // EX段または有効なID段のIN命令で外部入力待ち


//IF部分
pipelined_pc pipelined_pc_inst(
    .clk(clk),
    .rst(rst),
    .run_state(run_state_pc), //プロセッサが実行状態のときにPCを更新する
    .pc_input(pc_in), //EX段からのジャンプ先アドレスをPCに入力
    .pc_output(pc_now) 
);

assign instruction_address_bus = pc_now; //命令用主記憶装置のアドレスバスにIF段のPCの値を接続

//命令用主記憶装置のインスタンス化

/*
main_memory #(
    .INIT_FILE("simple_inst.hex")  // 命令用のhexファイルを指定
) instruction_memory_inst (
    .clk(clk),
    .write_enable(1'b0),
    .read_enable(run_state_if),
    .address_bus(instruction_address_bus),
    .data_input(16'h0000),
    .data_output(data_from_instruction_memory)
);
*/


inst_main_memory inst_main_memory_inst (
    .clock(clk),
    .address(instruction_address_bus[13:0]),
    .data(16'h0000),
    .addressstall(!run_state_if),
    .wren(1'b0),
    .q(data_from_instruction_memory)
);


wire fetch_valid_input = exec_run_state && !misprediction && !halt_draining;

reg_if reg_if_inst(
    .clk(clk),
    .rst(rst),
    .write_enable(run_state_if),

    .pc_input(pc_now),
    .valid_input(fetch_valid_input),

    .pc_output(pc_if),
    .valid_output(valid_if)
);

// 1. 予測器のインスタンス化 (IF段で PC に基づいて予測)
wire pred_jump_en;
wire [15:0] pred_jump_addr;

predictor branch_predictor(
    .clk(clk),
    .rst(rst),

    .PC_input(pc_now),
    .jump_enable(pred_jump_en),
    .jump_address(pred_jump_addr),

    .update_enable(exec_run_state),
    .PC_update(pc_id),
    .branch_order(valid_id && !stall && is_branch_id),
    .actual_address(pc_jump_id),
    .actual_jump(jump_enable_id)
);

// 2. 予測に基づく IF1段での次のPC候補
wire [15:0] pc_next = pc_now + 16'd1;
wire [15:0] pc_id_next = pc_id + 16'd1;

wire [15:0] pc_predicted = pred_jump_en ? pred_jump_addr : pc_next;
wire [15:0] pc_recovery  = jump_enable_id ? pc_jump_id : pc_id_next;


// --- (IF2段への予測の遅延伝搬) ---
// BRAMの遅延(reg_if)に合わせて、予測結果も1クロック遅らせる

always @(posedge clk or negedge rst) begin
    if (!rst) begin 
        pred_en_if <= 1'b0; 
        pred_pc_if <= 16'b0; 
    end else if (run_state_if) begin 
        if (misprediction || halt_draining) begin
            pred_en_if <= 1'b0;
            pred_pc_if <= 16'd0;
        end else begin
            pred_en_if <= pred_jump_en;
            pred_pc_if <= pred_jump_addr;
        end
    end
end

// --- ハザード検出ユニット (HDU) ---
wire hazard_detected;
hazard_detection hdu_inst(
    .is_ld_ex(is_ld_ex),                             // EX段の命令がLDか
    .is_in_ex(is_in_ex),                             // EX段の命令がINか
    .szcv_update_enable_ex(szcv_update_enable_ex),
    .ex_dest_addr(address_write_to_reg_file_ex),     // EX段が書き込むレジスタ
    .instruction_id(instruction_id),                 // ID段の命令
    .hazard_detected(hazard_detected)                // 検知フラグ
);

// ストール信号（ハザードを検知したら全体のパイプラインを止める）
assign stall = valid_id && hazard_detected;

//IFIDレジスタ
wire flush_ifid; //IF/IDレジスタをフラッシュする信号
wire ifid_valid_input = valid_if && !flush_ifid && !halt_draining;

reg_ifid reg_ifid_inst(
    .clk(clk),
    .rst(rst),
    .write_enable(run_state_ifid),

    .ir_input(data_from_instruction_memory),
    .pc_input(pc_if),
    .valid_input(ifid_valid_input),

    .pred_en_input(pred_en_if),
    .pred_pc_input(pred_pc_if),

    .ir_output(instruction_id),
    .pc_output(pc_id),
    .valid_output(valid_id),

    .pred_en_output(pred_en_id),
    .pred_pc_output(pred_pc_id)
);


// 4. ID段での「ミスプレディクション（予測外し）」判定
// クロック立ち上がり直後の早い信号だけで、先に必要な差分を引き算しておく

// 遅れて届く命令から即値を切り出す
wire pred_addr_ok = (pred_pc_id == pc_jump_id);

// tagなしpredictorでは、非分岐命令に対して predicted taken することがある。
// この場合、PCと若い命令は回復する必要があるが、
// 現在ID段にいる非分岐命令そのものは実行させる必要がある。
wire nonbranch_prediction_miss =
    valid_id && !stall && pred_en_id && !is_branch_id;

// ID段の命令が分岐命令だった場合の通常の予測ミス。
// 分岐命令自体は副作用を持たないので、ID/EXでbubble化してよい。
wire branch_prediction_miss =
    valid_id && !stall && is_branch_id && (
        (pred_en_id != jump_enable_id) ||
        (jump_enable_id && pred_en_id && !pred_addr_ok)
    );

assign misprediction =
    nonbranch_prediction_miss || branch_prediction_miss;


// 5. 最終的な PC の入力値とフラッシュ制御
// 予測が外れた時だけ PC を正しい値で強制上書きし、IF/IDをフラッシュする

assign pc_in = misprediction ? pc_recovery : pc_predicted;

reg flush_delay;
always @(posedge clk or negedge rst) begin
    if (!rst) flush_delay <= 1'b0;
    else if (exec_run_state && !stall) flush_delay <= misprediction;
end

// IF/IDは、ミスした瞬間と、その次のクロックの「2回」フラッシュして幽霊命令を消し去る
assign flush_ifid = misprediction | flush_delay | halt_draining;  

// ID/EX以降は、今ID段にいる命令だけを消せばいいので引き延ばさない
assign flush = 1'b0; // branch miss only redirects PC and flushes IF/ID

//ID部分
id id_inst(
    .instruction(instruction_id),
    .clk(clk),
    .rst(rst),
    .flush(1'b0),
    .write_back_data(write_back_data), //MEMWBレジスタからの書き戻しデータ入力
    .write_back_enable(write_back_enable), //MEMWBレジスタからの書き戻し有効信号入力
    .write_back_address(write_back_address), //MEMWBレジスタからの書き戻し先アドレス入力

    .data_a(data_a_id),
    .data_b(data_b_id),
    .op3_output(op3_id),
    .sel_shifter(sel_shifter_id),
    .data_write_to_main_memory(data_write_to_main_memory_id), //ストア命令でメインメモリに書き込むデータを出力
    .diff_4bit(diff_4bit_id), //即値演算のときの4ビットの即値を出力

    .pc_now(pc_id),
    .jump_enable(jump_enable_id),
    .pc_jump(pc_jump_id),
    .data_szcv_in(alu_szcv_mem), //MEM段からのフラグを入力

    .address_write_to_reg_file(address_write_to_reg_file_id), //レジスタファイルに書き込むときのアドレス出力
    .reg_write_enable_output(reg_write_enable_id), //レジスタファイルに書き込むときの有効信号出力
    .is_st(is_st_id), //ST命令かどうかを出力
    .is_alu(is_alu_id), //ALUを使う命令かどうかを出力
    .is_ld(is_ld_id), //LD命令かどうかを出力
    .is_in(is_in_id), //IN命令かどうかを出力
    .is_out(is_out_id), //OUT命令かどうかを出力
    .is_halt(is_halt_id), //HALT命令かどうかを出力
    .szcv_update_enable(szcv_update_enable_id),

    //フォワーディング処理
    .address_a_out(address_a_id), //フォワーディングユニットに送るためのアドレス信号
    .address_b_out(address_b_id), //フォワーディングユニットに送るためのアドレス信号
    .data_a_raw(data_a_raw_id), //フォワーディングユニットに送るためのデータ信号
    .data_b_raw(data_b_raw_id), //フォワーディングユニットに送るためのデータ信号
    .forwarded_data_a(forwarded_data_a_id), //フォワーディングユニットからのデータ信号
    .forwarded_data_b(forwarded_data_b_id), //フォワーディングユニットからのデータ信号

    .is_branch(is_branch_id) //この命令が分岐命令かどうかを示すフラグ
);


//IDEXレジスタ
reg_idex reg_idex_inst(
    .clk(clk),
    .rst(rst),
    .flush(stall | !valid_id), // hazard or invalid ID stage inserts a bubble
    .write_enable(run_state_idex),
    .reg_write_enable_input(reg_write_enable_id),
    .is_st_input(is_st_id),
    .is_alu_input(is_alu_id),
    .is_ld_input(is_ld_id),
    .is_in_input(is_in_id),
    .is_out_input(is_out_id),
    .is_halt_input(is_halt_id),
    .szcv_update_enable_input(szcv_update_enable_id),
    .sel_shifter_input(sel_shifter_id),
    .op3_input(op3_id),
    .data_a_input(data_a_id),
    .data_b_input(data_b_id),
    .address_write_to_reg_file_input(address_write_to_reg_file_id),
    .data_write_to_main_memory_input(data_write_to_main_memory_id),
    .diff_4bit_input(diff_4bit_id),
    .sel_out_input(sel_out_id),
    .reg_write_enable_output(reg_write_enable_ex),
    .is_st_output(is_st_ex),
    .is_alu_output(is_alu_ex),
    .is_ld_output(is_ld_ex),
    .is_in_output(is_in_ex),
    .is_out_output(is_out_ex),
    .is_halt_output(is_halt_ex),
    .szcv_update_enable_output(szcv_update_enable_ex),
    .sel_shifter_output(sel_shifter_ex),
    .op3_output(op3_ex),
    .data_a_output(data_a_ex),
    .data_b_output(data_b_ex),
    .address_write_to_reg_file_output(address_write_to_reg_file_ex),
    .data_write_to_main_memory_output(data_write_to_main_memory_ex),
    .diff_4bit_output(diff_4bit_ex),
    .sel_out_output(sel_out_ex)
);

//EX部分
calculator calculator_inst(
    .data_a(data_a_ex),
    .data_b(data_b_ex),
    .op3(op3_ex),
    .diff_4bit(diff_4bit_ex),
    .sel_shifter(sel_shifter_ex),
    .alu_pure_output(alu_pure_result_ex),
    .data_output(alu_result_ex),
    .data_szcv(alu_szcv_ex)
);


//外部出力
always @(posedge clk or negedge rst) begin
    if (!rst) begin
        persistent_external_output <= 16'b0;
    end else if (is_out_ex) begin
        persistent_external_output <= data_a_ex; //OUT命令のときはdata_a_exを外部出力として保存
    end
end
assign external_output = persistent_external_output;


//EX/MEMレジスタ
reg_exmem reg_exmem_inst(
    .clk(clk),
    .rst(rst),
    .flush(1'b0), 
    .write_enable(run_state_exmem),
    .reg_write_enable_input(reg_write_enable_ex),
    .is_st_input(is_st_ex),
    .is_ld_input(is_ld_ex),
    .is_in_input(is_in_ex),
    .is_halt_input(is_halt_ex),
    .szcv_update_enable_input(szcv_update_enable_ex),
    .alu_result_input(alu_result_ex),
    .alu_szcv_input(alu_szcv_ex),
    .address_write_to_reg_file_input(address_write_to_reg_file_ex),
    .data_write_to_main_memory_input(data_write_to_main_memory_ex),

    .reg_write_enable_output(reg_write_enable_mem),
    .is_st_output(is_st_mem),
    .is_ld_output(is_ld_mem),
    .is_in_output(is_in_mem),
    .is_halt_output(is_halt_mem),
    .alu_result_output(alu_result_mem),
    .alu_szcv_output(alu_szcv_mem),
    .address_write_to_reg_file_output(address_write_to_reg_file_mem),
    .data_write_to_main_memory_output(data_write_to_main_memory_mem)
);

//MEM部分
assign datamem_address_bus = data_b_ex + data_a_ex;
wire dmem_wren = rst && exec_run_state && is_st_ex;

//データ用主記憶装置のインスタンス化

/*
main_memory #(
    .INIT_FILE("simple_data.hex")  // データ用のhexファイルを指定
) data_memory_inst (
    .clk(clk),
    .write_enable(is_st_ex), //ST命令のときに書き込みを有効にする
    .read_enable(1'b1),
    .address_bus(datamem_address_bus),
    .data_input(data_write_to_main_memory_ex),
    .data_output(data_from_data_memory)
);
*/


data_main_memory data_main_memory_inst (
    .clock(clk),
    .address(datamem_address_bus[13:0]),
    .data(data_write_to_main_memory_ex),  
    .wren(dmem_wren),
    .q(data_from_data_memory)
);



assign memory_data_mem = (is_in_mem) ? external_input : data_from_data_memory; //IN命令のときは外部入力をメインメモリからのデータとして扱う。



//MEM/WBレジスタ

reg_memwb memwb_inst(
    .clk(clk),
    .rst(rst),
    .flush(1'b0),
    .write_enable(run_state_memwb),
    .reg_write_enable_input(reg_write_enable_mem),
    .is_ld_input(is_ld_mem),
    .is_in_input(is_in_mem),
    .is_halt_input(is_halt_mem),
    .alu_result_input(alu_result_mem),
    .memory_data_input(memory_data_mem),
    .address_write_to_reg_file_input(address_write_to_reg_file_mem),

    .reg_write_enable_output(reg_write_enable_wb),
    .is_ld_output(is_ld_wb),
    .is_in_output(is_in_wb),
    .is_halt_output(is_halt_wb),
    .address_write_to_reg_file_output(write_back_address),
    .alu_result_output(alu_result_wb),
    .memory_data_output(memory_data_wb)
);

assign write_back_data = (is_ld_wb || is_in_wb) ? memory_data_wb : alu_result_wb; //レジスタファイルに書き込むデータ。LD命令またはIN命令のときはメインメモリからのデータ、それ以外のときはALUの計算結果をレジスタファイルに書き込む。
assign write_back_enable = reg_write_enable_wb; //レジスタファイルに書き込むときの有効信号はMEM/WBレジスタから出力されるreg_write_enable_wbを使用する。



//Forwarding Unit
wire [15:0] mem_result_for_fwd = (is_ld_mem || is_in_mem) ? memory_data_mem : alu_result_mem;

forwarding_unit fwd_unit_inst (
    .address_a(address_a_id),
    .address_b(address_b_id),
    .data_a_raw(data_a_raw_id),
    .data_b_raw(data_b_raw_id),

    // EX段からのフィードバック (1クロック前) [cite: 53]
    .ex_reg_write_en(reg_write_enable_ex),
    .ex_dest_addr(address_write_to_reg_file_ex),
    .ex_result(alu_result_ex),

    // MEM段からのフィードバック (2クロック前) [cite: 54, 55]
    .mem_reg_write_en(reg_write_enable_mem),
    .mem_dest_addr(address_write_to_reg_file_mem),
    .mem_result(mem_result_for_fwd),

    .forwarded_data_a(forwarded_data_a_id),
    .forwarded_data_b(forwarded_data_b_id)
);



//あとで消す
assign pc_output = pc_now; //IF段のPCの値を外部に出力するワイヤ

sort_performance_counter sort_per_count_inst (
    .clk(clk),
    .rst(rst),
    .run_state(exec_run_state),
    .halt(halt_commit),
    .cycle_count(cycle_count)

);



endmodule
