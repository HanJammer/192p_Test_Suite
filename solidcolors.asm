// ==============================================================================
// 192p Test Suite - Solid Colors (100% Hardware Fill)
// ==============================================================================

solid_idx:      .byte 0

// ------------------------------------------------------------------------------
// WHITE stays as compile-time constant (not user-configurable). R/G/B slots are
// filled at init from the runtime ref_* RAM vars so picker changes propagate.
// ------------------------------------------------------------------------------
solid_pal:  .byte 0, 0, 0, PAL_WHITE
solid_ntsc: .byte 0, 0, 0, NTSC_WHITE

solid_init:
    mva #$00 SDMCTL         ; Turn off DMA - screen is pure border
    mva #$00 solid_idx      ; Reset to Red
    mwa #solid_dlist SDLSTL ; Keep system happy

    // Populate R/G/B slots from runtime references
    mva ref_pal_red    solid_pal
    mva ref_pal_green  solid_pal+1
    mva ref_pal_blue   solid_pal+2
    mva ref_ntsc_red   solid_ntsc
    mva ref_ntsc_green solid_ntsc+1
    mva ref_ntsc_blue  solid_ntsc+2

    jsr _solid_apply        ; Apply first color
    rts

solid_toggle:
    inc solid_idx
    lda solid_idx
    cmp #4
    bne _solid_apply
    mva #0 solid_idx
_solid_apply:
    ldx solid_idx
    lda system_region
    beq _use_pal
    lda solid_ntsc,x
    jmp _set_bg
_use_pal:
    lda solid_pal,x
_set_bg:
    sta COLOR4
    rts

solid_dlist:
    .byte $70, $70, $70, $41
    .word solid_dlist