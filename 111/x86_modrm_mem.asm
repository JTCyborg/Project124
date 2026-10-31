; 16-bit real-mode ModR/M effective addresses and MOV byte operands.

X86_Calc_ModRM_EA:
        LD      (X86_ModRM), A
        XOR     A
        LD      (X86_EA_Uses_SS), A
        LD      A, (X86_ModRM)
        AND     7
        CP      0
        JR      Z, .BX_SI
        CP      1
        JR      Z, .BX_DI
        CP      2
        JR      Z, .BP_SI
        CP      3
        JR      Z, .BP_DI
        CP      4
        JR      Z, .SI
        CP      5
        JR      Z, .DI
        CP      6
        JR      Z, .DirectOrBP
        LD      HL, (X86_REG_BX)
        JR      .BaseReady
.BX_SI:
        LD      HL, (X86_REG_BX)
        LD      DE, (X86_REG_SI)
        ADD     HL, DE
        JR      .BaseReady
.BX_DI:
        LD      HL, (X86_REG_BX)
        LD      DE, (X86_REG_DI)
        ADD     HL, DE
        JR      .BaseReady
.BP_SI:
        LD      A, 1
        LD      (X86_EA_Uses_SS), A
        LD      HL, (X86_REG_BP)
        LD      DE, (X86_REG_SI)
        ADD     HL, DE
        JR      .BaseReady
.BP_DI:
        LD      A, 1
        LD      (X86_EA_Uses_SS), A
        LD      HL, (X86_REG_BP)
        LD      DE, (X86_REG_DI)
        ADD     HL, DE
        JR      .BaseReady
.SI:
        LD      HL, (X86_REG_SI)
        JR      .BaseReady
.DI:
        LD      HL, (X86_REG_DI)
        JR      .BaseReady
.DirectOrBP:
        LD      A, (X86_ModRM)
        AND     $C0
        JR      NZ, .BP
        CALL    X86_Fetch_Byte
        LD      C, A
        CALL    X86_Fetch_Byte
        LD      H, A
        LD      L, C
        JR      .BaseReady
.BP:
        LD      A, 1
        LD      (X86_EA_Uses_SS), A
        LD      HL, (X86_REG_BP)
.BaseReady:
        LD      A, (X86_ModRM)
        AND     $C0
        CP      $40
        JR      Z, .Disp8
        CP      $80
        JR      Z, .Disp16
        JR      .AddressReady
.Disp8:
        CALL    X86_Fetch_Byte
        LD      E, A
        LD      D, 0
        BIT     7, E
        JR      Z, .AddDisplacement
        LD      D, $FF
        JR      .AddDisplacement
.Disp16:
        CALL    X86_Fetch_Byte
        LD      E, A
        CALL    X86_Fetch_Byte
        LD      D, A
.AddDisplacement:
        ADD     HL, DE
.AddressReady:
        LD      (X86_Effective_Offset), HL

        LD      A, (X86_Segment_Override)
        CP      1
        JR      Z, .UseCS
        CP      2
        JR      Z, .UseES
        CP      3
        JR      Z, .UseSS
        CP      4
        JR      Z, .UseDS
        LD      A, (X86_EA_Uses_SS)
        OR      A
        JR      NZ, .UseSS
.UseDS:
        LD      IX, (X86_REG_DS)
        JR      .ReturnEA
.UseCS:
        LD      IX, (X86_REG_CS)
        JR      .ReturnEA
.UseES:
        LD      IX, (X86_REG_ES)
        JR      .ReturnEA
.UseSS:
        LD      IX, (X86_REG_SS)
.ReturnEA:
        LD      DE, (X86_Effective_Offset)
        RET

X86_Get_Byte_Reg:
        PUSH    BC
        PUSH    DE
        PUSH    HL
        LD      L, A
        LD      H, 0
        ADD     HL, HL
        LD      DE, X86_Byte_Reg_Pointers
        ADD     HL, DE
        LD      E, (HL)
        INC     HL
        LD      D, (HL)
        EX      DE, HL
        LD      A, (HL)
        LD      (X86_TempByte), A
        POP     HL
        POP     DE
        POP     BC
        LD      A, (X86_TempByte)
        RET

X86_Set_Byte_Reg:
        LD      (X86_TempRegIndex), A
        PUSH    BC
        PUSH    DE
        PUSH    HL
        LD      A, (X86_TempRegIndex)
        LD      L, A
        LD      H, 0
        ADD     HL, HL
        LD      DE, X86_Byte_Reg_Pointers
        ADD     HL, DE
        LD      E, (HL)
        INC     HL
        LD      D, (HL)
        EX      DE, HL
        LD      A, (X86_TempByte)
        LD      (HL), A
        POP     HL
        POP     DE
        POP     BC
        RET

Op_MOV_R8_RM8:
        PUSH    AF
        PUSH    BC
        PUSH    DE
        PUSH    HL
        CALL    X86_Fetch_Byte
        LD      (X86_ModRM), A
        AND     $C0
        CP      $C0
        JR      Z, .RegisterSource
        LD      A, (X86_ModRM)
        CALL    X86_Calc_ModRM_EA
        CALL    X86_Read_Byte_Segment
        LD      (X86_TempByte), A
        JR      .StoreDestination
.RegisterSource:
        LD      A, (X86_ModRM)
        AND     7
        CALL    X86_Get_Byte_Reg
.StoreDestination:
        LD      A, (X86_ModRM)
        AND     $38
        SRL     A
        SRL     A
        SRL     A
        CALL    X86_Set_Byte_Reg
        POP     HL
        POP     DE
        POP     BC
        POP     AF
        RET

Op_MOV_RM8_R8:
        PUSH    AF
        PUSH    BC
        PUSH    DE
        PUSH    HL
        CALL    X86_Fetch_Byte
        LD      (X86_ModRM), A
        AND     $38
        SRL     A
        SRL     A
        SRL     A
        CALL    X86_Get_Byte_Reg
        LD      (X86_TempByte), A
        LD      A, (X86_ModRM)
        AND     $C0
        CP      $C0
        JR      Z, .RegisterDestination
        LD      A, (X86_ModRM)
        CALL    X86_Calc_ModRM_EA
        LD      A, (X86_TempByte)
        CALL    X86_Write_Byte_Segment
        JR      .Return
.RegisterDestination:
        LD      A, (X86_ModRM)
        AND     7
        CALL    X86_Set_Byte_Reg
.Return:
        POP     HL
        POP     DE
        POP     BC
        POP     AF
        RET

X86_EA_Uses_SS: DB 0
X86_TempRegIndex: DB 0
X86_Byte_Reg_Pointers:
        DW      X86_REG_AX, X86_REG_CX, X86_REG_DX, X86_REG_BX
        DW      X86_REG_AX + 1, X86_REG_CX + 1
        DW      X86_REG_DX + 1, X86_REG_BX + 1
