; =========================================================================
; Byte string operations and REP support for the guest x86
; =========================================================================

Op_MOVSB:
        PUSH    AF
        PUSH    BC
        PUSH    DE
        PUSH    HL
        PUSH    IX
        PUSH    IY
        LD      DE, (X86_REG_SI)
        LD      IX, (X86_REG_DS)
        CALL    X86_Read_Byte_Segment
        LD      DE, (X86_REG_DI)
        LD      IX, (X86_REG_ES)
        CALL    X86_Write_Byte_Segment
        CALL    X86_Adjust_String_Indexes
        POP     IY
        POP     IX
        POP     HL
        POP     DE
        POP     BC
        POP     AF
        RET

Op_STOSB:
        PUSH    AF
        PUSH    BC
        PUSH    DE
        PUSH    HL
        PUSH    IX
        PUSH    IY
        LD      A, (X86_REG_AX)
        LD      DE, (X86_REG_DI)
        LD      IX, (X86_REG_ES)
        CALL    X86_Write_Byte_Segment
        CALL    X86_Adjust_DI
        POP     IY
        POP     IX
        POP     HL
        POP     DE
        POP     BC
        POP     AF
        RET

Op_CMPSB:
        PUSH    AF
        PUSH    BC
        PUSH    DE
        PUSH    HL
        PUSH    IX
        PUSH    IY
        LD      DE, (X86_REG_SI)
        LD      IX, (X86_REG_DS)
        CALL    X86_Read_Byte_Segment
        LD      B, A
        LD      DE, (X86_REG_DI)
        LD      IX, (X86_REG_ES)
        CALL    X86_Read_Byte_Segment
        LD      E, A
        LD      A, B
        SUB     E
        PUSH    AF
        POP     BC
        CALL    Update_X86_Flags8
        CALL    X86_Adjust_String_Indexes
        POP     IY
        POP     IX
        POP     HL
        POP     DE
        POP     BC
        POP     AF
        RET

Op_SCASB:
        PUSH    AF
        PUSH    BC
        PUSH    DE
        PUSH    HL
        PUSH    IX
        PUSH    IY
        LD      DE, (X86_REG_DI)
        LD      IX, (X86_REG_ES)
        CALL    X86_Read_Byte_Segment
        LD      E, A
        LD      A, (X86_REG_AX)
        SUB     E
        PUSH    AF
        POP     BC
        CALL    Update_X86_Flags8
        CALL    X86_Adjust_DI
        POP     IY
        POP     IX
        POP     HL
        POP     DE
        POP     BC
        POP     AF
        RET

Op_XLAT:
        PUSH    AF
        PUSH    BC
        PUSH    DE
        PUSH    HL
        PUSH    IX
        PUSH    IY
        LD      DE, (X86_REG_BX)
        LD      A, (X86_REG_AX)
        ADD     A, E
        LD      E, A
        JR      NC, .AddressReady
        INC     D
.AddressReady:
        LD      IX, (X86_REG_DS)
        CALL    X86_Read_Byte_Segment
        LD      (X86_REG_AX), A
        POP     IY
        POP     IX
        POP     HL
        POP     DE
        POP     BC
        POP     AF
        RET

Op_REP:
        CALL    X86_Fetch_Byte
        CP      $AA
        JR      Z, .RepeatSTOSB
        CP      $A6
        JR      Z, .RepeatCMPSB
        LD      A, 2
        LD      (X86_CPU_State), A
        RET

.RepeatSTOSB:
        LD      HL, (X86_REG_CX)
        LD      A, H
        OR      L
        RET     Z
.STOSBLoop:
        CALL    Op_STOSB
        LD      HL, (X86_REG_CX)
        DEC     HL
        LD      (X86_REG_CX), HL
        LD      A, H
        OR      L
        JR      NZ, .STOSBLoop
        RET

.RepeatCMPSB:
        LD      HL, (X86_REG_CX)
        LD      A, H
        OR      L
        RET     Z
.CMPSBLoop:
        CALL    Op_CMPSB
        LD      HL, (X86_REG_CX)
        DEC     HL
        LD      (X86_REG_CX), HL
        LD      A, H
        OR      L
        RET     Z
        LD      A, (X86_REG_FLAGS)
        BIT     2, A
        JR      NZ, .CMPSBLoop
        RET

X86_Adjust_String_Indexes:
        CALL    X86_Adjust_DI
        LD      HL, (X86_REG_SI)
        LD      A, (X86_REG_FLAGS + 1)
        BIT     2, A
        JR      NZ, .DecrementSI
        INC     HL
        JR      .SaveSI
.DecrementSI:
        DEC     HL
.SaveSI:
        LD      (X86_REG_SI), HL
        RET

X86_Adjust_DI:
        PUSH    AF
        PUSH    HL
        LD      HL, (X86_REG_DI)
        LD      A, (X86_REG_FLAGS + 1)
        BIT     2, A
        JR      NZ, .DecrementDI
        INC     HL
        JR      .SaveDI
.DecrementDI:
        DEC     HL
.SaveDI:
        LD      (X86_REG_DI), HL
        POP     HL
        POP     AF
        RET
