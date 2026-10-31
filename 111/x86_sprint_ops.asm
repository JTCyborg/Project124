; =========================================================================
; Instruction handlers required by the active compatibility-test range
; =========================================================================

Op_Group_80:
        CALL    X86_Fetch_Byte
        LD      C, A
        CALL    X86_Fetch_Byte
        LD      E, A
        LD      A, C
        CP      $C0
        JR      Z, .AddAL
        CP      $F8
        JR      Z, .CompareAL
        JR      .Unsupported
.AddAL:
        LD      A, (X86_REG_AX)
        ADD     A, E
        LD      (X86_REG_AX), A
        PUSH    AF
        POP     BC
        LD      A, (X86_REG_AX)
        CALL    Update_X86_Flags8
        RET
.CompareAL:
        LD      A, (X86_REG_AX)
        SUB     E
        PUSH    AF
        POP     BC
        CALL    Update_X86_Flags8
        RET
.Unsupported:
        LD      A, 2
        LD      (X86_CPU_State), A
        RET

Op_Group_83:
        CALL    X86_Fetch_Byte
        CP      $C4
        JP      NZ, .Unsupported
        CALL    X86_Fetch_Byte
        LD      E, A
        LD      A, E
        ADD     A, A
        SBC     A, A
        LD      D, A
        LD      HL, (X86_REG_SP)
        ADD     HL, DE
        PUSH    AF
        LD      (X86_REG_SP), HL
        POP     BC
        CALL    Update_X86_ALU_Flags
        RET
.Unsupported:
        LD      A, 2
        LD      (X86_CPU_State), A
        RET

Op_AAA:
        LD      A, (X86_REG_AX)
        LD      B, A
        AND     $0F
        CP      10
        JR      NC, .Adjust
        LD      A, (X86_REG_FLAGS)
        BIT     4, A
        JR      NZ, .Adjust
        JR      .NoAdjust
.Adjust:
        LD      A, (X86_REG_AX)
        ADD     A, 6
        AND     $0F
        LD      (X86_REG_AX), A
        LD      A, (X86_REG_AX + 1)
        INC     A
        LD      (X86_REG_AX + 1), A
        LD      HL, (X86_REG_FLAGS)
        SET     0, L
        SET     4, L
        LD      (X86_REG_FLAGS), HL
        RET
.NoAdjust:
        LD      A, (X86_REG_AX)
        AND     $0F
        LD      (X86_REG_AX), A
        LD      HL, (X86_REG_FLAGS)
        RES     0, L
        RES     4, L
        LD      (X86_REG_FLAGS), HL
        RET

Op_ADC_AL_Imm8:
        PUSH    AF
        PUSH    BC
        PUSH    DE
        PUSH    HL
        CALL    X86_Fetch_Byte
        LD      E, A
        LD      (X86_Alu_Immediate), A
        LD      A, (X86_REG_FLAGS)
        AND     1
        LD      (X86_Alu_CarryIn), A
        LD      A, (X86_REG_AX)
        LD      (X86_Alu_Original), A
        LD      L, A
        LD      H, 0
        LD      D, 0
        ADD     HL, DE
        LD      A, (X86_Alu_CarryIn)
        OR      A
        JR      Z, .AdcStore
        INC     HL
.AdcStore:
        LD      A, L
        LD      (X86_REG_AX), A
        LD      A, H
        OR      A
        JR      Z, .AdcNoCarry
        SCF
        JR      .AdcCaptureFlags
.AdcNoCarry:
        OR      A
.AdcCaptureFlags:
        PUSH    AF
        POP     BC
        LD      A, L
        CALL    Update_X86_Flags8
        LD      A, (X86_Alu_Original)
        LD      C, A
        LD      A, (X86_Alu_Immediate)
        XOR     C
        CPL
        LD      B, A
        LD      A, (X86_REG_AX)
        LD      E, A
        LD      A, C
        XOR     E
        AND     B
        AND     $80
        LD      HL, (X86_REG_FLAGS)
        OR      A
        JR      Z, .AdcNoOverflow
        SET     3, H
        JR      .AdcSaveFlags
.AdcNoOverflow:
        RES     3, H
