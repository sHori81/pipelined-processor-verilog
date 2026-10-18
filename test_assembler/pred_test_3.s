; alias_test3_taken_to_different_taken_target.s
; 0x0040 BNE trains index 0 taken with target TRAIN_LOOP.
; 0x0080 BE is also taken but has a different target.

        LI   R0, 4
        LI   R2, 0
        LI   R3, 0
        LI   R4, 1

        .ORG 0x003C
TRAIN_LOOP:
        ADDI R2, 1
        SUBI R0, 1

        CMPI R0, 0
        NOP
        BNE  TRAIN_LOOP     ; PC = 0x0040, index = 0, target = TRAIN_LOOP

        ; fall through to 0x007E

        .ORG 0x007E
        CMPI R4, 1
        NOP
        BE   T3_TARGET      ; PC = 0x0080, index = 0, actual taken but different target

        ; If branch is not taken, this is wrong.
        LI   R3, -2
        LI   R5, 31
        OUT  R2, 0
        OUT  R3, 1
        OUT  R5, 7
        HLT

T3_TARGET:
        ADDI R3, 9

        CMPI R2, 4
        NOP
        BNE  T3_FAIL

        CMPI R3, 9
        NOP
        BNE  T3_FAIL

T3_PASS:
        LI   R5, 0x63
        OUT  R2, 0
        OUT  R3, 1
        OUT  R5, 6
        HLT

T3_FAIL:
        LI   R5, 3
        OUT  R2, 0
        OUT  R3, 1
        OUT  R5, 7
        HLT