module forwarding_unit (
    // ID段 (From Decoder/RegFile)
    input [2:0] address_a, address_b,
    input [15:0] data_a_raw, data_b_raw,

    // EX段 (From ID/EX Register or ALU)
    input ex_reg_write_en,
    input [2:0] ex_dest_addr,
    input [15:0] ex_result,

    // MEM段 (From EX/MEM Register or Memory/IN)
    input mem_reg_write_en,
    input [2:0] mem_dest_addr,
    input [15:0] mem_result,

    // Outputs to ID Stage
    output [15:0] forwarded_data_a,
    output [15:0] forwarded_data_b
);

    // Data A のフォワーディング判定
    // 優先順位：1. EX段(最新) > 2. MEM段 > 3. レジスタファイル
    // R0 (3'b000) は常に0なのでフォワーディング対象外とする
    assign forwarded_data_a = 
        (ex_reg_write_en && (ex_dest_addr == address_a)) ? ex_result :
        (mem_reg_write_en && (mem_dest_addr == address_a)) ? mem_result :
        data_a_raw;

    // Data B も同様
    assign forwarded_data_b = 
        (ex_reg_write_en && (ex_dest_addr == address_b)) ? ex_result :
        (mem_reg_write_en && (mem_dest_addr == address_b)) ? mem_result :
        data_b_raw;

endmodule