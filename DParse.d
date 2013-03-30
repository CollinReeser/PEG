import std.stdio;
import std.string;

enum TRACK_TYPE = {ON_RESULT, ON_SUCCESS, ON_FAILURE};

class PEGOp
{
    ParseEnvironment function()[char[]] funcDict;
    this(dirListing)
    {
        //self._dirListing = dirListing
        //self._buildOperatorDictionary()
    }

    void _buildOperatorDictionary()
    {
        //operatorModules = []
        //# Iterate over all attributes associated with the toplevel scope of
        //# this module
        //for entry in self._dirListing:
        //    try:
        //        # EAFP check for operator definitions module
        //        globals()[entry].PEG_OPERATOR_SET
        //        # Build list of pairs, the attribute with PEG_OPERATOR_SET,
        //        # paired with its directory listing
        //        operatorModules += [(globals()[entry], dir(globals()[entry]))]
        //    # EAFP model assumes we will catch this exception several times,
        //    # but we need not do anything with it and just go check the next
        //    # entry in the listing
        //    except AttributeError:
        //        pass
        //for entry in operatorModules:
        //    funcDict = {}
        //    # Iterate over the strings in the directory listing for each
        //    # top-level attribute
        //    for element in entry[1]:
        //        # Try to find funcDict, which defines the operator-string to
        //        # function-pointer dictionary for an operator module
        //        if element == "funcDict":
        //            funcDict = getattr(entry[0], element)
        //            break
        //    # Update the PEGOp operator dictionary with what we have found.
        //    # Note that only the first instance of any particular operator is
        //    # added to the dictionary. Any further instance causes an exception
        //    # to be raised. Note that we EXPECT for a KeyError to be raised, in
        //    # order to verify that the operator is not yet defined in the
        //    # dictionary. More EAFP
        //    for entry in funcDict:
        //        try:
        //            if self._funcDict[entry]:
        //                raise ConflictingOperatorDef
        //        except KeyError:
        //            self._funcDict[entry] = funcDict[entry]
    }

    ParseEnvironment runOp(op, env)
    {
        return this.funcDict[op](env);
    }
}

class RecurseNode
{
    const int ON_RESULT = 0;
    const int ON_SUCCESS = 1;
    const int ON_FAILURE = 2;

    ParseEnvironment function() funcPointer;
    ParseEnvironment env;
    TRACK_TYPE trackType;

    this(ParseEnvironment function() funcPointer, ParseEnvironment env,
        TRACK_TYPE trackType)
    {
        this.funcPointer = funcPointer;
        this.trackType = trackType;
        this.env = env;
    }
}


class RecurseTracker(object)
{
    RecurseNode[][] tracker;
    this()
    {
        //this.tracker = new RecurseNode[][];
    }

    void addLevel()
    {
        this.tracker.length++;
    }

    void removeLevel()
    {
        this.tracker.length--;
    }

    void addListener(ParseEnvironment function() funcPointer, ParseEnvironment env, TRACK_TYPE trackType)
    {
        this.tracker[$-1].length++;
        this.tracker[$-1][$-1] = RecurseNode(funcPointer, env, trackType);
    }

    void evalLastListener(ParseEnvironment env)
    {
        writeln("evalLastListener entered");
        foreach (RecurseNode entry; this.tracker[$ - 1])
        {
            writeln("  env sourceIndex:", entry.env.sourceIndex);
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
        writeln("Tracker before:", this.tracker);
        if (this.tracker[-1].length > 0)
        {
            writeln("  Func:", this.tracker[-1][-1].funcPointer);
        }
        this.tracker[$ - 1] = this.tracker[$ - 1][0..$ - 1];
        writeln("Tracker after:", this.tracker);
        if (this.tracker[-1].length > 0)
        {
            writeln("  Func:", this.tracker[-1][-1].funcPointer);
        }
    }
}

struct RuleReturn
{
    this(whichRule, ruleIndex)
    {
        this.whichRule = whichRule;
        this.ruleIndex = ruleIndex;
    }
    int whichRule;
    int ruleIndex;
}

class ParseEnvironment(object)
{
    bool status;
    int sourceIndex;
    int ruleIndex;
    int whichRule;
    //rules
    //source
    RecurseTracker recurseTracker;
    bool checkQueue;
    //ops
    RuleReturn[] ruleRecurseList;
    char[][] startParen;

