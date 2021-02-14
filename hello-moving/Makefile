ROM=hello-moving.gb
SOURCES=main.asm
OBJECTS=$(SOURCES:.asm=.o)

$(ROM): $(OBJECTS)
	rgblink -o $(ROM) $(OBJECTS)
	rgbfix -p 0 $(ROM)

main.o: $(SOURCES)
	rgbasm -o $(OBJECTS) $(SOURCES)

run: $(ROM)
	sameboy $(<)
clean:
	$(RM) $(ROM) $(OBJECTS)
