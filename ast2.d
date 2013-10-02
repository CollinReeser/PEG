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

    void walk(ref const(ASTNode) topNode)
    {
        if (topNode is null)
        {
            debug (BASIC)
            {
                writeln("Top-level walk() exiting on null node");
            }
            return;
        }
        walk(topNode, 0);
    }

    private void walk(ref const(ASTNode) topNode, int indent)
    {
        static char[] spaces(int indent)
        {
            char[] white;
            for (int i = 0; i < indent; i++)
            {
                white ~= "  ".dup;
            }
            return white;
        }
        auto whitespace = spaces(indent);
        if (topNode.parent !is null)
        {
            writefln("%s\"%s\": %d, %s%s: %d", whitespace,
                this.walkPrintElement(),
                topNode.recursionLevel,
                " Parent: ", topNode.parent.walkPrintElement(),
                topNode.parent.recursionLevel);
        }
        else
        {
            writefln("%s\"%s\": %d", whitespace, topNode.walkPrintElement(),
                topNode.recursionLevel);
        }
        const(ASTNode)[] children = topNode.getChildren();
        if (children.length > 0)
        {
            writefln("%s*c", whitespace);
            for (int i = 0; i < children.length; i++)
            {
                walk(children[i], indent + 1);
            }
        }
    }

    protected ref const(string) walkPrintElement() const nothrow
    {
        static string dummy = "NOT_AN_ELEMENT";
        return dummy;
    }

    protected const(ASTNode)[] getChildren() const nothrow
    {
        static const(ASTNode)[] dummy;
        return dummy;
    }

    void printSelf() const
    {
        writeln(this.classinfo.name);
        writefln("  Recursion Level: %d", this.recursionLevel);
        writefln("  Capturing Rule: %s", this.capturingRule);
        writefln("  Has Parent?: %s", (this.parent is null) ? "No" : "Yes");
    }
}

class BinOpASTNode : ASTNode
{
    ASTNode leftTree;
    ASTNode rightTree;
    OpASTNode op;

    void setLeftTree(ref ASTNode left)
    {
        this.leftTree = left;
    }

    void setRightTree(ref ASTNode right)
    {
        this.rightTree = right;
    }

    void setOp(ref OpASTNode op)
    {
        this.op = op;
    }

    override protected ref const(string) walkPrintElement() const nothrow
    {
        return this.op.walkPrintElement();
    }

    override protected const(ASTNode)[] getChildren() const nothrow
    {
        const(ASTNode)[] children;
        if (this.leftTree !is null)
        {
            children ~= [this.leftTree];
        }
        if (this.rightTree !is null)
        {
            children ~= [this.rightTree];
        }
        return children;
    }

    override void printSelf() const
    {
        super.printSelf();
        writefln("  Has Right Tree?: %s",
            (this.rightTree is null) ? "No" : "Yes");
        writefln("  Has Left Tree? : %s",
            (this.leftTree is null) ? "No" : "Yes");
        writefln("  Element: [%s]", this.op.walkPrintElement());
    }
}

class ElementASTNode : ASTNode
{
    string element;

    void setElement(string element)
    {
        this.element = element;
    }

    override protected ref const(string) walkPrintElement() const nothrow
    {
        return this.element;
    }

    override void printSelf() const
    {
        super.printSelf();
        writefln("  Element: [%s]", this.element);
    }
}

class NumASTNode : ElementASTNode
{
}

class VarASTNode : ElementASTNode
{
}

class OpASTNode : ElementASTNode
{
}

class ASTGen
{
    //static ASTNode topNode;
    //static ASTNode tempNode;
    static Stack!(ASTNode) nodeStack;

    //static ParseEnvironment binOpFunc(ParseEnvironment env,
    //    ParseEnvironment oldEnv)
    //{
    //    debug(BASIC)
    //    {
    //        writeln("  binOpFunc entered");
    //    }
    //    if (ASTGen.nodeStack is null)
    //    {
    //        ASTGen.nodeStack = new Stack!(ASTNode);
    //    }
    //    if (env.sourceIndex != oldEnv.sourceIndex && env.status)
    //    {
    //        debug(BASIC)
    //        {
    //        }
    //        BinOpASTNode newNode = new BinOpASTNode();
    //        newNode.setElement(env.source[oldEnv.sourceIndex..env.sourceIndex]);
    //        newNode.setRecursionLevel(env.recursionLevel);
    //        newNode.leftTree = nodeStack.pop();
    //        nodeStack.push(newNode);

    //        // See hack in DParse.operatorOR_RESPONSE()
    //        env.recurseTracker.tracker[$-1] =
    //            env.recurseTracker.tracker[$-1][0..$-1];
    //        env.recurseTracker.addListener(env.arbFuncs["binOpFollow"],
    //            new ParseEnvironment(env), TRACK_TYPE.ON_RESULT);
    //        env.recurseTracker.addListener(env.arbFuncs["binOpFollow"],
    //            new ParseEnvironment(env), TRACK_TYPE.ON_RESULT);
    //    }
    //    return env;
    //}

