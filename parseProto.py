import copy
import BaseOperators
import sys

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
    testRule = "* ( \"true\" \"more\" ) \"true\" ? \"more\" ! ! ! ( ! \"dragons\" \"something\" ) ? \"help\" \"the\" ? \"stuff\""
    testRule = testRule.split()
    env = ParseEnvironment()
    env.setSource("true more true more true help the")
    env.setRules([testRule])
    env.printSelf()
    while env.whichRule != 0 or (env.ruleIndex < len(env.rules[env.whichRule])):
        print env.rules[env.whichRule][env.ruleIndex]
        if (env.rules[env.whichRule][env.ruleIndex][0] == '"' and 
            env.rules[env.whichRule][env.ruleIndex][-1] == '"'):
            operatorSTRING_MATCH_DOUBLE_QUOTE(env)
        else:
            env = ops.runOp(env.rules[env.whichRule][env.ruleIndex], env)
        while env.checkQueue:
            env.evaluateQueue()
        env.printSelf()
    env.printSelf()
    print "Result:", env.status