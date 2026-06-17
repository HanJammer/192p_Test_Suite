// ==============================================================================
// 192p Test Suite - PLUGE (160x192, ANTIC Mode E / Graphics 15)
// Exact proportional layout, x2 scaled to fit 160px width.
// ==============================================================================

pluge_dli_idx .byte 0
pluge_colors  .byte GRAY_0A, GRAY_05, GRAY_02

pluge_init:
    mva #$00 SDMCTL
    mva #$00 $D01D
    mva #$00 GPRIOR         ; Normal GTIA

    mva #GRAY_00 COLOR4     ; COLBAK (Background Margin & Gaps)
    mva #GRAY_00 COLBAK
    mva #GRAY_01 COLOR0     ; COLPF0 (Vertical Bars)
    mva #GRAY_01 $D016
    
    mwa #pluge_dlist SDLSTL
    mwa #pluge_dli VDSLST
    mwa #pluge_vbi $0224
    
    mva #$C0 NMIEN
    mva #$22 SDMCTL
    rts

// ------------------------------------------------------------------------------
// INTERRUPTS
// ------------------------------------------------------------------------------
pluge_dli:
    pha
    txa
    pha
    sta WSYNC
    ldx pluge_dli_idx
    lda pluge_colors,x
    sta $D017               ; Update Center Bar Color (COLPF1)
    inc pluge_dli_idx
    pla
    tax
    pla
    rti

pluge_vbi:
    lda current_state
    cmp #STATE_MENU
    bne _pluge_vbi_active
    mwa #$E462 $0224
    jmp $E462
_pluge_vbi_active:
    mva #0 pluge_dli_idx
    mva #GRAY_0F $D017      ; Set first color (0F) for the top block
    jmp $E462

// ------------------------------------------------------------------------------
// DISPLAY LIST
// ------------------------------------------------------------------------------
    .align $0400
pluge_dlist:
    .byte $70, $70, $70
    
    // Block 1 (0F) - 48 lines
    .rept 47
        .byte $4E, <pluge_pat, >pluge_pat
    .endr
    .byte $CE, <pluge_pat, >pluge_pat  ; DLI -> loads 0A
    
    // Block 2 (0A) - 48 lines
    .rept 47
        .byte $4E, <pluge_pat, >pluge_pat
    .endr
    .byte $CE, <pluge_pat, >pluge_pat  ; DLI -> loads 05
    
    // Block 3 (05) - 48 lines
    .rept 47
        .byte $4E, <pluge_pat, >pluge_pat
    .endr
    .byte $CE, <pluge_pat, >pluge_pat  ; DLI -> loads 02
    
    // Block 4 (02) - 48 lines
    .rept 48
        .byte $4E, <pluge_pat, >pluge_pat
    .endr
    
    .byte $41, <pluge_dlist, >pluge_dlist

// ------------------------------------------------------------------------------
// PATTERN DATA (40 bytes = 160 pixels)
// ------------------------------------------------------------------------------
    .align $0400
pluge_pat:
    // 20px Margin (00), 20px V-bar (01), 20px Gap (00), 40px Center (10), 20px Gap (00), 20px V-bar (01), 20px Margin (00)
    .byte $00, $00, $00, $00, $00
    .byte $55, $55, $55, $55, $55
    .byte $00, $00, $00, $00, $00
    .byte $AA, $AA, $AA, $AA, $AA, $AA, $AA, $AA, $AA, $AA
    .byte $00, $00, $00, $00, $00
    .byte $55, $55, $55, $55, $55
    .byte $00, $00, $00, $00, $00