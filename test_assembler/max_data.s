; out_port_test.s
; OUT Rs, port の拡張確認用
;
; 期待:
;   port0 = R0 = 3
;   port1 = R1 = 4
;   port2 = R2 = 7      ; 3 + 4
;   port3 = R3 = 1      ; 4 - 3
;   port4 = R4 = 17     ; 7 + 10
;   port5 = R5 = 13     ; 17 - 4
;   port6 = R6 = 15     ; 0x3F & 0x0F
;   port7 = R7 = 8      ; 7 ^ 15

        LI   R0, 3          ; R0 = 3
        LI   R1, 4          ; R1 = 4

        MOV  R2, R0         ; R2 = 3
        ADD  R2, R1         ; R2 = 7

        MOV  R3, R1         ; R3 = 4
        SUB  R3, R0         ; R3 = 1

        MOV  R4, R2         ; R4 = 7
        ADDI R4, 10         ; R4 = 17

        MOV  R5, R4         ; R5 = 17
        SUBI R5, 4          ; R5 = 13

        LI   R6, 0x3F       ; R6 = 0x003F
        ANDI R6, 0x0F       ; R6 = 0x000F

        MOV  R7, R2         ; R7 = 7
        XOR  R7, R6         ; R7 = 7 ^ 15 = 8

        OUT  R0, 0          ; port0 <- 0003
        OUT  R1, 1          ; port1 <- 0004
        OUT  R2, 2          ; port2 <- 0007
        OUT  R3, 3          ; port3 <- 0001
        OUT  R4, 4          ; port4 <- 0011
        OUT  R5, 5          ; port5 <- 000D
        OUT  R6, 6          ; port6 <- 000F
        OUT  R7, 7          ; port7 <- 0008

        HLT