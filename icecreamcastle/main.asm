; --  
; -- Ice Cream Castle
; -- David Couzelis 2021-02-20
; -- 

INCLUDE "hardware.inc" ; Common definitions

; --
; -- Game Constants
; --
HERO_OAM        EQU 1
HERO_OAM_TILEID EQU (HERO_OAM*_OAMRAM)+OAMA_TILEID
HERO_OAM_X      EQU (HERO_OAM*_OAMRAM)+OAMA_X
HERO_OAM_Y      EQU (HERO_OAM*_OAMRAM)+OAMA_Y
HERO_OAM_FLAGS  EQU (HERO_OAM*_OAMRAM)+OAMA_FLAGS

HERO_DX_RESET EQU 4 ; Used to move the hero at the correct speed
HERO_START_X  EQU 48
HERO_START_Y  EQU 136
ANIM_SPEED    EQU 10 ; Frames until animation time

TILE_BRICK  EQU 0
TILE_SPIKES EQU 5

; Directions
DIR_U EQU %00000001
DIR_D EQU %00000010
DIR_L EQU %00000100
DIR_R EQU %00001000

load_current_level_to_hl: MACRO
    ld a, [wCurrLevel]
    ld l, a
    ld a, [wCurrLevel + 1]
    ld h, a
    ENDM

set_current_level1: MACRO
    ld hl, wCurrLevel
    ld [hl], LOW(Resources.level1)
    inc hl
    ld [hl], HIGH(Resources.level1)
    ENDM

; --
; -- VBlank Interrupt
; --
; -- Called approximately 60 times per second
; -- Used to time the main game loop
; -- Sets a flag notifying that it's time to update the game logic
; --
; -- @side wVBlankFlag = 1
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
    ld [wVBlankFlag], a ; VBlankFlag = 0
    ld [rSCX], a        ; Set the X...
    ld [rSCY], a        ; ...and Y position of the background to 0
    ld [rNR52], a       ; Turn off sound

    call ClearOAM

    ; Load background tiles
    ld hl, $9000
    ld de, Resources.background
    ld bc, Resources.endBackground - Resources.background
    call CopyMem

    ; Load background
    ld hl, $9800 ; The top-left corner of the screen
    ld de, Resources.level1
    ld bc, Resources.endLevel1 - Resources.level1
    call CopyMem

    ; Load sprite tiles
    ld hl, $8000
    ld de, Resources.sprites
    ld bc, Resources.endSprites - Resources.sprites
    call CopyMem

    ; Load sprites
    ; The hero
    ; Set X Position
    ld a, HERO_START_X
    ld [wHeroX], a
    ; Set Y Position
    ld a, HERO_START_Y
    ld [wHeroY], a
    ; Set the sprite tile number
    xor a ; a = 0
    ld [HERO_OAM_TILEID], a
    ; Set attributes
    ld [HERO_OAM_FLAGS], a
    ; Init speed
    ld hl, wHeroDX
    ld [hl], HERO_DX_RESET ; Reset the DX counter
    ; Init animation
    ld a, ANIM_SPEED
    ld [wAnimCounter], a

    ; Init palettes
    ld a, %00011011
    ld [rBGP], a
    ld [rOBP0], a

    ; Set level 1 as the current level
    set_current_level1

    ; Turn screen on, display the background
    ld a, LCDCF_ON | LCDCF_OBJON | LCDCF_BGON
    ld [rLCDC], a

    ld a, IEF_VBLANK
    ld [rIE], a
    ei ; Enable interrupts

    ; ...setup complete!

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

    ; Complete all OAM changes first, befor VBlank ends!

    ; Update the screen
    ld a, [wHeroX]
    ld [HERO_OAM_X], a
    ld a, [wHeroY]
    ld [HERO_OAM_Y], a

    ;call Animate
    ld hl, wAnimCounter
    dec [hl]
    jr nz, .readKeys
    ; Animate!
    ld [hl], ANIM_SPEED      ; Reset the animation counter
    ld a, [HERO_OAM_TILEID]
    xor a, $01               ; Toggle the animation frame
    ld [HERO_OAM_TILEID], a

.readKeys
    call ReadKeys
    call UpdateHero

    jr GameLoop

    ; End of the main game loop

; --
; -- UpdateHero
; --
; -- Move the hero based on key input and gravity
; --
; -- @return z Set if collision
; -- @side a Modified
; --
UpdateHero:
    ; RIGHT
    ld a, [wKeys]
    and PADF_RIGHT
    jr nz, .endMoveRight ; Right is not pressed, try left...
    ; Move the hero to the right!
    xor a ; a = 0
    ld [HERO_OAM_FLAGS], a ; Face right ; TODO Move up!
    ; Move 0.75 pixels per frame, or, skip movement every 4th frame
    ld hl, wHeroDX
    dec [hl]
    jr nz, .moveRight
    ld [hl], HERO_DX_RESET ; wHeroDX == 0, reset the DX counter
    jr .endMoveRight
