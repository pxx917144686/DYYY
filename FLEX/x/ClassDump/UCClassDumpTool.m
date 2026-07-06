#import "UCClassDumpTool.h"
#import "CDHeaderDumper.h"

@implementation UCClassDumpTool

+ (void)dumpHeadersZipWithProgress:(UCClassDumpToolProgressBlock)progress
                        completion:(UCClassDumpToolCompletionBlock)completion {
    [CDHeaderDumper dumpHeadersZipWithProgress:^(CGFloat value, NSString * _Nonnull text) {
        if (progress) progress(value, text ?: @"");
    } completion:^(NSURL * _Nullable zipURL, NSError * _Nullable error) {
        if (completion) completion(zipURL, error);
    }];
}

+ (NSString *)headerForClassName:(NSString *)className {
    return [CDHeaderDumper headerForClassName:className];
}

+ (CDClassInfo *)classInfoForName:(NSString *)className {
    return [CDHeaderDumper classInfoForName:className];
}

+ (NSArray<NSString *> *)allClassNames {
    return [CDHeaderDumper allClassNames];
}

+ (NSArray<NSString *> *)searchClassNames:(NSString *)keyword {
    return [CDHeaderDumper searchClassNames:keyword];
}

+ (NSArray<NSString *> *)searchClassNames:(NSString *)keyword prefixMatch:(BOOL)prefixMatch {
    return [CDHeaderDumper searchClassNames:keyword prefixMatch:prefixMatch];
}

+ (NSArray<NSDictionary *> *)classNamesByImage {
    return [CDHeaderDumper allClassNamesByImage];
}

+ (NSArray<NSString *> *)recentClassNames {
    return [CDHeaderDumper recentClassNames];
}

+ (void)addToRecentClasses:(NSString *)className {
    [CDHeaderDumper addToRecentClasses:className];
}

+ (NSArray<NSString *> *)inheritanceChainForClass:(NSString *)className {
    return [CDHeaderDumper inheritanceChainForClass:className];
}

+ (NSString *)protocolHeaderForName:(NSString *)protocolName {
    return [CDHeaderDumper protocolHeaderForName:protocolName];
}

+ (NSArray<NSString *> *)allProtocolNames {
    return [CDHeaderDumper allProtocolNames];
}

@end
