//
//  FLEXCollectionContentSection.h
//  FLEX
//
//  创建者：Tanner Bennett，日期：8/28/19.
//  版权所有 © 2020 FLEX Team。保留所有权利。
//
// 遇到问题联系中文翻译作者：pxx917144686

#import "FLEXTableViewSection.h"
#import "FLEXObjectInfoSection.h"
@class FLEXCollectionContentSection, FLEXTableViewCell;
@protocol FLEXCollection, FLEXMutableCollection;

/// 任何 foundation 集合都隐式遵循 FLEXCollection。
/// 这个 future 应该返回一个。我们没有在这里显式地写 FLEXCollection，
/// 因为让泛型集合遵循 FLEXCollection 会破坏泛型数组的编译时特性，
/// 例如 \c someArray[0].property
typedef id<NSObject, NSFastEnumeration /* FLEXCollection */>(^FLEXCollectionContentFuture)(__kindof FLEXCollectionContentSection *section);

#pragma mark Collection // 集合
/// 一个协议，使 \c FLEXCollectionContentSection 能够对任何任意集合进行操作。
/// \c NSArray、\c NSDictionary、\c NSSet 和 \c NSOrderedSet 都遵循此协议。
@protocol FLEXCollection <NSObject, NSFastEnumeration>

@property (nonatomic, readonly) NSUInteger count;

- (id)copy;
- (id)mutableCopy;

@optional

/// 无序、非键控集合必须实现此方法
@property (nonatomic, readonly) NSArray *allObjects;
/// 键控集合必须实现此方法和 \c objectForKeyedSubscript:
@property (nonatomic, readonly) NSArray *allKeys;

/// 有序、索引集合必须实现此方法。
- (id)objectAtIndexedSubscript:(NSUInteger)idx;
/// 键控、无序集合必须实现此方法和 \c allKeys
- (id)objectForKeyedSubscript:(id)idx;

@end

@protocol FLEXMutableCollection <FLEXCollection>
- (void)filterUsingPredicate:(NSPredicate *)predicate;
@end


#pragma mark - FLEXCollectionContentSection // FLEXCollectionContentSection 类
/// 用于查看集合元素的自定义部分。
///
/// 点击某一行会为该元素推送一个对象浏览器。
@interface FLEXCollectionContentSection<__covariant ObjectType> : FLEXTableViewSection <FLEXObjectInfoSection> {
    @protected
    /// 如果使用 future 初始化，则未使用
    id<FLEXCollection> _collection;
    /// 如果使用集合初始化，则未使用
    FLEXCollectionContentFuture _collectionFuture;
    /// 来自 \c _collection 或 \c _collectionFuture 的已过滤集合
    id<FLEXCollection> _cachedCollection;
}

+ (instancetype)forCollection:(id)collection;
/// 给定的 future 应该可以安全地多次调用。
/// 如果数据本质上是变化的，则多次调用此 future 的结果每次可能会产生不同的结果。
+ (instancetype)forReusableFuture:(FLEXCollectionContentFuture)collectionFuture;

/// 默认为 \c NO
@property (nonatomic) BOOL hideSectionTitle;
/// 默认为 \c nil
@property (nonatomic, copy) NSString *customTitle;
/// 默认为 \c NO
///
/// 将此设置为 \c NO 将不会显示有序集合的元素索引。
/// 此属性仅适用于 \c NSArray 或 \c NSOrderedSet 及其子类。
@property (nonatomic) BOOL hideOrderIndexes;

/// 设置此属性以提供自定义的过滤器匹配器。
///
/// 默认情况下，集合将根据行的标题和副标题进行过滤。
/// 因此，例如，如果您从不调用 \c configureCell:，则需要设置
/// 此属性，以便您的过滤逻辑与您设置单元格的方式相匹配。
@property (nonatomic) BOOL (^customFilter)(NSString *filterText, ObjectType element);

/// 获取与给定行关联的集合中的对象。
/// 对于字典，这返回的是值，而不是键。
- (ObjectType)objectForRow:(NSInteger)row;

/// 子类可以覆盖。
- (UITableViewCellAccessoryType)accessoryTypeForRow:(NSInteger)row;

@end
