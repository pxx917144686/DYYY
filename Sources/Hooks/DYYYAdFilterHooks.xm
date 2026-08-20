//
//  DYYYAdFilterHooks.xm
//  DYYY
//
//  列表数据源广告过滤 hook（拆分自 DYYY.xm）。
//

#import "DYYYMainHooksShared.h"

// 前向声明：%new 方法编译时可见性
@interface AWEAwemeModel (DYYYFilterPrivate)
- (BOOL)contentFilter;
@end

#pragma mark - DataController 广告过滤

// 过滤结果标记：getter 命中标记时跳过 O(n) 全量过滤。
// 快照 = count + 首/尾元素指针：同 count 换内容(下拉刷新同条数替换)时首尾指针变化，标记失效重滤
static char kDYYYAdFilteredMarkKey;

static void DYYYMarkAdFiltered(NSArray *array) {
    if ([array isKindOfClass:[NSArray class]] && array.count > 0) {
        NSDictionary *snapshot = @{
            @"count": @(array.count),
            @"first": @((uintptr_t)(__bridge void *)array.firstObject),
            @"last": @((uintptr_t)(__bridge void *)array.lastObject)
        };
        objc_setAssociatedObject(array, &kDYYYAdFilteredMarkKey, snapshot, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

static BOOL DYYYIsAdFilteredValid(NSArray *array) {
    if (![array isKindOfClass:[NSArray class]]) return NO;
    NSDictionary *snapshot = objc_getAssociatedObject(array, &kDYYYAdFilteredMarkKey);
    if (!snapshot) return NO;
    if ([snapshot[@"count"] unsignedIntegerValue] != array.count) return NO;
    if (array.count == 0) return YES; // 空数组无内容可替换
    uintptr_t first = [snapshot[@"first"] unsignedLongValue];
    uintptr_t last = [snapshot[@"last"] unsignedLongValue];
    return first == (uintptr_t)(__bridge void *)array.firstObject &&
           last == (uintptr_t)(__bridge void *)array.lastObject;
}

%hook AWEListDataController

- (void)setDataSource:(NSMutableArray *)dataSource {
    NSArray *result = [DYYYUtils arrayByRemovingAdvertisements:dataSource];
    NSMutableArray *filtered = [result isKindOfClass:[NSMutableArray class]]
        ? (NSMutableArray *)result : [result mutableCopy];
    %orig(filtered);
}

- (NSMutableArray *)dataSource {
    NSMutableArray *dataSource = %orig;
    if (!DYYYCachedBool(@"DYYYNoAds") || DYYYIsAdFilteredValid(dataSource)) {
        return dataSource;
    }
    NSArray *filtered = [DYYYUtils arrayByRemovingAdvertisements:dataSource];
    if (filtered != dataSource && [dataSource isKindOfClass:[NSMutableArray class]]) {
        [dataSource setArray:filtered];
    } else if (filtered != dataSource) {
        return [filtered mutableCopy];
    }
    DYYYMarkAdFiltered(dataSource);
    return dataSource;
}

- (void)setFilteredDataSource:(NSMutableArray *)filteredDataSource {
    NSArray *result = [DYYYUtils arrayByRemovingAdvertisements:filteredDataSource];
    NSMutableArray *filtered = [result isKindOfClass:[NSMutableArray class]]
        ? (NSMutableArray *)result : [result mutableCopy];
    %orig(filtered);
}

- (NSMutableArray *)filteredDataSource {
    NSMutableArray *filteredDataSource = %orig;
    if (!DYYYCachedBool(@"DYYYNoAds") || DYYYIsAdFilteredValid(filteredDataSource)) {
        return filteredDataSource;
    }
    NSArray *filtered = [DYYYUtils arrayByRemovingAdvertisements:filteredDataSource];
    if (filtered != filteredDataSource && [filteredDataSource isKindOfClass:[NSMutableArray class]]) {
        [filteredDataSource setArray:filtered];
    } else if (filtered != filteredDataSource) {
        return [filtered mutableCopy];
    }
    DYYYMarkAdFiltered(filteredDataSource);
    return filteredDataSource;
}

%end

%hook AWEMixVideoListDataController

- (void)setDataSource:(id)dataSource {
    NSArray *filtered = [DYYYUtils arrayByRemovingAdvertisements:dataSource];
    %orig(filtered);
}

- (id)dataSource {
    id dataSource = %orig;
    if (!DYYYCachedBool(@"DYYYNoAds") || DYYYIsAdFilteredValid(dataSource)) {
        return dataSource;
    }
    NSArray *filtered = [DYYYUtils arrayByRemovingAdvertisements:dataSource];
    if (filtered != dataSource && [dataSource isKindOfClass:[NSMutableArray class]]) {
        [dataSource setArray:filtered];
    } else if (filtered != dataSource) {
        return filtered;
    }
    DYYYMarkAdFiltered(dataSource);
    return dataSource;
}

%end


%hook AWEMixVideoRelatedListDataController

- (void)setDataSource:(id)dataSource {
    NSArray *filtered = [DYYYUtils arrayByRemovingAdvertisements:dataSource];
    %orig(filtered);
}

- (id)dataSource {
    id dataSource = %orig;
    if (!DYYYCachedBool(@"DYYYNoAds") || DYYYIsAdFilteredValid(dataSource)) {
        return dataSource;
    }
    NSArray *filtered = [DYYYUtils arrayByRemovingAdvertisements:dataSource];
    if (filtered != dataSource && [dataSource isKindOfClass:[NSMutableArray class]]) {
        [dataSource setArray:filtered];
    } else if (filtered != dataSource) {
        return filtered;
    }
    DYYYMarkAdFiltered(dataSource);
    return dataSource;
}

%end

%ctor {
    %init;
}
