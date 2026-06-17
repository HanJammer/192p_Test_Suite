// ==============================================================================
// 192p Test Suite by HanJammer - Display Test Suite for 8-bit Atari
// Compiler: MADS
// ==============================================================================

    icl 'config.asm'

// ------------------------------------------------------------------------------
// Program Memory
// ------------------------------------------------------------------------------
    org $2000

start:
    mva #$00 SDMCTL     ; Disable DMA during setup
    mva #$00 COLOR4     ; Set black background

    // PAL / NTSC system detection
    lda PAL
    cmp #$01
    beq _is_pal
_is_ntsc:
    mva #SYS_NTSC system_region
    jmp _init_done
_is_pal:
    mva #SYS_PAL system_region

_init_done:
    jsr ref_init        ; Seed runtime reference R/G/B vars from config.asm defaults
    jsr gtia2rgb_detect ; Probe for the Lotharek/Gowin FPGA companion chip

    // SELECT-cycle wrap point: two extra tests (80-col text + 80-col color) when the FPGA is present, the stock count otherwise.
    lda #MAX_TESTS
    ldx gtia2rgb_present
    beq _tc_set
    lda #MAX_TESTS+2
_tc_set:
    sta test_count

    mva #STATE_MENU current_state
    mva #0 current_test
    jsr menu_init
    mva #$FF CH         ; Clear keyboard buffer

// ------------------------------------------------------------------------------
// MAIN PROGRAM LOOP (State Machine)
// ------------------------------------------------------------------------------
main_loop:
    lda RTCLOK
wait_vbl:
    cmp RTCLOK
    beq wait_vbl

    lda input_delay
    beq _dispatch_state
    dec input_delay

_dispatch_state:
    lda current_state
    cmp #STATE_MENU
    beq state_handle_menu
    jmp state_handle_test

// ------------------------------------------------------------------------------
// MENU STATE
// ------------------------------------------------------------------------------
state_handle_menu:
    lda CH
    cmp #$FF
    bne _check_menu_keys
    jmp _menu_done

_check_menu_keys:
    // Map OS keycodes to tests
    cmp #$1F
    beq _key_1
    cmp #$1E
    beq _key_2
    cmp #$1A
    beq _key_3
    cmp #$18
    beq _key_4
    cmp #$1D
    beq _key_5
    cmp #$1B
    beq _key_6
    cmp #$33
    beq _key_7
    cmp #$35
    beq _key_8
    cmp #$30
    beq _key_9
    cmp #$32
    beq _key_0
    cmp #$3F
    beq _key_A
    cmp #$15
    beq _key_B
    cmp #$12
    beq _key_C
    cmp #$3A
    beq _key_D
    cmp #$2A
    beq _key_E
    cmp #$38
    beq _key_F
    jmp _menu_done_clear

_key_1:
    ldx #0
    jmp _run_from_menu
_key_2:
    ldx #1
    jmp _run_from_menu
_key_3:
    ldx #2
    jmp _run_from_menu
_key_4:
    ldx #3
    jmp _run_from_menu
_key_5:
    ldx #4
    jmp _run_from_menu
_key_6:
    ldx #5
    jmp _run_from_menu
_key_7:
    ldx #6
    jmp _run_from_menu
_key_8:
    ldx #7
    jmp _run_from_menu
_key_9:
    ldx #8
    jmp _run_from_menu
_key_0:
    ldx #9
    jmp _run_from_menu
_key_A:
    ldx #10
    jmp _run_from_menu
_key_B:
    ldx #11
    jmp _run_from_menu
_key_C:
    ldx #12
    jmp _run_from_menu
_key_D:
    ldx #13
    jmp _run_from_menu
_key_E:
    lda gtia2rgb_present        ; 80-col test exists only on GTIA2RGB hardware
    beq _menu_done_clear
    ldx #14
    jmp _run_from_menu
_key_F:
    lda gtia2rgb_present        ; 80-col color test - GTIA2RGB only
    beq _menu_done_clear
    ldx #15
    jmp _run_from_menu

_run_from_menu:
    stx current_test
    jsr run_selected_test
_menu_done_clear:
    mva #$FF CH         ; Clear keyboard buffer
_menu_done:
    jmp main_loop

// ------------------------------------------------------------------------------
// TEST STATE
// ------------------------------------------------------------------------------
state_handle_test:
    lda CONSOL
    and #%00000100      ; Check OPTION
    bne _ot_skip        ; Branch over the long jump if OPTION not pressed
    jmp _return_to_menu
_ot_skip:

    lda HELPFG
    cmp #$11
    bne _check_debounce
    mva #$00 HELPFG
    jmp _return_to_menu

_check_debounce:
    lda input_delay
    beq _read_inputs
    jmp _test_done

