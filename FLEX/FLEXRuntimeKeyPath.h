// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXRuntimeKeyPath.h
//  FLEX
//
//  由 Tanner 创建于 3/22/17.
//  版权所有 © 2017 Tanner Bennett。保留所有权利。
//

#import "FLEXSearchToken.h"

NS_ASSUME_NONNULL_BEGIN

/// 键路径表示对一组 bundle 或类中一个或多个方法的查询。
/// 它由三个标记组成：bundle、class 和 method。如果缺少任何标记，
/// 则键路径可能不完整。如果所有标记都没有选项，并且 methodKey.string
/// 以 + 或 - 开头，则认为键路径是“绝对的”。
///
/// @code TBKeyPathTokenizer @endcode 类用于从字符串创建键路径。
@interface FLEXRuntimeKeyPath : NSObject

+ (instancetype)empty;

/// @param method 必须以通配符、+ 或 - 开头。
+ (instancetype)bundle:(FLEXSearchToken *)bundle
                 class:(FLEXSearchToken *)cls
                method:(FLEXSearchToken *)method
            isInstance:(NSNumber *)instance
                string:(NSString *)keyPathString;

@property (nonatomic, nullable, readonly) FLEXSearchToken *bundleKey;
@property (nonatomic, nullable, readonly) FLEXSearchToken *classKey;
@property (nonatomic, nullable, readonly) FLEXSearchToken *methodKey;

/// 指示方法标记是否指定实例方法。
/// 如果未指定，则为 Nil。
@property (nonatomic, nullable, readonly) NSNumber *instanceMethods;

@end
NS_ASSUME_NONNULL_END
