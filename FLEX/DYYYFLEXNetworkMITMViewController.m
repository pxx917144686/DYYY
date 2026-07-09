//
//  DYYYFLEXNetworkMITMViewController.m
//  Flipboard
//
//  Created by Ryan Olson on 2/8/15.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

#import "DYYYFLEXColor.h"
#import "DYYYFLEXUtility.h"
#import "DYYYFLEXMITMDataSource.h"
#import "DYYYFLEXNetworkMITMViewController.h"
#import "DYYYFLEXNetworkTransaction.h"
#import "DYYYFLEXNetworkRecorder.h"
#import "DYYYFLEXNetworkObserver.h"
#import "DYYYFLEXNetworkTransactionCell.h"
#import "DYYYFLEXHTTPTransactionDetailController.h"
#import "DYYYFLEXNetworkSettingsController.h"
#import "DYYYFLEXObjectExplorerFactory.h"
#import "DYYYFLEXGlobalsViewController.h"
#import "DYYYFLEXWebViewController.h"
#import "UIBarButtonItem+FLEX.h"
#import "DYYYFLEXResources.h"
#import "NSUserDefaults+FLEX.h"

#define kFirebaseAvailable NSClassFromString(@"FIRDocumentReference")
#define kWebsocketsAvailable @available(iOS 13.0, *)

typedef NS_ENUM(NSInteger, FLEXNetworkObserverMode) {
    FLEXNetworkObserverModeFirebase = 0,
    FLEXNetworkObserverModeREST,
    FLEXNetworkObserverModeWebsockets,
};

@interface DYYYFLEXNetworkMITMViewController ()

@property (nonatomic) BOOL updateInProgress;
@property (nonatomic) BOOL pendingReload;

@property (nonatomic) FLEXNetworkObserverMode mode;

@property (nonatomic, readonly) DYYYFLEXMITMDataSource<DYYYFLEXNetworkTransaction *> *dataSource;
@property (nonatomic, readonly) DYYYFLEXMITMDataSource<DYYYFLEXHTTPTransaction *> *HTTPDataSource;
@property (nonatomic, readonly) DYYYFLEXMITMDataSource<DYYYFLEXWebsocketTransaction *> *websocketDataSource;
@property (nonatomic, readonly) DYYYFLEXMITMDataSource<DYYYFLEXFirebaseTransaction *> *firebaseDataSource;

@end

@implementation DYYYFLEXNetworkMITMViewController

#pragma mark - 生命周期

