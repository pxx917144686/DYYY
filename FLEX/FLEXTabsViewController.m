//
//  FLEXTabsViewController.m
//  FLEX
//
//  由 Tanner 创建于 6/29/20.
//  版权所有 © 2020 FLEX Team。保留所有权利。
//
//  遇到问题联系中文翻译作者：pxx917144686

#import "FLEXTabsViewController.h"
#import "FLEXNavigationController.h"
#import "FLEXTabList.h"
#import "FLEXBookmarkManager.h"
#import "FLEXTableView.h"
#import "FLEXUtility.h"
#import "FLEXColor.h"
#import "UIBarButtonItem+FLEX.h"
#import "FLEXExplorerViewController.h"
#import "FLEXGlobalsViewController.h"
#import "FLEXBookmarksViewController.h"

@interface FLEXTabsViewController ()
@property (nonatomic, copy) NSArray<UINavigationController *> *openTabs;
@property (nonatomic, copy) NSArray<UIImage *> *tabSnapshots;
@property (nonatomic) NSInteger activeIndex;
@property (nonatomic) BOOL presentNewActiveTabOnDismiss;

@property (nonatomic, readonly) FLEXExplorerViewController *corePresenter;
@end

@implementation FLEXTabsViewController

#pragma mark - 初始化

- (id)init {
    return [self initWithStyle:UITableViewStylePlain];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"打开标签";
    self.navigationController.hidesBarsOnSwipe = NO;
    self.tableView.allowsMultipleSelectionDuringEditing = YES;
    
    [self reloadData:NO];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self setupDefaultBarItems];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    // 我们在呈现后更新活动快照，而不是在呈现前更新，
    // 以避免呈现前的延迟
    dispatch_async(dispatch_get_main_queue(), ^{
        [FLEXTabList.sharedList updateSnapshotForActiveTab];
        [self reloadData:NO];
        [self.tableView reloadData];
    });
}


#pragma mark - 私有

/// @param trackActiveTabDelta 是否检查活动标签是否已更改并在“完成”关闭时需要呈现。
/// @return 活动标签是否已更改（如果还有剩余标签）。
- (BOOL)reloadData:(BOOL)trackActiveTabDelta {
    BOOL activeTabDidChange = NO;
    FLEXTabList *list = FLEXTabList.sharedList;
    
    // 用于启用检查以确定是否的标志
    if (trackActiveTabDelta) {
        NSInteger oldActiveIndex = self.activeIndex;
        if (oldActiveIndex != list.activeTabIndex && list.activeTabIndex != NSNotFound) {
            self.presentNewActiveTabOnDismiss = YES;
            activeTabDidChange = YES;
        } else if (self.presentNewActiveTabOnDismiss) {
            // 如果我们之前有东西要呈现，现在没有了
            // (即 activeTabIndex == NSNotFound)
            self.presentNewActiveTabOnDismiss = NO;
        }
    }
    
    // 我们假设标签不会在我们不知情的情况下改变，因为
    // 通过键盘快捷键呈现任何其他工具都应该首先关闭我们
    self.openTabs = list.openTabs;
    self.tabSnapshots = list.openTabSnapshots;
    self.activeIndex = list.activeTabIndex;
    
    return activeTabDidChange;
}

- (void)reloadActiveTabRowIfChanged:(BOOL)activeTabChanged {
    // 如果需要，刷新新激活的标签行
    if (activeTabChanged) {
        NSIndexPath *active = [NSIndexPath
           indexPathForRow:self.activeIndex inSection:0
        ];
        [self.tableView reloadRowsAtIndexPaths:@[active] withRowAnimation:UITableViewRowAnimationNone];
    }
}

