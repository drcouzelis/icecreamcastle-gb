; --  
; -- Ice Cream Castle
; -- David Couzelis 2021-02-20
; -- 

INCLUDE "hardware.inc" ; Common definitions

; --
; -- Game Constants
; --

; Hero sprite position in OAM
HERO_OAM        EQU 1 ; Sprite #1
HERO_OAM_TILEID EQU (HERO_OAM*_OAMRAM)+OAMA_TILEID
HERO_OAM_X      EQU (HERO_OAM*_OAMRAM)+OAMA_X
HERO_OAM_Y      EQU (HERO_OAM*_OAMRAM)+OAMA_Y
HERO_OAM_FLAGS  EQU (HERO_OAM*_OAMRAM)+OAMA_FLAGS

; Hero starting position on screen
HERO_START_X EQU 48
HERO_START_Y EQU 136
ANIM_SPEED   EQU 10 ; Frames until animation time, 10 is 6 FPS

; Number of pixels moved every frame when walking
HERO_WALK_SPEED_FUDGE EQU %11000000 ; BCD 0.75

; Jump up with a velocity of 2.75 pixels per frame
HERO_JUMP_VEL       EQU 2
HERO_JUMP_VEL_FUDGE EQU %11000000

GRAVITY_SPEED_FUDGE EQU %00100111 ; BCD 0.15234375, increase this amount every frame
GRAVITY_MAX         EQU 2         ; Terminal velocity, 2 pixels per frame

; Background tiles
TILE_BRICK  EQU 0 ; Bricks have collision detection
TILE_SPIKES EQU 5 ; Spikes have collision only from left, bottom, right sides

; Directions
DIR_U EQU %00000001
DIR_D EQU %00000010
DIR_L EQU %00000100
DIR_R EQU %00001000

; --
; -- VBlank Interrupt
; --
; -- Called 60 times per second
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
    ld hl, _VRAM9000 ; $9000
    ld de, Resources.background
    ld bc, Resources.endBackground - Resources.background
    call CopyMem

    ; Load background
    ld hl, _SCRN0 ; $9800 ; The top-left corner of the screen
    ld de, Resources.level1
    ld bc, Resources.endLevel1 - Resources.level1
    call CopyMem

    ; Load sprite tiles
    ld hl, _VRAM ; $8000
    ld de, Resources.sprites
    ld bc, Resources.endSprites - Resources.sprites
    call CopyMem

    ; Load sprites
    ; The hero
    ; Load X Position
    ld a, HERO_START_X
    ld [wHeroX], a
    ; Load Y Position
    ld a, HERO_START_Y
    ld [wHeroY], a
    ; Reset variables
    xor a ; a = 0
    ld [wHeroXFudge], a
    ld [wHeroYFudge], a
    ld [wHeroFacing], a
    ld [wHeroIsJumping], a
    ; Set the sprite tile number
    xor a ; a = 0
    ld [HERO_OAM_TILEID], a
    ; Set attributes
    ld [HERO_OAM_FLAGS], a
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

    ; Direction facing
    ld a, [wHeroFacing]
    ld [HERO_OAM_FLAGS], a

    ;; Is it time to animate?
    ;ld hl, wAnimCounter
    ;dec [hl]
    ;jr nz, .readKeys
    ;; Animate!
    ;ld [hl], ANIM_SPEED      ; Reset the animation counter
    ;ld a, [HERO_OAM_TILEID]
    ;xor a, $01               ; Toggle the animation frame
    ;ld [HERO_OAM_TILEID], a

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
    ld [wHeroFacing], a ; Face right
    ; Calculate the hero's new position
    ld a, [wHeroXFudge]
    add HERO_WALK_SPEED_FUDGE
    ld [wHeroXFudge], a
    jr nc, .endMoveRight
    ; Collision check
    ld a, [wHeroX]
    inc a ; Test one pixel right
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
    ld [wHeroFacing], a ; Face left
    ; Calculate the hero's new position
    ld a, [wHeroXFudge]
    sub HERO_WALK_SPEED_FUDGE
    ld [wHeroXFudge], a
    jr nc, .endMoveLeft
    ; Collision check
    ld a, [wHeroX]
    dec a ; Test one pixel left
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

