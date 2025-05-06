// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXSQLResult.h
//  FLEX
//
//  由 Tanner 创建于 3/3/20.
//  版权所有 © 2020 FLEX Team。保留所有权利。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FLEXSQLResult : NSObject

/// 描述非查询语句的结果，或任何类型查询的错误
+ (instancetype)message:(NSString *)message;
/// 描述已知执行失败的结果
+ (instancetype)error:(NSString *)message;

/// @param rowData 行列表，其中行中的每个元素
/// 对应于 /c columnNames 中给定的列
+ (instancetype)columns:(NSArray<NSString *> *)columnNames
                rows:(NSArray<NSArray<NSString *> *> *)rowData;

@property (nonatomic, readonly, nullable) NSString *message;

/// YES 值表示这肯定是一个错误，
/// 但即使值为 NO，它仍可能是一个错误
@property (nonatomic, readonly) BOOL isError;

/// 列名列表
@property (nonatomic, readonly, nullable) NSArray<NSString *> *columns;
/// 行列表，其中行中的每个元素对应于
/// \c columns 中相同索引处列的值。
///
/// 也就是说，给定一行，遍历该行的内容和
/// \c columns 的内容将为您提供该行列名到列值的键值对。
@property (nonatomic, readonly, nullable) NSArray<NSArray<NSString *> *> *rows;
/// 字段与列名配对的行列表。
///
/// 此属性是通过遍历其他两个属性中存在的行和列来延迟构造的。
@property (nonatomic, readonly, nullable) NSArray<NSDictionary<NSString *, id> *> *keyedRows;

@end

NS_ASSUME_NONNULL_END
