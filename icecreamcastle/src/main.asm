; --  
; -- Ice Cream Castle
; -- David Couzelis 2021-02-20
; -- 

; Common Game Boy definitions
; https://github.com/gbdev/hardware.inc
INCLUDE "hardware.inc"

INCLUDE "dma.asm"
INCLUDE "player.asm"
INCLUDE "utilities.asm" 

; --
; -- Game Constants
; --

; Player starting position on screen
PLAYER_START_COL   EQU 6
PLAYER_START_ROW   EQU 17
PLAYER_ANIM_SPEED  EQU 12 ; Frames until animation time, 12 is 5 FPS

PLAYER_WIDTH   EQU 7
PLAYER_HEIGHT  EQU 7

TARGET_COL     EQU 16
TARGET_ROW     EQU 7
TARGET_START_X EQU 8 * TARGET_COL
TARGET_START_Y EQU 8 * TARGET_ROW

; Number of pixels moved every frame when walking
PLAYER_WALK_SPEED_SUBPIXELS EQU %11000000 ; 0.75 in binary fraction

; Enemy Saw movement speed
ENEMY_SAW_SPEED_SUBPIXELS EQU %10000000 ; 0.5 in binary fraction
ENEMY_SAW_ANIM_SPEED EQU 4 ; 4 is 15 FPS

; Countdown until the lasers toggle on or off
LASER_SPEED EQU 60 ; Toggle lasers every second

; Jump up with a velocity of 2.75 pixels per frame
PLAYER_JUMP_SPEED           EQU 2
PLAYER_JUMP_SPEED_SUBPIXELS EQU %11000000 ; 0.75 in binary fraction

; Gravity, increase the speed falling down every frame by this amount
GRAVITY_SPEED_SUBPIXELS EQU %00100111 ; 0.15234375 in binary fraction

; Cap the speed of falling, AKA terminal velocity
GRAVITY_MAX_SPEED EQU 2 ; 2 pixels per frame

; This number is used to "push" the player down a bit
; to start "falling" from gravity more quickly
; This fixes an issue where the player can walk accross
; single tile sized gaps
GRAVITY_OFFSET_SUBPIXELS EQU %11011001 ; 1.0 - GRAVITY_SPEED_SUBPIXELS

; Directions
DIR_UP    EQU %00000001
DIR_DOWN  EQU %00000010
DIR_LEFT  EQU %00000100
DIR_RIGHT EQU %00001000

; Sprite tiles
; These values map to the tile index number in VRAM $8000
SPRITE_PLAYER EQU 0
SPRITE_TARGET EQU 2
SPRITE_SAW    EQU 5

; Background tiles
; The values map to the tile index number in VRAM $9000
TILE_BRICK  EQU 0 ; Bricks have collision detection
TILE_BLANK  EQU 1 ; The black background
TILE_LASER  EQU 3
TILE_SPIKES EQU 6 ; Spikes have collision only from left, bottom, right sides

; Video RAM
VRAM_OAM_TILES        EQU _VRAM         ; $8000, used for OAM sprites
VRAM_BACKGROUND_TILES EQU _VRAM + $1000 ; $9000, used for BG tiles

; Player sprite position in OAM
PLAYER_OAM        EQU 0 * sizeof_OAM_ATTRS ; The first sprite in the list

; Player sprite position in OAM DMA memory
PLAYER_OAM_TILEID EQU DMA_OAM + PLAYER_OAM + OAMA_TILEID
PLAYER_OAM_X      EQU DMA_OAM + PLAYER_OAM + OAMA_X
PLAYER_OAM_Y      EQU DMA_OAM + PLAYER_OAM + OAMA_Y
PLAYER_OAM_FLAGS  EQU DMA_OAM + PLAYER_OAM + OAMA_FLAGS

; Target sprite position in OAM
TARGET_OAM        EQU 1 * sizeof_OAM_ATTRS

; Target sprite position in OAM DMA memory
TARGET_OAM_TILEID EQU DMA_OAM + TARGET_OAM + OAMA_TILEID
TARGET_OAM_X      EQU DMA_OAM + TARGET_OAM + OAMA_X
TARGET_OAM_Y      EQU DMA_OAM + TARGET_OAM + OAMA_Y
TARGET_OAM_FLAGS  EQU DMA_OAM + TARGET_OAM + OAMA_FLAGS

; Enemy Saw 1 sprite position in OAM
ENEMYSAW1_OAM        EQU 2 * sizeof_OAM_ATTRS
; Enemy Saw 1 sprite position in OAM DMA memory
ENEMYSAW1_OAM_TILEID EQU DMA_OAM + ENEMYSAW1_OAM + OAMA_TILEID
ENEMYSAW1_OAM_X      EQU DMA_OAM + ENEMYSAW1_OAM + OAMA_X
ENEMYSAW1_OAM_Y      EQU DMA_OAM + ENEMYSAW1_OAM + OAMA_Y
ENEMYSAW1_OAM_FLAGS  EQU DMA_OAM + ENEMYSAW1_OAM + OAMA_FLAGS

; Enemy Saw 2 sprite position in OAM
ENEMYSAW2_OAM        EQU 3 * sizeof_OAM_ATTRS
; Enemy Saw 2 sprite position in OAM DMA memory
ENEMYSAW2_OAM_TILEID EQU DMA_OAM + ENEMYSAW2_OAM + OAMA_TILEID
ENEMYSAW2_OAM_X      EQU DMA_OAM + ENEMYSAW2_OAM + OAMA_X
ENEMYSAW2_OAM_Y      EQU DMA_OAM + ENEMYSAW2_OAM + OAMA_Y
ENEMYSAW2_OAM_FLAGS  EQU DMA_OAM + ENEMYSAW2_OAM + OAMA_FLAGS

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
    ld   hl, wVBlankFlag
    ld   [hl], 1
    pop  hl
    reti

