//
//  OSCache.h
//
//  版本 1.2.1
//
//  由 Nick Lockwood 创建于 01/01/2014.
//  版权所有 (C) 2014 Charcoal Design
//
//  基于宽松的zlib许可证分发
//  从这里获取最新版本:
//
//  https://github.com/nicklockwood/OSCache
//
//  本软件按"原样"提供，不提供任何明示或暗示的
//  保证。在任何情况下，作者均不对因使用本软件而产生
//  的任何损害负责。
//
//  允许任何人出于任何目的使用本软件，
//  包括商业应用，以及修改和重新分发，
//  但须遵守以下限制:
//
//  1. 不得歪曲本软件的来源；不得
//  声称您编写了原始软件。如果您在产品中使用本软件，
//  在产品文档中致谢将不胜感激，但并非必需。
//
//  2. 修改后的源代码版本必须明确标记为已修改，且不得
//  谎称其为原始软件。
//
//  3. 本声明不得从任何源代码分发中删除或更改。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface OSCache <KeyType, ObjectType> : NSCache <NSFastEnumeration>

@property (nonatomic, readonly) NSUInteger count;
@property (nonatomic, readonly) NSUInteger totalCost;

- (id)objectForKeyedSubscript:(KeyType <NSCopying>)key;
- (void)setObject:(ObjectType)obj forKeyedSubscript:(KeyType <NSCopying>)key;
- (void)enumerateKeysAndObjectsUsingBlock:(void (^)(KeyType key, ObjectType obj, BOOL *stop))block;

@end


@protocol OSCacheDelegate <NSCacheDelegate>
@optional

- (BOOL)cache:(OSCache *)cache shouldEvictObject:(id)entry;
- (void)cache:(OSCache *)cache willEvictObject:(id)entry;

@end

NS_ASSUME_NONNULL_END
