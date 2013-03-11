import copy
import parseProto

PEG_OPERATOR_SET = True

# TODO: Implement |

def operatorOR(env):
    print "operatorOR entered"
    env.recurseTracker.addListener(operatorOR_RESPONSE, copy.deepcopy(env),
        parseProto.RecurseNode.ON_RESULT)
    env.ruleIndex += 1
    return env

def operatorOR_CHAIN(env):
    print "operatorOR_CHAIN entered"
    env.ruleIndex += 1
    return env

def operatorOR_RESPONSE(env, oldEnv):
    print "operatorOR_RESPONSE entered"

    # Remember to set status to success if in fail state in env but not oldEnv!

    if oldEnv.status and env.status:
        # Initiate skipping to the end of the chain, as we have found a subrule
        # that matches correctly
        print "  OR_RESPONSE print one:", env.rules[env.whichRule][env.ruleIndex]
        if env.rules[env.whichRule][env.ruleIndex] == "||":
            pass
        else:
            pass
    elif oldEnv.status and not env.status:
        # Set up listener for next subrule, deciding on OR_RESPONSE or
        # OR_RESPONSE_FINAL depending on if we are sitting on top of an "||"
        print "  OR_RESPONSE print two:", env.rules[env.whichRule][env.ruleIndex]
        if env.rules[env.whichRule][env.ruleIndex] == "||":
            print "    OR_RESPONSE print two.one"
            # Reset status to success
            env.status = True
            # Reset source index back to before the last subrule we tried
            env.sourceIndex = oldEnv.sourceIndex
            # Set up listener.
            # FIXME: This is brutish. What we are doing is removing the last
            # listener BEFORE RecurseTracker does it automatically, then
            # ADDING two identical copies of the listener we want to add,
            # because then RecurseTracker will automatically remove one after
            # this function exits, resulting in the listener we want to add
            # being present after RecurseTracker does its work, while still
            # having removed the old listener
            env.recurseTracker.tracker[-1] = env.recurseTracker.tracker[-1][:-1]
            env.recurseTracker.addListener(operatorOR_RESPONSE,
                copy.deepcopy(env), parseProto.RecurseNode.ON_RESULT)
            env.recurseTracker.addListener(operatorOR_RESPONSE,
                copy.deepcopy(env), parseProto.RecurseNode.ON_RESULT)
        else:
            print "    OR_RESPONSE print two.two"
            # Reset status to success
            env.status = True
            # Reset source index back to before the last subrule we tried
            env.sourceIndex = oldEnv.sourceIndex
            # Set up listener, choosing FINAL version as this next subrule is
            # the very last in the chain.
            # FIXME: This is brutish. What we are doing is removing the last
            # listener BEFORE RecurseTracker does it automatically, then
            # ADDING two identical copies of the listener we want to add,
            # because then RecurseTracker will automatically remove one after
            # this function exits, resulting in the listener we want to add
            # being present after RecurseTracker does its work, while still
            # having removed the old listener
            env.recurseTracker.tracker[-1] = env.recurseTracker.tracker[-1][:-1]
            env.recurseTracker.addListener(operatorOR_RESPONSE_FINAL,
                copy.deepcopy(env), parseProto.RecurseNode.ON_RESULT)
            env.recurseTracker.addListener(operatorOR_RESPONSE_FINAL,
                copy.deepcopy(env), parseProto.RecurseNode.ON_RESULT)
    elif not oldEnv.status:
        # We should just be skipping past everything because we are in a fail
        # state
        print "  OR_RESPONSE print three:", env.rules[env.whichRule][env.ruleIndex]
    return env

def operatorOR_RESPONSE_FINAL(env, oldEnv):
    # This function seems to just need to be a nop to perform its "function"
    print "operatorOR_RESPONSE_FINAL entered"
    return env


def operatorZERO_OR_ONE_RESPONSE(env, oldEnv):
    print "operatorZERO_OR_ONE_RESPONSE entered"
    if oldEnv.status:
        env.status = True
    env.checkQueue = True
    return env

