; --  
; -- Ice Cream Castle
; -- David Couzelis 2021-02-20
; -- 

INCLUDE "hardware.inc" ; Common Game Boy definitions
INCLUDE "macros.inc"   ; For convenience

; --
; -- Game Constants
; --

; Player starting position on screen
PLAYER_START_X EQU 48
PLAYER_START_Y EQU 136
ANIM_SPEED     EQU 10 ; Frames until animation time, 10 is 6 FPS

; Number of pixels moved every frame when walking
PLAYER_WALK_SPEED_SUBPIXELS EQU %11000000 ; 0.75 in binary fraction

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
GRAVITY_OFFSET_SUBPIXELS EQU %11011001 ; Give the Y Fudge a little boost, to
                                       ; start falling from gravity sooner
                                       ; 1.0 - GRAVITY_SPEED_SUBPIXELS

; Directions
DIRECTION_UP    EQU %00000001
DIRECTION_DOWN  EQU %00000010
DIRECTION_LEFT  EQU %00000100
DIRECTION_RIGHT EQU %00001000

; Background tiles
; The values map to the tile index number in VRAM
TILE_BRICK  EQU 0 ; Bricks have collision detection
TILE_SPIKES EQU 5 ; Spikes have collision only from left, bottom, right sides

; Video RAM
VRAM_OAM_TILES        EQU _VRAM         ; $8000, used for OAM sprites
VRAM_BACKGROUND_TILES EQU _VRAM + $1000 ; $9000, used for BG tiles

; Player sprite position in OAM
PLAYER_OAM        EQU 1 ; Sprite #1
PLAYER_OAM_TILEID EQU (PLAYER_OAM*_OAMRAM)+OAMA_TILEID
PLAYER_OAM_X      EQU (PLAYER_OAM*_OAMRAM)+OAMA_X
PLAYER_OAM_Y      EQU (PLAYER_OAM*_OAMRAM)+OAMA_Y
PLAYER_OAM_FLAGS  EQU (PLAYER_OAM*_OAMRAM)+OAMA_FLAGS

; --
; -- VBlank Interrupt
; --
; -- Called 60 times per second
; -- Used to time the main game loop
; -- Sets a flag notifying that it's time to update the game logic
; --
; -- @side wram_vblank_flag = 1
; --
SECTION "VBlank Interrupt", ROM0[$0040]
    push hl
    ld hl, wram_vblank_flag
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

Entry_Point:
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
    call Wait_For_VBlank

    xor a
    ld [rLCDC], a       ; Turn off the screen
    ld [wram_vblank_flag], a ; VBlankFlag = 0
    ld [rSCX], a        ; Set the X...
    ld [rSCY], a        ; ...and Y position of the background to 0
    ld [rNR52], a       ; Turn off sound

    call Clear_OAM

    ; Load background tiles
    ld hl, VRAM_BACKGROUND_TILES
    ld de, Resources.background
    ld bc, Resources.end_background - Resources.background
    call Copy_Mem

    ; Load background
    ld hl, _SCRN0 ; $9800 ; The top-left corner of the screen
    ld de, Resources.level_01
    ld bc, Resources.end_level_01 - Resources.level_01
    call Copy_Mem

    ; Load sprite tiles
    ld hl, VRAM_OAM_TILES
    ld de, Resources.sprites
    ld bc, Resources.end_sprites - Resources.sprites
    call Copy_Mem

    ; Load sprites
    ; The player
    ; Load X Position
    ld a, PLAYER_START_X
    ld [wram_player_x], a
    ; Load Y Position
    ld a, PLAYER_START_Y
    ld [wram_player_y], a
    ; Reset variables
    xor a
    ld [wram_player_x_subpixels], a
    ld [wram_player_y_subpixels], a
    ld [wram_player_facing], a
    ld [wram_player_jumping], a
    ; Set the sprite tile number
    xor a
    ld [PLAYER_OAM_TILEID], a
    ; Set attributes
    ld [PLAYER_OAM_FLAGS], a
    ; Init animation
    ld a, ANIM_SPEED
    ld [wram_animation_counter], a

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

Game_Loop:
    ld hl, wram_vblank_flag
    xor a