; --
; -- Header
; --
; -- Memory type ROM0 for a 32K ROM
; -- https://gbdev.io/pandocs/#the-cartridge-header
; -- The rest is automatically filled in by rgbfix
; --
SECTION "Header", ROM0[$0100]

entry_point:
    nop
    jp   Start

REPT $150 - @
    db   0
ENDR

; --
; -- Game Code
; --
SECTION "Game Code", ROM0[$0150]

Start:

    ; Disable interrupts during setup
    di

    ; Wait for VBlank before starting setup
    call WaitForVBlank

; Initialize the system

    xor  a

    ; Turn off the screen
    ld   [rLCDC], a

    ; Reset the VBLank flag
    ld   [wVBlankFlag], a

    ; Set the X and Y positions of the background layer to 0
    ld   [rSCX], a
    ld   [rSCY], a

    ; Turn off sound (for now)
    ; TODO: Add sound!
    ld   [rNR52], a

    ; OAM is all messy at initialization, clean it up
    call ResetOAM

    ; Initialize DMA
    call InitDMA

; Load all graphics

    ; Load background tiles into VRAM
    ; These are the actual tiles / pixels themselves
    ld   hl, VRAM_BACKGROUND_TILES
    ld   de, Level01Tiles
    ld   bc, Level01Tiles.end - Level01Tiles
    call CopyMem

    ; Load the background tilemap into the background layer
    ; Starting at the top left corner of the background layer
    ; This maps tiles to a place in the background layer, to be drawn to the screen
    ld   hl, _SCRN0 ; $9800
    ld   de, Level01Tilemap
    ld   bc, Level01Tilemap.end - Level01Tilemap
    call CopyMem

    ; Load sprite tiles into VRAM
    ; These are the actual tiles / pixels themselves, not the OAM mappings
    ld   hl, VRAM_OAM_TILES
    ld   de, SpriteTiles
    ld   bc, SpriteTiles.end - SpriteTiles
    call CopyMem

; Initialize the player

    ; Set the sprite tile number
    ld   a, SPRITE_PLAYER
    ld   [PLAYER_OAM_TILEID], a

; Initialize the target (ice cream)

    ld   a, SPRITE_TARGET
    ld   [TARGET_OAM_TILEID], a
    ld   a, TARGET_START_X
    ld   [TARGET_OAM_X], a
    ld   a, TARGET_START_Y
    ld   [TARGET_OAM_Y], a

; Reset all level parameters before starting the level

    call ResetLevel

; Initialize more of the system

    ; Init palettes
    ld   a, %00011011

    ; Background palette
    ld   [rBGP], a

    ; Object palette 0
    ld   [rOBP0], a

    ; Turn the screen on, enable the OAM and BG layers
    ld   a, LCDCF_ON | LCDCF_OBJON | LCDCF_BGON
    ld   [rLCDC], a

    ; Enable interrupts
    ; We only need one interrupt, the VBlank interrupt
    ld   a, IEF_VBLANK
    ld   [rIE], a
    ei

    ; ...setup complete!

    ; Continue through to the main game loop

GameLoop:

    ld   hl, wVBlankFlag
    xor  a

.wait
    ; Wait for the VBlank interrupt
    halt

    ; NOTE: "nop" MUST be the next command after "halt"
    ; to avoid a bug in the Game Boy hardware
    nop

    ; Wait for the VBlank flag to be set...
    cp   a, [hl]
    jr   z, .wait

    ; ...done waiting! Now clear the VBlank flag and continue
    ld   [wVBlankFlag], a

; Time to update the game!

    ; Update the sprites in OAM using DMA
    call hDMA

    ; Did the player die?
    ld   a, [wPlayerDead]
    cp   1
    jr   nz, .notdead

    ; The player DIED
    ; Reset the current level so they can try again
    di
    call WaitForVBlank
    call ResetLevel
    ei
.notdead

    ; Did the player win?
    ld   a, [wPlayerWin]
    cp   1
    jr   nz, .notwon

    call VictoryScreen
.notwon

    ; Update the status of the lasers (part of the background layer)
    call UpdateLasers

    ; Update the game animations
    call AnimatePlayer

    ; Sync the WRAM variables with DMA
    call UpdateOAM

    call AnimateEnemies

    ; Get player input
    call ReadKeys

    ; Update the player location and map collision
    call UpdatePlayer

    ; Check for win condition
    call CheckTarget

    ; Check for collision with spikes and lasers
    call CheckTraps

    ; Check for collision with enemies
    call CheckEnemies
    ; TODO: Put collision detection for Saw 2 with Saw 1
    call CheckCollisionWithEnemySaw2

    ; Update enemies
    call UpdateEnemySaw1
    call UpdateEnemySaw2

.end
    jp   GameLoop

UpdateOAM:

    ; Update the player object
    ; Player position
    ld   a, [wPlayerX]
    ld   [PLAYER_OAM_X], a
    ld   a, [wPlayerY]
    ld   [PLAYER_OAM_Y], a

    ; Direction facing
    ld   a, [wPlayerFacing]
    ld   [PLAYER_OAM_FLAGS], a

    ; Update the enemy saw 1 object
    ld   a, [wEnemySaw1.x]
    ld   [ENEMYSAW1_OAM_X], a
    ld   a, [wEnemySaw1.y]
    ld   [ENEMYSAW1_OAM_Y], a

    ; Update the enemy saw 2 object
    ld   a, [wEnemySaw2.x]
    ld   [ENEMYSAW2_OAM_X], a
    ld   a, [wEnemySaw2.y]
    ld   [ENEMYSAW2_OAM_Y], a

    ret