- (void)setupDefaultBarItems {
    self.navigationItem.rightBarButtonItem = FLEXBarButtonItemSystem(Done, self, @selector(dismissAnimated));
    self.toolbarItems = @[
        UIBarButtonItem.flex_fixedSpace,
        UIBarButtonItem.flex_flexibleSpace,
        FLEXBarButtonItemSystem(Add, self, @selector(addTabButtonPressed:)),
        UIBarButtonItem.flex_flexibleSpace,
        FLEXBarButtonItemSystem(Edit, self, @selector(toggleEditing)),
    ];
    
    // 如果没有可用的标签，则禁用编辑
    self.toolbarItems.lastObject.enabled = self.openTabs.count > 0;
}

- (void)setupEditingBarItems {
    self.toolbarItems = @[
        UIBarButtonItem.flex_flexibleSpace,
        [UIBarButtonItem flex_disabledSystemItem:UIBarButtonSystemItemAdd],
        UIBarButtonItem.flex_flexibleSpace,
        // 我们使用非系统完成项，因为我们动态更改其标题
        [UIBarButtonItem flex_doneStyleitemWithTitle:@"完成" target:self action:@selector(toggleEditing)]
    ];
    
    self.toolbarItems.firstObject.tintColor = FLEXColor.destructiveColor;
}

- (FLEXExplorerViewController *)corePresenter {
    // 我们必须由FLEXExplorerViewController呈现，或由另一个
    // 由FLEXExplorerViewController呈现的视图控制器呈现
    FLEXExplorerViewController *presenter = (id)self.presentingViewController;
    presenter = (id)presenter.presentingViewController ?: presenter;
    NSAssert(
        [presenter isKindOfClass:[FLEXExplorerViewController class]],
        @"标签视图控制器期望由浏览器控制器呈现"
    );
    return presenter;
}


#pragma mark 按钮操作

- (void)dismissAnimated {
    if (self.presentNewActiveTabOnDismiss) {
        // 活动标签已关闭，所以我们需要呈现新的标签
        UIViewController *activeTab = FLEXTabList.sharedList.activeTab;
        FLEXExplorerViewController *presenter = self.corePresenter;
        [presenter dismissViewControllerAnimated:YES completion:^{
            [presenter presentViewController:activeTab animated:YES completion:nil];
        }];
    } else if (self.activeIndex == NSNotFound) {
        // 唯一的标签已关闭，因此关闭所有内容
        [self.corePresenter dismissViewControllerAnimated:YES completion:nil];
    } else {
        // 使用相同的活动标签简单关闭，仅关闭我自己
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)toggleEditing {
    NSArray<NSIndexPath *> *selected = self.tableView.indexPathsForSelectedRows;
    self.editing = !self.editing;
    
    if (self.isEditing) {
        [self setupEditingBarItems];
    } else {
        [self setupDefaultBarItems];
        
        // 获取要关闭的标签的索引集
        NSMutableIndexSet *indexes = [NSMutableIndexSet new];
        for (NSIndexPath *ip in selected) {
            [indexes addIndex:ip.row];
        }
        
        if (selected.count) {
            // 关闭标签并更新数据源
            [FLEXTabList.sharedList closeTabsAtIndexes:indexes];
            BOOL activeTabChanged = [self reloadData:YES];
            
            // 删除已删除的行
            [self.tableView deleteRowsAtIndexPaths:selected withRowAnimation:UITableViewRowAnimationAutomatic];
            
            // 如果需要，刷新新激活的标签行
            [self reloadActiveTabRowIfChanged:activeTabChanged];
        }
    }
}

- (void)addTabButtonPressed:(UIBarButtonItem *)sender {
    if (FLEXBookmarkManager.bookmarks.count) {
        [FLEXAlert makeSheet:^(FLEXAlert *make) {
            make.title(@"新标签");
            make.button(@"主菜单").handler(^(NSArray<NSString *> *strings) {
                [self addTabAndDismiss:[FLEXNavigationController
                    withRootViewController:[FLEXGlobalsViewController new]
                ]];
            });
            make.button(@"从书签中选择").handler(^(NSArray<NSString *> *strings) {
                [self presentViewController:[FLEXNavigationController
                    withRootViewController:[FLEXBookmarksViewController new]
                ] animated:YES completion:nil];
            });
            make.button(@"取消").cancelStyle();
        } showFrom:self source:sender];
    } else {
        // 没有书签，直接打开主菜单
        [self addTabAndDismiss:[FLEXNavigationController
            withRootViewController:[FLEXGlobalsViewController new]
        ]];
    }
}

- (void)addTabAndDismiss:(UINavigationController *)newTab {
    FLEXExplorerViewController *presenter = self.corePresenter;
    [presenter dismissViewControllerAnimated:YES completion:^{
        [presenter presentViewController:newTab animated:YES completion:nil];
    }];
}

- (void)closeAllButtonPressed:(UIBarButtonItem *)sender {
    [FLEXAlert makeSheet:^(FLEXAlert *make) {
        NSInteger count = self.openTabs.count;
        NSString *title = FLEXPluralFormatString(count, @"关闭 %@ 标签", @"关闭 %@ 标签");
        make.button(title).destructiveStyle().handler(^(NSArray<NSString *> *strings) {
            [self closeAll];
            [self toggleEditing];
        });
        make.button(@"取消").cancelStyle();
    } showFrom:self source:sender];
}

- (void)closeAll {
    NSInteger rowCount = self.openTabs.count;
    
    // 关闭标签并更新数据源
    [FLEXTabList.sharedList closeAllTabs];
    [self reloadData:YES];
    
    // 从表格视图中删除行
    NSArray<NSIndexPath *> *allRows = [NSArray flex_forEachUpTo:rowCount map:^id(NSUInteger row) {
        return [NSIndexPath indexPathForRow:row inSection:0];
    }];
    [self.tableView deleteRowsAtIndexPaths:allRows withRowAnimation:UITableViewRowAnimationAutomatic];
}


#pragma mark - 表格视图数据源

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.openTabs.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kFLEXDetailCell forIndexPath:indexPath];
    
    UINavigationController *tab = self.openTabs[indexPath.row];
    cell.imageView.image = self.tabSnapshots[indexPath.row];
    cell.textLabel.text = tab.topViewController.title;
    cell.detailTextLabel.text = FLEXPluralString(tab.viewControllers.count, @"页", @"页");
    
    if (!cell.tag) {
        cell.textLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
        cell.detailTextLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
        cell.tag = 1;
    }
    
    if (indexPath.row == self.activeIndex) {
        cell.backgroundColor = FLEXColor.secondaryBackgroundColor;
    } else {
        cell.backgroundColor = FLEXColor.primaryBackgroundColor;
    }
    
    return cell;
}


