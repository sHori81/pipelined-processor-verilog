;- ==========================================
;- Array Order Detection (State Machine Early Exit)
;- ==========================================
    LUI R2, 0x04    ; R2 = 0x0400 (ptr)
    LUI R3, 0x08    ; R3 = 0x0800 (end ptr)
    
    LD  R4, 0(R2)   ; R4 = prev
    NOP
    ADDI R2, 1
    
state_0_loop:
    CMP R2, R3
    NOP
    BE  done_asc    ; 全部同じ値なら昇順(ソート済み)扱い
    
    LD  R5, 0(R2)   ; R5 = curr
    NOP
    
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
; 🚀 昇順専用判定ループ (超高速化)
; ---------------------------------
state_asc_init:
    MOV R4, R5      ; prev = curr
    ADDI R2, 1
state_asc_loop:
    CMP R2, R3
    NOP
    BE  done_asc    ; 最後まで到達で昇順完了(即終了)
    
    LD  R5, 0(R2)
    NOP
    
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
    NOP
    BE  done_desc   ; 最後まで到達で降順完了(反転処理へ)
    
    LD  R5, 0(R2)
    NOP
    
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
    LUI R3, 0x07
    LI  R1, 0x7F
    ADDI R1, 0x7F
    ADDI R1, 1      ; R1 = 0xFF
    ADD R3, R1      ; R3 = 0x07FF
    
    LI  R1, 1       ; R1 = 1 (right減算用)
    
rev_loop:
    CMP R3, R2      ; right - left
    NOP
    BLE rev_done    ; right <= left で完了
    
    LD  R4, 0(R2)   ; A[left]
    NOP
    LD  R5, 0(R3)   ; A[right]
    NOP
    
    ST  R5, 0(R2)
    ST  R4, 0(R3)
    
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
    LI R3, 2
    SLL R3, 8
init_buckets_1:
    ST R0, 0(R2)
    ADDI R2, 1
    CMP R2, R3
    NOP
    BNE init_buckets_1

    LUI R2, 0x04
    LUI R3, 0x08
loop_hist_1:
    ; ★無駄な MOV R6, R5 を削除！直接 R6 にロードして最適化
    LD R6, 0(R2)
    NOP
    AND R6, R7      ; Apply mask
    ADD R6, R4      ; + Bucket base
    LD R1, 0(R6)
    NOP
    ADDI R1, 1
    ST R1, 0(R6)
    ADDI R2, 1
    CMP R2, R3
    NOP
    BNE loop_hist_1

    LUI R1, 0x08    ; Dest base B
    MOV R2, R4
    LI R3, 2
    SLL R3, 8
loop_sum_1:
    LD R5, 0(R2)
    NOP
    ST R1, 0(R2)
    ADD R1, R5
    ADDI R2, 1
    CMP R2, R3
    NOP
    BNE loop_sum_1

    LUI R2, 0x04
    LUI R3, 0x08
loop_dist_1:
    LD R5, 0(R2)
    NOP
    MOV R6, R5
    AND R6, R7
    ADD R6, R4
    LD R1, 0(R6)
    NOP
    ST R5, 0(R1)
    ADDI R1, 1
    ST R1, 0(R6)
    ADDI R2, 1
    CMP R2, R3
    NOP
    BNE loop_dist_1

;-- Pass 2: Upper 8 bits (B -> A)
    MOV R2, R4
    LI R3, 2
    SLL R3, 8
init_buckets_2:
    ST R0, 0(R2)
    ADDI R2, 1
    CMP R2, R3
    NOP
    BNE init_buckets_2

    LUI R2, 0x08
    LUI R3, 0x0C
loop_hist_2:
    ; ★無駄な MOV R6, R5 を削除！直接 R6 にロード
    LD R6, 0(R2)
    NOP
    SRL R6, 8
    AND R6, R7
    ADD R6, R4
    LD R1, 0(R6)
    NOP
    ADDI R1, 1
    ST R1, 0(R6)
    ADDI R2, 1
    CMP R2, R3
    NOP
    BNE loop_hist_2

    LUI R1, 0x04    ; Dest base A
    LI R5, 1
    SLL R5, 7       ; 128
    
    MOV R2, R4
    ADD R2, R5      ; 0x0180
    LI R3, 2
    SLL R3, 8       ; 0x0200
loop_sum_neg:
    LD R6, 0(R2)
    NOP
    ST R1, 0(R2)
    ADD R1, R6
    ADDI R2, 1
    CMP R2, R3
    NOP
    BNE loop_sum_neg

    MOV R2, R4      ; 0x0100
    MOV R3, R4
    ADD R3, R5      ; 0x0180
loop_sum_pos:
    LD R6, 0(R2)
    NOP
    ST R1, 0(R2)
    ADD R1, R6
    ADDI R2, 1
    CMP R2, R3
    NOP
    BNE loop_sum_pos

    LUI R2, 0x08
    LUI R3, 0x0C
loop_dist_2:
    LD R5, 0(R2)
    NOP
    MOV R6, R5
    SRL R6, 8
    AND R6, R7
    ADD R6, R4
    LD R1, 0(R6)
    NOP
    ST R5, 0(R1)
    ADDI R1, 1
    ST R1, 0(R6)
    ADDI R2, 1
    CMP R2, R3
    NOP
    BNE loop_dist_2

    HLT