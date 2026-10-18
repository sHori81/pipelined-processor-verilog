; test3_hlt_fallthrough_text.s
;
; expected:
;   port0 = 003C
;   port1 = 0006
;   port6 = 0053
;   port7 = unchanged

        LI   R2, 60
        LI   R1, 6
        LI   R5, 83

        OUT  R2, 0
        OUT  R1, 1
        OUT  R5, 6
        HLT

        ; ここから下が実行されたらHLT処理がまだ壊れている
        LI   R5, 3
        OUT  R2, 0
        OUT  R1, 1
        OUT  R5, 7
        HLT