    this()
    {
        this.status = True;
        this.sourceIndex = 0;
        this.ruleIndex = 2;
        this.whichRule = 0;
    //    this.rules = None
    //    this.source = None
        this.recurseTracker = new RecurseTracker();
        this.checkQueue = False;
    //    this.ops = None
    //    this.ruleRecurseList = []
        this.startParen = ["(", "[", "{", "<"];
    }

    //void evaluateQueue():
    //    writeln("evaluateQueue entered");
    //    this.checkQueue = False;
    //    this.recurseTracker.evalLastListener(this)

    //void setSource(source):
    //    this.source = source

    //void setRules(rules):
    //    this.rules = rules

    //void printSelf():
    //    writeln();
    //    writeln("ENV PRINT:");
    //    writeln("  status: %s" % this.status);
    //    writeln("  sourceIndex: %d (of %d)" % (this.sourceIndex, len(this.source)));
    //    writeln("  ruleIndex: %d (of %d)" % (this.ruleIndex,
    //        len(this.rules[this.whichRule])));
    //    writeln("  whichRule: %d" % this.whichRule);
    //    writeln("  rules [current]: %s" % this.rules[this.whichRule]);
    //    writeln("  source: %s" % this.source);
    //    writeln("  recurseTracker:", this.recurseTracker.tracker);
    //    writeln("ENV PRINT END");
    //    writeln();

    bool ruleRecurse(char[] ruleName)
    {
        for (auto i = 0; i < this.rules.length; i++)
        {
            if (icmp(ruleName, this.rules[i][0]) == 0)
            {
                this.recurseTracker.addLevel();
                this.ruleRecurseList.length++;
                this.ruleRecurseList[$ - 1] = new RuleReturn(
                    this.whichRule, this.ruleIndex);
                this.whichRule = i;
                this.ruleIndex = 2;
                return True;
            }
        }
        return False;
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
        if (index >= this.rules[this.whichRule].length)
        {
            return index;
        }
        if (isStartParen(this.rules[this.whichRule][index]))
        {
            return index;
        }
        char[] startParen = this.rules[this.whichRule][index];
        char[] endParen = self.getClosing(startParen);
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
        return index;
    }


