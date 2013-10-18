import std.stdio;
import std.string;
import ast2;

enum TRACK_TYPE {ON_RESULT, ON_SUCCESS, ON_FAILURE};

// Reimplementation of icmp to overcome shortcomings
// on phobos icmp (known worse performance in favor
// of pedantic correctness -> phobos uni.d)
int icmp_internal(S1)(const S1 str1, const S1 str2) pure nothrow
{
    if (str1.length == 0)
    {
        return (str2.length == 0) ? 0 : -1;
    }
    else if (str2.length == 0)
    {
        return 1;
    }
    if (str1.length == str2.length)
    {
        for (uint i = 0; i < str1.length; i++)
        {
            if (str1[i] == str2[i])
            {
            }
            else if (str1[i] < str2[i])
            {
                return -1;
            }
            else
            {
                return 1;
            }
        }
        return 0;
    }
    else if (str1.length < str2.length)
    {
        for (uint i = 0; i < str1.length; i++)
        {
            if (str1[i] == str2[i])
            {
            }
            else if (str1[i] < str2[i])
            {
                return -1;
            }
            else
            {
                return 1;
            }
        }
        return -1;
    }
    else
    {
        for (uint i = 0; i < str2.length; i++)
        {
            if (str1[i] == str2[i])
            {
            }
            else if (str1[i] < str2[i])
            {
                return -1;
            }
            else
            {
                return 1;
            }
        }
        return 1;
    }
}

version (PARSETREE)
string trimWhitespace(in string input) pure
{
    if (input.length == 0)
    {
        return input.idup;
    }
    auto start = 0;
    auto end = (input.length == 0) ? 0 : input.length - 1;
    while (start < input.length && inPattern(input[start], " \t\r\n"))
    {
        start++;
    }
    while (end >= 0 && inPattern(input[end], " \t\r\n"))
    {
        end--;
    }
    if (start > end)
    {
        return "".idup;
    }
    return input[start..end+1];
}

version (PARSETREE)
struct ParseTreeNode
{
    string ruleName;
    string[] captures;

    size_t startSrcIndex;
    size_t endSrcIndex;

    ParseTreeNode[] children;

    static string source;

    this(string ruleName, size_t startSrcIndex)
    {
        this.ruleName = ruleName;
        this.startSrcIndex = startSrcIndex;
    }

    static void walk(ref const(ParseTreeNode) topNode)
    {
        walk(topNode, 0);
    }

    private static void walk(ref const(ParseTreeNode) topNode, int indent)
    in
    {
        assert(ParseTreeNode.source.length >= topNode.endSrcIndex);
    }
    body
    {
        static char[] spaces(int indent)
        {
            char[] white;
            for (int i = 0; i < indent; i++)
            {
                white ~= "  ".dup;
            }
            return white;
        }
        auto whitespace = spaces(indent);
        write(whitespace, topNode.ruleName, ": ");
        writef("[%d, %d]: \"%s\": ", topNode.startSrcIndex, topNode.endSrcIndex,
            trimWhitespace(ParseTreeNode.source[
            topNode.startSrcIndex..topNode.endSrcIndex]));
        writeln(topNode.captures);
        if (topNode.children.length > 0)
        {
            writefln("%s*c", whitespace);
            for (int i = 0; i < topNode.children.length; i++)
            {
                walk(topNode.children[i], indent + 1);
            }
        }
    }
}

class PEGOp
{
    ParseEnvironment function(ParseEnvironment)[string] funcDict;
    this()
    {
        this.buildOperatorDictionary();
        this.funcDict.rehash;
    }

    void buildOperatorDictionary()
    {
        this.funcDict["?"] = &operatorZERO_OR_ONE;
        this.funcDict["*"] = &operatorZERO_OR_MORE;
        this.funcDict["+"] = &operatorONE_OR_MORE;
        this.funcDict["!"] = &operatorNOT;
        this.funcDict["&"] = &operatorAND;
        this.funcDict["|"] = &operatorOR;
        this.funcDict["||"] = &operatorOR_CHAIN;
        this.funcDict["["] = &operatorCHAR_CLASS;
        this.funcDict["("] = &operatorLEFT_PAREN;
        this.funcDict[")"] = &operatorRIGHT_PAREN;
        this.funcDict["#"] = &operatorARB_FUNC_REG;
        this.funcDict["$"] = &operatorARB_FUNC_IMM;
    }

    ParseEnvironment runOp(const ref string op, ParseEnvironment env)
    {
        auto p = (op in this.funcDict);
        if (p !is null)
        {
            return this.funcDict[op](env);
        }
        debug(BASIC)
        {
            writefln("FAILED TO FIND OP [%s] IN DICTIONARY.", op);
        }
        return env;
    }
}

class RecurseNode
{
    ParseEnvironment function(ParseEnvironment, ParseEnvironment) funcPointer;
    ParseEnvironment env;
    TRACK_TYPE trackType;

    this(ParseEnvironment
        function(ParseEnvironment, ParseEnvironment) funcPointer,
        ParseEnvironment env, TRACK_TYPE trackType)
    {
        this.funcPointer = funcPointer;
        this.trackType = trackType;
        this.env = env;
    }
}


class RecurseTracker
{
    RecurseNode[][] tracker;
    this()
    {
        this.addLevel();
    }

    this(ref RecurseTracker cpy)
    {
        this.tracker = cpy.tracker.dup;
    }

    void addLevel()
    {
        this.tracker.length++;
    }

    void removeLevel()
    {
        this.tracker.length--;
    }

    void addListener(ParseEnvironment
        function(ParseEnvironment, ParseEnvironment) funcPointer,
        ParseEnvironment env, TRACK_TYPE trackType)
    {
        this.tracker[$-1].length++;
        this.tracker[$-1][$-1] = new RecurseNode(funcPointer, env, trackType);
    }

