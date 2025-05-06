// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXRuntimeSafety.h
//  FLEX
//
//  由 Tanner 创建于 3/25/17.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#pragma mark - 类

extern NSUInteger const kFLEXKnownUnsafeClassCount;
extern const Class * FLEXKnownUnsafeClassList(void);
extern NSSet * FLEXKnownUnsafeClassNames(void);
extern CFSetRef FLEXKnownUnsafeClasses;

static Class cNSObject = nil, cNSProxy = nil;

__attribute__((constructor))
static void FLEXInitKnownRootClasses(void) {
    cNSObject = [NSObject class];
    cNSProxy = [NSProxy class];
}

static inline BOOL FLEXClassIsSafe(Class cls) {
    // 它是否为 nil 或已知不安全？
    if (!cls || CFSetContainsValue(FLEXKnownUnsafeClasses, (__bridge void *)cls)) {
        return NO;
    }
    
    // 它是否是已知的根类？
    if (!class_getSuperclass(cls)) {
        return cls == cNSObject || cls == cNSProxy;
    }
    
    // 可能安全
    return YES;
}

static inline BOOL FLEXClassNameIsSafe(NSString *cls) {
    if (!cls) return NO;
    
    NSSet *ignored = FLEXKnownUnsafeClassNames();
    return ![ignored containsObject:cls];
}

#pragma mark - 实例变量

extern CFSetRef FLEXKnownUnsafeIvars;

static inline BOOL FLEXIvarIsSafe(Ivar ivar) {
    if (!ivar) return NO;

    return !CFSetContainsValue(FLEXKnownUnsafeIvars, ivar);
}