.AdcSaveFlags:
        LD      (X86_REG_FLAGS), HL
        POP     HL
        POP     DE
        POP     BC
        POP     AF
        RET

Op_Group_D0:
        CALL    X86_Fetch_Byte
        CP      $C0
        JR      Z, .ROL_AL
        CP      $D0
        JR      Z, .RCL_AL
        JR      .Unsupported
.ROL_AL:
        LD      A, (X86_REG_AX)
        RLCA
        LD      (X86_REG_AX), A
        LD      B, A
        AND     1
        LD      C, A
        LD      A, B
        AND     $80
        RLCA
        XOR     C
        AND     1
        LD      B, A
        LD      HL, (X86_REG_FLAGS)
        RES     0, L
        LD      A, C
        OR      A
        JR      Z, .ROL_NoCarry
        SET     0, L
.ROL_NoCarry:
        RES     3, H
        LD      A, B
        OR      A
        JR      Z, .ROL_NoOverflow
        SET     3, H
.ROL_NoOverflow:
        LD      (X86_REG_FLAGS), HL
        RET
.RCL_AL:
        LD      A, (X86_REG_FLAGS)
        AND     1
        LD      C, A
        LD      A, (X86_REG_AX)
        RLCA
        AND     $FE
        OR      C
        LD      B, A
        LD      A, (X86_REG_AX)
        AND     $80
        RLCA
        LD      C, A
        LD      A, B
        LD      (X86_REG_AX), A
        LD      A, (X86_REG_AX)
        AND     $80
        RLCA
        XOR     C
        AND     1
        LD      B, A
        LD      HL, (X86_REG_FLAGS)
        RES     0, L
        LD      A, C
        OR      A
        JR      Z, .RCL_NoCarry
        SET     0, L
.RCL_NoCarry:
        RES     3, H
        LD      A, B
        OR      A
        JR      Z, .RCL_NoOverflow
        SET     3, H
.RCL_NoOverflow:
        LD      (X86_REG_FLAGS), HL
        RET
.Unsupported:
        LD      A, 2
        LD      (X86_CPU_State), A
        RET

Op_MOV_AL_BX:
        CALL    X86_Fetch_Byte
        CP      $07
        JR      NZ, .Unsupported
        LD      DE, (X86_REG_BX)
        LD      A, (X86_Segment_Override)
        OR      A
        JR      Z, .UseDS
        LD      IX, (X86_REG_CS)
        JR      .ReadByte
.UseDS:
        LD      IX, (X86_REG_DS)
.ReadByte:
        CALL    X86_Read_Byte_Segment
        LD      (X86_REG_AX), A
        RET
.Unsupported:
        LD      A, 2
        LD      (X86_CPU_State), A
        RET

Op_JMP_Far:
        PUSH    AF
        PUSH    BC
        PUSH    DE
        PUSH    HL
        CALL    X86_Fetch_Byte
        LD      E, A
        CALL    X86_Fetch_Byte
        LD      D, A
        CALL    X86_Fetch_Byte
        LD      C, A
        CALL    X86_Fetch_Byte
        LD      B, A
        LD      (X86_REG_IP), DE
        LD      (X86_REG_CS), BC
        POP     HL
        POP     DE
        POP     BC
        POP     AF
        RET

Op_CALL_Far:
        PUSH    AF
        PUSH    BC
        PUSH    DE
        PUSH    HL
        CALL    X86_Fetch_Byte
        LD      E, A
        CALL    X86_Fetch_Byte
        LD      D, A
        CALL    X86_Fetch_Byte
        LD      C, A
        CALL    X86_Fetch_Byte
        LD      B, A
        LD      (X86_Far_TempSegment), BC
        LD      BC, (X86_REG_CS)
        CALL    Push_To_X86_Stack
        LD      BC, (X86_REG_IP)
        CALL    Push_To_X86_Stack
        LD      (X86_REG_IP), DE
        LD      BC, (X86_Far_TempSegment)
        LD      (X86_REG_CS), BC
        POP     HL
        POP     DE
        POP     BC
        POP     AF
        RET

Op_RETF:
        PUSH    AF
        PUSH    BC
        PUSH    HL
        CALL    Pop_From_X86_Stack
        LD      (X86_REG_IP), BC
        CALL    Pop_From_X86_Stack
        LD      (X86_REG_CS), BC
        POP     HL
        POP     BC
        POP     AF
        RET

