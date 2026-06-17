// ==============================================================================
// 192p Test Suite - Palette 256 (GTIA Mode 9 Fullscreen)
// Generates a perfectly stable 16x16 full-screen color grid. 
// Uses PMG multiplexing to draw 'P' and 'N' markers directly on the tiles!
// ==============================================================================

pmbase = $8000

pal_dli_idx .byte 0
dli_p0_x    .ds 16      ; Player 0 X positions for each row (P marker)
dli_p1_x    .ds 16      ; Player 1 X positions for each row (N marker)
dli_p2_x    .ds 16      ; Player 2 X positions for each row (cursor)
dli_p0_c    .ds 16      ; Player 0 Color (Black/White depending on background)
dli_p1_c    .ds 16      ; Player 1 Color
dli_p2_c    .ds 16      ; Player 2 Color (cursor)

// ------------------------------------------------------------------------------
// Picker state. active_slot selects which reference (R/G/B) the picker is
// currently editing. The cursor's row is implicit (taken from that ref's hue
// = high nibble) and only the column (luma = low nibble) is adjustable - it
// makes no sense to set "red" inside a clearly green area.
// ------------------------------------------------------------------------------
active_slot .byte 0     ; 0 = R, 1 = G, 2 = B
input_dly   .byte 0     ; Debounce for joystick & R/G/B/0 keys

// ------------------------------------------------------------------------------
// Pointer table for the 6 reference RAM vars. Index = active_slot + region*3.
// get_active_ptr fills $84/$85 with the address of the currently-active ref.
// ------------------------------------------------------------------------------
ref_table_lo:
    .byte <ref_pal_red,   <ref_pal_green,   <ref_pal_blue
    .byte <ref_ntsc_red,  <ref_ntsc_green,  <ref_ntsc_blue
ref_table_hi:
    .byte >ref_pal_red,   >ref_pal_green,   >ref_pal_blue
    .byte >ref_ntsc_red,  >ref_ntsc_green,  >ref_ntsc_blue

// ------------------------------------------------------------------------------
// Perfectly calculated X-positions for the center of each of the 16 columns 
// across a standard 320-pixel (40-byte) screen.
// ------------------------------------------------------------------------------
x_pos_table:
    .byte 49, 59, 69, 79, 89, 99, 109, 119, 129, 139, 149, 159, 169, 179, 189, 199

palette_init:
    mva #$00 SDMCTL
    mva #$00 $D01D
    
    // Enable Mode 9 and set Priority for PMG over Playfield
    mva #$40 GPRIOR
    mva #$40 $D01B

    // Initialize PMG (Sprites)
    mva #>pmbase $D407      ; PMBASE
    mva #$03 $D01D          ; PMCNTL
    mva #$3E SDMCTL         ; Enable Playfield and Players
    
    // Clear Player 0, 1 and 2 RAM
    ldy #0
_clear_pmg:
    mva #$00 pmbase+$0400,y
    mva #$00 pmbase+$0500,y
    mva #$00 pmbase+$0600,y
    iny
    bne _clear_pmg

    // Clear DLI Arrays
    ldy #15
_clear_arr:
    mva #0 dli_p0_x,y
    mva #0 dli_p1_x,y
    mva #0 dli_p2_x,y
    mva #0 dli_p2_c,y
    dey
    bpl _clear_arr

    // Picker starts on the R (red) slot, debounce off
    mva #0 active_slot
    mva #0 input_dly
    jsr redraw_cursor

    // Setup P and N markers from runtime reference RAM vars (seeded in main.asm
    // from config.asm defaults; Phase B picker will write these live).
    // PAL Markers (Player 0)
    ldx ref_pal_red
    ldy #0
    jsr setup_marker

    ldx ref_pal_green
    ldy #0
    jsr setup_marker

    ldx ref_pal_blue
    ldy #0
    jsr setup_marker

    // NTSC Markers (Player 1)
    ldx ref_ntsc_red
    ldy #1
    jsr setup_marker

    ldx ref_ntsc_green
    ldy #1
    jsr setup_marker

    ldx ref_ntsc_blue
    ldy #1
    jsr setup_marker

    // Setup Screen
    mwa #pal_dli VDSLST
    mwa #pal_vbi $0224
    mva #$C0 NMIEN
    mwa #pal_dlist SDLSTL
    rts

