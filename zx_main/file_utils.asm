; =========================================================================
; FILE: zx_main/file_utils.asm
; PROJECT 124 — TR-DOS directory utilities
; Sector API verified for TR-DOS 5.04T: C=#05, D=track, E=internal sector
; 0..15, B=count, HL=destination; error status at #5D0F.
; =========================================================================

; IN: CursorY = visible row (2..10)
; OUT: HL = 16-byte descriptor in TRDOS_PANEL_BUFFER, carry clear.
;      HL=0 and carry set for an invalid/empty row.
GetSelectedFileDescriptor::
        ld      a, (CursorY)
        cp      2
        jr      c, .bad_row
        cp      11
        jr      nc, .bad_row
        sub     2
        ld      l, a
        ld      h, 0
        add     hl, hl
        add     hl, hl
        add     hl, hl
        add     hl, hl
        ld      de, TRDOS_PANEL_BUFFER
        add     hl, de

        ; Reject an empty/deleted/invalid catalogue slot.
        ld      a, (hl)
        cp      32
        jr      c, .bad_row
        cp      127
        jr      nc, .bad_row
        or      a
        ret
.bad_row:
        ld      hl, 0
        scf
        ret

LogSelectedFile::
        push    hl
        ld      hl, .str_exec_prefix
        call    LOG_WriteMessageToBuffer
        pop     hl
        ret
.str_exec_prefix:
        defb "[LAUNCH] Invoking system CODE loader for selected workspace node...", #0D, #0A, 0

