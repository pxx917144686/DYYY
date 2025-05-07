// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXAPNSViewController.m
//  FLEX
//
//  Created by Tanner Bennett on 2022/6/28.
//  Copyright © 2022 FLEX Team. All rights reserved.
//

#import "FLEXAPNSViewController.h"
#import "FLEXObjectExplorerFactory.h"
#import "FLEXMutableListSection.h"
#import "FLEXSingleRowSection.h"
#import "NSUserDefaults+FLEX.h"
#import "UIBarButtonItem+FLEX.h"
#import "NSDateFormatter+FLEX.h"
#import "FLEXResources.h"
#import "FLEXUtility.h"
#import "FLEXRuntimeUtility.h"
#import "flex_fishhook.h"
#import <dlfcn.h>
#import <UserNotifications/UserNotifications.h>

#define orig(method, ...) if (orig_##method) { orig_##method(__VA_ARGS__); } // 调用原始实现
// 方法查找宏
#define method_lookup(__selector, __cls, __return, ...) \
    ([__cls instancesRespondToSelector:__selector] ? \
        (__return(*)(__VA_ARGS__))class_getMethodImplementation(__cls, __selector) : nil)

@interface FLEXAPNSViewController ()
@property (nonatomic, readonly, class) Class appDelegateClass;
@property (nonatomic, class) NSData *deviceToken;
@property (nonatomic, class) NSError *registrationError;
@property (nonatomic, readonly, class) NSString *deviceTokenString;
@property (nonatomic, readonly, class) NSMutableArray<NSDictionary *> *remoteNotifications;
@property (nonatomic, readonly, class) NSMutableArray<UNNotification *> *userNotifications API_AVAILABLE(ios(10.0));

@property (nonatomic) FLEXSingleRowSection *deviceToken;
@property (nonatomic) FLEXMutableListSection<NSDictionary *> *remoteNotifications;
@property (nonatomic) FLEXMutableListSection<UNNotification *> *userNotifications API_AVAILABLE(ios(10.0));
@end

@implementation FLEXAPNSViewController

#pragma mark - 方法替换 (Swizzles)

/// Hook 应用委托和 UNUserNotificationCenter 委托类上的用户通知相关方法
+ (void)load { FLEX_EXIT_IF_NO_CTORS() // 如果没有构造函数则退出
    if (!NSUserDefaults.standardUserDefaults.flex_enableAPNSCapture) {
        // 如果未启用 APNS 捕获则返回
        return;
    }
    
    //──────────────────────//
    //     应用委托     //
    //──────────────────────//

    // Hook UIApplication 以拦截应用委托
    Class uiapp = UIApplication.self;
    // 获取原始 setDelegate: 实现
    auto orig_uiapp_setDelegate = (void(*)(id, SEL, id))class_getMethodImplementation(
        uiapp, @selector(setDelegate:)
    );
    
    // 创建新的 setDelegate: 实现块
    IMP uiapp_setDelegate = imp_implementationWithBlock(^(id _, id delegate) {
        [self hookAppDelegateClass:[delegate class]]; // Hook 应用委托类
        orig_uiapp_setDelegate(_, @selector(setDelegate:), delegate); // 调用原始实现
    });
    
    // 替换 setDelegate: 方法
    class_replaceMethod(
        uiapp,
        @selector(setDelegate:),
        uiapp_setDelegate,
        "v@:@" // 类型编码
    );
    
    //───────────────────────────────────────────//
    //     UNUserNotificationCenter 委托     //
    //───────────────────────────────────────────//
    
    if (@available(iOS 10.0, *)) {
        Class unusernc = UNUserNotificationCenter.self;
        // 获取原始 setDelegate: 实现
        auto orig_unusernc_setDelegate = (void(*)(id, SEL, id))class_getMethodImplementation(
            unusernc, @selector(setDelegate:) // 添加缺失的参数
        );
        
        // 创建新的 setDelegate: 实现块
        IMP unusernc_setDelegate = imp_implementationWithBlock(^(id _, id delegate) {
            [self hookUNUserNotificationCenterDelegateClass:[delegate class]]; // Hook UNUserNotificationCenter 委托类
            orig_unusernc_setDelegate(_, @selector(setDelegate:), delegate); // 调用原始实现
        });
        
        // 替换 setDelegate: 方法
        class_replaceMethod(
            unusernc,                              // 添加缺失的参数
            @selector(setDelegate:),               // 添加缺失的参数
            unusernc_setDelegate,                  // 添加缺失的参数
            method_getTypeEncoding(class_getInstanceMethod(unusernc, @selector(setDelegate:))) // 添加缺失的参数
        );
    }
}

