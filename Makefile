all: DParse DParseDebug DParseUnittest DParseAST

DParse: DParse.d
	dmd DParse.d

DParseDebug: DParse.d
	dmd -debug=BASIC -ofDParseDebug DParse.d

DParseAST: DParse.d
	dmd -debug=AST -ofDParseAST DParse.d

DParseUnittest: DParse.d
	dmd -unittest -ofDParseUnittest DParse.d

.PHONY: clean realclean force

force:
	dmd DParse.d
	dmd -debug=BASIC -ofDParseDebug DParse.d
	dmd -debug=AST -ofDParseAST DParse.d
	dmd -unittest -ofDParseUnittest DParse.d

clean:
	-rm DParse.o
	-rm DParseDebug.o
	-rm DParseUnittest.o
	-rm DParseAST.o

realclean: clean
	-rm DParse
	-rm DParseDebug
	-rm DParseUnittest
	-rm DParseAST