// ------------------------------------------------------------------------------
// Calculates position and contrast color for P/N markers, saves to DLI tables,
// and draws the sprite shape directly into PMG RAM.
// IN: X = Color Hex, Y = Player (0=P, 1=N)
// ------------------------------------------------------------------------------
setup_marker:
    txa
    and #$F0
    lsr
    lsr
    lsr
    lsr
    sta $80                 ; Row (0-15)
    
    txa
    and #$0F
    tax                     ; Col (0-15)
    
    lda x_pos_table,x
    sta $81                 ; Screen X position
    
    // Determine Contrast Color (White on dark, Black on bright)
    cpx #8
    bcc _dark_bg
    lda #$00                ; Black marker
    jmp _save_col
_dark_bg:
    lda #$0F                ; White marker
_save_col:
    sta $82

    // Save to proper DLI table
    ldx $80
    cpy #0
    bne _is_n
_is_p:
    lda $81
    sta dli_p0_x,x
    lda $82
    sta dli_p0_c,x
    jmp _draw_shape
_is_n:
    lda $81
    sta dli_p1_x,x
    lda $82
    sta dli_p1_c,x

_draw_shape:
    // Calculate exact Y offset in PMG memory (Row * 12 + 35)
    // Centers the 5-line sprite vertically in the 12-line row!
    lda $80
    asl
    asl
    sta $83
    asl
    clc
    adc $83
    clc
    adc #35
    tax                     ; X is now Y offset in PMG memory

    cpy #0
    bne _draw_n_shape
_draw_p_shape:
    // Draw 'P'
    mva #$78 pmbase+$0400,x
    mva #$44 pmbase+$0401,x
    mva #$78 pmbase+$0402,x
    mva #$40 pmbase+$0403,x
    mva #$40 pmbase+$0404,x
    rts
_draw_n_shape:
    // Draw 'N'
    mva #$44 pmbase+$0500,x
    mva #$64 pmbase+$0501,x
    mva #$54 pmbase+$0502,x
    mva #$4C pmbase+$0503,x
    mva #$44 pmbase+$0504,x
    rts

// ------------------------------------------------------------------------------
// Safe, Standard DLI (No cycle counting, triggers cleanly between rows)
// ------------------------------------------------------------------------------
pal_dli:
    pha
    txa
    pha
    
    ldx pal_dli_idx
    inx
    cpx #16
    bne _dli_continue
    ldx #0
_dli_continue:
    stx pal_dli_idx
    
    txa
    asl
    asl
    asl
    asl
    
    sta WSYNC               ; Safe sync to the edge of the screen
    sta $D01A               ; Update Hue for the newly starting row

    // Multiplex the PMG markers for the current row (P0=P, P1=N, P2=cursor)
    lda dli_p0_x,x
    sta $D000
    lda dli_p1_x,x
    sta $D001
    lda dli_p2_x,x
    sta $D002
    lda dli_p0_c,x
    sta $D012
    lda dli_p1_c,x
    sta $D013
    lda dli_p2_c,x
    sta $D014

    pla
    tax
    pla
    rti

pal_vbi:
    lda current_state
    cmp #STATE_MENU
    bne _pal_vbi_active
    mwa #$E462 $0224
    jmp $E462
_pal_vbi_active:
    mva #0 pal_dli_idx
    mva #$00 $D01A              ; Row 0 is ALWAYS Hue 0

    // Set initial PMG multiplexer states for Row 0
    lda dli_p0_x
    sta $D000
    lda dli_p1_x
    sta $D001
    lda dli_p2_x
    sta $D002
    lda dli_p0_c
    sta $D012
    lda dli_p1_c
    sta $D013
    lda dli_p2_c
    sta $D014
    jmp $E462

