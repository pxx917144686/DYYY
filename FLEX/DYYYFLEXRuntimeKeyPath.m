//
//  DYYYFLEXRuntimeKeyPath.m
//  FLEX
//
//  Created by Tanner on 3/22/17.
//  Copyright © 2017 Tanner Bennett. All rights reserved.
//

#import "DYYYFLEXRuntimeKeyPath.h"
#import "DYYYFLEXRuntimeClient.h"

@interface DYYYFLEXRuntimeKeyPath () {
    NSString *flex_description;
}
@end

@implementation DYYYFLEXRuntimeKeyPath

+ (instancetype)empty {
    static DYYYFLEXRuntimeKeyPath *empty = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        DYYYFLEXSearchToken *any = DYYYFLEXSearchToken.any;

        empty = [self new];
        empty->_bundleKey = any;
        empty->flex_description = @"";
    });

    return empty;
}

+ (instancetype)bundle:(DYYYFLEXSearchToken *)bundle
                 class:(DYYYFLEXSearchToken *)cls
                method:(DYYYFLEXSearchToken *)method
            isInstance:(NSNumber *)instance
                string:(NSString *)keyPathString {
    DYYYFLEXRuntimeKeyPath *keyPath  = [self new];
    keyPath->_bundleKey = bundle;
    keyPath->_classKey  = cls;
    keyPath->_methodKey = method;

    keyPath->_instanceMethods = instance;

    // Remove irrelevant trailing '*' for equality purposes
    if ([keyPathString hasSuffix:@"*"]) {
        keyPathString = [keyPathString substringToIndex:keyPathString.length];
    }
    keyPath->flex_description = keyPathString;
    
    if (bundle.isAny && cls.isAny && method.isAny) {
        [DYYYFLEXRuntimeClient initializeWebKitLegacy];
    }

    return keyPath;
}

- (NSString *)description {
    return flex_description;
}

- (NSUInteger)hash {
    return flex_description.hash;
}

- (BOOL)isEqual:(id)object {
    if ([object isKindOfClass:[DYYYFLEXRuntimeKeyPath class]]) {
        DYYYFLEXRuntimeKeyPath *kp = object;
        return [flex_description isEqualToString:kp->flex_description];
    }

    return NO;
}

@end
