module pipelined_pc(
  input clk,
  input rst,
  input run_state, // プロセッサが実行状態のときに1になる信号
  input [15:0] pc_input,
  output [15:0] pc_output
);

reg[15:0] pc_count;

always @(posedge clk or negedge rst) begin
  if(~rst) begin
    pc_count <= 16'd0;
  end else if (run_state) begin
    pc_count <= pc_input;
  end
end
assign pc_output = pc_count;

endmodule
