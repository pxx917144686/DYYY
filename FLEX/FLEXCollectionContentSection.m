//
//  FLEXCollectionContentSection.m
//  FLEX
//
//  创建者：Tanner Bennett，日期：8/28/19.
//  版权所有 © 2020 FLEX Team。保留所有权利。
//
// 遇到问题联系中文翻译作者：pxx917144686

#import "FLEXCollectionContentSection.h"
#import "FLEXUtility.h"
#import "FLEXRuntimeUtility.h"
#import "FLEXSubtitleTableViewCell.h"
#import "FLEXTableView.h"
#import "FLEXObjectExplorerFactory.h"
#import "FLEXDefaultEditorViewController.h"

typedef NS_ENUM(NSUInteger, FLEXCollectionType) {
    FLEXUnsupportedCollection,
    FLEXOrderedCollection,
    FLEXUnorderedCollection,
    FLEXKeyedCollection
};

@interface NSArray (FLEXCollection) <FLEXCollection> @end
@interface NSSet (FLEXCollection) <FLEXCollection> @end
@interface NSOrderedSet (FLEXCollection) <FLEXCollection> @end
@interface NSDictionary (FLEXCollection) <FLEXCollection> @end

@interface NSMutableArray (FLEXMutableCollection) <FLEXMutableCollection> @end
@interface NSMutableSet (FLEXMutableCollection) <FLEXMutableCollection> @end
@interface NSMutableOrderedSet (FLEXMutableCollection) <FLEXMutableCollection> @end
@interface NSMutableDictionary (FLEXMutableCollection) <FLEXMutableCollection>
- (void)filterUsingPredicate:(NSPredicate *)predicate;
@end

@interface FLEXCollectionContentSection ()
/// 从 \c collectionFuture 或 \c collection 生成
@property (nonatomic, copy) id<FLEXCollection> cachedCollection;
/// 要显示的静态集合
@property (nonatomic, readonly) id<FLEXCollection> collection;
/// 一个可能随时间变化并可以调用以获取新数据的集合
@property (nonatomic, readonly) FLEXCollectionContentFuture collectionFuture;
@property (nonatomic, readonly) FLEXCollectionType collectionType;
@property (nonatomic, readonly) BOOL isMutable;
@end

@implementation FLEXCollectionContentSection
@synthesize filterText = _filterText;

#pragma mark Initialization // 初始化

+ (instancetype)forObject:(id)object {
    return [self forCollection:object];
}

+ (id)forCollection:(id<FLEXCollection>)collection {
    FLEXCollectionContentSection *section = [self new];
    section->_collectionType = [self typeForCollection:collection];
    section->_collection = collection;
    section.cachedCollection = collection;
    section->_isMutable = [collection respondsToSelector:@selector(filterUsingPredicate:)];
    return section;
}

+ (id)forReusableFuture:(FLEXCollectionContentFuture)collectionFuture {
    FLEXCollectionContentSection *section = [self new];
    section->_collectionFuture = collectionFuture;
    section.cachedCollection = (id<FLEXCollection>)collectionFuture(section);
    section->_collectionType = [self typeForCollection:section.cachedCollection];
    section->_isMutable = [section->_cachedCollection respondsToSelector:@selector(filterUsingPredicate:)];
    return section;
}


#pragma mark - Misc // 其他

+ (FLEXCollectionType)typeForCollection:(id<FLEXCollection>)collection {
    // 这里的顺序很重要，因为 NSDictionary 是键控的，但它响应 allObjects
    if ([collection respondsToSelector:@selector(objectAtIndex:)]) {
        return FLEXOrderedCollection;
    }
    if ([collection respondsToSelector:@selector(objectForKey:)]) {
        return FLEXKeyedCollection;
    }
    if ([collection respondsToSelector:@selector(allObjects)]) {
        return FLEXUnorderedCollection;
    }

    [NSException raise:NSInvalidArgumentException
                format:@"给定的集合未正确遵循 FLEXCollection 协议"];
    return FLEXUnsupportedCollection;
}

/// 行标题
/// - 有序集合：索引
/// - 无序集合：对象
/// - 键控集合：键
- (NSString *)titleForRow:(NSInteger)row {
    switch (self.collectionType) {
        case FLEXOrderedCollection:
            if (!self.hideOrderIndexes) {
                return @(row).stringValue;
            }
            // 继续执行
        case FLEXUnorderedCollection:
            return [self describe:[self objectForRow:row]];
        case FLEXKeyedCollection:
            return [self describe:self.cachedCollection.allKeys[row]];

        case FLEXUnsupportedCollection:
            return nil;
    }
}