- (id)init {
    return [self initWithStyle:UITableViewStylePlain];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.showsSearchBar = YES;
    self.pinSearchBar = YES;
    self.showSearchBarInitially = NO;
    NSMutableArray *scopeTitles = [NSMutableArray arrayWithObject:@"REST"];
    
    _HTTPDataSource = [DYYYFLEXMITMDataSource dataSourceWithProvider:^NSArray * {
        return DYYYFLEXNetworkRecorder.defaultRecorder.HTTPTransactions;
    }];

    if (kFirebaseAvailable) {
        _firebaseDataSource = [DYYYFLEXMITMDataSource dataSourceWithProvider:^NSArray * {
            return DYYYFLEXNetworkRecorder.defaultRecorder.firebaseTransactions;
        }];
        [scopeTitles insertObject:@"Firebase" atIndex:0]; // 第一个空间
    }

    if (kWebsocketsAvailable) {
        [scopeTitles addObject:@"Websockets"]; // 最后一个空间
        _websocketDataSource = [DYYYFLEXMITMDataSource dataSourceWithProvider:^NSArray * {
            return DYYYFLEXNetworkRecorder.defaultRecorder.websocketTransactions;
        }];
    }
    
    // 只有在我们有Firebase或Websockets可用时才会显示范围
    self.searchController.searchBar.showsScopeBar = scopeTitles.count > 1;
    self.searchController.searchBar.scopeButtonTitles = scopeTitles;
    self.mode = NSUserDefaults.standardUserDefaults.flex_lastNetworkObserverMode;

    [self addToolbarItems:@[
        [UIBarButtonItem
            flex_itemWithImage:DYYYFLEXResources.gearIcon
            target:self
            action:@selector(settingsButtonTapped:)
        ],
        [[UIBarButtonItem
          flex_systemItem:UIBarButtonSystemItemTrash
          target:self
          action:@selector(trashButtonTapped:)
        ] flex_withTintColor:UIColor.redColor]
    ]];

    [self.tableView
        registerClass:DYYYFLEXNetworkTransactionCell.class
        forCellReuseIdentifier:DYYYFLEXNetworkTransactionCell.reuseID
    ];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.rowHeight = DYYYFLEXNetworkTransactionCell.preferredCellHeight;

    [self registerForNotifications];
    [self updateTransactions:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // 如果我们在屏幕外接收到更新，则重新加载表格
    if (self.pendingReload) {
        [self.tableView reloadData];
        self.pendingReload = NO;
    }
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)registerForNotifications {
    NSDictionary *notifications = @{
        kFLEXNetworkRecorderNewTransactionNotification:
            NSStringFromSelector(@selector(handleNewTransactionRecordedNotification:)),
        kFLEXNetworkRecorderTransactionUpdatedNotification:
            NSStringFromSelector(@selector(handleTransactionUpdatedNotification:)),
        kFLEXNetworkRecorderTransactionsClearedNotification:
            NSStringFromSelector(@selector(handleTransactionsClearedNotification:)),
        kFLEXNetworkObserverEnabledStateChangedNotification:
            NSStringFromSelector(@selector(handleNetworkObserverEnabledStateChangedNotification:)),
    };
    
    for (NSString *name in notifications.allKeys) {
        [NSNotificationCenter.defaultCenter addObserver:self
            selector:NSSelectorFromString(notifications[name]) name:name object:nil
        ];
    }
}


#pragma mark - 私有方法

#pragma mark 按钮操作

- (void)settingsButtonTapped:(UIBarButtonItem *)sender {
    UIViewController *settings = [DYYYFLEXNetworkSettingsController new];
    settings.navigationItem.rightBarButtonItem = FLEXBarButtonItemSystem(
        Done, self, @selector(settingsViewControllerDoneTapped:)
    );
    settings.title = @"网络监听开关";
    
    // 这不是一个FLEXNavigationController，因为它不是作为一个新标签设计的
    UIViewController *nav = [[UINavigationController alloc] initWithRootViewController:settings];
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)trashButtonTapped:(UIBarButtonItem *)sender {
    [DYYYFLEXAlert makeSheet:^(DYYYFLEXAlert *make) {
        BOOL clearAll = !self.dataSource.isFiltered;
        if (!clearAll) {
            make.title(@"清除过滤请求？");
            make.message(@"这只会删除此屏幕上与您的搜索字符串匹配的请求。");
        } else {
            make.title(@"清除所有记录的请求？");
            make.message(@"这是无法撤销的。");
        }
        
        make.button(@"取消").cancelStyle();
        make.button(@"清空").destructiveStyle().handler(^(NSArray *strings) {
            if (clearAll) {
                [DYYYFLEXNetworkRecorder.defaultRecorder clearRecordedActivity];
            } else {
                FLEXNetworkTransactionKind kind = (FLEXNetworkTransactionKind)self.mode;
                [DYYYFLEXNetworkRecorder.defaultRecorder clearRecordedActivity:kind matching:self.searchText];
            }
        });
    } showFrom:self source:sender];
}

- (void)settingsViewControllerDoneTapped:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}


#pragma mark 事务处理

- (FLEXNetworkObserverMode)mode {
    FLEXNetworkObserverMode mode = self.searchController.searchBar.selectedScopeButtonIndex;
    switch (mode) {
        case FLEXNetworkObserverModeFirebase:
            if (kFirebaseAvailable) {
                return FLEXNetworkObserverModeFirebase;
            }

            return FLEXNetworkObserverModeREST;
        case FLEXNetworkObserverModeREST:
            if (kFirebaseAvailable) {
                return FLEXNetworkObserverModeREST;
            }

            return FLEXNetworkObserverModeWebsockets;
        case FLEXNetworkObserverModeWebsockets:
            return FLEXNetworkObserverModeWebsockets;
    }
}

