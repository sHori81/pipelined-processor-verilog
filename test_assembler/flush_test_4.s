; flush_test4_kill_flags.s
;
; expected:
;   port0 = 0000
;   port1 = 0000
;   port6 = 0084
;   port7 = unchanged

        LI   R0, 0
        LI   R1, 0

        ; Z = 1 にしておく
        CMPI R0, 0
        NOP
        BE   T4_TARGET

        ; wrong-path: flushされるべき
        ; これが生きると R1=1, Z=0 になる
        ADDI R1, 1

T4_TARGET:
        ; ここでは、まだ Z=1 のはず
        NOP
        BE   T4_PASS

T4_FAIL:
        LI   R5, 4
        OUT  R0, 0
        OUT  R1, 1
        OUT  R5, 7
        HLT

T4_PASS:
        LI   R5, 0x84
        OUT  R0, 0
        OUT  R1, 1
        OUT  R5, 6
        HLT