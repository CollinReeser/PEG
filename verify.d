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
    string rulesIn;
    string sourceIn;
    try
    {
        rulesIn = cast(string)read(argv[1]);
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
    auto status = DParse.verifyOnly(rulesIn, sourceIn);
    writeln("Status: ", status);
    return 0;
}