AnimatePlayer:

    ; Is it time to animate?
    ld   hl, wPlayerAnimCounter
    dec  [hl]
    jr   nz, .end

    ; Animate!

    ; Reset the animation counter
    ld   [hl], PLAYER_ANIM_SPEED

    ; Toggle the animation frame for the player
    ld   a, [PLAYER_OAM_TILEID]
    xor  a, $01
    ld   [PLAYER_OAM_TILEID], a

    ; ...and the target
    ld   a, [TARGET_OAM_TILEID]
    xor  a, $01
    ld   [TARGET_OAM_TILEID], a

.end

    ret

AnimateEnemies:

    ld   hl, wEnemySawAnimCounter
    dec  [hl]
    jr   nz, .end

    ; %00000101 -> frame 1
    ; %00000110 -> frame 2
    ; %00000011 -> apply this xor to toggle

    ; Enemy Saw 1
    ld   a, [ENEMYSAW1_OAM_TILEID]
    xor  a, $03 ; Toggle between sprites 5 and 6
    ld   [ENEMYSAW1_OAM_TILEID], a

    ; Enemy Saw 2
    ld   a, [ENEMYSAW2_OAM_TILEID]
    xor  a, $03 ; Toggle between sprites 5 and 6
    ld   [ENEMYSAW2_OAM_TILEID], a

    ; Reset the counter
    ld   a, ENEMY_SAW_ANIM_SPEED
    ld   [wEnemySawAnimCounter], a

.end

    ret

; --
; -- Reset Level
; --
; -- Reset the current level
; --
ResetLevel:

    ; Load default player position
    ld   a, 8 * PLAYER_START_COL
    ld   [wPlayerX], a
    ld   a, 8 * PLAYER_START_ROW
    ld   [wPlayerY], a

    ; Reset player values
    xor  a
    ld   [wPlayerXSub], a
    ld   [wPlayerYSub], a
    ld   [wPlayerFacing], a
    ld   [wPlayerJumping], a

    ; Reset the enemy saw 1 values
    ld   a, SPRITE_SAW
    ld   [ENEMYSAW1_OAM_TILEID], a
    ld   a, 8 * 13
    ld   [wEnemySaw1.x], a
    ld   a, 8 * 9
    ld   [wEnemySaw1.y], a
    ld   a, DIR_RIGHT
    ld   [wEnemySaw1.dir], a
    xor  a
    ld   [wEnemySaw1.x_sub], a
    ld   [wEnemySaw1.y_sub], a

    ; Reset the enemy saw 2 values
    ld   a, SPRITE_SAW
    ld   [ENEMYSAW2_OAM_TILEID], a
    ld   a, 8 * 11
    ld   [wEnemySaw2.x], a
    ld   a, 8 * 4
    ld   [wEnemySaw2.y], a
    ld   a, DIR_RIGHT
    ld   [wEnemySaw2.dir], a
    xor  a
    ld   [wEnemySaw2.x_sub], a
    ld   [wEnemySaw2.y_sub], a

    ; Init the lasers
    ld   a, LASER_SPEED
    ld   [wLasersFlashCount], a
    call EnableLasers

    ; Init animation
    ld   a, PLAYER_ANIM_SPEED
    ld   [wPlayerAnimCounter], a

    ld   a, ENEMY_SAW_ANIM_SPEED
    ld   [wEnemySawAnimCounter], a

    ; Revive the player
    xor  a
    ld   [wPlayerDead], a

    ret

VictoryScreen:
    ; TODO: Wait until a button is pressed
    ;jr   nz, VictoryScreen
    ret

; --
; -- MACRO: Test Player Collision Going (Direction)
; --
; -- Test if the player is able to one pixel in
; -- the given direction without collision with
; -- the map
; --
; -- @param \1 One of the four directions
; --
MACRO test_player_collision_going
    ld   a, [wPlayerX]
IF \1 == DIR_LEFT
    dec  a
ELIF \1 == DIR_RIGHT
    inc  a
ENDC
    ld   b, a
    ld   a, [wPlayerY]
IF \1 == DIR_UP
    dec  a
ELIF \1 == DIR_DOWN
    inc  a
ENDC
    ld   c, a
    ld   a, \1
    ld   [wPlayerDir], a
    call CheckTerrain
ENDM

; --
; -- Update Player
; --
; -- Move the player based on key input and gravity
; --
; -- @return z Set if collision
; --
UpdatePlayer:

; RIGHT
    ld   a, [wKeys]
    and  PADF_RIGHT
    jr   nz, .end_right

    ; Right key pressed

    ; Face right
    xor  a
    ld   [wPlayerFacing], a

    ; Calculate the player's new position
    ld   a, [wPlayerXSub]
    add  PLAYER_WALK_SPEED_SUBPIXELS
    ld   [wPlayerXSub], a
    jr   nc, .end_right

    ; Check for map collision
    test_player_collision_going DIR_RIGHT
    jr   z, .end_right

    ; Move the player right
    ld   hl, wPlayerX
    inc  [hl]
.end_right
    
