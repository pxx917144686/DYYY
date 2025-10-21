//
//  FLEXTabList.m
//  FLEX
//
//  由 Tanner 创建于 2/1/20.
//  版权所有 © 2020 FLEX Team. 保留所有权利。
//

#import "FLEXTabList.h"
#import "FLEXUtility.h"

@interface FLEXTabList () {
    NSMutableArray *_openTabs;
    NSMutableArray *_openTabSnapshots;
}
@end
#pragma mark -
@implementation FLEXTabList

#pragma mark 初始化

+ (FLEXTabList *)sharedList {
    static FLEXTabList *sharedList = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedList = [self new];
    });
    
    return sharedList;
}

- (id)init {
    self = [super init];
    if (self) {
        _openTabs = [NSMutableArray new];
        _openTabSnapshots = [NSMutableArray new];
        _activeTabIndex = NSNotFound;
    }
    
    return self;
}


#pragma mark 私有方法

- (void)chooseNewActiveTab {
    if (self.openTabs.count) {
        self.activeTabIndex = self.openTabs.count - 1;
    } else {
        self.activeTabIndex = NSNotFound;
    }
}


#pragma mark 公共方法

- (void)setActiveTabIndex:(NSInteger)idx {
    NSParameterAssert(idx < self.openTabs.count || idx == NSNotFound);
    if (_activeTabIndex == idx) return;
    
    _activeTabIndex = idx;
    _activeTab = (idx == NSNotFound) ? nil : self.openTabs[idx];
}

- (void)addTab:(UINavigationController *)newTab {
    NSParameterAssert(newTab);
    
    // 更新上一个活动标签的快照
    if (self.activeTab) {
        [self updateSnapshotForActiveTab];
    }
    
    // 添加新标签和快照，
    // 更新活动标签和索引
    [_openTabs addObject:newTab];
    [_openTabSnapshots addObject:[FLEXUtility previewImageForView:newTab.view]];
    _activeTab = newTab;
    _activeTabIndex = self.openTabs.count - 1;
}

- (void)closeTab:(UINavigationController *)tab {
    NSParameterAssert(tab);
    NSInteger idx = [self.openTabs indexOfObject:tab];
    if (idx != NSNotFound) {
        [self closeTabAtIndex:idx];
    }
    
    // 不确定这是如何可能发生的，但有时确实会发生
    if (self.activeTab == tab) {
        [self chooseNewActiveTab];
    }
    
    // 对象浏览器可能会与其自己的导航控制器形成循环引用；
    // 关闭标签时手动清除视图控制器可以打破这个循环
    tab.viewControllers = @[];
}

- (void)closeTabAtIndex:(NSInteger)idx {
    NSParameterAssert(idx < self.openTabs.count);
    
    // 移除旧标签和快照
    [_openTabs removeObjectAtIndex:idx];
    [_openTabSnapshots removeObjectAtIndex:idx];
    
    // 如果需要，更新活动标签和索引
    if (self.activeTabIndex == idx) {
        [self chooseNewActiveTab];
    }
}

- (void)closeTabsAtIndexes:(NSIndexSet *)indexes {
    // 移除旧标签和快照
    [_openTabs removeObjectsAtIndexes:indexes];
    [_openTabSnapshots removeObjectsAtIndexes:indexes];
    
    // 如果需要，更新活动标签和索引
    if ([indexes containsIndex:self.activeTabIndex]) {
        [self chooseNewActiveTab];
    }
}

- (void)closeActiveTab {
    [self closeTab:self.activeTab];
}

- (void)closeAllTabs {
    // 移除标签和快照
    [_openTabs removeAllObjects];
    [_openTabSnapshots removeAllObjects];
    
    // 更新活动标签索引
    self.activeTabIndex = NSNotFound;
}

- (void)updateSnapshotForActiveTab {
    if (self.activeTabIndex != NSNotFound) {
        UIImage *newSnapshot = [FLEXUtility previewImageForView:self.activeTab.view];
        [_openTabSnapshots replaceObjectAtIndex:self.activeTabIndex withObject:newSnapshot];
    }
}

@end
