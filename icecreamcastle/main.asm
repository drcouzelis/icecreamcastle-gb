; Ice Cream Castle
; David Couzelis 2021-02-20
; Compile with RGB

; Helpful RGB compiler definitions
INCLUDE "hardware.inc"

; Header
; Memory type: ROM 0
; Game execution begins at address 100
SECTION "Header", ROM0[$100]

EntryPoint:
    di ; Disable interrupts (to avoid needing to deal with them for now)
    jp Start ; Leave this tiny space

; Fill in the extra space
REPT $150 - @
    db 0
ENDR

SECTION "Game code", ROM0

Start:
    ; Turn off the LCD
.waitVBlank
    ld a, [rLY]
    cp 144 ; Check if the LCD is past VBlank
    jr c, .waitVBlank

    xor a ; (ld a, 0) Reset bit 7 to turn off the screen
    ld [rLCDC], a

    ld hl, $9000
    ld de, Resources.background
    ld bc, Resources.endBackground - Resources.background
.copyTiles
    ld a, [de] ; Grab 1 byte from the source
    ld [hli], a ; Place it at the destination, incrementing hl
    inc de ; Move to the next byte
    dec bc ; Decrement count
    ld a, b ; 'dec bc' doesn't update flags, so this line...
    or c ; ...and this line check if bc is 0
    jr nz, .copyTiles

; Load Level 1 background
    ld hl, $9800 ; The top-left corner of the screen
    ld de, Resources.level1
    ld bc, Resources.endLevel1 - Resources.level1
.loadBG
    ld a, [de]
    ld [hli], a
    inc de
    dec bc
    ld a, b
    or c
    jr nz, .loadBG

    ; Init display registers
    ld a, %00011011 ; Palette, first number is text, last number is background
    ld [rBGP], a

    ; Set the X, Y position of the background
    xor a ; (ld a, 0)
    ld [rSCY], a
    ld [rSCX], a

    ; Turn off sound
    xor a ; (ld a, 0)
    ld [rNR52], a

    ; Turn screen on, display the background
    ld a, %10000001
    ld [rLCDC], a

    ; Trap the CPU in an infinite loop
.lockup
    jr .lockup

SECTION "Resources", ROM0

Resources:

; Background tiles
.background
INCBIN "res/tiles-background.2bpp"
.endBackground

; Sprite tiles
.sprites
INCBIN "res/tiles-sprites.2bpp"
.endSprites

; Map, level 1
.level1
INCBIN "res/tilemap-level1.map"
.endLevel1

