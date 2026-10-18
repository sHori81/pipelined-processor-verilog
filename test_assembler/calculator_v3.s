; calculator_v3.s
;
; Simple interactive calculator v3
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
;   0  = =
;   1  = ADD
;   2  = SUB
;   3  = MUL
;   4  = DIV
;   5  = MOD
;   6  = GCD
;   7  = LCM
;   8  = SUM
;   9  = ISPRIME
;   10 = FIBO
;   11 = PRIME_N
;   12 = MS    ; memory[addr] = accumulator
;   13 = MR    ; accumulator = memory[addr]
;   14 = MADD  ; memory[addr] += accumulator
;   15 = MSUB  ; memory[addr] -= accumulator
;   16 = MC    ; memory[addr] = 0
;
; Data memory:
;   data[0]  = ANS
;   data[1]  = REM
;   data[2]  = ERR
;   data[3]  = scratch abs_a
;   data[4]  = scratch abs_b
;   data[16]..data[31] = user memory M0..M15
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
        BE   CALC_DONE_EARLY

        ; unary operations
        CMPI R2, 9
        BE   OP_ISPRIME

        CMPI R2, 10
        BE   OP_FIBO

                CMPI R2, 11
        BE   OP_PRIME_N

        ; memory operations: 12..16
        CMPI R2, 12
        BLT  CHECK_BINARY_OP

        CMPI R2, 16
        BLE  OP_MEMORY

        B    INVALID_OP_EARLY

CHECK_BINARY_OP:
        ; binary operations: 1..8
        CMPI R2, 1
        BLT  INVALID_OP_EARLY

        CMPI R2, 8
        BLE  READ_VALUE

        B    INVALID_OP_EARLY


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

        CMPI R2, 6
        BE   OP_GCD

        CMPI R2, 7
        BE   OP_LCM

        CMPI R2, 8
        BE   OP_SUM

        B    INVALID_OP_EARLY

CALC_DONE_EARLY:
        ST   R0, 0(R6)      ; ANS = final result
        OUT  R0
        HLT

INVALID_OP_EARLY:
        LI   R5, 1          ; ERR = 1, invalid operator
        ST   R5, 2(R6)
        OUT  R5
        HLT

OP_SUM:
        B    OP_SUM_FWD_1

OP_ISPRIME:
        B    OP_ISPRIME_FWD_1

OP_FIBO:
        B    OP_FIBO_FWD_1

OP_PRIME_N:
        B    OP_PRIME_N_FWD_1

OP_LCM:
        B    OP_LCM_FWD_1

OP_MEMORY:
        B    OP_MEMORY_BODY_FWD_1

READ_OP_BACK_1:
        B    READ_OP

; ----------------------------
; ADD: R0 = R0 + R1
; ----------------------------
OP_ADD:
        ADD  R0, R1
        B    SAVE_RESULT_1

; ----------------------------
; SUB: R0 = R0 - R1
; ----------------------------
OP_SUB:
        SUB  R0, R1
        B    SAVE_RESULT_1

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

        B    SAVE_RESULT_1

MUL_NEG_RESULT:
        LI   R5, 0
        SUB  R5, R0         ; R5 = -result
        MOV  R0, R5
        B    SAVE_RESULT_1

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
        B    SAVE_RESULT_1

USE_REMAINDER:
        MOV  R0, R3
        B    SAVE_RESULT_1

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

SAVE_RESULT_1:
        LI   R5, 0
        ST   R5, 2(R6)      ; ERR = 0
        ST   R0, 0(R6)      ; ANS = accumulator
        OUT  R0             ; show intermediate result
        B    READ_OP_BACK_1

READ_OP_BACK_2:
        B    READ_OP_BACK_1

OP_SUM_FWD_1:
        B    OP_SUM_BODY

OP_ISPRIME_FWD_1:
        B    OP_ISPRIME_BODY

OP_LCM_FWD_1:
        B    OP_LCM_BODY

