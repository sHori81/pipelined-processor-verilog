;- ==========================================
;- Array Order Detection (State Machine Early Exit)
;- ==========================================
    LUI R2, 0x04    ; R2 = 0x0400 (ptr)
    LUI R3, 0x08    ; R3 = 0x0800 (end ptr)
    
    LD  R4, 0(R2)   ; R4 = prev
    ADDI R2, 1      ; fill LD-use
    
state_0_loop:
    CMP R2, R3
    LD  R5, 0(R2)   ; safe speculative read / fills CMP->BE
    BE  done_asc    ; 全部同じ値なら昇順(ソート済み)扱い
    
    CMP R4, R5      ; R4(prev) - R5(curr)
    NOP
    BLT state_asc_init ; prev < curr (昇順) なら 昇順専用モードへ
    
    CMP R5, R4      ; R5(curr) - R4(prev)
    NOP
    BLT state_desc_init ; curr < prev (降順) なら 降順専用モードへ
    
    ; prev == curr の場合は state 0 を継続
    MOV R4, R5
    ADDI R2, 1
    B   state_0_loop

; ;--;--;--;--;--------------------
; 昇順専用判定ループ (超高速化)
; ---------------------------------
state_asc_init:
    MOV R4, R5      ; prev = curr
    ADDI R2, 1
state_asc_loop:
    CMP R2, R3
    LD  R5, 0(R2)   ; safe speculative read / fills CMP->BE
    BE  done_asc    ; 最後まで到達で昇順完了(即終了)
    
    CMP R5, R4      ; R5(curr) - R4(prev)
    NOP
    BLT radix_sort_start ; curr < prev になったらランダム確定！即ソートへ
    
    MOV R4, R5
    ADDI R2, 1
    B   state_asc_loop

; ---------------------------------
; 🚀 降順専用判定ループ (超高速化)
; ---------------------------------
state_desc_init:
    MOV R4, R5
    ADDI R2, 1
state_desc_loop:
    CMP R2, R3
    LD  R5, 0(R2)   ; safe speculative read / fills CMP->BE
    BE  done_desc   ; 最後まで到達で降順完了(反転処理へ)
    
    CMP R4, R5      ; R4(prev) - R5(curr)
    NOP
    BLT radix_sort_start ; prev < curr になったらランダム確定！即ソートへ
    
    MOV R4, R5
    ADDI R2, 1
    B   state_desc_loop

; ---------------------------------
; 判定完了後の処理
; ---------------------------------
done_asc:
    HLT             ; 昇順なら何もしないで最速終了！

done_desc:
    ; 降順だった場合の配列反転処理 (Reverse)
    LUI R2, 0x04    ; R2 = left = 0x0400
    
    ; R3 = right = 0x07FF
    LUI R3, 0x08
    LI  R1, 1
    SUB R3, R1      ; R3 = 0x07FF
    
    
rev_loop:
    CMP R3, R2      ; right - left
    LD  R4, 0(R2)   ; safe speculative read / fills CMP->BLE
    BLE rev_done    ; right <= left で完了
    
    LD  R5, 0(R3)   ; A[right]
    ST  R4, 0(R3)
    ST  R5, 0(R2)
    
    ADDI R2, 1      ; left++
    SUB R3, R1      ; right--
    B   rev_loop

rev_done:
    HLT             ; 反転完了後、最速終了！

radix_sort_start:
;-- ==========================================
;-- Radix Sort (ランダムデータ用)
;-- ==========================================
    LI R4, 1
    SLL R4, 8       ; R4 = 0x0100 (Bucket base)
    
    LI R7, 0x7F     ; R7 = 0x007F (127)
    ADDI R7, 0x7F   ; R7 = 0x00FE (254)
    ADDI R7, 1      ; R7 = 0x00FF (Mask)

;-- Pass 1: Lower 8 bits (A -> B)
    MOV R2, R4
    MOV R3, R4
    ADD R3, R4      ; R3 = 0x0200
    LI R5, 3
    SLL R5, 8       ; R5 = 0x0300
init_buckets_1:
    ADDI R2, 1
    ADDI R3, 1
    CMP R3, R5
    ST R0, -1(R2)
    ST R0, -1(R3)
    BNE init_buckets_1

    LUI R2, 0x04
    LUI R3, 0x08