def operatorZERO_OR_ONE(env):
    print "operatorZERO_OR_ONE entered"
    env.recurseTracker.addListener(operatorZERO_OR_ONE_RESPONSE,
        copy.deepcopy(env), parseProto.RecurseNode.ON_RESULT)
    env.ruleIndex += 1
    return env

def operatorNOT(env):
    print "operatorNOT entered"
    # if not env.status:
    #     env.ruleIndex += 1
    #     return env
    env.recurseTracker.addListener(operatorNOT_RESPONSE, copy.deepcopy(env),
        parseProto.RecurseNode.ON_RESULT)
    env.ruleIndex += 1
    return env

def operatorAND(env):
    print "operatorAND entered"
    # if not env.status:
    #     env.ruleIndex += 1
    #     return env
    env.recurseTracker.addListener(operatorAND_RESPONSE, copy.deepcopy(env),
        parseProto.RecurseNode.ON_RESULT)
    env.ruleIndex += 1
    return env

def operatorLEFT_PAREN(env):
    print "operatorLEFT_PAREN entered"
    env.recurseTracker.addLevel()
    env.ruleIndex += 1
    return env

def operatorRIGHT_PAREN(env):
    print "operatorRIGHT_PAREN entered"
    env.recurseTracker.removeLevel()
    env.checkQueue = True
    env.ruleIndex += 1
    return env

def operatorNOT_RESPONSE(env, oldEnv):
    print "operatorNOT_RESPONSE entered"
    env.status = not env.status
    env.sourceIndex = oldEnv.sourceIndex
    env.checkQueue = True
    return env

def operatorAND_RESPONSE(env, oldEnv):
    print "operatorAND_RESPONSE entered"
    env.sourceIndex = oldEnv.sourceIndex
    env.checkQueue = True
    return env

def operatorZERO_OR_MORE_RESPONSE(env, oldEnv):
    print "operatorZERO_OR_MORE_RESPONSE entered"
    if env.status:
        env.ruleIndex = oldEnv.ruleIndex
    else:
        env.status = True
        env.sourceIndex = oldEnv.sourceIndex
    env.checkQueue = True
    return env

class VarContainer(object):
    ONE_OR_MORE_RESPONSE_static_check = False

def operatorONE_OR_MORE_RESPONSE(env, oldEnv):
    print "operatorONE_OR_MORE_RESPONSE entered"
    if env.status:
        VarContainer.ONE_OR_MORE_RESPONSE_static_check = True
        env.ruleIndex = oldEnv.ruleIndex
    else:
        if VarContainer.ONE_OR_MORE_RESPONSE_static_check:
            env.status = True
        VarContainer.ONE_OR_MORE_RESPONSE_static_check = False
        env.sourceIndex = oldEnv.sourceIndex
    env.checkQueue = True
    return env

def operatorZERO_OR_MORE(env):
    print "operatorZERO_OR_MORE entered"
    # if not env.status:
    #     env.ruleIndex += 1
    #     return env
    env.recurseTracker.addListener(operatorZERO_OR_MORE_RESPONSE,
        copy.deepcopy(env), parseProto.RecurseNode.ON_RESULT)
    env.ruleIndex += 1
    return env

def operatorONE_OR_MORE(env):
    print "operatorONE_OR_MORE entered"
    # if not env.status:
    #     env.ruleIndex += 1
    #     return env
    env.recurseTracker.addListener(operatorONE_OR_MORE_RESPONSE,
        copy.deepcopy(env), parseProto.RecurseNode.ON_RESULT)
    env.ruleIndex += 1
    return env

funcDict = {
    "?": operatorZERO_OR_ONE,
    "*": operatorZERO_OR_MORE,
    "+": operatorONE_OR_MORE,
    "!": operatorNOT,
    "&": operatorAND,
    "|": operatorOR,
    "||": operatorOR_CHAIN,
    "(": operatorLEFT_PAREN,
    ")": operatorRIGHT_PAREN
}