#pragma mark - 表格视图委托

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.editing) {
        // 情况：使用多选进行编辑
        self.toolbarItems.lastObject.title = @"关闭选择的";
        self.toolbarItems.lastObject.tintColor = FLEXColor.destructiveColor;
    } else {
        if (self.activeIndex == indexPath.row && self.corePresenter != self.presentingViewController) {
            // 情况：选择了已激活的标签
            [self dismissAnimated];
        } else {
            // 情况：选择了不同的标签，
            // 或从 FLEX 工具栏呈现时选择了标签
            FLEXTabList.sharedList.activeTabIndex = indexPath.row;
            self.presentNewActiveTabOnDismiss = YES;
            [self dismissAnimated];
        }
    }
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSParameterAssert(self.editing);
    
    if (tableView.indexPathsForSelectedRows.count == 0) {
        self.toolbarItems.lastObject.title = @"完成";
        self.toolbarItems.lastObject.tintColor = self.view.tintColor;
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)table
commitEditingStyle:(UITableViewCellEditingStyle)edit
forRowAtIndexPath:(NSIndexPath *)indexPath {
    NSParameterAssert(edit == UITableViewCellEditingStyleDelete);
    
    // 关闭标签并更新数据源
    [FLEXTabList.sharedList closeTab:self.openTabs[indexPath.row]];
    BOOL activeTabChanged = [self reloadData:YES];
    
    // 从表格视图中删除行
    [table deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    
    // 如果需要，刷新新激活的标签行
    [self reloadActiveTabRowIfChanged:activeTabChanged];
}

@end
