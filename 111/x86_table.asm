; =========================================================================
; PERFECT COMMANDER 111 — ТАБЛИЦА ПЕРЕХОДОВ ДЕКОДЕРА ОПКOДОВ x86
; МОДУЛЬ: src/x86_table.asm (СТРОГИЙ СИНТАКСИС ПОД ФЛАГ --DIRBOL)
; =========================================================================

        ALIGN   256
X86_Jump_Table:
        ; 1. Заполняем всю таблицу из 256 элементов дефолтным обработчиком
        REPT    256
        DW      Op_Unimplemented
        ENDR

        ; 2. ТОЧЕЧНАЯ ЖЕСТКАЯ ФИКСАЦИЯ АДРЕСОВ ПОДДЕРЖИВАЕМЫХ ИНСТРУКЦИЙ
        ORG     X86_Jump_Table + ($01 * 2)
        DW      Op_ADD_AX_CX         

        ORG     X86_Jump_Table + ($02 * 2)
        DW      Op_Group_02          

        ORG     X86_Jump_Table + ($05 * 2)
        DW      Op_ADD_AX_Imm16         

        ORG     X86_Jump_Table + ($09 * 2)
        DW      Op_OR_AX_CX          

        ORG     X86_Jump_Table + ($0A * 2)
        DW      Op_Group_0A

        ORG     X86_Jump_Table + ($21 * 2)
        DW      Op_AND_AX_CX         

        ORG     X86_Jump_Table + ($22 * 2)
        DW      Op_Group_22

        ORG     X86_Jump_Table + ($29 * 2)
        DW      Op_SUB_AX_CX         

        ORG     X86_Jump_Table + ($2A * 2)
        DW      Op_Group_2A          

        ORG     X86_Jump_Table + ($31 * 2)
        DW      Op_XOR_AX_CX         

        ORG     X86_Jump_Table + ($32 * 2)
        DW      Op_Group_32

        ORG     X86_Jump_Table + ($3B * 2)
        DW      Op_CMP_AX_CX         

        ORG     X86_Jump_Table + ($40 * 2)
        DW      Op_INC_AX            

        ORG     X86_Jump_Table + ($41 * 2)
        DW      Op_INC_CX            

        ORG     X86_Jump_Table + ($42 * 2)
        DW      Op_INC_DX            

        ORG     X86_Jump_Table + ($48 * 2)
        DW      Op_DEC_AX            

        ORG     X86_Jump_Table + ($49 * 2)
        DW      Op_DEC_CX            

        ORG     X86_Jump_Table + ($4A * 2)
        DW      Op_DEC_DX            

        ORG     X86_Jump_Table + ($50 * 2)
        DW      Op_PUSH_AX           

        ORG     X86_Jump_Table + ($51 * 2)
        DW      Op_PUSH_CX           

        ORG     X86_Jump_Table + ($58 * 2)
        DW      Op_POP_AX            

        ORG     X86_Jump_Table + ($59 * 2)
        DW      Op_POP_CX            

        ORG     X86_Jump_Table + ($72 * 2)
        DW      Op_JC_Rel8           

        ORG     X86_Jump_Table + ($73 * 2)
        DW      Op_JNC_Rel8          

        ORG     X86_Jump_Table + ($74 * 2)
        DW      Op_JZ_Rel8           

        ORG     X86_Jump_Table + ($75 * 2)
        DW      Op_JNZ_Rel8          

        ORG     X86_Jump_Table + ($78 * 2)
        DW      Op_JS_Rel8           

        ORG     X86_Jump_Table + ($79 * 2)
        DW      Op_JNS_Rel8          

        ORG     X86_Jump_Table + ($81 * 2)
        DW      Op_Group_81              

        ORG     X86_Jump_Table + ($84 * 2)
        DW      Op_Group_84    

        ORG     X86_Jump_Table + ($85 * 2)
        DW      Op_TEST_AX_CX        

        ORG     X86_Jump_Table + ($89 * 2)
        DW      Op_Group_89          

        ORG     X86_Jump_Table + ($8B * 2)
        DW      Op_Group_8B          

        ORG     X86_Jump_Table + ($8E * 2)
        DW      Op_Group_8E          

        ORG     X86_Jump_Table + ($90 * 2)
        DW      Op_NOP

        ORG     X86_Jump_Table + ($A5 * 2)
        DW      Op_MOVSW             

        ORG     X86_Jump_Table + ($A8 * 2)
        DW      Op_TEST_AL_Imm8       

        ORG     X86_Jump_Table + ($AB * 2)
        DW      Op_STOSW               

        ORG     X86_Jump_Table + ($B0 * 2)
        DW      Op_MOV_AL_Imm8       

        ORG     X86_Jump_Table + ($B1 * 2)
        DW      Op_MOV_CL_Imm8       

        ; --- ДОБАВЛЕНО: РЕГИСТРАЦИЯ НOВЫХ 8-БИТНЫХ ОПКOДOВ ПОД ТЕCТЫ СЕКТOРOВ ---
        ORG     X86_Jump_Table + ($B2 * 2)
        DW      Op_MOV_DL_Imm8

        ORG     X86_Jump_Table + ($B3 * 2)
        DW      Op_MOV_BL_Imm8       

        ORG     X86_Jump_Table + ($B4 * 2)
        DW      Op_MOV_AH_Imm8       

        ORG     X86_Jump_Table + ($B5 * 2)
        DW      Op_MOV_CH_Imm8       

        ORG     X86_Jump_Table + ($B6 * 2)
        DW      Op_MOV_DH_Imm8

        ORG     X86_Jump_Table + ($B7 * 2)
        DW      Op_MOV_BH_Imm8

        ORG     X86_Jump_Table + ($B8 * 2)
        DW      Op_MOV_AX_Imm16

        ORG     X86_Jump_Table + ($B9 * 2)
        DW      Op_MOV_CX_Imm16

        ORG     X86_Jump_Table + ($BA * 2)
        DW      Op_MOV_DX_Imm16

        ORG     X86_Jump_Table + ($BE * 2)
        DW      Op_MOV_SI_Imm16      

        ORG     X86_Jump_Table + ($BF * 2)
        DW      Op_MOV_DI_Imm16      

        ORG     X86_Jump_Table + ($C3 * 2)
        DW      Op_RET               

        ORG     X86_Jump_Table + ($CD * 2)
        DW      Op_INT_Imm8          

        ORG     X86_Jump_Table + ($D1 * 2)
        DW      Op_Group_D1          

        ORG     X86_Jump_Table + ($D3 * 2)
        DW      X86_Op_Group_D3

        ORG     X86_Jump_Table + ($E2 * 2)
        DW      Op_LOOP_Rel8         

        ORG     X86_Jump_Table + ($EB * 2)
        DW      Op_JMP_Rel8          

        ; --- РАСШИРЕНИЕ ПРОЕКТА 111: ПОДКЛЮЧЕНИЕ ПОРТОВОГО ВВОДА ГОСТЯ ---
        ORG     X86_Jump_Table + ($EC * 2)
        DW      X86_Op_IN_AL_DX         ; Врезка инструкции IN AL, DX под Тест 99

        ORG     X86_Jump_Table + ($F4 * 2)
        DW      Op_HLT               

        ORG     X86_Jump_Table + ($F5 * 2)
        DW      Op_CMC

        ORG     X86_Jump_Table + ($F6 * 2)
        DW      Op_Group_F6

        ORG     X86_Jump_Table + ($F7 * 2)
        DW      Op_Group_F7          

        ORG     X86_Jump_Table + ($F8 * 2)
        DW      Op_CLC

        ORG     X86_Jump_Table + ($F9 * 2)
        DW      Op_STC

        ORG     X86_Jump_Table + ($FC * 2)
        DW      Op_CLD

        ORG     X86_Jump_Table + ($FD * 2)
        DW      Op_STD

        ORG     X86_Jump_Table + ($FE * 2)
        DW      Op_Group_FE          

        ORG     X86_Jump_Table + ($04 * 2)
        DW      Op_ADD_AL_Imm8

        ORG     X86_Jump_Table + ($14 * 2)
        DW      Op_ADC_AL_Imm8

        ORG     X86_Jump_Table + ($27 * 2)
        DW      Op_DAA

        ORG     X86_Jump_Table + ($2E * 2)
        DW      Op_CS_Prefix

        ORG     X86_Jump_Table + ($26 * 2)
        DW      Op_ES_Prefix

        ORG     X86_Jump_Table + ($36 * 2)
        DW      Op_SS_Prefix

        ORG     X86_Jump_Table + ($3E * 2)
        DW      Op_DS_Prefix

        ORG     X86_Jump_Table + ($37 * 2)
        DW      Op_AAA

        ORG     X86_Jump_Table + ($69 * 2)
        DW      Op_IMUL_AX_Imm16

        ORG     X86_Jump_Table + ($80 * 2)
        DW      Op_Group_80

        ORG     X86_Jump_Table + ($83 * 2)
        DW      Op_Group_83

        ORG     X86_Jump_Table + ($8A * 2)
        DW      Op_MOV_R8_RM8

        ORG     X86_Jump_Table + ($88 * 2)
        DW      Op_MOV_RM8_R8

        ORG     X86_Jump_Table + ($98 * 2)
        DW      Op_CBW

        ORG     X86_Jump_Table + ($99 * 2)
        DW      Op_CWD

        ORG     X86_Jump_Table + ($9A * 2)
        DW      Op_CALL_Far

        ORG     X86_Jump_Table + ($9B * 2)
        DW      Op_WAIT

        ORG     X86_Jump_Table + ($A4 * 2)
        DW      Op_MOVSB

        ORG     X86_Jump_Table + ($A6 * 2)
        DW      Op_CMPSB

        ORG     X86_Jump_Table + ($AA * 2)
        DW      Op_STOSB

        ORG     X86_Jump_Table + ($AE * 2)
        DW      Op_SCASB

        ORG     X86_Jump_Table + ($BB * 2)
        DW      Op_MOV_BX_Imm16

        ORG     X86_Jump_Table + ($BC * 2)
        DW      Op_MOV_SP_Imm16

        ORG     X86_Jump_Table + ($BD * 2)
        DW      Op_MOV_BP_Imm16

        ORG     X86_Jump_Table + ($CC * 2)
        DW      Op_INT3

        ORG     X86_Jump_Table + ($CB * 2)
        DW      Op_RETF

        ORG     X86_Jump_Table + ($CE * 2)
        DW      Op_INTO

        ORG     X86_Jump_Table + ($D0 * 2)
        DW      Op_Group_D0

        ORG     X86_Jump_Table + ($D4 * 2)
        DW      Op_AAM

        ORG     X86_Jump_Table + ($D5 * 2)
        DW      Op_AAD

        ORG     X86_Jump_Table + ($D7 * 2)
        DW      Op_XLAT

        ORG     X86_Jump_Table + ($EA * 2)
        DW      Op_JMP_Far

        ORG     X86_Jump_Table + ($F2 * 2)
        DW      Op_REP

        ORG     X86_Jump_Table + ($F0 * 2)
        DW      Op_LOCK

        ORG     X86_Jump_Table + ($F3 * 2)
        DW      Op_REP

        ALIGN   256
