# Curry

Curry studies the possibility of introducing currying to Objective-C and the
various issues that come with it.

Please note that this is not the real "currying" by the strict definition,
and I'll explain the reason below. Plus, adding such language features to
an imperative, objected-oriented language like Objective-C has lots of other
issues. So this project is exploratory, not something intended for production
use.


## Motivation

For example, if you have a method:

    -[SomeClass doThis:withThat:andThat:]

And say you want to call:

    SomeClass *foo = [[SomeClass alloc] init];
    [foo doThis:a withThat:b andThat:c];
    [foo doThis:a withThat:b andThat:d];
    [foo doThis:a withThat:b andThat:e];

Apparently the only argument that changes is the last. With currying, it's
possible to write:

    SomeClass *foo = [[SomeClass alloc] init];
    id fooAB = [[foo doThis:a] withThat:b];
    [fooAB andThat:c];
    [fooAB andThat:d];
    [fooAB andThat:e];

In fact, since Objective-C now has blocks, we can write this instead:

    SomeClass *foo = [[SomeClass alloc] init];
    void (^fooABAnd)(id) = ^(id x) { [foo doThis:a withThat:b andThat:x]; }

The problem with that is you have to write it in an ad-hoc fashion, i.e. you
need to write such a block each time you need it. And, if you want to do
something like:

    ((fooDoThis(a))(b))(c);

You have to write something like:

    typedef void (^id_to_void)(id);
    typedef id_to_void (^id_to_id_to_void)(id);
    typedef id_to_id_to_void (^id_to_id_to_id_to_void)(id);
    id_to_id_to_id_to_void fooDoThis = ^(id x) {
        id_to_id_to_void withThat = ^(id y) {
            id_to_void andThat = ^(id z) {
                [foo doThis:x withThat:y andThat:z];
            };
            return andThat;
        };
        return withThat;
    };

    ((fooDoThis(a))(b))(c);

Apparently, that's not very fun to write.

## Usage

The supplied NSObject category, `NSObject (Curry)`, has a method called
`curry:` (or `curry:error:` which gives you some error diagnostics). Using
the example, above, if you call

    [SomeClass curry:@selector(doThis:withThat:andThat:)];

Then a method `doThis:` will be added to `SomeClass`, and two methods,
`withThat:` and `andThat:` will be added to a proxy class (transparently
created for you). So now you can call:

    SomeClass *foo = [[SomeClass alloc] init];
    [[[foo doThis:a] withThat:b] andThat:c];

In fact, each call in effect creates a closure for the immediate parameter.
For example:

    id fooDoWithA = [foo doThis:a];
    id thenB1 = [foo withThat:b1];
    id thenB2 = [foo withThat:b2];

    [thenB1 andThat:c]; // == [foo doThis:a withThat:b1 andThat:c]
    [thenB2 andThat:c]; // == [foo doThis:a withThat:b2 andThat:c]


## Implementations and Supported Types

Curry uses Objective-C Runtime API to dynamically create new classes and
methods. Because methods have to be typed, Curry only supports a limited
number of common types, such as id, character, (un)signed short/int/long/long long, general pointer. For return types, there is one more supported: void.

It's possible to add more types — see NSObject+Curry.m to see how to expand
the type support. For example, you can add CGRect/NSRect support. The problem
is that, unless deeper runtime API hack is found (perhaps some assembly
required), for n argument types and m return types, we have to write n*m
definitions. Even with the current macro usage it still won't scale well. If
you have better solution, I'd be very happy to hear from you.


## Issues (and Why It's Not the Real Currying)

Although proxies behave like immutable objects, the target object (i.e. the
original object on which the original method is invoked) is not. So while
the proxies create an illusion of closures, you are still dealing with an
imperative language. So if you intend to try Curry in a multithreaded system,
be warned.

Then there's the issue why it's not the real thing. By definition, curry
is an operation that turns a function

    f: (t_0, t_1, t_2, ..., t_n) -> t_n+1

into

    g: t_0 -> t_1 -> t_2 -> ... -> t_n -> t_n+1

So, instead of calling f(a, b, c, ...) to get the return value, we can do
this:

    g a             -- returns g'  : t_1 -> (t_2 -> ... -> t_n+1)
    (g a) b         -- returns g'' : t_2 -> (... -> ... -> t_n+1)
    ((g a) b) c     -- returns g''': t_3 -> (... -> t_n+1)
    ...
    (...) p_n-1     -- returns some f: t_n -> t_n+1
    ((... ) y) z    -- equivalent to f(z), and returns t_n+1

But we all know how a method invocation ("sending a message") is actually
implemented:

    objc_msgSend(obj, selector, arg1, arg2, ...);

So the real type of an Objective-C method is, if we want to use this
notation:

    someMethod: (objType, arg1Type, arg2Type, ...) -> returnType

And what Curry does is turning that into something like:

    cm: (ot -> a1t) -> ((pt -> a2t) -> (pt -> a3t) ... -> returnType)

Here `cm` stands for `curriedMethod`, `ot` for `objType`, `a1t` for
`arg1Type`, and `pt` stands for `proxyObjectType`.


## Extending the Fun

With the basics in place, it's possible to extend the fun. For example,
each proxy object can actually remember the parameters that are ever passed
to them and the returned objects. So if the parameter doesn't change, the
proxy can always returned the "memorized" return value. This is known as
"memoization". Again, in an imperative language like Objective-C, there are
all kinds of issues that come with this. The use of proxy object also brings
some overhead and will have some impact on performance in places such as
a tight loop. Finally, because this is not a feature supported by the
compiler, debugging can be tricky if something happened inside the
proxy object (especially in the last step that actually invokes the original
method).