Op_IMUL_AX_Imm16:
        PUSH    AF
        PUSH    BC
        PUSH    DE
        PUSH    HL
        CALL    X86_Fetch_Byte
        CP      $C0
        JP      NZ, .Unsupported
        CALL    X86_Fetch_Byte
        LD      E, A
        CALL    X86_Fetch_Byte
        LD      D, A
        LD      (X86_IMUL_Immediate), DE
        LD      BC, (X86_REG_CX)
        LD      (X86_IMUL_SavedCX), BC
        LD      A, (X86_REG_AX + 1)
        XOR     D
        AND     $80
        LD      (X86_IMUL_Sign), A

        LD      HL, (X86_REG_AX)
        BIT     7, H
        JR      Z, .AXMagnitudeReady
        XOR     A
        LD      DE, 0
        SBC     DE, HL
        LD      HL, DE
        LD      (X86_REG_AX), HL
.AXMagnitudeReady:
        LD      HL, (X86_IMUL_Immediate)
        BIT     7, H
        JR      Z, .ImmediateMagnitudeReady
        XOR     A
        LD      DE, 0
        SBC     DE, HL
        LD      HL, DE
.ImmediateMagnitudeReady:
        LD      (X86_REG_CX), HL
        CALL    Op_MUL_CX
        LD      A, (X86_IMUL_Sign)
        OR      A
        JR      Z, .RestoreCX

        LD      HL, (X86_REG_AX)
        LD      DE, (X86_REG_DX)
        LD      A, L
        CPL
        LD      L, A
        LD      A, H
        CPL
        LD      H, A
        LD      A, E
        CPL
        LD      E, A
        LD      A, D
        CPL
        LD      D, A
        INC     HL
        LD      A, H
        OR      L
        JR      NZ, .StoreNegatedProduct
        INC     DE
.StoreNegatedProduct:
        LD      (X86_REG_AX), HL
        LD      (X86_REG_DX), DE
.RestoreCX:
        LD      BC, (X86_IMUL_SavedCX)
        LD      (X86_REG_CX), BC
        POP     HL
        POP     DE
        POP     BC
        POP     AF
        RET
.Unsupported:
        LD      A, 2
        LD      (X86_CPU_State), A
        POP     HL
        POP     DE
        POP     BC
        POP     AF
        RET

Op_ADD_AL_Imm8:
        PUSH    AF
        PUSH    BC
        PUSH    DE
        CALL    X86_Fetch_Byte
        LD      E, A
        LD      A, (X86_REG_AX)
        LD      D, A
        ADD     A, E
        LD      (X86_REG_AX), A
        PUSH    AF
        POP     BC
        LD      A, (X86_REG_AX)
        CALL    Update_X86_Flags8
        LD      A, D
        XOR     E
        CPL
        LD      B, A
        LD      A, (X86_REG_AX)
        XOR     D
        AND     B
        AND     $80
        LD      HL, (X86_REG_FLAGS)
        OR      A
        JR      Z, .AddAL_ClearOF
        SET     3, H
        JR      .AddAL_FlagsDone
.AddAL_ClearOF:
        RES     3, H
.AddAL_FlagsDone:
        LD      (X86_REG_FLAGS), HL
        POP     DE
        POP     BC
        POP     AF
        RET

Op_DAA:
        PUSH    AF
        PUSH    BC
        PUSH    DE
        XOR     A
        LD      (X86_DAA_AF), A
        LD      (X86_DAA_CF), A
        LD      A, (X86_REG_AX)
        LD      B, A
        LD      A, (X86_REG_FLAGS)
        AND     1
        LD      C, A
        LD      A, B
        AND     $0F
        CP      10
        JR      NC, .DaaLowAdjust
        LD      A, (X86_REG_FLAGS)
        BIT     4, A
        JR      Z, .DaaHighCheck
.DaaLowAdjust:
        LD      A, (X86_REG_AX)
        ADD     A, 6
        LD      (X86_REG_AX), A
        LD      A, 1
        LD      (X86_DAA_AF), A
        JR      .DaaHighCheck
