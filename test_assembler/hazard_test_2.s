; hazard_test2_flag_branch_text.s
;
; expected:
;   port0 = 0005  ; R2 = 5 checks passed
;   port6 = 0072
;   port7 = unchanged

        LI   R2, 0

        LI   R0, 3
        LI   R1, 5

        ; CMP -> BLT direct, taken
        CMP  R0, R1         ; 3 < 5
        BLT  T2_A_OK

        LI   R5, 21
        OUT  R2, 0
        OUT  R5, 7
        HLT

T2_A_OK:
        ADDI R2, 1

        ; CMP -> BLT direct, not taken
        CMP  R1, R0         ; 5 < 3 is false
        BLT  T2_FAIL_22

        ADDI R2, 1

        ; CMPI -> BE direct, taken
        CMPI R2, 2
        BE   T2_B_OK

        LI   R5, 23
        OUT  R2, 0
        OUT  R5, 7
        HLT

T2_B_OK:
        ADDI R2, 1

        ; CMPI -> BNE direct, taken
        CMPI R2, 4          ; R2 is 3, so R2 != 4
        BNE  T2_C_OK

        LI   R5, 24
        OUT  R2, 0
        OUT  R5, 7
        HLT

T2_C_OK:
        ADDI R2, 1

        ; CMPI -> BLE direct, taken by equal
        CMPI R2, 4
        BLE  T2_D_OK

        LI   R5, 25
        OUT  R2, 0
        OUT  R5, 7
        HLT

T2_D_OK:
        ADDI R2, 1

        ; CMPI -> BLE direct, not taken
        CMPI R2, 4          ; 5 <= 4 is false
        BLE  T2_FAIL_26

T2_PASS:
        LI   R5, 0x72
        OUT  R2, 0
        OUT  R5, 6
        HLT

T2_FAIL_22:
        LI   R5, 22
        OUT  R2, 0
        OUT  R5, 7
        HLT

T2_FAIL_26:
        LI   R5, 26
        OUT  R2, 0
        OUT  R5, 7
        HLT