_read_inputs:
    // Check SELECT (Cycles to next test)
    lda CONSOL
    and #%00000010
    beq _do_select

    // Check ACTION (SPACEBAR or FIRE Button)
    lda STRIG0
    beq _do_action
    lda CH
    cmp #$21
    beq _do_action

    // Per-test idle-frame poll (joystick / extra keys). Currently used by palette256 (test 9) for the reference R/G/B picker.
    lda current_test
    cmp #9
    bne _test_done
    jsr palette_poll
    jmp _test_done

_do_select:
    inc current_test
    lda current_test
    cmp test_count              ; Dynamic: includes 80-col test on GTIA2RGB
    bne _do_cycle
    mva #0 current_test
_do_cycle:
    mva #20 input_delay
    jsr run_selected_test
    jmp main_loop

_do_action:
    mva #$FF CH             ; Consume Spacebar
    mva #15 input_delay     ; Debounce action

    // Dispatch Action to the correct Module!
    lda current_test
    cmp #10                 ; Index 10 = Solid Colors
    beq _act_solid
    cmp #11                 ; Index 11 = Convergence Dots
    beq _act_conv
    cmp #12                 ; Index 12 = Convergence RGB Fields
    beq _act_convf
    cmp #13                 ; Index 13 = Readme (Readability Test)
    beq _act_readme
    cmp #14                 ; Index 14 = GTIA2RGB 80-Column Text
    beq _act_text80
    cmp #15                 ; Index 15 = GTIA2RGB 80-Column Color
    beq _act_text80color
    jmp _test_done

_act_solid:
    jsr solid_toggle
    jmp _test_done
_act_conv:
    jsr convdots_toggle
    jmp _test_done
_act_convf:
    jsr convfields_toggle
    jmp _test_done
_act_readme:
    jsr readme_toggle
    jmp _test_done
_act_text80:
    jsr text80_toggle
    jmp _test_done
_act_text80color:
    jsr text80color_toggle
    jmp _test_done

_return_to_menu:
    mva #STATE_MENU current_state
    jsr menu_init
    mva #20 input_delay
    mva #$FF CH

_test_done:
    jmp main_loop

// ------------------------------------------------------------------------------
// TEST DISPATCHER
// ------------------------------------------------------------------------------
run_selected_test:
    mva #STATE_TEST current_state
    lda current_test
    cmp #0
    beq _run_pluge
    cmp #1
    beq _run_smpte
    cmp #2
    beq _run_ebu
    cmp #3
    beq _run_cbg
    cmp #4
    beq _run_monoscope
    cmp #5
    beq _run_grid160
    cmp #6
    beq _run_grid320
    cmp #7
    beq _run_grayramp
    cmp #8
    beq _run_rgbramp
    cmp #9
    beq _run_pal256
    cmp #10
    beq _run_solid
    cmp #11
    beq _run_convdots
    cmp #12
    beq _run_convrgb
    cmp #13
    beq _run_readme
    cmp #14
    beq _run_text80
    cmp #15
    beq _run_text80color

    // Default: Blank screen
    mwa #blank_dlist SDLSTL
    rts

_run_pluge:
    jsr pluge_init
    rts
_run_smpte:
    jsr smpte_init
    rts
_run_ebu:
    jsr ebu_init
    rts
_run_cbg:
    jsr cbg_init
    rts
_run_monoscope:
    jsr monoscope_init
    rts
_run_grid160:
    jsr grid160_init
    rts
_run_grid320:
    jsr grid320_init
    rts
_run_grayramp:
    jsr grayramp_init
    rts
_run_rgbramp:
    jsr rgbramp_init
    rts
_run_pal256:
    jsr palette_init
    rts
_run_solid:
    jsr solid_init
    rts
_run_convdots:
    jsr convdots_init
    rts
_run_convrgb:
    jsr convfields_init
    rts
_run_readme:
    jsr readme_init
    rts
_run_text80:
    jsr text80_init
    rts
_run_text80color:
    jsr text80color_init
    rts

// ------------------------------------------------------------------------------
// DATA AND VARIABLES
// ------------------------------------------------------------------------------
system_region:  .byte 0     ; 0 = PAL, 1 = NTSC
current_state:  .byte 0     ; 0 = Menu, 1 = Test Pattern
current_test:   .byte 0     ; ID of current test
input_delay:    .byte 0     ; Debounce timer
test_count:     .byte 0     ; SELECT wrap point (MAX_TESTS, +1 on GTIA2RGB)

// GTIA2RGB FPGA companion (Lotharek/Gowin). Detected once at boot. Stays  false on stock GTIA (and on Altirra, which doesn't emulate the FPGA), so all extra UI/features stay hidden by default.
gtia2rgb_present: .byte 0
gtia2rgb_major:   .byte 0   ; firmware major version as decimal digit (0-9)
gtia2rgb_minor:   .byte 0   ; firmware minor version as decimal digit (0-9)

