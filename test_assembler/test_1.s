; test1_nop_basic_text.s
; NOP = 16'h0000 の基本テスト
;
; data[5] = 123 にしておく。
; もし NOP が LD R0,0(R0) として実行されてしまうと、
; R0=5 から data[5]=123 を読んで R0 が壊れる。
;
; expected:
;   port0 = 0005
;   port1 = 0003
;   port6 = 0051
;   port7 = unchanged

        LI   R6, 0

        LI   R0, 5
        LI   R1, 0

        NOP
        NOP

        ; R0 が 5 のままか確認
        CMPI R0, 5
        NOP
        BE   T1_R0_OK

        LI   R5, 11
        OUT  R0, 0
        OUT  R5, 7
        HLT

T1_R0_OK:
        ADDI R1, 1

        ; NOP が Z=1 を壊していないか確認
        CMPI R0, 5
        NOP
        NOP
        BE   T1_FLAG_OK1

        LI   R5, 12
        OUT  R0, 0
        OUT  R5, 7
        HLT

T1_FLAG_OK1:
        ADDI R1, 1

        ; NOP が Z=0 も壊していないか確認
        CMPI R0, 4
        NOP
        NOP
        BNE  T1_FLAG_OK2

        LI   R5, 13
        OUT  R0, 0
        OUT  R5, 7
        HLT

T1_FLAG_OK2:
        ADDI R1, 1

T1_PASS:
        LI   R5, 81
        OUT  R0, 0
        OUT  R1, 1
        OUT  R5, 6
        HLT

        ; HLT後にここが実行されないこともついでに確認
        LI   R5, 1
        OUT  R5, 7
        HLT