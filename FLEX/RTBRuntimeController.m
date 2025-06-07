#import "RTBRuntimeController.h"
#import "RTBSearchToken.h"
#import <objc/runtime.h>

@implementation RTBRuntimeController

+ (instancetype)sharedController {
    static RTBRuntimeController *controller = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        controller = [[self alloc] init];
    });
    return controller;
}

- (NSArray *)allBundleNames {
    NSMutableArray *bundleNames = [NSMutableArray array];
    
    unsigned int imageCount = 0;
    const char **imageNames = objc_copyImageNames(&imageCount);
    
    if (imageNames) {
        for (unsigned int i = 0; i < imageCount; i++) {
            NSString *imagePath = @(imageNames[i]);
            NSString *bundleName = [imagePath lastPathComponent];
            [bundleNames addObject:bundleName];
        }
        free(imageNames);
    }
    
    return [bundleNames sortedArrayUsingSelector:@selector(compare:)];
}

- (NSArray *)classesForToken:(RTBSearchToken *)token inBundles:(NSArray *)bundles {
    NSMutableArray *classes = [NSMutableArray array];
    
    if (bundles && bundles.count > 0) {
        // 从指定Bundle获取类
        for (NSString *bundlePath in bundles) {
            unsigned int classCount = 0;
            const char **classNames = objc_copyClassNamesForImage(bundlePath.UTF8String, &classCount);
            
            if (classNames) {
                for (unsigned int i = 0; i < classCount; i++) {
                    NSString *className = @(classNames[i]);
                    if ([token matchesString:className]) {
                        [classes addObject:className];
                    }
                }
                free(classNames);
            }
        }
    } else {
        // 获取所有类
        unsigned int classCount = 0;
        Class *allClasses = objc_copyClassList(&classCount);
        
        for (unsigned int i = 0; i < classCount; i++) {
            NSString *className = NSStringFromClass(allClasses[i]);
            if ([token matchesString:className]) {
                [classes addObject:className];
            }
        }
        
        free(allClasses);
    }
    
    return [classes sortedArrayUsingSelector:@selector(compare:)];
}

@end