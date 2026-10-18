;- ==========================================
;- Array Order Detection (Early Exit)
;- ==========================================
    LUI R2, 0x04    ; R2 = 0x0400 (ptr)
    LUI R3, 0x08    ; R3 = 0x0800 (end ptr)
    LI  R6, 1       ; R6 = is_asc = 1 (昇順フラグ)
    LI  R7, 1       ; R7 = is_desc = 1 (降順フラグ)
    
    LD  R4, 0(R2)   ; R4 = prev (前の要素)
    NOP             ; Hazard avoid
    ADDI R2, 1
    
check_loop:
    CMP R2, R3
    NOP             ; Hazard avoid
    BE  check_done  ; 最後まで到達したら判定へ
    
    LD  R5, 0(R2)   ; R5 = curr (今の要素)
    NOP             ; Hazard avoid
    
    CMP R4, R5      ; prev と curr を比較 (R4 - R5)
    NOP             ; Hazard avoid
    BE  skip_flags  ; 同じ値ならフラグ維持
    BLT prev_less_curr ; prev < curr なら降順ではない
    
prev_greater_curr:  ; prev > curr なら昇順ではない
    LI  R6, 0       ; is_asc = 0
    B   check_both
    
prev_less_curr:
    LI  R7, 0       ; is_desc = 0
    
check_both:
    MOV R1, R0      ; R1 = 0
    ADD R1, R6
    ADD R1, R7      ; R1 = is_asc + is_desc
    CMP R1, R0
    NOP             ; Hazard avoid
    BE  radix_sort_start ; 昇順でも降順でもない（ランダム）なら検知を打ち切り即ソートへ！
    
skip_flags:
    MOV R4, R5      ; prev = curr に更新
    ADDI R2, 1
    B   check_loop
    
check_done:
    CMP R6, R0      ; 昇順フラグは消えたか？(is_asc == 0?)
    NOP             ; Hazard avoid
    BE  check_desc_and_reverse ; もし消えていれば(0)、降順なので反転処理へ
    
    ; ここに来た場合は昇順 (すでにソート済み)
    HLT             ; 最速で終了！(約1.2万サイクル)

check_desc_and_reverse:
    ; 降順 (Reverse Array) だった場合、配列の前後を入れ替える
    LUI R2, 0x04    ; R2 = left = 0x0400
    
    ; R3 = right = 0x07FF を安全に作る
    LUI R3, 0x07
    LI  R1, 0x7F
    ADDI R1, 0x7F
    ADDI R1, 1      ; R1 = 0xFF
    ADD R3, R1      ; R3 = 0x07FF
    
    LI  R1, 1       ; R1 = 1 (rightをマイナスする用)
    
rev_loop:
    CMP R3, R2      ; right - left
    NOP             ; Hazard avoid
    BLE rev_done    ; right <= left になったら反転完了
    
    LD  R4, 0(R2)   ; A[left] をロード
    NOP             ; Hazard avoid
    LD  R5, 0(R3)   ; A[right] をロード
    NOP             ; Hazard avoid
    
    ST  R5, 0(R2)   ; A[left] に A[right] を書き込み
    ST  R4, 0(R3)   ; A[right] に A[left] を書き込み
    
    ADDI R2, 1      ; left++
    SUB R3, R1      ; right;-
    
    B   rev_loop

rev_done:
    HLT             ; 反転完了、最速で終了！(約1.7万サイクル)


radix_sort_start:
;- ==========================================
;- Initialization for Radix Sort (ランダムデータ用)
;- ==========================================
    LI R4, 1
    SLL R4, 8       ; R4 = 0x0100 (Bucket base address)
    
    ; 符号拡張(Sign Extension)の罠を回避して安全に R7 = 0x00FF を作る
    LI R7, 0x7F     ; R7 = 0x007F (127)
    ADDI R7, 0x7F   ; R7 = 0x00FE (254)
    ADDI R7, 1      ; R7 = 0x00FF (255: Mask for lower 8 bits)

;- ==========================================
;- Pass 1: Lower 8 bits (Array A:0x0400 -> Array B:0x0800)
;- ==========================================
    MOV R2, R4      ; R2 = 0x0100
    LI R3, 2
    SLL R3, 8       ; R3 = 0x0200
init_buckets_1:
    ST R0, 0(R2)    ; R0 is always 0
    ADDI R2, 1
    CMP R2, R3
    NOP             ; Hazard avoid
    BNE init_buckets_1

    LUI R2, 0x04    ; R2 = 0x0400 (Source start)
    LUI R3, 0x08    ; R3 = 0x0800 (Source end)
