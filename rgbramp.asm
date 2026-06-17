// ==============================================================================
// 192p Test Suite - RGB + Gray Ramp (GTIA Mode 9)
// 64 colors! 4 Ascending Ramps with flawless hardware timing.
// ==============================================================================

rgb_state  .byte 0
rgb_colors .byte 0, 0, 0, 0, 0, 0, 0

rgbramp_init:
    mva #$00 SDMCTL
    mva #$00 $D01D
    mva #$40 GPRIOR
    mva #$40 $D01B

    lda system_region
    beq _rgb_pal
_rgb_ntsc:
    lda ref_ntsc_red
    and #$F0
    sta rgb_colors
    lda ref_ntsc_green
    and #$F0
    sta rgb_colors+2
    lda ref_ntsc_blue
    and #$F0
    sta rgb_colors+4
    jmp _rgb_common
_rgb_pal:
    lda ref_pal_red
    and #$F0
    sta rgb_colors
    lda ref_pal_green
    and #$F0
    sta rgb_colors+2
    lda ref_pal_blue
    and #$F0
    sta rgb_colors+4

_rgb_common:
    mva #$00 rgb_colors+1       ; Gap 1
    mva #$00 rgb_colors+3       ; Gap 2
    mva #$00 rgb_colors+5       ; Gap 3
    mva #$00 rgb_colors+6       ; Gray hue

    mwa #rgb_dli VDSLST
    mwa #rgb_vbi $0224
    mva #$C0 NMIEN
    mwa #rgb_dlist SDLSTL
    mva #$22 SDMCTL
    rts

// ------------------------------------------------------------------------------
// PRE-FETCH DLI (Zero-artifact timing trick)
// ------------------------------------------------------------------------------
rgb_dli:
    pha
    txa
    pha
    ldx rgb_state
    lda rgb_colors,x            ; Get next color BEFORE pausing!
    sta WSYNC                   ; Wait for HBLANK
    sta $D01A                   ; Apply instantly!
    inc rgb_state
    pla
    tax
    pla
    rti

rgb_vbi:
    lda current_state
    cmp #STATE_MENU
    bne _rgb_vbi_active
    mwa #$E462 $0224
    jmp $E462
_rgb_vbi_active:
    mva #0 rgb_state
    mva #$00 COLOR4             ; Maintain true black borders
    mva #$00 $D01A              ; Hue 0 for top margin
    jmp $E462

    .align $0400
rgb_dlist:
    .byte $70, $70, $70         ; 24 lines standard overscan
    .byte $70, $00, $80         ; 10 lines top margin. DLI 0 -> Triggers Red
    
    // RED
    .rept 39
        .byte $4F, <ramp_asc, >ramp_asc
    .endr
    .byte $CF, <ramp_asc, >ramp_asc     ; DLI 1 -> Triggers GAP

    .byte $20, $80                      ; 4 lines gap. DLI 2 -> Triggers Green

    // GREEN
    .rept 39
        .byte $4F, <ramp_asc, >ramp_asc
    .endr
    .byte $CF, <ramp_asc, >ramp_asc     ; DLI 3 -> Triggers GAP

    .byte $20, $80                      ; 4 lines gap. DLI 4 -> Triggers Blue

    // BLUE
    .rept 39
        .byte $4F, <ramp_asc, >ramp_asc
    .endr
    .byte $CF, <ramp_asc, >ramp_asc     ; DLI 5 -> Triggers GAP

    .byte $20, $80                      ; 4 lines gap. DLI 6 -> Triggers Gray

    // GRAY
    .rept 40
        .byte $4F, <ramp_asc, >ramp_asc
    .endr
    
    .byte $70, $10, $41, <rgb_dlist, >rgb_dlist

    .align $0400
ramp_asc:
    .byte $00, $00, $01, $11, $11, $22, $22, $23, $33, $33
    .byte $44, $44, $45, $55, $55, $66, $66, $67, $77, $77
    .byte $88, $88, $89, $99, $99, $AA, $AA, $AB, $BB, $BB
    .byte $CC, $CC, $CD, $DD, $DD, $EE, $EE, $EF, $FF, $FF