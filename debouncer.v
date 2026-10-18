module debouncer (
    input clk,
    input rst,
    input btn_in,      // 物理ボタンからのナマの入力
    output reg btn_out // 綺麗に整形された出力
);

`ifdef SYNTHESIS 
    // Quartusで論理合成する時（実機用）は本来の長いカウント値
    parameter WAIT_COUNT = 21'd1_450_000; 
`else
    // シミュレータで回す時は、あっという間に終わる短いカウント値
    parameter WAIT_COUNT = 21'd10; 
`endif

    reg [20:0] counter;
    reg sync_0, sync_1; // メタスタビリティ対策用2段フリップフロップ

    // 1. 非同期信号の同期化（メタスタビリティ対策）
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            sync_0 <= 1'b0;
            sync_1 <= 1'b0;
        end else begin
            sync_0 <= btn_in;
            sync_1 <= sync_0;
        end
    end

    // 2. チャタリング防止（一定時間同じ値が続いたら出力を更新）
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            counter <= 21'd0;
            btn_out <= 1'b0;
        end else begin
            if (sync_1 == btn_out) begin
                // 出力と入力が同じならカウンタをリセット
                counter <= 21'd0;
            end else begin
                // 変化が起きたらカウント開始
                counter <= counter + 21'd1;
                if (counter == WAIT_COUNT) begin
                    // 指定時間変化しなかったら（安定したら）出力を更新
                    btn_out <= sync_1;
                    counter <= 21'd0;
                end
            end
        end
    end
endmodule