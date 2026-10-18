; flush_test1_kill_out_hlt.s
;
; expected:
;   port6 = 0071
;   port7 = unchanged
;
; if failed:
;   port7 = 0001 が出る、または HLT で早止まりする

        LI   R0, 0
        LI   R5, 1

        CMPI R0, 0
        NOP
        BE   T1_TARGET

        ; wrong-path: flushされるべき
        OUT  R5, 7
        HLT

T1_TARGET:
        LI   R5, 0x71
        OUT  R5, 6
        HLT