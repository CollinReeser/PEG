import copy

class RecurseNode(object):
    ON_RESULT = 0
    ON_SUCCESS = 1
    ON_FAILURE = 2
    _TRACK_TYPE = [ON_RESULT, ON_SUCCESS, ON_FAILURE]
    def __init__(self, funcPointer, env, trackType):
        self.funcPointer = funcPointer
        if trackType not in RecurseNode._TRACK_TYPE:
            raise Exception("trackType not in _TRACK_TYPE")
        self.trackType = trackType
        self.env = env


class RecurseTracker(object):
    def __init__(self):
        self.tracker = [[]]

    def addLevel(self):
        self.tracker += [[]]

    def removeLevel(self):
        self.tracker = self.tracker[:-1]

    def addListener(self, funcPointer, env, trackType):
        self.tracker[-1] += [RecurseNode(funcPointer, env, trackType)]

    def evalLastListener(self, env):
        print "evalLastListener entered"
        for entry in self.tracker[-1]:
            print "  env sourceIndex:", entry.env.sourceIndex
            if env.status and entry.trackType in (
                RecurseNode.ON_RESULT, RecurseNode.ON_SUCCESS):
                entry.funcPointer(env, entry.env)
                break
            elif not env.status and entry.trackType in (
                RecurseNode.ON_RESULT, RecurseNode.ON_FAILURE):
                entry.funcPointer(env, entry.env)
                break
        self.tracker[-1] = self.tracker[-1][:-1]


class ParseEnvironment(object):
    def __init__(self):
        self.status = True
        self.sourceIndex = 0
        self.ruleIndex = 0
        self.whichRule = 0
        self.rules = None
        self.source = None
        self.recurseTracker = RecurseTracker()
        self.checkQueue = False

    def evaluateQueue(self):
        print "evaluateQueue entered"
        env.checkQueue = False
        self.recurseTracker.evalLastListener(env)

    def setSource(self, source):
        self.source = source

    def setRules(self, rules):
        self.rules = rules

    def printSelf(self):
        print
        print "ENV PRINT:"
        print "  status: %s" % self.status
        print "  sourceIndex: %d" % self.sourceIndex
        print "  ruleIndex: %d" % self.ruleIndex
        print "  whichRule: %d" % self.whichRule
        print "  rules [current]: %s" % self.rules[self.whichRule]
        print "  source: %s" % self.source
        print "  recurseTracker:", self.recurseTracker.tracker
        print "ENV PRINT END"
        print


def operatorZERO_OR_ONE(env):
    print "operatorZERO_OR_ONE entered"
    env.status = True
    env.ruleIndex += 1
    return env

def operatorZERO_OR_MORE(env):
    print "operatorZERO_OR_MORE entered"
    env.recurseTracker.addListener(operatorZERO_OR_MORE_RESPONSE, 
        copy.deepcopy(env), RecurseNode.ON_RESULT)
    env.ruleIndex += 1
    return env

def operatorNOT(env):
    print "operatorNOT entered"
    env.recurseTracker.addListener(operatorNOT_RESPONSE, copy.deepcopy(env), 
        RecurseNode.ON_RESULT)
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

def operatorSTRING_MATCH(env):
    print "operatorSTRING_MATCH entered"
    stringMatch = env.rules[env.whichRule][env.ruleIndex][1:-1]
    print stringMatch + " vs " + env.source[env.sourceIndex]
    if (env.source[env.sourceIndex] == stringMatch):
        print "  Match!"
        env.sourceIndex += 1
    else:
        print "  No match!"
        env.status = False
    env.ruleIndex += 1
    env.checkQueue = True
    return env


if __name__ == "__main__":
    funcDict = {
        "?": operatorZERO_OR_ONE,
        "*": operatorZERO_OR_MORE,
        "!": operatorNOT,
        "(": operatorLEFT_PAREN,
        ")": operatorRIGHT_PAREN
    }
    testRule = "* ( \"true\" \"more\" ) \"true\" \"more\" ? ! ! ! ( ! \"dragons\" \"something\" ) \"help\" ? \"the\""
    testRule = testRule.split()
    env = ParseEnvironment()
    env.setSource("true more true more true help the".split())
    env.setRules([testRule])
    env.printSelf()
    while env.whichRule != 0 or (env.ruleIndex < len(env.rules[env.whichRule])):
        print env.rules[env.whichRule][env.ruleIndex]
        if (env.rules[env.whichRule][env.ruleIndex][0] == '"' and 
            env.rules[env.whichRule][env.ruleIndex][-1] == '"'):
            operatorSTRING_MATCH(env)
        else:
            env = funcDict[env.rules[env.whichRule][env.ruleIndex]](env)
        while env.checkQueue:
            env.evaluateQueue()
        env.printSelf()
    env.printSelf
    print "Result:", env.status