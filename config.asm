// ==============================================================================
// 192p Test Suite - Master Configuration and
// Canonical Palette based on Atari Control Picture (RGB Approximations)
// ==============================================================================

// ------------------------------------------------------------------------------
// OS System and Hardware Registers (ANTIC/GTIA/POKEY)
// ------------------------------------------------------------------------------
RTCLOK      = $14       ; System clock (incremented every VBLANK)
SDMCTL      = $022F     ; DMACTL shadow register
SDLSTL      = $0230     ; Display List vector shadow
COLOR0      = $02C4
COLOR1      = $02C5     ; Color 1 shadow (COLPF1)
COLOR2      = $02C6     ; Color 2 shadow (COLPF2)
COLOR3      = $02C7
COLOR4      = $02C8     ; Background color shadow
GPRIOR      = $026F     ; Priority shadow register
CHBAS       = $02F4     ; Character set shadow
CH          = $02FC     ; Internal keyboard code shadow ($FF = empty)
HELPFG      = $02DC     ; OS HELP key flag
VDSLST      = $0200     ; DLI Vector shadow

PAL         = $D014     ; TV standard register (1 = PAL, 15 = NTSC)
CONSOL      = $D01F     ; Console keys register
PORTA       = $D300     ; Joystick ports register
STRIG0      = $0284     ; Joystick 1 fire button shadow
WSYNC       = $D40A     ; Wait for horizontal synchronization
VCOUNT      = $D40B     ; Vertical line counter
NMIEN       = $D40E     ; NMI Enable (DLI/VBI)

// ------------------------------------------------------------------------------
// Hardware Registers for DLI
// ------------------------------------------------------------------------------
COLPF1      = $D017     ; GTIA Color PF1
COLPF2      = $D018     ; GTIA Color PF2
COLBAK      = $D01A     ; GTIA Color Background

// ------------------------------------------------------------------------------
// Program Constants
// ------------------------------------------------------------------------------
SYS_PAL     = 0
SYS_NTSC    = 1
STATE_MENU  = 0
STATE_TEST  = 1
MAX_TESTS   = 14

// ------------------------------------------------------------------------------
// PAL Colors
// ------------------------------------------------------------------------------
PAL_RED     = $22
PAL_GREEN   = $B2
PAL_BLUE    = $72
PAL_WHITE   = $0F
PAL_BLACK   = $00
PAL_75_GRAY = $0B
PAL_YELLOW  = $DA
PAL_CYAN    = $99
PAL_75_GRN  = $C8
PAL_MAGENTA = $45
PAL_75_RED  = $25
PAL_75_BLU  = $73
PAL_75_BLK  = $01
PAL_MINUS_I = $92
PAL_PLUS_Q  = $40
PAL_4_ABOVE = $02

// ------------------------------------------------------------------------------
// NTSC Colors
// ------------------------------------------------------------------------------
NTSC_RED     = $32
NTSC_GREEN   = $C2
NTSC_BLUE    = $82
NTSC_WHITE   = $0F
NTSC_BLACK   = $00
NTSC_75_GRAY = $06
NTSC_YELLOW  = $F9
NTSC_CYAN    = $A9
NTSC_75_GRN  = $D8
NTSC_MAGENTA = $65
NTSC_75_RED  = $44
NTSC_75_BLU  = $72
NTSC_75_BLK  = $01
NTSC_MINUS_I = $71
NTSC_PLUS_Q  = $62
NTSC_4_ABOVE = $02

// ------------------------------------------------------------------------------
// Full Grayscale Range (Hue 0, Luminance 0-15)
// ------------------------------------------------------------------------------
GRAY_00 = $00
GRAY_01 = $01
GRAY_02 = $02
GRAY_03 = $03
GRAY_04 = $04
GRAY_05 = $05
GRAY_06 = $06
GRAY_07 = $07
GRAY_08 = $08
GRAY_09 = $09
GRAY_0A = $0A
GRAY_0B = $0B
GRAY_0C = $0C
GRAY_0D = $0D
GRAY_0E = $0E
GRAY_0F = $0F