;
; JUMP / vertical movement algorithm
;
; (Controller input)
; Is the A button pressed?
; Y -> Is the hero on solid ground?
;      Y -> Set IS_JUMPING to 1
;           Set DY to the initial jumping velocity
;
; (Apply gravity)
; Is the hero jumping / IS_JUMPING is set to 1?
; Y -> Apply gravity by SUBTRACTING it from DY
;      Did DY down rollover past 0?
;      Y -> Set IS_JUMPING to 0
;           Set DY to 0
; N -> Apply gravity by ADDING it to DY
;      Is DY at terminal velocity?
;      Y -> Cap DY at terminal velocity
;
; (Move the hero)
; Is the hero jumping / IS_JUMPING is set to 1?
; Y -> Move the hero UP according to DY
;      Did the hero bonk his head?
;      Y -> Set IS_JUMPING to 0
;           Set DY to 0
; N -> Move the hero DOWN according to DY
;

    ; JUMP / A
    ld a, [wKeys]
    and PADF_A
    jr nz, .endJumpInput ; Z set == A button pressed
    ; Jump button was pressed!
    ; Try to jump!
    ; Is the hero on solid ground?
    ; Collision check
    ld a, [wHeroX]
    ld b, a
    ld a, [wHeroY]
    inc a ; Test one pixel down
    ld c, a
    ld a, DIR_D
    ld [wHeroDir], a
    call TestSpriteCollision
    ; If not standing on anything solid then ignore the jump button
    jr nz, .endJumpInput ; Z set == collision
    ; Collision check end
.ifOnSolid
    ; The hero is standing on solid ground
    ; Set jumping parameters
    ld a, 1
    ld [wHeroIsJumping], a
    ld a, HERO_JUMP_VEL
    ld [wHeroDY], a
    ld a, HERO_JUMP_VEL_FUDGE
    ld [wHeroDYFudge], a
    xor a ; a = 0
    ; Clear any leftover movement fudge, for consistent jumping
    ld [wHeroYFudge], a
.endJumpInput
    
    ; Gravity
    ; Add gravity to DY every frame
    ; This section ONLY changes velocity, NOT the actual Y position
.addGravity
    ld a, [wHeroIsJumping]
    cp 0 ; Is the hero jumping?
    jr z, .addGravityDown
.addGravityUp
    ; The hero is jumping up
    ld a, [wHeroDYFudge]
    sub GRAVITY_SPEED_FUDGE
    ld [wHeroDYFudge], a
    ld a, [wHeroDY]
    sbc 0 ; Add the carry bit to DY
    ld [wHeroDY], a ; ...and store it
    jr nc, .endGravity ; Check if the velocity has gone below 0
    ; The hero is at the apex of the jump
    ; Clear the velocity and start falling
    xor a ; a = 0
    ld [wHeroIsJumping], a
    ld [wHeroDY], a
    ld [wHeroDYFudge], a
    jr .endGravity
.addGravityDown
    ; The hero is falling down
    ld a, [wHeroDYFudge]
    add GRAVITY_SPEED_FUDGE
    ld [wHeroDYFudge], a
    ld a, [wHeroDY]
    adc 0 ; Add the carry bit to DY
    ld [wHeroDY], a ; ...and store it
    ; Test for terminal velocity here!
    ; Don't go faster than terminal velocity
    cp a, GRAVITY_MAX
    jr c, .endGravity ; Not maxed out
.maxGravity
    ld [wHeroDY], a ; Cap the speed to GRAVITY_MAX
    xor a ; a = 0
    ld [wHeroDYFudge], a ; Zero out fudge
.endGravity

.verticalMovement
    ld a, [wHeroIsJumping]
    cp 0 ; Is the hero jumping?
    jr z, .verticalMovementDown
.verticalMovementUp
    ; The hero is jumping up
    ld a, [wHeroDYFudge]
    ld b, a
    ld a, [wHeroYFudge]
    ; TODO
    ; SHOULD THIS BE ADD OR SUB???
    sub b ; (Add DY Fudge to Y Fudge / Subtract DY Fudge from Y Fudge)
    ld [wHeroYFudge], a ; ...and store it
    ld a, [wHeroDY]
    adc 0 ; Subtract any carry from fudge
    ; Move, one pixel at a time
    ld b, a ; b is my counter