OP_FIBO_FWD_1:
        B    OP_FIBO_FWD_2

OP_PRIME_N_FWD_1:
        B    OP_PRIME_N_FWD_2

OP_MEMORY_BODY_FWD_1:
        B    OP_MEMORY_BODY_FWD_2

; ----------------------------
; GCD signed
;
; input:
;   R0 = a
;   R1 = b
;
; output:
;   R0 = gcd(abs(a), abs(b))
;
; semantics:
;   GCD(0, 0) = 0
; ----------------------------
OP_GCD:
; abs(a)
        CMPI R0, 0
        BLT  GCD_NEG_A

GCD_AFTER_A:
; abs(b)
        CMPI R1, 0
        BLT  GCD_NEG_B

GCD_AFTER_B:
; if a == 0 -> result = b
        CMPI R0, 0
        BE   GCD_A_ZERO

; if b == 0 -> result = a
        CMPI R1, 0
        BE   SAVE_RESULT_2

GCD_LOOP:
        CMP  R0, R1
        BE   GCD_DONE

        BLT  GCD_A_LT_B

; a > b
        SUB  R0, R1
        B    GCD_LOOP

GCD_A_LT_B:
        SUB  R1, R0
        B    GCD_LOOP

GCD_A_ZERO:
        MOV  R0, R1
        B    SAVE_RESULT_2

GCD_DONE:
        ; R0 == R1, R0 is gcd
        B    SAVE_RESULT_2

GCD_NEG_A:
        LI   R5, 0
        SUB  R5, R0
        MOV  R0, R5
        B    GCD_AFTER_A

GCD_NEG_B:
        LI   R5, 0
        SUB  R5, R1
        MOV  R1, R5
        B    GCD_AFTER_B

SAVE_RESULT_2:
        LI   R5, 0
        ST   R5, 2(R6)      ; ERR = 0
        ST   R0, 0(R6)      ; ANS = accumulator
        OUT  R0             ; show intermediate result
        B    READ_OP_BACK_2

; ----------------------------
; LCM signed
;
; input:
;   R0 = a
;   R1 = b
;
; output:
;   R0 = lcm(abs(a), abs(b))
;
; semantics:
;   LCM(a, b) = abs(a / gcd(a,b) * b)
;   LCM(0, b) = 0
;   LCM(a, 0) = 0
;
; note:
;   overflow is lower 16 bits
; ----------------------------
OP_LCM_BODY:
; abs(a)
        CMPI R0, 0
        BLT  LCM_NEG_A

LCM_AFTER_A:
; abs(b)
        CMPI R1, 0
        BLT  LCM_NEG_B

LCM_AFTER_B:
        ST   R0, 3(R6)      ; scratch abs_a
        ST   R1, 4(R6)      ; scratch abs_b

; if a == 0 -> 0
        CMPI R0, 0
        BE   LCM_ZERO

; if b == 0 -> 0
        CMPI R1, 0
        BE   LCM_ZERO

; ----------------------------
; gcd(abs_a, abs_b)
; R0 = a, R1 = b
; result gcd in R0
; ----------------------------
LCM_GCD_LOOP:
        CMP  R0, R1
        BE   LCM_GCD_DONE

        BLT  LCM_GCD_A_LT_B

        SUB  R0, R1
        B    LCM_GCD_LOOP

LCM_GCD_A_LT_B:
        SUB  R1, R0
        B    LCM_GCD_LOOP

LCM_GCD_DONE:
        MOV  R5, R0         ; R5 = gcd

; ----------------------------
; quotient = abs_a / gcd
; R2 = quotient
; R3 = remainder work
; ----------------------------
        LD   R3, 3(R6)      ; R3 = abs_a
        LI   R2, 0          ; R2 = quotient

LCM_DIV_LOOP:
        CMP  R3, R5
        BLT  LCM_DIV_DONE

        SUB  R3, R5
        ADDI R2, 1
        B    LCM_DIV_LOOP

