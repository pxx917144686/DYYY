// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXRuntimeKeyPath.m
//  FLEX
//
//  由 Tanner 创建于 3/22/17.
//  版权所有 © 2017 Tanner Bennett。保留所有权利。
//

#import "FLEXRuntimeKeyPath.h"
#import "FLEXRuntimeClient.h"

@interface FLEXRuntimeKeyPath () {
    NSString *flex_description;
}
@end

@implementation FLEXRuntimeKeyPath

+ (instancetype)empty {
    static FLEXRuntimeKeyPath *empty = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        FLEXSearchToken *any = FLEXSearchToken.any;

        empty = [self new];
        empty->_bundleKey = any;
        empty->flex_description = @"";
    });

    return empty;
}

+ (instancetype)bundle:(FLEXSearchToken *)bundle
                 class:(FLEXSearchToken *)cls
                method:(FLEXSearchToken *)method
            isInstance:(NSNumber *)instance
                string:(NSString *)keyPathString {
    FLEXRuntimeKeyPath *keyPath  = [self new];
    keyPath->_bundleKey = bundle;
    keyPath->_classKey  = cls;
    keyPath->_methodKey = method;

    keyPath->_instanceMethods = instance;

    // 为了相等性比较，移除无关的尾随 '*'
    if ([keyPathString hasSuffix:@"*"]) {
        keyPathString = [keyPathString substringToIndex:keyPathString.length];
    }
    keyPath->flex_description = keyPathString;
    
    if (bundle.isAny && cls.isAny && method.isAny) {
        [FLEXRuntimeClient initializeWebKitLegacy];
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
    if ([object isKindOfClass:[FLEXRuntimeKeyPath class]]) {
        FLEXRuntimeKeyPath *kp = object;
        return [flex_description isEqualToString:kp->flex_description];
    }

    return NO;
}

@end