; LEFT
    ld   a, [wKeys]
    and  PADF_LEFT
    jr   nz, .end_left

    ; Left key pressed

    ; Face left
    ld   a, OAMF_XFLIP
    ld   [wPlayerFacing], a

    ; Calculate the player's new position
    ld   a, [wPlayerXSub]
    sub  PLAYER_WALK_SPEED_SUBPIXELS
    ld   [wPlayerXSub], a
    jr   nc, .end_left

    ; Check for map collision
    test_player_collision_going DIR_LEFT
    jr   z, .end_left

    ; Move the player left
    ld   hl, wPlayerX
    dec  [hl]
.end_left

; JUMP / vertical movement

    ; CONTROLLER INPUT
    ; Is the A button pressed?
    ; Y -> Is the player on solid ground?
    ;      Y -> Set IS_JUMPING to 1
    ;           Set DY to the initial jumping speed

    ; JUMP / A
    ld   a, [wKeys]
    and  PADF_A
    jr   nz, .end_button_a

    ; Jump button was pressed!
    ; If not standing on anything solid then ignore the jump button
    test_player_collision_going DIR_DOWN
    jr   nz, .end_button_a

    ; The player is standing on solid ground and is trying to jump
    ; Set jumping parameters
    ld   a, 1
    ld   [wPlayerJumping], a
    ld   a, PLAYER_JUMP_SPEED
    ld   [wPlayerDY], a
    ld   a, PLAYER_JUMP_SPEED_SUBPIXELS
    ld   [wPlayerDYSub], a

    ; Clear any leftover subpixel movement, for consistent jumping
    xor  a
    ld   [wPlayerYSub], a
.end_button_a
    
; APPLY GRAVITY

    ; Is the player jumping / IS_JUMPING is set to 1?
    ; Y -> Apply gravity by SUBTRACTING it from DY
    ;      Did DY down rollover past 0?
    ;      Y -> Set IS_JUMPING to 0
    ;           Set DY to 0
    ; N -> Apply gravity by ADDING it to DY
    ;      Is DY at terminal velocity?
    ;      Y -> Cap DY at terminal velocity

    ; Gravity
    ; Add gravity to DY every frame
    ; This section ONLY changes speed, NOT the actual Y position

    ; Is the player moving upwards (jumping) or down?
    ld   a, [wPlayerJumping]
    cp   0
    jr   z, .going_down

    ; The player is jumping up
    ld   a, [wPlayerDYSub]
    sub  GRAVITY_SPEED_SUBPIXELS
    ld   [wPlayerDYSub], a
    ld   a, [wPlayerDY]
    ; Subtract the carry bit from DY...
    sbc  0
    ; ...and store it
    ld   [wPlayerDY], a

    ; Check if the upward velocity has gone below 0
    jr   nc, EndGravity

    ; The player is at the apex of the jump
    ; Start coming back down!
    ; Clear the velocity and start falling
    xor  a
    ld   [wPlayerJumping], a
    ld   [wPlayerDY], a
    ld   [wPlayerDYSub], a
    jr   EndGravity

.going_down
    ; Only add gravity if the player isn't on solid ground
    ; If not standing on anything solid then add gravity
    test_player_collision_going DIR_DOWN
    jr   nz, .no_collision_down

    ; On solid, clear velocity and skip to the next section
    xor  a
    ld   [wPlayerYSub], a
    ld   [wPlayerDY], a
    ; The subpixel position SHOULD be cleared to 0, but we instead
    ; give it a little bit of an offset
    ; This prevents a glitch where you can walk over single tile gaps
    ld   a, GRAVITY_OFFSET_SUBPIXELS
    ld   [wPlayerDYSub], a
    jr   EndGravity

.no_collision_down
    ; The player is falling down
    ld   a, [wPlayerDYSub]
    add  GRAVITY_SPEED_SUBPIXELS
    ld   [wPlayerDYSub], a
    ld   a, [wPlayerDY]
    ; Add the carry bit to DY...
    adc  0
    ; ...and store it
    ld   [wPlayerDY], a
    ; Test for terminal velocity here!
    ; Don't go faster than terminal velocity
    cp   a, GRAVITY_MAX_SPEED
    ; If c is set then that means DY is less than GRAVITY MAX SPEED
    jr   c, EndGravity

    ; Cap the speed to GRAVITY_MAX_SPEED
    ; Cap it to the max speed so you don't fall at excessive speeds
    ld   [wPlayerDY], a
    xor  a
    ; Zero out the subpixel speed
    ld   [wPlayerDYSub], a

EndGravity:

; MOVE THE PLAYER

    ; Is the player jumping / IS_JUMPING is set to 1?
    ; Y -> Move the player UP according to DY
    ;      Did the player bonk his head?
    ;      Y -> Set IS_JUMPING to 0
    ;           Set DY to 0
    ; N -> Move the player DOWN according to DY

    ; Is the player moving upwards (jumping) or down?
    ld   a, [wPlayerJumping]
    cp   0
    jr   z, _update_player__vertical_movement_down

_update_player__vertical_movement_up:
    ; The player is jumping up
    ld a, [wPlayerDYSub]
    ld b, a
    ld a, [wPlayerYSub]
    sub b ; Subtract DY Fudge from Y Fudge
    ld [wPlayerYSub], a ; ...and store it
    ld a, [wPlayerDY]
    adc 0 ; Add any carry from fudge
    ; Move, one pixel at a time
    ld b, a ; b is my counter

    ; While b != 0
    ;   Check collision one pixel up
    ;   If no collision, move one pixel up, dec b
    ;   If yes collision, clear DY/Fudge and break
