; max_text.s
; データメモリ上の data[0..7] の最大値を R3 に求めて OUT する
; data はデータメモリの 0 番地から置く想定

        LI   R0, 0          ; R0 = データメモリ上の配列先頭アドレス
        LI   R1, 8          ; R1 = 要素数
        LI   R7, 0          ; R7 = 0。ダミー演算用

        LD   R3, 0(R0)      ; R3 = min = data[0]
        ADDI R0, 1          ; R0 = &data[1]
        SUBI R1, 1          ; 残り要素数 = N - 1

check:
        ADD  R5, R7         ; ★ loop の LD の4つ前にある演算命令
        CMPI R1, 0          ; 残り要素数 == 0 ?
        B    0              ; 比較→無関係処理→条件分岐 のスペーサ
        BE   done           ; 残り0なら終了

loop:
        LD   R2, 0(R0)      ; R2 = *R0

        ADDI R0, 1          ; LD-use回避
        SUBI R1, 1          ; LD-use回避
        ADD  R5, R7         ; LD-use回避用ダミー演算

        CMP  R2, R3         ; current - min 
        B    0              ; 比較→無関係処理→条件分岐 のスペーサ
        BLT  update_max     ; if current < min then update

        B    check

update_max:
        MOV  R3, R2         ; max = current
        B    check

done:
        OUT  R3
        HLT