    void evalLastListener(ParseEnvironment env)
    {
        debug(BASIC)
        {
            writeln("evalLastListener entered");
        }
        foreach (RecurseNode entry; this.tracker[$ - 1])
        {
            debug(BASIC)
            {
                writeln("  env sourceIndex: ", entry.env.sourceIndex);
            }
            if (env.status && (entry.trackType == TRACK_TYPE.ON_RESULT ||
                entry.trackType == TRACK_TYPE.ON_SUCCESS))
            {
                entry.funcPointer(env, entry.env);
                break;
            }
            else if (!env.status && (entry.trackType == TRACK_TYPE.ON_RESULT ||
                entry.trackType == TRACK_TYPE.ON_FAILURE))
            {
                entry.funcPointer(env, entry.env);
                break;
            }
        }
        debug(BASIC)
        {
            writeln("Tracker before: ", this.tracker);
        }
        if (this.tracker[$-1].length > 0)
        {
            debug(BASIC)
            {
                writeln("  Func: ", this.tracker[$-1][$-1].funcPointer);
            }
            this.tracker[$ - 1] = this.tracker[$ - 1][0..$ - 1];
        }
        debug(BASIC)
        {
            writeln("Tracker after: ", this.tracker);
        }
        if (this.tracker[$-1].length > 0)
        {
            debug(BASIC)
            {
                writeln("  Func: ", this.tracker[$-1][$-1].funcPointer);
            }
        }
    }
}

struct RuleReturn
{
    this(int whichRule, int ruleIndex)
    {
        this.whichRule = whichRule;
        this.ruleIndex = ruleIndex;
    }
    int whichRule;
    int ruleIndex;
}

class ParseEnvironment
{
    bool status;
    int sourceIndex;
    int ruleIndex;
    int whichRule;
    bool checkQueue;
    string source;
    string[][] rules;
    RecurseTracker recurseTracker;
    long recursionLevel;
    PEGOp ops;
    RuleReturn[] ruleRecurseList;
    string[] startParen;
    static ParseEnvironment
        function(ParseEnvironment, ParseEnvironment)[string] arbFuncs;
    static ParseEnvironment function(ParseEnvironment)[string] immFuncs;

    version (PARSETREE)
    {
        package static Stack!(ParseTreeNode) parseTreeStack;
        ParseTreeNode parseTree;
    }

    this()
    {
        this.status = true;
        this.sourceIndex = 0;
        this.ruleIndex = 2;
        this.whichRule = 0;
        this.recurseTracker = new RecurseTracker();
        this.checkQueue = false;
        this.startParen = ["(".idup, "[".idup, "{".idup, "<".idup];
        this.recursionLevel = 0;

        alias ASTGen.ElementT!("NumASTNode") NumASTNode;
        alias ASTGen.ElementT!("OpASTNode") OpASTNode;
        alias ASTGen.ElementT!("VarASTNode") VarASTNode;
        alias ASTGen.ElementT!("KeywordASTNode") KeywordASTNode;
        alias ASTGen.ListTemplate!("ParameterList") ParameterList;
        alias ASTGen.ListTemplate!("AttributeList") AttributeList;
        alias ASTGen.ListTemplate!("StatementList") StatementList;
        alias ASTGen.VariadicT!("BinOpASTNode", ASTNode,
            OpASTNode.OpASTNode, ASTNode) BinOpASTNode;
        alias ASTGen.VariadicT!("FuncSigASTNode",
            AttributeList.AttributeList, VarASTNode.VarASTNode,
            ParameterList.ParameterList) FuncSigASTNode;
        alias ASTGen.VariadicT!("FunctionDef", FuncSigASTNode.FuncSigASTNode,
            StatementList.StatementList) FunctionDef;
        alias ASTGen.VariadicT!("NumOpNum",
            NumASTNode.NumASTNode, OpASTNode.OpASTNode, NumASTNode.NumASTNode)
            NumOpNum;

        this.arbFuncs["numCapt"] = &NumASTNode.captFunc;
        this.arbFuncs["opCapt"] = &OpASTNode.captFunc;
        this.arbFuncs["varCapt"] = &VarASTNode.captFunc;
        this.arbFuncs["keywordCapt"] = &KeywordASTNode.captFunc;

        this.immFuncs["binOp"] = &BinOpASTNode.variadicFunc;
        this.immFuncs["funcSig"] = &FuncSigASTNode.variadicFunc;
        this.immFuncs["root"] = &ASTGen.rootFunc;
        this.immFuncs["paramToken"] = &ParameterList.tokenNodeFunc;
        this.immFuncs["paramList"] = &ParameterList.listGenFunc;
        this.immFuncs["attribToken"] = &AttributeList.tokenNodeFunc;
        this.immFuncs["attribList"] = &AttributeList.listGenFunc;
        this.immFuncs["statementToken"] = &StatementList.tokenNodeFunc;
        this.immFuncs["statementList"] = &StatementList.listGenFunc;
        this.immFuncs["funcDef"] = &FunctionDef.variadicFunc;
        this.immFuncs["numOpNum"] = &NumOpNum.variadicFunc;


        this.arbFuncs.rehash;
        this.immFuncs.rehash;

        version (PARSETREE)
        {
            parseTreeStack = new Stack!(ParseTreeNode)();
        }
    }

    this(ref ParseEnvironment cpy)
    {
        this.status = cpy.status;
        this.sourceIndex = cpy.sourceIndex;
        this.ruleIndex = cpy.ruleIndex;
        this.whichRule = cpy.whichRule;
        this.checkQueue = cpy.checkQueue;
        this.source = cpy.source;

        this.rules = cpy.rules;

        this.recurseTracker = new RecurseTracker(cpy.recurseTracker);
        this.ops = cpy.ops;
        this.ruleRecurseList = cpy.ruleRecurseList.dup;
        this.startParen = cpy.startParen;
        this.recursionLevel = cpy.recursionLevel;
    }

    void evaluateQueue()
    {
        debug(BASIC)
        {
            writeln("evaluateQueue entered");
        }
        this.checkQueue = false;
        this.recurseTracker.evalLastListener(this);
    }

    void setSource(string source)
    {
        this.source = source;
        version (PARSETREE)
        {
            ParseTreeNode.source = source;
        }
    }

    void setRules(string[][] rules)
    {
        this.rules = rules;
    }

