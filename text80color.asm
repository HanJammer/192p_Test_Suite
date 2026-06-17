// ==============================================================================
// 192p Test Suite - GTIA2RGB 80-Column Color (COL80 Modes 2/3/4)
// Test index 15, key F. Reachable only when the FPGA was detected at boot.
//
// SPACE cycles the colour-capable COL80 screens:
//   0 = Mode 2 ($D01D=$60) - CGA 16-colour per-character attributes
//   1 = Mode 3 ($D01D=$48) - Atari chroma + luma per character
//   2 = Mode 4 ($D01D=$68) - full RGB bands (R/G/B/grey intensity ramps)
//   3 = Mode 4 ($D01D=$68) - full RGB rich screen (ramps + rainbow)
//
// Screen data is too big to keep static (Mode 4 = 320 bytes/row), so it is
// GENERATED AT RUNTIME into the engine scratch area $9000-$AFFF. The grid
// tests and this test never run at the same time, so sharing the buffer is
// safe. Layout: each ANTIC mode F "line" (40 bytes) lives in its own 64-byte
// slot, so line N is at $9000 + N*64. 64 divides 4096, so no line ever
// crosses a 4 KB boundary - the ANTIC wrap bug can't bite. 128 slots
// (Mode 4 = 16 rows x 8 lines) fill exactly $9000-$AFFF.
//
// Per the manual the FPGA latches a row over 8 scan lines then renders it
// during the next 8, so every mode is 8 scan lines per row and the display
// lists carry a trailing 8-blank slot for the last row to render into.
//
// Code + tables sit at $8800 (free RAM between palette256's PMG at $8000-$87FF
// and the scratch buffer at $9000); the display lists sit at $B800. The only
// external call is g2r_load_font from text80.asm.
// ==============================================================================

    org $8800

LINEBUF = $9000

t80c_state:  .byte 0
t80c_d01d:   .byte $60, $48, $68, $68    ; Mode 2 / 3 / 4 bands / 4 rich

dl_table:    .word m2_dlist, m3_dlist, m4_dlist, m4_dlist

text80color_init:
    mva #$00 SDMCTL
    mva #$40 NMIEN              ; Disable DLI, keep VBLANK
    mva #$00 GPRIOR
    mva #$40 $D01D             ; COL80 on (Mode 1 bits) so font writes land
    jsr g2r_load_font          ; shared routine from text80.asm
    mva #0 t80c_state
    jsr _t80c_apply
    rts

text80color_toggle:
    inc t80c_state
    lda t80c_state
    cmp #4
    bne _tg_apply
    mva #0 t80c_state
_tg_apply:
    jsr _t80c_apply
    rts

// ------------------------------------------------------------------------------
// Set the mode register, regenerate the buffer, point ANTIC at the matching
// display list. DMA is off during generation so ANTIC never reads a half-
// written buffer.
// ------------------------------------------------------------------------------
_t80c_apply:
    mva #$00 SDMCTL
    ldx t80c_state
    lda t80c_d01d,x
    sta $D01D

    lda t80c_state
    beq _ap_s0
    cmp #1
    beq _ap_s1
    cmp #2
    beq _ap_s2
    jsr gen_mode4_rich         ; state 3: Mode 4 rich
    jmp _ap_dl
_ap_s0:
    jsr gen_mode2              ; state 0: Mode 2 CGA
    jmp _ap_dl
_ap_s1:
    jsr gen_mode3              ; state 1: Mode 3 Atari chroma+luma
    jmp _ap_dl
_ap_s2:
    jsr gen_mode4              ; state 2: Mode 4 bands
_ap_dl:
    lda t80c_state
    asl
    tax
    lda dl_table,x
    sta SDLSTL
    lda dl_table+1,x
    sta SDLSTL+1
    mva #$22 SDMCTL
    rts

