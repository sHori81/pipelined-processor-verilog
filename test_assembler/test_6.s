; test6_max_text.s
;
; data[1] = n = 8
; data[2..9] = array
; array = 3, 7, -2, 15, 4, 15, -1, 8
;
; expected:
;   port0 = 000F  ; max = 15
;   port1 = 0000  ; remaining = 0
;   port2 = 000A  ; final address = 10
;   port6 = 0056
;   port7 = unchanged

        LI   R6, 0
        LD   R1, 1(R6)      ; R1 = n

        LI   R0, 2          ; R0 = array address
        LD   R2, 0(R0)      ; R2 = max = array[0]

        ADDI R0, 1
        SUBI R1, 1

        NOP
        NOP

T6_LOOP_CHECK:
        CMPI R1, 0
        NOP
        BE   T6_DONE

        LD   R3, 0(R0)      ; R3 = current
        ADDI R0, 1
        SUBI R1, 1
        NOP                 ; LD-use spacer

        CMP  R2, R3
        NOP
        BLT  T6_UPDATE

T6_NO_UPDATE:
        CMPI R6, 0
        NOP
        BE   T6_LOOP_CHECK

T6_UPDATE:
        MOV  R2, R3

        CMPI R6, 0
        NOP
        BE   T6_LOOP_CHECK

T6_DONE:
        CMPI R2, 15
        NOP
        BNE  T6_FAIL

        CMPI R1, 0
        NOP
        BNE  T6_FAIL

        CMPI R0, 10
        NOP
        BNE  T6_FAIL

T6_PASS:
        LI   R5, 86
        OUT  R2, 0
        OUT  R1, 1
        OUT  R0, 2
        OUT  R5, 6
        HLT

T6_FAIL:
        LI   R5, 6
        OUT  R2, 0
        OUT  R1, 1
        OUT  R0, 2
        OUT  R5, 7
        HLT