import std.stdio;
import std.string;
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
            writefln("%s\"%s\": %d: %s, %s%s: %d", whitespace,
                this.walkPrintElement(),
                topNode.recursionLevel, topNode.nodeName(),
                " Parent: ", topNode.parent.walkPrintElement(),
                topNode.parent.recursionLevel);
        }
        else
        {
            writefln("%s\"%s\": %d: %s", whitespace, topNode.walkPrintElement(),
                topNode.recursionLevel, topNode.nodeName());
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

    protected string nodeName() const nothrow
    {
        return this.classinfo.name;
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

abstract class LeftMidRightASTNode(Top) : ASTNode
{
    ASTNode leftTree;
    ASTNode rightTree;
    Top top;

    void setLeftTree(ref ASTNode left)
    {
        this.leftTree = left;
    }

    void setRightTree(ref ASTNode right)
    {
        this.rightTree = right;
    }

    void setTop(ref Top top)
    {
        this.top = top;
    }

    override protected ref const(string) walkPrintElement() const nothrow
    {
        return this.top.walkPrintElement();
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
        writefln("  Element: [%s]", this.top.walkPrintElement());
    }
}

abstract class ElementASTNode : ASTNode
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

abstract class TokenNode : ASTNode {}

abstract class ListNode : ASTNode
{
    protected ASTNode[] children;

    protected void addChild(ref ASTNode child)
    {
        this.children ~= [child];
    }

    override protected const(ASTNode)[] getChildren() const nothrow
    {
        return children;
    }
}

static this()
{
    ASTGen.nodeStack = new Stack!(ASTNode)();
}

private static bool isValidIdentifier(string str)
{
    if (str.length == 0)
    {
        return false;
    }
    if (!inPattern(str[0], "a-zA-Z"))
    {
        return false;
    }
    foreach (x; str)
    {
        if (!inPattern(x, "a-zA-Z0-9"))
        {
            return false;
        }
    }
    return true;
}

class ASTGen
{
    static Stack!(ASTNode) nodeStack;

    template ElementT(string className) if (isValidIdentifier(className))
    {
        mixin(`static class ` ~ className ~ ` : ElementASTNode {}`);

        static ParseEnvironment captFunc(ParseEnvironment env,
            ParseEnvironment oldEnv)
        in
        {
            assert(nodeStack !is null);
        }
        body
        {
            debug(BASIC)
            {
                writefln("  captFunc(%s) entered", className);
            }
            if (env.sourceIndex != oldEnv.sourceIndex && env.status)
            {
                debug(BASIC)
                {
                    writefln(
                        "    Captured string: [%s] at recursionLevel: [%d]",
                        env.source[oldEnv.sourceIndex..env.sourceIndex],
                        env.recursionLevel);
                }
                mixin(`auto newNode = new ` ~ className ~ `();`);
                newNode.setElement(
                    env.source[oldEnv.sourceIndex..env.sourceIndex]);
                newNode.setRecursionLevel(env.recursionLevel);
                nodeStack.push(newNode);
            }
            return env;
        }
    }

    template LeftMidRightT(string className, T : ASTNode)
        if (isValidIdentifier(className))
    {
        mixin(`static class ` ~ className ~ ` : LeftMidRightASTNode!(T) {}`);

        static ParseEnvironment leftMidRightFunc(ParseEnvironment env)
        in
        {
            assert(nodeStack !is null);
        }
        body
        {
            debug(BASIC)
            {
                writeln("  leftMidRightFunc entered");
            }
            if (env.status)
            {
                mixin(`auto newNode = new ` ~ className ~ ` ();`);
                newNode.setRecursionLevel(env.recursionLevel);
                ASTNode midNodeCandidate = nodeStack.pop();
                if (cast(T)midNodeCandidate)
                {
                    T midNode = cast(T)midNodeCandidate;
                    newNode.top = midNode;
                }
                else
                {
                    nodeStack.push(midNodeCandidate);
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
                    string errStr = "Error: leftMidRightFunc:\n";
                    errStr ~= "  Unexpected stack element:\n";
                    errStr ~= "  " ~ midNodeCandidate.classinfo.name;
                    errStr ~= "  Expected stack element:\n";
                    errStr ~= "  " ~ T.classinfo.name;
                    throw new Exception(errStr);
                }
                newNode.leftTree = nodeStack.pop();
                nodeStack.push(newNode);

                // See hack in DParse.operatorOR_RESPONSE()

                env.arbFuncs[className ~ "Follow"]
                    = &LeftMidRightT!(className, T).leftMidRightFollowFunc;

                env.recurseTracker.addListener(
                    env.arbFuncs[className ~ "Follow"],
                    new ParseEnvironment(env), TRACK_TYPE.ON_RESULT);
            }
            return env;
        }

        static ParseEnvironment leftMidRightFollowFunc(ParseEnvironment env,
            ParseEnvironment oldEnv)
        in
        {
            assert(nodeStack !is null);
        }
        body
        {
            debug(BASIC)
            {
                writeln("  leftMidRightFollowFunc entered");
                writeln("    env.status: ", env.status);
                writeln("    nodeStack.size(): ", nodeStack.size());
            }
            if (env.status && nodeStack.size() > 0)
            {
                ASTNode rightTree = nodeStack.pop();
                ASTNode leftMidRightNodeCandidate = nodeStack.pop();
                debug(BASIC)
                {
                    writeln("    rightTree:");
                    rightTree.printSelf();
                    writeln("    leftMidRightNodeCandidate:");
                    leftMidRightNodeCandidate.printSelf();
                }
                mixin(`alias ` ~ className ~ ` ClassNameT;`);
                if (cast(ClassNameT)leftMidRightNodeCandidate)
                {
                    ClassNameT leftMidRightNode
                        = cast(ClassNameT)leftMidRightNodeCandidate;
                    leftMidRightNode.rightTree = rightTree;
                    nodeStack.push(leftMidRightNode);
                }
                else
                {
                    nodeStack.push(leftMidRightNodeCandidate);
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
                    string errStr = "Error: leftMidRightFollowFunc: ".idup;
                    errStr ~= "Unexpected stack element".idup;
                    throw new Exception(errStr);
                }
            }
            return env;
        }
    }

    // For any given "className", generate two classes and two functions that
    // operate on those classes. One class is a "token", which sits on the
    // stack and literally has the job of just being something to find on the
    // stack. The other is a subclass of the ListNode ASTNode, which has the
    // trait of being able to contain a list of children. Outwardly, the
    // "API" of this template is intended to supply three entities.
    // The first is the existence of a ListNode accessible by the name
    // "className". The second and third are a token-pushing function
    // (tokenNodeFunc) and a list generation function (listGenFunc), that both
    // operate specifically on the specialized TokenNode and ListNode of any
    // specific instantiation of this template. Use of the template in terms
    // of parsing rulesets is: Just before some arbitrary list of captured
    // elements that you want to wrap up into a ListNode, call
    // tokenNodeFunc() to place a Token on the stack. Then, capture
    // some arbitrary number of ASTNodes. Then, call listGenFunc(), which
    // will take all ASTNodes on the stack as children until it encounters
    // its Token, which is silently discarded. The children will be contained
    // within the ListNode in the order that they were originally placed on the
    // stack (pushing order, not popping order)
    // Ex.
    // ListNode:       ASTGen.ListTemplate!("ParameterList").ParameterList
    // tokenNodeFunc: &ASTGen.ListTemplate!("ParameterList").tokenNodeFunc
    // listGenFunc:   &ASTGen.ListTemplate!("ParameterList").listGenFunc
    template ListTemplate(string className) if (isValidIdentifier(className))
    {
        mixin(`protected static class ` ~ className ~ `Token : TokenNode {}`);

        mixin(`static class ` ~ className ~ ` : ListNode {}`);

        mixin(`private alias ` ~ className ~ ` ClassNameT;`);
        mixin(`private alias ` ~ className ~ `Token ClassNameTokenT;`);

        static ParseEnvironment tokenNodeFunc(ParseEnvironment env)
        in
        {
            assert(nodeStack !is null);
        }
        body
        {
            debug(BASIC)
            {
                writefln("  tokenNodeFunc entered");
            }
            ClassNameTokenT tokenNode = new ClassNameTokenT();
            tokenNode.setRecursionLevel(env.recursionLevel);
            nodeStack.push(tokenNode);
            return env;
        }

        static ParseEnvironment listGenFunc(ParseEnvironment env)
        in
        {
            assert(nodeStack !is null);
            assert(nodeStack.size() > 0);
            mixin(`assert(nodeStack.containsInstance!(`
                ~ className ~ `Token)());`);
        }
        body
        {
            debug(BASIC)
            {
                writefln("  listGenFunc entered");
            }
            ClassNameT listNode = new ClassNameT();
            auto node = nodeStack.pop();
            while (cast(ClassNameTokenT)node is null)
            {
                listNode.addChild(node);
                node = nodeStack.pop();
            }
            // We popped nodes off the stack in reverse order to their
            // order of appearance, so reverse it to get the original order
            // of appearance
            listNode.children.reverse;
            listNode.setRecursionLevel(env.recursionLevel);
            nodeStack.push(listNode);
            return env;
        }
    }

    static ParseEnvironment rootFunc(ParseEnvironment env)
    in
    {
        assert(nodeStack !is null);
    }
    body
    {
        debug(BASIC)
        {
            writeln("  rootFunc entered");
        }
        ASTNode newNode = new ASTNode();
        newNode.setRecursionLevel(env.recursionLevel);
        nodeStack.push(newNode);
        return env;
    }
}

unittest
{
    writeln("ASTGen.ListTemplate unittest entered!");
    if (ASTGen.nodeStack is null)
    {
        ASTGen.nodeStack = new Stack!(ASTNode);
    }
    assert(ASTGen.nodeStack !is null);
    // Create hypothetical ParameterList/ParameterListToken class pair, and
    // grab operating functions that are magically created for us
    ParseEnvironment function(ParseEnvironment env) tokenNodeFunc =
        &ASTGen.ListTemplate!("ParameterList").tokenNodeFunc;
    ParseEnvironment function(ParseEnvironment env) listGenFunc =
        &ASTGen.ListTemplate!("ParameterList").listGenFunc;
    auto env = new ParseEnvironment();
    // Dummy node on the stack to check to make sure it's still there at the
    // end
    ASTGen.nodeStack.push(new ASTNode());
    // Shove a ParameterListToken on the stack
    tokenNodeFunc(env);
    // Arbitrary intermediary nodes
    ASTGen.nodeStack.push(new ASTNode());
    ASTGen.nodeStack.push(new ASTNode());
    ASTGen.nodeStack.push(new ASTNode());
    // Create ParameterList node
    listGenFunc(env);
    // Ensure that the top node was a ParameterList node with three children
    auto node = ASTGen.nodeStack.pop();
    assert(cast(ASTGen.ListTemplate!("ParameterList").ParameterList)node);
    assert((cast(ASTGen.ListTemplate!("ParameterList").ParameterList)node)
        .getChildren().length == 3);
    // Ensure that there is still that first ASTNode on the stack
    assert(ASTGen.nodeStack.size() == 1);
    writeln("ASTGen.ListTemplate unittest PASSED!");
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

    T pop()
    in
    {
        assert(this.stack.length > 0);
    }
    body
    {
        T temp = this.stack[$-1];
        this.stack = this.stack[0..$-1];
        return temp;
    }

    ref T peek()
    in
    {
        assert(this.stack.length > 0);
    }
    body
    {
        return this.stack[$-1];
    }

    pure auto size()
    {
        return this.stack.length;
    }

    pure auto getUnderlying()
    {
        return this.stack;
    }

    bool containsInstance(Q)() const pure nothrow
    in
    {
        assert(stack !is null);
    }
    body
    {
        foreach (T; stack)
        {
            if (cast(Q)T)
            {
                return true;
            }
        }
        return false;
    }
}

unittest
{
    writeln("Stack!(T) unittest entered!");
    auto stack = new Stack!(ASTNode);
    assert(stack.size() == 0);
    stack.push(new ASTNode());
    assert(stack.size() == 1);
    stack.pop();
    assert(stack.size() == 0);
    assert(stack.containsInstance!(
        ASTGen.ListTemplate!("ExampleToken").ExampleToken)() == false);
    stack.push(new ASTGen.ListTemplate!("ExampleToken").ExampleToken());
    assert(stack.containsInstance!(
        ASTGen.ListTemplate!("ExampleToken").ExampleToken)() == true);
    writeln("Stack!(T) unittest PASSED!");
}
