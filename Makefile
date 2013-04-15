all: DParse DParseDebug DParseUnittest

DParse: DParse.d
	dmd DParse.d

DParseDebug: DParse.d
	dmd -debug -ofDParseDebug DParse.d

DParseUnittest: DParse.d
	dmd -unittest -ofDParseUnittest DParse.d

.PHONY: clean realclean force

force:
	dmd DParse.d
	dmd -debug -ofDParseDebug DParse.d
	dmd -unittest -ofDParseUnittest DParse.d

clean:
	-rm DParse.o
	-rm DParseDebug.o
	-rm DParseUnittest.o

realclean: clean
	-rm DParse
	-rm DParseDebug
	-rm DParseUnittest