.DaaHighCheck:
        LD      A, B
        CP      $9A
        JR      NC, .DaaHighAdjust
        LD      A, C
        OR      A
        JR      NZ, .DaaHighAdjust
        XOR     A
        LD      (X86_DAA_CF), A
        JR      .DaaFlags
.DaaHighAdjust:
        LD      A, (X86_REG_AX)
        ADD     A, $60
        LD      (X86_REG_AX), A
        LD      A, 1
        LD      (X86_DAA_CF), A
.DaaFlags:
        LD      HL, (X86_REG_FLAGS)
        RES     0, L
        RES     4, L
        LD      A, (X86_DAA_AF)
        OR      A
        JR      Z, .DaaNoAF
        SET     4, L
.DaaNoAF:
        LD      A, (X86_DAA_CF)
        OR      A
        JR      Z, .DaaNoCF
        SET     0, L
.DaaNoCF:
        LD      A, (X86_REG_AX)
        OR      A
        JR      NZ, .DaaNotZero
        SET     2, L
        JR      .DaaSign
.DaaNotZero:
        RES     2, L
.DaaSign:
        LD      A, (X86_REG_AX)
        BIT     7, A
        JR      Z, .DaaNotSign
        SET     3, L
        JR      .DaaStore
.DaaNotSign:
        RES     3, L
.DaaStore:
        LD      (X86_REG_FLAGS), HL
        POP     DE
        POP     BC
        POP     AF
        RET

Op_AAM:
        CALL    X86_Fetch_Byte
        OR      A
        JR      Z, .AAMInvalidBase
        LD      B, A
        LD      A, (X86_REG_AX)
        LD      C, 0
.AAMDivide:
        CP      B
        JR      C, .AAMDone
        SUB     B
        INC     C
        JR      .AAMDivide
.AAMDone:
        LD      (X86_REG_AX), A
        LD      A, C
        LD      (X86_REG_AX + 1), A
        LD      A, (X86_REG_AX)
        PUSH    AF
        POP     BC
        CALL    Update_X86_Flags8
        RET
.AAMInvalidBase:
        LD      A, 2
        LD      (X86_CPU_State), A
        RET

Op_AAD:
        CALL    X86_Fetch_Byte
        LD      B, A
        LD      A, (X86_REG_AX + 1)
        LD      C, A
        LD      A, (X86_REG_AX)
        LD      E, A
        LD      D, 0
.AADMultiply:
        LD      A, C
        OR      A
        JR      Z, .AADAddLow
        LD      A, D
        ADD     A, B
        LD      D, A
        DEC     C
        JR      .AADMultiply
.AADAddLow:
        LD      A, D
        ADD     A, E
        LD      (X86_REG_AX), A
        XOR     A
        LD      (X86_REG_AX + 1), A
        LD      A, (X86_REG_AX)
        AND     A
        PUSH    AF
        POP     BC
        LD      A, (X86_REG_AX)
        CALL    Update_X86_Flags8
        RET

Op_INT3:
        RET

Op_INTO:
        LD      A, (X86_REG_FLAGS + 1)
        BIT     3, A
        RET     Z
        RET

Op_WAIT:
Op_LOCK:
        RET

Op_CS_Prefix:
        LD      A, 1
        LD      (X86_Segment_Override), A
        JP      Op_Segment_Prefix_Dispatch

Op_ES_Prefix:
        LD      A, 2
        LD      (X86_Segment_Override), A
        JP      Op_Segment_Prefix_Dispatch

Op_SS_Prefix:
        LD      A, 3
        LD      (X86_Segment_Override), A
        JP      Op_Segment_Prefix_Dispatch

Op_DS_Prefix:
        LD      A, 4
        LD      (X86_Segment_Override), A

Op_Segment_Prefix_Dispatch:
        CALL    X86_Fetch_Byte
        LD      (X86_Current_Opcode), A
        LD      (X86_Fault_Opcode), A
        CALL    X86_Dispatch_Opcode
        XOR     A
        LD      (X86_Segment_Override), A
        RET

Op_MOV_BX_Imm16:
        CALL    X86_Fetch_Byte
        LD      C, A
        CALL    X86_Fetch_Byte
        LD      B, A
        LD      (X86_REG_BX), BC
        RET