// ------------------------------------------------------------------------------
// PICKER UI - called from main.asm idle-frame poll when current_test = 9.
//   R / G / B keys: select which reference (Red/Green/Blue) we are editing.
//                   Cursor jumps to that ref's current position.
//   "+" / "*" keys (on 800XL these print arrows LEFT / RIGHT under CTRL,
//                   bare they print the symbol; either way is fine here):
//                   change luma (low nibble) of the active ref. The row
//                   (hue) is fixed because a "red" reference only makes
//                   sense within the red row.
//   0: reset all 12 references to config.asm defaults.
//
// Modifier bits (CTRL/SHIFT) on CH are masked off before comparing so the
// picker works in both Altirra (where Cooked-mode key translation prefers
// bare scancodes) and on real hardware (where CTRL+"+" is the natural
// arrow gesture). Holding any key auto-repeats via the OS keyboard
// handler; we throttle with input_dly.
// ------------------------------------------------------------------------------
palette_poll:
    lda input_dly
    beq _pp_active
    dec input_dly
    rts

_pp_active:
    // bne+jmp pattern keeps branches in range as handlers grow.
    lda CH
    and #$3F                ; ignore CTRL / SHIFT modifier bits
    cmp #$28                ; R
    bne _pp_chk_g
    jmp _pp_key_r
_pp_chk_g:
    cmp #$3D                ; G
    bne _pp_chk_b
    jmp _pp_key_g
_pp_chk_b:
    cmp #$15                ; B
    bne _pp_chk_0
    jmp _pp_key_b
_pp_chk_0:
    cmp #$32                ; 0 (reset)
    bne _pp_chk_arrows
    jmp _pp_key_reset

_pp_chk_arrows:
    cmp #$06                ; "+" = LEFT  (printed ← on 800XL)
    beq _pp_left
    cmp #$07                ; "*" = RIGHT (printed → on 800XL)
    beq _pp_right
    rts

_pp_left:
    jsr get_active_ptr      ; $84/$85 -> active ref var
    ldy #0
    lda ($84),y
    and #$0F
    beq _pp_done            ; already col 0
    lda ($84),y
    sec
    sbc #$01
    sta ($84),y
    jmp _pp_after_xmove
_pp_right:
    jsr get_active_ptr
    ldy #0
    lda ($84),y
    and #$0F
    cmp #$0F
    beq _pp_done            ; already col 15
    lda ($84),y
    clc
    adc #$01
    sta ($84),y
_pp_after_xmove:
    mva #$FF CH             ; Consume key. Atari OS does NOT clear CH on key
                            ; release - without consuming, a single tap would
                            ; keep firing forever. OS auto-repeat refills CH
                            ; while the key is held, so hold-to-scroll still
                            ; works (paced by KRPDEL/KRPDEL2 + our input_dly).
    mva #6 input_dly
    jsr recompute_75        ; Keep 75% pair in sync with the new pure value
    jsr redraw_markers      ; Move the P/N marker on screen
    jsr redraw_cursor       ; Cursor follows the active ref
_pp_done:
    rts

_pp_key_r:
    mva #0 active_slot
    jmp _pp_after_slot
_pp_key_g:
    mva #1 active_slot
    jmp _pp_after_slot
_pp_key_b:
    mva #2 active_slot
_pp_after_slot:
    mva #$FF CH             ; Consume key
    mva #10 input_dly
    jsr redraw_cursor       ; Cursor jumps to the new slot's ref position
    rts

_pp_key_reset:
    mva #$FF CH
    mva #15 input_dly
    jsr ref_init            ; Reseed all 12 refs from config.asm defaults
    jsr redraw_markers
    jsr redraw_cursor
    rts

// ------------------------------------------------------------------------------
// get_active_ptr: writes the address of the currently-active reference RAM
// var into $84/$85, based on active_slot (0/1/2) and system_region (PAL/NTSC).
// Preserves A.
// ------------------------------------------------------------------------------
get_active_ptr:
    pha
    lda active_slot
    ldx system_region
    beq _gap_pal
    clc
    adc #3                  ; NTSC entries live at indices 3..5
_gap_pal:
    tax
    lda ref_table_lo,x
    sta $84
    lda ref_table_hi,x
    sta $85
    pla
    rts

