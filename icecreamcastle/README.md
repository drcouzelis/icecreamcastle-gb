# icecreamcastle.gb

A conversion of my game [Ice Cream Castle](https://github.com/drcouzelis/pico-8), originally for the PICO-8, to the Nintendo Game Boy.

The source for this project started from the "Hello World" tutorial from ISSOtm's [GB ASM tutorial](https://eldred.fr/gb-asm-tutorial/hello-world.html).

The "hardware.inc" reference file is from [the gbdev community](https://github.com/gbdev/hardware.inc).

Some macros and other ideas are from the work of [mdsteele](https://github.com/mdsteele/big2small).

## TODO

- [x] Collision detection
  - [x] Ensure subpixels are cleared on collision
  - [ ] Change TestSpriteCollision to always check the hero
- [x] Physics / gravity
- [x] Jumping
- [ ] Change variables / fudges to words (two bytes)
- [x] Add spikes collision / death / restart
- [ ] Add laser enemies
- [ ] Add saw enemies
- [ ] Tries counter
- [ ] ...stretch goal... Level 2!