+ (void)hookAppDelegateClass:(Class)appDelegate {
    // 如果已经 hook 过，则中止
    if (_appDelegateClass) {
        return;
    }
    
    _appDelegateClass = appDelegate;
    
    // 下面的 hookUNUserNotificationCenterDelegateClass: 中有更详细的文档说明
    
    // 类型编码
    auto types_didRegisterForRemoteNotificationsWithDeviceToken = "v@:@@";
    auto types_didFailToRegisterForRemoteNotificationsWithError = "v@:@@";
    auto types_didReceiveRemoteNotification = "v@:@@@?"; // 注意最后一个 ? 表示 block
    
    // 选择器
    auto sel_didRegisterForRemoteNotifications = @selector(application:didRegisterForRemoteNotificationsWithDeviceToken:);
    auto sel_didFailToRegisterForRemoteNotifs = @selector(application:didFailToRegisterForRemoteNotificationsWithError:);
    auto sel_didReceiveRemoteNotification = @selector(application:didReceiveRemoteNotification:fetchCompletionHandler:);
    
    // 获取原始实现
    auto orig_didRegisterForRemoteNotificationsWithDeviceToken = method_lookup(
        sel_didRegisterForRemoteNotifications, appDelegate, void, id, SEL, id, id);
    auto orig_didFailToRegisterForRemoteNotificationsWithError = method_lookup(
        sel_didFailToRegisterForRemoteNotifs, appDelegate, void, id, SEL, id, id);
    auto orig_didReceiveRemoteNotification = method_lookup(
        sel_didReceiveRemoteNotification, appDelegate, void, id, SEL, id, id, id);
    
    // 创建新的实现块
    IMP didRegisterForRemoteNotificationsWithDeviceToken = imp_implementationWithBlock(^(id _, id app, NSData *token) {
        self.deviceToken = token; // 保存设备令牌
        orig(didRegisterForRemoteNotificationsWithDeviceToken, _, sel_didRegisterForRemoteNotifications, app, token); // 调用原始实现，修正参数
    });
    IMP didFailToRegisterForRemoteNotificationsWithError = imp_implementationWithBlock(^(id _, id app, NSError *error) {
        self.registrationError = error; // 保存注册错误
        orig(didFailToRegisterForRemoteNotificationsWithError, _, sel_didFailToRegisterForRemoteNotifs, app, error); // 调用原始实现，修正参数
    });
    IMP didReceiveRemoteNotification = imp_implementationWithBlock(^(id _, id app, NSDictionary *payload, id handler) {
        // TODO: 添加新通知时通知 UI 更新
        [self.remoteNotifications addObject:payload]; // 添加收到的远程通知
        orig(didReceiveRemoteNotification, _, sel_didReceiveRemoteNotification, app, payload, handler); // 调用原始实现，修正参数
    });
    
    // 替换方法
    class_replaceMethod(
        appDelegate,
        sel_didRegisterForRemoteNotifications,
        didRegisterForRemoteNotificationsWithDeviceToken,
        types_didRegisterForRemoteNotificationsWithDeviceToken
    );
    class_replaceMethod(
        appDelegate,
        sel_didFailToRegisterForRemoteNotifs,
        didFailToRegisterForRemoteNotificationsWithError,
        types_didFailToRegisterForRemoteNotificationsWithError
    );
    class_replaceMethod(
        appDelegate,
        sel_didReceiveRemoteNotification,
        didReceiveRemoteNotification,
        types_didReceiveRemoteNotification
    );
}

+ (void)hookUNUserNotificationCenterDelegateClass:(Class)delegate API_AVAILABLE(ios(10.0)) {
    // 选择器
    auto sel_didReceiveNotification =
        @selector(userNotificationCenter:willPresentNotification:withCompletionHandler:);
    // 原始实现（如果未实现则为 nil）
    auto orig_didReceiveNotification = method_lookup(
        sel_didReceiveNotification, delegate, void, id, SEL, id, id, id);
    // 我们的 hook（忽略 self 和其他不需要的参数）
    IMP didReceiveNotification = imp_implementationWithBlock(^(id _, id __, UNNotification *notification, id ___) {
        [self.userNotifications addObject:notification]; // 添加收到的用户通知
        // 如果没有原始实现，此宏为空操作
        orig(didReceiveNotification, _, nil, __, notification, ___); // 调用原始实现
    });
    
    // 设置 hook
    class_replaceMethod(
        delegate,
        sel_didReceiveNotification,
        didReceiveNotification,
        "v@:@@@?" // 类型编码
    );
}

