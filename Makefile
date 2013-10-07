all: DParse DParseDebug DParseUnittest DParseAST2 DParseProfile DParseOptimized DParseCoverage DParseTree DParseGrammarDebug

DParse: main.d DParse.d ast2.d
	dmd -ofDParse main.d DParse.d ast2.d

DParseOptimized: main.d DParse.d ast2.d
	dmd -ofDParseOptimized -O main.d DParse.d ast2.d

DParseDebug: main.d DParse.d ast2.d
	dmd -debug=AST2 -debug=BASIC -ofDParseDebug main.d DParse.d ast2.d

DParseAST2: main.d DParse.d ast2.d
	dmd -debug=AST2 -ofDParseAST2 main.d DParse.d ast2.d

DParseUnittest: main.d DParse.d ast2.d
	dmd -unittest -ofDParseUnittest main.d DParse.d ast2.d

DParseGrammarDebug: main.d DParse.d ast2.d
	dmd -version=GRAMMAR_DEBUGGING -debug=AST2 -ofDParseGrammarDebug main.d DParse.d ast2.d

DParseProfile: main.d DParse.d ast2.d
	dmd -ofDParseProfile -profile main.d DParse.d ast2.d

DParseCoverage: main.d DParse.d ast2.d
	dmd -ofDParseCoverage -cov main.d DParse.d ast2.d

DParseTree: main.d DParse.d ast2.d
	dmd -debug=AST2 -debug=BASIC -version=PARSETREE -ofDParseTree main.d DParse.d ast2.d

.PHONY: clean realclean

clean:
	-rm DParse.o
	-rm DParseDebug.o
	-rm DParseUnittest.o
	-rm DParseAST2.o
	-rm DParseGrammarDebug.o
	-rm DParseProfile.o
	-rm DParseOptimized.o
	-rm DParseCoverage.o
	-rm DParseTree.o

realclean: clean
	-rm DParse
	-rm DParseDebug
	-rm DParseUnittest
	-rm DParseAST2
	-rm DParseGrammarDebug
	-rm DParseProfile
	-rm DParseOptimized
	-rm DParseCoverage
	-rm DParseTree
