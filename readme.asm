// ==============================================================================
// 192p Test Suite - Readme / Instructions (Text Mode)
// Spacebar cycles full-screen text modes to test CRT text readability.
// Each mode appears in normal then inverse (6 states total):
//   0,1 = Graphics 0 (40x24 hi-res)
//   2,3 = Graphics 1 (20x24 double-width text)
//   4,5 = Graphics 2 (20x12 large text)
// Even state = white-on-black, odd = black-on-white. All monochrome -
// the suite's color/chroma tests live in the dedicated pattern screens.
// ==============================================================================

NUM_README_STATES = 6

readme_state: .byte 0

// ------------------------------------------------------------------------------
// GR.0 hi-res monochrome palette: 0 = white/black, 1 = black/white (inverse)
// ------------------------------------------------------------------------------
readme_pal_bg:   .byte PAL_BLACK, PAL_WHITE
readme_pal_txt:  .byte PAL_WHITE, PAL_BLACK

readme_init:
    mva #$00 SDMCTL
    mva #$40 NMIEN              ; Disable DLI, keep VBLANK
    mva #$00 $D01D              ; Disable PMG
    mva #$00 GPRIOR             ; Clear priority
    mva #$E0 CHBAS              ; Restore ROM charset (engine tests may change it)

    mva #0 readme_state
    jsr _readme_apply
    mva #$22 SDMCTL
    rts

readme_toggle:
    inc readme_state
    lda readme_state
    cmp #NUM_README_STATES
    bne _skip_r_reset
    mva #0 readme_state
_skip_r_reset:
    jsr _readme_apply
    rts

// ------------------------------------------------------------------------------
// Select display list + colors for the current state:
//   0,1 = Graphics 0    2,3 = Graphics 1    4,5 = Graphics 2
// ------------------------------------------------------------------------------
_readme_apply:
    lda readme_state
    cmp #2
    bcc _apply_g0               ; states 0,1
    cmp #4
    bcc _apply_g1               ; states 2,3

    // States 4,5: Graphics 2
    jsr _apply_mono_colors
    mwa #readme_dlist_g2 SDLSTL
    rts

_apply_g1:
    jsr _apply_mono_colors
    mwa #readme_dlist_g1 SDLSTL
    rts

_apply_g0:
    jsr _apply_readme_colors
    mwa #readme_dlist SDLSTL
    rts

// ------------------------------------------------------------------------------
// GR.0 monochrome text/background (X = state 0 or 1). White/black are
// region-independent, so no PAL/NTSC branch is needed here.
// ------------------------------------------------------------------------------
_apply_readme_colors:
    ldx readme_state
    lda readme_pal_bg,x
    sta COLOR4                  ; Background / border
    sta COLOR2
    lda readme_pal_txt,x
    sta COLOR1                  ; Text luminance
    rts

// GR.1 / GR.2 monochrome. Text = COLPF0 (char hi-bits 00), bg/border = COLBK.
// Odd state = inverse (black text on white).
_apply_mono_colors:
    lda readme_state
    and #1
    bne _mono_inverse
    // Normal: white text on black
    mva #PAL_BLACK COLOR4       ; Background / border
    mva #PAL_BLACK COLOR2
    mva #PAL_WHITE COLOR0       ; Text (COLPF0)
    rts
_mono_inverse:
    // Inverse: black text on white
    mva #PAL_WHITE COLOR4       ; Background / border
    mva #PAL_WHITE COLOR2
    mva #PAL_BLACK COLOR0       ; Text (COLPF0)
    rts

// ------------------------------------------------------------------------------
// DISPLAY LIST (Graphics 0 - 40x24 characters)
// ------------------------------------------------------------------------------
    .align $0400
readme_dlist:
    .byte $70, $70, $70, $42
    .word readme_screen
    .rept 23
        .byte $02
    .endr
    .byte $41
    .word readme_dlist