    void printSelf()
    {
        // Determine the line number and column that the current source index
        // is sitting on, and then print this out down the road
        auto line = 1;
        for (auto i = 0; i < source[0..this.sourceIndex].length; i++)
        {
            if (source[i] == '\n')
            {
                line++;
            }
        }
        auto column =
            this.sourceIndex - source[0..this.sourceIndex].lastIndexOf('\n');
        if (column < 0)
        {
            column = this.sourceIndex + 1;
        }
        writeln();
        writeln("ENV PRINT:");
        writefln("  status: %s", this.status);
        writef("  sourceIndex: %d (of %d)", this.sourceIndex,
            this.source.length - 1);
        // Give a small window into the source, where the middle character in
        // the bracketed section is the one we are currently sitting on
        if ( this.sourceIndex >= 3 &&
            this.sourceIndex <= this.source.length - 4)
        {
            writefln(" Context: [%s]",
                this.source[this.sourceIndex - 3..this.sourceIndex + 4]);
        }
        else if (this.sourceIndex <= 6)
        {
            writefln(" Context: [%s]",
                this.source[0..($ <= 6) ? $ : 6]);
        }
        else if (this.sourceIndex >= this.source.length - 7)
        {
            writefln(" Context: [%s]",
                this.source[($ - ($ > 7) ? 7 : $)..$]);
        }
        else
        {
            writeln();
        }
        writefln("  Line: %d, Column: %d", line, column);
        writefln("  ruleIndex: %d (of %d)", this.ruleIndex,
            this.rules[this.whichRule].length);
        writefln("  whichRule: %d", this.whichRule);
        writefln("  rules [current]: %s", this.rules[this.whichRule]);
        //writefln("  source: %s", this.source);
        writeln("  recurseTracker: ", this.recurseTracker.tracker);
        writeln("  recursionLevel: ", this.recursionLevel);
        writeln("ENV PRINT END");
        writeln();
    }

    bool ruleRecurse(const ref string ruleName)
    {
        debug(BASIC)
        {
            writefln("Rule recurse entered, searching for [%s] in:", ruleName);
            for (int i = 0; i < this.rules.length; i++)
            {
                writeln("  ", this.rules[i][0]);
            }
        }
        for (auto i = 0; i < this.rules.length; i++)
        {
            if (icmp_internal!string(ruleName, this.rules[i][0]) == 0)
            {
                // We are in a fail state, so don't recurse
                if (!this.status)
                {
                    this.ruleIndex++;
                    return true;
                }
                version (PARSETREE)
                {
                    parseTreeStack.push(ParseTreeNode(rules[whichRule][0],
                        sourceIndex));
                }

                this.recurseTracker.addLevel();
                this.ruleRecurseList.length++;
                this.ruleRecurseList[$ - 1] = RuleReturn(
                    this.whichRule, this.ruleIndex);
                this.whichRule = i;
                this.ruleIndex = 2;
                this.lowerRecursionLevel();
                debug(BASIC)
                {
                    writeln("RECURSING ON RULE: ", this.rules[i][0]);
                }
                return true;
            }
        }
        return false;
    }

    bool isStartParen(const ref string start) pure
    {
        for (int i = 0; i < this.startParen.length; i++)
        {
            if (icmp_internal!string(start, this.startParen[i]) == 0)
            {
                return true;
            }
        }
        return false;
    }

    int matchParen(int index)
    {
        debug(BASIC)
        {
            writeln("matchParen() entered");
        }
        debug(BASIC)
        {
            writeln("  index in: ", index);
        }
        if (index >= this.rules[this.whichRule].length)
        {
            return index;
        }
        if (!isStartParen(this.rules[this.whichRule][index]))
        {
            return index;
        }
        string startParen = this.rules[this.whichRule][index];
        string endParen = this.getClosing(startParen);
        index++;
        int count = 0;
        while (icmp_internal!string(this.rules[this.whichRule][index], endParen) != 0 ||
            count != 0)
        {
            if (icmp_internal!string(this.rules[this.whichRule][index], startParen) == 0)
            {
                count++;
            }
            else if (icmp_internal!string(this.rules[this.whichRule][index], endParen) == 0)
            {
                count--;
            }
            index++;
        }
        debug(BASIC)
        {
            writeln("  index out: ", index);
        }
        return index;
    }


    string getClosing(const ref string opening) pure
    {
        switch(opening)
        {
            case "(":
                return ")".idup;
            case "[":
                return "]".idup;
            case "{":
                return "}".idup;
            case "<":
                return ">".idup;
            default:
                return "".idup;
        }
        //raise Exception
    }

    void raiseRecursionLevel() pure nothrow
    {
        this.recursionLevel++;
        return;
    }

    void lowerRecursionLevel() pure nothrow
    {
        this.recursionLevel--;
        return;
    }
}


class EscapeReplacementException : Exception
{
    this(string msg)
    {
        super(msg);
    }
}

// Iterate through a string, and replace escaped characters with their
// meaning (i.e. "\n" -> '\n'), where excaped characters that do not have a
// special meaning are just replaced with themselves, sans the '\'
void replaceEscaped(ref char[] escapes)
{
    static char escapeCodes[char];
    if (escapeCodes is null)
    {
        escapeCodes['n'] = '\n';
        escapeCodes['r'] = '\r';
        escapeCodes['t'] = '\t';
        escapeCodes['f'] = '\f';
        escapeCodes['a'] = '\a';
        escapeCodes['b'] = '\b';
        escapeCodes['v'] = '\v';
        escapeCodes['s'] = ' ';
        escapeCodes['\''] = '\'';
        escapeCodes['"'] = '"';
        escapeCodes.rehash;
    }
    if (escapes.length == 1 && escapes[0] == '\\')
    {
        throw new EscapeReplacementException(
            "Error: Dangling '\\' at end of passed string!");
    }
    if (escapes.length >= 2)
    {
        if (escapes[$-1] == '\\' && escapes[$-2] != '\\')
        {
            throw new EscapeReplacementException(
                "Error: Dangling '\\' at end of passed string!");
        }
        for (int i = 0; i < escapes.length - 1; i++)
        {
            if (escapes[i] == '\\')
            {
                if (escapes[i+1] in escapeCodes)
                {
                    escapes = escapes[0..i] ~ escapeCodes[escapes[i+1]] ~
                        escapes[i+2..$];
                }
                else
                {
                    // Just replace the escaped character with itself, as it did
                    // not have any special meaning
                    escapes = escapes[0..i] ~ escapes[i+1..$];
                }
            }
        }
    }
}

