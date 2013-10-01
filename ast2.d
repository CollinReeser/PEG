import std.stdio;
import std.random;
import std.conv;
import DParse;

class ASTNode
{
    long recursionLevel;
    string capturingRule;
    ASTNode parent;

    this()
    {
    }

    void setRecursionLevel(long recursionLevel)
    {
        this.recursionLevel = recursionLevel;
    }

    void setCapturingRule(string capturingRule)
    {
        this.capturingRule = capturingRule;
    }
}

class BinOpASTNode : ASTNode
{
    ASTNode leftTree;
    ASTNode rightTree;
    string element;

    void setLeftTree(ref ASTNode left)
    {
        this.leftTree = left;
    }

    void setRightTree(ref ASTNode right)
    {
        this.rightTree = right;
    }

    void setElement(string element)
    {
        this.element = element;
    }
}

class ElementASTNode : ASTNode {}

class NumASTNode : ElementASTNode
{
    string element;

    void setElement(string element)
    {
        this.element = element;
    }
}

class VarASTNode : ElementASTNode
{
    string element;

    void setElement(string element)
    {
        this.element = element;
    }
}

class ASTGen
{
    //static ASTNode topNode;
    //static ASTNode tempNode;
    static Stack!(ASTNode) nodeStack;

    static ParseEnvironment captNumFunc(ParseEnvironment env,
        ParseEnvironment oldEnv)
    {
        debug(BASIC)
        {
            writeln("  captNumFunc entered");
        }
        if (ASTGen.nodeStack is null)
        {
            ASTGen.nodeStack = new Stack!(ASTNode);
        }
        if (env.sourceIndex != oldEnv.sourceIndex && env.status)
        {
            debug(BASIC)
            {
                writefln("    Captured string: [%s] at recursionLevel: [%d]",
                    env.source[oldEnv.sourceIndex..env.sourceIndex],
                    env.recursionLevel);
            }
            NumASTNode newNode = new NumASTNode();
            newNode.setElement(env.source[oldEnv.sourceIndex..env.sourceIndex]);
            newNode.setRecursionLevel(env.recursionLevel);
            nodeStack.push(newNode);
        }
        return env;
    }

    static ParseEnvironment rootFunc(ParseEnvironment env)
    {
        debug(BASIC)
        {
            writeln("  rootFunc entered");
        }
        if (ASTGen.nodeStack is null)
        {
            ASTGen.nodeStack = new Stack!(ASTNode);
        }
        ASTNode newNode = new ASTNode();
        newNode.setRecursionLevel(env.recursionLevel);
        nodeStack.push(newNode);
        return env;
    }
}

class Stack(T)
{
    private T[] stack;

    this()
    {
    }

    void push(T node)
    {
        this.stack ~= node;
    }

    T pop() nothrow
    {
        if (this.stack.length > 0)
        {
            T temp = this.stack[$-1];
            this.stack = this.stack[0..$-1];
            return temp;
        }
        return null;
    }

    T peek() nothrow
    {
        if (this.stack.length > 0)
        {
            return this.stack[$-1];
        }
        return null;
    }

    auto size() pure nothrow
    {
        return this.stack.length;
    }

    auto getUnderlying() pure nothrow
    {
        return this.stack;
    }
}