- (void)setMode:(FLEXNetworkObserverMode)mode {
// 分段控制将根据可用的API具有不同的外观。例如，当只有Websockets可用时：
//
//               0                           1
// ┌───────────────────────────┬────────────────────────────┐
// │            REST           │         Websockets         │
// └───────────────────────────┴────────────────────────────┘
//
// 当Firebase和Websockets都可用时：
//
//          0                  1                  2
// ┌──────────────────┬──────────────────┬──────────────────┐
// │     Firebase     │       REST       │    Websockets    │
// └──────────────────┴──────────────────┴──────────────────┘
//
// 因此，我们需要相应地调整输入模式变量，然后再实际设置它。
// 当我们尝试将其设置为Firebase但Firebase不可用时，我们不做任何事情，因为当Firebase不可用时，
// FLEXNetworkObserverModeFirebase表示与没有Firebase的REST相同的索引。
// 对于其他每个，我们减去1，对于每个相关的API不可用。
// 因此，对于Websockets，如果它不可用，我们减去1，它变成FLEXNetworkObserverModeREST。
// 如果Firebase也不可用，我们再次减去1。

    switch (mode) {
        case FLEXNetworkObserverModeFirebase:
            // 如果Firebase不可用，将默认为REST
            break;
        case FLEXNetworkObserverModeREST:
            // 如果Firebase不可用，Firebase将变为REST
            if (!kFirebaseAvailable) {
                mode--;
            }
            break;
        case FLEXNetworkObserverModeWebsockets:
            // 如果Websockets不可用，将默认为REST
            if (!kWebsocketsAvailable) {
                mode--;
            }
            // 如果Firebase不可用，Firebase将变为REST
            if (!kFirebaseAvailable) {
                mode--;
            }
    }

    self.searchController.searchBar.selectedScopeButtonIndex = mode;
}

- (DYYYFLEXMITMDataSource<DYYYFLEXNetworkTransaction *> *)dataSource {
    switch (self.mode) {
        case FLEXNetworkObserverModeREST:
            return self.HTTPDataSource;
        case FLEXNetworkObserverModeWebsockets:
            return self.websocketDataSource;
        case FLEXNetworkObserverModeFirebase:
            return self.firebaseDataSource;
    }
}

- (void)updateTransactions:(void(^)(void))callback {
    id completion = ^(DYYYFLEXMITMDataSource *dataSource) {
        // 更新字节计数
        [self updateFirstSectionHeader];
        if (callback && dataSource == self.dataSource) callback();
    };
    
    [self.HTTPDataSource reloadData:completion];
    [self.websocketDataSource reloadData:completion];
    [self.firebaseDataSource reloadData:completion];
}


#pragma mark 标题

- (void)updateFirstSectionHeader {
    UIView *view = [self.tableView headerViewForSection:0];
    if ([view isKindOfClass:[UITableViewHeaderFooterView class]]) {
        UITableViewHeaderFooterView *headerView = (UITableViewHeaderFooterView *)view;
        headerView.textLabel.text = [self headerText];
        [headerView setNeedsLayout];
    }
}

- (NSString *)headerText {
    long long bytesReceived = self.dataSource.bytesReceived;
    NSInteger totalRequests = self.dataSource.transactions.count;
    
    NSString *byteCountText = [NSByteCountFormatter
        stringFromByteCount:bytesReceived countStyle:NSByteCountFormatterCountStyleBinary
    ];
    NSString *requestsText = totalRequests == 1 ? @"请求" : @"请求";
    
    // 从Firebase排除字节计数
    if (self.mode == FLEXNetworkObserverModeFirebase) {
        return [NSString stringWithFormat:@"%@ %@",
            @(totalRequests), requestsText
        ];
    }
    
    return [NSString stringWithFormat:@"%@ %@ (%@ 已接收)",
        @(totalRequests), requestsText, byteCountText
    ];
}


