all: DParse DParseDebug DParseUnittest DParseAST DParseProfile DParseOptimized DParseCoverage DParseTree

DParse: main.d DParse.d ast.d
	dmd -ofDParse main.d DParse.d ast.d

DParseOptimized: main.d DParse.d ast.d
	dmd -ofDParseOptimized -O main.d DParse.d ast.d

DParseDebug: main.d DParse.d ast.d
	dmd -debug=BASIC -ofDParseDebug main.d DParse.d ast.d

DParseAST: main.d DParse.d ast.d
	dmd -debug=AST -debug=BASIC -ofDParseAST main.d DParse.d ast.d

DParseUnittest: main.d DParse.d ast.d
	dmd -unittest -ofDParseUnittest main.d DParse.d ast.d

DParseProfile: main.d DParse.d ast.d
	dmd -ofDParseProfile -profile main.d DParse.d ast.d

DParseCoverage: main.d DParse.d ast.d
	dmd -ofDParseCoverage -cov main.d DParse.d ast.d

DParseTree: main.d DParse.d ast.d
	dmd -debug=AST -debug=BASIC -version=PARSETREE -ofDParseTree main.d DParse.d ast.d

.PHONY: clean realclean

clean:
	-rm DParse.o
	-rm DParseDebug.o
	-rm DParseUnittest.o
	-rm DParseAST.o
	-rm DParseProfile.o
	-rm DParseOptimized.o
	-rm DParseCoverage.o
	-rm DParseTree.o

realclean: clean
	-rm DParse
	-rm DParseDebug
	-rm DParseUnittest
	-rm DParseAST
	-rm DParseProfile
	-rm DParseOptimized
	-rm DParseCoverage
	-rm DParseTree
