//
//  FLEXHookDetector.m
//  FLEX
//
//  Created from RuntimeBrowser functionalities.
//

#import "FLEXHookDetector.h"
#import <dlfcn.h>
#import <mach-o/dyld.h>

@implementation FLEXHookDetector

+ (instancetype)sharedDetector {
    static FLEXHookDetector *detector = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        detector = [[self alloc] init];
    });
    return detector;
}

- (BOOL)isMethodHooked:(Method)method ofClass:(Class)cls {
    if (!method || !cls) return NO;
    
    SEL selector = method_getName(method);
    IMP imp = class_getMethodImplementation(cls, selector);
    IMP originalImp = method_getImplementation(method);
    
    // 从 RTBHookDetector 移植的检测逻辑
    
    // 检查 IMP 地址是否在可执行段外
    Dl_info info;
    if (dladdr((void *)imp, &info)) {
        // 如果 IMP 不在原始库中，可能被 hook
        if (strstr(info.dli_fname, "hook") || strstr(info.dli_fname, "substrate")) {
            return YES;
        }
    }
    
    // 检查方法实现是否被替换
    return (imp != originalImp);
}

- (NSArray *)getHookedMethodsForClass:(Class)cls {
    if (!cls) return @[];
    
    NSMutableArray *hookedMethods = [NSMutableArray array];
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList(cls, &methodCount);
    
    for (unsigned int i = 0; i < methodCount; i++) {
        Method method = methods[i];
        if ([self isMethodHooked:method ofClass:cls]) {
            SEL selector = method_getName(method);
            IMP imp = class_getMethodImplementation(cls, selector);
            IMP originalImp = method_getImplementation(method);
            
            // 从 RTB 移植的详细信息收集
            Dl_info hookInfo;
            NSString *hookLocation = @"Unknown";
            if (dladdr((void *)imp, &hookInfo) && hookInfo.dli_fname) {
                hookLocation = @(hookInfo.dli_fname);
            }
            
            [hookedMethods addObject:@{
                @"selector": NSStringFromSelector(selector),
                @"currentAddress": [NSString stringWithFormat:@"%p", imp],
                @"originalAddress": [NSString stringWithFormat:@"%p", originalImp],
                @"hookLocation": hookLocation,
                @"typeEncoding": @(method_getTypeEncoding(method) ?: "")
            }];
        }
    }
    
    free(methods);
    return hookedMethods;
}

- (NSDictionary *)getAllHookedMethods {
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    
    unsigned int classCount = 0;
    Class *classes = objc_copyClassList(&classCount);
    
    for (unsigned int i = 0; i < classCount; i++) {
        Class cls = classes[i];
        NSArray *hookedMethods = [self getHookedMethodsForClass:cls];
        
        if (hookedMethods.count > 0) {
            result[NSStringFromClass(cls)] = hookedMethods;
        }
    }
    
    free(classes);
    return result;
}

@end