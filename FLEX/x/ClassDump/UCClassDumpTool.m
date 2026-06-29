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

+ (NSArray<NSString *> *)allClassNames {
    return [CDHeaderDumper allClassNames];
}

+ (NSArray<NSString *> *)searchClassNames:(NSString *)keyword {
    return [CDHeaderDumper searchClassNames:keyword];
}

+ (NSArray<NSDictionary *> *)classNamesByImage {
    return [CDHeaderDumper allClassNamesByImage];
}

@end
