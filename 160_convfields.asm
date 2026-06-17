// ==============================================================================
// 192p Test Suite - Convergence RGB Fields (160x192)
// Custom 8x8 Matrix. Uses PMG + DLI Hardware Magic to inject the 5th color!
// ==============================================================================

convfields_state: .byte 0
cf_dli_state:     .byte 0

convfields_init:
    mva #$00 SDMCTL
    mva #$00 $D01D
    mva #$00 GPRIOR
    
    mva #0 $D00D
    mva #0 $D00E
    mva #0 $D00F
    mva #0 $D010
    mva #0 $D011
    
    jsr clear_buffer
    lda #$0E                ; ANTIC Mode 15 (160x192)
    jsr build_dlist
    
    jsr init_pmg            ; Setup PMG Graphics RAM for the White Blocks
    
    ; Setup PMG Hardware Registers
    mva #$80 $D407          ; PMBASE = $8000
    mva #1 $D004            ; SIZEP0 = Double (16px)
    mva #0 $D005            ; SIZEP1 = Normal (We use 3px)
    mva #1 $D006            ; SIZEP2 = Double (16px)
    mva #0 $D007            ; SIZEP3 = Normal (We use 3px)
    
    lda #PAL_WHITE
    sta $D012
    sta $D013
    sta $D014
    sta $D015
    
    mva #0 convfields_state ; Default: Solid blocks
    jsr _apply_conv_state
    
    mwa #mono_dlist SDLSTL
    rts

convfields_toggle:
    lda convfields_state
    eor #$01                ; Toggle between 0 and 1
    sta convfields_state
    jsr _apply_conv_state
    rts

_apply_conv_state:
    jsr draw_convfields

    lda convfields_state
    beq _state_solid
    
_state_border:
    mva #PAL_BLACK COLOR4
    mva #PAL_BLACK COLBAK
    
    jsr setup_dlis          ; Inject DLI into Display List
    mwa #convfields_dli VDSLST
    mva #$C0 NMIEN          ; Enable DLI
    mva #$3E SDMCTL         ; Enable PMG (Single line resolution)
    jmp _set_rgb
    
_state_solid:
    mva #PAL_WHITE COLOR4
    mva #PAL_WHITE COLBAK
    
    jsr remove_dlis         ; Clean Display List
    mva #$40 NMIEN          ; Disable DLI
    mva #$22 SDMCTL         ; Standard DMA (Disable PMG)
    
_set_rgb:
    lda system_region
    beq _pal
_ntsc:
    lda ref_ntsc_red
    sta COLOR0
    sta $D016
    lda ref_ntsc_green
    sta COLOR1
    lda ref_ntsc_blue
    sta COLOR2
    rts
_pal:
    lda ref_pal_red
    sta COLOR0
    sta $D016
    lda ref_pal_green
    sta COLOR1
    lda ref_pal_blue
    sta COLOR2
    rts

// ------------------------------------------------------------------------------
// PMG GENERATOR - Draws White Blocks into Sprite Memory
// ------------------------------------------------------------------------------
init_pmg:
    ; Clear PMG RAM $8400-$87FF
    lda #<$8400
    sta $E0
    lda #>$8400
    sta $E1
    ldy #0
    tya
_clr_pm:
    sta ($E0),y
    iny
    bne _clr_pm
    inc $E1
    lda $E1
    cmp #$88
    bne _clr_pm
    
    ; Draw the shapes!
    lda #32
    sta $E2                 ; Start at visible scanline 32
    ldx #0
_pm_row:
    inc $E2                 ; Leave 1 line blank for the horizontal black gap
    ldy #23                 ; 23 solid lines
_pm_line:
    sty $E3
    ldy $E2
    lda #$FF                ; Solid 16px block
    sta $8400,y             ; Player 0
    sta $8600,y             ; Player 2
    lda #$E0                ; Partial 3px block (11100000)
    sta $8500,y             ; Player 1
    sta $8700,y             ; Player 3
    inc $E2
    ldy $E3
    dey
    bne _pm_line
    inx
    cpx #8
    bne _pm_row
    rts

// ------------------------------------------------------------------------------
// DLI LOGIC - Injects and handles the interrupts
// ------------------------------------------------------------------------------
setup_dlis:
    mwa #mono_dlist $E0
    ldy #0
    lda #$F0                ; DLI on the first blank line before screen
    sta ($E0),y
    lda $E0
    clc
    adc #3
    sta $E0
    bcc _sd1
    inc $E0+1
_sd1:
    lda $E0
    clc
    adc #69                 ; 23 lines * 3 bytes
    sta $E0
    bcc _sd2
    inc $E0+1
_sd2:
    ldx #7
_sd_loop:
    ldy #0
    lda #$CE                ; LMS + DLI bit ($4E + $80)
    sta ($E0),y
    lda $E0
    clc
    adc #72                 ; 24 lines * 3 bytes
    sta $E0
    bcc _sd3
    inc $E0+1
_sd3:
    dex
    bne _sd_loop
    mva #1 cf_dli_state     ; Prime the state machine
    rts

