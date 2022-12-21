init_level:
    ;setup level RAM variables using the current level metadata
    call init_objects
    jp game_loop




init_objects:
    ;load object_type
    ;call init_object_type_x based on object type
    ;if 'current_level_objects' not equal to 0 then jr init_objects
    ret

init_object_type_1:
    ;setup object RAM variables
    ;do any needed logic
    ret

init_object_type_2:
    ;setup object RAM variables
    ;do any needed logic
    ret

init_object_type_3:
    ;setup object RAM variables
    ;do any needed logic
    ret




game_loop:
    halt
    call handle_objects
    ;do logic
    ;...
    jr game_loop


handle_objects:
    ;setup pointer to current object_variables
    ;if object = active then
    ;    load object_type
    ;    call handle_object_type_x based on object type
    ;if NOT all level objects have been handled then jr handle_objects
    ret

handle_object_type_1:
    ;do logic
    ret

handle_object_type_2:
    ;do logic
    ret

handle_object_type_3:
    ;do logic
    ret

;-----------------------------------------------------

level_1_metadata:

db 1    ; level number
db 5    ; number of objects in level
dw      ; pointer to level tile map in ROM
db      ; etc...

level_1_objects:

;object 1
db 1    ; object type
db      ; x pos
db 	; y pos
db	; speed
db	; etc...

;object 2
db 3    ; object type
db      ; x pos
db      ; y pos
db      ; speed
db      ; etc...

;object 3
db 3    ; object type
db      ; x pos
db      ; y pos
db      ; speed
db      ; etc...

;object 4
db 2    ; object type
db      ; x pos
db      ; y pos
db      ; speed
db      ; etc...

;object 5
db 1    ; object type
db      ; x pos
db      ; y pos
db      ; speed
db      ; etc...