LCM_DIV_DONE:
; ----------------------------
; result = quotient * abs_b
; R0 = multiplicand
; R1 = multiplier
; R3 = result
; ----------------------------
        MOV  R0, R2         ; R0 = quotient
        LD   R1, 4(R6)      ; R1 = abs_b
        LI   R3, 0          ; R3 = result

LCM_MUL_LOOP:
        CMPI R1, 0
        BE   LCM_MUL_DONE

        MOV  R4, R1
        ANDI R4, 1
        CMPI R4, 0
        BE   LCM_MUL_SKIP_ADD

        ADD  R3, R0

LCM_MUL_SKIP_ADD:
        SLL  R0, 1
        SRL  R1, 1
        B    LCM_MUL_LOOP

LCM_MUL_DONE:
        MOV  R0, R3
        B    SAVE_RESULT_2

LCM_ZERO:
        LI   R0, 0
        B    SAVE_RESULT_2

LCM_NEG_A:
        LI   R5, 0
        SUB  R5, R0
        MOV  R0, R5
        B    LCM_AFTER_A

LCM_NEG_B:
        LI   R5, 0
        SUB  R5, R1
        MOV  R1, R5
        B    LCM_AFTER_B

READ_OP_BACK_3:
        B    READ_OP_BACK_2

OP_FIBO_FWD_2:
        B    OP_FIBO_BODY

OP_PRIME_N_FWD_2:
        B    OP_PRIME_N_BODY

OP_MEMORY_BODY_FWD_2:
        B    OP_MEMORY_BODY

; ----------------------------
; SUM
;
; input:
;   R0 = n
;   R1 = m
;
; output:
;   R0 = n + (n+1) + ... + m
;
; semantics:
;   if n > m, swap n and m
;   result is lower 16 bits if overflow occurs
; ----------------------------
OP_SUM_BODY:
; if R0 <= R1, keep order
        CMP  R0, R1
        BLE  SUM_ORDER_OK

; swap R0 and R1
        MOV  R3, R0
        MOV  R0, R1
        MOV  R1, R3

SUM_ORDER_OK:
        MOV  R4, R0         ; R4 = current
        LI   R3, 0          ; R3 = sum

SUM_LOOP:
        ADD  R3, R4         ; sum += current

        CMP  R4, R1
        BE   SUM_DONE       ; if current == end, done

        ADDI R4, 1
        B    SUM_LOOP

SUM_DONE:
        MOV  R0, R3
        B    SAVE_RESULT

; ----------------------------
; ISPRIME
;
; input:
;   R0 = n
;
; output:
;   R0 = 1 if n is prime
;   R0 = 0 otherwise
;
; note:
;   negative numbers, 0, 1 are not prime
; ----------------------------
OP_ISPRIME_BODY:
; if n < 2 -> false
        CMPI R0, 2
        BLT  PRIME_FALSE

; if n == 2 -> true
        CMPI R0, 2
        BE   PRIME_TRUE

; d = 2
        LI   R4, 2

PRIME_D_LOOP:
; if d >= n -> prime
        CMP  R4, R0
        BE   PRIME_TRUE

        BLT  PRIME_CHECK_DIVISIBLE

        ; normally not reached, but safe
        B    PRIME_TRUE

PRIME_CHECK_DIVISIBLE:
; R3 = remainder candidate = n
        MOV  R3, R0

PRIME_REM_LOOP:
        CMP  R3, R4
        BLT  PRIME_NOT_DIVISIBLE

        SUB  R3, R4
        B    PRIME_REM_LOOP

PRIME_NOT_DIVISIBLE:
; if remainder == 0, divisible -> false
        CMPI R3, 0
        BE   PRIME_FALSE

; d++
        ADDI R4, 1
        B    PRIME_D_LOOP

PRIME_TRUE:
        LI   R0, 1
        B    SAVE_RESULT

