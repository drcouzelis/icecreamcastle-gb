; Hello Game Boy
; David Couzelis 2021-01-28
; https://eldred.fr/gb-asm-tutorial/hello-world.html
; Compile with RGB

; Helpful RGB definitions
INCLUDE "hardware.inc"

; Header
; Memory type: ROM 0
; Game execution begins at address 100
SECTION "Header", ROM0[$100]

EntryPoint:
    nop ; Common practice to have this here
    jp Start ; Leave this tiny space

REPT $150 - $104
    db 0
ENDR

;; TO DO
;; Main game loop
;Main:
;    halt           ; Stop the system clock return from halt when interrupted
;    nop            ; Always nop after halt
;    ld a,[rIE]     ; Get the interrupts
;    or a           ; V-Blank interrupt?
;    jr z, Main     ; No, some other interrupt
;    xor a
;    ld (VblnkFlag),a ; Clear V-Blank flag
;    ;call Controls  ; Handle controls input
;    ;call Update    ; Update the game
;    ;call Draw      ; Draw the game
;    jr Main

SECTION "Game code", ROM0
Start:
    ei ; Enable interrupts
    ; Turn off the LCD
.waitVBlank
    ld a, [rLY]
    cp 144 ; Check if the LCD is past VBlank
    jr c, .waitVBlank

    xor a ; (ld a, 0) Reset bit 7 to turn off the screen
    ld [rLCDC], a ; We'll need to write to LCDC again later...

    ld hl, $9000
    ld de, FontTiles
    ld bc, FontTilesEnd - FontTiles
.copyFont
    ld a, [de] ; Grab 1 byte from the source
    ld [hli], a ; Place it at the destination, incrementing hl
    inc de ; Move to the next byte
    dec bc ; Decrement count
    ld a, b ; 'dec bc' doesn't update flags, so this line...
    or c ; ...and this line check if bc is 0
    jr nz, .copyFont

    ld hl, $9800 ; Print the string at the top-left corner of the screen
    ld de, HelloWorldStr
.copyString
    ld a, [de]
    ld [hli], a
    inc de
    and a ; Check if the byte we just copied is zero...
    jr nz, .copyString ; ...and continue if it's not

    ; Init display registers
    ld a, %00100110 ; Palette, first number is text, last number is background
    ld [rBGP], a

    ; Set the X, Y position of the text
    ; ...was originally set to 0
    ;xor a ; (ld a, 0)
    ; ...rSCY and rSCX are the SCROLL / window position, NOT the text position
    ld a, -8
    ld [rSCY], a
    ld a, -16
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

SECTION "Font", ROM0

FontTiles:
INCBIN "font.chr" ; Copy contents into my ROM
FontTilesEnd:

SECTION "Hello World string", ROM0

HelloWorldStr:
    db "Hello Game Boy!", 0