.loop
    xor a
    cp b ; b == 0?
    jr z, _update_player__end_vertical_movement
    push bc
    test_player_collision_going DIR_UP
    pop bc
    jr z, _update_player__vertical_collision_up ; Collision! Skip movement
    ; Move one pixel up
    ld hl, wPlayerY
    dec [hl]
    dec b
    jr .loop

_update_player__vertical_collision_up:
    ; Head bonk!
    ; The player bonked his head!
    ; Cancel the jump
    xor a
    ld [wPlayerJumping], a
    ld [wPlayerDY], a
    ld [wPlayerDYSub], a
    jr _update_player__end_vertical_movement

_update_player__vertical_movement_down:
    ; The player is falling down
    ;
    ; Move Y down DY number of pixels
    ; One pixel at a time, testing collision along the way
    ; Start by updating YFudge from DYFudge,
    ; taking Carry into consideration...
    ; DY doesn't change, unless the player lands on a solid surface
    ;
    ld a, [wPlayerDYSub]
    ld b, a
    ld a, [wPlayerYSub]
    add b ; Add DY Fudge to Y Fudge
    ld [wPlayerYSub], a ; ...and store it
    ld a, [wPlayerDY]
    adc 0 ; Add any carry from fudge
    ; Move, one pixel at a time
    ld b, a ; b is my counter
    ; While b != 0
    ;   Check collision one pixel down
    ;   If no collision, move one pixel down, dec b
    ;   If yes collision, clear DY/Fudge and break
.loop
    xor a
    cp b ; b == 0?
    jr z, _update_player__end_vertical_movement
    push bc
    test_player_collision_going DIR_DOWN
    pop bc
    jr z, _update_player__end_vertical_movement ; Collision! Skip movement
    ; Move one pixel down
    ld hl, wPlayerY
    inc [hl]
    dec b
    jr .loop

_update_player__end_vertical_movement:
    ; Done updating player
    ret

; --
; -- Check Terrain
; --
; -- Check for player collision with the level terrain
; --
; -- @param b X position to test
; -- @param c Y position to test
; -- @return z Set if collision
; --
CheckTerrain:

    ; Upper-left pixel
    ; b is already set to the needed X position
    ; c is already set to the needed Y position
    call CheckTerrainAtPoint
    ret  z

    ; Upper-right pixel
    ; c is already set to the needed Y position
    ld   a, b
    add  PLAYER_WIDTH
    ld   b, a
    call CheckTerrainAtPoint
    ret  z

    ; Lower-right pixel
    ; b is already set to the needed X position
    ld   a, c
    add  PLAYER_HEIGHT
    ld   c, a
    call CheckTerrainAtPoint
    ret  z

    ; Lower-left pixel
    ; c is already set to the needed Y position
    ld   a, b
    sub  PLAYER_WIDTH
    ld   b, a
    call CheckTerrainAtPoint

    ; Just return the answer, regardless of what the result is
    ; at this point
    ret

; --
; -- Check Terrain At Point
; --
; -- Check for collision of a pixel with a background map tile
; -- or the edge of the screen
; -- Takes into account the direction of movement
; -- The given X and Y positions will be adjusted with the screen offsets
; --
; -- @param b X position to check
; -- @param c Y position to check
; -- @return z Set if collision
; --
CheckTerrainAtPoint:

    push hl
    push bc
    push de

    ; Check if off screen / bound the player to the screen

    ; Is the X position == 0?
    ld   a, 0 + (OAM_X_OFS - 1)
    cp   b
    jr   z, .end

    ; Is the Y position == 0?
    ld   a, 0 + (OAM_Y_OFS - 1)
    cp   c
    jr   z, .end

    ; Is the X position == edge of screen X?
    ld   a, SCRN_X + OAM_X_OFS
    cp   b
    jr   z, .end

    ; Is the Y position == edge of screenY?
    ld   a, SCRN_Y + OAM_Y_OFS
    cp   c
    jr   z, .end

    ; Check tile collision

    ld   a, b
    ; The X position is offset by 8
    sub  OAM_X_OFS
    ld   b, a
    ld   a, c
    ; The Y position is offset by 16
    sub  OAM_Y_OFS
    ld   c, a

    ; Divide X position by 8
    divide_by_8 b

    ; Divide Y position by 8
    divide_by_8 c

    ; Load the current level map into hl
    ld hl, Level01Tilemap

    ; Calculate "pos = (y * 32) + x"
    ld de, 32
.loop
    xor  a
    or   c
    ; Finish when Y position is 0
    jr   z, .end_loop

    ; Add a row of tile addresses (looped)
    add  hl, de
    dec  c
    jr   .loop
