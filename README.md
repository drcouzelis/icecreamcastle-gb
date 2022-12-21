# Ice Cream Castle GB

A tiny run-and-jump game for the Game Boy. This is my first attempt at making a Game Boy game in Assembly language. The game is a conversion of my game [Ice Cream Castle](https://github.com/drcouzelis/pico-8), originally for the PICO-8.

By tiny, I mean you can see everything the game has to offer in 15 seconds.

- The source for this project started from the "Hello World" tutorial from ISSOtm's [GB ASM tutorial](https://eldred.fr/gb-asm-tutorial/hello-world.html)
- The "hardware.inc" reference file is from [the gbdev community](https://github.com/gbdev/hardware.inc)
- Some macros and other ideas are from the work of [mdsteele](https://github.com/mdsteele/big2small)
- The sound effects were developed using the [GBSoundDemo](https://github.com/Zal0/GBSoundDemo/)

The ROM is under 32k. The game will run on actual DMG hardware.

## TODO

- [x] Collision detection
  - [x] Clear subpixels on collision
- [x] Physics / gravity
- [x] Jumping
- [x] Add spikes collision / death / restart
- [x] Add saw enemies
  - [x] Add sprite to screen
  - [x] Animation
  - [x] Movement
  - [x] Collision detection with player
  - [x] Fix speed
  - [x] ...add the second saw
- [x] Add laser enemies
- [x] Tries counter
- [x] Sound effects

## History

- 2021-01-28 Initial commit, Hello World!
- 2021-02-25 Started Ice Cream Castle code
- 2021-02-28 Added background
- 2021-03-02 Added my first sprite
- 2021-03-10 Added animated player character
- 2021-04-04 Collision detection
- 2021-04-09 Added gravity
- 2021-09-13 Can't figure out jumping, added temp jump code instead
- 2022-02-06 Spikes cause death
- 2022-02-07 Realize my art is TOO TINY to see on an actual Game Boy, consider giving up, after many months finally decide to stick to my original goal of recreating my PICO-8 game
- 2022-10-10 Added OAM DMA
- 2022-10-22 Enemies now move
- 2022-11-15 Collision with enemies complete
- 2022-12-04 Gameplay is now complete
- 2022-12-11 Added sound effects
- 2022-12-11 Final version 1.0 complete (almost 2 years)
