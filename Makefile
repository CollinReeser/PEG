all: DParse DParseDebug DParseUnittest DParseAST

DParse: DParse.d ast.d
	dmd DParse.d ast.d

DParseDebug: DParse.d ast.d
	dmd -debug=BASIC -ofDParseDebug DParse.d ast.d

DParseAST: DParse.d ast.d
	dmd -debug=AST -ofDParseAST DParse.d ast.d

DParseUnittest: DParse.d ast.d
	dmd -unittest -ofDParseUnittest DParse.d ast.d

.PHONY: clean realclean force

force:
	dmd DParse.d ast.d
	dmd -debug=BASIC -ofDParseDebug DParse.d ast.d
	dmd -debug=AST -ofDParseAST DParse.d ast.d
	dmd -unittest -ofDParseUnittest DParse.d ast.d

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
