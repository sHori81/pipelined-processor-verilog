module shifter(
    input [15:0] data_b,
    input [3:0] op3,
    input [3:0] diff,
    output reg [15:0] data_output,
    output [3:0] data_szcv
);

    // 1. データ本体の並列計算
    wire [15:0] sll_out = data_b << diff;
    wire [15:0] srl_out = data_b >> diff;
    wire [15:0] sra_out = $signed(data_b) >>> diff;
    
    wire [3:0] rot_diff = -diff; 
    wire [15:0] r_rot   = data_b >> rot_diff;
    wire [15:0] rol_out = sll_out | r_rot;

    // フラグ（ZとS）もMUXの前に並列で計算
    // 巨大な16入力NORゲートを、MUXの後ろではなく前（時間が余っている場所）に配置する
    wire z_sll = (sll_out == 16'b0);
    wire z_rol = (rol_out == 16'b0);
    wire z_srl = (srl_out == 16'b0);
    wire z_sra = (sra_out == 16'b0);

    wire s_sll = sll_out[15];
    wire s_rol = rol_out[15];
    wire s_srl = srl_out[15];
    wire s_sra = sra_out[15];

    // 3. データ本体とフラグ（Z, S）を1つの case 文で同時にセレクト
    reg zero, sign;
    always @(*) begin
        case (op3)
            4'b1000: begin data_output = sll_out; zero = z_sll; sign = s_sll; end
            4'b1001: begin data_output = rol_out; zero = z_rol; sign = s_rol; end
            4'b1010: begin data_output = srl_out; zero = z_srl; sign = s_srl; end
            4'b1011: begin data_output = sra_out; zero = z_sra; sign = s_sra; end
            default: begin data_output = 16'h0000; zero = 1'b1;  sign = 1'b0; end
        endcase
    end
    
    // 4. Carryフラグの並列セレクト（仕様書に完全準拠）
    reg carry;
    always @(*) begin
        if (diff == 4'd0) begin
            carry = 1'b0; // シフト量0の時はC=0
        end else begin
            case (op3)
                4'b1000: carry = data_b[16 - diff];
                4'b1001: carry = 1'b0; // SLRではC=0 (仕様書準拠)
                4'b1010: carry = data_b[diff - 1];
                4'b1011: carry = data_b[diff - 1];
                default: carry = 1'b0;
            endcase
        end
    end

    wire overflow = 1'b0; // Vは常に0 (仕様書準拠)
    assign data_szcv = {sign, zero, carry, overflow};

endmodule