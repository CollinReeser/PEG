import std.stdio;
import std.random;
import std.conv;

class ASTNode
{
    ASTNode[] children;
    ASTNode sibling;
    long recursionLevel;
    char[] element;
    char[] capturingRule;
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

    void setElement(char[] element)
    {
        this.element = element;
    }

    void setCapturingRule(char[] capturingRule)
    {
        this.capturingRule = capturingRule;
    }

    void printSelf()
    {
        writeln("Element: ", this.element);
        writeln("  RecursionLevel: ", this.recursionLevel);
    }

    static void walk(ref ASTNode topNode)
    {
        walk(topNode, 0);
    }

    private static void walk(ref ASTNode topNode, int indent)
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
        if (topNode.sibling !is null)
        {
            ASTNode sib = topNode.sibling;
            while (sib !is null)
            {
                writefln("%s*s", whitespace);
                walk(sib, indent);
                sib = sib.sibling;
            }
        }
    }

    private static randomWord()
    {
        char[] selection = "ABCDEF0123456789".dup;
        char[] ranWord;
        for (int i = 0; i < 8; i++)
        {
            ranWord ~= selection[uniform(0, selection.length)];
        }
        return ranWord;
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

debug(ASTTESTS)
{
    int main(char[][] args)
    {
        return 0;
    }
}
