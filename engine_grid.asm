// ==============================================================================
// Shared Grid & Tile Rendering Engine (Split-Buffer High RAM)
// ==============================================================================
mono_dlist  = $B000     ; 1KB DL at safe High RAM

zp_dest     = $E0   ; 2 bytes (Screen pointer)
zp_src      = $E2   ; 2 bytes (Map pointer)
zp_tile     = $E4   ; 2 bytes (Tile definition pointer)
zp_t0       = $E6   ; Temp byte
zp_t1       = $E7   ; Temp byte
zp_row      = $EA   ; Row counter (0-11)
zp_line     = $EB   ; Line counter (0-15)
zp_xoff     = $EC   ; X byte offset
zp_tileid   = $EE   ; Tile ID for fill_screen
zp_mode     = $EF   ; ANTIC mode for Display List
zp_tbase    = $F0   ; 2 bytes (Tile Library Base Pointer!)

clear_buffer:
    lda #<$9000             ; Buffer 1 at $9000
    sta zp_dest
    lda #>$9000
    sta zp_dest+1
    ldx #15
    jsr _clr_pages
    lda #<$A000             ; Buffer 2 at $A000
    sta zp_dest
    lda #>$A000
    sta zp_dest+1
    ldx #15
_clr_pages:
    ldy #0
    lda #0
_clr_loop:
    sta (zp_dest),y
    iny
    bne _clr_loop
    inc zp_dest+1
    dex
    bne _clr_loop
    rts

// ------------------------------------------------------------------------------
// IN: A = ANTIC Mode ($0F for Gr.8, $0E for Gr.15)
// ------------------------------------------------------------------------------
build_dlist:
    ora #$40                ; Convert Mode to LMS Instruction
    sta zp_mode
    mwa #mono_dlist zp_dest
    ldy #0
    lda #$70
    jsr _put_dl
    lda #$70
    jsr _put_dl
    lda #$70
    jsr _put_dl

    ; TOP HALF (96 scanlines starting at $9000)
    mwa #$9000 zp_src
    ldx #96
_dl_loop1:
    lda zp_mode
    jsr _put_dl
    lda zp_src
    jsr _put_dl
    lda zp_src+1
    jsr _put_dl
    lda zp_src
    clc
    adc #40
    sta zp_src
    bcc _dls1
    inc zp_src+1
_dls1:
    dex
    bne _dl_loop1

    ; BOTTOM HALF (96 scanlines starting at $A000)
    mwa #$A000 zp_src
    ldx #96
_dl_loop2:
    lda zp_mode
    jsr _put_dl
    lda zp_src
    jsr _put_dl
    lda zp_src+1
    jsr _put_dl
    lda zp_src
    clc
    adc #40
    sta zp_src
    bcc _dls2
    inc zp_src+1
_dls2:
    dex
    bne _dl_loop2
    
    lda #$41
    jsr _put_dl
    lda #<mono_dlist
    jsr _put_dl
    lda #>mono_dlist
    jsr _put_dl
    rts
_put_dl:
    sta (zp_dest),y
    inc zp_dest
    bne _pdb_skip
    inc zp_dest+1
_pdb_skip:
    rts

// ------------------------------------------------------------------------------
// IN: zp_src (Tile Map Pointer), zp_tbase (Tile Library)
// ------------------------------------------------------------------------------
render_screen:
    lda #0
    sta zp_row
_row_loop:
    lda zp_row
    cmp #0
    bne _chk_row6
    lda #<$9000
    sta zp_dest
    lda #>$9000
    sta zp_dest+1
    jmp _line_init
_chk_row6:
    cmp #6
    bne _line_init
    lda #<$A000
    sta zp_dest
    lda #>$A000
    sta zp_dest+1
_line_init:
    lda #0
    sta zp_line
_line_loop:
    ldy #0
    lda #0
    sta zp_xoff
_col_loop:
    lda (zp_src),y
    sta zp_tile
    lda #0
    sta zp_tile+1
    asl zp_tile
    rol zp_tile+1
    asl zp_tile
    rol zp_tile+1
    asl zp_tile
    rol zp_tile+1
    asl zp_tile
    rol zp_tile+1
    asl zp_tile
    rol zp_tile+1
    lda zp_line
    asl
    clc
    adc zp_tile
    sta zp_tile
    bcc _skip1
    inc zp_tile+1
_skip1:
    lda zp_tile
    clc
    adc zp_tbase
    sta zp_tile
    lda zp_tile+1
    adc zp_tbase+1
    sta zp_tile+1
    tya
    pha
    ldy #0
    lda (zp_tile),y
    ldy zp_xoff
    sta (zp_dest),y
    ldy #1
    lda (zp_tile),y
    ldy zp_xoff
    iny
    sta (zp_dest),y
    iny
    sty zp_xoff
    pla
    tay
    iny
    cpy #20
    bne _col_loop
    lda zp_dest
    clc
    adc #40
    sta zp_dest
    bcc _skip2
    inc zp_dest+1
_skip2:
    inc zp_line
    lda zp_line
    cmp #16
    bne _line_loop
    lda zp_src
    clc
    adc #20
    sta zp_src
    bcc _skip3
    inc zp_src+1
_skip3:
    inc zp_row
    lda zp_row
    cmp #12
    beq _render_done
    jmp _row_loop
_render_done:
    rts

// ------------------------------------------------------------------------------
// IN: A = Tile ID, zp_tbase = Tile Library
// ------------------------------------------------------------------------------
fill_screen:
    sta zp_tileid
    lda #0
    sta zp_row
_fs_row:
    lda zp_row
    cmp #0
    bne _fschk_row6
    lda #<$9000
    sta zp_dest
    lda #>$9000
    sta zp_dest+1
    jmp _fs_line_init
_fschk_row6:
    cmp #6
    bne _fs_line_init
    lda #<$A000
    sta zp_dest
    lda #>$A000
    sta zp_dest+1
_fs_line_init:
    lda #0
    sta zp_line
_fs_line:
    lda zp_tileid
    sta zp_tile
    lda #0
    sta zp_tile+1
    asl zp_tile
    rol zp_tile+1
    asl zp_tile
    rol zp_tile+1
    asl zp_tile
    rol zp_tile+1
    asl zp_tile
    rol zp_tile+1
    asl zp_tile
    rol zp_tile+1
    lda zp_line
    asl
    clc
    adc zp_tile
    sta zp_tile
    bcc _fskip1
    inc zp_tile+1
_fskip1:
    lda zp_tile
    clc
    adc zp_tbase
    sta zp_tile
    lda zp_tile+1
    adc zp_tbase+1
    sta zp_tile+1
    ldy #0
    lda (zp_tile),y
    sta zp_t0
    iny
    lda (zp_tile),y
    sta zp_t1
    ldy #0
_fs_col:
    lda zp_t0
    sta (zp_dest),y
    iny
    lda zp_t1
    sta (zp_dest),y
    iny
    cpy #40
    bne _fs_col
    lda zp_dest
    clc
    adc #40
    sta zp_dest
    bcc _fskip2
    inc zp_dest+1
_fskip2:
    inc zp_line
    lda zp_line
    cmp #16
    bne _fs_line
    inc zp_row
    lda zp_row
    cmp #12
    beq _fs_done
    jmp _fs_row
_fs_done:
    rts