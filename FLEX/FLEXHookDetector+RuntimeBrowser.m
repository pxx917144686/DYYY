#import "FLEXHookDetector+RuntimeBrowser.h"
#import <dlfcn.h>

@implementation FLEXHookDetector (RuntimeBrowser)

- (NSDictionary *)getDetailedHookAnalysis {
    NSMutableDictionary *analysis = [NSMutableDictionary dictionary];
    
    // 基础 Hook 信息
    analysis[@"hookedMethods"] = [self getAllHookedMethods];
    
    // 检测已知的 Hook 框架
    analysis[@"hookingFrameworks"] = [self getKnownHookingFrameworks];
    
    // 统计信息
    NSUInteger totalHookedMethods = 0;
    for (NSString *className in analysis[@"hookedMethods"]) {
        NSArray *methods = analysis[@"hookedMethods"][className];
        totalHookedMethods += methods.count;
    }
    
    analysis[@"statistics"] = @{
        @"totalHookedClasses": @([analysis[@"hookedMethods"] count]),
        @"totalHookedMethods": @(totalHookedMethods)
    };
    
    // 检测方法交换
    analysis[@"methodSwizzling"] = [self detectMethodSwizzling];
    
    return analysis;
}

- (NSArray *)getSwizzledMethodsForClass:(Class)cls {
    NSMutableArray *swizzled = [NSMutableArray array];
    
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList(cls, &methodCount);
    
    for (unsigned int i = 0; i < methodCount; i++) {
        Method method = methods[i];
        SEL selector = method_getName(method);
        
        if ([self isMethodSwizzled:selector inClass:cls]) {
            [swizzled addObject:@{
                @"selector": NSStringFromSelector(selector),
                @"originalIMP": [NSString stringWithFormat:@"%p", method_getImplementation(method)]
            }];
        }
    }
    
    free(methods);
    return swizzled;
}

- (BOOL)isMethodSwizzled:(SEL)selector inClass:(Class)cls {
    Method method = class_getInstanceMethod(cls, selector);
    if (!method) return NO;
    
    IMP imp = method_getImplementation(method);
    IMP classImp = class_getMethodImplementation(cls, selector);
    
    // 检查实现是否被替换
    return imp != classImp;
}

- (NSArray *)getKnownHookingFrameworks {
    NSMutableArray *frameworks = [NSMutableArray array];
    
    // 检测常见的 Hook 框架
    NSArray *knownFrameworks = @[
        @"fishhook",
        @"MSHookFunction",
        @"CydiaSubstrate",
        @"libffi",
        @"Aspects"
    ];
    
    for (NSString *framework in knownFrameworks) {
        void *handle = dlopen(framework.UTF8String, RTLD_NOLOAD);
        if (handle) {
            [frameworks addObject:@{
                @"name": framework,
                @"loaded": @YES,
                @"path": @(dladdr(handle, NULL) ? "" : "unknown")
            }];
            dlclose(handle);
        }
    }
    
    return frameworks;
}

- (NSDictionary *)detectMethodSwizzling {
    NSMutableDictionary *swizzling = [NSMutableDictionary dictionary];
    
    // 检查常见的被 Swizzle 的类
    NSArray *commonTargets = @[
        @"UIViewController",
        @"UIView",
        @"NSObject",
        @"UIApplication",
        @"NSURLSession"
    ];
    
    for (NSString *className in commonTargets) {
        Class cls = NSClassFromString(className);
        if (cls) {
            NSArray *swizzledMethods = [self getSwizzledMethodsForClass:cls];
            if (swizzledMethods.count > 0) {
                swizzling[className] = swizzledMethods;
            }
        }
    }
    
    return swizzling;
}

@end