// ------------------------------------------------------------------------------
// Wipe all 6 P/N markers and redraw from current ref_* RAM vars.
// Used after a picker assignment or reset.
// ------------------------------------------------------------------------------
redraw_markers:
    ldy #15
_rm_clear:
    mva #0 dli_p0_x,y
    mva #0 dli_p1_x,y
    dey
    bpl _rm_clear

    ldy #0
_rm_pmg:
    mva #$00 pmbase+$0400,y
    mva #$00 pmbase+$0500,y
    iny
    bne _rm_pmg

    ldx ref_pal_red
    ldy #0
    jsr setup_marker
    ldx ref_pal_green
    ldy #0
    jsr setup_marker
    ldx ref_pal_blue
    ldy #0
    jsr setup_marker
    ldx ref_ntsc_red
    ldy #1
    jsr setup_marker
    ldx ref_ntsc_green
    ldy #1
    jsr setup_marker
    ldx ref_ntsc_blue
    ldy #1
    jsr setup_marker
    rts

// ------------------------------------------------------------------------------
// Wipe Player 2 (cursor) and draw a hollow box at the active reference's
// current palette position.
// ------------------------------------------------------------------------------
redraw_cursor:
    ldy #15
_rc_clear_x:
    mva #0 dli_p2_x,y
    mva #0 dli_p2_c,y
    dey
    bpl _rc_clear_x

    ldy #0
_rc_clear_pmg:
    mva #$00 pmbase+$0600,y
    iny
    bne _rc_clear_pmg

    // Read active ref value via pointer; decode row (hue) and col (luma)
    jsr get_active_ptr
    ldy #0
    lda ($84),y
    pha
    and #$F0
    lsr
    lsr
    lsr
    lsr
    sta $80                 ; row (0-15)

    pla
    and #$0F
    tax                     ; col (0-15)

    lda x_pos_table,x
    sta $81                 ; screen X

    // Contrast color: white on dark columns (col < 8), black on bright
    cpx #8
    bcc _rc_dark_bg
    lda #$00
    jmp _rc_save_c
_rc_dark_bg:
    lda #$0F
_rc_save_c:
    sta $82

    // Write to DLI tables for the cursor's row
    ldx $80
    lda $81
    sta dli_p2_x,x
    lda $82
    sta dli_p2_c,x

    // Draw box at row*12 + 35 (same vertical centering as P/N markers)
    lda $80
    asl
    asl
    sta $83
    asl
    clc
    adc $83
    clc
    adc #35
    tax

    mva #$FE pmbase+$0600,x   ; XXXXXXX.
    mva #$82 pmbase+$0601,x   ; X.....X.
    mva #$82 pmbase+$0602,x   ; X.....X.
    mva #$82 pmbase+$0603,x   ; X.....X.
    mva #$FE pmbase+$0604,x   ; XXXXXXX.
    rts

// ------------------------------------------------------------------------------
// Perfect 192-line Full Screen Display List
// ------------------------------------------------------------------------------
    .align $0400
pal_dlist:
    .byte $70, $70, $70         ; Top Overscan
    
    // 15 Rows (12 scanlines each)
    .rept 15
        .rept 11
            .byte $4F, <pal_pat, >pal_pat
        .endr
        .byte $CF, <pal_pat, >pal_pat   ; DLI updates Hue/PMG for the NEXT row!
    .endr
    
    // 16th Row (no DLI needed at the end)
    .rept 12
        .byte $4F, <pal_pat, >pal_pat
    .endr
    
    .byte $41, <pal_dlist, >pal_dlist

// ------------------------------------------------------------------------------
// PATTERN DATA (40 bytes = exactly 16 columns of 5 mode-9-pixels)
// ------------------------------------------------------------------------------
    .align $0400
pal_pat:
    .byte $00, $00, $01, $11, $11, $22, $22, $23, $33, $33
    .byte $44, $44, $45, $55, $55, $66, $66, $67, $77, $77
    .byte $88, $88, $89, $99, $99, $AA, $AA, $AB, $BB, $BB
    .byte $CC, $CC, $CD, $DD, $DD, $EE, $EE, $EF, $FF, $FF