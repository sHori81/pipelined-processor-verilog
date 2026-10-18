;- ==========================================
;- Initialization
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
;- 1. Initialize buckets (0x0100 to 0x01FF with 0)
    MOV R2, R4      ; R2 = 0x0100
    LI R3, 2
    SLL R3, 8       ; R3 = 0x0200
init_buckets_1:
    ADDI R2, 1
    CMP R2, R3
    ST R0, -1(R2)   ; R0 is always 0 / fills CMP->BNE
    BNE init_buckets_1

;- 2. Create Histogram (1024 items)
    LUI R2, 0x04    ; R2 = 0x0400 (Source start)
    LUI R3, 0x08    ; R3 = 0x0800 (Source end)
loop_hist_1:
    LD R5, 0(R2)
    ADDI R2, 1      ; fills LD-use
    MOV R6, R5
    AND R6, R7      ; Apply 0x00FF mask safely
    ADD R6, R4      ; Bucket address = 0x0100 + lower 8 bits
    LD R1, 0(R6)    
    NOP             ; Hazard avoid
    ADDI R1, 1      
    CMP R2, R3
    ST R1, 0(R6)    ; fills CMP->BNE
    BNE loop_hist_1

;- 3. Calculate Prefix Sums (Cumulative sum)
    LUI R1, 0x08    ; R1 = 0x0800 (Destination base: Array B)
    MOV R2, R4      ; R2 = 0x0100
    LI R3, 2
    SLL R3, 8       ; R3 = 0x0200
loop_sum_1:
    LD R5, 0(R2)    
    ADDI R2, 1      ; fills LD-use
    ST R1, -1(R2)
    ADD R1, R5      ; Next pointer = current pointer + count
    CMP R2, R3
    NOP             ; Hazard avoid
    BNE loop_sum_1

;- 4. Distribute Data (1024 items)
    LUI R2, 0x04    ; R2 = 0x0400
    LUI R3, 0x08    ; R3 = 0x0800
loop_dist_1:
    LD R5, 0(R2)
    ADDI R2, 1      ; fills LD-use
    MOV R6, R5
    AND R6, R7      ; Extract lower 8 bits
    ADD R6, R4      
    LD R1, 0(R6)    ; Get destination address
    NOP             ; Hazard avoid
    ST R5, 0(R1)    ; Write to Array B
    ADDI R1, 1      
    CMP R2, R3
    ST R1, 0(R6)    ; fills CMP->BNE
    BNE loop_dist_1


;- ==========================================
;- Pass 2: Upper 8 bits (Array B:0x0800 -> Array A:0x0400)
;- ==========================================
;- 1. Initialize buckets
    MOV R2, R4      
    LI R3, 2
    SLL R3, 8       
init_buckets_2:
    ADDI R2, 1
    CMP R2, R3
    ST R0, -1(R2)   ; fills CMP->BNE
    BNE init_buckets_2

;- 2. Create Histogram 
    LUI R2, 0x08    ; Array B start
    LUI R3, 0x0C    ; Array B end
loop_hist_2:
    LD R5, 0(R2)
    ADDI R2, 1      ; fills LD-use
    MOV R6, R5
    SRL R6, 8       ; Extract upper 8 bits
    AND R6, R7      ; ★安全対策: SRLがSRA扱いされてもマスクで防ぐ
    ADD R6, R4      
    LD R1, 0(R6)    
    NOP             ; Hazard avoid
    ADDI R1, 1      
    CMP R2, R3
    ST R1, 0(R6)    ; fills CMP->BNE
    BNE loop_hist_2

;- 3. Calculate Prefix Sums (Handling negative numbers)
    LUI R1, 0x04    ; Array A base (0x0400)
    LI R5, 1
    SLL R5, 7       ; R5 = 128 (0x0080) for offset math
    
    MOV R2, R4      ; R2 = 0x0100
    ADD R2, R5      ; R2 = 0x0180 (Negative domain start)
    LI R3, 2
    SLL R3, 8       ; R3 = 0x0200 (Negative domain end)
loop_sum_neg:
    LD R6, 0(R2)    ; Use R6 so we don't overwrite R5
    ADDI R2, 1      ; fills LD-use
    ST R1, -1(R2)
    ADD R1, R6      
    CMP R2, R3
    NOP             ; Hazard avoid
    BNE loop_sum_neg

    MOV R2, R4      ; R2 = 0x0100 (Positive domain start)
    MOV R3, R4
    ADD R3, R5      ; R3 = 0x0180 (Positive domain end, R5 is still 0x0080)
loop_sum_pos:
    LD R6, 0(R2)    ; Use R6
    ADDI R2, 1      ; fills LD-use
    ST R1, -1(R2)
    ADD R1, R6      
    CMP R2, R3
    NOP             ; Hazard avoid
    BNE loop_sum_pos

;- 4. Distribute Data 
    LUI R2, 0x08    ; Array B start
    LUI R3, 0x0C    ; Array B end
loop_dist_2:
    LD R5, 0(R2)
    ADDI R2, 1      ; fills LD-use
    MOV R6, R5
    SRL R6, 8       
    AND R6, R7      ; ★安全対策: マスクで確実に8ビット化
    ADD R6, R4      
    LD R1, 0(R6)    
    NOP             ; Hazard avoid
    ST R5, 0(R1)    ; Write data back to Array A (0x0400)
    ADDI R1, 1      
    CMP R2, R3
    ST R1, 0(R6)    ; fills CMP->BNE
    BNE loop_dist_2

;- ==========================================
;- Finish
;- ==========================================
    HLT
