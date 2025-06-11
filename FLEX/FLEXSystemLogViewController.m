//
//  FLEXSystemLogViewController.m
//  FLEX
//
//  由 Ryan Olson 创建于 1/19/15.
//  版权所有 (c) 2020 FLEX Team. 保留所有权利。
//

#import "FLEXSystemLogViewController.h"
#import "FLEXASLLogController.h"
#import "FLEXOSLogController.h"
#import "FLEXSystemLogCell.h"
#import "FLEXMutableListSection.h"
#import "FLEXUtility.h"
#import "FLEXColor.h"
#import "FLEXResources.h"
#import "UIBarButtonItem+FLEX.h"
#import "NSUserDefaults+FLEX.h"
#import "flex_fishhook.h"
#import <dlfcn.h>

@interface FLEXSystemLogViewController ()

@property (nonatomic, readonly) FLEXMutableListSection<FLEXSystemLogMessage *> *logMessages;
@property (nonatomic, readonly) id<FLEXLogController> logController;

@end

static void (*MSHookFunction)(void *symbol, void *replace, void **result);

static BOOL FLEXDidHookNSLog = NO;
static BOOL FLEXNSLogHookWorks = NO;

BOOL (*os_log_shim_enabled)(void *addr) = nil;
BOOL (*orig_os_log_shim_enabled)(void *addr) = nil;
static BOOL my_os_log_shim_enabled(void *addr) {
    return NO;
}

@implementation FLEXSystemLogViewController

#pragma mark - 初始化

+ (void)load {
    // 用户必须选择禁用 os_log
    if (!NSUserDefaults.standardUserDefaults.flex_disableOSLog) {
        return;
    }

    // 感谢 GitHub 上的 @Ram4096 告诉我
    // os_log 是由 SDK 版本条件性启用的
    void *addr = __builtin_return_address(0);
    void *libsystem_trace = dlopen("/usr/lib/system/libsystem_trace.dylib", RTLD_LAZY);
    os_log_shim_enabled = dlsym(libsystem_trace, "os_log_shim_enabled");
    if (!os_log_shim_enabled) {
        return;
    }

    FLEXDidHookNSLog = flex_rebind_symbols((struct rebinding[1]) {{
        "os_log_shim_enabled",
        (void *)my_os_log_shim_enabled,
        (void **)&orig_os_log_shim_enabled
    }}, 1) == 0;

    if (FLEXDidHookNSLog && orig_os_log_shim_enabled != nil) {
        // 检查我们的重新绑定是否有效
        FLEXNSLogHookWorks = my_os_log_shim_enabled(addr) == NO;
    }

    // 所以，仅仅因为重新绑定了惰性加载的符号，这个函数并不意味着它会被使用。
    // 虽然它在模拟器上似乎足够了，但是由于某种原因，它在设备上不够用。需要实际使用类似 Substrate 的东西来挂钩函数。

    // 检查是否有 substrate，如果有就使用它
    void *handle = dlopen("/usr/lib/libsubstrate.dylib", RTLD_LAZY);
    if (handle) {
        MSHookFunction = dlsym(handle, "MSHookFunction");

        if (MSHookFunction) {
            // 设置钩子并检查是否有效
            void *unused;
            MSHookFunction(os_log_shim_enabled, my_os_log_shim_enabled, &unused);
            FLEXNSLogHookWorks = os_log_shim_enabled(addr) == NO;
        }
    }
}

- (id)init {
    return [super initWithStyle:UITableViewStylePlain];
}


#pragma mark - 重写

- (void)viewDidLoad {
    [super viewDidLoad];

    self.showsSearchBar = YES;
    self.pinSearchBar = YES;

    weakify(self)
    id logHandler = ^(NSArray<FLEXSystemLogMessage *> *newMessages) { strongify(self)
        [self handleUpdateWithNewMessages:newMessages];
    };

    if (FLEXOSLogAvailable() && !FLEXNSLogHookWorks) {
        _logController = [FLEXOSLogController withUpdateHandler:logHandler];
    } else {
        _logController = [FLEXASLLogController withUpdateHandler:logHandler];
    }

    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.title = @"等待日志...";

    // 工具栏按钮 //

    UIBarButtonItem *scrollDown = [UIBarButtonItem
        flex_itemWithImage:FLEXResources.scrollToBottomIcon
        target:self
        action:@selector(scrollToLastRow)
    ];
    UIBarButtonItem *settings = [UIBarButtonItem
        flex_itemWithImage:FLEXResources.gearIcon
        target:self
        action:@selector(showLogSettings)
    ];

    [self addToolbarItems:@[scrollDown, settings]];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self.logController startMonitoring];
}

- (NSArray<FLEXTableViewSection *> *)makeSections { weakify(self)
    _logMessages = [FLEXMutableListSection list:@[]
        cellConfiguration:^(FLEXSystemLogCell *cell, FLEXSystemLogMessage *message, NSInteger row) {
            strongify(self)
        
            cell.logMessage = message;
            cell.highlightedText = self.filterText;

            if (row % 2 == 0) {
                cell.backgroundColor = FLEXColor.primaryBackgroundColor;
            } else {
                cell.backgroundColor = FLEXColor.secondaryBackgroundColor;
            }
        } filterMatcher:^BOOL(NSString *filterText, FLEXSystemLogMessage *message) {
            NSString *displayedText = [FLEXSystemLogCell displayedTextForLogMessage:message];
            return [displayedText localizedCaseInsensitiveContainsString:filterText];
        }
    ];

    self.logMessages.cellRegistrationMapping = @{
        kFLEXSystemLogCellIdentifier : [FLEXSystemLogCell class]
    };

    return @[self.logMessages];
}

