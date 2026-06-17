// ==============================================================================
// 192p Test Suite - GTIA2RGB 80-Column Text (COL80 Mode 1)
// Only reachable when the FPGA companion was detected at boot (test index 14).
//
// ANTIC supplies mode F scan lines; GTIA2RGB reinterprets them as 80-column
// character data. Mode 1 layout per text row: 2 mode F lines (chars, left
// then right half) + 6 blank lines = 8 scanlines. The FPGA latches a row
// during one 8-line slot and renders it during the next, so the visible
// picture sits one slot (8 lines) below the first mode F instruction and
// the last row needs a trailing 8-blank-line slot to get rendered.
//
// SPACE cycles 4 states - classic monitor phosphors plus inverse:
//   0 = white on black   ($D01D=$40, fg luma only)
//   1 = green on black   ($D01D=$50, COLPF1 chroma feeds the foreground)
//   2 = amber on black   ($D01D=$50)
//   3 = black on white   ($D01D=$50, swapped)
// ==============================================================================

NUM_TEXT80_STATES = 4

text80_state: .byte 0

// Per-state register values. $50 = COL80 + bit 4 (independent foreground
// chroma from COLPF1); $40 = plain mode 1 (fg takes chroma from COLPF2).
text80_d01d: .byte $40, $50, $50, $50
text80_pf1:  .byte $0E, $C8, $28, $00   ; foreground (text)
text80_pf2:  .byte $00, $00, $00, $0E   ; background
text80_bak:  .byte $00, $00, $00, $0E   ; border follows background

// GTIA2RGB font-upload registers (manual section 5.3)
FONT_ADDR_HI = $D010    ; addr[10:3] - writing clears addr[2:0]
FONT_ADDR_LO = $D011    ; addr[2:0]  - row within current character
FONT_DATA    = $D01E    ; data byte + auto-increment (COL80 must be on)

text80_init:
    mva #$00 SDMCTL
    mva #$40 NMIEN              ; Disable DLI, keep VBLANK
    mva #$00 GPRIOR

    // COL80 on first - font writes are gated by bit 6 of $D01D
    mva #$40 $D01D
    jsr g2r_load_font

    mva #0 text80_state
    jsr _text80_apply
    mwa #text80_dlist SDLSTL
    mva #$22 SDMCTL
    rts

text80_toggle:
    inc text80_state
    lda text80_state
    cmp #NUM_TEXT80_STATES
    bne _text80_apply
    mva #0 text80_state
_text80_apply:
    ldx text80_state
    lda text80_d01d,x
    sta $D01D
    lda text80_pf1,x
    sta COLOR1
    lda text80_pf2,x
    sta COLOR2
    lda text80_bak,x
    sta COLOR4
    rts

// ------------------------------------------------------------------------------
// Upload the OS ROM character set (128 chars + 128 inverse = 2 KB) to the
// GTIA2RGB font memory, remapped to ATASCII order. Straight from the hardware
// manual, Appendix A.1. Font memory is undefined at power-on, so this must
// run before anything is displayed. Self-modifying EOR for the inverse half.
// Uses $E0/$E1 as the source pointer (project ZP convention).
// ------------------------------------------------------------------------------
g2r_load_font:
    lda #0
    sta FONT_ADDR_HI            ; start at char 0, row 0
    sta $E0                     ; source page low byte
    ldx #0
_lf_block:
    lda _lf_src_hi,x
    sta $E1                     ; source page high byte
    lda _lf_eor,x
    sta _lf_eor_op+1            ; self-modify: $00 = normal, $FF = inverse
    ldy #0
_lf_byte:
    lda ($E0),y
_lf_eor_op:
    eor #0
    sta FONT_DATA               ; write + auto-increment
    iny
    bne _lf_byte                ; 256 bytes per page
    inx
    cpx #8                      ; 8 pages = 2048 bytes
    bne _lf_block
    rts

// ROM pages ($E000 charset) remapped to ATASCII destination order.
_lf_src_hi: .byte $E2, $E0, $E1, $E3, $E2, $E0, $E1, $E3
_lf_eor:    .byte 0,   0,   0,   0,   $FF, $FF, $FF, $FF

// ------------------------------------------------------------------------------
// DISPLAY LIST. 24 blank + 23 row slots (8 lines each) + 8 blank for the
// last row's render slot = 216 scanlines, same total as a standard GR.0
// frame. LMS on every row start keeps each 80-byte row contiguous for ANTIC.
//
// Data lives in its own segment at $B000: the natural flow would land it on
// $8000 (palette256's PMG area) and run into the engine split buffers at
// $9000/$A000. At $B000 everything (122-byte DL + 1840-byte screen) fits in
// one 4KB block, so no row crosses a 4KB boundary and the DL stays inside
// its 1KB window - no .align needed. Stays below the OS boot screen (~$BC00).
// ------------------------------------------------------------------------------
    org $B000
text80_dlist:
    .byte $70, $70, $70
    .rept 23
        .byte $4F
        .word text80_screen + #*80
        .byte $0F, $50
    .endr
    .byte $70                   ; render slot for the 23rd row
    .byte $41
    .word text80_dlist

// ------------------------------------------------------------------------------
// SCREEN DATA - 23 rows x 80 chars, written as 2x40 chunks per row.
// The uploaded font is in ATASCII order, so c'...' (ATASCII) strings map
// directly; trailing * marks inverse video.
// ------------------------------------------------------------------------------
text80_screen:
    dta c' 192p TEST SUITE  -  GTIA2RGB 80-COLUMN '
    dta c'TEXT (COL80 MODE 1)                     '
    dta c'----------------------------------------'
    dta c'----------------------------------------'
    dta c' CONTROLS                               '
    dta c'                                        '
    dta c'  HELP    return to the main menu       '
    dta c'                                        '
    dta c'  SELECT  cycle to the next test        '
    dta c'                                        '
    dta c'  SPACE   cycle text color: white / gree'
    dta c'n / amber / inverse                     '
    dta c'  1-E     jump to a test (see the main m'
    dta c'enu)                                    '
    dta c'----------------------------------------'
    dta c'----------------------------------------'
    dta c' ABOUT THE TESTS                        '
    dta c'                                        '
    dta c' Standard calibration: PLUGE, SMPTE, EBU'
    dta c', color bars with gray scale.           '
    dta c' Set the black level with PLUGE first.  '
    dta c'                                        '
    dta c' Geometry: 160/320 grids and monoscope -'
    dta c' check linearity and overscan.          '
    dta c' Convergence: dots and RGB fields - alig'
    dta c'n the CRT electron guns.                '
    dta c'----------------------------------------'
    dta c'----------------------------------------'
    dta c' THIS SCREEN: 80-column text via the GTI'
    dta c'A2RGB COL80 overlay. Check focus,       '
    dta c' sharpness, edge bleed and ringing on sm'
    dta c'all text and thin lines.                '
    dta c'----------------------------------------'
    dta c'----------------------------------------'
    dta c' NOTE: with GTIA2RGB treat this suite as'
    dta c' a demonstrator, not a real             '
    dta c' calibration tool for RGB monitors:     '
    dta c'                                        '
    dta c'   15 kHz RGB :  use the 240p Test Suite'
    dta c'                                        '
    dta c'   31 kHz VGA :  use a DOS / Windows cal'
    dta c'ibration tool                           '
    dta c'----------------------------------------'
    dta c'----------------------------------------'
    dta c' HELP = menu    SELECT = next test      '
    dta c'            HanJammer / Rusty Bits 2026 '
