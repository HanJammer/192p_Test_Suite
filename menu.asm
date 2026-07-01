// ==============================================================================
// 192p Test Suite - Main Menu Module
// ==============================================================================

MENU_COLOR_BG   = $00
MENU_COLOR_TEXT = $0A

menu_init:
    mva #$00 SDMCTL
    mva #$40 NMIEN              ; Disable DLI, keep VBLANK
    mva #$00 $D01D              ; GRACTL - Disable PMG
    mva #$00 GPRIOR             ; Clear priority

    mva #MENU_COLOR_BG COLOR4
    mva #MENU_COLOR_BG COLOR2
    mva #MENU_COLOR_TEXT COLOR1
    mwa #menu_dlist SDLSTL
    mva #$22 SDMCTL
    jsr menu_render_gtia_footer ; Patch the bottom row if GTIA2RGB was detected

    // Rainbow-title DLI: only when the FPGA is present. The DLI repaints
    // COLPF1 per scanline across the title row. All palette entries share
    // luma 8, so without HRBICOLOR (OSD set to OFF, or stock-GTIA semantics)
    // the title just renders at a steady luma - no flicker, no tell. With
    // HRBICOLOR ON/USER the FPGA feeds COLPF1 chroma to set pixels and the
    // title becomes a flowing rainbow.
    lda gtia2rgb_present
    beq _mi_done
    mva #$F0 menu_dlist+2       ; DLI bit on last blank-8 line before the title
    mva #$82 menu_dlist+27      ; DLI on row 22 - fires before the footer row
    mwa #menu_dli VDSLST
    mva #$10 $D01D              ; Bit 4 = HRBICOLOR USER override (COL80 off,
                                ; PMG DMA bits 0-1 stay clear)
    mva #$C0 NMIEN              ; Enable DLI
_mi_done:
    rts

// ------------------------------------------------------------------------------
// Rainbow DLI - fires twice per frame: once on the last blank scanline before
// the title row, once at the end of row 22 (just before the GTIA2RGB footer).
// Both passes repaint COLPF1 on 8 scanlines from rainbow_pal at the shared
// offset, so title and footer flow in sync. The flow advances only on the
// title pass (top of screen, low VCOUNT) so it still steps once per frame.
// ------------------------------------------------------------------------------
rainbow_offset: .byte 0
rainbow_frame:  .byte 0

// ------------------------------------------------------------------------------
// 15 hues (no hue 0 - gray reads as a dull line sweeping through the rainbow),
// doubled so offset+row needs no masking. Wrap point is 15, not 16.
// ------------------------------------------------------------------------------
rainbow_pal:
    .byte $18,$28,$38,$48,$58,$68,$78,$88,$98,$A8,$B8,$C8,$D8,$E8,$F8
    .byte $18,$28,$38,$48,$58,$68,$78,$88,$98,$A8,$B8,$C8,$D8,$E8,$F8

menu_dli:
    pha
    txa
    pha
    tya
    pha

    ldx rainbow_offset
    ldy #8
_mdli_line:
    lda rainbow_pal,x
    sta WSYNC                   ; Land the write in HBLANK of the next line
    sta COLPF1
    inx
    dey
    bne _mdli_line

    // Restore the normal text luma from the next scanline onward
    lda #MENU_COLOR_TEXT
    sta WSYNC
    sta COLPF1

    // Footer pass (bottom of screen)? Then skip the flow advance - it
    // already happened on this frame's title pass.
    lda VCOUNT
    cmp #$40
    bcs _mdli_done

    // Advance the flow one palette step every 4th frame (wrap at 15 hues)
    inc rainbow_frame
    lda rainbow_frame
    and #3
    bne _mdli_done
    ldx rainbow_offset
    inx
    cpx #15
    bne _mdli_save
    ldx #0
_mdli_save:
    stx rainbow_offset
_mdli_done:
    pla
    tay
    pla
    tax
    pla
    rti

