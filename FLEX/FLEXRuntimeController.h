// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXRuntimeController.h
//  FLEX
//
//  由 Tanner 创建于 3/23/17.
//  版权所有 © 2017 Tanner Bennett。保留所有权利。
//

#import "FLEXRuntimeKeyPath.h"
#import "FLEXSearchToken.h"

@class FLEXMethod; // 添加前向声明

/// 包装 FLEXRuntimeClient 并提供额外的缓存机制
@interface FLEXRuntimeController : NSObject

/// @return 如果键路径仅解析为类或 bundle，则返回字符串数组；
///         否则，返回 FLEXMethods 的列表的列表。
+ (NSArray *)dataForKeyPath:(FLEXRuntimeKeyPath *)keyPath;

/// 当您需要指定在哪些类中搜索时很有用。
/// \c dataForKeyPath: 将仅搜索与类键匹配的类。
/// 当我们需要搜索类层次结构时，我们在其他地方使用它。
+ (NSArray<NSArray<FLEXMethod *> *> *)methodsForToken:(FLEXSearchToken *)token
                                             instance:(NSNumber *)onlyInstanceMethods
                                            inClasses:(NSArray<NSString*> *)classes;

/// 当您需要与从 \c dataForKeyPath 返回的方法的双重列表相关联的类时很有用
+ (NSMutableArray<NSString *> *)classesForKeyPath:(FLEXRuntimeKeyPath *)keyPath;

+ (NSString *)shortBundleNameForClass:(NSString *)name;

+ (NSString *)imagePathWithShortName:(NSString *)suffix;

/// 返回短名称。例如，“Foundation.framework”
+ (NSArray<NSString*> *)allBundleNames;

@end
