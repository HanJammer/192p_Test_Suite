// ==============================================================================
// 192p Test Suite - Color Bars with Gray Scale
// (GTIA Mode 10)
// ==============================================================================
cbg_init:
    mva #$00 SDMCTL
    mva #$00 $D01D
    mva #$80 GPRIOR
    mva #$80 $D01B
    mva #$00 $02C0
    mva #$00 $02C8

    lda system_region
    beq _cbg_p
_cbg_n:
    mva #NTSC_75_GRAY $02C1
    mva #NTSC_YELLOW  $02C2
    mva #NTSC_CYAN    $02C3
    mva ref_ntsc_75_grn $02C4
    mva #NTSC_MAGENTA $02C5
    mva ref_ntsc_75_red $02C6
    mva ref_ntsc_75_blu $02C7
    jmp _cbg_c
_cbg_p:
    mva #PAL_75_GRAY  $02C1
    mva #PAL_YELLOW   $02C2
    mva #PAL_CYAN     $02C3
    mva ref_pal_75_grn $02C4
    mva #PAL_MAGENTA  $02C5
    mva ref_pal_75_red $02C6
    mva ref_pal_75_blu $02C7

_cbg_c:
    mwa #cbg_dli VDSLST
    mva #$C0 NMIEN
    mwa #cbg_dlist SDLSTL
    mva #$22 SDMCTL
    rts

cbg_dli:
    pha
    sta WSYNC
    lda #GRAY_02
    sta $D013               ; P0
    lda #GRAY_04
    sta $D014               ; P1
    lda #GRAY_06
    sta $D015               ; P2
    lda #GRAY_08
    sta $D016               ; P3
    lda #GRAY_0A
    sta $D017               ; C0
    lda #GRAY_0C
    sta $D018               ; C1
    lda #GRAY_0E
    sta $D019               ; C2
    pla
    rti

    .align $0400
cbg_dlist:
    .byte $70, $70, $70
    .rept 95
        .byte $4F, <ebu_pat, >ebu_pat
    .endr
    .byte $CF, <ebu_pat, >ebu_pat      ; DLI
    .rept 96
        .byte $4F, <ebu_pat, >ebu_pat
    .endr
    .byte $41, <cbg_dlist, >cbg_dlist