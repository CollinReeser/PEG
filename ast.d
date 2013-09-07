import std.stdio;
import std.random;
import std.conv;
import DParse;

class ASTNode
{
    ASTNode[] children;
    ASTNode sibling;
    long recursionLevel;
    string element;
    string capturingRule;
    ASTNode parent;

    this()
    {
    }

    void addChild(ASTNode child)
    {
        child.parent = this;
        this.children ~= child;
    }

    void addSibling(ASTNode sibling)
    {
        ASTNode temp = this.sibling;
        if (temp !is null)
        {
            while(temp.sibling !is null)
            {
                temp = temp.sibling;
            }
            temp.sibling = sibling;
        }
        else
        {
            this.sibling = sibling;
        }
    }

    void setRecursionLevel(long recursionLevel)
    {
        this.recursionLevel = recursionLevel;
    }

    void setElement(string element)
    {
        this.element = element;
    }

    void setCapturingRule(string capturingRule)
    {
        this.capturingRule = capturingRule;
    }

    public ref const(ASTNode[]) getChildren() const
    {
        return children;
    }

    public ref const(string) getElement() const
    {
        return element;
    }

    void printSelf()
    {
        writeln("Element: ", this.element);
        writeln("  RecursionLevel: ", this.recursionLevel);
    }

    static void walk(ref const(ASTNode) topNode)
    {
        walk(topNode, 0);
    }

    private static void walk(ref const(ASTNode) topNode, int indent)
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
            writefln("%s\"%s\": %d, %s%s: %d", whitespace, topNode.element,
                topNode.recursionLevel, " Parent: ", topNode.parent.element,
                topNode.parent.recursionLevel);
        }
        else
        {
            writefln("%s\"%s\": %d", whitespace, topNode.element,
                topNode.recursionLevel);
        }
        if (topNode.children.length > 0)
        {
            writefln("%s*c", whitespace);
            for (int i = 0; i < topNode.children.length; i++)
            {
                walk(topNode.children[i], indent + 1);
            }
        }
        //if (topNode.sibling !is null)
        //{
        //    auto sib = topNode.sibling;
        //    while (sib !is null)
        //    {
        //        writefln("%s*s", whitespace);
        //        walk(sib, indent);
        //        sib = sib.sibling;
        //    }
        //}
    }

    private static string randomWord()
    {
        string selection = "ABCDEF0123456789".idup;
        char[] ranWord;
        for (int i = 0; i < 8; i++)
        {
            ranWord ~= selection[uniform(0, selection.length)];
        }
        return ranWord.idup;
    }

    private static ASTNode growTree(ref ASTNode node, int depth)
    {
        if (depth < 4)
        {
            for (int i = 0; i < dice(30, 10, 10, 10, 10, 10, 10, 10); i++)
            {
                ASTNode newChild = new ASTNode();
                newChild.setElement(to!string(depth) ~ "-" ~ randomWord());
                node.addChild(growTree(newChild, depth + 1));
            }
            for (int i = 0; i < dice(75, 10, 10, 5); i++)
            {
                ASTNode newSibling = new ASTNode();
                newSibling.setElement(to!string(depth) ~ "-" ~ randomWord());
                node.addSibling(growTree(newSibling, depth + 1));
            }
        }
        return node;
    }

    static ASTNode randomTree()
    {
        ASTNode toplevelNode = new ASTNode();
        toplevelNode.setElement(randomWord());
        growTree(toplevelNode, 0);
        return toplevelNode;
    }

}

unittest
{
    ASTNode node = new ASTNode();
    node.setElement("this".dup);
    ASTNode newNode = new ASTNode();
    newNode.setElement("that".dup);
    node.addChild(newNode);
    ASTNode.walk(node);
    ASTNode randTree = ASTNode.randomTree();
    ASTNode.walk(randTree);
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
    {
        if (this.stack.length > 0)
        {
            T temp = this.stack[$-1];
            this.stack = this.stack[0..$-1];
            return temp;
        }
        return null;
    }

    T peek()
    {
        if (this.stack.length > 0)
        {
            return this.stack[$-1];
        }
        return null;
    }

    pure auto size()
    {
        return this.stack.length;
    }

    pure auto getUnderlying()
    {
        return this.stack;
    }
}

class ASTGen
{
    static ASTNode topNode;
    static ASTNode tempNode;
    static Stack!(ASTNode) nodeStack;

    static ParseEnvironment captFunc(ParseEnvironment env,
        ParseEnvironment oldEnv)
    {
        debug(AST)
        {
            writeln("  captFunc entered");
        }
        if (ASTGen.nodeStack is null)
        {
            ASTGen.nodeStack = new Stack!(ASTNode);
        }
        if (env.sourceIndex != oldEnv.sourceIndex)
        {
            debug(AST)
            {
                writefln("    Captured string: [%s] at recursionLevel: [%d]",
                    env.source[oldEnv.sourceIndex..env.sourceIndex],
                    env.recursionLevel);
            }
            ASTNode newNode = new ASTNode();
            newNode.setElement(env.source[oldEnv.sourceIndex..env.sourceIndex]);
            newNode.setRecursionLevel(env.recursionLevel);
            if (nodeStack.size() == 0)
            {
                nodeStack.push(newNode);
            }
            else
            {
                if (nodeStack.peek().recursionLevel < newNode.recursionLevel)
                {
                    auto topNode = nodeStack.pop();
                    newNode.addChild(topNode);
                    nodeStack.push(newNode);
                }
                else
                {
                    nodeStack.push(newNode);
                }
            }
        }
        return env;
    }

    static ParseEnvironment foldStackFunc(ParseEnvironment env)
    {
        debug(AST)
        {
            writeln("  foldStackFunc entered");
        }
        if (ASTGen.nodeStack is null)
        {
            ASTGen.nodeStack = new Stack!(ASTNode);
        }
        for(;;)
        {
            if (nodeStack.size() < 2)
            {
                break;
            }
            auto top = nodeStack.pop();
            auto second = nodeStack.pop();
            if (top.recursionLevel < env.recursionLevel)//&&
                //second.recursionLevel == env.recursionLevel)
            {
                second.addChild(top);
                nodeStack.push(second);
            }
            else
            {
                nodeStack.push(second);
                nodeStack.push(top);
                break;
            }
        }
        return env;
    }

    static ParseEnvironment rootFunc(ParseEnvironment env)
    {
        debug(AST)
        {
            writeln("  rootFunc entered");
        }
        if (ASTGen.nodeStack is null)
        {
            ASTGen.nodeStack = new Stack!(ASTNode);
        }
        ASTNode newNode = new ASTNode();
        newNode.setElement("".idup);
        newNode.setRecursionLevel(env.recursionLevel);
        nodeStack.push(newNode);
        return env;
    }
}