// replaceEscaped() unittest
unittest
{
    writeln("replaceEscaped() unittest entered");
    char[] testStr1 = "the\\ntest".dup;
    replaceEscaped(testStr1);
    assert(icmp_internal!(char[])(testStr1, "the\ntest".dup) == 0);
    char[] testStr2 = "\\nthe\\ntest".dup;
    replaceEscaped(testStr2);
    assert(icmp_internal!(char[])(testStr2, "\nthe\ntest".dup) == 0);
    char[] testStr3 = "\\r\\n\\a\\f\\t\\b\\v\\'\\\"\'test".dup;
    replaceEscaped(testStr3);
    assert(icmp_internal!(char[])(testStr3, "\r\n\a\f\t\b\v\'\"\'test".dup) == 0);
    char[] testStr4 = "\\g\\u\\n\\l\\t\\5\\[\\-\\,\\jtest".dup;
    replaceEscaped(testStr4);
    assert(icmp_internal!(char[])(testStr4, "gu\nl\t5[-,jtest".dup) == 0);
    char[] testStr5 = "\\ntest\\n".dup;
    replaceEscaped(testStr5);
    assert(icmp_internal!(char[])(testStr5, "\ntest\n".dup) == 0);
    char[] testStr6 = "test\\n\\ttest\\\\".dup;
    replaceEscaped(testStr6);
    assert(icmp_internal!(char[])(testStr6, "test\n\ttest\\".dup) == 0);
    char[] testStr7 = "test\\n\\ttest\\".dup;
    try
    {
        replaceEscaped(testStr7);
        assert(false);
    }
    catch (EscapeReplacementException ex)
    {
    }
    char[] testStr8 = "\\".dup;
    try
    {
        replaceEscaped(testStr8);
        assert(false);
    }
    catch (EscapeReplacementException ex)
    {
    }
    char[] testStr9 = "\\\\".dup;
    replaceEscaped(testStr9);
    assert(icmp_internal!(char[])(testStr9, "\\".dup) == 0);
    writeln("replaceEscaped() unittest PASSED.");
}

// FIXME: Check to see if we are or even need to check env.status before we
// do this stuff.
// This function matches and consumes a token, and then consumes all whitespace
// in the source up until the next non-whitespace character
ParseEnvironment operatorSTRING_MATCH_DOUBLE_QUOTE(ParseEnvironment env)
{
    debug(BASIC)
    {
        writeln("operatorSTRING_MATCH_DOUBLE_QUOTE entered");
    }
    if (!env.status)
    {
        env.ruleIndex++;
        return env;
    }
    // Pull out the characters in between the quotes, so this grabs 'the' from
    // '"the"'
    char[] stringMatch = env.rules[env.whichRule][env.ruleIndex][1..$ - 1].dup;
    // Now, we need to replace escaped characters with their representation
    replaceEscaped(stringMatch);
    // Automatic failure if the source index is out of bounds of the source
    // itself, or if the length of the string we're matching is too long to
    // fit in what's left of the source
    if (env.sourceIndex >= env.source.length ||
        stringMatch.length > env.source[env.sourceIndex..$].length)
    {
        debug(BASIC)
        {
            writeln("operatorSTRING_MATCH_DOUBLE_QUOTE fail out");
        }
        // Special case, don't fail if '""' is the string to match
        if (stringMatch.length == 0)
        {
            debug(BASIC)
            {
                writeln("  Just Kidding Empty String, returning with success");
            }
            env.ruleIndex++;
            env.checkQueue = true;
            return env;
        }
        env.status = false;
        env.ruleIndex++;
        env.checkQueue = true;
        return env;
    }
    //debug
    //{
    //    writeln("Before:", env.source[env.sourceIndex..$]);
    //}
    debug(BASIC)
    {
        writeln(stringMatch, " vs ",
            env.source[env.sourceIndex..env.sourceIndex + stringMatch.length]);
    }
    if (env.source[env.sourceIndex..
        env.sourceIndex + stringMatch.length] == stringMatch)
    {
        debug(BASIC)
        {
            writeln("  Match!");
        }
        env.sourceIndex += stringMatch.length;
        // Consume extra whitespace following this token
        while (env.sourceIndex < env.source.length &&
            inPattern(env.source[env.sourceIndex], " \n\t\r"))
        {
            debug(BASIC)
            {
                writefln("Source [%d]: '%c'", env.sourceIndex,
                    env.source[env.sourceIndex]);
            }
            env.sourceIndex++;
        }
        //debug
        //{
        //    writefln("Source: '%s'", env.source[env.sourceIndex..$]);
        //}
    }
    else
    {
        debug(BASIC)
        {
            writeln("  No match!");
        }
        env.status = false;
    }
    env.ruleIndex++;
    env.checkQueue = true;
    return env;
}

// This function matches and consumes a token, and then DOES NOT consume the
// following whitespace after this token, if there is any
ParseEnvironment operatorSTRING_MATCH_SINGLE_QUOTE(ParseEnvironment env)
{
    debug(BASIC)
    {
        writeln("operatorSTRING_MATCH_SINGLE_QUOTE entered");
    }
    if (!env.status)
    {
        env.ruleIndex++;
        return env;
    }
    // Pull out the characters in between the quotes, so this grabs 'the' from
    // ''the''
    char[] stringMatch = env.rules[env.whichRule][env.ruleIndex][1..$ - 1].dup;
    // Now, we need to replace escaped characters with their representation
    replaceEscaped(stringMatch);
    if (env.sourceIndex >= env.source.length ||
        stringMatch.length > env.source[env.sourceIndex..$].length)
    {
        debug(BASIC)
        {
            writeln("operatorSTRING_MATCH_SINGLE_QUOTE fail out");
        }
        env.status = false;
        env.ruleIndex++;
        env.checkQueue = true;
        return env;
    }
    //debug
    //{
    //    writeln("Before:", env.source[env.sourceIndex..$]);
    //}
    debug(BASIC)
    {
        writeln(stringMatch, " vs ",
            env.source[env.sourceIndex..env.sourceIndex + stringMatch.length]);
    }
    if (env.source[env.sourceIndex..
        env.sourceIndex + stringMatch.length] == stringMatch)
    {
        debug(BASIC)
        {
            writeln("  Match!");
        }
        env.sourceIndex += stringMatch.length;
    }
    else
    {
        debug(BASIC)
        {
            writeln("  No match!");
        }
        env.status = false;
    }
    env.ruleIndex++;
    env.checkQueue = true;
    return env;
}

