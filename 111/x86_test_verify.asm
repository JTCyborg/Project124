; =========================================================================
; PERFECT COMMANDER 111 — СЕРВИСНЫЙ МОДУЛЬ ХОСТА ДЛЯ ВЕРИФИКАЦИИ ТЕСТОВ x86
; МОДУЛЬ: src/x86_test_verify.asm (СТРОГИЙ СИНТАКСИС ПОД ФЛАГ --DIRBOL)
; =========================================================================

X86_Verify_Current_Test:
        PUSH    BC
        PUSH    DE
        PUSH    HL
        LD      A, (X86_CPU_State)
        CP      1
        JP      NZ, .Failed
        LD      A, (Current_Test_ID)
        CP      55
        JP      Z, .Test56
        CP      56
        JP      Z, .Test57
        CP      57
        JP      Z, .Test58
        CP      58
        JP      Z, .Test59
        CP      59
        JP      Z, .Test60
        CP      60
        JP      Z, .Test61
        CP      61
        JP      Z, .Test62
        CP      62
        JP      Z, .Test63
        CP      63
        JP      Z, .Test64
        CP      64
        JP      Z, .Test65
        CP      65
        JP      Z, .Test66
        CP      66
        JP      Z, .Test67
        CP      67
        JP      Z, .Test68
        CP      68
        JP      Z, .Test69
        CP      69
        JP      Z, .Test70
        CP      70
        JP      Z, .Test71
        CP      71
        JP      Z, .Test72
        CP      72
        JP      Z, .Test73
        CP      73
        JP      Z, .Test74
        CP      74
        JP      Z, .Test75
        CP      75
        JP      Z, .Test76
        CP      76
        JP      Z, .Test77
        CP      77
        JP      Z, .Test78
        CP      78
        JP      Z, .Test79
        CP      79
        JP      Z, .Test80
        CP      80
        JP      Z, .Test81
        CP      81
        JP      Z, .Test82
        CP      82
        JP      Z, .Test83
        CP      83
        JP      Z, .Test84
        CP      84
        JP      Z, .Test85
        CP      85
        JP      Z, .Test86
        CP      86
        JP      Z, .Test87
        CP      87
        JP      Z, .Test88
        CP      88
        JP      Z, .Test89
        CP      89
        JP      Z, .Test90
        CP      90
        JP      Z, .Test91
        CP      91
        JP      Z, .Test92
        CP      92
        JP      Z, .Test93
        CP      93
        JP      Z, .Test94
        CP      94
        JP      Z, .Test95
        CP      95
        JP      Z, .Test96
        CP      96
        JP      Z, .Test97
        CP      97
        JP      Z, .Test98
        CP      98
        JP      Z, .Test99
        CP      99
        JP      Z, .Test100
        CP      100
        JP      Z, .Test101
        CP      101
        JP      Z, .Test102             
        CP      102
        JP      Z, .Test103             
        CP      103
        JP      Z, .Test104             
        CP      104
        JP      Z, .Test105             
        JP      .Failed

.Test56:
        LD      A, (X86_REG_FLAGS)
        BIT     0, A
        JP      NZ, .Failed
        JP      .Passed
.Test57:
        LD      A, (X86_REG_FLAGS + 1)
        BIT     2, A
        JP      NZ, .Failed
        JP      .Passed
.Test58:
        LD      HL, (X86_REG_AX)
        LD      DE, $00FF
        CALL    .CompareHLDE
        JP      NZ, .Failed
        LD      HL, (X86_REG_CX)
        LD      DE, $FFFB
        CALL    .CompareHLDE
        JP      NZ, .Failed
        JP      .Passed
.Test59:
        LD      A, (X86_REG_AX)
        CP      $80
        JP      NZ, .Failed
        LD      A, (X86_REG_FLAGS)
        BIT     3, A
        JP      Z, .Failed
        BIT     2, A
        JP      NZ, .Failed
        BIT     0, A
        JP      NZ, .Failed
        JP      .Passed
