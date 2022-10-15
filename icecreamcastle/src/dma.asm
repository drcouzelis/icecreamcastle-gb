; --
; -- DMA OAM
; --

; The address of the start of OAM in WRAM
DMA_OAM EQU $C100

; --
; -- DMA ROUTINES
; --
SECTION "DMA Routines", ROM0

; --
; -- INIT DMA
; -- 
; -- Initialize DMA for OAM. This will copy the DMA routine to HRAM.
; --
InitDMA:
    ; The DMA routine must be run from HRAM
    ; so copy the routine from here to there

    ld   hl, RunDMA
    ld   b, EndRunDMA - RunDMA ; Number of bytes to copy
    ld   c, LOW(hDMA)  ; Low byte of the destination address
.copy
    ldi  a, [hl]
    ldh  [c], a
    inc  c
    dec  b
    jr   nz, .copy
    ret

; --
; -- RUN DMA
; --
; -- Every time this routine is called it will copy the version
; -- of OAM in WRAM to the actual OAM in VRAM, then wait for the
; -- DMA to finish.
; --
; -- NOTE: DO NOT CALL THIS ROUTINE
; --
; -- Instead, this will get copied and run from HRAM.
; --
RunDMA:
    ; Start the DMA transfer
    ld   a, HIGH(wDMAStart)
    ldh  [rDMA], a
    ; Delay for a total of 40 * 4 = 160 cycles
    ld   a, OAM_COUNT
.wait
    dec  a         ; 1 cycle
    jr   nz, .wait ; 3 cycles
    ret
EndRunDMA:

; --
; -- DMA OAM
; --
; -- We use a chunk of WRAM as a way to access OAM
; -- OAM is 40 sprites * 4 bytes each
; --
; TODO: Replace this with "ALIGN"
SECTION "DMA OAM", WRAM0[DMA_OAM]

wDMAStart: ds OAM_COUNT * sizeof_OAM_ATTRS
wDMAEnd:

; --
; -- HRAM DMA
; --
SECTION "HRAM DMA", HRAM

; The DMA routine must be loaded to HRAM at runtime
; Reserve space to copy the routine to
hDMA: ds EndRunDMA - RunDMA