.end_loop

    ; Set bc to the X position...
    ld   c, b
    ld   b, a

    ; ...and add the X position
    add  hl, bc

    ; The background tile we need is now in hl

    ; BRICK collision check

    ; Is it a brick?
    ld   a, TILE_BRICK
    cp   [hl]
    ; If it's a brick, finish up and return the result
    jr   z, .end

    ; SPIKES collision check, in regards to movement
    ; You can only collide with spikes from the
    ; left, right, or bottom, but you'll pass through
    ; spikes coming from above (and you'll die)

    ; Is the player moving downwards?
    ld   a, [wPlayerDir]
    and  DIR_DOWN
    jr   nz, .end ; ...no! Test for spike collision...

    ; The player is not moving downwards, so check for collision
    ld   a, TILE_SPIKES
    cp   [hl]

.end

    pop  de
    pop  bc
    pop  hl

    ret

CheckTarget:

    push bc

    ; Upper-left pixel
    ld   a, [wPlayerX]
    ld   b, a
    ld   a, [wPlayerY]
    ld   c, a
    call CheckTargetAtPoint
    jr z, .end

    ; Upper-right pixel
    ld   a, b
    add  PLAYER_WIDTH + 1
    ld   b, a
    call CheckTargetAtPoint
    jr   z, .end

    ; Lower-right pixel
    ld   a, c
    add  PLAYER_HEIGHT + 1
    ld   c, a
    call CheckTargetAtPoint
    jr   z, .end

    ; Lower-left pixel
    ld   a, b
    sub  PLAYER_WIDTH
    ld   b, a
    call CheckTargetAtPoint

.end
    pop  bc
    ret

; --
; -- Check Target At Point
; --
; -- Test for collision of a pixel with the target / goal
; --
; -- @param b X position to check
; -- @param c Y position to check
; -- @return z Set if collision
; --
CheckTargetAtPoint:
    push bc

    divide_by_8 b
    divide_by_8 c

    ; Check the X position
    ld   a, TARGET_COL
    cp   a, b
    jr   nz, .end

    ; Check the Y position
    ld   a, TARGET_ROW
    cp   a, c
    jr   nz, .end

    ; The player touched the target!
    call PlayerWon

.end
    pop  bc
    ret

; --
; -- Check Traps
; --
; -- Check for player collision with traps (spikes, lasers)
; --
; -- @return z Set if collision
; --
CheckTraps:

    push bc

    ; Upper-left pixel
    ld   a, [wPlayerX]
    ld   b, a
    ld   a, [wPlayerY]
    ld   c, a
    call CheckTrapsAtPoint
    jr z, .end

    ; Upper-right pixel
    ld   a, b
    add  PLAYER_WIDTH
    ld   b, a
    call CheckTrapsAtPoint
    jr   z, .end

    ; Lower-right pixel
    ld   a, c
    add  PLAYER_HEIGHT
    ld   c, a
    call CheckTrapsAtPoint
    jr   z, .end

    ; Lower-left pixel
    ld   a, b
    sub  PLAYER_WIDTH
    ld   b, a
    call CheckTrapsAtPoint

.end
    pop  bc
    ret

; --
; -- Check Traps At Point
; --
; -- Check for player collisions with traps at a specific pixel
; --
; -- @param b X position to check
; -- @param c Y position to check
; -- @return z Set if collision
; --
CheckTrapsAtPoint:

    push hl
    push bc
    push de

    ; Check collision with spikes
    ; The X position is offset by 8
    ld   a, b
    sub  OAM_X_OFS
    ld   b, a
    ; The Y position is offset by 16
    ld   a, c
    sub  OAM_Y_OFS
    ld   c, a
    divide_by_8 b
    divide_by_8 c
    ; Load the current level map into hl
    ld   hl, Level01Tilemap
    ; Calculate "pos = (y * 32) + x"
    ld   de, 32
.loop
    xor  a
    or   c
    ; End when Y position is 0
    jr   z, .end_loop
    ; Add a row of tile addresses (looped)
    add  hl, de       
    dec  c
    jr   .loop
.end_loop

    ld   c, b
    ld   b, a    ; bc now == b, the X position
    add  hl, bc  ; Add X position

    ; The background tile we need is now in hl

; Check for collision with lasers

    ; Check collision with lasers first
    ; otherwise z may be set incorrectly for the return

    ; If the lasers are off, skip the check
    ld   a, [wLasersEnabled]
    cp   0
    jr   z, .end_lasers

    ld   a, TILE_LASER
    cp   [hl]
    jr   nz, .end_lasers

    ; Player hit a laser!
    call PlayerKilled

.end_lasers

; Check for collision with spikes

    ld   a, TILE_SPIKES
    cp   [hl]
    jr   nz, .end_spikes

    ; Player hit spikes!
    call PlayerKilled

.end_spikes

    pop  de
    pop  bc
    pop  hl

    ret

PlayerWon:
    ld   a, 1
    ; TODO
    ;ld   [wPlayerWin], a
    ld   [wPlayerDead], a
    ret

; --
; -- Player Killed
; --
; -- Mark that the player has been killed
; --
PlayerKilled:
    ld   a, 1
    ld   [wPlayerDead], a
    ret

; --
; -- Update Enemy Saw 1
; --
UpdateEnemySaw1:

    ; TODO: The saw should be moving at the speed of ENEMY_SAW_SPEED_SUBPIXELS
    ;       using wEnemySaw1.x_sub

    ld   a, [wEnemySaw1.dir]
    cp   a, DIR_RIGHT
    jr   nz, .left
.right
    ld   a, [wEnemySaw1.x_sub]
    add  a, ENEMY_SAW_SPEED_SUBPIXELS
    ld   [wEnemySaw1.x_sub], a
    jr   nc, .check_bounce
    ld   hl, wEnemySaw1.x
    inc  [hl]
    jr   .check_bounce

.left
    ld   a, [wEnemySaw1.x_sub]
    add  a, ENEMY_SAW_SPEED_SUBPIXELS
    ld   [wEnemySaw1.x_sub], a
    jr   nc, .check_bounce
    ld   hl, wEnemySaw1.x
    dec  [hl]

.check_bounce
    ld   hl, wEnemySaw1.x
    ld   a, 8 * 15
    cp   a, [hl]
    jr   z, .bounce_left

    ld   a, 8 * 8
    cp   a, [hl]
    jr   z, .bounce_right

    jr   .end

.bounce_left
    ld   a, DIR_LEFT
    ld   [wEnemySaw1.dir], a
    jr   .end

.bounce_right
    ld   a, DIR_RIGHT
    ld   [wEnemySaw1.dir], a
    jr   .end

.end
    ret

; --
; -- Update Enemy Saw 2
; --
UpdateEnemySaw2:

    ld   a, [wEnemySaw2.dir]
    cp   a, DIR_RIGHT
    jr   nz, .left
.right
    ld   a, [wEnemySaw2.x_sub]
    add  a, ENEMY_SAW_SPEED_SUBPIXELS
    ld   [wEnemySaw2.x_sub], a
    jr   nc, .check_bounce
    ld   hl, wEnemySaw2.x
    inc  [hl]
    jr   .check_bounce

.left
    ld   a, [wEnemySaw2.x_sub]
    add  a, ENEMY_SAW_SPEED_SUBPIXELS
    ld   [wEnemySaw2.x_sub], a
    jr   nc, .check_bounce
    ld   hl, wEnemySaw2.x
    dec  [hl]

.check_bounce
    ; if X == 8 * 15 then go LEFT
    ; if X == 8 * 8 then go RIGHT
    ld   hl, wEnemySaw2.x
    ld   a, 8 * 13
    cp   a, [hl]
    jr   z, .bounce_left

    ld   a, 8 * 7
    cp   a, [hl]
    jr   z, .bounce_right

    jr   .end

.bounce_left
    ld   a, DIR_LEFT
    ld   [wEnemySaw2.dir], a
    jr   .end

.bounce_right
    ld   a, DIR_RIGHT
    ld   [wEnemySaw2.dir], a
    jr   .end

.end
    ret

; --
; -- Check Collision With Enemy Saw 1
; --
CheckEnemies:

    push bc

    ; Upper-left pixel
    ld   a, [wPlayerX]
    ld   b, a
    ld   a, [wPlayerY]
    ld   c, a
    call CheckEnemiesAtPoint
    jr z, .end

    ; Upper-right pixel
    ld   a, b
    add  PLAYER_WIDTH + 1
    ld   b, a
    call CheckEnemiesAtPoint
    jr   z, .end

    ; Lower-right pixel
    ld   a, c
    add  PLAYER_HEIGHT + 1
    ld   c, a
    call CheckEnemiesAtPoint
    jr   z, .end

    ; Lower-left pixel
    ld   a, b
    sub  PLAYER_WIDTH
    ld   b, a
    call CheckEnemiesAtPoint

.end
    pop  bc
    ret

; --
; -- Check Enemies At Point
; --
; -- Check for collision with enemies (saws) at a specific pixel
; --
; -- @param b X position to check
; -- @param c Y position to check
; --
CheckEnemiesAtPoint:

    ; if X (b) > wEnemySaw1.x
    ; if wEnemySaw1.x (a) < X (b)
    ;   no -> jr .end
    ld   a, [wEnemySaw1.x]
    cp   a, b
    jr   nc, .end

    ; if X (b) < wEnemySaw1.x + 8
    ; if wEnemySaw1.x + 8 (a) > X (b)
    ;   no -> jr .end
    ld   a, [wEnemySaw1.x]
    add  7
    cp   a, b
    jr   c, .end

    ; if Y (c) > wEnemySaw1.y
    ; if wEnemySaw1.y (a) < Y (c)
    ;   no -> jr .end
    ld   a, [wEnemySaw1.y]
    cp   a, c
    jr   nc, .end

    ; if Y (c) < wEnemySaw1.y + 8
    ;   no -> jr .end
    ld   a, [wEnemySaw1.y]
    add  7
    cp   a, c
    jr   c, .end

    ; Collision!
    call PlayerKilled

.end
    ; No collision
    ret

; --
; -- Check Collision With Enemy Saw 2
; --
CheckCollisionWithEnemySaw2:
    push bc

    ; Upper-left pixel
    ld   a, [wPlayerX]
    ld   b, a
    ld   a, [wPlayerY]
    ld   c, a
    call CheckCollisionWithEnemySaw2AtPoint
    jr z, .end

    ; Upper-right pixel
    ld   a, b
    add  PLAYER_WIDTH + 1
    ld   b, a
    call CheckCollisionWithEnemySaw2AtPoint
    jr   z, .end

    ; Lower-right pixel
    ld   a, c
    add  PLAYER_HEIGHT + 1
    ld   c, a
    call CheckCollisionWithEnemySaw2AtPoint
    jr   z, .end

    ; Lower-left pixel
    ld   a, b
    sub  PLAYER_WIDTH
    ld   b, a
    call CheckCollisionWithEnemySaw2AtPoint

.end
    pop  bc
    ret

; --
; -- Check Collision With Enemy Saw 2 At Point (Pixel Position)
; --
; -- @param b X position to check
; -- @param c Y position to check
; --
CheckCollisionWithEnemySaw2AtPoint:

; Enemy Saw 2

    ld   a, [wEnemySaw2.x]
    cp   a, b
    jr   nc, .end

    ld   a, [wEnemySaw2.x]
    add  7
    cp   a, b
    jr   c, .end

    ld   a, [wEnemySaw2.y]
    cp   a, c
    jr   nc, .end

    ld   a, [wEnemySaw2.y]
    add  7
    cp   a, c
    jr   c, .end

    call PlayerKilled
    ret

.end
    ret

UpdateLasers:
    ld   hl, wLasersFlashCount
    dec  [hl]
    jr   nz, .end

    ; Reset the laser countdown
    ld   [hl], LASER_SPEED

    ; Toggle the lasers
    ld   a, [wLasersEnabled]
    cp   0
    jr   z, .enable_lasers

    ; Disable lasers
    ld   a, TILE_BLANK ; The blank black background tile
    call SetLasers
    ld   hl, wLasersEnabled
    ld   [hl], 0
    jr .end

.enable_lasers
    ; Enable lasers
    ld   a, TILE_LASER ; Laser tile
    call SetLasers
    ld   hl, wLasersEnabled
    ld   [hl], 1

.end
    ret

EnableLasers:
    ld   a, TILE_LASER
    call SetLasers

    ld   hl, wLasersEnabled
    ld   [hl], 1
    ret

SetLasers:
    ; Top row laser
    ld   hl, _SCRN0 + ((2 * SCRN_VX_B) + 9)
    ld   [hl], a
    ld   hl, _SCRN0 + ((3 * SCRN_VX_B) + 9)
    ld   [hl], a
    ld   hl, _SCRN0 + ((4 * SCRN_VX_B) + 9)
    ld   [hl], a
    ld   hl, _SCRN0 + ((5 * SCRN_VX_B) + 9)
    ld   [hl], a

    ; Bottom row left laser
    ld   hl, _SCRN0 + ((12 * SCRN_VX_B) + 8)
    ld   [hl], a
    ld   hl, _SCRN0 + ((13 * SCRN_VX_B) + 8)
    ld   [hl], a
    ld   hl, _SCRN0 + ((14 * SCRN_VX_B) + 8)
    ld   [hl], a
    ld   hl, _SCRN0 + ((15 * SCRN_VX_B) + 8)
    ld   [hl], a

    ; Bottom row right laser
    ld   hl, _SCRN0 + ((12 * SCRN_VX_B) + 12)
    ld   [hl], a
    ld   hl, _SCRN0 + ((13 * SCRN_VX_B) + 12)
    ld   [hl], a
    ld   hl, _SCRN0 + ((14 * SCRN_VX_B) + 12)
    ld   [hl], a
    ld   hl, _SCRN0 + ((15 * SCRN_VX_B) + 12)
    ld   [hl], a

    ret

; --
; -- Read Keys
; --
; -- Get the current state of button presses
; -- (Down, Up, Left, Right, Start, Select, B, A)
; -- Use "and PADF_<KEYNAME>", if Z is set then the key is pressed
; --
; -- @return wKeys The eight inputs, 0 means pressed
; --
ReadKeys:
    push hl

    ; Results will be stored in hl
    ld   hl, wKeys

    ; Read D-pad (Down, Up, Left, Right)
    ld   a, P1F_GET_DPAD
    ld   [rP1], a

    ; Use REPT to read the values multiple times to ensure
    ; button presses are recorded

    ; Read the input from rP1, 0 means pressed
REPT 2
    ld   a, [rP1]
ENDR
    or   %11110000
    swap a

    ; Store the result
    ld   [hl], a

    ; Read buttons (Start, Select, B, A)
    ld   a, P1F_GET_BTN
    ld   [rP1], a

REPT 6
    ld   a, [rP1]
ENDR
    or   %11110000

    ; Combine and store the result
    and  [hl]
    ld   [hl], a

    ; Clear the retrieval of button presses
    ld   a, P1F_GET_NONE
    ld   [rP1], a

    pop  hl
    ret

; --
; -- Game State Variables
; --
SECTION "Game State Variables", WRAM0

; The VBlank flag is used to update the game at 60 frames per second
; If this is unset then update the game
wVBlankFlag: db

; If unset then it is time to animate the sprites
wPlayerAnimCounter: db

; The currently pressed keys, updated every game loop
wKeys: db

; --
; -- Player
; --

; Player position, plus subpixel position
wPlayerX:    db
wPlayerXSub: db
wPlayerY:    db
wPlayerYSub: db

; Player Y speed
wPlayerDY:    db
wPlayerDYSub: db

; The direction the player is facing, 0 for right, OAMF_XFLIP for left
wPlayerFacing: db

; Set if the player is currently jumping up (moving in an upwards motion)
wPlayerJumping: db

; The direction the player is currently moving (U, D, L, R)
; Can change mid-frame, for example, when jumping to the right
; Used when moving pixel by pixel
wPlayerDir: db

; Set to 1 if the player is dead
wPlayerDead: db

; Set to 1 if the player won
wPlayerWin: db

; --
; -- Enemies
; --

; Enemy Saw 1
; Middle section of the level
; 
wEnemySaw1:
.x:         db ; X pos
.x_sub:     db
.y:         db ; Y pos
.y_sub:     db
.dir:       db ; Direction the saw is moving in

; Enemy Saw 2
; Middle section of the level
; 
wEnemySaw2:
.x:         db ; X pos
.x_sub:     db
.y:         db ; Y pos
.y_sub:     db
.dir:       db ; Direction the saw is moving in

wEnemySawAnimCounter: db

; Lasers
; Countdown to 0, then toggle the lasers
;
wLasersFlashCount: db
wLasersEnabled:    db

; --
; -- Resources
; --
SECTION "Resources", ROM0

; Background tiles
Level01Tiles:
INCBIN "tiles-background.2bpp"
.end

; Sprite tiles
SpriteTiles:
INCBIN "tiles-sprites.2bpp"
.end

; Map, level 01
Level01Tilemap:
INCBIN "tilemap-level-01.map"
.end
