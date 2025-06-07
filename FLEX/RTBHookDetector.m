#import "RTBHookDetector.h"
#import <objc/runtime.h>
#import <dlfcn.h>

@implementation RTBHookDetector

+ (instancetype)sharedDetector {
    static RTBHookDetector *detector = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        detector = [[self alloc] init];
    });
    return detector;
}

- (NSDictionary *)getAllHookedMethods {
    NSMutableDictionary *hookedMethods = [NSMutableDictionary dictionary];
    
    unsigned int classCount = 0;
    Class *classes = objc_copyClassList(&classCount);
    
    for (unsigned int i = 0; i < classCount; i++) {
        Class cls = classes[i];
        NSArray *hookedInClass = [self getHookedMethodsForClass:cls];
        
        if (hookedInClass.count > 0) {
            hookedMethods[NSStringFromClass(cls)] = hookedInClass;
        }
    }
    
    free(classes);
    return hookedMethods;
}

- (NSArray *)getHookedMethodsForClass:(Class)cls {
    NSMutableArray *hooked = [NSMutableArray array];
    
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList(cls, &methodCount);
    
    for (unsigned int i = 0; i < methodCount; i++) {
        Method method = methods[i];
        SEL selector = method_getName(method);
        
        if ([self isMethodHooked:selector inClass:cls]) {
            IMP implementation = method_getImplementation(method);
            
            [hooked addObject:@{
                @"selector": NSStringFromSelector(selector),
                @"implementation": [NSString stringWithFormat:@"%p", implementation],
                @"encoding": @(method_getTypeEncoding(method))
            }];
        }
    }
    
    free(methods);
    return hooked;
}

- (BOOL)isMethodHooked:(SEL)selector inClass:(Class)cls {
    Method method = class_getInstanceMethod(cls, selector);
    if (!method) return NO;
    
    IMP imp = method_getImplementation(method);
    IMP originalImp = class_getMethodImplementation(cls, selector);
    
    // 检查实现是否不同
    if (imp != originalImp) return YES;
    
    // 检查实现地址是否在可疑区域
    Dl_info info;
    if (dladdr((void *)imp, &info)) {
        NSString *imageName = @(info.dli_fname);
        
        // 检查是否来自Hook框架
        NSArray *hookFrameworks = @[@"fishhook", @"substrate", @"substitute", @"frida"];
        for (NSString *framework in hookFrameworks) {
            if ([imageName.lowercaseString containsString:framework]) {
                return YES;
            }
        }
    }
    
    return NO;
}

- (NSDictionary *)getAllSwizzledMethods {
    // 检测方法交换的高级逻辑
    NSMutableDictionary *swizzled = [NSMutableDictionary dictionary];
    
    // 这里需要更复杂的检测逻辑
    // 比如检查方法表的修改等
    
    return swizzled;
}

- (NSArray *)getKnownHookingFrameworks {
    NSMutableArray *frameworks = [NSMutableArray array];
    
    NSArray *knownFrameworks = @[
        @"libfishhook.dylib",
        @"CydiaSubstrate.framework",
        @"substitute.dylib",
        @"frida-agent.dylib",
        @"Aspects.framework"
    ];
    
    for (NSString *framework in knownFrameworks) {
        void *handle = dlopen(framework.UTF8String, RTLD_NOLOAD);
        if (handle) {
            [frameworks addObject:@{
                @"name": framework,
                @"loaded": @YES
            }];
            dlclose(handle);
        }
    }
    
    return frameworks;
}

@end