.Test60:
        LD      HL, (X86_REG_AX)
        LD      DE, $0010
        CALL    .CompareHLDE
        JP      NZ, .Failed
        LD      A, (X86_REG_CX)
        CP      4
        JP      NZ, .Failed
        JP      .Passed
.Test61:
        LD      HL, (X86_REG_AX)
        LD      DE, $FF80
        CALL    .CompareHLDE
        JP      NZ, .Failed
        LD      HL, (X86_REG_DX)
        LD      DE, $FFFF
        CALL    .CompareHLDE
        JP      NZ, .Failed
        JP      .Passed
.Test62:
        LD      A, (X86_REG_AX)
        CP      $14
        JP      NZ, .Failed
        LD      A, (X86_REG_FLAGS)
        BIT     4, A
        JP      Z, .Failed
        BIT     0, A
        JP      NZ, .Failed
        JP      .Passed
.Test63:
        LD      HL, (X86_REG_SI)
        LD      DE, $010D
        CALL    .CompareHLDE
        JP      NZ, .Failed
        LD      HL, (X86_REG_DI)
        LD      DE, $010F
        CALL    .CompareHLDE
        JP      NZ, .Failed
        LD      DE, $010D
        LD      IX, 0
        CALL    X86_Read_Byte_Segment
        CP      $5A
        JP      NZ, .Failed
        LD      DE, $010E
        LD      IX, 0
        CALL    X86_Read_Byte_Segment
        CP      $2A
        JP      NZ, .Failed
        JP      .Passed
.Test64:
        LD      HL, (X86_REG_CX)
        LD      DE, 0
        CALL    .CompareHLDE
        JP      NZ, .Failed
        LD      HL, (X86_REG_DI)
        LD      DE, 10
        CALL    .CompareHLDE
        JP      NZ, .Failed
        LD      DE, 9
        LD      IX, 0
        CALL    X86_Read_Byte_Segment
        OR      A
        JP      NZ, .Failed
        JP      .Passed
.Test65:
        LD      HL, (X86_REG_AX)
        LD      DE, $0021
        CALL    .CompareHLDE
        JP      NZ, .Failed
        JP      .Passed
.Test66:
        LD      HL, (X86_REG_AX)
        LD      DE, $0280
        CALL    .CompareHLDE
        JP      NZ, .Failed
        JP      .Passed
.Test67:
        LD      A, (X86_REG_AX)
        CP      $0F
        JP      NZ, .Failed
        LD      A, (X86_REG_FLAGS)
        BIT     2, A
        JP      Z, .Failed
        BIT     0, A
        JP      NZ, .Failed
        JP      .Passed
.Test68:
        LD      HL, (X86_REG_SP)
        LD      DE, $0FFC
        CALL    .CompareHLDE
        JP      NZ, .Failed
        JP      .Passed
.Test69:
        LD      HL, (X86_REG_AX)
        LD      DE, $0103
        CALL    .CompareHLDE
        JP      NZ, .Failed
        LD      A, (X86_REG_FLAGS)
        BIT     0, A
        JP      Z, .Failed
        BIT     4, A
        JP      Z, .Failed
        JP      .Passed
.Test70:
        LD      HL, (X86_REG_AX)
        LD      DE, $0205               
        CALL    .CompareHLDE
        JP      NZ, .Failed
        JP      .Passed
.Test71:
        LD      A, (X86_REG_AX)
        CP      3
        JP      NZ, .Failed
        LD      A, (X86_REG_FLAGS)
        BIT     0, A
        JP      Z, .Failed
        LD      A, (X86_REG_FLAGS + 1)
        BIT     3, A
        JP      Z, .Failed
        JP      .Passed
.Test72:
        LD      A, (X86_REG_AX)
        CP      1
        JP      NZ, .Failed
        LD      A, (X86_REG_FLAGS)
        BIT     0, A
        JP      NZ, .Failed
        JP      .Passed