ASTNode parseEntry(string[][] fileRules, string sourceIn)
{
    auto ops = new PEGOp();

    ParseEnvironment env = new ParseEnvironment();
    env.setRules(fileRules);
    env.setSource(sourceIn);

    debug(BASIC)
    {
        env.printSelf();
    }
    env.ops = ops;

    version (PARSETREE)
    {
        env.parseTreeStack.push(ParseTreeNode(env.rules[0][0],
            env.sourceIndex));
    }

    while (env.whichRule != 0 || env.ruleIndex <
        env.rules[env.whichRule].length || env.ruleRecurseList.length > 0)
    {
        debug(BASIC)
        {
            writefln("Which: %d Index: %d", env.whichRule, env.ruleIndex);
        }
        if (env.ruleIndex < env.rules[env.whichRule].length)
        {
            debug(BASIC)
            {
                writeln(env.rules[env.whichRule][env.ruleIndex]);
            }
        }
        if (env.ruleIndex == env.rules[env.whichRule].length)
        {
            debug(BASIC)
            {
                writeln("Recurse Return:");
                writeln("  From:");
                writeln("    whichRule:", env.whichRule);
                writeln("    ruleIndex:", env.ruleIndex);
            }
            version (PARSETREE)
            {
                if (env.parseTreeStack.size() > 0)
                {
                    auto parseTreeNode = env.parseTreeStack.pop();
                    if (parseTreeNode.startSrcIndex < env.sourceIndex)
                    {
                        parseTreeNode.endSrcIndex = env.sourceIndex;
                        if (env.parseTreeStack.size() > 0)
                        {
                            env.parseTreeStack.peek().children ~=
                                [parseTreeNode];
                        }
                        else
                        {
                            env.parseTreeStack.push(parseTreeNode);
                        }
                    }
                }
            }

            env.recurseTracker.removeLevel();
            RuleReturn ruleRecurseReturn = env.ruleRecurseList[$-1];
            env.ruleRecurseList = env.ruleRecurseList[0..$-1];
            env.whichRule = ruleRecurseReturn.whichRule;
            env.ruleIndex = ruleRecurseReturn.ruleIndex;
            env.checkQueue = true;
            env.ruleIndex++;
            env.raiseRecursionLevel();
            debug(BASIC)
            {
                writeln("  To:");
                writeln("    whichRule:", env.whichRule);
                writeln("    ruleIndex:", env.ruleIndex);
            }
        }
        else if (env.ruleRecurse(env.rules[env.whichRule][env.ruleIndex]))
        {
        }
        else if (env.ruleIndex < env.rules[env.whichRule].length &&
            env.rules[env.whichRule][env.ruleIndex][0] == '"' &&
            env.rules[env.whichRule][env.ruleIndex][$-1] == '"')
        {
            operatorSTRING_MATCH_DOUBLE_QUOTE(env);
        }
        else if (env.ruleIndex < env.rules[env.whichRule].length &&
            env.rules[env.whichRule][env.ruleIndex][0] == '\'' &&
            env.rules[env.whichRule][env.ruleIndex][$-1] == '\'')
        {
            operatorSTRING_MATCH_SINGLE_QUOTE(env);
        }
        else if (env.ruleIndex < env.rules[env.whichRule].length)
        {
            env = env.ops.runOp(env.rules[env.whichRule][env.ruleIndex], env);
        }
        else
        {
            debug(BASIC)
            {
                writeln("NOTHING");
            }
            writefln("ERROR: Operation not found: %s",
                env.rules[env.whichRule][env.ruleIndex]);
            writefln("  At rule: [%s], token #[%d]",
                env.rules[env.whichRule][0], env.ruleIndex);
            break;
        }
        while (env.checkQueue)
        {
            env.evaluateQueue();
        }
        debug(BASIC)
        {
            env.printSelf();
        }
    }
    debug(BASIC)
    {
        env.printSelf();
    }
    if (env.sourceIndex < env.source.length - 1)
    {
        env.status = false;
    }
    ASTNode topNode = new ASTNode();
    if (ASTGen.nodeStack !is null && ASTGen.nodeStack.size() > 0)
    {
        auto underlying = ASTGen.nodeStack.getUnderlying();
        debug(BASIC)
        {
            writeln("AST STACK DUMP START");
            foreach_reverse (node; underlying)
            {
                node.printSelf();
                writeln();
            }
            writeln("AST STACK DUMP END");
            writeln("START WALKING");
            foreach_reverse (node; underlying)
            {
                node.walk(node);
                writeln("BREAK");
            }
            writeln("END WALKING");
            writeln("FINAL TREE");
        }
        topNode = ASTGen.nodeStack.pop();
        debug(AST)
        {
            topNode.walk(topNode);
        }
    }
    version (PARSETREE)
    {
        if (env.parseTreeStack.size() == 1)
        {
            env.parseTreeStack.peek().endSrcIndex = env.sourceIndex;
        }
        foreach_reverse (node; env.parseTreeStack.getUnderlying())
        {
            node.walk(node);
        }
    }
    debug(BASIC)
    {
        writeln("Result:", env.status);
    }
    if (env.status)
    {
        return topNode;
    }
    return null;
}
















