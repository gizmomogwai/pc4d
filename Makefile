SOURCES=pc/parser.d main.d

all: main
	./main

main: $(SOURCES)
	dmd -D -unittest -odout_unittest -of$@ $^

docs:
	doxygen

clean:
	rm -rf out_unittest docs
	rm main
