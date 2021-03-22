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
HERO_START_X EQU 48
HERO_START_Y EQU 136
ANIM_SPEED   EQU 10 ; Frames until animation time

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
    ld [HERO_OAM_X], a
    ; Set Y Position
    ld a, HERO_START_Y
    ld [HERO_OAM_Y], a
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

    ; Turn screen on, display the background
    ld a, LCDCF_ON | LCDCF_OBJON | LCDCF_BGON
    ld [rLCDC], a

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

    ; Character control
.isPressedKeyRight
    ld a, b
    and PADF_RIGHT
    jr nz, .isPressedKeyLeft ; Right is not pressed, try left...
    ; Move the hero to the right!
    xor a ; a = 0
    ld [_OAMRAM + OAMA_FLAGS], a ; Face right
    ; Move 0.75 pixels per frame, or, skip movement every 4th frame
    ld hl, wHeroDX
    dec [hl]
    jr nz, .moveRight
    ld [hl], HERO_DX_RESET ; wHeroDX == 0, reset the DX counter
    jr .isPressedKeyLeft
.moveRight
    push bc
    ;ld a, [HERO_OAM_X]
    ;ld b, a
    ;ld a, [HERO_OAM_Y]
    ;ld c, a
    ;;ld d, DIRECTION_DOWN
    ;ld hl, Resources.level1
    ;call TestCollision8x8
    pop bc
    jr z, .isPressedKeyLeft ; Collision! Skip movement
    ld hl, HERO_OAM_X
    inc [hl] ; Move the hero right
    
.isPressedKeyLeft
    ld a, b
    and PADF_LEFT
    jr nz, .isPressedKeyUp
    ; Move the hero to the left!
    ld a, OAMF_XFLIP
    ld [_OAMRAM + OAMA_FLAGS], a ; Face left
    ; Move 0.75 pixels per frame, or, skip movement every 4th frame
    ld hl, wHeroDX
    dec [hl]
    jr nz, .moveLeft
    ld [hl], HERO_DX_RESET ; wHeroDX == 0, reset the DX counter
    jr .isPressedKeyUp
.moveLeft
    ld hl, HERO_OAM_X
    dec [hl] ; Move the hero left

.isPressedKeyUp
    ld a, b
    and PADF_UP
    jr nz, .isPressedKeyDown
    ld hl, HERO_OAM_Y
    dec [hl]
    
.isPressedKeyDown
    ld a, b
    and PADF_DOWN
    jr nz, .inputDone
    ld hl, HERO_OAM_Y
    inc [hl]
    
.inputDone
    jr GameLoop

; --
; -- TestCollision8x8
; --
; -- Test for collision of an 8x8 tile with a background map tile
; --
; -- @param b X position
; -- @param c Y position
; -- @param d Direction
; -- @param hl Current level map
; -- @return z Set if collision
; -- @side a Modified
; --
TestCollision8x8:
    ; Upper-left pixel
    ; b is already set to the needed X position
    ; c is already set to the needed Y position
    call TestCollision1x1
    ret z
    ; Upper-right pixel
    ; c is already set to the needed Y position
    ld a, 7
    add b
    ld b, a
    call TestCollision1x1
    ret z
    ; Lower-right pixel
    ; b is already set to the needed X position
    ld a, 7
    add c
    ld c, a
    call TestCollision1x1
    ret z
    ; Lower-left pixel
    ; c is already set to the needed Y position
    ld a, 7
    sub b
    ld b, a
    call TestCollision1x1
    ret ; Just return the answer

; --
; -- TestCollision1x1
; --
; -- Test for collision of a pixel with a background map tile
; --
; -- @param b X position
; -- @param c Y position
; -- @param d Direction
; -- @param hl Current level map
; -- @return z Set if collision
; -- @side a Modified
; --
TestCollision1x1:
    push hl
    push bc
REPT 3    ; Divide by 8
    sra b
ENDR
REPT 3    ; Divide by 8
    sra c
ENDR
    ; pos = (y * 32) + x
    ; Use de for multiplication
    push de
    xor a
    ld d, a
    ld e, c        ; de == c, the Y position
    or e
.loop
    jr z, .endLoop ; e == 0?
    add hl, de     ; Add Y position (looped)
    dec e
    jr .loop
.endLoop
    ld e, b        ; de == b, the X position
    add hl, de     ; Add X position
    pop de
    ; Is it a brick?
    ; The background tile we need is now in hl
    xor a ; a = 0
    cp [hl] ; If tile 0 (bricks) then collision!
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
; -- @return b The eight inputs, 0 means pressed
; -- @side a Modified
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

; --
; -- Game State Variables
; --
SECTION "Game State Variables", WRAM0

wVBlankFlag: db ; If not zero then update the game

wAnimCounter: db ; If zero then animate
wHeroDX: db ; To move the hero at the correct speed

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