// ------------------------------------------------------------------------------
// Zero-page scratch (only used while DMA is off, before display starts):
//   $E0/$E1 = destination pointer (set by line_addr)
//   $E2 cur_row   $E3 cur_line(base)   $E4 cur_col(start col of this line)
//   $E5 band/temp   $E6 chroma value   $E7 fill value/temp
//   $E8 channel idx   $E9 channel line offset
// ------------------------------------------------------------------------------
cur_row  = $E2
cur_line = $E3
cur_col  = $E4

// line_addr: X = line index (0-127) -> $E0/$E1 = LINEBUF + X*64.
// X*64 -> low byte = (X & 3) << 6, high byte = (X >> 2) + $90. Preserves X.
line_addr:
    txa
    lsr
    lsr
    clc
    adc #>LINEBUF
    sta $E1
    txa
    and #$03
    tay
    lda _la_lowbits,y
    sta $E0
    rts
_la_lowbits: .byte $00, $40, $80, $C0

// ------------------------------------------------------------------------------
// A (0-15) -> ATASCII hex digit char. Preserves Y.
// ------------------------------------------------------------------------------
hexdigit:
    cmp #10
    bcc _hd_num
    clc
    adc #$41-10                ; 'A'..'F'
    rts
_hd_num:
    clc
    adc #$30                   ; '0'..'9'
    rts

// ------------------------------------------------------------------------------
// fill_const: X = line idx, A = byte value -> 40 identical bytes.
// ------------------------------------------------------------------------------
fill_const:
    sta $E7
    jsr line_addr
    ldy #0
    lda $E7
_fc_l:
    sta ($E0),y
    iny
    cpy #40
    bne _fc_l
    rts

// ------------------------------------------------------------------------------
// fill_charband: X = line idx, cur_col = start col -> hex digit of the
// column's band (col_band[col]) per cell.
// ------------------------------------------------------------------------------
fill_charband:
    jsr line_addr
    ldy #0
_fcb_l:
    tya
    clc
    adc cur_col
    tax
    lda col_band,x
    jsr hexdigit
    sta ($E0),y
    iny
    cpy #40
    bne _fcb_l
    rts

// ------------------------------------------------------------------------------
// fill_attrband: X = line idx, cur_col = start col, cur_row = bg colour
// -> attribute byte (bg << 4) | band.
// ------------------------------------------------------------------------------
fill_attrband:
    jsr line_addr
    ldy #0
_fab_l:
    tya
    clc
    adc cur_col
    tax
    lda col_band,x
    sta $E7
    lda cur_row
    asl
    asl
    asl
    asl
    ora $E7
    sta ($E0),y
    iny
    cpy #40
    bne _fab_l
    rts

// ------------------------------------------------------------------------------
// fill_bandhi: X = line idx, cur_col = start col -> band value in the high
// nibble (col_band[col] << 4), low nibble 0. Used for chroma/luma/RGB where
// the swatch shows the background and the foreground (space) is invisible.
// ------------------------------------------------------------------------------
fill_bandhi:
    jsr line_addr
    ldy #0
_fbh_l:
    tya
    clc
    adc cur_col
    tax
    lda col_band,x
    asl
    asl
    asl
    asl
    sta ($E0),y
    iny
    cpy #40
    bne _fbh_l
    rts

// ------------------------------------------------------------------------------
// Mode 2 - CGA attributes. 16 rows; row r uses background colour r, swept
// across all 16 foreground colours (one per 5-column band). The character is
// the hex digit of the foreground colour, so you see coloured text on each
// background. Lines per row: charL, charR, attrL, attrR.
// ------------------------------------------------------------------------------
gen_mode2:
    mva #0 cur_row
_g2_row:
    lda cur_row
    asl
    asl                        ; base = row * 4
    sta cur_line

    ldx cur_line               ; charL
    mva #0 cur_col
    jsr fill_charband
    lda cur_line               ; charR
    clc
    adc #1
    tax
    mva #40 cur_col
    jsr fill_charband
    lda cur_line               ; attrL
    clc
    adc #2
    tax
    mva #0 cur_col
    jsr fill_attrband
    lda cur_line               ; attrR
    clc
    adc #3
    tax
    mva #40 cur_col
    jsr fill_attrband

    inc cur_row
    lda cur_row
    cmp #16
    bne _g2_row
    rts

