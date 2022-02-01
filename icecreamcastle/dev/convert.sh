#!/usr/bin/env bash

# Sprites
rgbgfx --output ../resources/tiles-sprites.2bpp tiles-sprites.png 

# Background map and tiles
rgbgfx --unique-tiles --output ../resources/tiles-background.2bpp --tilemap ../resources/tilemap-level-01.map tilemap-level-01.png
