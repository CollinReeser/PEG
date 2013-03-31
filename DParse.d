import std.stdio;
import std.string;
import std.file;
import std.c.process;

enum TRACK_TYPE {ON_RESULT, ON_SUCCESS, ON_FAILURE};

class PEGOp
{
    ParseEnvironment function(ParseEnvironment)[char[]] funcDict;
    this()
    {
        this.buildOperatorDictionary();
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
        this.funcDict["("] = &operatorLEFT_PAREN;
        this.funcDict[")"] = &operatorRIGHT_PAREN;
    }

    ParseEnvironment runOp(char[] op, ParseEnvironment env)
    {
        auto p = (op in this.funcDict);
        if (p !is null)
        {
            return this.funcDict[op](env);
        }
        return env;
    }
}

class RecurseNode
{
    ParseEnvironment function(ParseEnvironment, ParseEnvironment) funcPointer;
    ParseEnvironment env;
    TRACK_TYPE trackType;

    this(ParseEnvironment function(ParseEnvironment, ParseEnvironment) funcPointer, ParseEnvironment env,
        TRACK_TYPE trackType)
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

    this(RecurseTracker cpy)
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

    void addListener(ParseEnvironment function(ParseEnvironment, ParseEnvironment) funcPointer, ParseEnvironment env, TRACK_TYPE trackType)
    {
        this.tracker[$-1].length++;
        this.tracker[$-1][$-1] = new RecurseNode(funcPointer, env, trackType);
    }

