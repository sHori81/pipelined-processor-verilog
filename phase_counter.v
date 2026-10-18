module phase_counter(
    input clk, // クロック信号
    input rst, // リセット信号（非同期、アクティブロー）
    input input_enter,
    input exec, // 実行信号（フェーズカウンタの進行を制御）
    input wait_for_input, 
    output p1, p2, p3, p4, p5 // 各フェーズの個別出力
);
    reg run_state; // 実行状態を保持するレジスタ
    reg exec_prev; // 前のクロックサイクルのexec信号を保持
    reg enter_prev; // 前のクロックサイクルのinput_enter信号を保持
    reg [2:0] phase; 


    assign p1 = (phase == 3'b001) && run_state;
    assign p2 = (phase == 3'b010);
    assign p3 = (phase == 3'b011);
    assign p4 = (phase == 3'b100);
    assign p5 = (phase == 3'b101);

    // exec信号の立ち上がりを検出して実行状態を更新
    always @(posedge clk or negedge rst) begin
        if (!rst) begin 
            phase <= 3'b001; // リセット時はフェーズ1に戻る
            run_state <= 0; // 実行状態をリセット
            exec_prev <= 0; // 前のexec信号をリセット
            enter_prev <= 0; // 前のinput_enter信号をリセット
        end else begin
            if (exec && !exec_prev) begin// execの立ち上がりを検出
                run_state <=  ~run_state; // 実行状態をトグル
            end
            if (run_state || phase != 3'b001) begin //実行完了(Phase5)まで待つ
                if (phase == 3'b100 && wait_for_input && !(input_enter && !enter_prev)) begin
                    phase <= phase; // フェーズ4で停止
                end else if(phase == 3'b101) begin
                        phase <= 3'b001;
                end else
                        phase <= phase + 1; 
            end
            exec_prev <= exec; // 現在のexec信号を保存
            enter_prev <= input_enter; // 現在のinput_enter信号を保存
        end
    end
endmodule