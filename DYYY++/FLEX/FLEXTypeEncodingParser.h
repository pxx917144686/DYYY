//
//  FLEXTypeEncodingParser.h
//  FLEX
//
//  由 Tanner Bennett 创建于 8/22/19.
//  版权所有 © 2020 FLEX Team. 保留所有权利。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// @return 如果类型被支持则返回 \c YES，否则返回 \c NO
BOOL FLEXGetSizeAndAlignment(const char *type, NSUInteger * _Nullable sizep, NSUInteger * _Nullable alignp);

@interface FLEXTypeEncodingParser : NSObject

/// \c cleanedEncoding 是必要的，因为类型编码可能包含指向
/// 不支持类型的指针。\c NSMethodSignature 会将每个类型传给 \c NSGetSizeAndAlignment，
/// 而后者会在不支持的结构体指针上抛出异常，这个异常会被
/// \c NSMethodSignature 捕获，但它仍然会打扰到任何使用 \c objc_exception_throw 进行调试的人
///
/// @param cleanedEncoding 可以传递给 \c NSMethodSignature 的"安全"类型编码
/// @return 给定的类型编码是否可以传递给
/// \c NSMethodSignature 而不会导致它抛出异常。
+ (BOOL)methodTypeEncodingSupported:(NSString *)typeEncoding cleaned:(NSString *_Nonnull*_Nullable)cleanedEncoding;

/// @return 方法类型编码字符串中单个参数的类型编码。
/// 传入 0 可获取返回值的类型。1 和 2 分别是 `self` 和 `_cmd`。
+ (NSString *)type:(NSString *)typeEncoding forMethodArgumentAtIndex:(NSUInteger)idx;

/// @return 方法类型编码字符串中单个参数类型的字节大小。
/// 传入 0 可获取返回值的大小。1 和 2 分别是 `self` 和 `_cmd`。
+ (ssize_t)size:(NSString *)typeEncoding forMethodArgumentAtIndex:(NSUInteger)idx;

/// @param unaligned 是否计算未对齐或已对齐的大小。
/// @return 字节大小，如果类型编码不支持则返回 \c -1。
/// 不要传入 \c method_getTypeEncoding 的结果
+ (ssize_t)sizeForTypeEncoding:(NSString *)type alignment:(nullable ssize_t *)alignOut unaligned:(BOOL)unaligned;

/// 默认为 \C unaligned:NO
+ (ssize_t)sizeForTypeEncoding:(NSString *)type alignment:(nullable ssize_t *)alignOut;

@end

NS_ASSUME_NONNULL_END
