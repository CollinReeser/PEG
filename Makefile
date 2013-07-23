all: DParse DParseDebug DParseUnittest DParseAST

DParse: main.d DParse.d ast.d
	dmd -ofDParse main.d DParse.d ast.d

DParseDebug: main.d DParse.d ast.d
	dmd -debug=BASIC -ofDParseDebug main.d DParse.d ast.d

DParseAST: main.d DParse.d ast.d
	dmd -debug=AST -debug=BASIC -ofDParseAST main.d DParse.d ast.d

DParseUnittest: main.d DParse.d ast.d
	dmd -unittest -ofDParseUnittest main.d DParse.d ast.d

.PHONY: clean realclean

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
