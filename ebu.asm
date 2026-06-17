// ==============================================================================
// 192p Test Suite - Color Bars (GTIA Mode 10)
// Exact 10px bars (Gray, Yellow, Cyan, Green, Magenta, Red, Blue).
// ==============================================================================

ebu_init:
    mva #$00 SDMCTL
    mva #$00 $D01D
    mva #$80 GPRIOR
    mva #$80 $D01B

    mva #$00 $02C0          ; PCOLR0 = Black (GTIA bug fix)
    mva #$00 $02C8          ; COLOR4 = Black (Margin)

    lda system_region
    beq _ebu_pal

_ebu_ntsc:
    mva #NTSC_75_GRAY $02C1
    mva #NTSC_YELLOW  $02C2
    mva #NTSC_CYAN    $02C3
    mva ref_ntsc_75_grn $02C4
    mva #NTSC_MAGENTA $02C5
    mva ref_ntsc_75_red $02C6
    mva ref_ntsc_75_blu $02C7
    jmp _ebu_common

_ebu_pal:
    mva #PAL_75_GRAY  $02C1
    mva #PAL_YELLOW   $02C2
    mva #PAL_CYAN     $02C3
    mva ref_pal_75_grn $02C4
    mva #PAL_MAGENTA  $02C5
    mva ref_pal_75_red $02C6
    mva ref_pal_75_blu $02C7

_ebu_common:
    mwa #ebu_dlist SDLSTL
    mva #$22 SDMCTL
    rts

    .align $0400
ebu_dlist:
    .byte $70, $70, $70
    .rept 192
        .byte $4F, <ebu_pat, >ebu_pat
    .endr
    .byte $41, <ebu_dlist, >ebu_dlist

    .align $0400
ebu_pat:
    .byte $00, $00, $11, $11, $11, $11, $11, $22
    .byte $22, $22, $22, $22, $33, $33, $33, $33
    .byte $33, $44, $44, $44, $44, $44, $55, $55
    .byte $55, $55, $55, $66, $66, $66, $66, $66
    .byte $77, $77, $77, $77, $77, $00, $00, $00