;- ==========================================
;- Array Order Detection + Fast Paths
;- ==========================================
    LUI R2, 0x04        ; R2 = ptr = 0x0400
    LUI R3, 0x08        ; R3 = end = 0x0800

    LD  R4, 0(R2)       ; R4 = prev
    ADDI R2, 1          ; fill LD-use

state_0_loop:
    CMP R2, R3
    LD  R5, 0(R2)       ; safe speculative read / fills CMP->BE
    BE  done_asc

    CMP R4, R5
    NOP
    BLT state_asc_init  ; prev < curr

    CMP R5, R4
    NOP
    BLT done_desc       ; curr < prev

    MOV R4, R5
    ADDI R2, 1
    B   state_0_loop

state_asc_init:
    MOV R4, R5
    ADDI R2, 1
    MOV R7, R3
    SUBI R7, 2          ; R7 = tail-2 start address
state_asc_loop:
    CMP R2, R7
    LD  R5, 0(R2)
    BE  state_asc_last
    LD  R6, 1(R2)       ; second element

    CMP R5, R4          ; first >= prev ?
    LD  R1, 2(R2)       ; third element / fills CMP->BLT
    BLT radix_sort_start

    CMP R6, R5          ; second >= first ?
    LD  R0, 3(R2)       ; fourth element / fills CMP->BLT
    BLT radix_sort_start

    CMP R1, R6          ; third >= second ?
    LD  R5, 4(R2)       ; safe prefetch / fills CMP->BLT
    BLT radix_sort_start

    CMP R0, R1          ; fourth >= third ?
    LD  R6, 5(R2)       ; safe prefetch / fills CMP->BLT
    BLT radix_sort_start

    MOV R4, R0          ; prev = fourth
    ADDI R2, 4
    B   state_asc_loop

state_asc_last:
    LD  R6, 1(R2)
    CMP R5, R4
    NOP
    BLT radix_sort_start
    CMP R6, R5
    NOP
    BLT radix_sort_start
    HLT

done_asc:
    HLT

;- ------------------------------------------
;- Descending candidate:
;- verify descending order while reversing.
;- If a violation is found, the array is still a permutation,
;- so falling back to radix sort is safe.
;- ------------------------------------------
done_desc:
    LUI R2, 0x04        ; left = 0x0400
    LUI R3, 0x08
    SUBI R3, 1          ; right = 0x07FF

rev_check_loop:
    CMP R3, R2
    LD  R4, 0(R2)       ; A[left]
    BLE rev_done

    LD  R5, 1(R2)       ; A[left + 1]
    LD  R7, 0(R3)       ; A[right]

    CMP R4, R5          ; A[left] >= A[left + 1] ?
    LD  R6, 2(R2)       ; A[left + 2] / fills CMP->BLT
    BLT radix_sort_start

    CMP R5, R6          ; A[left + 1] >= A[left + 2] ?
    LD  R1, -1(R3)      ; A[right - 1] / fills CMP->BLT
    BLT radix_sort_start

    CMP R1, R7          ; A[right - 1] >= A[right] ?
    LD  R0, -2(R3)      ; A[right - 2] / fills CMP->BLT
    BLT radix_sort_start

    CMP R0, R1          ; A[right - 2] >= A[right - 1] ?
    NOP
    BLT radix_sort_start

    ST  R4, 0(R3)
    ST  R7, 0(R2)
    ST  R5, -1(R3)
    ST  R1, 1(R2)

    ADDI R2, 2
    SUBI R3, 2
    B   rev_check_loop

rev_done:
    HLT

;- ==========================================
;- Radix Sort, 8-bit digits
;- ==========================================
radix_sort_start:
    LI R0, 0
    LI R4, 1
    SLL R4, 8           ; R4 = 0x0100, lower bucket base

    LI R7, 0x7F
    ADDI R7, 0x7F
    ADDI R7, 1          ; R7 = 0x00FF, lower-byte mask

;- Pass 1: build lower/upper histograms
    MOV R2, R4
    MOV R3, R4
    ADD R3, R4          ; R3 = 0x0200
    LI R5, 3
    SLL R5, 8           ; R5 = 0x0300

init_buckets_1:
    ADDI R2, 4
    ADDI R3, 4
    ST R0, -4(R2)
    ST R0, -4(R3)
    ST R0, -3(R2)
    ST R0, -3(R3)
    ST R0, -2(R2)
    ST R0, -2(R3)
    ST R0, -1(R2)
    CMP R3, R5
    ST R0, -1(R3)
    BNE init_buckets_1

    LUI R2, 0x04
    LUI R3, 0x08
    MOV R0, R4
    ADD R0, R4          ; R0 = 0x0200, upper bucket base
    LD R1, 0(R2)        ; first source prefetch