// Runtime reference R/G/B (seeded from config.asm defaults in ref_init). Consumed by tests 2, 3, 6, 9, A, C and palette256 instead of compile-time constants. Picker UI in palette256 (Phase B) writes these.
ref_pal_red:     .byte 0
ref_pal_green:   .byte 0
ref_pal_blue:    .byte 0
ref_ntsc_red:    .byte 0
ref_ntsc_green:  .byte 0
ref_ntsc_blue:   .byte 0
// 75% variants for SMPTE/EBU bars. Derived from pure refs via constant byte delta (PAL_75_RED - PAL_RED etc.); re-seeded at boot, recomputed by picker.
ref_pal_75_red:  .byte 0
ref_pal_75_grn:  .byte 0
ref_pal_75_blu:  .byte 0
ref_ntsc_75_red: .byte 0
ref_ntsc_75_grn: .byte 0
ref_ntsc_75_blu: .byte 0

ref_init:
    mva #PAL_RED       ref_pal_red
    mva #PAL_GREEN     ref_pal_green
    mva #PAL_BLUE      ref_pal_blue
    mva #NTSC_RED      ref_ntsc_red
    mva #NTSC_GREEN    ref_ntsc_green
    mva #NTSC_BLUE     ref_ntsc_blue
    mva #PAL_75_RED    ref_pal_75_red
    mva #PAL_75_GRN    ref_pal_75_grn
    mva #PAL_75_BLU    ref_pal_75_blu
    mva #NTSC_75_RED   ref_ntsc_75_red
    mva #NTSC_75_GRN   ref_ntsc_75_grn
    mva #NTSC_75_BLU   ref_ntsc_75_blu
    rts

// Re-derive 75% reference R/G/B from pure refs. Deltas are compile-time constants - the relationship "75% variant - pure" is fixed and propagates the picker's choice into SMPTE/EBU/cbg bars.
recompute_75:
    lda ref_pal_red
    clc
    adc #(PAL_75_RED - PAL_RED)
    sta ref_pal_75_red
    lda ref_pal_green
    clc
    adc #(PAL_75_GRN - PAL_GREEN)
    sta ref_pal_75_grn
    lda ref_pal_blue
    clc
    adc #(PAL_75_BLU - PAL_BLUE)
    sta ref_pal_75_blu
    lda ref_ntsc_red
    clc
    adc #(NTSC_75_RED - NTSC_RED)
    sta ref_ntsc_75_red
    lda ref_ntsc_green
    clc
    adc #(NTSC_75_GRN - NTSC_GREEN)
    sta ref_ntsc_75_grn
    lda ref_ntsc_blue
    clc
    adc #(NTSC_75_BLU - NTSC_BLUE)
    sta ref_ntsc_75_blu
    rts

// ------------------------------------------------------------------------------
// Detect the GTIA2RGB FPGA companion. Per the May 2026 Draft hardware manual
// (Appendix A.2), $D01E read returns $0A on the FPGA and $0F on a stock GTIA.
// When present, $D01C and $D01D also expose firmware major/minor as decimal
// digits. Must run BEFORE anything writes to $D01D (write to $D01D configures
// the COL80 overlay on the FPGA and clobbers PMCTL on stock GTIA).
// ------------------------------------------------------------------------------
gtia2rgb_detect:
    lda $D01E
    cmp #$0A
    beq _g2r_yes
    mva #0 gtia2rgb_present
    rts
_g2r_yes:
    mva #1 gtia2rgb_present
    mva $D01C gtia2rgb_major
    mva $D01D gtia2rgb_minor
    rts

blank_dlist:
    .byte $70, $70, $70, $41
    .word blank_dlist

// ------------------------------------------------------------------------------
// INCLUDED MODULES
// ------------------------------------------------------------------------------
    icl 'engine_grid.asm'   ; Has to be before rest of the screens - contains rendering engine!
    icl '320_symbols.asm'   ; Contains tiles_base library
    icl '160_symbols.asm'
    icl 'screen_data.asm'   ; Contains mono_tile_map
    icl 'menu.asm'
    icl 'pluge.asm'
    icl 'smpte.asm'
    icl 'ebu.asm'
    icl 'cbg.asm'
    icl '320_monoscope.asm'
    icl '160_grid.asm'
    icl '320_grid.asm'
    icl 'grayramp.asm'
    icl 'rgbramp.asm'
    icl 'palette256.asm'
    icl 'solidcolors.asm'
    icl '320_convdots.asm'
    icl '160_convfields.asm'
    icl 'readme.asm'
    icl 'text80.asm'
    icl 'text80color.asm'

    run start