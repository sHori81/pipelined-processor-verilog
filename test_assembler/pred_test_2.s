; alias_test2_taken_to_not_taken_branch.s
; 0x0040 BNE trains index 0 as taken.
; 0x0080 BE has same index but should be not taken.

        LI   R0, 4
        LI   R2, 0
        LI   R3, 0
        LI   R4, 1          ; R4 != 0, so BE after CMPI R4,0 is not taken

        .ORG 0x003C
TRAIN_LOOP:
        ADDI R2, 1
        SUBI R0, 1

        CMPI R0, 0
        NOP
        BNE  TRAIN_LOOP     ; PC = 0x0040, index = 0

        ; fall through to 0x007E

        .ORG 0x007E
        CMPI R4, 0
        NOP
        BE   T2_WRONG       ; PC = 0x0080, index = 0, actual not taken

        ADDI R3, 5          ; correct path

        CMPI R2, 4
        NOP
        BNE  T2_FAIL

        CMPI R3, 5
        NOP
        BNE  T2_FAIL

T2_PASS:
        LI   R5, 0x62
        OUT  R2, 0
        OUT  R3, 1
        OUT  R5, 6
        HLT

T2_WRONG:
        LI   R3, -1
        LI   R5, 22
        OUT  R2, 0
        OUT  R3, 1
        OUT  R5, 7
        HLT

T2_FAIL:
        LI   R5, 2
        OUT  R2, 0
        OUT  R3, 1
        OUT  R5, 7
        HLT