; test5_alternate_branch_text.s
;
; 16回ループ。
; R1 toggle = 0ならeven側、1ならodd側。
;
; expected:
;   port0 = 0010  ; R0 = 16
;   port1 = 0000  ; R1 = 0
;   port2 = 0008  ; even count
;   port3 = 0008  ; odd count
;   port6 = 0055
;   port7 = unchanged

        LI   R0, 0          ; loop counter
        LI   R1, 0          ; toggle
        LI   R2, 0          ; even count
        LI   R3, 0          ; odd count
        LI   R7, 0

T5_LOOP:
        CMPI R1, 0
        NOP
        BE   T5_EVEN

T5_ODD:
        ADDI R3, 1
        LI   R1, 0

        CMPI R7, 0
        NOP
        BE   T5_AFTER_IF

T5_EVEN:
        ADDI R2, 1
        LI   R1, 1

T5_AFTER_IF:
        ADDI R0, 1

        CMPI R0, 16
        NOP
        BLT  T5_LOOP

        CMPI R0, 16
        NOP
        BNE  T5_FAIL

        CMPI R1, 0
        NOP
        BNE  T5_FAIL

        CMPI R2, 8
        NOP
        BNE  T5_FAIL

        CMPI R3, 8
        NOP
        BNE  T5_FAIL

T5_PASS:
        LI   R5, 85
        OUT  R0, 0
        OUT  R1, 1
        OUT  R2, 2
        OUT  R3, 3
        OUT  R5, 6
        HLT

T5_FAIL:
        LI   R5, 5
        OUT  R0, 0
        OUT  R1, 1
        OUT  R2, 2
        OUT  R3, 3
        OUT  R5, 7
        HLT