    void evalLastListener(ParseEnvironment env)
    {
        debug
        {
            writeln("evalLastListener entered");
        }
        foreach (RecurseNode entry; this.tracker[$ - 1])
        {
            debug
            {
                writeln("  env sourceIndex:", entry.env.sourceIndex);
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
        debug
        {
            writeln("Tracker before:", this.tracker);
        }
        if (this.tracker[$-1].length > 0)
        {
            debug
            {
                writeln("  Func:", this.tracker[$-1][$-1].funcPointer);
            }
            this.tracker[$ - 1] = this.tracker[$ - 1][0..$ - 1];
        }
        debug
        {
            writeln("Tracker after:", this.tracker);
        }
        if (this.tracker[$-1].length > 0)
        {
            debug
            {
                writeln("  Func:", this.tracker[$-1][$-1].funcPointer);
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
    char[] source;
    char[][][] rules;
    RecurseTracker recurseTracker;
    PEGOp ops;
    RuleReturn[] ruleRecurseList;
    char[][] startParen;

    this()
    {
        this.status = true;
        this.sourceIndex = 0;
        this.ruleIndex = 2;
        this.whichRule = 0;
        this.recurseTracker = new RecurseTracker();
        this.checkQueue = false;
        this.startParen = ["(".dup, "[".dup, "{".dup, "<".dup];
    }

    this(ParseEnvironment cpy)
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
    }

    void evaluateQueue()
    {
        debug
        {
            writeln("evaluateQueue entered");
        }
        this.checkQueue = false;
        this.recurseTracker.evalLastListener(this);
    }

    void setSource(char[] source)
    {
        this.source = source;
    }

    void setRules(char[][][] rules)
    {
        this.rules = rules;
    }

    void printSelf()
    {
        writeln();
        writeln("ENV PRINT:");
        writefln("  status: %s", this.status);
        writefln("  sourceIndex: %d (of %d)", this.sourceIndex, this.source.length);
        writefln("  ruleIndex: %d (of %d)", this.ruleIndex,
            this.rules[this.whichRule].length);
        writefln("  whichRule: %d", this.whichRule);
        writefln("  rules [current]: %s", this.rules[this.whichRule]);
        //writefln("  source: %s", this.source);
        writeln("  recurseTracker:", this.recurseTracker.tracker);
        writeln("ENV PRINT END");
        writeln();
    }

    bool ruleRecurse(char[] ruleName)
    {
        for (auto i = 0; i < this.rules.length; i++)
        {
            if (icmp(ruleName, this.rules[i][0]) == 0)
            {
                // We are in a fail state, so don't recurse
                if (!this.status)
                {
                    this.ruleIndex++;
                    return true;
                }
                this.recurseTracker.addLevel();
                this.ruleRecurseList.length++;
                this.ruleRecurseList[$ - 1] = RuleReturn(
                    this.whichRule, this.ruleIndex);
                this.whichRule = i;
                this.ruleIndex = 2;
                debug
                {
                    writeln("RECURSING ON RULE: ", this.rules[i][0]);
                }
                return true;
            }
        }
        return false;
    }

    bool isStartParen(char[] start)
    {
        for (int i = 0; i < this.startParen.length; i++)
        {
            if (icmp(start, this.startParen[i]) == 0)
            {
                return true;
            }
        }
        return false;
    }

    int matchParen(int index)
    {
        debug
        {
            writeln("matchParen() entered");
        }
        debug
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
        char[] startParen = this.rules[this.whichRule][index];
        char[] endParen = this.getClosing(startParen);
        index++;
        int count = 0;
        while (icmp(this.rules[this.whichRule][index], endParen) != 0 ||
            count != 0)
        {
            if (icmp(this.rules[this.whichRule][index], startParen) == 0)
            {
                count++;
            }
            else if (icmp(this.rules[this.whichRule][index], endParen) == 0)
            {
                count--;
            }
            index++;
        }
        debug
        {
            writeln("  index out: ", index);
        }
        return index;
    }


    char[] getClosing(char[] opening)
    {
        switch(opening)
        {
            case "(":
                return ")".dup;
            case "[":
                return "]".dup;
            case "{":
                return "}".dup;
            case "<":
                return ">".dup;
            default:
                return "".dup;
        }
        //raise Exception
    }
}


// FIXME: Check to see if we are or even need to check env.status before we
// do this stuff.
ParseEnvironment operatorSTRING_MATCH_DOUBLE_QUOTE(ParseEnvironment env)
{
    debug
    {
        writeln("operatorSTRING_MATCH entered");
    }
    if (!env.status)
    {
        env.ruleIndex++;
        return env;
    }
    char[] stringMatch = env.rules[env.whichRule][env.ruleIndex][1..$ - 1];
    if (env.sourceIndex >= env.source.length ||
        stringMatch.length > env.source[env.sourceIndex..$].length)
    {
        debug
        {
            writeln("operatorSTRING_MATCH fail out");
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
    debug
    {
        writeln(stringMatch, " vs ",
            env.source[env.sourceIndex..env.sourceIndex + stringMatch.length]);
    }
    if (env.source[env.sourceIndex..
        env.sourceIndex + stringMatch.length] == stringMatch)
    {
        debug
        {
            writeln("  Match!");
        }
        env.sourceIndex += stringMatch.length;
        while (env.sourceIndex < env.source.length &&
            inPattern(env.source[env.sourceIndex], " \n\t\r"))
        {
            debug
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
        debug
        {
            writeln("  No match!");
        }
        env.status = false;
    }
    env.ruleIndex++;
    env.checkQueue = true;
    return env;
}

char[][][] getRules(char[] ruleSource)
{
    char[][][] rules;
    auto splitSource = ruleSource.split();
    for (auto i = 0; i < splitSource.length; i++)
    {
        if (icmp(splitSource[i], ";".dup) == 0)
        {
            rules.length++;
            rules[$-1] = splitSource[0..i];
            splitSource = splitSource[i + 1..$];
            i = -1;
        }
    }
    return rules;
}

int main()
{
    //dirListing = dir()
    debug
    {
        writeln("\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n");
    }
    char[][][] fileRules;
    char[] sourceIn;
    try
    {
        char[] rulesIn = cast(char[])read("pegEx1.peg");
        fileRules = getRules(rulesIn);
        debug
        {
            writeln(fileRules);
        }
        sourceIn = cast(char[])read("srcEx1.src");
        debug
        {
            writeln(sourceIn);
        }
    }
    catch (FileException x)
    {
        debug
        {
            writeln("SHIT BROKE.");
        }
        // std.c.process
        exit(0);
    }

    //exit(0);

    auto ops = new PEGOp();

    ParseEnvironment env = new ParseEnvironment();
    env.setRules(fileRules);
    env.setSource(sourceIn);

    //char[] testRule = "testRule :: | ( \"(\" ) || ( \"<\" ) || ( \"{\" ) ( \"[\" ) \"}\" + testRule2".dup;
    //char[][] testRuleS = testRule.split();
    //char[] testRule2 = "testRule2 :: | \"if\" \"else\" | \"trucks\" || \"cars\" \"dragons\"".dup;
    //char[][] testRule2S = testRule2.split();
    //env.setSource("{ } else dragons if cars else cars if trucks".dup);
    //char[][][] ruleset;
    //ruleset.length = 2;
    //ruleset[0] = testRuleS;
    //ruleset[1] = testRule2S;
    //ParseEnvironment env = new ParseEnvironment();
    //env.setRules(ruleset);


    debug
    {
        env.printSelf();
    }
    env.ops = ops;

    // print env.matchParen(2)
    // sys.exit(0)


    // FIXME: This while ends when the toplevel rule exits, or when the source
    // has been exhausted. However, if the source is exhausted while in a
    // passing state, we will return a passing state, even if we were not also
    // at the end of the ruleset.
    while (env.whichRule != 0 || env.ruleIndex <
        env.rules[env.whichRule].length)
    {
        debug
        {
            writefln("Which: %d Index: %d", env.whichRule, env.ruleIndex);
        }
        if (env.ruleIndex < env.rules[env.whichRule].length)
        {
            debug
            {
                writeln(env.rules[env.whichRule][env.ruleIndex]);
            }
        }
        if (env.whichRule != 0 &&
            env.ruleIndex == env.rules[env.whichRule].length)
        {
            env.recurseTracker.removeLevel();
            RuleReturn ruleRecurseReturn = env.ruleRecurseList[$-1];
            env.ruleRecurseList = env.ruleRecurseList[0..$-1];
            env.whichRule = ruleRecurseReturn.whichRule;
            env.ruleIndex = ruleRecurseReturn.ruleIndex;
            env.checkQueue = true;
            env.ruleIndex++;
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
        else if (env.ruleIndex < env.rules[env.whichRule].length)
        {
            env = env.ops.runOp(env.rules[env.whichRule][env.ruleIndex], env);
        }
        while (env.checkQueue)
        {
            env.evaluateQueue();
        }
        debug
        {
            env.printSelf();
        }
    }
    debug
    {
        env.printSelf();
    }
    if (env.sourceIndex < env.source.length - 1)
    {
        env.status = false;
    }
    writeln("Result:", env.status);
    return 0;
}
















ParseEnvironment operatorOR(ParseEnvironment env)
{
    debug
    {
        writeln("operatorOR entered");
    }
    if (!env.status)
    {
        env.ruleIndex++;
        return env;
    }
    env.recurseTracker.addListener(&operatorOR_RESPONSE, new ParseEnvironment(env),
        TRACK_TYPE.ON_RESULT);
    env.ruleIndex++;
    return env;
}

ParseEnvironment operatorOR_CHAIN(ParseEnvironment env)
{
    debug
    {
        writeln("operatorOR_CHAIN entered");
    }
    env.ruleIndex++;
    return env;
}

ParseEnvironment operatorOR_RESPONSE(ParseEnvironment env, ParseEnvironment oldEnv)
{
    debug
    {
        writeln("operatorOR_RESPONSE entered");
    }

    // Remember to set status to success if in fail state in env but not oldEnv!

    if (oldEnv.status && env.status)
    {
        // Initiate skipping to the end of the chain, as we have found a subrule
        // that matches correctly
        debug
        {
            writeln("  OR_RESPONSE print one:", env.rules[env.whichRule][env.ruleIndex]);
        }
        if (icmp(env.rules[env.whichRule][env.ruleIndex], "||".dup) == 0)
        {
            debug
            {
                writeln("Success and ||");
            }
            while (icmp(env.rules[env.whichRule][env.ruleIndex], "||".dup) == 0)
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
        debug
        {
            writeln("  OR_RESPONSE print two:", env.rules[env.whichRule][env.ruleIndex]);
        }
        if (icmp(env.rules[env.whichRule][env.ruleIndex], "||".dup) == 0)
        {
            debug
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
            env.recurseTracker.tracker[$-1] = env.recurseTracker.tracker[$-1][0..$-1];
            env.recurseTracker.addListener(&operatorOR_RESPONSE,
                new ParseEnvironment(env), TRACK_TYPE.ON_RESULT);
            env.recurseTracker.addListener(&operatorOR_RESPONSE,
                new ParseEnvironment(env), TRACK_TYPE.ON_RESULT);
        }
        else
        {
            debug
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
            env.recurseTracker.tracker[$-1] = env.recurseTracker.tracker[$-1][0..$-1];
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
        debug
        {
            writeln("  OR_RESPONSE print three:", env.rules[env.whichRule][env.ruleIndex]);
        }
    }
    return env;
}

ParseEnvironment operatorOR_RESPONSE_FINAL(ParseEnvironment env, ParseEnvironment oldEnv)
{
    // This function seems to just need to be a nop to perform its "function"
    debug
    {
        writeln("operatorOR_RESPONSE_FINAL entered");
    }
    return env;

}

ParseEnvironment operatorZERO_OR_ONE_RESPONSE(ParseEnvironment env, ParseEnvironment oldEnv)
{
    debug
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
    debug
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

ParseEnvironment operatorNOT(ParseEnvironment env)
{
    debug
    {
        writeln("operatorNOT entered");
    }
    if (!env.status)
    {
        env.ruleIndex++;
        return env;
    }
    env.recurseTracker.addListener(&operatorNOT_RESPONSE, new ParseEnvironment(env),
        TRACK_TYPE.ON_RESULT);
    env.ruleIndex++;
    return env;
}

ParseEnvironment operatorAND(ParseEnvironment env)
{
    debug
    {
        writeln("operatorAND entered");
    }
    if (!env.status)
    {
        env.ruleIndex++;
        return env;
    }
    env.recurseTracker.addListener(&operatorAND_RESPONSE, new ParseEnvironment(env),
        TRACK_TYPE.ON_RESULT);
    env.ruleIndex++;
    return env;
}

ParseEnvironment operatorLEFT_PAREN(ParseEnvironment env)
{
    debug
    {
        writeln("operatorLEFT_PAREN entered");
    }
    env.recurseTracker.addLevel();
    env.ruleIndex++;
    return env;
}

ParseEnvironment operatorRIGHT_PAREN(ParseEnvironment env)
{
    debug
    {
        writeln("operatorRIGHT_PAREN entered");
    }
    env.recurseTracker.removeLevel();
    env.checkQueue = true;
    env.ruleIndex++;
    return env;
}

ParseEnvironment operatorNOT_RESPONSE(ParseEnvironment env, ParseEnvironment oldEnv)
{
    debug
    {
        writeln("operatorNOT_RESPONSE entered");
    }
    env.status = !env.status;
    env.sourceIndex = oldEnv.sourceIndex;
    env.checkQueue = true;
    return env;
}

ParseEnvironment operatorAND_RESPONSE(ParseEnvironment env, ParseEnvironment oldEnv)
{
    debug
    {
        writeln("operatorAND_RESPONSE entered");
    }
    env.sourceIndex = oldEnv.sourceIndex;
    env.checkQueue = true;
    return env;
}

ParseEnvironment operatorZERO_OR_MORE_RESPONSE(ParseEnvironment env, ParseEnvironment oldEnv)
{
    debug
    {
        writeln("operatorZERO_OR_MORE_RESPONSE entered");
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
    return env;
}

class VarContainer
{
    static bool ONE_OR_MORE_RESPONSE_static_check = false;
}

ParseEnvironment operatorONE_OR_MORE_RESPONSE(ParseEnvironment env, ParseEnvironment oldEnv)
{
    debug
    {
        writeln("operatorONE_OR_MORE_RESPONSE entered");
    }
    if (env.status)
    {
        VarContainer.ONE_OR_MORE_RESPONSE_static_check = true;
        env.ruleIndex = oldEnv.ruleIndex;
    }
    else
    {
        if (VarContainer.ONE_OR_MORE_RESPONSE_static_check)
        {
            env.status = true;
        }
        VarContainer.ONE_OR_MORE_RESPONSE_static_check = false;
        env.sourceIndex = oldEnv.sourceIndex;
    }
    env.checkQueue = true;
    return env;
}

ParseEnvironment operatorZERO_OR_MORE(ParseEnvironment env)
{
    debug
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
    debug
    {
        writeln("operatorONE_OR_MORE entered");
    }
    if (!env.status)
    {
        env.ruleIndex++;
        return env;
    }
    env.recurseTracker.addListener(&operatorONE_OR_MORE_RESPONSE,
        new ParseEnvironment(env), TRACK_TYPE.ON_RESULT);
    env.ruleIndex++;
    return env;
}
