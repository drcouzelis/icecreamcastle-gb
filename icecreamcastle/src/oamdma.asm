;WRAM_OAM_DMA EQU $C100
;
;; Player sprite position in OAM DMA memory
;WRAM_PLAYER_OAM_TILEID EQU WRAM_OAM_DMA+PLAYER_OAM+OAMA_TILEID
;WRAM_PLAYER_OAM_X      EQU WRAM_OAM_DMA+PLAYER_OAM+OAMA_X
;WRAM_PLAYER_OAM_Y      EQU WRAM_OAM_DMA+PLAYER_OAM+OAMA_Y
;WRAM_PLAYER_OAM_FLAGS  EQU WRAM_OAM_DMA+PLAYER_OAM+OAMA_FLAGS
;
;; Target sprite position in OAM DMA memory
;WRAM_TARGET_OAM_TILEID EQU WRAM_OAM_DMA+TARGET_OAM+OAMA_TILEID
;WRAM_TARGET_OAM_X      EQU WRAM_OAM_DMA+TARGET_OAM+OAMA_X
;WRAM_TARGET_OAM_Y      EQU WRAM_OAM_DMA+TARGET_OAM+OAMA_Y
;WRAM_TARGET_OAM_FLAGS  EQU WRAM_OAM_DMA+TARGET_OAM+OAMA_FLAGS

; --
; -- DMA SPRITES
; --
; -- We use a chunk of WRAM as a way to access OAM
SECTION "OAM DMA", WRAM0[$C100]

wram_oam_dma_start: DS 4*40
wram_oam_dma_end:

; --
; -- DMA ROUTINES
; --
SECTION "DMA Routines", ROM0

load_dma:
    ; DMA only needs to be setup once
    ; The run_dma routine must be run from HRAM
    ; so copy the routine from here to there
    ;push bc ; ...probably not needed
    ;push hl

    call clear_dma_oam 

    ld   hl, run_dma
    ld   b, end_run_dma - run_dma ; Number of bytes to copy
    ld   c, LOW(hram_oam_dma)     ; Low byte of the destination address
.copy
    ld   a, [hli]
    ldh  [c], a
    inc  c
    dec  b
    jr   nz, .copy
    ;pop  hl
    ;pop  bc
    ret

run_dma:
    ; Start the DMA transfer
    ld   a, HIGH(wram_oam_dma_start)
    ldh  [rDMA], a
    ; Delay for a total of 4x40 = 160 cycles
    ld   a, 40
.wait
    dec  a         ; 1 cycle
    jr   nz, .wait ; 3 cycles
    ret
end_run_dma:

; --
; -- Clear DMA OAM
; --
; -- Set all values in DMA OAM to 0
; --
; -- @side a, b, hl Modified
; --
clear_dma_oam:
    ld   hl, wram_oam_dma_start
    ; OAM is 40 sprites, 4 bytes each
    ld   b, OAM_COUNT * sizeof_OAM_ATTRS
    xor  a
.loop
    ldi  [hl], a
    dec  b
    jr   nz, .loop
    ret

; --
; -- HRAM OAM DMA
; --
SECTION "HRAM OAM DMA", HRAM

hram_oam_dma: ds end_run_dma - run_dma ; Reserve space to copy the routine to