.wait
    halt                ; Wait for the VBlank interrupt
    ;nop ; nop is automatically inserted after halt by rgbasm
    cp a, [hl]
    jr z, .wait              ; Wait for the VBlank flag to be set
    ld [wram_vblank_flag], a ; Done waiting! Clear the VBlank flag

    ; Time to update the game!

    ; Complete all OAM changes first, befor VBlank ends!

    ; Update the screen
    ld a, [wram_player_x]
    ld [PLAYER_OAM_X], a
    ld a, [wram_player_y]
    ld [PLAYER_OAM_Y], a

    ; Direction facing
    ld a, [wram_player_facing]
    ld [PLAYER_OAM_FLAGS], a

    ; Is it time to animate?
    ; TODO: Only animate the player when on solid
    ld hl, wram_animation_counter
    dec [hl]
    jr nz, .done_animating
    ; Animate!
    ld [hl], ANIM_SPEED      ; Reset the animation counter
    ld a, [PLAYER_OAM_TILEID]
    xor a, $01               ; Toggle the animation frame
    ld [PLAYER_OAM_TILEID], a
.done_animating

    call Read_Keys
    call Update_Player

    jr Game_Loop

    ; End of the main game loop

; --
; -- Update_Player
; --
; -- Move the player based on key input and gravity
; --
; -- @return z Set if collision
; -- @side a Modified
; --
Update_Player:
    ; RIGHT
    ld a, [wram_keys]
    and PADF_RIGHT
    jr nz, .end_move_right ; Right is not pressed, try left...
    ; Move the player to the right!
    xor a
    ld [wram_player_facing], a ; Face right
    ; Calculate the player's new position
    ld a, [wram_player_x_subpixels]
    add PLAYER_WALK_SPEED_SUBPIXELS
    ld [wram_player_x_subpixels], a
    jr nc, .end_move_right
    ; Collision check
    ld a, [wram_player_x]
    inc a ; Test one pixel right
    ld b, a
    ld a, [wram_player_y]
    ld c, a
    ld a, DIRECTION_RIGHT
    ld [wram_player_direction], a
    call Is_Player_Collision
    jr z, .end_move_right ; Collision! Skip movement
    ; Collision check end
    ld hl, wram_player_x
    inc [hl] ; Move the player right
.end_move_right
    
    ; LEFT
    ld a, [wram_keys]
    and PADF_LEFT
    jr nz, .end_move_left
    ; Move the player to the left!
    ld a, OAMF_XFLIP
    ld [wram_player_facing], a ; Face left
    ; Calculate the player's new position
    ld a, [wram_player_x_subpixels]
    sub PLAYER_WALK_SPEED_SUBPIXELS
    ld [wram_player_x_subpixels], a
    jr nc, .end_move_left
    ; Collision check
    ld a, [wram_player_x]
    dec a ; Test one pixel left
    ld b, a
    ld a, [wram_player_y]
    ld c, a
    ld a, DIRECTION_LEFT
    ld [wram_player_direction], a
    call Is_Player_Collision
    jr z, .end_move_left ; Collision! Skip movement
    ; Collision check end
    ld hl, wram_player_x
    dec [hl] ; Move the player left
.end_move_left

;
; JUMP / vertical movement algorithm
;
; (Controller input)
; Is the A button pressed?
; Y -> Is the player on solid ground?
;      Y -> Set IS_JUMPING to 1
;           Set DY to the initial jumping velocity
;
; (Apply gravity)
; Is the player jumping / IS_JUMPING is set to 1?
; Y -> Apply gravity by SUBTRACTING it from DY
;      Did DY down rollover past 0?
;      Y -> Set IS_JUMPING to 0
;           Set DY to 0
; N -> Apply gravity by ADDING it to DY
;      Is DY at terminal velocity?
;      Y -> Cap DY at terminal velocity
;
; (Move the player)
; Is the player jumping / IS_JUMPING is set to 1?
; Y -> Move the player UP according to DY
;      Did the player bonk his head?
;      Y -> Set IS_JUMPING to 0
;           Set DY to 0
; N -> Move the player DOWN according to DY
;

    ; JUMP / A
    ld a, [wram_keys]
    and PADF_A
    jr nz, .end_jump_input ; Z set == A button pressed
    ; Jump button was pressed!
    ; Try to jump!
    ; Is the player on solid ground?
    ; Collision check
    ld a, [wram_player_x]
    ld b, a
    ld a, [wram_player_y]
    inc a ; Test one pixel down
    ld c, a
    ld a, DIRECTION_DOWN
    ld [wram_player_direction], a
    call Is_Player_Collision
    ; If not standing on anything solid then ignore the jump button
    jr nz, .end_jump_input ; Z set == collision
    ; Collision check end
