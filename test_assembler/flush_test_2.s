; flush_test2_kill_store_text.s
;
; data[3] should stay 0.
;
; expected:
;   port0 = 0000
;   port6 = 0082
;   port7 = unchanged

        LI   R6, 0
        LI   R2, 0x55
        LI   R0, 0

        CMPI R0, 0
        NOP
        BE   T2_TARGET

        ; wrong-path: flushされるべき
        ST   R2, 3(R6)

T2_TARGET:
        LD   R3, 3(R6)
        NOP
        NOP

        CMPI R3, 0
        NOP
        BE   T2_PASS

T2_FAIL:
        LI   R5, 2
        OUT  R3, 0
        OUT  R5, 7
        HLT

T2_PASS:
        LI   R5, 0x82
        OUT  R3, 0
        OUT  R5, 6
        HLT