#pragma mark 类属性

static Class _appDelegateClass = nil;
+ (Class)appDelegateClass {
    return _appDelegateClass;
}

static NSData *_apnsDeviceToken = nil;
+ (NSData *)deviceToken {
    return _apnsDeviceToken;
}

+ (void)setDeviceToken:(NSData *)deviceToken {
    _apnsDeviceToken = deviceToken;
}

+ (NSString *)deviceTokenString {
    static NSString *_deviceTokenString = nil;
    
    if (!_deviceTokenString && self.deviceToken) {
        NSData *token = self.deviceToken;
        NSUInteger capacity = token.length * 2; // 容量为长度的两倍
        NSMutableString *tokenString = [NSMutableString stringWithCapacity:capacity];
        
        const UInt8 *tokenData = token.bytes; // 获取字节数据
        // 遍历字节并格式化为十六进制字符串
        for (NSUInteger idx = 0; idx < token.length; ++idx) {
            [tokenString appendFormat:@"%02x", tokenData[idx]]; // 修正 … 为实际代码
        }
        
        _deviceTokenString = tokenString; // 保存字符串
    }
    
    return _deviceTokenString;
}

static NSError *_apnsRegistrationError = nil;
+ (NSError *)registrationError {
    return _apnsRegistrationError;
}

+ (void)setRegistrationError:(NSError *)error {
    _apnsRegistrationError = error;
}

+ (NSMutableArray<NSDictionary *> *)remoteNotifications {
    static NSMutableArray *_remoteNotifications = nil;
    if (!_remoteNotifications) {
        _remoteNotifications = [NSMutableArray new];
    }
    
    return _remoteNotifications;
}

+ (NSMutableArray<UNNotification *> *)userNotifications API_AVAILABLE(ios(10.0)) { // 修正：返回类型应为 UNNotification
    static NSMutableArray<UNNotification *> *_userNotifications = nil; // 修正：存储 UNNotification
    if (!_userNotifications) {
        _userNotifications = [NSMutableArray new];
    }
    
    return _userNotifications;
}

#pragma mark 实例相关

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"推送通知";
    
    // 初始化刷新控件
    self.refreshControl = [UIRefreshControl new];
    [self.refreshControl addTarget:self action:@selector(reloadData) forControlEvents:UIControlEventValueChanged];
    
    // 添加工具栏按钮
    [self addToolbarItems:@[
        [UIBarButtonItem
            flex_itemWithTitle:@"设置" // 使用 flex_itemWithTitle
            target:self // 目标为 self
            action:@selector(settingsButtonTapped)
        ],
    ]];
}

