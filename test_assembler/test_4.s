; test4_branch_loop_text.s
;
; sum = 5 + 4 + 3 + 2 + 1 = 15
;
; expected:
;   port0 = 000F
;   port1 = 0000
;   port2 = 0005
;   port6 = 0054
;   port7 = unchanged

        LI   R0, 5          ; counter
        LI   R1, 0          ; remaining after loop
        LI   R2, 0          ; sum
        LI   R3, 0          ; loop count

T4_LOOP:
        ADD  R2, R0
        ADDI R3, 1
        SUBI R0, 1

        CMPI R0, 0
        NOP
        BNE  T4_LOOP

        MOV  R1, R0

        CMPI R2, 15
        NOP
        BNE  T4_FAIL

        CMPI R3, 5
        NOP
        BNE  T4_FAIL

T4_PASS:
        LI   R5, 84
        OUT  R2, 0
        OUT  R1, 1
        OUT  R3, 2
        OUT  R5, 6
        HLT

T4_FAIL:
        LI   R5, 4
        OUT  R2, 0
        OUT  R1, 1
        OUT  R3, 2
        OUT  R5, 7
        HLT