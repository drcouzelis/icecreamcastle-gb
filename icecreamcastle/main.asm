; Ice Cream Castle
; David Couzelis 2021-02-20
; Compile with RGB

; Helpful RGB compiler definitions
INCLUDE "hardware.inc"

; Game constants
HERO_START_X EQU 48
HERO_START_Y EQU 136
;HERO_DX_RESET EQU 4 ; Used to move the hero at the correct speed

; Interrupts
SECTION "VBlank interrupt", ROM0[$0040] ; Called 60 FPS
    push hl            ; Save HL
    ld hl, wVBlankFlag
    ld [hl], 1         ; Set a flag, it's time to update the game!
    pop hl             ; Restore HL
    reti               ; Return and enable interrupts

; Header
; Memory type: ROM 0
; Game execution begins at address 100
SECTION "Header", ROM0[$0100]

EntryPoint:
    nop
    jp Start ; Jump to the start of the game code

; Fill in the extra space, to be filled in with RGBFIX
REPT $150 - @
    db 0
ENDR

SECTION "Game code", ROM0[$0150]

Start:
    di ; Disable interrupts during setup
    call WaitForVBlank

    xor a
    ld [rLCDC], a ; Reset bit 7 to turn off the screen
    ld [wVBlankFlag], a ; Clear the VBlank flag

    call ClearOAM

    ; Set the X, Y position of the background
    xor a
    ld [rSCY], a
    ld [rSCX], a

; Load background tiles
    ld hl, $9000
    ld de, Resources.background
    ld bc, Resources.endBackground - Resources.background
.loadBackgroundTiles
    ld a, [de] ; Grab 1 byte from the source
    ld [hli], a ; Place it at the destination, incrementing hl
    inc de ; Move to the next byte
    dec bc ; Decrement count
    ld a, b ; 'dec bc' doesn't update flags, so this line...
    or c ; ...and this line check if bc is 0
    jr nz, .loadBackgroundTiles

; Load background
    ld hl, $9800 ; The top-left corner of the screen
    ld de, Resources.level1
    ld bc, Resources.endLevel1 - Resources.level1
.loadBackground
    ld a, [de]
    ld [hli], a
    inc de
    dec bc
    ld a, b
    or c
    jr nz, .loadBackground

; Load sprite tiles
    ld hl, $8000
    ld de, Resources.sprites
    ld bc, Resources.endSprites - Resources.sprites
.loadSpriteTiles
    ld a, [de]
    ld [hli], a
    inc de
    dec bc
    ld a, b
    or c
    jr nz, .loadSpriteTiles

; Load sprites
    ; The hero
    ; Set X Position
    ld hl, wHeroX
    ld [hl], HERO_START_X
    ld a, [wHeroX]
    ld [_OAMRAM + OAMA_X], a
    ; Set Y Position
    ld hl, wHeroY
    ld [hl], HERO_START_Y
    ld a, [wHeroY]
    ld [_OAMRAM + OAMA_Y], a
    ; Set the sprite tile number
    xor a
    ld [_OAMRAM + OAMA_TILEID], a
    ; Set attributes
    ld [_OAMRAM + OAMA_FLAGS], a

    ; Init palettes
    ld a, %00011011 ; Palette, first number is text, last number is background
    ld [rBGP], a
    ld [rOBP0], a

    ; Turn off sound
    xor a
    ld [rNR52], a

    ; Turn screen on, display the background
    ld a, LCDCF_ON | LCDCF_OBJON | LCDCF_BGON
    ld [rLCDC], a

    ; Reset the hero movement
    ;ld hl, wHeroDX
    ;ld [hl], HERO_DX_RESET

    ld a, IEF_VBLANK
    ld [rIE], a
    ei ; Enable interrupts

GameLoop:
    halt ; Wait for VBlank interrupt...
    nop

    ld a, [wVBlankFlag]
    and a
    jr z, GameLoop ; Continue waiting if the VBlank flag hasn't been set...

    ; Time to update the game!
    xor a
    ld [wVBlankFlag], a

    call ReadKeys ; Returns Reg B

    ; Character control
.isPressedKeyRight
    ld a, b
    and PADF_RIGHT
    jr nz, .isPressedKeyLeft ; Right is not pressed, try left...
    ; Move the hero to the right!
    xor a
    ld [_OAMRAM + OAMA_FLAGS], a ; Face right

    ;ld hl, wHeroDX
    ;dec [hl]
    ;ld a, 1
    ;cp [hl] ; wHeroDX == 1?
    ;jr z, .isPressedKeyLeft
    ;xor a
    ;cp [hl] ; wHeroDX == 0?
    ;jr nz, .moveRight
    ;ld [hl], HERO_DX_RESET ; Reset the DX counter
    ;jr .isPressedKeyLeft
;.moveRight
    ld hl, wHeroX
    inc [hl] ; Move the hero right
    
.isPressedKeyLeft
    ld a, b
    and PADF_LEFT
    jr nz, .inputDone
    ; Move the hero to the left!
    ld a, OAMF_XFLIP
    ld [_OAMRAM + OAMA_FLAGS], a ; Face left
    ;ld hl, HERO_DX
    ;dec [hl]
    ;jr nz, .inputDone
    ;ld [hl], HERO_SPEED ; Reset the DX counter
    ld hl, wHeroX
    dec [hl] ; Move the hero left

.inputDone
    ; Update hero position
    ; Set X Position
    ld a, [wHeroX]
    ld [$FE01], a
    ; Set Y Position
    ld a, [wHeroY]
    ld [$FE00], a

    ; Done!
    jr GameLoop

; Procedure: WaitForVBlank
WaitForVBlank:
    ld a, [rLY]
    cp 144 ; Check if the LCD is past VBlank
    jr nz, WaitForVBlank
    ret

; Procedure: ClearOAM
; OAM memory is filled with garbage at startup
; Destroys Reg C
ClearOAM:
    ld hl, _OAMRAM
    ld c, OAM_COUNT * sizeof_OAM_ATTRS ; 40 sprites, 4 bytes each
    xor a
.loop
    ld [hli], a
    dec c
    jr nz, .loop

; Procedure: ReadKeys
; OUT: Reg B - The key inputs, 0 means pressed
; NOTES: 
;   Use "and PADF_KEYNAME", if Z is set then the key is pressed
ReadKeys:

    ; Read buttons (Start, Select, B, A)
    ld a, P1F_GET_BTN
    ld [rP1], a
REPT 6            ; Read a few times, to ensure button presses are received
    ld a, [rP1]   ; Read the input, 0 means "pressed"
ENDR
    or %11110000
    ld b, a       ; Store the first half of the buttons in B

    ; Read D-pad (Down, Up, Left, Right)
    ld a, P1F_GET_DPAD
    ld [rP1], a
REPT 6
    ld a, [rP1]
ENDR
    or %11110000

    ; Combine D-pad with buttons, store in B
    swap a
    and b
    ld b, a ; The return value is now stored in Reg B

    ; Clear the retrieval of button presses
    ld a, P1F_GET_NONE
    ld [rP1], a

    ret

SECTION "Game State Variables", WRAM0

wVBlankFlag: db ; When set, update the game

; Hero position
wHeroX: db
wHeroY: db

; Used to move the hero at the correct speed
;wHeroDX: db

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