// ------------------------------------------------------------------------------
// TEXT DATA (Must be exactly 24 lines, 40 chars each)
// Space padding is required!
// ------------------------------------------------------------------------------
readme_screen:
    dta d' 192p TEST SUITE         HanJammer 2026 '
    dta d'----------------------------------------'
    dta d' CONTROLS                               '
    dta d'  HELP    return to main menu           '
    dta d'  SELECT  cycle to next test            '
    dta d'  SPACE   toggle pattern variation      '
    dta d'  1-D     jump to test (see main menu)  '
    dta d'----------------------------------------'
    dta d' ABOUT THE TESTS                        '
    dta d' Standard calibration: PLUGE, SMPTE,    '
    dta d' EBU, color bars with gray scale -      '
    dta d' set black level with PLUGE first.      '
    dta d' Geometry: 160/320 grids, monoscope -   '
    dta d' check linearity and overscan.          '
    dta d' Convergence: dots and RGB fields -     '
    dta d' align CRT electron guns.               '
    dta d'----------------------------------------'
    dta d' THIS SCREEN: text readability test.    '
    dta d' SPACE cycles text modes and inverse:   '
    dta d'  GR.0 40x24  GR.1 20x24  GR.2 20x12    '
    dta d' Check focus, sharpness, edge bleed     '
    dta d' and ringing on text and thin lines.    '
    dta d'----------------------------------------'
    dta d' HELP = menu        SELECT = next test  '

// ------------------------------------------------------------------------------
// DISPLAY LIST (Graphics 1 - ANTIC mode 6, 20x24 double-width chars)
// Aligned to $0400: DL (32B) + screen (480B) = 512B stays inside one 4KB block.
// ------------------------------------------------------------------------------
    .align $0400
readme_dlist_g1:
    .byte $70, $70, $70, $46
    .word readme_screen_g1
    .rept 23
        .byte $06
    .endr
    .byte $41
    .word readme_dlist_g1

// ------------------------------------------------------------------------------
// 20 chars x 24 lines. GR.1 shows the 64-glyph upper-case set only.
// ------------------------------------------------------------------------------
readme_screen_g1:
    dta d'                    '
    dta d'  192P TEST SUITE   '
    dta d'                    '
    dta d' GR.1 TEXT MODE     '
    dta d' 20 X 24 WHITE/BLK  '
    dta d'                    '
    dta d' ABCDEFGHIJKLMNOPQR '
    dta d' STUVWXYZ  0123456  '
    dta d' 789 .,:-+*=/()     '
    dta d'                    '
    dta d' READABILITY TEST   '
    dta d' CHECK EDGE BLEED   '
    dta d' AND COLOR FRINGE   '
    dta d'                    '
    dta d' IIIIIIIIIIIIIIIIII '
    dta d' MMMMMMMMMMMMMMMMMM '
    dta d' WWWWWWWWWWWWWWWWWW '
    dta d'                    '
    dta d' SPACE = NEXT MODE  '
    dta d' SELECT = NEXT TEST '
    dta d' HELP = MAIN MENU   '
    dta d'                    '
    dta d'                    '
    dta d'                    '

// ------------------------------------------------------------------------------
// DISPLAY LIST (Graphics 2 - ANTIC mode 7, 20x12 double-width+height chars)
// Aligned to $0400: DL (20B) + screen (240B) = 260B stays inside one 4KB block.
// ------------------------------------------------------------------------------
    .align $0400
readme_dlist_g2:
    .byte $70, $70, $70, $47
    .word readme_screen_g2
    .rept 11
        .byte $07
    .endr
    .byte $41
    .word readme_dlist_g2

// ------------------------------------------------------------------------------
// 20 chars x 12 lines. GR.2 shows the 64-glyph upper-case set only.
// ------------------------------------------------------------------------------
readme_screen_g2:
    dta d'                    '
    dta d'  192P TEST SUITE   '
    dta d'                    '
    dta d' GR.2 BIG TEXT      '
    dta d' 20 X 12 MODE       '
    dta d'                    '
    dta d' ABCDEFGH 012345    '
    dta d' SHARPNESS TEST     '
    dta d'                    '
    dta d' SPACE = NEXT MODE  '
    dta d' SELECT = NEXT TEST '
    dta d' HELP = MENU        '