- (NSArray<FLEXTableViewSection *> *)makeSections {
    // 设备令牌部分
    self.deviceToken = [FLEXSingleRowSection title:@"APNS 设备令牌" reuse:nil cell:^(UITableViewCell *cell) {
        NSString *tokenString = FLEXAPNSViewController.deviceTokenString;
        if (tokenString) {
            cell.textLabel.text = tokenString; // 如果有令牌字符串则显示
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator; // 显示指示器
        }
        else if (!NSUserDefaults.standardUserDefaults.flex_enableAPNSCapture) {
            cell.textLabel.text = @"APNS 捕获已禁用"; // 如果禁用则显示此消息
            cell.accessoryType = UITableViewCellAccessoryNone; // 不显示指示器
        }
        else {
            cell.textLabel.text = FLEXAPNSViewController.registrationError.localizedDescription ?: @"尚未收到"; // 显示错误或“尚未收到”
            cell.accessoryType = UITableViewCellAccessoryNone; // 不显示指示器
        }
    }];
    self.deviceToken.selectionAction = ^(UIViewController *host) {
        // 复制令牌到剪贴板
        UIPasteboard.generalPasteboard.string = FLEXAPNSViewController.deviceTokenString;
        [FLEXAlert showQuickAlert:@"已复制到剪贴板" from:host]; // 显示提示
    };
    
    // 远程通知部分 //
    
    self.remoteNotifications = [FLEXMutableListSection list:FLEXAPNSViewController.remoteNotifications
        cellConfiguration:^(UITableViewCell *cell, NSDictionary *notif, NSInteger row) {
            cell.textLabel.text = [NSString stringWithFormat:@"%@", notif]; // 显示通知内容
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator; // 显示指示器
        }
        filterMatcher:^BOOL(NSString *filterText, NSDictionary *notif) {
            return [notif.description localizedCaseInsensitiveContainsString:filterText]; // 根据描述进行过滤
        }
    ];
    
    self.remoteNotifications.customTitle = @"远程通知"; // 设置标题
    self.remoteNotifications.selectionHandler = ^(UIViewController *host, NSDictionary *notif) {
        // 跳转到对象浏览器
        [host.navigationController pushViewController:[
            FLEXObjectExplorerFactory explorerViewControllerForObject:notif
        ] animated:YES];
    };
    
    // 用户通知部分 //
    
    if (@available(iOS 10.0, *)) {
        self.userNotifications = [FLEXMutableListSection list:FLEXAPNSViewController.userNotifications
            cellConfiguration:^(UITableViewCell *cell, UNNotification *notif, NSInteger row) { // 添加 cellConfiguration
                cell.textLabel.text = notif.request.content.title ?: @"无标题"; // 显示通知标题
                cell.detailTextLabel.text = notif.request.content.body; // 显示通知正文
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator; // 显示指示器
            }
            filterMatcher:^BOOL(NSString *filterText, UNNotification *notif) { // 添加 filterMatcher
                NSString *searchText = [NSString stringWithFormat:@"%@ %@",
                                        notif.request.content.title ?: @"",
                                        notif.request.content.body ?: @""];
                return [searchText localizedCaseInsensitiveContainsString:filterText]; // 根据标题和正文过滤
            }
        ];
        
        self.userNotifications.customTitle = @"推送通知"; // 设置标题
        self.userNotifications.selectionHandler = ^(UIViewController *host, UNNotification *notif) {
            [host.navigationController pushViewController:[ // 跳转到对象浏览器
                FLEXObjectExplorerFactory explorerViewControllerForObject:notif
            ] animated:YES];
        };
        
        return @[self.deviceToken, self.remoteNotifications, self.userNotifications]; // 返回所有部分
    }
    else {
        return @[self.deviceToken, self.remoteNotifications]; // 返回设备令牌和远程通知部分
    }
}

- (void)reloadData {
    [self.refreshControl endRefreshing]; // 结束刷新
    
    // 更新远程通知标题，显示数量
    self.remoteNotifications.customTitle = [NSString stringWithFormat:
        @"远程通知 (%@)", @(FLEXAPNSViewController.remoteNotifications.count)
    ];
    if (@available(iOS 10.0, *)) {
        self.userNotifications.customTitle = [NSString stringWithFormat: // 更新用户通知标题
            @"用户通知 (%@)", @(FLEXAPNSViewController.userNotifications.count)
        ];
    }
    [super reloadData]; // 调用父类重新加载数据
}

- (void)settingsButtonTapped {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    BOOL enabled = defaults.flex_enableAPNSCapture; // 获取当前启用状态

    NSString *apnsToggle = enabled ? @"禁用捕获" : @"启用捕获"; // 切换按钮标题
    
    // 显示设置弹窗
    [FLEXAlert makeAlert:^(FLEXAlert *make) {
        make.title(@"APNS 设置"); // 设置标题
        make.button(apnsToggle).handler(^(NSArray<NSString *> *strings) { // 切换捕获状态
            defaults.flex_enableAPNSCapture = !enabled;
            // TODO: 可能需要重新 hook 或取消 hook
        });
        make.button(@"取消").cancelStyle(); // 取消按钮
    } showFrom:self];
}

#pragma mark - FLEXGlobalsEntry

+ (NSString *)globalsEntryTitle:(FLEXGlobalsRow)row {
    // 全局入口标题
    return @"📌  推送通知";
}

+ (UIViewController *)globalsEntryViewController:(FLEXGlobalsRow)row {
    // 返回此视图控制器的新实例
    return [self new];
}

@end
