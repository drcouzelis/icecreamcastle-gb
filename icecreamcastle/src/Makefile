ROM=icecreamcastle.gb
SOURCES=main.asm
OBJECTS=$(ROM:.gb=.o)
RESOURCES=../res
MAP=$(ROM:.gb=.map)
SYMBOLS=$(ROM:.gb=.sym)

$(ROM): $(OBJECTS)
	rgblink --dmg --tiny --map $(MAP) --sym $(SYMBOLS) --output $(ROM) $(OBJECTS)
	rgbfix --validate --pad-value 0 $(ROM)

$(OBJECTS): $(SOURCES)
	rgbasm --halt-without-nop --preserve-ld -i $(RESOURCES) --output $*.o $(SOURCES)

run: $(ROM)
	sameboy $(<)

debug: $(ROM)
	bgb --rom $(<)

clean:
	$(RM) $(ROM) $(OBJECTS) $(MAP) $(SYMBOLS)
