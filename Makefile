all: DParse DParseDebug

DParse: DParse.d
	dmd DParse.d

DParseDebug: DParse.d
	dmd -debug -ofDParseDebug DParse.d

.PHONY: clean realclean force

force:
	dmd DParse.d
	dmd -debug -ofDParseDebug DParse.d

clean:
	-rm DParse.o
	-rm DParseDebug.o

realclean: clean
	-rm DParse
	-rm DParseDebug
