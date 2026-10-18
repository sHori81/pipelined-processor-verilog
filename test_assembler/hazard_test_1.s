; hazard_test1_load_use_text.s
;
; data[1] = 12
; data[2] = 5
; data[3] = 20
;
; expected:
;   port0 = 0007  ; R2 = 12 - 5
;   port1 = 0016  ; R3 = 22
;   port6 = 0071
;   port7 = unchanged

        LI   R6, 0
        LI   R2, 0

        ; direct LD-use: LD -> ADD
        LD   R0, 1(R6)      ; R0 = 12
        ADD  R2, R0         ; R2 = 12

        ; direct LD-use: LD -> SUB
        LD   R1, 2(R6)      ; R1 = 5
        SUB  R2, R1         ; R2 = 7

        ; spaced LD-use: LD -> unrelated LI -> ADD
        LD   R3, 3(R6)      ; R3 = 20
        LI   R4, 2          ; unrelated spacer
        ADD  R3, R4         ; R3 = 22

        CMPI R2, 7
        NOP
        BNE  T1_FAIL

        CMPI R3, 22
        NOP
        BNE  T1_FAIL

T1_PASS:
        LI   R5, 0x71
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