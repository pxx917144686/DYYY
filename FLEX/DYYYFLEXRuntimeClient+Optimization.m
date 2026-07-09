//
//  DYYYFLEXRuntimeClient+Optimization.m
//  FLEX
//
//  Created from RuntimeBrowser functionalities.
//

#import "DYYYFLEXRuntimeClient+Optimization.h"

@implementation DYYYFLEXRuntimeClient (Optimization)

+ (BOOL)isRuntimeReady {
    // 使用公共的 imageDisplayNames 属性代替私有的 imagePaths
    return DYYYFLEXRuntimeClient.runtime.imageDisplayNames.count > 0;
}

+ (void)ensureRuntimeInitialized {
    DYYYFLEXRuntimeClient *runtime = DYYYFLEXRuntimeClient.runtime;
    // 使用公共的 imageDisplayNames 属性代替私有的 imagePaths
    if (runtime.imageDisplayNames.count == 0) {
        [runtime reloadLibrariesList];
    }
}

- (void)reloadLibrariesListAsync:(void(^)(BOOL success))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @try {
            [self reloadLibrariesList];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(YES);
            });
        } @catch (NSException *exception) {
            NSLog(@"FLEX: 加载运行时信息失败 - %@", exception.reason);
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(NO);
            });
        }
    });
}

@end