#pragma mark - DYYYFLEXGlobalsEntry

+ (NSString *)globalsEntryTitle:(FLEXGlobalsRow)row {
    return @"📡  网络监听";
}

+ (FLEXGlobalsEntryRowAction)globalsEntryRowAction:(FLEXGlobalsRow)row {
    return ^(UITableViewController *host) {
        if (DYYYFLEXNetworkObserver.isEnabled) {
            [host.navigationController pushViewController:[
                self globalsEntryViewController:row
            ] animated:YES];
        } else {
            [DYYYFLEXAlert makeAlert:^(DYYYFLEXAlert *make) {
                make.title(@"网络监视器当前禁用");
                make.message(@"您必须启用网络监控才能继续。");
                
                make.button(@"打开").preferred().handler(^(NSArray<NSString *> *strings) {
                    DYYYFLEXNetworkObserver.enabled = YES;
                    [host.navigationController pushViewController:[
                        self globalsEntryViewController:row
                    ] animated:YES];
                });
                make.button(@"取消").cancelStyle();
            } showFrom:host];
        }
    };
}

+ (UIViewController *)globalsEntryViewController:(FLEXGlobalsRow)row {
    UIViewController *controller = [self new];
    controller.title = [self globalsEntryTitle:row];
    return controller;
}


#pragma mark - 通知处理程序

- (void)handleNewTransactionRecordedNotification:(NSNotification *)notification {
    [self tryUpdateTransactions];
}

- (void)tryUpdateTransactions {
    // 如果我们不在视图层次结构中，则不进行任何视图更新
    if (!self.viewIfLoaded.window) {
        [self updateTransactions:nil];
        self.pendingReload = YES;
        return;
    }
    
    // 让之前的行插入动画完成后再开始新的动画以避免踩踏。
    // 我们将在插入完成时尝试再次调用该方法，
    // 如果没有发生变化，我们将正确地无操作。
    if (self.updateInProgress) {
        return;
    }
    
    self.updateInProgress = YES;

    // 在更新之前获取状态
    NSString *currentFilter = self.searchText;
    FLEXNetworkObserverMode currentMode = self.mode;
    NSInteger existingRowCount = self.dataSource.transactions.count;
    
    [self updateTransactions:^{
        // 与更新后的状态进行比较
        NSString *newFilter = self.searchText;
        FLEXNetworkObserverMode newMode = self.mode;
        NSInteger newRowCount = self.dataSource.transactions.count;
        NSInteger rowCountDiff = newRowCount - existingRowCount;
        
        // 如果观察模式发生变化，或者搜索字段文本发生变化，则中止
        if (newMode != currentMode || ![currentFilter isEqualToString:newFilter]) {
            self.updateInProgress = NO;
            return;
        }
        
        if (rowCountDiff) {
            // 如果我们在顶部，则插入动画。
            if (self.tableView.contentOffset.y <= 0.0 && rowCountDiff > 0) {
                [CATransaction begin];
                
                [CATransaction setCompletionBlock:^{
                    self.updateInProgress = NO;
                    // 这不是一个无限循环，如果第二次没有新的事务，它不会运行第三次
                    [self tryUpdateTransactions];
                }];
                
                NSMutableArray<NSIndexPath *> *indexPathsToReload = [NSMutableArray new];
                for (NSInteger row = 0; row < rowCountDiff; row++) {
                    [indexPathsToReload addObject:[NSIndexPath indexPathForRow:row inSection:0]];
                }

                [self.tableView insertRowsAtIndexPaths:indexPathsToReload withRowAnimation:UITableViewRowAnimationAutomatic];
                [CATransaction commit];
            } else {
                // 如果用户已经向下滚动，则保持用户的位置。
                CGSize existingContentSize = self.tableView.contentSize;
                [self.tableView reloadData];
                CGFloat contentHeightChange = self.tableView.contentSize.height - existingContentSize.height;
                self.tableView.contentOffset = CGPointMake(self.tableView.contentOffset.x, self.tableView.contentOffset.y + contentHeightChange);
                self.updateInProgress = NO;
            }
        } else {
            self.updateInProgress = NO;
        }
    }];
}

