// ==============================================================================
// 192p Test Suite - Grid RAM Engine (160x192)
// Uses dynamic screen rendering. 2 Tile Types (Red Outer, White Inner).
// ==============================================================================

grid160_init:
    mva #$00 SDMCTL
    mva #$00 $D01D
    mva #$00 GPRIOR
    mva #$40 NMIEN

    jsr clear_buffer
    
    lda #$0E                ; ANTIC Mode 15 (160x192, 4 colors)
    jsr build_dlist
    
    mwa #tiles_160 zp_tbase       ; Tiles dedicated library from 160_symbols.asm
    mwa #grid160_tile_map zp_src
    jsr render_screen
    
    ; Setup Palette for Mode $0E
    mva #PAL_BLACK COLOR4
    mva #PAL_BLACK COLBAK
    mva #PAL_BLACK COLOR2
    mva #PAL_BLACK COLPF2
    
    mva #PAL_WHITE COLOR1
    mva #PAL_WHITE COLPF1
    
    lda system_region
    beq _pal_red
_ntsc_red:
    lda ref_ntsc_red
    jmp _set_red
_pal_red:
    lda ref_pal_red
_set_red:
    sta COLOR0
    sta $D016               ; Hardware COLPF0
    
    mwa #mono_dlist SDLSTL
    mva #$22 SDMCTL
    rts

// ------------------------------------------------------------------------------
// GRID TILE MAP
// ------------------------------------------------------------------------------
grid160_tile_map:
    ; Row 0 (Top Red Border)
    .rept 20
        .byte $00
    .endr
    
    ; Rows 1-10 (Red on edges, White inside)
    .rept 10
        .byte $00           ; Left Red edge
        .rept 18
            .byte $01       ; Inner White cells
        .endr
        .byte $00           ; Right Red edge
    .endr
    
    ; Row 11 (Bottom Red Border)
    .rept 20
        .byte $00
    .endr