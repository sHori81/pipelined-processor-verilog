; hazard_test3_shifter_use_text.s
;
; expected:
;   port0 = 0006  ; R0 = 6
;   port1 = 000F  ; R2 = 15
;   port2 = 000C  ; R3 = 12
;   port3 = FFFC  ; R5 = -4
;   port6 = 0073
;   port7 = unchanged

        LI   R0, 3
        LI   R2, 0

        ; direct Shifter-use: SLL -> ADD
        SLL  R0, 1          ; R0 = 6
        ADD  R2, R0         ; R2 = 6

        ; direct Shifter-use: SRL -> ADD
        SRL  R0, 1          ; R0 = 3
        ADD  R2, R0         ; R2 = 9

        ; direct Shifter-use: SLL -> ADD
        SLL  R0, 1          ; R0 = 6
        ADD  R2, R0         ; R2 = 15

        ; spaced Shifter-use: SLL -> unrelated LI -> ADD
        LI   R1, 2
        LI   R3, 0

        SLL  R1, 3          ; R1 = 16
        LI   R4, 0          ; unrelated spacer
        ADD  R3, R1         ; R3 = 16

        ; direct SRA-use
        LI   R5, -8
        SRA  R5, 1          ; R5 = -4
        ADD  R3, R5         ; R3 = 12

        CMPI R0, 6
        NOP
        BNE  T3_FAIL

        CMPI R2, 15
        NOP
        BNE  T3_FAIL

        CMPI R3, 12
        NOP
        BNE  T3_FAIL

        CMPI R5, -4
        NOP
        BNE  T3_FAIL

T3_PASS:
        LI   R5, 0x73
        OUT  R0, 0
        OUT  R2, 1
        OUT  R3, 2
        LI   R4, -4
        OUT  R4, 3
        OUT  R5, 6
        HLT

T3_FAIL:
        LI   R5, 3
        OUT  R0, 0
        OUT  R2, 1
        OUT  R3, 2
        OUT  R5, 7
        HLT