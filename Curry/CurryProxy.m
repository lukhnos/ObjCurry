//
// CurryProxy.m
// Curry
//
// Copyright (C) 2012 Lukhnos Liu.
//
// Permission is hereby granted, free of charge, to any person obtaining a
// copy of this software and associated documentation files (the "Software"),
// to deal in the Software without restriction, including without limitation
// the rights to use, copy, modify, merge, publish, distribute, sublicense,
// and/or sell copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
// DEALINGS IN THE SOFTWARE.
//

#import "CurryProxy.h"

@implementation CurryProxy
- (id)initWithMethodSignature:(NSMethodSignature *)signature selector:(SEL)selector target:(id)target;
{
    self = [super init];
    if (self) {
        invocation = [[NSInvocation invocationWithMethodSignature:signature] retain];
        [invocation setSelector:selector];
        [invocation retainArguments];
        [invocation setTarget:target];
    }
    return self;
}

// make a copy of the proxy object; we need to make a copy of the invocation object
// (calling -[NSInvocation copy] won't get what you expect)
- (id)copy
{
    NSMethodSignature *signature = [invocation methodSignature];
    SEL selector = [invocation selector];
    id target = [invocation target];

    CurryProxy *newProxy = [[[self class] alloc] initWithMethodSignature:signature selector:selector target:target];

    size_t frameSize = [signature frameLength];
    char buf[frameSize];
    for (NSUInteger i = 2, c = [signature numberOfArguments]; i < c; i++) {
        bzero(buf, frameSize);

        [invocation getArgument:&buf atIndex:i];
        [[newProxy invocation] setArgument:&buf atIndex:i];
    }

    return newProxy;
}

- (void)dealloc
{
    [invocation release];
}

- (NSInvocation *)invocation;
{
    return invocation;
}
@end
