// ==============================================================================
// 192p Test Suite - Grid Symbols (160x192)
// Tiles (Graphics 15)
// ==============================================================================
    .align $0100
tiles_160:

// ------------------------------------------------------------------------------
// Tile 00: Outer Red Cell with Center Red Dot
// ------------------------------------------------------------------------------
    .byte $55, $55          ; Top border (Solid Red)
    .rept 6
        .byte $40, $01      ; Left & Right borders (Red)
    .endr
    .byte $41, $41          ; Left/Right + Center Dot (Row 1)
    .byte $41, $41          ; Left/Right + Center Dot (Row 2)
    .rept 6
        .byte $40, $01      ; Left & Right borders (Red)
    .endr
    .byte $55, $55          ; Bottom border (Solid Red)

// ------------------------------------------------------------------------------
// Tile 01: Inner White Cell with Center White Dot
// ------------------------------------------------------------------------------
    .byte $AA, $AA          ; Top border (Solid White)
    .rept 6
        .byte $80, $02      ; Left & Right borders (White)
    .endr
    .byte $82, $82          ; Left/Right + Center Dot (Row 1)
    .byte $82, $82          ; Left/Right + Center Dot (Row 2)
    .rept 6
        .byte $80, $02      ; Left & Right borders (White)
    .endr
    .byte $AA, $AA          ; Bottom border (Solid White)