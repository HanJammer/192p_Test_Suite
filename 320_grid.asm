// ==============================================================================
// 192p Test Suite - Grid (320x192)
// (Graphics 8)
// ==============================================================================
grid320_init:
    mva #$00 SDMCTL
    mva #$00 $D01D
    mva #$00 GPRIOR
    mva #$40 NMIEN
    mva #0 $D00D
    mva #0 $D00E
    mva #0 $D00F
    mva #0 $D010
    mva #0 $D011
    
    jsr clear_buffer
    lda #$0F                ; ANTIC Mode 8
    jsr build_dlist

    mwa #tiles_base zp_tbase
    lda #$02                ; Tile ID 02 for Full Grid
    jsr fill_screen
    
    mva #PAL_BLACK COLOR4
    mva #PAL_BLACK COLBAK
    mva #PAL_BLACK COLOR2
    mva #PAL_BLACK COLPF2
    mva #PAL_WHITE COLOR1
    mva #PAL_WHITE COLPF1
    mwa #mono_dlist SDLSTL
    mva #$22 SDMCTL
    rts