.verticalMovementUpLoop
    ; While b != 0
    ;   Check collision one pixel up
    ;   If no collision, move one pixel up, dec b
    ;   If yes collision, clear DY/Fudge and break
    xor a ; a = 0
    cp b ; b == 0?
    jr z, .endVerticalMovement
    push bc
    ; Collision check
    ld a, [wHeroX]
    ld b, a
    ld a, [wHeroY]
    dec a ; Test one pixel up
    ld c, a
    ld a, DIR_U
    ld [wHeroDir], a
    call TestSpriteCollision
    ; Collision check end
    pop bc
    jr z, .verticalCollisionUp ; Collision! Skip movement
.noVerticalCollisionUp
    ; Move one pixel up
    ld hl, wHeroY
    dec [hl]
    dec b
    jr .verticalMovementUpLoop
.verticalCollisionUp
    ; Head bonk!
    ; The hero bonked his head!
    ; Cancel the jump
    xor a ; a = 0
    ld [wHeroIsJumping], a
    ld [wHeroDY], a
    ld [wHeroDYFudge], a
    jr .endVerticalMovement

.verticalMovementDown
    ; The hero is falling down
    ;
    ; Move Y down DY number of pixels
    ; One pixel at a time, testing collision along the way
    ; Start by updating YFudge from DYFudge,
    ; taking Carry into consideration...
    ; DY doesn't change, unless the hero lands on a solid surface
    ;
    ld a, [wHeroDYFudge]
    ld b, a
    ld a, [wHeroYFudge]
    add b ; Add DY Fudge to Y Fudge
    ld [wHeroYFudge], a ; ...and store it
    ld a, [wHeroDY]
    adc 0 ; Add any carry from fudge
    ; Move, one pixel at a time
    ld b, a ; b is my counter
.verticalMovementDownLoop
    ; While b != 0
    ;   Check collision one pixel down
    ;   If no collision, move one pixel down, dec b
    ;   If yes collision, clear DY/Fudge and break
    xor a ; a = 0
    cp b ; b == 0?
    jr z, .endVerticalMovement
    push bc
    ; Collision check
    ld a, [wHeroX]
    ld b, a
    ld a, [wHeroY]
    inc a ; Test one pixel down
    ld c, a
    ld a, DIR_D
    ld [wHeroDir], a
    call TestSpriteCollision
    pop bc
    jr z, .verticalCollisionDown ; Collision! Skip movement
.noVerticalCollisionDown
    ; Move one pixel down
    ld hl, wHeroY
    inc [hl]
    dec b
    jr .verticalMovementDownLoop
.verticalCollisionDown
    xor a ; a = 0
    ld [wHeroDY], a
    ld [wHeroDYFudge], a
    jr .endVerticalMovement
.endVerticalMovement
    
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
    ld hl, Resources.level1
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
    jr z, .endTestPixelCollision ; ...collision! Set z
    ; Moving downwards?
    ld a, [wHeroDir]
    and DIR_D ; Moving downwards?
    jr nz, .endTestPixelCollision ; ...no! Test for spike collision...
    ld a, TILE_SPIKES
    cp [hl] ; Collision with spikes going up, left, right? If yes, set z
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
    ldi [hl], a ; Place it at the destination, incrementing hl
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
    ldi [hl], a
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
; -- Hero
; --
wHeroX: db       ; X position
wHeroY: db       ; Y position
wHeroXFudge: db  ; X position, sub-pixel fractions
wHeroYFudge: db  ; Y position, sub-pixel fractions
wHeroDY: db      ; Y change, per frame
wHeroDYFudge: db ; Y change, per frame
wHeroFacing: db  ; The direction the hero is facing, 0 for right, OAMF_XFLIP for left
wHeroIsJumping: db ; Set if the hero is currently jumping up
wHeroDir: db     ; The direction the hero is currently moving (U, D, L, R)
                 ; Can change mid-frame, for example, when jumping to the right
                 ; Used when moving pixel by pixel

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




; --
; -- OLD UNUSED CODE
; --

;; --
;; -- Gameplay
;; --
;wCurrLevel: dw ; Points to the address of the current level
;    ; Set level 1 as the current level
;    ld hl, wCurrLevel
;    ld [hl], LOW(Resources.level1)
;    inc hl
;    ld [hl], HIGH(Resources.level1)

