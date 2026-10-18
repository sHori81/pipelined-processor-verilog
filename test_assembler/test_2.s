; test2_forward_imm_text.s
;
; expected:
;   port0 = 0012  ; R0 = 18
;   port2 = 0014  ; R2 = 20
;   port3 = 0004  ; R3 = 4
;   port6 = 0052
;   port7 = unchanged

        LI   R0, 18

        MOV  R2, R0
        ADDI R2, 5
        SUBI R2, 3          ; R2 = 18 + 5 - 3 = 20

        MOV  R3, R2
        ANDI R3, 15         ; R3 = 20 & 15 = 4

        CMPI R2, 20
        NOP
        BE   T2_R2_OK

        LI   R5, 21
        OUT  R2, 2
        OUT  R5, 7
        HLT

T2_R2_OK:
        CMPI R3, 4
        NOP
        BE   T2_PASS

        LI   R5, 22
        OUT  R3, 3
        OUT  R5, 7
        HLT

T2_PASS:
        LI   R5, 82
        OUT  R0, 0
        OUT  R2, 2
        OUT  R3, 3
        OUT  R5, 6
        HLT

        LI   R5, 2
        OUT  R5, 7
        HLT