import std.stdio;
import std.getopt;
import std.file;
import std.string;
import DParse;
import ast2;

int main(string[] argv)
{
    ASTNode tree;

    version (GRAMMAR_DEBUGGING)
    {
        string inputRuleset;
        // This ruleset should recognize valid PEG rulesets, including itself
        string[][] grammar = [
            ["top", "::", "$", "root", "\"\"", "+", "rule", "$", "foldStack"],
            ["rule", "::", "ruleName", "\"::\"", "+", "expression", "\";\"",
                "$", "foldStack"],
            ["expression", "::", "|", "orChain", "||",
                "parenEnclosedExpression", "||", "(", "operator", "expression",
                ")", "||", "charClass", "||", "literal", "||", "string", "||",
                "ASTcommand", "ruleName", "$", "foldStack"],
            ["charClass", "::", "#", "capt", "'['", "\"\"", "#", "capt", "(",
                "'\\''", "+", "(", "|", "'-'", "[",
                "'a-zA-Z0-9;:*!&+-?(){}[],@#$%'", "]", ")", "'\\''", ")",
                "\"\"", "#", "capt", "']'", "\"\""],
            ["operator", "::", "#", "capt", "(", "|", "'*'", "||", "'!'", "||",
                "'&'", "||", "'+'", "'?'", ")", "\"\""],
            ["orChain", "::", "#", "capt", "\"|\"", "expression", "*", "(", "#",
                "capt", "\"||\"", "expression", ")", "expression"],
            ["parenEnclosedExpression", "::", "#", "capt", "'('", "\"\"", "+",
                "expression", "#", "capt", "')'", "\"\""],
            ["literal", "::", "#", "capt", "(", "'\\''", "litVar", "'\\''", ")",
                "\"\""],
            ["string", "::", "#", "capt", "(", "'\\\"'", "litVar", "'\\\"'",
                ")", "\"\""],
            ["litVar", "::", "*", "(", "|", "(", "[",
                "'a-zA-Z0-9;:*!&+-?(){}[],@#$%'", "]", ")", "||", "'\\\\\\\\'",
                "||", "'\\\\\\''", "||", "'\\\\\\\"'", "||", "'\\\\'", "'|'",
                ")", "\"\""],
            ["ruleName", "::", "#", "capt", "(", "+", "(", "[", "'a-zA-Z'", "]",
                ")", ")", "\"\""],
            ["ASTcommand", "::", "#", "capt", "(", "|", "'$'", "'#'", ")",
                "\"\"", "ruleName"]
            ];

        bool verifyRuleset = false;
        getopt(argv,
            "verify",  &verifyRuleset);
    }
    if (argv.length < 3)
    {
        writeln("Please provide a ruleset and a source file.");
        return 1;
    }
    string[][] fileRules;
    string sourceIn;
    try
    {
        string rulesIn = cast(string)read(argv[1]);
        version (GRAMMAR_DEBUGGING)
        {
            inputRuleset = rulesIn;
        }
        fileRules = getRules(rulesIn);
        debug(BASIC)
        {
            writeln(fileRules);
        }
        sourceIn = cast(string)read(argv[2]);
        debug(BASIC)
        {
            writeln(sourceIn);
        }
    }
    catch (FileException x)
    {
        debug(BASIC)
        {
            writeln("ERROR: Could not read ruleset file or source file.");
        }
        return 1;
    }
    version (GRAMMAR_DEBUGGING)
    {
        if (verifyRuleset)
        {
            writeln("Verifying ruleset");
            ASTNode topnode = DParse.parseEntry(grammar, inputRuleset);
            if (topnode is null)
            {
                writefln("Ruleset [%s] is malformed: ", argv[1]);
                writeln("  See preceeding output for parse errors.");
                return 1;
            }
            else
            {
                writefln("Ruleset [%s] is well-formed.", argv[1]);
            }
            return 0;
        }
        try
        {
            tree = DParse.parseEntry(fileRules, sourceIn);
        }
        catch (UndefinedFunctionException ex)
        {
            writeln(ex);
        }
        catch (EscapeReplacementException ex)
        {
            writeln(ex);
        }
    }
    else
    {
        tree = DParse.parseEntry(fileRules, sourceIn);
    }
    if (tree !is null)
    {
        return 0;
    }
    return 1;
}

string[][] getRules(const ref string ruleSource)
{
    string[][] rules;
    auto splitSource = ruleSource.split();
    for (auto i = 0; i < splitSource.length; i++)
    {
        if (icmp(splitSource[i], ";".idup) == 0)
        {
            rules.length++;
            rules[$-1] = splitSource[0..i];
            splitSource = splitSource[i + 1..$];
            i = -1;
        }
    }
    return rules;
}
