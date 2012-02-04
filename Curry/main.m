//
// main.m
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

#import <Foundation/Foundation.h>
#import "NSObject+Curry.h"

@interface Foo : NSObject
- (id)addNumber:(id)a withNumber:(id)b;
@end

@implementation Foo
- (id)addNumber:(id)a withNumber:(id)b
{
    double x = [a doubleValue];
    double y = [b doubleValue];
    return [NSNumber numberWithDouble:x + y];
}
@end

int main (int argc, const char * argv[])
{
    @autoreleasepool {
        [[Foo class] curry:@selector(addNumber:withNumber:)];


        Foo *foo = [[[Foo alloc] init] autorelease];
        NSNumber *x = [NSNumber numberWithDouble:10.0];
        NSNumber *y = [NSNumber numberWithDouble:20.0];
        NSNumber *z = [foo addNumber:x withNumber:y];
        NSLog(@"x: %f, y: %f, x + y = z: %f", [x doubleValue], [y doubleValue], [z doubleValue]);

        id fooAddX = [foo addNumber:x];

        y = [NSNumber numberWithDouble:30.0];
        z = [fooAddX withNumber:y];
        NSLog(@"x: %f, y: %f, x + y = z: %f", [x doubleValue], [y doubleValue], [z doubleValue]);

        y = [NSNumber numberWithDouble:40.0];
        z = [fooAddX withNumber:y];
        NSLog(@"x: %f, y: %f, x + y = z: %f", [x doubleValue], [y doubleValue], [z doubleValue]);

    }

    return 0;
}
