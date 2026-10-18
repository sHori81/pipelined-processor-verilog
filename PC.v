module PC(
  input clk,
  input rst,
  input [15:0] pc_input,
  input jump_enable,
  input p1,
  input p5,
  output [15:0] pc_output
);

reg[15:0] pc_count;

always @(posedge clk or negedge rst) begin
    if (~rst) begin
        pc_count <= 16'd0;
    end else if (p5 && jump_enable) begin
        // p5でジャンプ成立時のみ、計算されたアドレスで上書き
        pc_count <= pc_input;
    end else if (p1) begin
        // p1で常に+1しておく（これでメモリフェッチのタイミングが合う＆デコーダにPC+1が渡る）
        pc_count <= pc_count + 16'd1;
    end
end

assign pc_output = pc_count;

endmodule
