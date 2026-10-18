module hazard_detection(
    input is_ld_ex,
    input is_in_ex,
    input szcv_update_enable_ex,
    input [2:0] ex_dest_addr,
    input [15:0] instruction_id,
    output hazard_detected
);
    wire [1:0] op1 = instruction_id[15:14];
    wire [2:0] op2 = instruction_id[13:11];
    wire [2:0] ra  = instruction_id[13:11];
    wire [2:0] rb  = instruction_id[10:8];
    wire is_nop = (instruction_id == 16'h0000);

    wire reads_ra = !is_nop && ((op1 == 2'b11) || (op1 == 2'b01));

    wire is_imm_arith = (op1 == 2'b10) &&
        (op2 == 3'b001 || op2 == 3'b010 || op2 == 3'b011 || op2 == 3'b101);
    wire reads_rb = !is_nop &&
        ((op1 == 2'b11) || (op1 == 2'b00) || (op1 == 2'b01) || is_imm_arith);

    wire is_cond_branch = !is_nop && (op1 == 2'b10) && (op2 == 3'b111);

    wire register_hazard = (is_ld_ex || is_in_ex) && (
        (reads_ra && (ex_dest_addr == ra)) ||
        (reads_rb && (ex_dest_addr == rb))
    );

    wire szcv_hazard = szcv_update_enable_ex && is_cond_branch;

    assign hazard_detected = register_hazard || szcv_hazard;
endmodule
