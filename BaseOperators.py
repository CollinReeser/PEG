import copy
import parseProto

PEG_OPERATOR_SET = True

def decorator(func):
    print callable(func)
    return func

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

def operatorZERO_OR_MORE_RESPONSE(env, oldEnv):
    print "operatorZERO_OR_MORE_RESPONSE entered"
    if env.status:
        env.ruleIndex = oldEnv.ruleIndex
    else:
        env.status = True
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

funcDict = {
    "?": operatorZERO_OR_ONE,
    "*": operatorZERO_OR_MORE,
    "!": operatorNOT,
    "(": operatorLEFT_PAREN,
    ")": operatorRIGHT_PAREN
}