// ------------------------------------------------------------------------------
// Mode 3 - Atari chroma + luma. 16 rows = 16 hues; columns sweep 16 lumas
// (5 cols each). Character is a space, so only the background shows: a full
// 16x16 Atari palette map. Lines per row: charL, charR, chromaL, chromaR,
// lumaL, lumaR. chroma byte = bg hue in high nibble; luma byte = bg luma in
// high nibble.
// ------------------------------------------------------------------------------
gen_mode3:
    mva #0 cur_row
_g3_row:
    lda cur_row
    asl                        ; *2
    sta $E5
    asl                        ; *4
    clc
    adc $E5                    ; *6
    sta cur_line

    ldx cur_line               ; charL = space
    lda #$20
    jsr fill_const
    lda cur_line               ; charR = space
    clc
    adc #1
    tax
    lda #$20
    jsr fill_const

    lda cur_row                ; chroma value = hue << 4
    asl
    asl
    asl
    asl
    sta $E6
    lda cur_line               ; chromaL
    clc
    adc #2
    tax
    lda $E6
    jsr fill_const
    lda cur_line               ; chromaR
    clc
    adc #3
    tax
    lda $E6
    jsr fill_const

    lda cur_line               ; lumaL = band << 4
    clc
    adc #4
    tax
    mva #0 cur_col
    jsr fill_bandhi
    lda cur_line               ; lumaR
    clc
    adc #5
    tax
    mva #40 cur_col
    jsr fill_bandhi

    inc cur_row
    lda cur_row
    cmp #16
    bne _g3_row
    rts

// ------------------------------------------------------------------------------
// Mode 4 - full RGB. 16 rows in 4 bands of 4: red, green, blue, grey. Columns
// sweep 16 intensity steps (5 cols each). Character is a space (background
// swatch). Lines per row: charL, charR, Rl, Rr, Gl, Gr, Bl, Br. Each channel
// byte = bg intensity in high nibble.
// ------------------------------------------------------------------------------
gen_mode4:
    mva #0 cur_row
_g4_row:
    lda cur_row
    asl
    asl
    asl                        ; base = row * 8
    sta cur_line
    lda cur_row
    lsr
    lsr                        ; band = row / 4 (0=R 1=G 2=B 3=grey)
    sta $E5

    ldx cur_line               ; charL = space
    lda #$20
    jsr fill_const
    lda cur_line               ; charR = space
    clc
    adc #1
    tax
    lda #$20
    jsr fill_const

    mva #0 $E8                 ; R channel, lines base+2 / base+3
    lda #2
    jsr do_channel
    mva #1 $E8                 ; G channel, lines base+4 / base+5
    lda #4
    jsr do_channel
    mva #2 $E8                 ; B channel, lines base+6 / base+7
    lda #6
    jsr do_channel

    inc cur_row
    lda cur_row
    cmp #16
    bne _g4_row
    rts

// ------------------------------------------------------------------------------
// do_channel: A = first line offset of this channel (2/4/6). $E8 = channel
// index, $E5 = band. Active when band == channel or band == 3 (grey): both
// halves get the intensity ramp; otherwise both halves are zeroed.
// ------------------------------------------------------------------------------
do_channel:
    sta $E9
    lda $E5
    cmp #3
    beq _dc_active
    cmp $E8
    beq _dc_active

    lda cur_line               ; inactive: zero both halves
    clc
    adc $E9
    tax
    lda #0
    jsr fill_const
    lda cur_line
    clc
    adc $E9
    clc
    adc #1
    tax
    lda #0
    jsr fill_const
    rts

_dc_active:
    lda cur_line               ; left half cols 0-39
    clc
    adc $E9
    tax
    mva #0 cur_col
    jsr fill_bandhi
    lda cur_line               ; right half cols 40-79
    clc
    adc $E9
    clc
    adc #1
    tax
    mva #40 cur_col
    jsr fill_bandhi
    rts

