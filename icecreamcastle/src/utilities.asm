; --
; -- General use code
; --

; --
; -- MACRO: Divide By 8
; --
; -- Divide the given register by 8.
; --
; -- @param \1 Register
; --
MACRO divide_by_8
    srl  \1
    srl  \1
    srl  \1
ENDM

SECTION "Utilities", ROM0

; --
; -- Reset OAM
; --
; -- Set all values in OAM to 0
; -- Because OAM is filled with garbage at startup
; --
; -- @side b, hl Modified
; --
ResetOAM:
    ld   hl, _OAMRAM

    ; OAM is 40 sprites, 4 bytes each
    ld   b, OAM_COUNT * sizeof_OAM_ATTRS

    xor  a
.loop
    ldi  [hl], a
    dec  b
    jr   nz, .loop

    ret

; --
; -- Wait For VBlank
; --
; -- Wait for VBlank
; -- The screen can only be updated during VBlank
; --
WaitForVBlank:

    ; Get the Y coordinate that is currently been drawn...
    ld   a, [rLY]

    ; ...and is it equal to the number of rows on the screen?
    cp   SCRN_Y
    jr   nz, WaitForVBlank

    ret

; --
; -- Copy Mem
; --
; -- Copy memory from one section to another
; --
; -- @param hl The destination address
; -- @param de The source address
; -- @param bc The number of bytes to copy
; -- @side bc, de, hl Modified
; --
CopyMem:

    ; Grab 1 byte from the source
    ld   a, [de]

    ; Place it at the destination, then increment hl
    ldi  [hl], a

    ; Move to the next byte
    inc  de

    ; Decrement the counter
    dec  bc

    ; dec doesn't update flags
    ; These two instructions check if bc is 0
    ld   a, b
    or   c
    jr   nz, CopyMem

    ret

