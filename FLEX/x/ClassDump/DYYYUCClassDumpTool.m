#import "DYYYUCClassDumpTool.h"
#import "DYYYCDHeaderDumper.h"

@implementation DYYYUCClassDumpTool

+ (void)dumpHeadersZipWithProgress:(UCClassDumpToolProgressBlock)progress
                        completion:(UCClassDumpToolCompletionBlock)completion {
    [DYYYCDHeaderDumper dumpHeadersZipWithProgress:^(CGFloat value, NSString * _Nonnull text) {
        if (progress) progress(value, text ?: @"");
    } completion:^(NSURL * _Nullable zipURL, NSError * _Nullable error) {
        if (completion) completion(zipURL, error);
    }];
}

+ (NSString *)headerForClassName:(NSString *)className {
    return [DYYYCDHeaderDumper headerForClassName:className];
}

+ (DYYYCDClassInfo *)classInfoForName:(NSString *)className {
    return [DYYYCDHeaderDumper classInfoForName:className];
}

+ (NSArray<NSString *> *)allClassNames {
    return [DYYYCDHeaderDumper allClassNames];
}

+ (NSArray<NSString *> *)searchClassNames:(NSString *)keyword {
    return [DYYYCDHeaderDumper searchClassNames:keyword];
}

+ (NSArray<NSString *> *)searchClassNames:(NSString *)keyword prefixMatch:(BOOL)prefixMatch {
    return [DYYYCDHeaderDumper searchClassNames:keyword prefixMatch:prefixMatch];
}

+ (NSArray<NSDictionary *> *)classNamesByImage {
    return [DYYYCDHeaderDumper allClassNamesByImage];
}

+ (NSArray<NSString *> *)recentClassNames {
    return [DYYYCDHeaderDumper recentClassNames];
}

+ (void)addToRecentClasses:(NSString *)className {
    [DYYYCDHeaderDumper addToRecentClasses:className];
}

+ (NSArray<NSString *> *)inheritanceChainForClass:(NSString *)className {
    return [DYYYCDHeaderDumper inheritanceChainForClass:className];
}

+ (NSString *)protocolHeaderForName:(NSString *)protocolName {
    return [DYYYCDHeaderDumper protocolHeaderForName:protocolName];
}

+ (NSArray<NSString *> *)allProtocolNames {
    return [DYYYCDHeaderDumper allProtocolNames];
}

@end
