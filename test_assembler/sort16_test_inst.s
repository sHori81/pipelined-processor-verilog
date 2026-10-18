; 【初期化】
LI R0, 0
LI R1, 1

; 【アウター・ループ（16周）】
OUTER_LOOP:
    CMPI R1, 0
    NOP
    BLT IS_SIGN
    LI R7, 0
    B INIT_PTR
    IS_SIGN:
        LI R7, 1

; (ポインタ初期化)
INIT_PTR:
    LI R2, 0
    LI R3, 16
    LI R4, 32

; 【インナー・ループ：配列の振り分け】
INNER_LOOP:
    NOP
    LD R5, 0(R2)
    NOP
    MOV R6, R5
    AND R6, R1
    CMPI R6, 0
    NOP
    BNE IS_ONE

; (IS_ZERO)
    CMPI R7, 0
    NOP
    BE PUT_HEAD0
    B PUT_HEAD1

; (IS_ONE)
IS_ONE:
    CMPI R7, 1
    NOP
    BNE PUT_HEAD1
; (符号ならそのままPUT_HEAD0へ落ちる)

; (PUT_HEAD0)
PUT_HEAD0:
    ST R5, 0(R3)
    ADDI R3, 1
    B NEXT_ELEM

; (PUT_HEAD1)
PUT_HEAD1:
    ST R5, 0(R4)
    ADDI R4, 1

; (NEXT_ELEM: 16個の終了判定)
NEXT_ELEM:
    ADDI R2, 1
    CMPI R2, 16
    NOP
    BNE INNER_LOOP

; 【配列の書き戻しフェーズ】
    LI R2, 0
    LI R6, 16

; (0バッファの書き戻し)
COPY0_LOOP:
    CMP R6, R3
    NOP
    BE COPY1_INIT
    LD R5, 0(R6)
    NOP
    ST R5, 0(R2)
    ADDI R6, 1
    ADDI R2, 1
    B COPY0_LOOP

; (1バッファの書き戻し)
COPY1_INIT:
    LI R6, 32
COPY1_LOOP:
    CMP R6, R4
    NOP
    BE END_OUTER
    LD R5, 0(R6)
    NOP
    ST R5, 0(R2)
    ADDI R6, 1
    ADDI R2, 1
    B COPY1_LOOP

; 【アウター・ループ終了判定】
END_OUTER:
    SLL R1, 1
    NOP
    CMPI R1, 0
    NOP
    BNE OUTER_LOOP

; 完了停止
LUI R7, 0xFF
B HALT_LOOP
HALT_LOOP:
HLT