.ifOnSolid
    ; The player is standing on solid ground
    ; Set jumping parameters
    ld a, 1
    ld [wram_player_jumping], a
    ld a, PLAYER_JUMP_SPEED
    ld [wram_player_dy], a
    ld a, PLAYER_JUMP_SPEED_SUBPIXELS
    ld [wram_player_dy_subpixels], a
    ; Clear any leftover movement fudge, for consistent jumping
    xor a
    ld [wram_player_y_subpixels], a
.end_jump_input
    
    ; Gravity
    ; Add gravity to DY every frame
    ; This section ONLY changes velocity, NOT the actual Y position
.add_gravity
    ld a, [wram_player_jumping]
    cp 0 ; Is the player jumping?
    jr z, .add_gravity_down
.add_gravity_up
    ; The player is jumping up
    ld a, [wram_player_dy_subpixels]
    sub GRAVITY_SPEED_SUBPIXELS
    ld [wram_player_dy_subpixels], a
    ld a, [wram_player_dy]
    sbc 0 ; Subtract the carry bit to DY
    ld [wram_player_dy], a ; ...and store it
    jr nc, .end_add_gravity ; Check if the velocity has gone below 0
    ; The player is at the apex of the jump
    ; Clear the velocity and start falling
    xor a
    ld [wram_player_jumping], a
    ld [wram_player_dy], a
    ld [wram_player_dy_subpixels], a
    jr .end_add_gravity
.add_gravity_down
    ; Only add gravity if the player isn't on solid ground
    ; Is the player on solid ground?
    ; Collision check
    ld a, [wram_player_x]
    ld b, a
    ld a, [wram_player_y]
    inc a ; Test one pixel down
    ld c, a
    ld a, DIRECTION_DOWN
    ld [wram_player_direction], a
    call Is_Player_Collision
    ; If not standing on anything solid then add gravity
    jr nz, .add_gravity_nothing_below ; Z set == collision
    ; Collision check end
.add_gravity_on_solid
    ; On solid, clear velocity and skip to the next section
    xor a
    ld [wram_player_y_subpixels], a
    ld [wram_player_dy], a
    ld a, GRAVITY_OFFSET_SUBPIXELS
    ld [wram_player_dy_subpixels], a
    jr .end_add_gravity
.add_gravity_nothing_below
    ; The player is falling down
    ld a, [wram_player_dy_subpixels]
    add GRAVITY_SPEED_SUBPIXELS
    ld [wram_player_dy_subpixels], a
    ld a, [wram_player_dy]
    adc 0 ; Add the carry bit to DY
    ld [wram_player_dy], a ; ...and store it
    ; Test for terminal velocity here!
    ; Don't go faster than terminal velocity
    cp a, GRAVITY_MAX_SPEED
    jr c, .end_add_gravity ; Not maxed out
.max_gravity
    ld [wram_player_dy], a ; Cap the speed to GRAVITY_MAX_SPEED
    xor a
    ld [wram_player_dy_subpixels], a ; Zero out fudge
.end_add_gravity

.vertical_movement
    ld a, [wram_player_jumping]
    cp 0 ; Is the player jumping?
    jr z, .vertical_movement_down
.vertical_movement_up
    ; The player is jumping up
    ld a, [wram_player_dy_subpixels]
    ld b, a
    ld a, [wram_player_y_subpixels]
    sub b ; Subtract DY Fudge from Y Fudge
    ld [wram_player_y_subpixels], a ; ...and store it
    ld a, [wram_player_dy]
    adc 0 ; Add any carry from fudge
    ; Move, one pixel at a time
    ld b, a ; b is my counter
.vertical_movement_up_loop
    ; While b != 0
    ;   Check collision one pixel up
    ;   If no collision, move one pixel up, dec b
    ;   If yes collision, clear DY/Fudge and break
    xor a
    cp b ; b == 0?
    jr z, .end_vertical_movement
    push bc
    ; Collision check
    ld a, [wram_player_x]
    ld b, a
    ld a, [wram_player_y]
    dec a ; Test one pixel up
    ld c, a
    ld a, DIRECTION_UP
    ld [wram_player_direction], a
    call Is_Player_Collision
    ; Collision check end
    pop bc
    jr z, .verticalCollisionUp ; Collision! Skip movement
