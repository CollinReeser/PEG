all: DParse DParseDebug DParseUnittest DParseAST DParseGrammarDebug

DParse: main.d DParse.d ast.d
	dmd -ofDParse main.d DParse.d ast.d

DParseDebug: main.d DParse.d ast.d
	dmd -debug=AST -debug=BASIC -ofDParseDebug main.d DParse.d ast.d

DParseAST: main.d DParse.d ast.d
	dmd -debug=AST -ofDParseAST main.d DParse.d ast.d

DParseUnittest: main.d DParse.d ast.d
	dmd -unittest -ofDParseUnittest main.d DParse.d ast.d

DParseGrammarDebug: main.d DParse.d ast.d
	dmd -version=GRAMMAR_DEBUGGING -debug=AST -ofDParseGrammarDebug main.d DParse.d ast.d

.PHONY: clean realclean

clean:
	-rm DParse.o
	-rm DParseDebug.o
	-rm DParseUnittest.o
	-rm DParseAST.o
	-rm DParseGrammarDebug.o

realclean: clean
	-rm DParse
	-rm DParseDebug
	-rm DParseUnittest
	-rm DParseAST
	-rm DParseGrammarDebug