- (void)handleTransactionUpdatedNotification:(NSNotification *)notification {
    [self.HTTPDataSource reloadByteCounts];
    [self.websocketDataSource reloadByteCounts];
    // 不需要在这里重新加载Firebase

    DYYYFLEXNetworkTransaction *transaction = notification.userInfo[kFLEXNetworkRecorderUserInfoTransactionKey];

    // 如果需要，更新主表视图和搜索表视图。
    for (DYYYFLEXNetworkTransactionCell *cell in self.tableView.visibleCells) {
        if ([cell.transaction isEqual:transaction]) {
            // 使用-[UITableView reloadRowsAtIndexPaths:withRowAnimation:]在这里是过度的，
            // 并启动了很多工作，这可能会使表视图在大量更新流入时有些不响应。
            // 我们只需要告诉单元格它需要重新布局。
            [cell setNeedsLayout];
            break;
        }
    }
    
    [self updateFirstSectionHeader];
}

- (void)handleTransactionsClearedNotification:(NSNotification *)notification {
    [self updateTransactions:^{
        [self.tableView reloadData];
    }];
}

- (void)handleNetworkObserverEnabledStateChangedNotification:(NSNotification *)notification {
    // 更新标题，当网络调试被禁用时显示警告
    [self updateFirstSectionHeader];
}


