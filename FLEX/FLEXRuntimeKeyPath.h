//
//  FLEXRuntimeKeyPath.h
//  FLEX
//
//  由 Tanner 创建于 3/22/17.
//  版权所有 © 2017 Tanner Bennett. 保留所有权利。
//

#import "FLEXSearchToken.h"
@class FLEXMethod;

NS_ASSUME_NONNULL_BEGIN

/// 键路径表示对一组包或类的查询，
/// 用于获取一组或多组方法。它由三个标记组成：
/// 包、类和方法。如果缺少任何标记，
/// 键路径可能不完整。如果所有标记都没有选项，
/// 且 methodKey.string 以 + 或 - 开头，
/// 则键路径被视为"绝对路径"。
///
/// @code TBKeyPathTokenizer @endcode 类用于
/// 从字符串创建键路径。
@interface FLEXRuntimeKeyPath : NSObject

+ (instancetype)empty;

/// @param method 必须以通配符或 + 或 - 开头。
+ (instancetype)bundle:(FLEXSearchToken *)bundle
                 class:(FLEXSearchToken *)cls
                method:(FLEXSearchToken *)method
            isInstance:(NSNumber *)instance
                string:(NSString *)keyPathString;

@property (nonatomic, nullable, readonly) FLEXSearchToken *bundleKey;
@property (nonatomic, nullable, readonly) FLEXSearchToken *classKey;
@property (nonatomic, nullable, readonly) FLEXSearchToken *methodKey;

/// 指示方法标记是否指定实例方法。
/// 如果未指定则为 Nil。
@property (nonatomic, nullable, readonly) NSNumber *instanceMethods;

@end
NS_ASSUME_NONNULL_END