loop_hist_1:
    LD R5, 0(R2)
    NOP             ; Hazard avoid
    MOV R6, R5
    AND R6, R7      ; Apply 0x00FF mask safely
    ADD R6, R4      ; Bucket address = 0x0100 + lower 8 bits
    LD R1, 0(R6)    
    NOP             ; Hazard avoid
    ADDI R1, 1      
    ST R1, 0(R6)    
    ADDI R2, 1
    CMP R2, R3
    NOP             ; Hazard avoid
    BNE loop_hist_1

    LUI R1, 0x08    ; R1 = 0x0800 (Destination base: Array B)
    MOV R2, R4      ; R2 = 0x0100
    LI R3, 2
    SLL R3, 8       ; R3 = 0x0200
loop_sum_1:
    LD R5, 0(R2)    
    NOP             ; Hazard avoid
    ST R1, 0(R2)    
    ADD R1, R5      ; Next pointer = current pointer + count
    ADDI R2, 1
    CMP R2, R3
    NOP             ; Hazard avoid
    BNE loop_sum_1

    LUI R2, 0x04    ; R2 = 0x0400
    LUI R3, 0x08    ; R3 = 0x0800
loop_dist_1:
    LD R5, 0(R2)
    NOP             ; Hazard avoid
    MOV R6, R5
    AND R6, R7      ; Extract lower 8 bits
    ADD R6, R4      
    LD R1, 0(R6)    ; Get destination address
    NOP             ; Hazard avoid
    ST R5, 0(R1)    ; Write to Array B
    ADDI R1, 1      
    ST R1, 0(R6)    
    ADDI R2, 1
    CMP R2, R3
    NOP             ; Hazard avoid
    BNE loop_dist_1


;- ==========================================
;- Pass 2: Upper 8 bits (Array B:0x0800 -> Array A:0x0400)
;- ==========================================
    MOV R2, R4      
    LI R3, 2
    SLL R3, 8       
init_buckets_2:
    ST R0, 0(R2)    
    ADDI R2, 1
    CMP R2, R3
    NOP             ; Hazard avoid
    BNE init_buckets_2

    LUI R2, 0x08    ; Array B start
    LUI R3, 0x0C    ; Array B end
loop_hist_2:
    LD R5, 0(R2)
    NOP             ; Hazard avoid
    MOV R6, R5
    SRL R6, 8       ; Extract upper 8 bits
    AND R6, R7      ; 安全対策
    ADD R6, R4      
    LD R1, 0(R6)    
    NOP             ; Hazard avoid
    ADDI R1, 1      
    ST R1, 0(R6)    
    ADDI R2, 1
    CMP R2, R3
    NOP             ; Hazard avoid
    BNE loop_hist_2

    LUI R1, 0x04    ; Array A base (0x0400)
    LI R5, 1
    SLL R5, 7       ; R5 = 128 (0x0080) for offset math
    
    MOV R2, R4      ; R2 = 0x0100
    ADD R2, R5      ; R2 = 0x0180 (Negative domain start)
    LI R3, 2
    SLL R3, 8       ; R3 = 0x0200 (Negative domain end)
loop_sum_neg:
    LD R6, 0(R2)    ; Use R6 so we don't overwrite R5
    NOP             ; Hazard avoid
    ST R1, 0(R2)    
    ADD R1, R6      
    ADDI R2, 1
    CMP R2, R3
    NOP             ; Hazard avoid
    BNE loop_sum_neg

    MOV R2, R4      ; R2 = 0x0100 (Positive domain start)
    MOV R3, R4
    ADD R3, R5      ; R3 = 0x0180 (Positive domain end, R5 is still 0x0080)
loop_sum_pos:
    LD R6, 0(R2)    
    NOP             ; Hazard avoid
    ST R1, 0(R2)    
    ADD R1, R6      
    ADDI R2, 1
    CMP R2, R3
    NOP             ; Hazard avoid
    BNE loop_sum_pos

    LUI R2, 0x08    ; Array B start
    LUI R3, 0x0C    ; Array B end
loop_dist_2:
    LD R5, 0(R2)
    NOP             ; Hazard avoid
    MOV R6, R5
    SRL R6, 8       
    AND R6, R7      
    ADD R6, R4      
    LD R1, 0(R6)    
    NOP             ; Hazard avoid
    ST R5, 0(R1)    ; Write data back to Array A (0x0400)
    ADDI R1, 1      
    ST R1, 0(R6)    
    ADDI R2, 1
    CMP R2, R3
    NOP             ; Hazard avoid
    BNE loop_dist_2

;- ==========================================
;- Finish
;- ==========================================
    HLT