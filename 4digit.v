module four_digit(
    input clk,
    input rst_n,
    input [15:0] data,
    output [7:0] seg_out,
    output [3:0] sel
);

    // 各桁のデータ（4ビットずつ分割）
    wire [3:0] data1; // 下位桁 (1の位)
    wire [3:0] data2; // (16の位)
    wire [3:0] data3; // (256の位)
    wire [3:0] data4; // 上位桁 (4096の位)

    assign data1 = data[3:0];
    assign data2 = data[7:4];
    assign data3 = data[11:8];
    assign data4 = data[15:12];

    // ダイナミック点灯用カウンタ
    reg [14:0] dynamic_count;
    reg [1:0] dynamic_sel;

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            dynamic_count <= 15'd0;
            dynamic_sel <= 2'd0;
        end else if (dynamic_count == 15'd19_999) begin
            dynamic_count <= 15'd0;
            dynamic_sel <= dynamic_sel + 2'd1;
        end else begin
            dynamic_count <= dynamic_count + 15'd1;
        end
    end

    // 表示する桁のデータを選択
    wire [3:0] disp_data;
    assign disp_data = (dynamic_sel == 2'd0) ? data1 :
                       (dynamic_sel == 2'd1) ? data2 :
                       (dynamic_sel == 2'd2) ? data3 :
                                               data4;

    // 表示する桁を選択（アクティブロー）
    assign sel = (dynamic_sel == 2'd0) ? 4'b0111 :
                 (dynamic_sel == 2'd1) ? 4'b1011 :
                 (dynamic_sel == 2'd2) ? 4'b1101 :
                                         4'b1110;

    // 7セグメントデコーダのインスタンス化
    seg7decoder U1(
        .a   (disp_data),
        .minus (1'b0),
        .blank (1'b0),
        .out (seg_out),
        .sel ()
    );

endmodule