ParseEnvironment operatorOR(ParseEnvironment env)
{
    debug(BASIC)
    {
        writeln("operatorOR entered");
    }
    if (!env.status)
    {
        env.ruleIndex++;
        return env;
    }
    env.recurseTracker.addListener(&operatorOR_RESPONSE,
        new ParseEnvironment(env), TRACK_TYPE.ON_RESULT);
    env.ruleIndex++;
    return env;
}

ParseEnvironment operatorOR_CHAIN(ParseEnvironment env)
{
    debug(BASIC)
    {
        writeln("operatorOR_CHAIN entered");
    }
    env.ruleIndex++;
    return env;
}

ParseEnvironment operatorOR_RESPONSE(ParseEnvironment env,
    ParseEnvironment oldEnv)
{
    debug(BASIC)
    {
        writeln("operatorOR_RESPONSE entered");
    }

    // Remember to set status to success if in fail state in env but not oldEnv!

    if (oldEnv.status && env.status)
    {
        // Initiate skipping to the end of the chain, as we have found a subrule
        // that matches correctly
        debug(BASIC)
        {
            writeln("  OR_RESPONSE print one:",
                env.rules[env.whichRule][env.ruleIndex]);
        }
        if (icmp_internal!string(env.rules[env.whichRule][env.ruleIndex], "||".idup) == 0)
        {
            debug(BASIC)
            {
                writeln("Success and ||");
            }
            while (icmp_internal!string(env.rules[env.whichRule][env.ruleIndex], "||".idup) == 0)
            {
                auto newIndex = env.matchParen(env.ruleIndex + 1);
                if (newIndex == env.ruleIndex)
                {
                    break;
                }
                else
                {
                    env.ruleIndex = newIndex + 1;
                }
            }
            auto newIndex = env.matchParen(env.ruleIndex);
            env.ruleIndex = newIndex + 1;
        }
        else
        {
            auto newIndex = env.matchParen(env.ruleIndex);
            env.ruleIndex = newIndex + 1;
        }
    }
    else if (oldEnv.status && !env.status)
    {
        // Set up listener for next subrule, deciding on OR_RESPONSE or
        // OR_RESPONSE_FINAL depending on if we are sitting on top of an "||"
        debug(BASIC)
        {
            writeln("  OR_RESPONSE print two:",
                env.rules[env.whichRule][env.ruleIndex]);
        }
        if (icmp_internal!string(env.rules[env.whichRule][env.ruleIndex], "||".idup) == 0)
        {
            debug(BASIC)
            {
                writeln("    OR_RESPONSE print two.one");
            }
            // Reset status to success
            env.status = true;
            // Reset source index back to before the last subrule we tried
            env.sourceIndex = oldEnv.sourceIndex;
            // Set up listener.
            // FIXME: This is brutish. What we are doing is removing the last
            // listener BEFORE RecurseTracker does it automatically, then
            // ADDING two identical copies of the listener we want to add,
            // because then RecurseTracker will automatically remove one after
            // this function exits, resulting in the listener we want to add
            // being present after RecurseTracker does its work, while still
            // having removed the old listener
            env.recurseTracker.tracker[$-1] =
                env.recurseTracker.tracker[$-1][0..$-1];
            env.recurseTracker.addListener(&operatorOR_RESPONSE,
                new ParseEnvironment(env), TRACK_TYPE.ON_RESULT);
            env.recurseTracker.addListener(&operatorOR_RESPONSE,
                new ParseEnvironment(env), TRACK_TYPE.ON_RESULT);
        }
        else
        {
            debug(BASIC)
            {
                writeln("    OR_RESPONSE print two.two");
            }
            // Reset status to success
            env.status = true;
            // Reset source index back to before the last subrule we tried
            env.sourceIndex = oldEnv.sourceIndex;
            // Set up listener, choosing FINAL version as this next subrule is
            // the very last in the chain.
            // FIXME: This is brutish. What we are doing is removing the last
            // listener BEFORE RecurseTracker does it automatically, then
            // ADDING two identical copies of the listener we want to add,
            // because then RecurseTracker will automatically remove one after
            // this function exits, resulting in the listener we want to add
            // being present after RecurseTracker does its work, while still
            // having removed the old listener
            env.recurseTracker.tracker[$-1] =
                env.recurseTracker.tracker[$-1][0..$-1];
            env.recurseTracker.addListener(&operatorOR_RESPONSE_FINAL,
                new ParseEnvironment(env), TRACK_TYPE.ON_RESULT);
            env.recurseTracker.addListener(&operatorOR_RESPONSE_FINAL,
                new ParseEnvironment(env), TRACK_TYPE.ON_RESULT);
        }
    }
    else if (!oldEnv.status)
    {
        // We should just be skipping past everything because we are in a fail
        // state
        debug(BASIC)
        {
            writeln("  OR_RESPONSE print three:",
                env.rules[env.whichRule][env.ruleIndex]);
        }
    }
    return env;
}

ParseEnvironment operatorOR_RESPONSE_FINAL(ParseEnvironment env,
    ParseEnvironment oldEnv)
{
    // This function seems to just need to be a nop to perform its "function"
    debug(BASIC)
    {
        writeln("operatorOR_RESPONSE_FINAL entered");
    }
    return env;

}

ParseEnvironment operatorZERO_OR_ONE_RESPONSE(ParseEnvironment env,
    ParseEnvironment oldEnv)
{
    debug(BASIC)
    {
        writeln("operatorZERO_OR_ONE_RESPONSE entered");
    }
    if (oldEnv.status)
    {
        env.status = true;
    }
    env.checkQueue = true;
    return env;
}

ParseEnvironment operatorZERO_OR_ONE(ParseEnvironment env)
{
    debug(BASIC)
    {
        writeln("operatorZERO_OR_ONE entered");
    }
    if (!env.status)
    {
        env.ruleIndex++;
        return env;
    }
    env.recurseTracker.addListener(&operatorZERO_OR_ONE_RESPONSE,
        new ParseEnvironment(env), TRACK_TYPE.ON_RESULT);
    env.ruleIndex++;
    return env;
}