.moveRight
    ; Collision check
    ld a, [wHeroX]
    inc a                   ; Test one pixel right
    ld b, a
    ld a, [wHeroY]
    ld c, a
    ld a, DIR_R
    ld [wHeroDir], a
    call TestSpriteCollision
    jr z, .endMoveRight ; Collision! Skip movement
    ; Collision check end
    ld hl, wHeroX
    inc [hl] ; Move the hero right
.endMoveRight
    
    ; LEFT
    ld a, [wKeys]
    and PADF_LEFT
    jr nz, .endMoveLeft
    ; Move the hero to the left!
    ld a, OAMF_XFLIP
    ld [HERO_OAM_FLAGS], a ; Face left ; TODO Move up!
    ; Move 0.75 pixels per frame, or, skip movement every 4th frame
    ld hl, wHeroDX
    dec [hl]
    jr nz, .moveLeft
    ld [hl], HERO_DX_RESET ; wHeroDX == 0, reset the DX counter
    jr .endMoveLeft
.moveLeft
    ; Collision check
    ld a, [wHeroX]
    dec a                   ; Test one pixel left
    ld b, a
    ld a, [wHeroY]
    ld c, a
    ld a, DIR_L
    ld [wHeroDir], a
    call TestSpriteCollision
    jr z, .endMoveLeft ; Collision! Skip movement
    ; Collision check end
    ld hl, wHeroX
    dec [hl] ; Move the hero left
.endMoveLeft

    ; UP
    ld a, [wKeys]
    and PADF_UP
    jr nz, .endMoveUp
    ; Collision check
    ld a, [wHeroX]
    ld b, a
    ld a, [wHeroY]
    dec a                   ; Test one pixel up
    ld c, a
    ld a, DIR_U
    ld [wHeroDir], a
    call TestSpriteCollision
    jr z, .endMoveUp ; Collision! Skip movement
    ; Collision check end
    ld hl, wHeroY
    dec [hl]
.endMoveUp
    
    ; DOWN
    ld a, [wKeys]
    and PADF_DOWN
    jr nz, .endMoveDown
    ; Collision check
    ld a, [wHeroX]
    ld b, a
    ld a, [wHeroY]
    inc a                   ; Test one pixel down
    ld c, a
    ld a, DIR_D
    ld [wHeroDir], a
    call TestSpriteCollision
    jr z, .endMoveDown ; Collision! Skip movement
    ; Collision check end
    ld hl, wHeroY
    inc [hl]
.endMoveDown
    
    ; Done updating hero
    ret

; --
; -- TestSpriteCollision
; --
; -- Test for collision of an 8x8 tile with a background map tile
; --
; -- @param b X position to test
; -- @param c Y position to test
; -- @return z Set if collision
; -- @side a Modified
; --
TestSpriteCollision:
    ; Upper-left pixel
    ; b is already set to the needed X position
    ; c is already set to the needed Y position
    call TestPixelCollision
    ret z
    ; Upper-right pixel
    ; c is already set to the needed Y position
    ld a, b
    add 7
    ld b, a
    call TestPixelCollision
    ret z
    ; Lower-right pixel
    ; b is already set to the needed X position
    ld a, c
    add 7
    ld c, a
    call TestPixelCollision
    ret z
    ; Lower-left pixel
    ; c is already set to the needed Y position
    ld a, b
    sub 7
    ld b, a
    call TestPixelCollision
    ret ; Just return the answer

; --
; -- TestPixelCollision
; --
; -- Test for collision of a pixel with a background map tile
; -- or the edge of the screen
; -- Takes into account the direction of movement
; -- The given X/Y position will be adjusted with the Gameboy screen offsets
; --
; -- @param b X position to check
; -- @param c Y position to check
; -- @return z Set if collision
; -- @side a Modified
; --
TestPixelCollision:
    push hl
    push bc
    push de
    ; Check if off screen
    ld a, 0 + 7
    cp b ; Is the X position == 0?
    jr z, .endTestPixelCollision
    ld a, 0 + 15
    cp c ; Is the Y position == 0?
    jr z, .endTestPixelCollision
    ld a, SCRN_X + 8
    cp b ; Is the X position == edge of screen X?
    jr z, .endTestPixelCollision
    ld a, SCRN_Y + 16
    cp c ; Is the Y position == edge of screen Y+
    jr z, .endTestPixelCollision
    ; Check tile collision
    ; The X position if offset by 8
    ld a, b
    sub 8
    ld b, a
    ; The Y position if offset by 16
    ld a, c
    sub 16
    ld c, a
    ; Divide X position by 8
    srl b
    srl b
    srl b
    ; Divide Y position by 8
    srl c
    srl c
    srl c
    ; Load the current level map into hl
    load_current_level_to_hl
    ; Calculate "pos = (y * 32) + x"
    ld de, 32
