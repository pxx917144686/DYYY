// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXTypeEncodingParser.h
//  FLEX
//
//  由 Tanner Bennett 创建于 8/22/19.
//  版权所有 © 2020 FLEX Team。保留所有权利。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// @return 如果类型受支持，则为 \c YES，否则为 \c NO
BOOL FLEXGetSizeAndAlignment(const char *type, NSUInteger * _Nullable sizep, NSUInteger * _Nullable alignp);

@interface FLEXTypeEncodingParser : NSObject

/// \c cleanedEncoding 是必需的，因为类型编码可能包含指向不受支持类型的指针。
/// \c NSMethodSignature 会将每个类型传递给 \c NSGetSizeAndAlignment，
/// 这会在不受支持的结构体指针上引发异常，并且此异常会被 \c NSMethodSignature 捕获，
/// 但它仍然会困扰任何使用 \c objc_exception_throw 进行调试的人。
///
/// @param cleanedEncoding 您可以传递给 \c NSMethodSignature 的“安全”类型编码
/// @return 给定的类型编码是否可以传递给
/// \c NSMethodSignature 而不引发异常。
+ (BOOL)methodTypeEncodingSupported:(NSString *)typeEncoding cleaned:(NSString *_Nonnull*_Nullable)cleanedEncoding;

/// @return 方法类型编码字符串中单个参数的类型编码。
/// 传递 0 以获取返回值的类型。1 和 2 分别是 `self` 和 `_cmd`。
+ (NSString *)type:(NSString *)typeEncoding forMethodArgumentAtIndex:(NSUInteger)idx;

/// @return 方法类型编码字符串中单个参数的类型的大小（以字节为单位）。
/// 传递 0 以获取返回值的大小。1 和 2 分别是 `self` 和 `_cmd`。
+ (ssize_t)size:(NSString *)typeEncoding forMethodArgumentAtIndex:(NSUInteger)idx;

/// @param unaligned 是否计算对齐或未对齐的大小。
/// @return 大小（以字节为单位），如果类型编码不受支持，则为 \c -1。
/// 不要传入 \c method_getTypeEncoding 的结果
+ (ssize_t)sizeForTypeEncoding:(NSString *)type alignment:(nullable ssize_t *)alignOut unaligned:(BOOL)unaligned;

/// 默认为 \C unaligned:NO
+ (ssize_t)sizeForTypeEncoding:(NSString *)type alignment:(nullable ssize_t *)alignOut;

@end

NS_ASSUME_NONNULL_END