/// 行副标题
/// - 有序集合：对象
/// - 无序集合：无
/// - 键控集合：值
- (NSString *)subtitleForRow:(NSInteger)row {
    switch (self.collectionType) {
        case FLEXOrderedCollection:
            if (!self.hideOrderIndexes) {
                nil;
            }
            // 继续执行
        case FLEXKeyedCollection:
            return [self describe:[self objectForRow:row]];
        case FLEXUnorderedCollection:
            return nil;

        case FLEXUnsupportedCollection:
            return nil;
    }
}

- (NSString *)describe:(id)object {
    return [FLEXRuntimeUtility summaryForObject:object];
}

- (id)objectForRow:(NSInteger)row {
    switch (self.collectionType) {
        case FLEXOrderedCollection:
            return self.cachedCollection[row];
        case FLEXUnorderedCollection:
            return self.cachedCollection.allObjects[row];
        case FLEXKeyedCollection:
            return self.cachedCollection[self.cachedCollection.allKeys[row]];

        case FLEXUnsupportedCollection:
            return nil;
    }
}

- (UITableViewCellAccessoryType)accessoryTypeForRow:(NSInteger)row {
    return UITableViewCellAccessoryDisclosureIndicator;
//    return self.isMutable ? UITableViewCellAccessoryDetailDisclosureButton : UITableViewCellAccessoryDisclosureIndicator;
}


#pragma mark - Overrides // 覆盖方法

- (NSString *)title {
    if (!self.hideSectionTitle) {
        if (self.customTitle) {
            return self.customTitle;
        }
        
        return FLEXPluralString(self.cachedCollection.count, @"条目", @"条目");
    }
    
    return nil;
}

- (NSInteger)numberOfRows {
    return self.cachedCollection.count;
}

- (void)setFilterText:(NSString *)filterText {
    super.filterText = filterText;
    
    if (filterText.length) {
        BOOL (^matcher)(id, id) = self.customFilter ?: ^BOOL(NSString *query, id obj) {
            return [[self describe:obj] localizedCaseInsensitiveContainsString:query];
        };
        
        NSPredicate *filter = [NSPredicate predicateWithBlock:^BOOL(id obj, NSDictionary *bindings) {
            return matcher(filterText, obj);
        }];
        
        id<FLEXMutableCollection> tmp = self.cachedCollection.mutableCopy;
        [tmp filterUsingPredicate:filter];
        self.cachedCollection = tmp;
    } else {
        self.cachedCollection = self.collection ?: (id<FLEXCollection>)self.collectionFuture(self);
    }
}

- (void)reloadData {
    if (self.collectionFuture) {
        self.cachedCollection = (id<FLEXCollection>)self.collectionFuture(self);
    } else {
        self.cachedCollection = self.collection.copy; // 如果 collection 为 nil，这里可能会崩溃。确保 collection 已初始化。
    }
}

- (BOOL)canSelectRow:(NSInteger)row {
    return YES;
}

- (UIViewController *)viewControllerToPushForRow:(NSInteger)row {
    return [FLEXObjectExplorerFactory explorerViewControllerForObject:[self objectForRow:row]];
}

- (NSString *)reuseIdentifierForRow:(NSInteger)row {
    return kFLEXDetailCell;
}

- (void)configureCell:(__kindof FLEXTableViewCell *)cell forRow:(NSInteger)row {
    cell.titleLabel.text = [self titleForRow:row];
    cell.subtitleLabel.text = [self subtitleForRow:row];
    cell.accessoryType = [self accessoryTypeForRow:row];
}

@end


#pragma mark - NSMutableDictionary // NSMutableDictionary 分类

@implementation NSMutableDictionary (FLEXMutableCollection)

- (void)filterUsingPredicate:(NSPredicate *)predicate {
    id test = ^BOOL(id key, NSUInteger idx, BOOL *stop) {
        if ([predicate evaluateWithObject:key]) {
            return NO;
        }
        
        return ![predicate evaluateWithObject:self[key]];
    };
    
    NSArray *keys = self.allKeys;
    NSIndexSet *remove = [keys indexesOfObjectsPassingTest:test];
    
    [self removeObjectsForKeys:[keys objectsAtIndexes:remove]];
}

@end