#pragma mark - 表视图数据源

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.dataSource.transactions.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return [self headerText];
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section {
    if ([view isKindOfClass:[UITableViewHeaderFooterView class]]) {
        UITableViewHeaderFooterView *headerView = (UITableViewHeaderFooterView *)view;
        headerView.textLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DYYYFLEXNetworkTransactionCell *cell = [tableView
        dequeueReusableCellWithIdentifier:DYYYFLEXNetworkTransactionCell.reuseID
        forIndexPath:indexPath
    ];
    
    cell.transaction = [self transactionAtIndexPath:indexPath];

    // 由于我们从顶部插入，因此从底部分配背景颜色以保持每个事务的一致性。
    NSInteger totalRows = [tableView numberOfRowsInSection:indexPath.section];
    if ((totalRows - indexPath.row) % 2 == 0) {
        cell.backgroundColor = DYYYFLEXColor.secondaryBackgroundColor;
    } else {
        cell.backgroundColor = DYYYFLEXColor.primaryBackgroundColor;
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (self.mode) {
        case FLEXNetworkObserverModeREST: {
            DYYYFLEXHTTPTransaction *transaction = [self HTTPTransactionAtIndexPath:indexPath];
            UIViewController *details = [DYYYFLEXHTTPTransactionDetailController withTransaction:transaction];
            [self.navigationController pushViewController:details animated:YES];
            break;
        }
            
        case FLEXNetworkObserverModeWebsockets: {
            if (@available(iOS 13.0, *)) { // 此检查永远不会失败
                DYYYFLEXWebsocketTransaction *transaction = [self websocketTransactionAtIndexPath:indexPath];
                
                UIViewController *details = nil;
                if (transaction.message.type == NSURLSessionWebSocketMessageTypeData) {
                    details = [DYYYFLEXObjectExplorerFactory explorerViewControllerForObject:transaction.message.data];
                } else {
                    details = [[DYYYFLEXWebViewController alloc] initWithText:transaction.message.string];
                }
                
                [self.navigationController pushViewController:details animated:YES];
            }
            break;
        }
        
        case FLEXNetworkObserverModeFirebase: {
            DYYYFLEXFirebaseTransaction *transaction = [self firebaseTransactionAtIndexPath:indexPath];
//            id obj = transaction.documents.count == 1 ? transaction.documents.firstObject : transaction.documents;
            UIViewController *explorer = [DYYYFLEXObjectExplorerFactory explorerViewControllerForObject:transaction];
            [self.navigationController pushViewController:explorer animated:YES];
        }
    }
}


#pragma mark - 菜单操作

- (BOOL)tableView:(UITableView *)tableView shouldShowMenuForRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (BOOL)tableView:(UITableView *)tableView canPerformAction:(SEL)action forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender {
    return action == @selector(copy:);
}

- (void)tableView:(UITableView *)tableView performAction:(SEL)action forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender {
    if (action == @selector(copy:)) {
        UIPasteboard.generalPasteboard.string = [self transactionAtIndexPath:indexPath].copyString;
    }
}

- (UIContextMenuConfiguration *)tableView:(UITableView *)tableView contextMenuConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath point:(CGPoint)point __IOS_AVAILABLE(13.0) {
    
    DYYYFLEXNetworkTransaction *transaction = [self transactionAtIndexPath:indexPath];
    
    return [UIContextMenuConfiguration
        configurationWithIdentifier:nil
        previewProvider:nil
        actionProvider:^UIMenu *(NSArray<UIMenuElement *> *suggestedActions) {
            UIAction *copy = [UIAction
                actionWithTitle:@"复制URL"
                image:nil
                identifier:nil
                handler:^(__kindof UIAction *action) {
                    UIPasteboard.generalPasteboard.string = transaction.copyString;
                }
            ];
        
            NSArray *children = @[copy];
            if (self.mode == FLEXNetworkObserverModeREST) {
                NSURLRequest *request = [self HTTPTransactionAtIndexPath:indexPath].request;
                UIAction *denylist = [UIAction
                    actionWithTitle:[NSString stringWithFormat:@"排除 '%@'", request.URL.host]
                    image:nil
                    identifier:nil
                    handler:^(__kindof UIAction *action) {
                        NSMutableArray *denylist =  DYYYFLEXNetworkRecorder.defaultRecorder.hostDenylist;
                        [denylist addObject:request.URL.host];
                        [DYYYFLEXNetworkRecorder.defaultRecorder clearExcludedTransactions];
                        [DYYYFLEXNetworkRecorder.defaultRecorder synchronizeDenylist];
                        [self tryUpdateTransactions];
                    }
                ];
                
                children = [children arrayByAddingObject:denylist];
            }
            return [UIMenu
                menuWithTitle:@"" image:nil identifier:nil
                options:UIMenuOptionsDisplayInline
                children:children
            ];
        }
    ];
}

- (DYYYFLEXNetworkTransaction *)transactionAtIndexPath:(NSIndexPath *)indexPath {
    return self.dataSource.transactions[indexPath.row];
}

- (DYYYFLEXHTTPTransaction *)HTTPTransactionAtIndexPath:(NSIndexPath *)indexPath {
    return self.HTTPDataSource.transactions[indexPath.row];
}

- (DYYYFLEXWebsocketTransaction *)websocketTransactionAtIndexPath:(NSIndexPath *)indexPath {
    return self.websocketDataSource.transactions[indexPath.row];
}

- (DYYYFLEXFirebaseTransaction *)firebaseTransactionAtIndexPath:(NSIndexPath *)indexPath {
    return self.firebaseDataSource.transactions[indexPath.row];
}

#pragma mark - 搜索栏

- (void)updateSearchResults:(NSString *)searchString {
    id callback = ^(DYYYFLEXMITMDataSource *dataSource) {
        if (self.dataSource == dataSource) {
            [self.tableView reloadData];
        }
    };
    
    [self.HTTPDataSource filter:searchString completion:callback];
    [self.websocketDataSource filter:searchString completion:callback];
    [self.firebaseDataSource filter:searchString completion:callback];
}

- (void)searchBar:(UISearchBar *)searchBar selectedScopeButtonIndexDidChange:(NSInteger)newScope {
    [self updateFirstSectionHeader];
    [self.tableView reloadData];

    NSUserDefaults.standardUserDefaults.flex_lastNetworkObserverMode = self.mode;
}

- (void)willDismissSearchController:(UISearchController *)searchController {
    [self.tableView reloadData];
}

@end
