import copy
import BaseOperators
import sys

# TODO: Do this better, use it better
class ConflictingOperatorDef(Exception):
    def __init__(self):
        pass

class PEGOp(object):

    def __init__(self, dirListing):
        self._dirListing = dirListing
        self._funcDict = {}
        self._buildOperatorDictionary()

    def _buildOperatorDictionary(self):
        operatorModules = []
        # Iterate over all attributes associated with the toplevel scope of
        # this module
        for entry in self._dirListing:
            try:
                # EAFP check for operator definitions module
                globals()[entry].PEG_OPERATOR_SET
                # Build list of pairs, the attribute with PEG_OPERATOR_SET,
                # paired with its directory listing
                operatorModules += [(globals()[entry], dir(globals()[entry]))]
            # EAFP model assumes we will catch this exception several times,
            # but we need not do anything with it and just go check the next
            # entry in the listing
            except AttributeError:
                pass
        for entry in operatorModules:
            funcDict = {}
            # Iterate over the strings in the directory listing for each
            # top-level attribute
            for element in entry[1]:
                # Try to find funcDict, which defines the operator-string to
                # function-pointer dictionary for an operator module
                if element == "funcDict":
                    funcDict = getattr(entry[0], element)
                    break
            # Update the PEGOp operator dictionary with what we have found.
            # Note that only the first instance of any particular operator is
            # added to the dictionary. Any further instance causes an exception
            # to be raised. Note that we EXPECT for a KeyError to be raised, in
            # order to verify that the operator is not yet defined in the
            # dictionary. More EAFP
            for entry in funcDict:
                try:
                    if self._funcDict[entry]:
                        raise ConflictingOperatorDef
                except KeyError:
                    self._funcDict[entry] = funcDict[entry]

    def runOp(self, op, env):
        return self._funcDict[op](env)

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
        print "Tracker before:", self.tracker
        if len(self.tracker[-1]) > 0:
            print "  Func:", self.tracker[-1][-1].funcPointer
        self.tracker[-1] = self.tracker[-1][:-1]
        print "Tracker after:", self.tracker
        if len(self.tracker[-1]) > 0:
            print "  Func:", self.tracker[-1][-1].funcPointer


class ParseEnvironment(object):
    def __init__(self):
        self.status = True
        self.sourceIndex = 0
        self.ruleIndex = 2
        self.whichRule = 0
        self.rules = None
        self.source = None
        self.recurseTracker = RecurseTracker()
        self.checkQueue = False
        self.ops = None
        self.ruleRecurseList = []
        self.startParen = ['(', '[', '{', '<']

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
        print "  sourceIndex: %d (of %d)" % (self.sourceIndex, len(self.source))
        print "  ruleIndex: %d (of %d)" % (self.ruleIndex,
            len(self.rules[self.whichRule]))
        print "  whichRule: %d" % self.whichRule
        print "  rules [current]: %s" % self.rules[self.whichRule]
        print "  source: %s" % self.source
        print "  recurseTracker:", self.recurseTracker.tracker
        print "ENV PRINT END"
        print

    def ruleRecurse(self, ruleName):
        for i in xrange(len(self.rules)):
            if ruleName == self.rules[i][0]:
                self.recurseTracker.addLevel()
                env.ruleRecurseList += [(env.whichRule, env.ruleIndex)]
                env.whichRule = i
                env.ruleIndex = 2
                return True
        return False

    def matchParen(self, index):
        if index >= len(env.rules[env.whichRule]):
            return index
        if env.rules[env.whichRule][index] not in env.startParen:
            return index
        startParen = env.rules[env.whichRule][index]
        endParen = self.getClosing(startParen)
        index += 1
        count = 0
        while env.rules[env.whichRule][index] != endParen or count != 0:
            if env.rules[env.whichRule][index] == startParen:
                count += 1
            elif env.rules[env.whichRule][index] == endParen:
                count -= 1
            index += 1
        return index


    def getClosing(self, opening):
        if opening == '(':
            return ')'
        if opening == '[':
            return ']'
        if opening == '{':
            return '}'
        if opening == '<':
            return '>'
        raise Exception


# FIXME: Check to see if we are or even need to check env.status before we
# do this stuff.
def operatorSTRING_MATCH_DOUBLE_QUOTE(env):
    print "operatorSTRING_MATCH entered"
    # if not env.status:
    #     env.ruleIndex += 1
    #     return env
    stringMatch = env.rules[env.whichRule][env.ruleIndex][1:-1]
    if (env.sourceIndex >= len(env.source) or
        len(stringMatch) > len(env.source[env.sourceIndex:])):
        print "operatorSTRING_MATCH fail out"
        env.status = False
        env.ruleIndex += 1
        env.checkQueue = True
        return env
    print "Before:", env.source[env.sourceIndex:]
    print stringMatch + " vs " + env.source[env.sourceIndex:
        env.sourceIndex + len(stringMatch)]
    if (env.source[env.sourceIndex:env.sourceIndex + len(stringMatch)] ==
        stringMatch):
        print "  Match!"
        env.sourceIndex += len(stringMatch)
        while env.sourceIndex < len(env.source) and (
            env.source[env.sourceIndex] in (' ', '\t', '\r', '\n')):
            print "Source [%d]: '%c'" % (env.sourceIndex,
                env.source[env.sourceIndex])
            env.sourceIndex += 1
        print "Source: '%s'" % env.source[env.sourceIndex:]
    else:
        print "  No match!"
        env.status = False
    env.ruleIndex += 1
    env.checkQueue = True
    return env


if __name__ == "__main__":
    dirListing = dir()
    ops = PEGOp(dirListing)
    print "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n"

    # begin = "begin :: \"(*\""
    # begin = begin.split()
    # end = "end :: \"*)\""
    # end = end.split()
    # C = "C :: begin * N end"
    # C = C.split()
    # N = "N :: C | ( ! begin ! end Z )"
    # N = N.split()
    # Z = "Z :: \"a\" | \"b\" | \"c\""
    # Z = Z.split()
    # env = ParseEnvironment()
    # env.setSource("(* which can (* nest *) like this *)")
    # env.setRules([N, C, Z, begin, end])
    # env.printSelf()

    # testRule = "testRule :: \"if\" ? \"not\" \"logic\" \"then\""
    # testRule = testRule.split()
    # testRule2 = "testRule2 :: ( ( \"{\" testRule \"}\" ) )"
    # testRule2 = testRule2.split()
    # env = ParseEnvironment()
    # env.setSource("{ if not logic then }")
    # env.setRules([testRule2, testRule])

    testRule = "testRule :: | ( \"(\" ) || ( \"<\" ) || ( \"{\" ) ( \"[\" ) \"}\" + testRule2"
    # testRule = "testRule :: | \"<\" \"{\" \"}\""
    testRule = testRule.split()
    testRule2 = "testRule2 :: | \"if\" \"else\" | \"trucks\" || \"cars\" \"dragons\""
    testRule2 = testRule2.split()
    env = ParseEnvironment()
    env.setSource("{ } else dragons if cars else cars if trucks")
    env.setRules([testRule, testRule2])

    # testRule = 'testRule :: "SELECT" * ( ! ( keywords ) ) "FROM"'
    # testRule = testRule.split()
    # keywords = 'keywords :: | "SELECT" || "FROM" "WHERE"'
    # keywords = keywords.split()
    # env = ParseEnvironment()
    # env.setSource("SELECT this FROM")
    # env.setRules([testRule, keywords])

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