// ------------------------------------------------------------------------------
// Mode 4 (RICH) - same RGB mode as the bands screen ($68), but a fuller test
// card. 16 rows in 8 sections of 2 rows each, columns sweep 16 intensity
// steps (5 cols each):
//   grey ramp / red / green / blue / yellow / cyan / magenta / rainbow.
// The rainbow section drives R/G/B from a 16-entry hue LUT for a smooth
// spectrum. Characters are spaces; everything is background swatches.
// ------------------------------------------------------------------------------
gen_mode4_rich:
    mva #0 cur_row
_g4r_row:
    lda cur_row
    asl
    asl
    asl                        ; cur_line = row * 8
    sta cur_line
    lda cur_row
    lsr                        ; section = row / 2 (0-7)
    sta $E5

    ldx cur_line               ; charL = space
    lda #$20
    jsr fill_const
    lda cur_line               ; charR = space
    clc
    adc #1
    tax
    lda #$20
    jsr fill_const

    lda $E5
    cmp #7
    beq _g4r_rainbow

    // Ramp sections 0-6: each channel is either a 16-step ramp or zero.
    ldx $E5
    lda chan_mode_r,x
    ldy #2
    jsr do_rampchan
    ldx $E5
    lda chan_mode_g,x
    ldy #4
    jsr do_rampchan
    ldx $E5
    lda chan_mode_b,x
    ldy #6
    jsr do_rampchan
    jmp _g4r_next

_g4r_rainbow:
    mwa #rainbow_r _flut_tbl+1
    ldy #2
    jsr do_lutchan
    mwa #rainbow_g _flut_tbl+1
    ldy #4
    jsr do_lutchan
    mwa #rainbow_b _flut_tbl+1
    ldy #6
    jsr do_lutchan

_g4r_next:
    inc cur_row
    lda cur_row
    cmp #16
    bne _g4r_row
    rts

// ------------------------------------------------------------------------------
// do_rampchan: A = mode (0 = off/zero, 1 = 16-step ramp), Y = first line
// offset of the channel (2/4/6). Fills both halves of the channel for the
// current row. Uses $E8 (mode) / $E9 (offset) which fill_* never touch.
// ------------------------------------------------------------------------------
do_rampchan:
    sta $E8
    sty $E9
    lda cur_line
    clc
    adc $E9
    tax
    mva #0 cur_col
    lda $E8
    beq _drc_l0
    jsr fill_bandhi
    jmp _drc_r
_drc_l0:
    lda #0
    jsr fill_const
_drc_r:
    lda cur_line
    clc
    adc $E9
    clc
    adc #1
    tax
    mva #40 cur_col
    lda $E8
    beq _drc_r0
    jsr fill_bandhi
    rts
_drc_r0:
    lda #0
    jsr fill_const
    rts

// ------------------------------------------------------------------------------
// do_lutchan: Y = first line offset; _flut_tbl+1 already points at the 16-byte
// LUT. Fills both halves of the channel via fill_lut.
// ------------------------------------------------------------------------------
do_lutchan:
    sty $E9
    lda cur_line
    clc
    adc $E9
    tax
    mva #0 cur_col
    jsr fill_lut
    lda cur_line
    clc
    adc $E9
    clc
    adc #1
    tax
    mva #40 cur_col
    jsr fill_lut
    rts

// ------------------------------------------------------------------------------
// fill_lut: X = line idx, cur_col = start col, _flut_tbl+1/+2 = base of a
// 16-entry LUT (values 0-15). cell = LUT[col_band[col]] << 4.
// ------------------------------------------------------------------------------
fill_lut:
    jsr line_addr
    ldy #0
_fl_l:
    tya
    clc
    adc cur_col
    tax
    lda col_band,x
    tax
_flut_tbl:
    lda $FFFF,x                ; base self-modified by callers
    asl
    asl
    asl
    asl
    sta ($E0),y
    iny
    cpy #40
    bne _fl_l
    rts

