; calculator_v1_text.s
;
; Simple interactive calculator v1
;
; Input sequence:
;   first_value
;   op
;   next_value
;   op
;   next_value
;   ...
;   0
;
; Operator codes:
;   0 = =
;   1 = ADD
;   2 = SUB
;   3 = MUL
;   4 = DIV
;   5 = MOD
;
; Data memory:
;   data[0] = ANS
;   data[1] = REM
;   data[2] = ERR
;
; Registers:
;   R0 = accumulator / result
;   R1 = next input / divisor / multiplier
;   R2 = operator code
;   R3 = result temp / remainder
;   R4 = sign flag
;   R5 = temp / error code
;   R6 = data memory base
;   R7 = temp / sign flag

        LI   R6, 0          ; data memory base

        LI   R5, 0
        ST   R5, 1(R6)      ; REM = 0
        ST   R5, 2(R6)      ; ERR = 0

; ----------------------------
; read first value
; ----------------------------
        IN   R0             ; accumulator = first input
        ST   R0, 0(R6)      ; ANS = accumulator
        OUT  R0

; ----------------------------
; main loop
; ----------------------------
READ_OP:
        IN   R2             ; read operator code

        CMPI R2, 0
        BE   CALC_DONE

        CMPI R2, 1
        BLT  INVALID_OP

        CMPI R2, 5
        BLE  READ_VALUE

        B    INVALID_OP

READ_VALUE:
        IN   R1             ; read next value

        CMPI R2, 1
        BE   OP_ADD

        CMPI R2, 2
        BE   OP_SUB

        CMPI R2, 3
        BE   OP_MUL

        CMPI R2, 4
        BE   OP_DIVMOD

        CMPI R2, 5
        BE   OP_DIVMOD

        B    INVALID_OP

; ----------------------------
; ADD: R0 = R0 + R1
; ----------------------------
OP_ADD:
        ADD  R0, R1
        B    SAVE_RESULT

; ----------------------------
; SUB: R0 = R0 - R1
; ----------------------------
OP_SUB:
        SUB  R0, R1
        B    SAVE_RESULT

; ----------------------------
; MUL signed
; R0 = R0 * R1
; result low 16 bits only
; ----------------------------
OP_MUL:
        LI   R3, 0          ; R3 = result
        LI   R4, 0          ; R4 = sign flag, 0 positive, 1 negative
        LI   R7, 1          ; R7 = 1 for sign toggle

; if R0 < 0: R0 = -R0, sign ^= 1
MUL_CHECK_A:
        CMPI R0, 0
        BLT  MUL_NEG_A

MUL_AFTER_A:

; if R1 < 0: R1 = -R1, sign ^= 1
        CMPI R1, 0
        BLT  MUL_NEG_B

MUL_AFTER_B:

MUL_LOOP:
        CMPI R1, 0
        BE   MUL_UNSIGNED_DONE

        MOV  R5, R1
        ANDI R5, 1
        CMPI R5, 0
        BE   MUL_SKIP_ADD

        ADD  R3, R0         ; result += multiplicand

MUL_SKIP_ADD:
        SLL  R0, 1          ; multiplicand <<= 1
        SRL  R1, 1          ; multiplier >>= 1
        B    MUL_LOOP

MUL_NEG_A:
        XOR  R4, R7         ; sign ^= 1
        LI   R5, 0
        SUB  R5, R0         ; R5 = -R0
        MOV  R0, R5
        B    MUL_AFTER_A

MUL_NEG_B:
        XOR  R4, R7         ; sign ^= 1
        LI   R5, 0
        SUB  R5, R1         ; R5 = -R1
        MOV  R1, R5
        B    MUL_AFTER_B

MUL_UNSIGNED_DONE:
        MOV  R0, R3         ; R0 = result

        CMPI R4, 0
        BNE  MUL_NEG_RESULT

        B    SAVE_RESULT

