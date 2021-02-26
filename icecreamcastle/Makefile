ROM=icecreamcastle.gb
SOURCES=main.asm
OBJECTS=$(SOURCES:.asm=.o)

$(ROM): $(OBJECTS)
	rgblink --dmg --tiny --output $(ROM) $(OBJECTS)
	rgbfix --validate --pad-value 0 $(ROM)

main.o: $(SOURCES)
	rgbasm --output $(OBJECTS) $(SOURCES)

run: $(ROM)
	sameboy $(<)
clean:
	$(RM) $(ROM) $(OBJECTS)