loop_hist_1:
    ; element 1
    ADDI R2, 1
    MOV R6, R1
    AND R1, R7
    ADD R1, R4
    LD R5, 0(R1)
    SRL R6, 8
    ADDI R5, 1
    ST R5, 0(R1)
    ADD R6, R0
    LD R5, 0(R6)
    LD R1, 0(R2)        ; second source prefetch
    ADDI R5, 1
    ST R5, 0(R6)

    ; element 2
    ADDI R2, 1
    MOV R6, R1
    AND R1, R7
    ADD R1, R4
    LD R5, 0(R1)
    SRL R6, 8
    ADDI R5, 1
    ST R5, 0(R1)
    ADD R6, R0
    LD R5, 0(R6)
    LD R1, 0(R2)        ; next first source prefetch
    ADDI R5, 1
    ST R5, 0(R6)

    ; element 3
    ADDI R2, 1
    MOV R6, R1
    AND R1, R7
    ADD R1, R4
    LD R5, 0(R1)
    SRL R6, 8
    ADDI R5, 1
    ST R5, 0(R1)
    ADD R6, R0
    LD R5, 0(R6)
    LD R1, 0(R2)
    ADDI R5, 1
    ST R5, 0(R6)

    ; element 4
    ADDI R2, 1
    MOV R6, R1
    AND R1, R7
    ADD R1, R4
    LD R5, 0(R1)
    SRL R6, 8
    ADDI R5, 1
    ST R5, 0(R1)
    ADD R6, R0
    LD R5, 0(R6)
    LD R1, 0(R2)
    ADDI R5, 1
    CMP R2, R3
    ST R5, 0(R6)
    BNE loop_hist_1

;- Prefix sum for lower buckets, 4 buckets/loop
    LUI R1, 0x08        ; destination base B
    MOV R2, R4
    MOV R3, R0          ; 0x0200
    LD R5, 0(R2)

loop_sum_1:
    ADDI R2, 1
    ST R1, -1(R2)
    ADD R1, R5
    LD R5, 0(R2)

    ADDI R2, 1
    ST R1, -1(R2)
    ADD R1, R5
    LD R5, 0(R2)

    ADDI R2, 1
    ST R1, -1(R2)
    ADD R1, R5
    LD R5, 0(R2)

    ADDI R2, 1
    ST R1, -1(R2)
    ADD R1, R5
    CMP R2, R3
    LD R5, 0(R2)
    BNE loop_sum_1

;- Distribute by lower byte, A -> B
    LUI R2, 0x04
    LUI R3, 0x08
    LD R5, 0(R2)

loop_dist_1:
    MOV R6, R5
    AND R6, R7
    ADD R6, R4
    LD R1, 0(R6)
    LD R0, 1(R2)        ; second source prefetch, fills LD-use
    ST R5, 0(R1)
    ADDI R1, 1
    ST R1, 0(R6)

    MOV R6, R0
    AND R6, R7
    ADD R6, R4
    LD R1, 0(R6)
    LD R5, 2(R2)        ; next first source prefetch
    ST R0, 0(R1)
    ADDI R1, 1
    ADDI R2, 2
    CMP R2, R3
    ST R1, 0(R6)
    BNE loop_dist_1

;- Pass 2: prefix sum for upper byte, signed order
pass2_prefix_start:
    LUI R1, 0x04        ; destination base A
    LI R5, 1
    SLL R5, 7           ; R5 = 128

    MOV R2, R4
    ADD R2, R4
    ADD R2, R5          ; R2 = 0x0280
    LI R3, 3
    SLL R3, 8           ; R3 = 0x0300
    LD R6, 0(R2)

loop_sum_neg:
    ADDI R2, 1
    ST R1, -1(R2)
    ADD R1, R6
    LD R6, 0(R2)

    ADDI R2, 1
    ST R1, -1(R2)
    ADD R1, R6
    LD R6, 0(R2)

    ADDI R2, 1
    ST R1, -1(R2)
    ADD R1, R6
    LD R6, 0(R2)

    ADDI R2, 1
    ST R1, -1(R2)
    ADD R1, R6
    CMP R2, R3
    LD R6, 0(R2)
    BNE loop_sum_neg

    MOV R2, R4
    ADD R2, R4          ; R2 = 0x0200
    MOV R3, R2
    ADD R3, R5          ; R3 = 0x0280
    LD R6, 0(R2)

loop_sum_pos:
    ADDI R2, 1
    ST R1, -1(R2)
    ADD R1, R6
    LD R6, 0(R2)

    ADDI R2, 1
    ST R1, -1(R2)
    ADD R1, R6
    LD R6, 0(R2)

    ADDI R2, 1
    ST R1, -1(R2)
    ADD R1, R6
    LD R6, 0(R2)

    ADDI R2, 1
    ST R1, -1(R2)
    ADD R1, R6
    CMP R2, R3
    LD R6, 0(R2)
    BNE loop_sum_pos

;- Distribute by upper byte, B -> A
    LUI R2, 0x08
    LUI R3, 0x0C
    MOV R7, R4
    ADD R7, R4          ; R7 = 0x0200, upper bucket base
    LD R5, 0(R2)

loop_dist_2:
    ; element 1
    MOV R6, R5
    SRL R6, 8
    ADD R6, R7
    LD R1, 0(R6)
    LD R4, 1(R2)        ; second source prefetch
    ST R5, 0(R1)
    ADDI R1, 1
    ST R1, 0(R6)

    ; element 2
    MOV R6, R4
    SRL R6, 8
    ADD R6, R7
    LD R1, 0(R6)
    LD R5, 2(R2)        ; third source prefetch
    ST R4, 0(R1)
    ADDI R1, 1
    ST R1, 0(R6)

    ; element 3
    MOV R6, R5
    SRL R6, 8
    ADD R6, R7
    LD R1, 0(R6)
    LD R4, 3(R2)        ; fourth source prefetch
    ST R5, 0(R1)
    ADDI R1, 1
    ST R1, 0(R6)

    ; element 4
    MOV R6, R4
    SRL R6, 8
    ADD R6, R7
    LD R1, 0(R6)
    LD R5, 4(R2)        ; next first source prefetch
    ST R4, 0(R1)
    ADDI R1, 1
    ADDI R2, 4
    CMP R2, R3
    ST R1, 0(R6)
    BNE loop_dist_2

    HLT