MUL_NEG_RESULT:
        LI   R5, 0
        SUB  R5, R0         ; R5 = -result
        MOV  R0, R5
        B    SAVE_RESULT

; ----------------------------
; DIV / MOD signed
;
; input:
;   R0 = dividend
;   R1 = divisor
;   R2 = operator code, 4 DIV, 5 MOD
;
; output:
;   DIV: R0 = quotient
;   MOD: R0 = remainder
;   data[1] = remainder
;
; semantics:
;   quotient rounds toward zero
;   remainder has same sign as dividend
; ----------------------------
OP_DIVMOD:
        CMPI R1, 0
        BE   DIV_BY_ZERO

        LI   R4, 0          ; quotient negative flag
        LI   R7, 0          ; remainder negative flag

; if dividend < 0
DIV_CHECK_A:
        CMPI R0, 0
        BLT  DIV_NEG_A

DIV_AFTER_A:

; if divisor < 0
        CMPI R1, 0
        BLT  DIV_NEG_B

DIV_AFTER_B:
        MOV  R3, R0         ; R3 = remainder = abs(dividend)
        LI   R0, 0          ; R0 = quotient

DIV_LOOP:
        CMP  R3, R1
        BLT  DIV_UNSIGNED_DONE

        SUB  R3, R1         ; remainder -= divisor
        ADDI R0, 1          ; quotient++
        B    DIV_LOOP

DIV_NEG_A:
        LI   R7, 1          ; remainder should be negative

        LI   R5, 1
        XOR  R4, R5         ; quotient sign ^= 1

        LI   R5, 0
        SUB  R5, R0         ; R5 = -dividend
        MOV  R0, R5
        B    DIV_AFTER_A

DIV_NEG_B:
        LI   R5, 1
        XOR  R4, R5         ; quotient sign ^= 1

        LI   R5, 0
        SUB  R5, R1         ; R5 = -divisor
        MOV  R1, R5
        B    DIV_AFTER_B

DIV_UNSIGNED_DONE:
; apply quotient sign
        CMPI R4, 0
        BNE  DIV_NEG_QUOTIENT

DIV_AFTER_QUOTIENT_SIGN:
; apply remainder sign
        CMPI R7, 0
        BNE  DIV_NEG_REMAINDER

DIV_AFTER_REMAINDER_SIGN:
        ST   R3, 1(R6)      ; REM = remainder

        CMPI R2, 5
        BE   USE_REMAINDER  ; MOD

        ; DIV: R0 is already quotient
        B    SAVE_RESULT

USE_REMAINDER:
        MOV  R0, R3
        B    SAVE_RESULT

DIV_NEG_QUOTIENT:
        LI   R5, 0
        SUB  R5, R0         ; R5 = -quotient
        MOV  R0, R5
        B    DIV_AFTER_QUOTIENT_SIGN

DIV_NEG_REMAINDER:
        LI   R5, 0
        SUB  R5, R3         ; R5 = -remainder
        MOV  R3, R5
        B    DIV_AFTER_REMAINDER_SIGN

DIV_BY_ZERO:
        LI   R5, 2          ; ERR = 2, divide by zero
        ST   R5, 2(R6)
        OUT  R5
        HLT

; ----------------------------
; save and continue
; ----------------------------
SAVE_RESULT:
        LI   R5, 0
        ST   R5, 2(R6)      ; ERR = 0
        ST   R0, 0(R6)      ; ANS = accumulator
        OUT  R0             ; show intermediate result
        B    READ_OP

; ----------------------------
; done
; ----------------------------
CALC_DONE:
        ST   R0, 0(R6)      ; ANS = final result
        OUT  R0
        HLT

; ----------------------------
; invalid operator
; ----------------------------
INVALID_OP:
        LI   R5, 1          ; ERR = 1, invalid operator
        ST   R5, 2(R6)
        OUT  R5
        HLT