.noVerticalCollisionUp
    ; Move one pixel up
    ld hl, wram_player_y
    dec [hl]
    dec b
    jr .vertical_movement_up_loop
.verticalCollisionUp
    ; Head bonk!
    ; The player bonked his head!
    ; Cancel the jump
    xor a
    ld [wram_player_jumping], a
    ld [wram_player_dy], a
    ld [wram_player_dy_subpixels], a
    jr .end_vertical_movement

.vertical_movement_down
    ; The player is falling down
    ;
    ; Move Y down DY number of pixels
    ; One pixel at a time, testing collision along the way
    ; Start by updating YFudge from DYFudge,
    ; taking Carry into consideration...
    ; DY doesn't change, unless the player lands on a solid surface
    ;
    ld a, [wram_player_dy_subpixels]
    ld b, a
    ld a, [wram_player_y_subpixels]
    add b ; Add DY Fudge to Y Fudge
    ld [wram_player_y_subpixels], a ; ...and store it
    ld a, [wram_player_dy]
    adc 0 ; Add any carry from fudge
    ; Move, one pixel at a time
    ld b, a ; b is my counter
.verticalMovementDownLoop
    ; While b != 0
    ;   Check collision one pixel down
    ;   If no collision, move one pixel down, dec b
    ;   If yes collision, clear DY/Fudge and break
    xor a
    cp b ; b == 0?
    jr z, .end_vertical_movement
    push bc
    ; Collision check
    ld a, [wram_player_x]
    ld b, a
    ld a, [wram_player_y]
    inc a ; Test one pixel down
    ld c, a
    ld a, DIRECTION_DOWN
    ld [wram_player_direction], a
    call Is_Player_Collision
    pop bc
    jr z, .verticalCollisionDown ; Collision! Skip movement
.noVerticalCollisionDown
    ; Move one pixel down
    ld hl, wram_player_y
    inc [hl]
    dec b
    jr .verticalMovementDownLoop
.verticalCollisionDown
    xor a
    ld [wram_player_dy], a
    ; This prevents a glitch where you can walk over single tile gaps
    ; But you travel two pixels shorter than if it was cleared to 0
    ld a, GRAVITY_OFFSET_SUBPIXELS
    ld [wram_player_dy_subpixels], a
.end_vertical_movement
    
    ; Done updating player
    ret

; --
; -- Is_Player_Collision
; --
; -- Test for collision of an 8x8 tile with a background map tile
; --
; -- @param b X position to test
; -- @param c Y position to test
; -- @return z Set if collision
; -- @side a Modified
; --
Is_Player_Collision:
    ; Upper-left pixel
    ; b is already set to the needed X position
    ; c is already set to the needed Y position
    call Is_Player_Collision_At_Point
    ret z
    ; Upper-right pixel
    ; c is already set to the needed Y position
    ld a, b
    add 7
    ld b, a
    call Is_Player_Collision_At_Point
    ret z
    ; Lower-right pixel
    ; b is already set to the needed X position
    ld a, c
    add 7
    ld c, a
    call Is_Player_Collision_At_Point
    ret z
    ; Lower-left pixel
    ; c is already set to the needed Y position
    ld a, b
    sub 7
    ld b, a
    call Is_Player_Collision_At_Point
    ret ; Just return the answer

; --
; -- Is_Player_Collision_At_Point
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
Is_Player_Collision_At_Point:
    push hl
    push bc
    push de
    ; Check if off screen
    ld a, 0 + (OAM_X_OFS - 1)
    cp b ; Is the X position == 0?
    jr z, .end
    ld a, 0 + (OAM_Y_OFS - 1)
    cp c ; Is the Y position == 0?
    jr z, .end
    ld a, SCRN_X + OAM_X_OFS
    cp b ; Is the X position == edge of screen X?
    jr z, .end
    ld a, SCRN_Y + OAM_Y_OFS
    cp c ; Is the Y position == edge of screen Y+
    jr z, .end
    ; Check tile collision
    ; The X position if offset by 8
    ld a, b
    sub OAM_X_OFS
    ld b, a
    ; The Y position if offset by 16
    ld a, c
    sub OAM_Y_OFS
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
    ld hl, Resources.level_01
    ; Calculate "pos = (y * 32) + x"
    ld de, 32
