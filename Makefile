all: DParse DParseDebug DParseUnittest DParseAST DParseGDC DParseGDCOptimized

DParse: main.d DParse.d ast.d
	dmd -ofDParse main.d DParse.d ast.d

DParseDebug: main.d DParse.d ast.d
	dmd -debug=BASIC -ofDParseDebug main.d DParse.d ast.d

DParseAST: main.d DParse.d ast.d
	dmd -debug=AST -debug=BASIC -ofDParseAST main.d DParse.d ast.d

DParseUnittest: main.d DParse.d ast.d
	dmd -unittest -ofDParseUnittest main.d DParse.d ast.d

DParseGDC: main.d DParse.d ast.d
	gdc -ofDParseGDC main.d DParse.d ast.d

DParseGDCOptimized: main.d DParse.d ast.d
	gdc -ofDParseGDCOptimized -O main.d DParse.d ast.d

.PHONY: clean realclean

clean:
	-rm DParse.o
	-rm DParseDebug.o
	-rm DParseUnittest.o
	-rm DParseAST.o
	-rm DParseGDC.o
	-rm DParseGDCOptimized.o

realclean: clean
	-rm DParse
	-rm DParseDebug
	-rm DParseUnittest
	-rm DParseAST
	-rm DParseGDC
	-rm DParseGDCOptimized
