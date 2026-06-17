// ==============================================================================
// 192p Test Suite - Gray Ramp (GTIA Mode 9)
// 16 shades, 5px blocks. Top: 00->0F, Bottom: 0F->00. 
// 96 scanlines per ramp (split perfectly in the middle).
// ==============================================================================

grayramp_init:
    mva #$00 SDMCTL
    mva #$00 $D01D
    mva #$40 NMIEN          ; VBLANK only
    
    mva #$40 GPRIOR         ; Enable GTIA Mode 9
    mva #$40 $D01B
    
    mva #GRAY_00 COLOR4     ; Background HUE = 0 (Grayscale)
    mva #GRAY_00 $D01A

    mwa #ramp_dlist SDLSTL
    mva #$22 SDMCTL
    rts

// ------------------------------------------------------------------------------
// DISPLAY LIST
// ------------------------------------------------------------------------------
    .align $0400
ramp_dlist:
    .byte $70, $70, $70     ; 24 scanlines normal overscan
    
    // Top Ramp: exactly 96 scanlines
    .rept 96
        .byte $4F, <ramp_top, >ramp_top
    .endr

    // Bottom Ramp: exactly 96 scanlines
    .rept 96
        .byte $4F, <ramp_bot, >ramp_bot
    .endr

    .byte $41, <ramp_dlist, >ramp_dlist

// ------------------------------------------------------------------------------
// PATTERN DATA (40 bytes = 80 pixels)
// ------------------------------------------------------------------------------
    .align $0400
ramp_top:
    .byte $00, $00, $01, $11, $11
    .byte $22, $22, $23, $33, $33
    .byte $44, $44, $45, $55, $55
    .byte $66, $66, $67, $77, $77
    .byte $88, $88, $89, $99, $99
    .byte $AA, $AA, $AB, $BB, $BB
    .byte $CC, $CC, $CD, $DD, $DD
    .byte $EE, $EE, $EF, $FF, $FF

ramp_bot:
    .byte $FF, $FF, $FE, $EE, $EE
    .byte $DD, $DD, $DC, $CC, $CC
    .byte $BB, $BB, $BA, $AA, $AA
    .byte $99, $99, $98, $88, $88
    .byte $77, $77, $76, $66, $66
    .byte $55, $55, $54, $44, $44
    .byte $33, $33, $32, $22, $22
    .byte $11, $11, $10, $00, $00