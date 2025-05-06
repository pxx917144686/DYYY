// 遇到问题联系中文翻译作者：pxx917144686
//
//  OSCache.h
//
//  版本 1.2.1
//
//  由 Nick Lockwood 创建于 01/01/2014.
//  版权所有 (C) 2014 Charcoal Design
//
//  根据宽松的 zlib 许可证分发
//  从此获取最新版本：
//
//  https://github.com/nicklockwood/OSCache
//
//  本软件按“原样”提供，不作任何明示或暗示的保证。
//  在任何情况下，作者均不对因使用本软件而造成的任何损害承担责任。
//
//  允许任何人将本软件用于任何目的（包括商业应用），
//  并允许自由修改和重新分发，但须遵守以下限制：
//
//  1. 不得歪曲本软件的来源；您不得声称您编写了原始软件。如果您在产品中使用本软件，
//  则在产品文档中进行鸣谢将会受到赞赏，但并非必需。
//
//  2. 修改后的源代码版本必须明确标记，并且不得歪曲为原始软件。
//
//  3. 不得从任何源代码分发中删除或更改此声明。
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
