; --  
; -- Ice Cream Castle
; -- David Couzelis 2021-02-20
; -- 

INCLUDE "hardware.inc" ; Common definitions

; --
; -- Game Constants
; --
HERO_OAM_TILEID EQU _OAMRAM+OAMA_TILEID
HERO_OAM_X      EQU _OAMRAM+OAMA_X
HERO_OAM_Y      EQU _OAMRAM+OAMA_Y
HERO_OAM_FLAGS  EQU _OAMRAM+OAMA_FLAGS
;HERO_DX_RESET EQU 4 ; Used to move the hero at the correct speed
HERO_START_X EQU 48
HERO_START_Y EQU 136

; --
; -- VBlank Interrupt
; --
; -- Called approximately 60 times per second
; -- Used to time the main game loop
; -- Sets a flag notifying that it's time to update the game logic
; --
; -- @return wVBlankFlag 1
; --
SECTION "VBlank Interrupt", ROM0[$0040]
    push hl
    ld hl, wVBlankFlag
    ld [hl], 1
    pop hl
    reti

; --
; -- Header
; --
; -- Memory type ROM0 for a 32K ROM
; -- https://gbdev.io/pandocs/#the-cartridge-header
; -- The rest is automatically filled in by rgbfix
; --
SECTION "Header", ROM0[$0100]

EntryPoint:
    nop
    jp Start

REPT $150 - @
    db 0
ENDR

; --
; -- Game Code
; --
SECTION "Game Code", ROM0[$0150]

Start:
    di ; Disable interrupts during setup
    call WaitForVBlank

    xor a ; a = 0
    ld [rLCDC], a       ; Turn off the screen
    ld [wVBlankFlag], a ; Clear the VBlank flag
    ld [rSCY], a        ; Set the X, Y position of the background to 0
    ld [rSCX], a
    ld [rNR52], a       ; Turn off sound

    call ClearOAM

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
    ld a, HERO_START_X
    ld [HERO_OAM_X], a
    ; Set Y Position
    ld a, HERO_START_Y
    ld [HERO_OAM_Y], a
    ; Set the sprite tile number
    xor a
    ld [HERO_OAM_TILEID], a
    ; Set attributes
    ld [HERO_OAM_FLAGS], a

    ; Init palettes
    ld a, %00011011
    ld [rBGP], a
    ld [rOBP0], a

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
    ld hl, wVBlankFlag
    xor a ; a = 0
.wait
    halt                ; Wait for the VBlank interrupt
    ;nop ; nop is automatically inserted after halt by rgbasm
    cp a, [hl]
    jr z, .wait         ; Wait for the VBlank flag to be set
    ld [wVBlankFlag], a ; Done waiting! Clear the VBlank flag

    ; Time to update the game!
    call ReadKeys

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
    ld hl, HERO_OAM_X
    inc [hl] ; Move the hero right
    
.isPressedKeyLeft
    ld a, b
    and PADF_LEFT
    jr nz, .inputDone
    ; Move the hero to the left!
    ld a, OAMF_XFLIP
    ld [_OAMRAM + OAMA_FLAGS], a ; Face left
    ld hl, HERO_OAM_X
    dec [hl] ; Move the hero left

.inputDone
    jr GameLoop

; --
; -- WaitForVBlank
; --
; -- @returns a Undefined
; --
WaitForVBlank:
    ld a, [rLY]
    cp 144 ; Check if the LCD is past VBlank
    jr nz, WaitForVBlank
    ret

; --
; -- ClearOAM
; --
; -- Set all values in OAM to 0
; -- Because OAM is filled with garbage at startup
; --
; -- @return a 0
; --
ClearOAM:
    push bc
    push hl
    ld hl, _OAMRAM
    ld c, OAM_COUNT * sizeof_OAM_ATTRS ; 40 sprites, 4 bytes each
    xor a ; a = 0
.loop
    ld [hli], a
    dec c
    jr nz, .loop
    pop hl
    pop bc
    ret

; --
; -- ReadKeys
; --
; -- Get the current state of button presses
; -- (Down, Up, Left, Right, Start, Select, B, A)
; -- Use "and PADF_<KEYNAME>", if Z is set then the key is pressed
; --
; -- @return a Undefined
; -- @return b The 8 inputs, 0 means pressed
; --
ReadKeys:
    ; Read D-pad (Down, Up, Left, Right)
    ld a, P1F_GET_DPAD
    ld [rP1], a
REPT 6
    ld a, [rP1]
ENDR
    or %11110000
    swap a
    ld b, a ; Store the result in upper-b
    ; Read buttons (Start, Select, B, A)
    ld a, P1F_GET_BTN
    ld [rP1], a
REPT 6            ; Read a few times, to ensure button presses are received
    ld a, [rP1]   ; Read the input, 0 means "pressed"
ENDR
    or %11110000
    ; Combine and load the result in b
    and b
    ld b, a
    ; Clear the retrieval of button presses
    ld a, P1F_GET_NONE
    ld [rP1], a
    ret

SECTION "Game State Variables", WRAM0

wVBlankFlag: db ; If not zero then update the game
;wHeroDX: db ; To move the hero at the correct speed

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