remove_dlis:
    mwa #mono_dlist $E0
    ldy #0
    lda #$70                ; Remove DLI
    sta ($E0),y
    lda $E0
    clc
    adc #3
    sta $E0
    bcc _rd1
    inc $E0+1
_rd1:
    lda $E0
    clc
    adc #69
    sta $E0
    bcc _rd2
    inc $E0+1
_rd2:
    ldx #7
_rd_loop:
    ldy #0
    lda #$4E                ; Pure LMS
    sta ($E0),y
    lda $E0
    clc
    adc #72
    sta $E0
    bcc _rd3
    inc $E0+1
_rd3:
    dex
    bne _rd_loop
    rts

convfields_dli:
    pha                     ; Save A
    lda cf_dli_state
    beq _cf_state_b
_cf_state_a:
    mva #49 $D000           ; HPOSP0 (Block 0, X=48+1)
    mva #65 $D001           ; HPOSP1
    mva #129 $D002          ; HPOSP2 (Block 4, X=128+1)
    mva #145 $D003          ; HPOSP3
    mva #0 cf_dli_state
    jmp _cf_dli_end
_cf_state_b:
    mva #89 $D000           ; HPOSP0 (Block 2, X=88+1)
    mva #105 $D001          ; HPOSP1
    mva #169 $D002          ; HPOSP2 (Block 6, X=168+1)
    mva #185 $D003          ; HPOSP3
    mva #1 cf_dli_state
_cf_dli_end:
    pla                     ; Restore A
    rti

// ------------------------------------------------------------------------------
// 8x8 RAM GENERATOR (Fills $9000 and $A000 buffers)
// ------------------------------------------------------------------------------
draw_convfields:
    mwa #$9000 $E0
    ldx #0
_top_loop:
    jsr draw_8x8_row
    inx
    cpx #4
    bne _top_loop

    mwa #$A000 $E0
    ldx #4
_bot_loop:
    jsr draw_8x8_row
    inx
    cpx #8
    bne _bot_loop
    rts

draw_8x8_row:
    txa
    and #1
    bne _is_pat2
_is_pat1:
    lda convfields_state
    beq _s1
    mwa #pat_black $E2
    jsr copy_line
    mwa #pat_border_1 $E2
    jmp _fill_23
_s1:
    mwa #pat_solid_1 $E2
    jmp _fill_24
_is_pat2:
    lda convfields_state
    beq _s2
    mwa #pat_black $E2
    jsr copy_line
    mwa #pat_border_2 $E2
    jmp _fill_23
_s2:
    mwa #pat_solid_2 $E2
    jmp _fill_24

_fill_24:
    ldy #24
    jmp _cf_line_loop
_fill_23:
    ldy #23
_cf_line_loop:
    tya
    pha
    jsr copy_line
    pla
    tay
    dey
    bne _cf_line_loop
    rts

copy_line:
    ldy #0
_cl:
    lda ($E2),y
    sta ($E0),y
    iny
    cpy #40
    bne _cl
    lda $E0
    clc
    adc #40
    sta $E0
    bcc _cl_skip
    inc $E0+1
_cl_skip:
    rts

// ------------------------------------------------------------------------------
// LINE PATTERNS
// ------------------------------------------------------------------------------
pat_black:
    .rept 40
        .byte $00
    .endr

pat_solid_1:    ; W, B, G, R, W, B, G, R
    .byte $00,$00,$00,$00,$00, $FF,$FF,$FF,$FF,$FF, $AA,$AA,$AA,$AA,$AA, $55,$55,$55,$55,$55
    .byte $00,$00,$00,$00,$00, $FF,$FF,$FF,$FF,$FF, $AA,$AA,$AA,$AA,$AA, $55,$55,$55,$55,$55

pat_solid_2:    ; G, R, W, B, G, R, W, B
    .byte $AA,$AA,$AA,$AA,$AA, $55,$55,$55,$55,$55, $00,$00,$00,$00,$00, $FF,$FF,$FF,$FF,$FF
    .byte $AA,$AA,$AA,$AA,$AA, $55,$55,$55,$55,$55, $00,$00,$00,$00,$00, $FF,$FF,$FF,$FF,$FF

pat_border_1:   ; 1px Gap injected on left!
    .byte $00,$00,$00,$00,$00, $3F,$FF,$FF,$FF,$FF, $2A,$AA,$AA,$AA,$AA, $15,$55,$55,$55,$55
    .byte $00,$00,$00,$00,$00, $3F,$FF,$FF,$FF,$FF, $2A,$AA,$AA,$AA,$AA, $15,$55,$55,$55,$55

pat_border_2:
    .byte $2A,$AA,$AA,$AA,$AA, $15,$55,$55,$55,$55, $00,$00,$00,$00,$00, $3F,$FF,$FF,$FF,$FF
    .byte $2A,$AA,$AA,$AA,$AA, $15,$55,$55,$55,$55, $00,$00,$00,$00,$00, $3F,$FF,$FF,$FF,$FF