- (NSArray<FLEXTableViewSection *> *)nonemptySections {
    return @[self.logMessages];
}


#pragma mark - 私有方法

- (void)handleUpdateWithNewMessages:(NSArray<FLEXSystemLogMessage *> *)newMessages {
    self.title = [self.class globalsEntryTitle:FLEXGlobalsRowSystemLog];

    [self.logMessages mutate:^(NSMutableArray *list) {
        [list addObjectsFromArray:newMessages];
    }];
    
    // 重新过滤消息以过滤新消息
    if (self.filterText.length) {
        [self updateSearchResults:self.filterText];
    }

    // 如果我们之前接近底部，在新消息流入时"跟随"日志。
    UITableView *tv = self.tableView;
    BOOL wasNearBottom = tv.contentOffset.y >= tv.contentSize.height - tv.frame.size.height - 100.0;
    [self reloadData];
    if (wasNearBottom) {
        [self scrollToLastRow];
    }
}

- (void)scrollToLastRow {
    NSInteger numberOfRows = [self.tableView numberOfRowsInSection:0];
    if (numberOfRows > 0) {
        NSIndexPath *last = [NSIndexPath indexPathForRow:numberOfRows - 1 inSection:0];
        [self.tableView scrollToRowAtIndexPath:last atScrollPosition:UITableViewScrollPositionBottom animated:YES];
    }
}

- (void)showLogSettings {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    BOOL disableOSLog = defaults.flex_disableOSLog;
    BOOL persistent = defaults.flex_cacheOSLogMessages;

    NSString *aslToggle = disableOSLog ? @"启用os_log（默认）" : @"禁用os_log";
    NSString *persistence = persistent ? @"禁用持久日志记录" : @"启用持久日志记录";

    NSString *title = @"系统日志设置";
    NSString *body = @"在iOS 10及更高版本中，ASL已被os_log取代。"
    "Os_log API的限制要大得多。在下面，您可以选择旧的行为 "
    "如果您想在FLEX中更干净、更可靠的日志，但这会破坏"
    "任何希望os_log工作的东西，比如Console.app。"
    "此设置需要重新启动应用程序才能生效。 \n\n"

    "为了在启用os_log的情况下尽可能接近旧行为，日志必须 "
    "在启动时手动收集和存储。此设置没有效果"
    "在iOS 9及更低版本上，或者如果os_log被禁用。"
    "您只应在需要时启用持久日志记录。";

    FLEXOSLogController *logController = (FLEXOSLogController *)self.logController;

    [FLEXAlert makeAlert:^(FLEXAlert *make) {
        make.title(title).message(body);
        make.button(aslToggle).destructiveStyle().handler(^(NSArray<NSString *> *strings) {
            [defaults flex_toggleBoolForKey:kFLEXDefaultsDisableOSLogForceASLKey];
        });

        make.button(persistence).handler(^(NSArray<NSString *> *strings) {
            [defaults flex_toggleBoolForKey:kFLEXDefaultsiOSPersistentOSLogKey];
            logController.persistent = !persistent;
            [logController.messages addObjectsFromArray:self.logMessages.list];
        });
        make.button(@"不予考虑").cancelStyle();
    } showFrom:self];
}


#pragma mark - FLEXGlobalsEntry

+ (NSString *)globalsEntryTitle:(FLEXGlobalsRow)row {
    return @"⚠️  系统日志";
}

+ (UIViewController *)globalsEntryViewController:(FLEXGlobalsRow)row {
    return [self new];
}


#pragma mark - 表视图数据源

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    FLEXSystemLogMessage *logMessage = self.logMessages.filteredList[indexPath.row];
    return [FLEXSystemLogCell preferredHeightForLogMessage:logMessage inWidth:self.tableView.bounds.size.width];
}


#pragma mark - 长按复制

- (BOOL)tableView:(UITableView *)tableView shouldShowMenuForRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (BOOL)tableView:(UITableView *)tableView canPerformAction:(SEL)action forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender {
    return action == @selector(copy:);
}

- (void)tableView:(UITableView *)tableView performAction:(SEL)action forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender {
    if (action == @selector(copy:)) {
        // 我们通常只想复制日志消息本身，而不是与之关联的任何元数据。
        UIPasteboard.generalPasteboard.string = self.logMessages.filteredList[indexPath.row].messageText ?: @"";
    }
}

- (UIContextMenuConfiguration *)tableView:(UITableView *)tableView
contextMenuConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath
                                    point:(CGPoint)point __IOS_AVAILABLE(13.0) {
    weakify(self)
    return [UIContextMenuConfiguration configurationWithIdentifier:nil previewProvider:nil
        actionProvider:^UIMenu *(NSArray<UIMenuElement *> *suggestedActions) {
            UIAction *copy = [UIAction actionWithTitle:@"复制"
                                                 image:nil
                                            identifier:@"Copy"
                                               handler:^(UIAction *action) { strongify(self)
                // 我们通常只想复制日志消息本身，而不是与之关联的任何元数据。
                UIPasteboard.generalPasteboard.string = self.logMessages.filteredList[indexPath.row].messageText ?: @"";
            }];
            return [UIMenu menuWithTitle:@"" image:nil identifier:nil options:UIMenuOptionsDisplayInline children:@[copy]];
        }
    ];
}

@end