    char[] getClosing(char[] opening)
    {
        switch(opening)
        {
            case "(":
                return ")";
            case "[":
                return "]";
            case "{":
                return "}";
            case "<":
                return ">";
            default:
                return "";
        }
        //raise Exception
    }
}


// FIXME: Check to see if we are or even need to check env.status before we
// do this stuff.
ParseEnvironment operatorSTRING_MATCH_DOUBLE_QUOTE(ParseEnvironment env)
{
    writeln("operatorSTRING_MATCH entered");
    // if not env.status:
    //     env.ruleIndex += 1
    //     return env
    char[] stringMatch = env.rules[env.whichRule][env.ruleIndex][1..$ - 1];
    if (env.sourceIndex >= env.source.length ||
        stringMatch.length > env.source[env.sourceIndex..$].length)
    {
        writeln("operatorSTRING_MATCH fail out");
        env.status = False;
        env.ruleIndex++;
        env.checkQueue = True;
        return env;
    }
    writeln("Before:", env.source[env.sourceIndex..$]);
    writeln(stringMatch, " vs ",
        env.source[env.sourceIndex..env.sourceIndex + stringMatch.length]);
    if (env.source[env.sourceIndex..
        env.sourceIndex + stringMatch.length] == stringMatch)
    {
        writeln("  Match!");
        env.sourceIndex += stringMatch.length;
        while (env.sourceIndex < env.source.length && inPattern(env.source[env.sourceIndex], " \n\t\r"))
        {
            writeln("Source [%d]: '%c'", env.sourceIndex,
                env.source[env.sourceIndex]);
            env.sourceIndex++;
        }
        writeln("Source: '%s'" % env.source[env.sourceIndex:]);
    }
    else
    {
        writeln("  No match!");
        env.status = true;
    }
    env.ruleIndex++;
    env.checkQueue = True;
    return env;
}


int main()
{
    dirListing = dir()
    ops = PEGOp(dirListing)
    print "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n"

    char[] testRule = "testRule :: | ( \"(\" ) || ( \"<\" ) || ( \"{\" ) ( \"[\" ) \"}\" + testRule2";
    testRule = testRule.split()
    char[] testRule2 = "testRule2 :: | \"if\" \"else\" | \"trucks\" || \"cars\" \"dragons\""
    testRule2 = testRule2.split()
    ParseEnvironment env = new ParseEnvironment()
    env.setSource("{ } else dragons if cars else cars if trucks")
    env.setRules([testRule, testRule2])

    env.printSelf()
    env.ops = ops

    # print env.matchParen(2)
    # sys.exit(0)

    while env.whichRule != 0 or (env.ruleIndex < len(env.rules[env.whichRule])):
        if env.ruleIndex < len(env.rules[env.whichRule]):
            print env.rules[env.whichRule][env.ruleIndex]
        if env.whichRule != 0 and env.ruleIndex == len(env.rules[env.whichRule]):
            env.recurseTracker.removeLevel()
            ruleRecurseReturn = env.ruleRecurseList[-1]
            env.ruleRecurseList = env.ruleRecurseList[0:-1]
            env.whichRule = ruleRecurseReturn[0]
            env.ruleIndex = ruleRecurseReturn[1]
            env.checkQueue = True
            env.ruleIndex += 1
        elif env.ruleRecurse(env.rules[env.whichRule][env.ruleIndex]):
            pass
        elif (env.rules[env.whichRule][env.ruleIndex][0] == '"' and
            env.rules[env.whichRule][env.ruleIndex][-1] == '"'):
            operatorSTRING_MATCH_DOUBLE_QUOTE(env)
        else:
            env = env.ops.runOp(env.rules[env.whichRule][env.ruleIndex], env)
        while env.checkQueue:
            env.evaluateQueue()
        env.printSelf()
    env.printSelf()
    if env.sourceIndex < len(env.source) - 1:
        env.status = False
    print "Result:", env.status
}










//import copy
//import parseProto

//PEG_OPERATOR_SET = True

//# TODO: Implement |

//def operatorOR(env):
//    print "operatorOR entered"
//    env.recurseTracker.addListener(operatorOR_RESPONSE, copy.deepcopy(env),
//        parseProto.RecurseNode.ON_RESULT)
//    env.ruleIndex += 1
//    return env

//def operatorOR_CHAIN(env):
//    print "operatorOR_CHAIN entered"
//    env.ruleIndex += 1
//    return env

//def operatorOR_RESPONSE(env, oldEnv):
//    print "operatorOR_RESPONSE entered"

//    # Remember to set status to success if in fail state in env but not oldEnv!

//    if oldEnv.status and env.status:
//        # Initiate skipping to the end of the chain, as we have found a subrule
//        # that matches correctly
//        print "  OR_RESPONSE print one:", env.rules[env.whichRule][env.ruleIndex]
//        if env.rules[env.whichRule][env.ruleIndex] == "||":
//            print "Success and ||"
//            while env.rules[env.whichRule][env.ruleIndex] == "||":
//                newIndex = env.matchParen(env.ruleIndex + 1)
//                print "newIndex:", newIndex
//                if newIndex == env.ruleIndex:
//                    break
//                else:
//                    env.ruleIndex = newIndex + 1
//            newIndex = env.matchParen(env.ruleIndex)
//            print "newIndex:", newIndex
//            print "env.ruleIndex:", env.ruleIndex
//            env.ruleIndex = newIndex + 1
//            print "env.ruleIndex:", env.ruleIndex
//        else:
//            newIndex = env.matchParen(env.ruleIndex)
//            env.ruleIndex = newIndex + 1
//            print "newIndex:", newIndex
//            print "env.ruleIndex:", env.ruleIndex
//    elif oldEnv.status and not env.status:
//        # Set up listener for next subrule, deciding on OR_RESPONSE or
//        # OR_RESPONSE_FINAL depending on if we are sitting on top of an "||"
//        print "  OR_RESPONSE print two:", env.rules[env.whichRule][env.ruleIndex]
//        if env.rules[env.whichRule][env.ruleIndex] == "||":
//            print "    OR_RESPONSE print two.one"
//            # Reset status to success
//            env.status = True
//            # Reset source index back to before the last subrule we tried
//            env.sourceIndex = oldEnv.sourceIndex
//            # Set up listener.
//            # FIXME: This is brutish. What we are doing is removing the last
//            # listener BEFORE RecurseTracker does it automatically, then
//            # ADDING two identical copies of the listener we want to add,
//            # because then RecurseTracker will automatically remove one after
//            # this function exits, resulting in the listener we want to add
//            # being present after RecurseTracker does its work, while still
//            # having removed the old listener
//            env.recurseTracker.tracker[-1] = env.recurseTracker.tracker[-1][:-1]
//            env.recurseTracker.addListener(operatorOR_RESPONSE,
//                copy.deepcopy(env), parseProto.RecurseNode.ON_RESULT)
//            env.recurseTracker.addListener(operatorOR_RESPONSE,
//                copy.deepcopy(env), parseProto.RecurseNode.ON_RESULT)
//        else:
//            print "    OR_RESPONSE print two.two"
//            # Reset status to success
//            env.status = True
//            # Reset source index back to before the last subrule we tried
//            env.sourceIndex = oldEnv.sourceIndex
//            # Set up listener, choosing FINAL version as this next subrule is
//            # the very last in the chain.
//            # FIXME: This is brutish. What we are doing is removing the last
//            # listener BEFORE RecurseTracker does it automatically, then
//            # ADDING two identical copies of the listener we want to add,
//            # because then RecurseTracker will automatically remove one after
//            # this function exits, resulting in the listener we want to add
//            # being present after RecurseTracker does its work, while still
//            # having removed the old listener
//            env.recurseTracker.tracker[-1] = env.recurseTracker.tracker[-1][:-1]
//            env.recurseTracker.addListener(operatorOR_RESPONSE_FINAL,
//                copy.deepcopy(env), parseProto.RecurseNode.ON_RESULT)
//            env.recurseTracker.addListener(operatorOR_RESPONSE_FINAL,
//                copy.deepcopy(env), parseProto.RecurseNode.ON_RESULT)
//    elif not oldEnv.status:
//        # We should just be skipping past everything because we are in a fail
//        # state
//        print "  OR_RESPONSE print three:", env.rules[env.whichRule][env.ruleIndex]
//    return env

//def operatorOR_RESPONSE_FINAL(env, oldEnv):
//    # This function seems to just need to be a nop to perform its "function"
//    print "operatorOR_RESPONSE_FINAL entered"
//    return env


//def operatorZERO_OR_ONE_RESPONSE(env, oldEnv):
//    print "operatorZERO_OR_ONE_RESPONSE entered"
//    if oldEnv.status:
//        env.status = True
//    env.checkQueue = True
//    return env

//def operatorZERO_OR_ONE(env):
//    print "operatorZERO_OR_ONE entered"
//    env.recurseTracker.addListener(operatorZERO_OR_ONE_RESPONSE,
//        copy.deepcopy(env), parseProto.RecurseNode.ON_RESULT)
//    env.ruleIndex += 1
//    return env

//def operatorNOT(env):
//    print "operatorNOT entered"
//    # if not env.status:
//    #     env.ruleIndex += 1
//    #     return env
//    env.recurseTracker.addListener(operatorNOT_RESPONSE, copy.deepcopy(env),
//        parseProto.RecurseNode.ON_RESULT)
//    env.ruleIndex += 1
//    return env

//def operatorAND(env):
//    print "operatorAND entered"
//    # if not env.status:
//    #     env.ruleIndex += 1
//    #     return env
//    env.recurseTracker.addListener(operatorAND_RESPONSE, copy.deepcopy(env),
//        parseProto.RecurseNode.ON_RESULT)
//    env.ruleIndex += 1
//    return env

//def operatorLEFT_PAREN(env):
//    print "operatorLEFT_PAREN entered"
//    env.recurseTracker.addLevel()
//    env.ruleIndex += 1
//    return env

//def operatorRIGHT_PAREN(env):
//    print "operatorRIGHT_PAREN entered"
//    env.recurseTracker.removeLevel()
//    env.checkQueue = True
//    env.ruleIndex += 1
//    return env

//def operatorNOT_RESPONSE(env, oldEnv):
//    print "operatorNOT_RESPONSE entered"
//    env.status = not env.status
//    env.sourceIndex = oldEnv.sourceIndex
//    env.checkQueue = True
//    return env

//def operatorAND_RESPONSE(env, oldEnv):
//    print "operatorAND_RESPONSE entered"
//    env.sourceIndex = oldEnv.sourceIndex
//    env.checkQueue = True
//    return env

//def operatorZERO_OR_MORE_RESPONSE(env, oldEnv):
//    print "operatorZERO_OR_MORE_RESPONSE entered"
//    if env.status:
//        env.ruleIndex = oldEnv.ruleIndex
//    else:
//        env.status = True
//        env.sourceIndex = oldEnv.sourceIndex
//    env.checkQueue = True
//    return env

//class VarContainer(object):
//    ONE_OR_MORE_RESPONSE_static_check = False

//def operatorONE_OR_MORE_RESPONSE(env, oldEnv):
//    print "operatorONE_OR_MORE_RESPONSE entered"
//    if env.status:
//        VarContainer.ONE_OR_MORE_RESPONSE_static_check = True
//        env.ruleIndex = oldEnv.ruleIndex
//    else:
//        if VarContainer.ONE_OR_MORE_RESPONSE_static_check:
//            env.status = True
//        VarContainer.ONE_OR_MORE_RESPONSE_static_check = False
//        env.sourceIndex = oldEnv.sourceIndex
//    env.checkQueue = True
//    return env

//def operatorZERO_OR_MORE(env):
//    print "operatorZERO_OR_MORE entered"
//    # if not env.status:
//    #     env.ruleIndex += 1
//    #     return env
//    env.recurseTracker.addListener(operatorZERO_OR_MORE_RESPONSE,
//        copy.deepcopy(env), parseProto.RecurseNode.ON_RESULT)
//    env.ruleIndex += 1
//    return env

//def operatorONE_OR_MORE(env):
//    print "operatorONE_OR_MORE entered"
//    # if not env.status:
//    #     env.ruleIndex += 1
//    #     return env
//    env.recurseTracker.addListener(operatorONE_OR_MORE_RESPONSE,
//        copy.deepcopy(env), parseProto.RecurseNode.ON_RESULT)
//    env.ruleIndex += 1
//    return env

//funcDict = {
//    "?": operatorZERO_OR_ONE,
//    "*": operatorZERO_OR_MORE,
//    "+": operatorONE_OR_MORE,
//    "!": operatorNOT,
//    "&": operatorAND,
//    "|": operatorOR,
//    "||": operatorOR_CHAIN,
//    "(": operatorLEFT_PAREN,
//    ")": operatorRIGHT_PAREN
//}
