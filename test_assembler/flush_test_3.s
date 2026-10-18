; flush_test3_kill_regwrite.s
;
; expected:
;   port0 = 0000
;   port6 = 0083
;   port7 = unchanged

        LI   R0, 0
        LI   R3, 0

        CMPI R0, 0
        NOP
        BE   T3_TARGET

        ; wrong-path: flushされるべき
        ADDI R3, 7

T3_TARGET:
        CMPI R3, 0
        NOP
        BE   T3_PASS

T3_FAIL:
        LI   R5, 3
        OUT  R3, 0
        OUT  R5, 7
        HLT

T3_PASS:
        LI   R5, 0x83
        OUT  R3, 0
        OUT  R5, 6
        HLT