; Jump info
;NOT_JUMPING EQU 0
;IS_JUMPING  EQU 1

;HERO_JUMP_SPEED       EQU %00000010 ; DEC 2
;HERO_JUMP_SPEED_FUDGE EQU %10001100 ; BCD 0.55 Approx

;    ; UP
;    ld a, [wKeys]
;    and PADF_UP
;    jr nz, .endMoveUp
;    ; Clear acceleration
;    xor a ; a = 0
;    ld [wHeroDY], a
;    ld [wHeroDYFudge], a
;    ; Collision check
;    ld a, [wHeroX]
;    ld b, a
;    ld a, [wHeroY]
;    dec a ; Test one pixel up
;    ld c, a
;    ld a, DIR_U
;    ld [wHeroDir], a
;    call TestSpriteCollision
;    jp z, .endGravity ; Collision! Up was pressed, skip gravity
;    ; Collision check end
;    ld hl, wHeroY
;    dec [hl]
;    jp .endGravity ; Up was pressed, skip gravity
;.endMoveUp

;.ifOnSolid
;    ; The hero is standing on solid ground
;    ; Set jumping parameters
;    ld a, HERO_JUMP_SPEED_FUDGE
;    ld [wHeroDYFudge], a
;    ld a, HERO_JUMP_SPEED
;    ld [wHeroDY], a
;    ld a, IS_JUMPING
;    ld [wHeroJumping], a ; Mark the character as jumping / moving / headed up
;.endMoveJump

;    ; Jump
;    ; Move the hero up, if needed
;.jump
;    ld a, [wHeroJumping]
;    cp IS_JUMPING ; Is the hero moving up, aka jumping?
;    jr nz, .gravity ; ...no, skip jumping, move on to adding gravity
;.performJump
;    ; Move Y up DY number of pixels
;    ; One pixel at a time, testing collision along the way
;    ld a, [wHeroDYFudge]
;    ld b, a
;    ld a, [wHeroYFudge]
;    sub b ; Subtract DY Fudge from Y Fudge
;    ld [wHeroYFudge], a ; ...and store it
;    ld a, [wHeroDY]
;    sbc 0 ; Subtract any carry from fudge
;    jr nc, .beginJumpMovementLoop
;    ; If there was a carry, that means it's time to start going down!
;    ld a, NOT_JUMPING
;    xor a ; a = 0
;    ld [wHeroDY], a
;    ld [wHeroDYFudge], a
;    jr .endJump ; Starting to travel down, skip the rest of the jump and go to gravity
;.beginJumpMovementLoop
;    ; Move, one pixel at a time
;    ld b, a ; b is my counter
;.jumpMovementLoop
;    ; While b != 0
;    ;   Check collision one pixel up
;    ;   If no collision, move one pixel up, dec b
;    ;   If yes collision, clean DY/Fudge and break
;    xor a ; a = 0
;    cp b ; b == 0?
;    jr z, .endJump
;    push bc
;    ; Collision check
;    ld a, [wHeroX]
;    ld b, a
;    ld a, [wHeroY]
;    dec a ; Test one pixel up
;    ld c, a
;    ld a, DIR_U
;    ld [wHeroDir], a
;    call TestSpriteCollision
;    pop bc
;    jr z, .jumpCollision ; Collision! Skip movement
;.noJumpCollision
;    ; Move one pixel up
;    ld hl, wHeroY
;    dec [hl]
;    dec b
;    jr .jumpMovementLoop
;.jumpCollision
;    ; The hero is bonking his head
;    xor a ; a = 0
;    ld [wHeroDY], a
;    ld [wHeroDYFudge], a
;.endJump
;    jr .endGravity ; Done with vertical movement, skip adding gravity

;wHeroDX: db      ; X change, per frame
;wHeroNewX: db    ; X position, where trying to move to
;wHeroNewY: db    ; Y position, where trying to move to
;ld [wHeroJumping], a ; NOT_JUMPING == 0
;wHeroJumping: db ; If the hero is moving in an upwards direction,
;                 ; NOT_JUMPING (0) for down, IS_JUMPING (1) for up