// ------------------------------------------------------------------------------
// Per-section channel modes for the ramp sections (index = section 0-6;
// index 7 = rainbow, handled separately). 1 = ramp, 0 = off.
//          grey red grn blu yel cyn mag (rbw)
// ------------------------------------------------------------------------------
chan_mode_r: .byte 1,  1,  0,  0,  1,  0,  1,  0
chan_mode_g: .byte 1,  0,  1,  0,  1,  1,  0,  0
chan_mode_b: .byte 1,  0,  0,  1,  0,  1,  1,  0

// 16-step hue wheel for the rainbow section (4-bit R/G/B per entry).
rainbow_r: .byte $F,$F,$F,$C,$6,$0,$0,$0,$0,$0,$0,$6,$C,$F,$F,$F
rainbow_g: .byte $0,$6,$C,$F,$F,$F,$F,$F,$C,$6,$0,$0,$0,$0,$0,$0
rainbow_b: .byte $0,$0,$0,$0,$0,$0,$6,$C,$F,$F,$F,$F,$F,$C,$6,$0

// ------------------------------------------------------------------------------
// Column -> band lookup (0-15 across the 80 columns, 5 columns per band).
// ------------------------------------------------------------------------------
col_band:
    .byte 0,0,0,0,0, 1,1,1,1,1, 2,2,2,2,2, 3,3,3,3,3
    .byte 4,4,4,4,4, 5,5,5,5,5, 6,6,6,6,6, 7,7,7,7,7
    .byte 8,8,8,8,8, 9,9,9,9,9, 10,10,10,10,10, 11,11,11,11,11
    .byte 12,12,12,12,12, 13,13,13,13,13, 14,14,14,14,14, 15,15,15,15,15

// ------------------------------------------------------------------------------
// Display lists. Per-line LMS ($4F) points each mode F line at its 64-byte
// slot, so the generators and ANTIC agree on addresses and nothing crosses a
// 4 KB boundary. 3x$70 top overscan + 16 rows (8 scan lines each) + trailing
// $70 render slot + JVB.
//
// All three DLs live together in ONE 1 KB-aligned block at $B800 (total 917
// bytes, fits in $B800-$BBFF). A display list must never cross a 1 KB ($0400)
// boundary or ANTIC wraps the DL pointer inside the block and the picture
// desyncs - keeping them in a single aligned block guarantees safety.
// ------------------------------------------------------------------------------
    org $B800
m2_dlist:
    .byte $70, $70, $70
    .rept 16
        .byte $4F
        .word LINEBUF + (#*4)*64
        .byte $4F
        .word LINEBUF + (#*4+1)*64
        .byte $4F
        .word LINEBUF + (#*4+2)*64
        .byte $4F
        .word LINEBUF + (#*4+3)*64
        .byte $30                       ; 4 blank lines -> 8 scan lines/row
    .endr
    .byte $70                           ; render slot for the last row
    .byte $41
    .word m2_dlist

m3_dlist:
    .byte $70, $70, $70
    .rept 16
        .byte $4F
        .word LINEBUF + (#*6)*64
        .byte $4F
        .word LINEBUF + (#*6+1)*64
        .byte $4F
        .word LINEBUF + (#*6+2)*64
        .byte $4F
        .word LINEBUF + (#*6+3)*64
        .byte $4F
        .word LINEBUF + (#*6+4)*64
        .byte $4F
        .word LINEBUF + (#*6+5)*64
        .byte $10                       ; 2 blank lines -> 8 scan lines/row
    .endr
    .byte $70
    .byte $41
    .word m3_dlist

m4_dlist:
    .byte $70, $70, $70
    .rept 16
        .byte $4F
        .word LINEBUF + (#*8)*64
        .byte $4F
        .word LINEBUF + (#*8+1)*64
        .byte $4F
        .word LINEBUF + (#*8+2)*64
        .byte $4F
        .word LINEBUF + (#*8+3)*64
        .byte $4F
        .word LINEBUF + (#*8+4)*64
        .byte $4F
        .word LINEBUF + (#*8+5)*64
        .byte $4F
        .word LINEBUF + (#*8+6)*64
        .byte $4F
        .word LINEBUF + (#*8+7)*64       ; 8 mode F lines, no blank
    .endr
    .byte $70
    .byte $41
    .word m4_dlist