bool charClassMatch(string charClass, immutable char sourceChar) pure nothrow
{
    // Execute the character class matching algorithm. Obviously a regex
    // could be used to replace this, but the goal is no dependence on
    // non-IO-and-system libraries
    auto i = 0;
    bool isNegated = false;
    bool successfulMatch = false;
    if (charClass[0] == '^')
    {
        isNegated = true;
        i = 1;
    }
    while (i < charClass.length)
    {
        // Check if we're dealing with a character range, and ensure that if
        // the dash is at the beginning or end of the character class, that
        // it be treated like an ordinary character
        if (charClass[i] == '-' && i > 0 && i < charClass.length - 1)
        {
            // If the source char is in the character range, then break and
            // deal with the match appropriately
            if (sourceChar >= charClass[i-1] &&
                sourceChar <= charClass[i+1])
            {
                if (!isNegated)
                {
                    successfulMatch = true;
                    break;
                }
                else
                {
                    break;
                }
            }
            // Increment once here to sit on top of the rhs of the range,
            // and then increment once at the end of the loop to skip past
            // the range and get onto the next character to actually be
            // evaluated
            i++;
        }
        // If we are not dealing with a range, just test the character
        // directly
        else if (sourceChar == charClass[i])
        {
            if (!isNegated)
            {
                successfulMatch = true;
                break;
            }
            else
            {
                break;
            }
        }
        i++;
    }
    if (isNegated && i >= charClass.length)
    {
        successfulMatch = true;
    }
    return successfulMatch;
}

unittest
{
    writeln("charClassMatch() unittest entered");
    assert(charClassMatch("a-zA-Z".idup, 'a') == true);
    assert(charClassMatch("a-zA-Z".idup, 'b') == true);
    assert(charClassMatch("a-zA-Z".idup, 'm') == true);
    assert(charClassMatch("a-zA-Z".idup, 'y') == true);
    assert(charClassMatch("a-zA-Z".idup, 'z') == true);
    assert(charClassMatch("a-zA-Z".idup, 'A') == true);
    assert(charClassMatch("a-zA-Z".idup, 'B') == true);
    assert(charClassMatch("a-zA-Z".idup, 'M') == true);
    assert(charClassMatch("a-zA-Z".idup, 'Y') == true);
    assert(charClassMatch("a-zA-Z".idup, 'Z') == true);
    assert(charClassMatch("a-zA-Z".idup, ';') == false);

    // Assert to fix bug that fails to identify non-range '-' correctly
    assert(charClassMatch("+-".idup, '-') == true);
    assert(charClassMatch("-+".idup, '-') == true);
    assert(charClassMatch("-".idup, '-') == true);
    assert(charClassMatch("stuf-".idup, '-') == true);
    assert(charClassMatch("-stuf".idup, '-') == true);
    assert(charClassMatch("+-".idup, 'g') == false);
    assert(charClassMatch("-+".idup, 'g') == false);
    assert(charClassMatch("-".idup, 'g') == false);
    assert(charClassMatch("stuf-".idup, 'g') == false);
    assert(charClassMatch("-stuf".idup, 'g') == false);
    writeln("charClassMatch() unittest PASSED");
}

ParseEnvironment operatorCHAR_CLASS(ParseEnvironment env)
{
    debug(BASIC)
    {
        write("operatorCHAR_CLASS entered: ", env.status);
    }
    // Check to ensure we are still within the bounds of the source
    if (env.sourceIndex >= env.source.length)
    {
        debug(BASIC)
        {
            write("\n  operatorCHAR_CLASS fail out: out of bounds of source: ", env.status);
        }
        env.status = false;
        env.ruleIndex += 3;
        env.checkQueue = true;
        debug(BASIC)
        {
            writeln(" -> ", env.status);
        }
        return env;
    }
    // We are assuming that this character class is syntactically valid
    auto charClass = env.rules[env.whichRule][env.ruleIndex + 1][1..$ - 1].dup;
    // Replace escaped characters with their representation
    replaceEscaped(charClass);
    char sourceChar = env.source[env.sourceIndex];
    debug(BASIC)
    {
        writef("  Matching character class [%s] against character [%c]: ",
            charClass, sourceChar);
        write(env.status);
    }
    // If match was successful, then awesome, increment source index and we'll
    // move on. Otherwise, set our status to false
    if (charClassMatch(charClass.idup, sourceChar))
    {
        env.sourceIndex++;
    }
    else
    {
        env.status = false;
    }
    // Skip both the character class definition string and the ending ']'
    env.ruleIndex += 3;
    env.checkQueue = true;
    debug(BASIC)
    {
        writeln(" -> ", env.status);
    }
    return env;
}

ParseEnvironment operatorNOT(ParseEnvironment env)
{
    debug(BASIC)
    {
        writeln("operatorNOT entered");
    }
    if (!env.status)
    {
        env.ruleIndex++;
        return env;
    }
    env.recurseTracker.addListener(&operatorNOT_RESPONSE,
        new ParseEnvironment(env), TRACK_TYPE.ON_RESULT);
    env.ruleIndex++;
    return env;
}

ParseEnvironment operatorAND(ParseEnvironment env)
{
    debug(BASIC)
    {
        writeln("operatorAND entered");
    }
    if (!env.status)
    {
        env.ruleIndex++;
        return env;
    }
    env.recurseTracker.addListener(&operatorAND_RESPONSE,
        new ParseEnvironment(env), TRACK_TYPE.ON_RESULT);
    env.ruleIndex++;
    return env;
}

ParseEnvironment operatorLEFT_PAREN(ParseEnvironment env)
{
    debug(BASIC)
    {
        writeln("operatorLEFT_PAREN entered");
    }
    env.recurseTracker.addLevel();
    env.ruleIndex++;
    return env;
}

ParseEnvironment operatorRIGHT_PAREN(ParseEnvironment env)
{
    debug(BASIC)
    {
        writeln("operatorRIGHT_PAREN entered");
    }
    env.recurseTracker.removeLevel();
    env.checkQueue = true;
    env.ruleIndex++;
    return env;
}

ParseEnvironment operatorNOT_RESPONSE(ParseEnvironment env,
    ParseEnvironment oldEnv)
{
    debug(BASIC)
    {
        writeln("operatorNOT_RESPONSE entered: ", env.status);
    }
    env.status = !env.status;
    env.sourceIndex = oldEnv.sourceIndex;
    env.checkQueue = true;
    debug(BASIC)
    {
        writeln(" -> ", env.status);
    }
    return env;
}

