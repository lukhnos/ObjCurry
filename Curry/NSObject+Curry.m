//
// NSObject+Curry.m
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

#import "NSObject+Curry.h"
#import "CurryProxy.h"
#import <objc/runtime.h>

static NSString *const kProxyClassSuffix = @"_CurryProxy";

static BOOL ArgumentTypeSupported(const char *type)
{
    return !strcmp(type, @encode(id));
}

static BOOL ReturnTypeSupported(const char *type)
{
    return !strcmp(type, @encode(id));
}

static char *CreateMethodSignature(const char *argType)
{
    char *str = (char *)calloc(1, (2 + strlen(argType) + 1));
    if (str) {
        strcat(str, "@:");
        strcat(str, argType);
    }
    return str;
}

static void SetError(NSError **error, NSString *message)
{
    if (error) {
        *error = [NSError errorWithDomain:@"org.lukhnos.Curry" code:-1 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:message, NSLocalizedDescriptionKey, nil]];
    }
}

@implementation NSObject (Curry)
+ (BOOL)curry:(SEL)selector
{
    return [self curry:selector error:NULL];
}

+ (BOOL)curry:(SEL)selector error:(NSError **)error;
{
    // get and check the signature of the instance method from the class object
    NSMethodSignature *signature = [self instanceMethodSignatureForSelector:selector];
    if (!signature) {
        SetError(error, @"Invalud signature (no such method)");
        return NO;
    }

    // get and check the argument count
    NSUInteger argumentCount = [signature numberOfArguments] - 2;
    if (argumentCount < 2) {
        SetError(error, @"Curried method must take at least two arguments");
        return NO;
    }

    // every signature has 2 hidden arguments, 0 is the self, 1 is the _cmd
    NSUInteger lastArgumentIndex = argumentCount - 1;

    // check if we support the return type
    if (!ReturnTypeSupported([signature methodReturnType])) {
        SetError(error, @"Unsupported return type");
        return NO;
    }

    // check if we support the argument types
    for (NSUInteger i = 0; i < lastArgumentIndex; i++) {
        if (!ArgumentTypeSupported([signature getArgumentTypeAtIndex:(i + 2)])) {
            SetError(error, @"Unsupported argument type");
            return NO;
        }
    }

    // now we need to separate the method name into components
    NSString *selString = NSStringFromSelector(selector);
    NSRegularExpression *methodMatch = [NSRegularExpression regularExpressionWithPattern:@"[_A-Za-z][_A-Za-z0-9]*:+" options:0 error:NULL];
    NSArray *matches = [methodMatch matchesInString:selString options:0 range:NSMakeRange(0, [selString length])];

    // sanity check that our regex is working correctly
    NSAssert([matches count] == argumentCount, @"Number of method arguments in the selector and that in the signature must match");

    // fetch the proxy class; if it doesn't exist, create it
    // for class Foo, the created proxy class will be called Foo_CurryProxy
    // (or anything defined in kProxyClassSuffix)
    NSString *proxyClassName = [NSString stringWithFormat:@"%@%@", NSStringFromClass(self), kProxyClassSuffix];
    Class proxyClass = NSClassFromString(proxyClassName);
    if (!proxyClass) {
        proxyClass = objc_allocateClassPair([CurryProxy class], [proxyClassName UTF8String], 0);
        if (!proxyClass) {
            SetError(error, @"Cannot create the proxy class");
            return NO;
        }

        objc_registerClassPair(proxyClass);
    }

    // except the first and the last, create method for each component
    for (NSUInteger i = 1; i < lastArgumentIndex; i++) {
        NSString *methodName = [selString substringWithRange:[[matches objectAtIndex:i] range]];
        const char *argumentType = [signature getArgumentTypeAtIndex:(i + 2)];

        IMP methodIMP = NULL;
        if (!strcmp(argumentType, @encode(id))) {
            methodIMP = imp_implementationWithBlock(^(id _self, NSUInteger argIndex, id arg) {
                [[_self invocation] setArgument:&arg atIndex:(argIndex + 2)];
                return _self;
            });
        }
        else {
            // why are we ever here if we've checked?
            NSAssert(NO, @"Invalid argument type");
        }

        SEL sel = NSSelectorFromString(methodName);
        char *newMethodSignature = CreateMethodSignature(argumentType);
        BOOL success = class_addMethod(proxyClass, sel, methodIMP, newMethodSignature);
        if (!success) {
            SetError(error, @"Failed to create method in the proxy class");
            return NO;
        }

        free(newMethodSignature);
    }

    // when the last method is called, we need to invoke the real thing and return the value
    do {
        NSString *methodName = [selString substringWithRange:[[matches objectAtIndex:lastArgumentIndex] range]];
        const char *argumentType = [signature getArgumentTypeAtIndex:(lastArgumentIndex + 2)];
        const char *returnType = [signature methodReturnType];

        IMP methodIMP = NULL;
        if (!strcmp(argumentType, @encode(id)) && !strcmp(returnType, @encode(id))) {
            methodIMP = imp_implementationWithBlock(^(id _self, id arg) {
                NSInvocation *invocation = [_self invocation];
                [invocation setArgument:&arg atIndex:(lastArgumentIndex + 2)];
                [invocation invoke];

                id returnValue;
                [invocation getReturnValue:&returnValue];
                return returnValue;
            });
        }
        else {
            // why are we ever here if we've checked?
            NSAssert(NO, @"Invalid argument type");
        }

        SEL sel = NSSelectorFromString(methodName);
        char *newMethodSignature = CreateMethodSignature(argumentType);
        BOOL success = class_addMethod(proxyClass, sel, methodIMP, newMethodSignature);
        if (!success) {
            SetError(error, @"Cannot create the last method in the proxy class");
            return NO;
        }

        free(newMethodSignature);
    } while(0);

    // sending the first part of the message (i.e. method with the first parameter) returns a proxy object
    do {
        NSString *headMethodName = [selString substringWithRange:[[matches objectAtIndex:0] range]];
        const char *argumentType = [signature getArgumentTypeAtIndex:(0 + 2)];

        IMP methodIMP = NULL;
        if (!strcmp(argumentType, @encode(id))) {
            methodIMP = imp_implementationWithBlock(^(id _self, id arg) {
                id proxyObject = [[[proxyClass alloc] initWithMethodSignature:signature selector:selector target:_self] autorelease];
                [[proxyObject invocation] setArgument:&arg atIndex:(0 + 2)];
                return proxyObject;
            });
        }
        else {
            // why are we ever here if we've checked?
            NSAssert(NO, @"Invalid argument type");
        }


        SEL sel = NSSelectorFromString(headMethodName);
        char *newMethodSignature = CreateMethodSignature(argumentType);
        BOOL success = class_addMethod(self, sel, methodIMP, newMethodSignature);
        if (!success) {
            SetError(error, @"Cannot create the first method in the original class");
            return NO;
        }

        free(newMethodSignature);

    } while(0);

    return YES;
}
@end