PRIME_FALSE:
        LI   R0, 0
        B    SAVE_RESULT

; ----------------------------
; FIBO
;
; input:
;   R0 = n
;
; output:
;   R0 = F(n)
;
; definition:
;   F(0)=0, F(1)=1, F(2)=1, ...
;
; note:
;   result is lower 16 bits if overflow occurs
; ----------------------------
OP_FIBO_BODY:
        ; if n < 0 -> error
        CMPI R0, 0
        BLT  INVALID_ARG

        ; if n == 0 -> 0
        CMPI R0, 0
        BE   FIBO_ZERO

        ; if n == 1 -> 1
        CMPI R0, 1
        BE   FIBO_ONE

        ; R1 = prev = F(0) = 0
        ; R3 = curr = F(1) = 1
        ; R4 = index = 1
        LI   R1, 0
        LI   R3, 1
        LI   R4, 1

FIBO_LOOP:
        CMP  R4, R0
        BE   FIBO_DONE

        ; next = prev + curr
        MOV  R5, R1
        ADD  R5, R3

        ; prev = curr
        MOV  R1, R3

        ; curr = next
        MOV  R3, R5

        ; index++
        ADDI R4, 1

        B    FIBO_LOOP

FIBO_DONE:
        MOV  R0, R3
        B    SAVE_RESULT

FIBO_ZERO:
        LI   R0, 0
        B    SAVE_RESULT

FIBO_ONE:
        LI   R0, 1
        B    SAVE_RESULT

; ----------------------------
; PRIME_N
;
; input:
;   R0 = n
;
; output:
;   R0 = nth prime
;
; definition:
;   PRIME_N(1)=2
;   PRIME_N(2)=3
;   PRIME_N(3)=5
;
; note:
;   very slow for large n
; ----------------------------
OP_PRIME_N_BODY:
        ; if n <= 0 -> error
        CMPI R0, 1
        BLT  INVALID_ARG

        ; R0 = target n
        ; R1 = candidate
        ; R3 = found_count
        LI   R1, 1          ; candidate starts from 1
        LI   R3, 0          ; found_count = 0

PRIME_N_CANDIDATE_LOOP:
        ADDI R1, 1          ; candidate++

        ; check if candidate is prime
        ; if candidate < 2 -> not prime
        CMPI R1, 2
        BLT  PRIME_N_NOT_PRIME

        ; if candidate == 2 -> prime
        CMPI R1, 2
        BE   PRIME_N_IS_PRIME

        ; divisor d = 2
        LI   R4, 2

PRIME_N_D_LOOP:
        ; if d == candidate -> prime
        CMP  R4, R1
        BE   PRIME_N_IS_PRIME

        ; if d > candidate, safety true
        ; normally not reached
        ; if d < candidate, check divisibility
        BLT  PRIME_N_CHECK_DIVISIBLE

        B    PRIME_N_IS_PRIME

PRIME_N_CHECK_DIVISIBLE:
        ; R5 = remainder candidate = candidate
        MOV  R5, R1

PRIME_N_REM_LOOP:
        CMP  R5, R4
        BLT  PRIME_N_NOT_DIVISIBLE

        SUB  R5, R4
        B    PRIME_N_REM_LOOP

PRIME_N_NOT_DIVISIBLE:
        ; if remainder == 0, divisible -> not prime
        CMPI R5, 0
        BE   PRIME_N_NOT_PRIME

        ; d++
        ADDI R4, 1
        B    PRIME_N_D_LOOP

PRIME_N_IS_PRIME:
        ADDI R3, 1          ; found_count++

        CMP  R3, R0
        BE   PRIME_N_DONE

        B    PRIME_N_CANDIDATE_LOOP

PRIME_N_NOT_PRIME:
        B    PRIME_N_CANDIDATE_LOOP

PRIME_N_DONE:
        MOV  R0, R1
        B    SAVE_RESULT

