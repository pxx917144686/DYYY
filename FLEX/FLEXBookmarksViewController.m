//
//  FLEXBookmarksViewController.m
//  FLEX
//
//  Created by Tanner on 2/6/20.
//  Copyright © 2020 FLEX Team. All rights reserved.
//

// 遇到问题联系中文翻译作者：pxx917144686

#import "FLEXBookmarksViewController.h"
#import "FLEXExplorerViewController.h"
#import "FLEXNavigationController.h"
#import "FLEXObjectExplorerFactory.h"
#import "FLEXBookmarkManager.h"
#import "UIBarButtonItem+FLEX.h"
#import "FLEXColor.h"
#import "FLEXUtility.h"
#import "FLEXRuntimeUtility.h"
#import "FLEXTableView.h"

@interface FLEXBookmarksViewController ()
@property (nonatomic, copy) NSArray *bookmarks;
@property (nonatomic, readonly) FLEXExplorerViewController *corePresenter;
@end

@implementation FLEXBookmarksViewController

#pragma mark - 初始化

- (id)init {
    return [self initWithStyle:UITableViewStylePlain];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationController.hidesBarsOnSwipe = NO;
    self.tableView.allowsMultipleSelectionDuringEditing = YES;
    
    [self reloadData];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self setupDefaultBarItems];
}


#pragma mark - 私有方法

- (void)reloadData {
    // 我们假设书签不会在我们不知情的情况下发生变化，因为通过键盘快捷键
    // 呈现的任何其他工具都应该先将我们关闭
    self.bookmarks = FLEXBookmarkManager.bookmarks;
    self.title = [NSString stringWithFormat:@"书签 (%@)", @(self.bookmarks.count)];
}

- (void)setupDefaultBarItems {
    self.navigationItem.rightBarButtonItem = FLEXBarButtonItemSystem(Done, self, @selector(dismissAnimated));
    self.toolbarItems = @[
        UIBarButtonItem.flex_flexibleSpace,
        FLEXBarButtonItemSystem(Edit, self, @selector(toggleEditing)),
    ];
    
    // 如果没有可用的书签则禁用编辑
    self.toolbarItems.lastObject.enabled = self.bookmarks.count > 0;
}

- (void)setupEditingBarItems {
    self.navigationItem.rightBarButtonItem = nil;
    self.toolbarItems = @[
        [UIBarButtonItem flex_itemWithTitle:@"关闭所有" target:self action:@selector(closeAllButtonPressed:)],
        UIBarButtonItem.flex_flexibleSpace,
        // 我们使用非系统完成按钮，因为我们需要动态更改其标题
        [UIBarButtonItem flex_doneStyleitemWithTitle:@"完成" target:self action:@selector(toggleEditing)]
    ];
    
    self.toolbarItems.firstObject.tintColor = FLEXColor.destructiveColor;
}

- (FLEXExplorerViewController *)corePresenter {
    // 我们必须由 FLEXExplorerViewController 呈现，或者由
    // 被 FLEXExplorerViewController 呈现的另一个视图控制器呈现
    FLEXExplorerViewController *presenter = (id)self.presentingViewController;
    presenter = (id)presenter.presentingViewController ?: presenter;
    presenter = (id)presenter.presentingViewController ?: presenter;
    NSAssert(
        [presenter isKindOfClass:[FLEXExplorerViewController class]],
        @"The bookmarks view controller expects to be presented by the explorer controller"
    );
    return presenter;
}

#pragma mark 按钮操作

- (void)dismissAnimated {
    [self dismissAnimated:nil];
}

- (void)dismissAnimated:(id)selectedObject {
    if (selectedObject) {
        UIViewController *explorer = [FLEXObjectExplorerFactory
            explorerViewControllerForObject:selectedObject
        ];
        if ([self.presentingViewController isKindOfClass:[FLEXNavigationController class]]) {
            // 我在现有导航栈上呈现，所以
            // 关闭自己并在那里推送书签
            UINavigationController *presenter = (id)self.presentingViewController;
            [presenter dismissViewControllerAnimated:YES completion:^{
                [presenter pushViewController:explorer animated:YES];
            }];
        } else {
            // 关闭自己并呈现浏览器
            UIViewController *presenter = self.corePresenter;
            [presenter dismissViewControllerAnimated:YES completion:^{
                [presenter presentViewController:[FLEXNavigationController
                    withRootViewController:explorer
                ] animated:YES completion:nil];
            }];
        }
    } else {
        // 仅关闭自己
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
        
        // 获取要关闭的书签的索引集
        NSMutableIndexSet *indexes = [NSMutableIndexSet new];
        for (NSIndexPath *ip in selected) {
            [indexes addIndex:ip.row];
        }
        
        if (selected.count) {
            // 关闭书签并更新数据源
            [FLEXBookmarkManager.bookmarks removeObjectsAtIndexes:indexes];
            [self reloadData];
            
            // 删除已删除的行
            [self.tableView deleteRowsAtIndexPaths:selected withRowAnimation:UITableViewRowAnimationAutomatic];
        }
    }
}

- (void)closeAllButtonPressed:(UIBarButtonItem *)sender {
    [FLEXAlert makeSheet:^(FLEXAlert *make) {
        NSInteger count = self.bookmarks.count;
        NSString *title = FLEXPluralFormatString(count, @"删除 %@ 书签", @"删除 %@ 书签");
        make.button(title).destructiveStyle().handler(^(NSArray<NSString *> *strings) {
            [self closeAll];
            [self toggleEditing];
        });
        make.button(@"取消").cancelStyle();
    } showFrom:self source:sender];
}

- (void)closeAll {
    NSInteger rowCount = self.bookmarks.count;
    
    // 关闭书签并更新数据源
    [FLEXBookmarkManager.bookmarks removeAllObjects];
    [self reloadData];
    
    // 从表视图中删除行
    NSArray<NSIndexPath *> *allRows = [NSArray flex_forEachUpTo:rowCount map:^id(NSUInteger row) {
        return [NSIndexPath indexPathForRow:row inSection:0];
    }];
    [self.tableView deleteRowsAtIndexPaths:allRows withRowAnimation:UITableViewRowAnimationAutomatic];
}


#pragma mark - 表视图数据源

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.bookmarks.count;
}

- (UITableViewCell *)tableView:(FLEXTableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kFLEXDetailCell forIndexPath:indexPath];
    
    id object = self.bookmarks[indexPath.row];
    cell.textLabel.text = [FLEXRuntimeUtility safeDescriptionForObject:object];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ — %p", [object class], object];
    
    return cell;
}


#pragma mark - 表视图代理

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.editing) {
        // 情况：使用多选进行编辑
        self.toolbarItems.lastObject.title = @"删除选定的";
        self.toolbarItems.lastObject.tintColor = FLEXColor.destructiveColor;
    } else {
        // 情况：选择了一个书签
        [self dismissAnimated:self.bookmarks[indexPath.row]];
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
    
    // 删除书签并更新数据源
    [FLEXBookmarkManager.bookmarks removeObjectAtIndex:indexPath.row];
    [self reloadData];
    
    // 从表视图中删除行
    [table deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
}

@end