.loop
    xor a ; a = 0
    or c
    jr z, .endLoop ; Y position == 0?
    add hl, de     ; Add a row of tile addresses (looped)
    dec c
    jr .loop
.endLoop
    ld c, b
    ld b, a        ; bc now == b, the X position
    add hl, bc     ; Add X position
    ; The background tile we need is now in hl
    ; Is it a brick?
    ld a, TILE_BRICK
    cp [hl] ; Collision with bricks?
    jr z, .endTestPixelCollision
    ; Moving downwards?
    ld a, [wHeroDir]
    and DIR_D
    jr nz, .endTestPixelCollision
    ld a, TILE_SPIKES
    cp [hl] ; Collision with spikes going U/L/R?
.endTestPixelCollision
    pop de
    pop bc
    pop hl
    ret

; --
; -- WaitForVBlank
; --
; -- @side a Modified
; --
WaitForVBlank:
    ld a, [rLY] ; Is the Screen Y coordinate...
    cp SCRN_Y   ; ...done drawing the screen?
    jr nz, WaitForVBlank
    ret

; --
; -- CopyMem
; --
; -- Copy memory from one section to another
; --
; -- @param hl The destination address
; -- @param de The source address
; -- @param bc The number of bytes to copy
; -- @side a, bc, de, hl Modified
; --
CopyMem:
    ld a, [de]  ; Grab 1 byte from the source
    ld [hli], a ; Place it at the destination, incrementing hl
    inc de      ; Move to the next byte
    dec bc      ; Decrement count
    ld a, b     ; 'dec bc' doesn't update flags, so this line...
    or c        ; ...and this line check if bc is 0
    jr nz, CopyMem
    ret

; --
; -- ClearOAM
; --
; -- Set all values in OAM to 0
; -- Because OAM is filled with garbage at startup
; --
; -- @side a, b, hl Modified
; --
ClearOAM:
    ld hl, _OAMRAM
    ld b, OAM_COUNT * sizeof_OAM_ATTRS ; 40 sprites, 4 bytes each
    xor a ; a = 0
.loop
    ld [hli], a
    dec b
    jr nz, .loop
    ret

; --
; -- ReadKeys
; --
; -- Get the current state of button presses
; -- (Down, Up, Left, Right, Start, Select, B, A)
; -- Use "and PADF_<KEYNAME>", if Z is set then the key is pressed
; --
; -- @return wKeys The eight inputs, 0 means pressed
; -- @side a Modified
; --
ReadKeys:
    push hl
    ld hl, wKeys
    ; Read D-pad (Down, Up, Left, Right)
    ld a, P1F_GET_DPAD
    ld [rP1], a
REPT 2            ; Read multiple times to ensure button presses are received
    ld a, [rP1]   ; Read the input, 0 means pressed
ENDR
    or %11110000
    swap a
    ld [hl], a ; Store the result
    ; Read buttons (Start, Select, B, A)
    ld a, P1F_GET_BTN
    ld [rP1], a
REPT 6            ; Read multiple times to ensure button presses are received
    ld a, [rP1]   ; Read the input, 0 means pressed
ENDR
    or %11110000
    ; Combine and store the result
    and [hl]
    ld [hl], a
    pop hl
    ; Clear the retrieval of button presses
    ld a, P1F_GET_NONE
    ld [rP1], a
    ret

; --
; -- Game State Variables
; --
SECTION "Game State Variables", WRAM0

wVBlankFlag: db ; If not zero then update the game

wAnimCounter: db ; If zero then animate

wKeys: db ; The currently pressed keys, updated every game loop

; --
; -- Gameplay
; --
wCurrLevel: dw ; The address pointing to the current level

; --
; -- Hero
; --
wHeroX: db   ; X position
wHeroY: db   ; Y position
wHeroDX: db  ; To move the hero at the correct speed
wHeroDir: db ; The direction the hero is currently moving (U, D, L, R)
             ; Can change mid-frame, for example, when jumping to the right

; --
; -- Enemies
; --

; Spikes
wSpikeList:
wSpike1:
.enabled: db
.x:       db
.y:       db
wEndSpikeList:

; --
; -- Resources
; --
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

