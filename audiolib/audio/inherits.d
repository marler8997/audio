// TODO: move to mar?
module audio.inherits;

mixin template Inherit(T)
{
    T base;
    static assert(base.offsetof == 0, "Inherit!(" ~ T.stringof ~ ") needs to be the first field with offset 0");
    final inout(T)* asBase() inout { return cast(inout(T)*)&this; }
}

//
// A "BaseTemplate" is a pattern where the base type is a template that takes a
// type that will only be referenced as a pointer. This means that every template instance
// should have the same binary implementation. So:
//     BaseTemplate!void should be equivalent to any BaseTemplate!T
//
mixin template ForwardInheritBaseTemplate(alias Template, LeafType)
{
    // verify this is a valid BaseTemplate
    static assert(Template!void.sizeof == Template!(LeafType).sizeof);

    Template!LeafType base;
    static assert(base.offsetof == 0, "InheritTemplateVoidBase!(" ~ T.stringof ~ ") needs to be the first field with offset 0");
    final inout(Template!void)* asBase() inout { return cast(inout(Template!void)*)&this; }
}
mixin template InheritBaseTemplate(alias Template)
{
    mixin ForwardInheritBaseTemplate!(Template, typeof(this));
}