; ----------------------------
; MEMORY OPERATIONS
;
; operator:
;   R2 = 12 MS
;   R2 = 13 MR
;   R2 = 14 MADD
;   R2 = 15 MSUB
;   R2 = 16 MC
;
; input:
;   R0 = accumulator
;   next IN = memory address 0..15
;
; actual address:
;   data[16 + addr]
;
; output:
;   MS:
;       memory[addr] = R0
;       R0 unchanged
;   MR:
;       R0 = memory[addr]
;   MADD:
;       memory[addr] = memory[addr] + R0
;       R0 = memory[addr]
;   MSUB:
;       memory[addr] = memory[addr] - R0
;       R0 = memory[addr]
;   MC:
;       memory[addr] = 0
;       R0 unchanged
; ----------------------------
READ_OP_BACK_4:
        B    READ_OP_BACK_3

OP_MEMORY_BODY:
        IN   R1             ; R1 = user memory address 0..15

        ; addr < 0 -> error
        CMPI R1, 0
        BLT  MEM_ADDR_INVALID

        ; addr <= 15 -> OK
        CMPI R1, 15
        BLE  MEM_ADDR_OK

        B    MEM_ADDR_INVALID

MEM_ADDR_OK:
        ADDI R1, 16         ; R1 = actual address = 16 + addr

        CMPI R2, 12
        BE   MEM_STORE

        CMPI R2, 13
        BE   MEM_RECALL

        CMPI R2, 14
        BE   MEM_ADD

        CMPI R2, 15
        BE   MEM_SUB

        CMPI R2, 16
        BE   MEM_CLEAR

        B    INVALID_OP

; ----------------------------
; MS: memory[addr] = accumulator
; ----------------------------
MEM_STORE:
        ST   R0, 0(R1)
        B    MEM_SAVE_RESULT

; ----------------------------
; MR: accumulator = memory[addr]
; ----------------------------
MEM_RECALL:
        LD   R0, 0(R1)
        B    MEM_SAVE_RESULT

; ----------------------------
; MADD: memory[addr] += accumulator
; result becomes new memory value
; ----------------------------
MEM_ADD:
        LD   R3, 0(R1)
        ADD  R3, R0
        ST   R3, 0(R1)
        MOV  R0, R3
        B    MEM_SAVE_RESULT

; ----------------------------
; MSUB: memory[addr] -= accumulator
; result becomes new memory value
; ----------------------------
MEM_SUB:
        LD   R3, 0(R1)
        SUB  R3, R0
        ST   R3, 0(R1)
        MOV  R0, R3
        B    MEM_SAVE_RESULT

; ----------------------------
; MC: memory[addr] = 0
; accumulator unchanged
; ----------------------------
MEM_CLEAR:
        LI   R3, 0
        ST   R3, 0(R1)
        B    MEM_SAVE_RESULT

; ----------------------------
; memory address error
; ----------------------------
MEM_ADDR_INVALID:
        LI   R5, 4          ; ERR = 4, invalid memory address
        ST   R5, 2(R6)
        OUT  R5
        HLT

; ----------------------------
; save after memory operation
; ----------------------------
MEM_SAVE_RESULT:
        LI   R5, 0
        ST   R5, 2(R6)      ; ERR = 0
        ST   R0, 0(R6)      ; ANS = accumulator
        OUT  R0
        B    READ_OP_BACK_4


; ----------------------------
; save and continue
; ----------------------------
SAVE_RESULT:
        LI   R5, 0
        ST   R5, 2(R6)      ; ERR = 0
        ST   R0, 0(R6)      ; ANS = accumulator
        OUT  R0             ; show intermediate result
        B    READ_OP_BACK_4

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

; ----------------------------
; invalid argument
; ----------------------------
INVALID_ARG:
        LI   R5, 3          ; ERR = 3, invalid argument
        ST   R5, 2(R6)
        OUT  R5
        HLT
