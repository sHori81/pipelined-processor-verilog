module seg7_snoop_display (
    input  wire        clk,
    input  wire        rst,
    
    // スヌープ（盗み聞き）用ポート
    input  wire        dmem_we,    // メモリ書き込み有効信号
    input  wire [15:0] dmem_addr,  // メモリアドレス
    input  wire [15:0] dmem_wdata, // 書き込みデータ

    // MU500-7SEGボードへの出力
    output wire [7:0]  seg_a_out,
    output wire [7:0]  seg_b_out,
    output wire [7:0]  seg_c_out,
    output wire [7:0]  seg_d_out,
    output wire [7:0]  seg_e_out,
    output wire [7:0]  seg_f_out,
    output wire [7:0]  seg_g_out,
    output wire [7:0]  seg_h_out,
    output wire [7:0]  seg_sel
);

    // ① 7セグ表示専用の16ワードバッファ
    reg [15:0] snoop_buffer [0:15];
    integer i;

    // メモリスヌープ処理
    always @(posedge clk or negedge rst) begin
        if (~rst) begin
            // リセット時はバッファを0クリア（初期状態は 0000 が表示される）
            for (i = 0; i < 16; i = i + 1) begin
                snoop_buffer[i] <= 16'h0000;
            end
        end else if (dmem_we && (dmem_addr < 16)) begin
            // 0〜15番地への書き込みが発生したらバッファにも保存
            snoop_buffer[dmem_addr] <= dmem_wdata;
        end
    end

    // ② ダイナミックスキャン用カウンタ
    // 常に0〜7を高速にカウントアップし、表示する列（A0〜A7等）を切り替える
    reg [15:0] scan_cnt; 
    always @(posedge clk or negedge rst) begin
        if (~rst) scan_cnt <= 16'd0;
        else      scan_cnt <= scan_cnt + 1'b1;
    end
    
    // クロックを適度に分周して列インデックス(0〜7)を作成
    // ※シミュレーション時は下位ビット[2:0]に、実機時は[15:13]等に調整するとチラツキが消えます
    wire [2:0] col_idx = scan_cnt[15:13]; 
    assign seg_sel = 8'b0000_0001 << col_idx;

    // ③ 選択中の列に応じて、表示すべき16ビットデータを取得
    // col_idxが 0〜3 の時は前半のアドレス、4〜7 の時は後半のアドレスを選択
    wire [15:0] word_a = (col_idx < 4) ? snoop_buffer[0]  : snoop_buffer[1];
    wire [15:0] word_b = (col_idx < 4) ? snoop_buffer[2]  : snoop_buffer[3];
    wire [15:0] word_c = (col_idx < 4) ? snoop_buffer[4]  : snoop_buffer[5];
    wire [15:0] word_d = (col_idx < 4) ? snoop_buffer[6]  : snoop_buffer[7];
    wire [15:0] word_e = (col_idx < 4) ? snoop_buffer[8]  : snoop_buffer[9];
    wire [15:0] word_f = (col_idx < 4) ? snoop_buffer[10] : snoop_buffer[11];
    wire [15:0] word_g = (col_idx < 4) ? snoop_buffer[12] : snoop_buffer[13];
    wire [15:0] word_h = (col_idx < 4) ? snoop_buffer[14] : snoop_buffer[15];

    // ④ 取得した16ビットから、対象の4ビット(1桁分)を切り出す関数
    function [3:0] get_nibble;
        input [15:0] word;
        input [1:0]  idx; // col_idxの下位2ビット
        begin
            case (idx)
                // 左から右へ上位桁→下位桁となるように割り当て
                2'b00: get_nibble = word[15:12];
                2'b01: get_nibble = word[11:8];
                2'b10: get_nibble = word[7:4];
                2'b11: get_nibble = word[3:0];
            endcase
        end
    endfunction

    // ⑤ 4ビット(0〜F)を7セグメントLEDの8ビット点灯信号に変換する関数
    // ※MU500-7SEGマニュアル「表 2.3.3-1」に基づくマッピング
    function [7:0] hex2seg;
        input [3:0] hex;
        begin
            case (hex)
                4'h0: hex2seg = 8'b1111_1100;
                4'h1: hex2seg = 8'b0110_0000;
                4'h2: hex2seg = 8'b1101_1010;
                4'h3: hex2seg = 8'b1111_0010;
                4'h4: hex2seg = 8'b0110_0110;
                4'h5: hex2seg = 8'b1011_0110;
                4'h6: hex2seg = 8'b1011_1110;
                4'h7: hex2seg = 8'b1110_0000;
                4'h8: hex2seg = 8'b1111_1110;
                4'h9: hex2seg = 8'b1111_0110;
                4'hA: hex2seg = 8'b1110_1110;
                4'hB: hex2seg = 8'b0011_1110;
                4'hC: hex2seg = 8'b1001_1100;
                4'hD: hex2seg = 8'b0111_1010;
                4'hE: hex2seg = 8'b1001_1110;
                4'hF: hex2seg = 8'b1000_1110;
                default: hex2seg = 8'b0000_0000;
            endcase
        end
    endfunction

    // 最終出力
    assign seg_a_out = hex2seg(get_nibble(word_a, col_idx[1:0]));
    assign seg_b_out = hex2seg(get_nibble(word_b, col_idx[1:0]));
    assign seg_c_out = hex2seg(get_nibble(word_c, col_idx[1:0]));
    assign seg_d_out = hex2seg(get_nibble(word_d, col_idx[1:0]));
    assign seg_e_out = hex2seg(get_nibble(word_e, col_idx[1:0]));
    assign seg_f_out = hex2seg(get_nibble(word_f, col_idx[1:0]));
    assign seg_g_out = hex2seg(get_nibble(word_g, col_idx[1:0]));
    assign seg_h_out = hex2seg(get_nibble(word_h, col_idx[1:0]));

endmodule