ROM=icecreamcastle.gb
SOURCES=main.asm dma.asm player.asm utilities.asm
OBJECTS=$(SOURCES:.asm=.o)
MAP=$(ROM:.gb=.map)
SYMBOLS=$(ROM:.gb=.sym)

$(ROM): $(OBJECTS)
	rgblink --dmg --tiny --map $(MAP) --sym $(SYMBOLS) --output $(ROM) $(OBJECTS)
	rgbfix --validate --pad-value 0 $(ROM)

main.o: $(SOURCES)
	rgbasm --halt-without-nop --preserve-ld --output $*.o $*.asm

dma.o: $(SOURCES)
	rgbasm --halt-without-nop --preserve-ld --output $*.o $*.asm

player.o: $(SOURCES)
	rgbasm --halt-without-nop --preserve-ld --output $*.o $*.asm

utilities.o: $(SOURCES)
	rgbasm --halt-without-nop --preserve-ld --output $*.o $*.asm

run: $(ROM)
	sameboy $(<)

debug: $(ROM)
	bgb --rom $(<)

clean:
	$(RM) $(ROM) $(OBJECTS) $(MAP) $(SYMBOLS)
