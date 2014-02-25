import std.stdio;
import std.getopt;
import std.file;
import std.string;
import DParse;

int main(string[] argv)
{
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
    auto status = DParse.verifyOnly(fileRules, sourceIn);
    writeln("Status: ", status);
    return 0;
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