.Test73:
        LD      HL, (X86_REG_SI)
        LD      DE, $0111
        CALL    .CompareHLDE
        JP      NZ, .Failed
        LD      HL, (X86_REG_DI)
        LD      DE, $0115
        CALL    .CompareHLDE
        JP      NZ, .Failed
        LD      A, (X86_REG_FLAGS)
        BIT     2, A
        JP      Z, .Failed
        JP      .Passed
.Test74:
        LD      HL, (X86_REG_CX)
        LD      DE, 0
        CALL    .CompareHLDE
        JP      NZ, .Failed
        LD      HL, (X86_REG_SI)
        LD      DE, $0123
        CALL    .CompareHLDE
        JP      NZ, .Failed             
        LD      HL, (X86_REG_DI)
        LD      DE, $0133
        CALL    .CompareHLDE
        JP      NZ, .Failed
        LD      A, (X86_REG_FLAGS)
        BIT     2, A
        JP      Z, .Failed
        JP      .Passed
.Test75:
        LD      A, (X86_REG_AX)
        CP      $5A
        JP      NZ, .Failed
        JP      .Passed
.Test76:
        LD      A, (X86_REG_AX)
        CP      $5A
        JP      NZ, .Failed
        JP      .Passed
.Test77:
        LD      HL, (X86_REG_CS)
        LD      DE, 0
        CALL    .CompareHLDE
        JP      NZ, .Failed
        LD      HL, (X86_REG_IP)
        LD      DE, $0106
        CALL    .CompareHLDE
        JP      NZ, .Failed
        JP      .Passed
.Test78:
        LD      HL, (X86_REG_CS)
        LD      DE, 0
        CALL    .CompareHLDE
        JP      NZ, .Failed
        LD      HL, (X86_REG_IP)
        LD      DE, $0106
        CALL    .CompareHLDE
        JP      NZ, .Failed
        LD      HL, (X86_REG_SP)
        LD      DE, $FFFE
        CALL    .CompareHLDE
        JP      NZ, .Failed
        JP      .Passed
.Test79:
        LD      A, (X86_REG_AX)
        CP      4
        JP      NZ, .Failed
        JP      .Passed
.Test80:
        LD      HL, (X86_REG_AX)
        LD      DE, $FFF6
        CALL    .CompareHLDE
        JP      NZ, .Failed
        LD      HL, (X86_REG_DX)
        LD      DE, $FFFF
        CALL    .CompareHLDE
        JP      NZ, .Failed
        JP      .Passed
.Test81:
        LD      A, (X86_REG_AX)
        CP      $81
        JP      NZ, .Failed
        LD      A, (X86_REG_FLAGS + 1)
        BIT     3, A
        JP      Z, .Failed
        JP      .Passed
.Test82:
        LD      HL, (X86_REG_AX)
        LD      DE, 1
        CALL    .CompareHLDE
        JP      NZ, .Failed
        JP      .Passed
.Test83:
        LD      HL, (X86_REG_AX)
        LD      DE, $1300
        CALL    .CompareHLDE
        JP      NZ, .Failed
        LD      A, (X86_REG_FLAGS)
        BIT     0, A
        JP      NZ, .Failed
        LD      HL, (X86_REG_IP)
        LD      DE, $0107
        CALL    .CompareHLDE
        JP      NZ, .Failed
        JP      .Passed
.Test84:
        LD      HL, (X86_REG_AX)
        LD      DE, 0
        CALL    .CompareHLDE
        JP      NZ, .Failed
        LD      A, (X86_REG_FLAGS)
        BIT     0, A
        JP      Z, .Failed
        BIT     2, A
        JP      Z, .Failed
        LD      HL, (X86_REG_IP)
        LD      DE, $0106
        CALL    .CompareHLDE
        JP      NZ, .Failed
        JP      .Passed