.loop
    xor a
    or c
    jr z, .end_loop ; Y position == 0?
    add hl, de      ; Add a row of tile addresses (looped)
    dec c
    jr .loop
.end_loop
    ld c, b
    ld b, a    ; bc now == b, the X position
    add hl, bc ; Add X position
    ; The background tile we need is now in hl
    ; Is it a brick?
    ld a, TILE_BRICK
    cp [hl] ; Collision with bricks?
    jr z, .end ; ...collision! Set z
    ; Moving downwards?
    ld a, [wram_player_direction]
    and DIRECTION_DOWN ; Moving downwards?
    jr nz, .end ; ...no! Test for spike collision...
    ld a, TILE_SPIKES
    cp [hl] ; Collision with spikes going up, left, right? If yes, set z
.end
    pop de
    pop bc
    pop hl
    ret

Is_Player_On_Solid:
    ; TODO

Is_Player_Hit:
    ; TODO

; --
; -- Wait_For_VBlank
; --
; -- @side a Modified
; --
Wait_For_VBlank:
    ld a, [rLY] ; Is the Screen Y coordinate...
    cp SCRN_Y   ; ...done drawing the screen?
    jr nz, Wait_For_VBlank
    ret

; --
; -- Copy_Mem
; --
; -- Copy memory from one section to another
; --
; -- @param hl The destination address
; -- @param de The source address
; -- @param bc The number of bytes to copy
; -- @side a, bc, de, hl Modified
; --
Copy_Mem:
    ld a, [de]  ; Grab 1 byte from the source
    ldi [hl], a ; Place it at the destination, incrementing hl
    inc de      ; Move to the next byte
    dec bc      ; Decrement count
    ld a, b     ; 'dec bc' doesn't update flags, so this line...
    or c        ; ...and this line check if bc is 0
    jr nz, Copy_Mem
    ret

; --
; -- Clear OAM
; --
; -- Set all values in OAM to 0
; -- Because OAM is filled with garbage at startup
; --
; -- @side a, b, hl Modified
; --
Clear_OAM:
    ld hl, _OAMRAM
    ld b, OAM_COUNT * sizeof_OAM_ATTRS ; 40 sprites, 4 bytes each
    xor a
.loop
    ldi [hl], a
    dec b
    jr nz, .loop
    ret

; --
; -- Read_Keys
; --
; -- Get the current state of button presses
; -- (Down, Up, Left, Right, Start, Select, B, A)
; -- Use "and PADF_<KEYNAME>", if Z is set then the key is pressed
; --
; -- @return wram_keys The eight inputs, 0 means pressed
; -- @side a Modified
; --
Read_Keys:
    push hl
    ld hl, wram_keys
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

; The VBlank flag is used to update the game at 60 frames per second
; If this is unset then update the game
wram_vblank_flag: db

; If unset then it is time to animate the sprites
wram_animation_counter: db

wram_keys: db ; The currently pressed keys, updated every game loop

; --
; -- Player
; --

; Player X position
wram_player_x:           db
wram_player_x_subpixels: db

; Player Y position
wram_player_y:           db
wram_player_y_subpixels: db

; Player Y speed
wram_player_dy:           db
wram_player_dy_subpixels: db

; The direction the player is facing, 0 for right, OAMF_XFLIP for left
wram_player_facing: db

; Set if the player is currently jumping up (moving in an upwards motion)
wram_player_jumping: db

; The direction the player is currently moving (U, D, L, R)
; Can change mid-frame, for example, when jumping to the right
; Used when moving pixel by pixel
wram_player_direction: db

; --
; -- Enemies
; --

; Spikes
;wram_spike_list:
;wram_spike_1:
;.enabled: db
;.x:       db
;.y:       db
;wram_end_spike_list:

; --
; -- Resources
; --
SECTION "Resources", ROM0

Resources:

; Background tiles
.background
INCBIN "resources/tiles-background.2bpp"
.end_background

; Sprite tiles
.sprites
INCBIN "resources/tiles-sprites.2bpp"
.end_sprites

; Map, level 01
.level_01
INCBIN "resources/tilemap-level-01.map"
.end_level_01

