// ==============================================================================
// 192p Test Suite - SMPTE Color Bars (GTIA Mode 10)
// Uses config.asm definitions. Perfect layout with GTIA bug avoidance.
// ==============================================================================

smpte_dli_mid_val .byte 0
smpte_dli_bot_1   .byte 0
smpte_dli_bot_2   .byte 0
smpte_dli_bot_3   .byte 0
smpte_dli_bot_4   .byte 0
smpte_dli_bot_6   .byte 0

smpte_init:
    mva #$00 SDMCTL
    mva #$00 $D01D
    mva #$80 GPRIOR
    mva #$80 $D01B

    ; Set Margins & Bugfix! PCOLR0 = $00 absorbs the GTIA left-edge artifact.
    mva #$00 $02C0          ; PCOLR0 = Super-Black 
    mva #$00 $02C8          ; COLOR4 = Super-Black (Overscan)

    lda system_region
    beq _smpte_pal

_smpte_ntsc:
    mva #NTSC_75_GRAY $02C1
    mva #NTSC_YELLOW  $02C2
    mva #NTSC_CYAN    $02C3
    mva ref_ntsc_75_grn $02C4
    mva #NTSC_MAGENTA $02C5
    mva ref_ntsc_75_red $02C6
    mva ref_ntsc_75_blu $02C7
    
    mva #NTSC_75_BLK  smpte_dli_mid_val
    mva #NTSC_MINUS_I smpte_dli_bot_1
    mva #NTSC_WHITE   smpte_dli_bot_2
    mva #NTSC_PLUS_Q  smpte_dli_bot_3
    mva #NTSC_75_BLK  smpte_dli_bot_4
    mva #NTSC_4_ABOVE smpte_dli_bot_6
    jmp _smpte_common

_smpte_pal:
    mva #PAL_75_GRAY  $02C1
    mva #PAL_YELLOW   $02C2
    mva #PAL_CYAN     $02C3
    mva ref_pal_75_grn $02C4
    mva #PAL_MAGENTA  $02C5
    mva ref_pal_75_red $02C6
    mva ref_pal_75_blu $02C7
    
    mva #PAL_75_BLK   smpte_dli_mid_val
    mva #PAL_MINUS_I  smpte_dli_bot_1
    mva #PAL_WHITE    smpte_dli_bot_2
    mva #PAL_PLUS_Q   smpte_dli_bot_3
    mva #PAL_75_BLK   smpte_dli_bot_4
    mva #PAL_4_ABOVE  smpte_dli_bot_6

_smpte_common:
    mwa #smpte_dli_mid VDSLST
    mwa #smpte_vbi $0224
    mva #$C0 NMIEN

    mwa #smpte_dlist SDLSTL
    mva #$22 SDMCTL
    rts

smpte_dli_mid:
    pha
    sta WSYNC
    lda smpte_dli_mid_val
    sta $D018               ; Swap Red to 75% Black
    lda #<smpte_dli_bot
    sta VDSLST
    lda #>smpte_dli_bot
    sta VDSLST+1
    pla
    rti

smpte_dli_bot:
    pha
    sta WSYNC
    lda smpte_dli_bot_1
    sta $D013               ; PCOLR1
    lda smpte_dli_bot_2
    sta $D014               ; PCOLR2
    lda smpte_dli_bot_3
    sta $D015               ; PCOLR3
    lda smpte_dli_bot_4
    sta $D016               ; COLOR0
    lda smpte_dli_bot_6
    sta $D018               ; COLOR2
    pla
    rti

smpte_vbi:
    lda current_state
    cmp #STATE_MENU
    bne _smpte_vbi_active
    mwa #$E462 $0224
    jmp $E462
_smpte_vbi_active:
    mwa #smpte_dli_mid VDSLST
    jmp $E462

    .align $0400
smpte_dlist:
    .byte $70, $70, $70
    .rept 127
        .byte $4F, <smpte_top, >smpte_top
    .endr
    .byte $CF, <smpte_top, >smpte_top      ; DLI -> Mid
    .rept 15
        .byte $4F, <smpte_mid, >smpte_mid
    .endr
    .byte $CF, <smpte_mid, >smpte_mid      ; DLI -> Bot
    .rept 48
        .byte $4F, <smpte_bot, >smpte_bot
    .endr
    .byte $41, <smpte_dlist, >smpte_dlist

    .align $0400
smpte_top:
    .byte $00, $00, $01, $11, $11, $11, $11, $12
    .byte $22, $22, $22, $22, $23, $33, $33, $33
    .byte $33, $34, $44, $44, $44, $44, $45, $55
    .byte $55, $55, $55, $56, $66, $66, $66, $66
    .byte $67, $77, $77, $77, $77, $70, $00, $00

smpte_mid:
    .byte $00, $00, $07, $77, $77, $77, $77, $76
    .byte $66, $66, $66, $66, $65, $55, $55, $55
    .byte $55, $56, $66, $66, $66, $66, $63, $33
    .byte $33, $33, $33, $36, $66, $66, $66, $66
    .byte $61, $11, $11, $11, $11, $10, $00, $00

smpte_bot:
    .byte $00, $00, $01, $11, $11, $11, $11, $11
    .byte $12, $22, $22, $22, $22, $22, $22, $33
    .byte $33, $33, $33, $33, $33, $44, $44, $44
    .byte $44, $44, $44, $40, $00, $44, $46, $66
    .byte $60, $00, $00, $00, $00, $00, $00, $00