.Test85:
        LD      HL, (X86_REG_AX)
        LD      DE, $1234
        CALL    .CompareHLDE
        JP      NZ, .Failed
        LD      HL, (X86_REG_CX)
        LD      DE, $1234
        CALL    .CompareHLDE
        JP      NZ, .Failed
        LD      A, (X86_REG_FLAGS)
        BIT     2, A
        JP      Z, .Failed
        BIT     0, A
        JP      NZ, .Failed
        LD      HL, (X86_REG_IP)
        LD      DE, $0109
        CALL    .CompareHLDE
        JP      NZ, .Failed
        JP      .Passed
.Test86:
        LD      HL, (X86_REG_BX)
        LD      DE, $5678
        CALL    .CompareHLDE
        JP      NZ, .Failed
        LD      HL, (X86_REG_IP)
        LD      DE, $0111
        CALL    .CompareHLDE
        JP      NZ, .Failed
        JP      .Passed
.Test87:
        LD      HL, (X86_REG_AX)
        LD      DE, 3
        CALL    .CompareHLDE
        JP      NZ, .Failed
        LD      HL, (X86_REG_CX)
        LD      DE, 0
        CALL    .CompareHLDE
        JP      NZ, .Failed
        LD      HL, (X86_REG_IP)
        LD      DE, $010A
        CALL    .CompareHLDE
        JP      NZ, .Failed
        JP      .Passed
.Test88:
        LD      HL, (X86_REG_AX)
        LD      DE, $1234
        CALL    .CompareHLDE
        JP      NZ, .Failed
        LD      HL, (X86_REG_CX)
        LD      DE, $BEEF
        CALL    .CompareHLDE
        JP      NZ, .Failed
        LD      HL, (X86_REG_SP)
        LD      DE, $FFFE
        CALL    .CompareHLDE
        JP      NZ, .Failed
        LD      HL, (X86_REG_IP)
        LD      DE, $0109
        CALL    .CompareHLDE
        JP      NZ, .Failed
        JP      .Passed
.Test89:
        LD      HL, (X86_REG_BX)
        LD      DE, $2222
        CALL    .CompareHLDE
        JP      NZ, .Failed
        LD      HL, (X86_REG_IP)
        LD      DE, $010B
        CALL    .CompareHLDE
        JP      NZ, .Failed
        JP      .Passed
.Test90:
        LD      HL, (X86_REG_AX)
        LD      DE, 0
        CALL    .CompareHLDE
        JP      NZ, .Failed
        LD      A, (X86_REG_FLAGS)
        BIT     0, A
        JP      Z, .Failed
        BIT     2, A
        JP      Z, .Failed
        LD      HL, (X86_REG_IP)
        LD      DE, $0107
        CALL    .CompareHLDE
        JP      NZ, .Failed
        JP      .Passed
.Test91:
        LD      A, (X86_REG_AX)
        CP      $5A
        JP      NZ, .Failed
        LD      IX, 0
        LD      DE, $0203
        CALL    X86_Read_Byte_Segment
        CP      $5A
        JP      NZ, .Failed
        JP      .Passed
.Test92:
        LD      HL, (X86_REG_AX)
        LD      DE, $20A5
        CALL    .CompareHLDE
        JP      NZ, .Failed
        LD      A, (X86_REG_CX)
        CP      $A5
        JP      NZ, .Failed
        LD      HL, (X86_REG_DS)
        LD      DE, $1000
        CALL    .CompareHLDE
        JP      NZ, .Failed
        LD      HL, (X86_REG_SS)
        LD      DE, $2000
        CALL    .CompareHLDE
        JP      NZ, .Failed
        JP      .Passed
.Test93:
        LD      HL, (X86_REG_AX)
        LD      DE, $20B6
        CALL    .CompareHLDE
        JP      NZ, .Failed
        LD      HL, (X86_REG_CX)
        LD      DE, $00B6
        CALL    .CompareHLDE
        JP      NZ, .Failed
        JP      .Passed