// ------------------------------------------------------------------------------
// Render the GTIA2RGB status footer on the bottom row of the menu screen.
// If the FPGA was detected at boot, copies a centred "GTIA2RGB vX.Y detected"
// template into menu_footer_row and patches the two digits from the firmware
// version bytes. If absent, leaves the row at its compile-time default (all
// blanks) so stock GTIA users see a clean menu.
// ------------------------------------------------------------------------------
GTIA_FOOTER_MAJOR_X = 19        ; '0' position of major version digit in template
GTIA_FOOTER_MINOR_X = 21        ; '0' position of minor version digit in template

menu_render_gtia_footer:
    lda gtia2rgb_present
    bne _mrgf_present
    rts                         ; Not detected: footer + E row stay blank
_mrgf_present:
    ldx #39
_mrgf_copy:
    lda gtia2rgb_template,x
    sta menu_footer_row,x
    lda gtia2rgb_e_template,x
    sta menu_e_row,x            ; Reveal the E. menu entry
    lda gtia2rgb_f_template,x
    sta menu_f_row,x            ; Reveal the F. menu entry
    lda gtia2rgb_hint_template,x
    sta menu_hint_row,x         ; "Press 1-F" instead of "1-D"
    dex
    bpl _mrgf_copy

    // Patch the two version digits. $D01C / $D01D return values 0-9 as raw
    // bytes; ANTIC mode 2 internal char codes for '0'-'9' live at $10-$19.
    lda gtia2rgb_major
    clc
    adc #$10
    sta menu_footer_row + GTIA_FOOTER_MAJOR_X
    lda gtia2rgb_minor
    clc
    adc #$10
    sta menu_footer_row + GTIA_FOOTER_MINOR_X
    rts

gtia2rgb_template:
    dta d'         GTIA2RGB v0.0 detected         '
gtia2rgb_e_template:
    dta d'   E. 80-Column Text (GTIA2RGB)         '
gtia2rgb_f_template:
    dta d'   F. 80-Column Color (GTIA2RGB)        '
gtia2rgb_hint_template:
    dta d'  Press 1-F to select a test pattern    '

menu_dlist:
    .byte $70, $70, $70, $42
    .word menu_screen
    .byte $02, $02, $02, $02, $02, $02, $02, $02, $02, $02
    .byte $02, $02, $02, $02, $02, $02, $02, $02, $02, $02
    .byte $02, $02, $02, $41
    .word menu_dlist

// ------------------------------------------------------------------------------
// MENU SCREEN AND VERSION INFO
// ------------------------------------------------------------------------------
menu_screen:
    dta d'          192p Test Suite v.0.5         '
    dta d'   Display Test Suite for 8-bit Atari   '
    dta d'      HanJammer / Rusty Bits 2026       '
    dta d'                                        '
    dta d'   1. PLUGE                             '
    dta d'   2. SMPTE Color Bars                  '
    dta d'   3. EBU Color Bars                    '
    dta d'   4. Color Bars with Gray Scale        '
    dta d'   5. Monoscope Pattern                 '
    dta d'   6. Grid (160x192)                    '
    dta d'   7. Grid (320x192)                    '
    dta d'   8. Gray Ramp                         '
    dta d'   9. RGB Ramp                          '
    dta d'   0. 256-color Palette                 '
    dta d'   A. Solid Colors                      '
    dta d'   B. Convergence Dots                  '
    dta d'   C. Convergence RGB Fields            '
    dta d'   D. Readme (Readability Test)         '
menu_e_row:
    dta d'                                        '
menu_f_row:
    dta d'                                        '
menu_hint_row:
    dta d'  Press 1-D to select a test pattern    '
    dta d'  SELECT to cycle tests, HELP to menu   '
    dta d'                                        '
menu_footer_row:
    dta d'                                        '   ; GTIA2RGB status (runtime)
    dta d'                                        '