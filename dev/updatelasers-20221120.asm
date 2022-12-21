UpdateLasers:
    ld hl,wLasersCountdown
    dec [hl]
    ret nz
    
    ; Reset the laser countdown
    ld [hl],LASER_SPEED
    
    ; Toggle the lasers
    ld a,[wLasersEnabled]
    xor 1 ; toggle (!!! remember to init wLasersEnable with 0 !!!)
    ld [wLasersEnabled],a
    jr z,.disable_lasers

.enable_lasers
    ld bc,$5A3C ; $5A = first byte of laser tile graphics, $3C = second byte of laser tile graphics
    jr .upload_laser_VRAM

.disable_lasers
    ld bc,$0000

.upload_laser_VRAM
    ld hl,$9070 ; VRAM location of first byte of laser tile data (tile 7)

    ld a,b ; unrolled loop for speed...
    ld [hl+],a
    ld a,c
    ld [hl+],a
    ld a,b
    ld [hl+],a
    ld a,c
    ld [hl+],a
    ld a,b
    ld [hl+],a
    ld a,c
    ld [hl+],a
    ld a,b
    ld [hl+],a
    ld a,c
    ld [hl+],a
    ld a,b
    ld [hl+],a
    ld a,c
    ld [hl+],a
    ld a,b
    ld [hl+],a
    ld a,c
    ld [hl+],a
    ld a,b
    ld [hl+],a
    ld a,c
    ld [hl+],a
    ld a,b
    ld [hl+],a
    ld a,c
    ld [hl+],a
    
    ret