.Test94:
        LD      A, (X86_REG_AX)
        CP      $6D
        JP      NZ, .Failed
        LD      IX, 0
        LD      DE, $1234
        CALL    X86_Read_Byte_Segment
        CP      $6D
        JP      NZ, .Failed
        JP      .Passed
.Test95:
        LD      A, (X86_REG_AX)
        CP      $C3
        JP      NZ, .Failed
        LD      IX, (X86_REG_ES)
        LD      DE, $0203
        CALL    X86_Read_Byte_Segment
        CP      $C3
        JP      NZ, .Failed
        JP      .Passed
.Test96:
        LD      A, (X86_REG_AX)
        CP      $B8
        JP      NZ, .Failed
        JP      .Passed
.Test97:
        LD      HL, (X86_REG_AX)
        LD      DE, $0155
        CALL    .CompareHLDE
        JP      NZ, .Failed
        LD      HL, (X86_REG_CX)
        LD      DE, $00AA
        CALL    .CompareHLDE
        JP      NZ, .Failed
        JP      .Passed
.Test98:
        LD      HL, (X86_REG_AX)
        LD      DE, $08E7
        CALL    .CompareHLDE
        JP      NZ, .Failed
        LD      HL, (X86_REG_CX)
        LD      DE, $0011
        CALL    .CompareHLDE
        JP      NZ, .Failed
        JP      .Passed
.Test99:
        LD      A, (X86_REG_AX)
        BIT     6, A
        JP      Z, .Failed
        BIT     7, A
        JP      NZ, .Failed
        JP      .Passed
.Test100:
        LD      A, (X86_REG_AX + 1)
        OR      A
        JP      NZ, .Failed
        LD      A, (X86_REG_FLAGS)
        BIT     0, A
        JP      NZ, .Failed
        JP      .Passed
.Test101:
        LD      A, (X86_REG_AX + 1)
        OR      A
        JP      NZ, .Failed
        LD      A, (X86_REG_FLAGS)
        BIT     0, A
        JP      NZ, .Failed
        JP      .Passed
.Test102:
        LD      A, (X86_REG_AX + 1)
        OR      A
        JP      NZ, .Failed
        LD      A, (X86_REG_FLAGS)
        BIT     0, A
        JP      NZ, .Failed
        JP      .Passed
.Test103:
        LD      A, (X86_REG_AX + 1)
        OR      A
        JP      NZ, .Failed
        LD      A, (X86_REG_FLAGS)
        BIT     0, A
        JP      NZ, .Failed
        LD      HL, X86_HDD_Sector_Buffer
        LD      BC, 512
.VerifySectorPattern:
        LD      A, (HL)
        CP      #A5
        JP      NZ, .Failed
        INC     HL
        DEC     BC
        LD      A, B
        OR      C
        JR      NZ, .VerifySectorPattern
        JP      .Passed
; =========================================================================
; ИСПРАВЛЕННЫЙ ТЕСТ 104: ЧЕСТНАЯ ВЕРИФИКАЦИЯ ВЫХОДА НА СТОП HLT
; =========================================================================
.Test104:
; Проверяем только то, что гостевой IP корректно дошел до адреса HLT останова ($0117)
        LD      HL, (X86_REG_IP)
        LD      DE, $0117
        CALL    .CompareHLDE
        JP      NZ, .Failed
        JP      .Passed
; =========================================================================
; ИСПРАВЛЕННЫЙ ТЕСТ 105: ЧЕСТНАЯ ВЕРИФИКАЦИЯ ВЫХОДА НА СТОП HLT
; =========================================================================
.Test105:
; Проверяем только то, что гостевой IP корректно дошел до адреса HLT останова ($0117)
        LD      HL, (X86_REG_IP)
        LD      DE, $0117
        CALL    .CompareHLDE
        JP      NZ, .Failed
        JP      .Passed
.CompareHLDE:
        OR      A
        SBC     HL, DE
        RET
.Passed:
        XOR     A
        JR      .Return
.Failed:
        LD      A, 1
.Return:
        POP     HL
        POP     DE
        POP     BC
        RET