loop_hist_1:
    ; ★無駄な MOV R6, R5 を削除！直接 R6 にロードして最適化
    LD R6, 0(R2)
    ADDI R2, 1      ; fill LD-use
    MOV R1, R6
    AND R1, R7      ; lower byte
    ADD R1, R4      ; lower bucket base 0x0100
    LD R5, 0(R1)
    SRL R6, 8       ; fill LD-use / upper byte
    ADDI R5, 1
    ST R5, 0(R1)
    ADD R6, R4
    ADD R6, R4      ; upper bucket base 0x0200
    LD R5, 0(R6)
    LD R1, 0(R2)    ; prefetch next source / fill LD-use
    ADDI R5, 1
    ST R5, 0(R6)

    ADDI R2, 1      ; fill prefetch LD-use
    MOV R6, R1
    AND R1, R7      ; lower byte
    ADD R1, R4      ; lower bucket base 0x0100
    LD R5, 0(R1)
    SRL R6, 8       ; fill LD-use / upper byte
    ADDI R5, 1
    ST R5, 0(R1)
    ADD R6, R4
    ADD R6, R4      ; upper bucket base 0x0200
    LD R5, 0(R6)
    NOP
    ADDI R5, 1
    CMP R2, R3
    ST R5, 0(R6)
    BNE loop_hist_1

    LUI R1, 0x08    ; Dest base B
    MOV R2, R4
    LI R3, 2
    SLL R3, 8
    LD R5, 0(R2)
loop_sum_1:
    ADDI R2, 1      ; fill LD-use
    ST R1, -1(R2)
    ADD R1, R5
    LD R5, 0(R2)
    ADDI R2, 1      ; fill LD-use
    ST R1, -1(R2)
    ADD R1, R5
    CMP R2, R3
    LD R5, 0(R2)    ; prefetch next bucket / fills CMP->BNE
    BNE loop_sum_1

    LUI R2, 0x04
    LUI R3, 0x08
loop_dist_1:
    LD R5, 0(R2)
    ADDI R2, 1      ; fill LD-use
    MOV R6, R5
    AND R6, R7
    ADD R6, R4
    LD R1, 0(R6)
    NOP
    ST R5, 0(R1)
    ADDI R1, 1
    ST R1, 0(R6)
    LD R5, 0(R2)
    ADDI R2, 1      ; fill LD-use
    MOV R6, R5
    AND R6, R7
    ADD R6, R4
    LD R1, 0(R6)
    NOP
    ST R5, 0(R1)
    ADDI R1, 1
    CMP R2, R3
    ST R1, 0(R6)
    BNE loop_dist_1

;-- Pass 2: Upper 8 bits (B -> A)
    ; ★無駄な MOV R6, R5 を削除！直接 R6 にロード
pass2_prefix_start:
    LUI R1, 0x04    ; Dest base A
    LI R5, 1
    SLL R5, 7       ; 128
    
    MOV R2, R4
    ADD R2, R4      ; 0x0200
    ADD R2, R5      ; 0x0280
    LI R3, 3
    SLL R3, 8       ; 0x0300
    LD R6, 0(R2)
loop_sum_neg:
    ADDI R2, 1      ; fill LD-use
    ST R1, -1(R2)
    ADD R1, R6
    LD R6, 0(R2)
    ADDI R2, 1      ; fill LD-use
    ST R1, -1(R2)
    ADD R1, R6
    CMP R2, R3
    LD R6, 0(R2)    ; prefetch next bucket / fills CMP->BNE
    BNE loop_sum_neg

    MOV R2, R4
    ADD R2, R4      ; 0x0200
    MOV R3, R2
    ADD R3, R5      ; 0x0280
    LD R6, 0(R2)
loop_sum_pos:
    ADDI R2, 1      ; fill LD-use
    ST R1, -1(R2)
    ADD R1, R6
    LD R6, 0(R2)
    ADDI R2, 1      ; fill LD-use
    ST R1, -1(R2)
    ADD R1, R6
    CMP R2, R3
    LD R6, 0(R2)    ; prefetch next bucket / fills CMP->BNE
    BNE loop_sum_pos

    LUI R2, 0x08
    LUI R3, 0x0C
    MOV R7, R4
    ADD R7, R4      ; R7 = upper bucket base 0x0200
    LD R5, 0(R2)
loop_dist_2:
    ADDI R2, 1      ; fill LD-use
    MOV R6, R5
    SRL R6, 8
    ADD R6, R7      ; upper bucket base 0x0200
    LD R1, 0(R6)
    LD R4, 0(R2)    ; prefetch second source / fill LD-use
    ST R5, 0(R1)
    ADDI R1, 1
    ST R1, 0(R6)
    ADDI R2, 1      ; fill LD-use
    MOV R6, R4
    SRL R6, 8
    ADD R6, R7      ; upper bucket base 0x0200
    LD R1, 0(R6)
    LD R5, 0(R2)    ; prefetch next first source / fill LD-use
    ST R4, 0(R1)
    ADDI R1, 1
    CMP R2, R3
    ST R1, 0(R6)
    BNE loop_dist_2

    HLT