; Read and render the complete 128-entry TR-DOS catalogue (8 * 256 bytes).
PrintDiskDirectory::
        push    af
        push    bc
        push    de
        push    hl

        ; Select drive A and clear the two-byte TR-DOS error result.
        xor     a
        ld      (#5D19), a
        ld      (#5D0F), a
        ld      (#5D10), a

        ; C=#05 raw resident convention: D=track 0, E=sector 0..15.
        ld      de, #0000
        ld      b, 8
        ld      c, 5
        ld      hl, TRDOS_PANEL_BUFFER
        call    #3D13

        ; C=#05 reports read errors in the TR-DOS error byte #5D0F.
        ld      a, (#5D0F)
        ld      b, a
        ld      a, (#5D10)
        or      b
        jp      nz, .directory_read_error

        ld      b, 128
        ld      hl, TRDOS_PANEL_BUFFER
        ld      a, 2
        ld      (File_Y), a

.loop_slots:
        push    bc
        push    hl

        ld      a, (hl)
        or      a
        jp      z, .empty_slot
        cp      1
        jp      z, .invalid_slot
        cp      32
        jp      c, .invalid_slot
        cp      127
        jp      nc, .invalid_slot

        ld      a, 2
        ld      (File_X), a
        ld      c, 25
.clear_pixels_loop:
        push    bc
        push    hl
        ld      a, (File_X)
        ld      c, a
        ld      a, (File_Y)
        ld      d, a
        ld      b, " "
        call    Direct_PrintChar_Args
        pop     hl
        pop     bc
        ld      a, (File_X)
        inc     a
        ld      (File_X), a
        dec     c
        jr      nz, .clear_pixels_loop

        ld      a, 2
        ld      (File_X), a
        ld      c, 8
.print_name:
        ld      a, (hl)
        push    bc
        push    hl
        ld      b, a
        ld      a, (File_X)
        ld      c, a
        ld      a, (File_Y)
        ld      d, a
        call    Direct_PrintChar_Args
        ld      a, (File_X)
        inc     a
        ld      (File_X), a
        pop     hl
        pop     bc
        inc     hl
        dec     c
        jr      nz, .print_name

        ; Extension separator at X=10.
        ld      a, 10
        ld      (File_X), a
        push    hl
        ld      c, 10
        ld      a, (File_Y)
        ld      d, a
        ld      b, "."
        call    Direct_PrintChar_Args
        pop     hl

        ; File type at X=11.
        ld      a, 11
        ld      (File_X), a
        ld      a, (hl)
        push    hl
        ld      b, a
        ld      a, 11
        ld      c, a
        ld      a, (File_Y)
        ld      d, a
        call    Direct_PrintChar_Args
        pop     hl

        ; Descriptor byte 13 = allocated sector count. Display ceil(sectors/4)
        ; without 8-bit overflow: (sectors + 3) is calculated in 16 bits.
        push    hl
        ld      de, 13
        add     hl, de
        ld      a, (hl)
        ld      e, a
        ld      d, 0
        ld      hl, 3
        add     hl, de
        srl     h
        rr      l
        srl     h
        rr      l
        ld      a, l
        pop     hl

        ld      c, 16
        call    Util_PrintDecimalByte

        ld      a, 20
        ld      (File_X), a
        ld      a, (File_Y)
        ld      d, a
        ld      c, 20
        ld      b, "K"
        call    Direct_PrintChar_Args

        ld      a, 21
        ld      (File_X), a
        ld      a, (File_Y)
        ld      d, a
        ld      c, 21
        ld      b, "b"
        call    Direct_PrintChar_Args

        ld      a, (File_Y)
        inc     a
        ld      (File_Y), a
        cp      11
        jp      nc, .directory_done

        ; Advance to next 16-byte descriptor. Restore saved slot counter.
        pop     hl
        ld      de, 16
        add     hl, de
        pop     bc
        dec     b
        jp      nz, .loop_slots
        jp      .directory_success

.invalid_slot:
        ; Drop the per-slot saves, advance HL, and decrement the ORIGINAL
        ; 128-entry counter. Do not load 16 into BC (that destroys B), and
        ; do not push the per-slot saves again before re-entering the loop.
        pop     hl
        pop     bc
        ld      de, 16
        add     hl, de
        dec     b
        jp      nz, .loop_slots
        jp      .directory_success

.empty_slot:
        ; Per-slot BC/HL saves are still present.
        pop     hl
        pop     bc
        jp      .directory_success

.directory_done:
        ; Per-slot BC/HL saves are still present.
        pop     hl
        pop     bc
.directory_success:
        pop     hl
        pop     de
        pop     bc
        pop     af
        or      a
        ret

.directory_read_error:
        pop     hl
        pop     de
        pop     bc
        pop     af
        scf
        ret

; IN: A=value 0..255, C=screen X. Prints exactly three decimal digits.
Util_PrintDecimalByte:
        push    af
        push    bc
        push    de
        push    hl
        ld      e, a
        ld      a, c
        ld      (File_X), a
        ld      a, e
        ld      b, 0
.hundreds:
        cp      100
        jr      c, .p_hundreds
        sub     100
        inc     b
        jr      .hundreds
.p_hundreds:
        ld      e, a
        ld      a, b
        add     a, #30
        push    de
        ld      b, a
        ld      a, (File_X)
        ld      c, a
        ld      a, (File_Y)
        ld      d, a
        call    Direct_PrintChar_Args
        ld      a, (File_X)
        inc     a
        ld      (File_X), a
        pop     de

        ld      a, e
        ld      b, 0
.tens:
        cp      10
        jr      c, .p_tens
        sub     10
        inc     b
        jr      .tens
.p_tens:
        ld      e, a
        ld      a, b
        add     a, #30
        push    de
        ld      b, a
        ld      a, (File_X)
        ld      c, a
        ld      a, (File_Y)
        ld      d, a
        call    Direct_PrintChar_Args
        ld      a, (File_X)
        inc     a
        ld      (File_X), a
        pop     de

        ld      a, e
        add     a, #30
        ld      b, a
        ld      a, (File_X)
        ld      c, a
        ld      a, (File_Y)
        ld      d, a
        call    Direct_PrintChar_Args
        pop     hl
        pop     de
        pop     bc
        pop     af
        ret

Refresh_Panel_Directory::
        push    af
        push    bc
        push    de
        push    hl

        ; Fill 320 attribute bytes with #4F. The original byte sequence was
        ; LD HL,#5841, leaving DE undefined. This is the correct fill idiom.
        ld      hl, #5840
        ld      (hl), %01001111
        ld      de, #5841
        ld      bc, 319
        ldir

        call    PrintDiskDirectory
        jr      c, .refresh_failed
        call    DrawActiveCursor
        pop     hl
        pop     de
        pop     bc
        pop     af
        or      a
        ret
.refresh_failed:
        pop     hl
        pop     de
        pop     bc
        pop     af
        scf
        ret

File_X: DB 0
File_Y: DB 0
