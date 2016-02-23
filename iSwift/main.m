//
//  main.m
//  iSwift
//
//  Created by Jin Wang on 17/02/2016.
//  Copyright © 2016 Uthoft. All rights reserved.
//

#import <Foundation/Foundation.h>
@import iSwiftCore;

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // insert code here...
        NSArray *arguments = [[NSProcessInfo processInfo] arguments];
        NSArray *actualArguments = [arguments count] > 0 ? [arguments subarrayWithRange: NSMakeRange(1, [arguments count] - 1)] : [NSArray array];
        
        [[Kernel sharedInstance] start: actualArguments];
    }
    return 0;
}