    static ParseEnvironment binOpFollowFunc(ParseEnvironment env,
        ParseEnvironment oldEnv)
    {
        debug(BASIC)
        {
            writeln("  binOpFollowFunc entered");
        }
        if (nodeStack is null)
        {
            nodeStack = new Stack!(ASTNode);
        }
        debug(BASIC)
        {
            writeln("    env.status: ", env.status);
            writeln("    nodeStack.size(): ", nodeStack.size());
        }
        if (env.status && nodeStack.size() > 0)
        {
            ASTNode rightTree = nodeStack.pop();
            ASTNode binOpNodeCandidate = nodeStack.pop();
            debug(BASIC)
            {
                writeln("    rightTree:");
                rightTree.printSelf();
                writeln("    binOpNodeCandidate:");
                binOpNodeCandidate.printSelf();
            }
            if (cast(BinOpASTNode)binOpNodeCandidate)
            {
                BinOpASTNode binOpNode = cast(BinOpASTNode)binOpNodeCandidate;
                binOpNode.rightTree = rightTree;
                nodeStack.push(binOpNode);
            }
            else
            {
                nodeStack.push(binOpNodeCandidate);
                nodeStack.push(rightTree);
                debug(BASIC)
                {
                    writeln("AST Stack Dump Start");
                    foreach_reverse (node; nodeStack.getUnderlying())
                    {
                        node.printSelf();
                        writeln();
                    }
                    writeln("AST Stack Dump End");
                }
                string errStr = "Error: binOpFollowFunc: ".idup;
                errStr ~= "Unexpected stack element".idup;
                throw new Exception(errStr);
            }
        }
        return env;
    }

    static ParseEnvironment captFunc(T : ElementASTNode)(ParseEnvironment env,
        ParseEnvironment oldEnv)
    {
        debug(BASIC)
        {
            writeln("  captFunc(T) entered");
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
            T newNode = new T();
            newNode.setElement(env.source[oldEnv.sourceIndex..env.sourceIndex]);
            newNode.setRecursionLevel(env.recursionLevel);
            nodeStack.push(newNode);
        }
        return env;
    }

    static ParseEnvironment binOpFunc(ParseEnvironment env)
    {
        debug(BASIC)
        {
            writeln("  binOpFunc entered");
        }
        if (ASTGen.nodeStack is null)
        {
            ASTGen.nodeStack = new Stack!(ASTNode);
        }
        if (env.status)
        {
            debug(BASIC)
            {
            }
            BinOpASTNode newNode = new BinOpASTNode();
            newNode.setRecursionLevel(env.recursionLevel);
            ASTNode opNodeCandidate = nodeStack.pop();
            if (cast(OpASTNode)opNodeCandidate)
            {
                OpASTNode opNode = cast(OpASTNode)opNodeCandidate;
                newNode.op = opNode;
            }
            else
            {
                nodeStack.push(opNodeCandidate);
                debug(BASIC)
                {
                    writeln("AST Stack Dump Start");
                    foreach_reverse (node; nodeStack.getUnderlying())
                    {
                        node.printSelf();
                        writeln();
                    }
                    writeln("AST Stack Dump End");
                }
                string errStr = "Error: binOpFunc: ".idup;
                errStr ~= "Unexpected stack element".idup;
                throw new Exception(errStr);
            }
            newNode.leftTree = nodeStack.pop();
            nodeStack.push(newNode);

            // See hack in DParse.operatorOR_RESPONSE()

            env.recurseTracker.addListener(env.arbFuncs["binOpFollow"],
                new ParseEnvironment(env), TRACK_TYPE.ON_RESULT);
        }
        return env;
    }

    //static ParseEnvironment binOpFollowFunc(ParseEnvironment env)
    //{
    //    debug(BASIC)
    //    {
    //        writeln("  binOpFollowFunc entered");
    //    }
    //    if (nodeStack is null)
    //    {
    //        nodeStack = new Stack!(ASTNode);
    //    }
    //    if (env.status && nodeStack.size() > 0)
    //    {
    //        debug(BASIC)
    //        {
    //        }
    //        ASTNode rightTree = nodeStack.pop();
    //        ASTNode binOpNodeCandidate = nodeStack.pop();
    //        if (cast(BinOpASTNode)binOpNodeCandidate)
    //        {
    //            BinOpASTNode binOpNode = cast(BinOpASTNode)binOpNodeCandidate;
    //            binOpNode.rightTree = rightTree;
    //            nodeStack.push(binOpNode);
    //        }
    //        else
    //        {
    //            nodeStack.push(binOpNodeCandidate);
    //            nodeStack.push(rightTree);
    //            debug(BASIC)
    //            {
    //                writeln("AST Stack Dump Start");
    //                foreach_reverse (node; nodeStack.getUnderlying())
    //                {
    //                    node.printSelf();
    //                    writeln();
    //                }
    //                writeln("AST Stack Dump End");
    //            }
    //            string errStr = "Error: binOpFollowFunc: ".idup;
    //            errStr ~= "Unexpected stack element".idup;
    //            throw new Exception(errStr);
    //        }
    //    }
    //    return env;
    //}

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