ParseEnvironment operatorAND_RESPONSE(ParseEnvironment env,
    ParseEnvironment oldEnv)
{
    debug(BASIC)
    {
        writeln("operatorAND_RESPONSE entered");
    }
    env.sourceIndex = oldEnv.sourceIndex;
    env.checkQueue = true;
    return env;
}

ParseEnvironment operatorZERO_OR_MORE_RESPONSE(ParseEnvironment env,
    ParseEnvironment oldEnv)
{
    debug(BASIC)
    {
        writeln("operatorZERO_OR_MORE_RESPONSE entered: ", env.status);
    }
    if (env.status)
    {
        env.ruleIndex = oldEnv.ruleIndex;
    }
    else
    {
        env.status = true;
        env.sourceIndex = oldEnv.sourceIndex;
    }
    env.checkQueue = true;
    debug(BASIC)
    {
        writeln(" -> ", env.status);
    }
    return env;
}

class VarContainer
{
    static bool[] ONE_OR_MORE_RESPONSE_static_check;
    static bool reiterationOfSameExpression = false;
}

ParseEnvironment operatorONE_OR_MORE_RESPONSE(ParseEnvironment env,
    ParseEnvironment oldEnv)
{
    debug(BASIC)
    {
        writeln("operatorONE_OR_MORE_RESPONSE entered");
        writeln("  VCSize: ", VarContainer.ONE_OR_MORE_RESPONSE_static_check.length);
        writeln("  ", VarContainer.ONE_OR_MORE_RESPONSE_static_check);
        write("  ", env.status);
    }
    if (env.status)
    {
        VarContainer.ONE_OR_MORE_RESPONSE_static_check[$-1] = true;
        VarContainer.reiterationOfSameExpression = true;
        env.ruleIndex = oldEnv.ruleIndex;
        debug(BASIC)
        {
            writeln("\n  env.ruleIndex: ", env.ruleIndex);
        }
    }
    else
    {
        if (VarContainer.ONE_OR_MORE_RESPONSE_static_check[$-1])
        {
            env.status = true;
        }
        VarContainer.ONE_OR_MORE_RESPONSE_static_check =
            VarContainer.ONE_OR_MORE_RESPONSE_static_check[0..$-1];
        env.sourceIndex = oldEnv.sourceIndex;
    }
    env.checkQueue = true;
    debug(BASIC)
    {
        writeln(" -> ", env.status);
    }
    return env;
}

ParseEnvironment operatorZERO_OR_MORE(ParseEnvironment env)
{
    debug(BASIC)
    {
        writeln("operatorZERO_OR_MORE entered");
    }
    if (!env.status)
    {
        env.ruleIndex++;
        return env;
    }
    env.recurseTracker.addListener(&operatorZERO_OR_MORE_RESPONSE,
        new ParseEnvironment(env), TRACK_TYPE.ON_RESULT);
    env.ruleIndex++;
    return env;
}

ParseEnvironment operatorONE_OR_MORE(ParseEnvironment env)
{
    debug(BASIC)
    {
        writeln("operatorONE_OR_MORE entered");
    }
    if (!env.status)
    {
        env.ruleIndex++;
        return env;
    }
    if (VarContainer.reiterationOfSameExpression)
    {
        VarContainer.reiterationOfSameExpression = false;
    }
    else
    {
        VarContainer.ONE_OR_MORE_RESPONSE_static_check ~= false;
    }
    env.recurseTracker.addListener(&operatorONE_OR_MORE_RESPONSE,
        new ParseEnvironment(env), TRACK_TYPE.ON_RESULT);
    env.ruleIndex++;
    return env;
}

class UndefinedFunctionException : Exception
{
    this(string msg)
    {
        super(msg);
    }
}

ParseEnvironment operatorARB_FUNC_REG(ParseEnvironment env)
{
    debug(BASIC)
    {
        writeln("operatorARB_FUNC_REG entered");
    }
    if (!env.status)
    {
        env.ruleIndex += 2;
        return env;
    }
    env.ruleIndex++;
    debug(BASIC)
    {
        writeln("  ", env.rules[env.whichRule][env.ruleIndex]);
    }
    version (GRAMMAR_DEBUGGING)
    {
        if (env.rules[env.whichRule][env.ruleIndex] !in env.arbFuncs)
        {
            string errorMsg = std.string.format(
                "ERROR: In rule [%s], token #[%d]:" ~
                "  Capturing function [#%s] not defined.",
                env.rules[env.whichRule][0], env.ruleIndex,
                env.rules[env.whichRule][env.ruleIndex]);
            throw new UndefinedFunctionException(errorMsg);
        }
    }
    env.recurseTracker.addListener(
        env.arbFuncs[env.rules[env.whichRule][env.ruleIndex]],
        new ParseEnvironment(env), TRACK_TYPE.ON_RESULT);
    env.ruleIndex++;
    return env;
}

ParseEnvironment operatorARB_FUNC_IMM(ParseEnvironment env)
{
    debug(BASIC)
    {
        writeln("operatorARB_FUNC_IMM entered");
    }
    if (!env.status)
    {
        env.ruleIndex += 2;
        return env;
    }
    env.ruleIndex++;
    version (GRAMMAR_DEBUGGING)
    {
        if (env.rules[env.whichRule][env.ruleIndex] !in env.immFuncs)
        {
            string errorMsg = std.string.format(
                "ERROR: In rule [%s], token #[%d]:" ~
                "  Immediate function [$%s] not defined.",
                env.rules[env.whichRule][0], env.ruleIndex,
                env.rules[env.whichRule][env.ruleIndex]);
            throw new UndefinedFunctionException(errorMsg);
        }
    }
    debug(BASIC)
    {
        writefln("  Trying [%s]", env.rules[env.whichRule][env.ruleIndex]);
    }
    env.immFuncs[env.rules[env.whichRule][env.ruleIndex]](env);
    env.ruleIndex++;
    return env;
}

