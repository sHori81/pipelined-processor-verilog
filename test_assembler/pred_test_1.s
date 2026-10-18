; alias_test1_branch_to_nonbranch.s
; 64-entry predictor alias test
; 0x0040 and 0x0080 have the same predictor index: PC[5:0] = 0

        LI   R0, 4          ; loop counter
        LI   R2, 0          ; training loop execution count
        LI   R3, 0          ; non-branch execution result

        .ORG 0x003C
TRAIN_LOOP:
        ADDI R2, 1
        SUBI R0, 1

        CMPI R0, 0
        NOP
        BNE  TRAIN_LOOP     ; PC = 0x0040, index = 0

        ; fall through, NOP area until 0x0080

        .ORG 0x0080
ALIAS_NONBRANCH:
        ADDI R3, 1          ; same index as branch at 0x0040
        ADDI R3, 2          ; R3 should become 3

        CMPI R2, 4
        NOP
        BNE  T1_FAIL

        CMPI R3, 3
        NOP
        BNE  T1_FAIL

T1_PASS:
        LI   R5, 0x61
        OUT  R2, 0
        OUT  R3, 1
        OUT  R5, 6
        HLT

T1_FAIL:
        LI   R5, 1
        OUT  R2, 0
        OUT  R3, 1
        OUT  R5, 7
        HLT