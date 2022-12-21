#!/usr/bin/env bash

# Sprites
rgbgfx -c embedded --output ../res/tiles-sprites.2bpp tiles-sprites.png 
rgbgfx -c embedded --output ../res/tiles-numbers.2bpp tiles-numbers.png 
rgbgfx -c embedded --output ../res/tiles-playagain.2bpp tiles-playagain.png
rgbgfx -c embedded --output ../res/tiles-youdied.2bpp tiles-youdied.png
rgbgfx -c embedded --output ../res/tiles-youwin.2bpp tiles-youwin.png


# Background map and tiles
rgbgfx --unique-tiles --output ../res/tiles-background.2bpp --tilemap ../res/tilemap-level-01.map tilemap-level-01.png
