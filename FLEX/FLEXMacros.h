// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXMacros.h
//  FLEX
//
//  由 Tanner 创建于 3/12/20.
//  版权所有 © 2020 FLEX Team。保留所有权利。
//

#ifndef FLEXMacros_h
#define FLEXMacros_h

#ifndef __cplusplus
#ifndef auto
#define auto __auto_type
#endif
#endif

#define flex_keywordify class NSObject;
#define ctor flex_keywordify __attribute__((constructor)) void __flex_ctor_##__LINE__()
#define dtor flex_keywordify __attribute__((destructor)) void __flex_dtor_##__LINE__()

#ifndef strongify

#define weakify(var) __weak __typeof(var) __weak__##var = var;

#define strongify(var) \
_Pragma("clang diagnostic push") \
_Pragma("clang diagnostic ignored \"-Wshadow\"") \
__strong typeof(var) var = __weak__##var; \
_Pragma("clang diagnostic pop")

#endif

// 一个用于检查我们是否在测试环境中运行的宏
#define FLEX_IS_TESTING() (NSClassFromString(@"XCTest") != nil)

/// 我们是否希望大多数构造函数在加载时运行。
extern BOOL FLEXConstructorsShouldRun(void);

/// 一个用于在我们不希望运行构造函数时从当前过程返回的宏
#define FLEX_EXIT_IF_NO_CTORS() if (!FLEXConstructorsShouldRun()) return;

/// 向下取整到最近的“点”坐标
NS_INLINE CGFloat FLEXFloor(CGFloat x) {
    return floor(UIScreen.mainScreen.scale * (x)) / UIScreen.mainScreen.scale;
}

/// 返回给定点数的像素值
NS_INLINE CGFloat FLEXPointsToPixels(CGFloat points) {
    return points / UIScreen.mainScreen.scale;
}

/// 创建一个 CGRect，其所有成员都向下取整到最近的“点”坐标
NS_INLINE CGRect FLEXRectMake(CGFloat x, CGFloat y, CGFloat width, CGFloat height) {
    return CGRectMake(FLEXFloor(x), FLEXFloor(y), FLEXFloor(width), FLEXFloor(height));
}

/// 调整现有矩形的原点
NS_INLINE CGRect FLEXRectSetOrigin(CGRect r, CGPoint origin) {
    r.origin = origin; return r;
}

/// 调整现有矩形的大小
NS_INLINE CGRect FLEXRectSetSize(CGRect r, CGSize size) {
    r.size = size; return r;
}

/// 调整现有矩形的 origin.x
NS_INLINE CGRect FLEXRectSetX(CGRect r, CGFloat x) {
    r.origin.x = x; return r;
}

/// 调整现有矩形的 origin.y
NS_INLINE CGRect FLEXRectSetY(CGRect r, CGFloat y) {
    r.origin.y = y ; return r;
}

/// 调整现有矩形的 size.width
NS_INLINE CGRect FLEXRectSetWidth(CGRect r, CGFloat width) {
    r.size.width = width; return r;
}

/// 调整现有矩形的 size.height
NS_INLINE CGRect FLEXRectSetHeight(CGRect r, CGFloat height) {
    r.size.height = height; return r;
}

#define FLEXPluralString(count, plural, singular) [NSString \
    stringWithFormat:@"%@ %@", @(count), (count == 1 ? singular : plural) \
]

#define FLEXPluralFormatString(count, pluralFormat, singularFormat) [NSString \
    stringWithFormat:(count == 1 ? singularFormat : pluralFormat), @(count)  \
]

#define flex_dispatch_after(nSeconds, onQueue, block) \
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, \
    (int64_t)(nSeconds * NSEC_PER_SEC)), onQueue, block)

#endif /* FLEXMacros_h */
