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
