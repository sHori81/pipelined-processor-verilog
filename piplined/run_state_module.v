module run_state_module(
    input clk,
    input rst,
    input exec,
    input wait_for_input,
    input input_enter,
    input is_halt,
    output reg run_state // 実行状態を保持するレジスタ
);

reg exec_prev;
reg input_enter_prev;
reg wait_for_input_prev; // ← 【追加】前のクロックの入力待ち状態を保持

always @(posedge clk or negedge rst) begin
    if (!rst) begin
        run_state <= 0;
        exec_prev <= 0;
        input_enter_prev <= 0;
        wait_for_input_prev <= 0;
    end 
    else begin
        // 1. HALT命令
        if (is_halt) begin
            run_state <= 0;
        end
        // 2. execボタン
        else if (exec && !exec_prev) begin
            run_state <= ~run_state;
        end
        // 3. IN命令が「新しく来た瞬間（0 → 1）」だけ止める
        else if (wait_for_input && !wait_for_input_prev && run_state) begin
            run_state <= 0;
        end
        // 4. 停止中で、エンターが押されたら再開
        else if (!run_state && wait_for_input && input_enter && !input_enter_prev) begin
            run_state <= 1;
        end
        
        // 過去値の更新
        exec_prev <= exec; 
        input_enter_prev <= input_enter; 
        wait_for_input_prev <= wait_for_input; // ← 【追加】
    end
end
endmodule