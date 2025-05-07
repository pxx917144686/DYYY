// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXObjectExplorerFactory.m
//  Flipboard
//
//  由 Ryan Olson 创建于 5/15/14.
//  版权所有 (c) 2020 FLEX Team。保留所有权利。

#import "FLEXObjectExplorerFactory.h"
#import "FLEXGlobalsViewController.h"
#import "FLEXClassShortcuts.h"
#import "FLEXViewShortcuts.h"
#import "FLEXWindowShortcuts.h"
#import "FLEXViewControllerShortcuts.h"
#import "FLEXUIAppShortcuts.h"
#import "FLEXImageShortcuts.h"
#import "FLEXLayerShortcuts.h"
#import "FLEXColorPreviewSection.h"
#import "FLEXDefaultsContentSection.h"
#import "FLEXBundleShortcuts.h"
#import "FLEXNSStringShortcuts.h"
#import "FLEXNSDataShortcuts.h"
#import "FLEXBlockShortcuts.h"
#import "FLEXUtility.h"
#import "FLEXAddressExplorerViewController.h"
#import "FLEXObjcRuntimeViewController.h"
#import "FLEXKeychainViewController.h"
#import "FLEXCookiesViewController.h"
#import "FLEXFileBrowserController.h"
#import "FLEXSystemLogViewController.h"
#import "FLEXLiveObjectsController.h"
#import "FLEXAPNSViewController.h"
#import "FLEXNetworkMITMViewController.h"

@implementation FLEXObjectExplorerFactory
static NSMutableDictionary<id<NSCopying>, Class> *classesToRegisteredSections = nil;

+ (void)initialize {
    if (self == [FLEXObjectExplorerFactory class]) {
        // 这里不要使用字符串键
        // 我们需要使用类作为键，因为我们无法
        // 区分类的名称和元类的名称。
        // 这些映射是针对每个类对象的，而不是针对每个类名的。
        //
        // 例如，如果我们使用类名，这将导致
        // 对象浏览器尝试为 UIColor 类对象渲染颜色预览，
        // 而 UIColor 类对象本身并不是一种颜色。
        #define ClassKey(name) (id<NSCopying>)[name class]
        #define ClassKeyByName(str) (id<NSCopying>)NSClassFromString(@ #str)
        #define MetaclassKey(meta) (id<NSCopying>)object_getClass([meta class])
        classesToRegisteredSections = [NSMutableDictionary dictionaryWithDictionary:@{
            MetaclassKey(NSObject)     : [FLEXClassShortcuts class],
            ClassKey(NSArray)          : [FLEXCollectionContentSection class],
            ClassKey(NSSet)            : [FLEXCollectionContentSection class],
            ClassKey(NSDictionary)     : [FLEXCollectionContentSection class],
            ClassKey(NSOrderedSet)     : [FLEXCollectionContentSection class],
            ClassKey(NSUserDefaults)   : [FLEXDefaultsContentSection class],
            ClassKey(UIViewController) : [FLEXViewControllerShortcuts class],
            ClassKey(UIApplication)    : [FLEXUIAppShortcuts class],
            ClassKey(UIView)           : [FLEXViewShortcuts class],
            ClassKey(UIWindow)         : [FLEXWindowShortcuts class],
            ClassKey(UIImage)          : [FLEXImageShortcuts class],
            ClassKey(CALayer)          : [FLEXLayerShortcuts class],
            ClassKey(UIColor)          : [FLEXColorPreviewSection class],
            ClassKey(NSBundle)         : [FLEXBundleShortcuts class],
            ClassKey(NSString)         : [FLEXNSStringShortcuts class],
            ClassKey(NSData)           : [FLEXNSDataShortcuts class],
            ClassKeyByName(NSBlock)    : [FLEXBlockShortcuts class],
        }];
        #undef ClassKey
        #undef ClassKeyByName
        #undef MetaclassKey
    }
}

+ (FLEXObjectExplorerViewController *)explorerViewControllerForObject:(id)object {
    // 不能浏览 nil
    if (!object) {
        return nil;
    }

    // 如果我们得到一个对象，这将查找它的类层次结构
    // 直到找到一个注册。这对于 KVC 类是有效的，
    // 因为它们是原始类的子类，而不是兄弟类。
    // 如果我们得到一个对象，object_getClass 将返回一个元类，
    // 并且会发生同样的事情。FLEXClassShortcuts 是 NSObject 的默认
    // 快捷方式部分。
    //
    // TODO: 将其重命名为 FLEXNSObjectShortcuts 之类的名称？
    FLEXShortcutsSection *shortcutsSection = [FLEXShortcutsSection forObject:object];
    NSArray *sections = @[shortcutsSection];
    
    Class customSectionClass = nil;
    Class cls = object_getClass(object);
    do {
        customSectionClass = classesToRegisteredSections[(id<NSCopying>)cls];
    } while (!customSectionClass && (cls = [cls superclass]));

    if (customSectionClass) {
        id customSection = [customSectionClass forObject:object];
        BOOL isFLEXShortcutSection = [customSection respondsToSelector:@selector(isNewSection)];
        
        // 如果该部分“替换”了默认的快捷方式部分，
        // 则仅返回该部分。否则，返回此部分
        // 和默认的快捷方式部分。
        if (isFLEXShortcutSection && ![customSection isNewSection]) {
            sections = @[customSection];
        } else {
            // 自定义部分将位于快捷方式之前
            sections = @[customSection, shortcutsSection];            
        }
    }

    return [FLEXObjectExplorerViewController
        exploringObject:object
        customSections:sections
    ];
}

+ (void)registerExplorerSection:(Class)explorerClass forClass:(Class)objectClass {
    classesToRegisteredSections[(id<NSCopying>)objectClass] = explorerClass;
}

#pragma mark - FLEXGlobalsEntry

+ (NSString *)globalsEntryTitle:(FLEXGlobalsRow)row {
    switch (row) {
        case FLEXGlobalsRowApplication:
            return @"应用程序";
        case FLEXGlobalsRowAppDelegate:
            return @"应用代理";
        case FLEXGlobalsRowKeyWindow:
            return @"主窗口";
        case FLEXGlobalsRowRootViewController:
            return @"根视图控制器";
        case FLEXGlobalsRowProcessInfo:
            return @"进程信息";
        case FLEXGlobalsRowUserDefaults:
            return @"用户偏好设置";
        case FLEXGlobalsRowMainBundle:
            return @"主资源包";
        case FLEXGlobalsRowMainScreen:
            return @"主屏幕";
        case FLEXGlobalsRowCurrentDevice:
            return @"当前设备";
        case FLEXGlobalsRowPasteboard:
            return @"剪贴板";
        case FLEXGlobalsRowURLSession:
            return @"URL会话";
        case FLEXGlobalsRowURLCache:
            return @"URL缓存";
        case FLEXGlobalsRowNotificationCenter:
            return @"通知中心";
        case FLEXGlobalsRowMenuController:
            return @"菜单控制器";
        case FLEXGlobalsRowFileManager:
            return @"文件管理器";
        case FLEXGlobalsRowTimeZone:
            return @"时区";
        case FLEXGlobalsRowLocale:
            return @"区域设置";
        case FLEXGlobalsRowCalendar:
            return @"日历";
        case FLEXGlobalsRowMainRunLoop:
            return @"主运行循环";
        case FLEXGlobalsRowMainThread:
            return @"主线程";
        case FLEXGlobalsRowOperationQueue:
            return @"操作队列";

        // 系统服务
        case FLEXGlobalsRowCookies:
            return @"HTTP Cookie 管理";
        case FLEXGlobalsRowCaches:
            return @"缓存";
        case FLEXGlobalsRowDictionaryPreferences:
            return @"字典偏好设置"; 
        case FLEXGlobalsRowWebKitPreferences:
            return @"WebKit偏好设置";
        case FLEXGlobalsRowNetworkHistory:
            return @"网络历史";
        case FLEXGlobalsRowSystemLog:
            return @"系统日志";
        case FLEXGlobalsRowLiveObjects:
            return @"实时对象";
        case FLEXGlobalsRowAddressInspector:
            return @"地址检查器";
        case FLEXGlobalsRowBrowseRuntime:
            return @"浏览运行时";
        case FLEXGlobalsRowAppKeychainItems:
            return @"钥匙串项目";
        case FLEXGlobalsRowBrowseBundle:
            return @"浏览资源包";
        case FLEXGlobalsRowBrowseContainer:
            return @"浏览容器";
        case FLEXGlobalsRowPushNotifications:
            return @"推送通知";
        case FLEXGlobalsRowCount:
            return nil;
    }
    
    return nil;
}

+ (UIViewController *)globalsEntryViewController:(FLEXGlobalsRow)row {
    switch (row) {
        case FLEXGlobalsRowAppDelegate: {
            id<UIApplicationDelegate> appDelegate = UIApplication.sharedApplication.delegate;
            return [self explorerViewControllerForObject:appDelegate];
        }
        case FLEXGlobalsRowProcessInfo:
            return [self explorerViewControllerForObject:NSProcessInfo.processInfo];
        case FLEXGlobalsRowUserDefaults:
            return [self explorerViewControllerForObject:NSUserDefaults.standardUserDefaults];
        case FLEXGlobalsRowMainBundle:
            return [self explorerViewControllerForObject:NSBundle.mainBundle];
        case FLEXGlobalsRowApplication:
            return [self explorerViewControllerForObject:UIApplication.sharedApplication];
        case FLEXGlobalsRowMainScreen:
            return [self explorerViewControllerForObject:UIScreen.mainScreen];
        case FLEXGlobalsRowCurrentDevice:
            return [self explorerViewControllerForObject:UIDevice.currentDevice];
        case FLEXGlobalsRowPasteboard:
            return [self explorerViewControllerForObject:UIPasteboard.generalPasteboard];
        case FLEXGlobalsRowURLSession:
            return [self explorerViewControllerForObject:NSURLSession.sharedSession];
        case FLEXGlobalsRowURLCache:
            return [self explorerViewControllerForObject:NSURLCache.sharedURLCache];
        case FLEXGlobalsRowNotificationCenter:
            return [self explorerViewControllerForObject:NSNotificationCenter.defaultCenter];
        case FLEXGlobalsRowMenuController:
            return [self explorerViewControllerForObject:UIMenuController.sharedMenuController];
        case FLEXGlobalsRowFileManager:
            return [self explorerViewControllerForObject:NSFileManager.defaultManager];
        case FLEXGlobalsRowTimeZone:
            return [self explorerViewControllerForObject:NSTimeZone.systemTimeZone];
        case FLEXGlobalsRowLocale:
            return [self explorerViewControllerForObject:NSLocale.currentLocale];
        case FLEXGlobalsRowCalendar:
            return [self explorerViewControllerForObject:NSCalendar.currentCalendar];
        case FLEXGlobalsRowMainRunLoop:
            return [self explorerViewControllerForObject:NSRunLoop.mainRunLoop];
        case FLEXGlobalsRowMainThread:
            return [self explorerViewControllerForObject:NSThread.mainThread];
        case FLEXGlobalsRowOperationQueue:
            return [self explorerViewControllerForObject:NSOperationQueue.mainQueue];

        case FLEXGlobalsRowKeyWindow:
            return [FLEXObjectExplorerFactory
                explorerViewControllerForObject:FLEXUtility.appKeyWindow
            ];
        case FLEXGlobalsRowRootViewController: {
            id<UIApplicationDelegate> delegate = UIApplication.sharedApplication.delegate;
            if ([delegate respondsToSelector:@selector(window)]) {
                return [self explorerViewControllerForObject:delegate.window.rootViewController];
            }

            return nil;
        }
        
        case FLEXGlobalsRowNetworkHistory:
            return [[FLEXNetworkMITMViewController alloc] init];
        case FLEXGlobalsRowSystemLog:
            return [[FLEXSystemLogViewController alloc] init];
        case FLEXGlobalsRowLiveObjects:
            return [[FLEXLiveObjectsController alloc] init];  // 修改此行，使用 Controller
        case FLEXGlobalsRowAddressInspector:
            return [[FLEXAddressExplorerViewController alloc] init];
        case FLEXGlobalsRowBrowseRuntime:
            return [[FLEXObjcRuntimeViewController alloc] init];
        case FLEXGlobalsRowAppKeychainItems:
            return [[FLEXKeychainViewController alloc] init];
        case FLEXGlobalsRowCookies:
            return [[FLEXCookiesViewController alloc] init];
        case FLEXGlobalsRowBrowseBundle:
            return [[FLEXFileBrowserController alloc] initWithPath:NSBundle.mainBundle.bundlePath];
        case FLEXGlobalsRowBrowseContainer:
            return [[FLEXFileBrowserController alloc] initWithPath:NSHomeDirectory()];
        case FLEXGlobalsRowCaches:
            return [self explorerViewControllerForObject:NSURLCache.sharedURLCache];
        case FLEXGlobalsRowDictionaryPreferences:
            return [self explorerViewControllerForObject:NSUserDefaults.standardUserDefaults];
        case FLEXGlobalsRowWebKitPreferences:
            return [self explorerViewControllerForObject:nil]; // 或返回适当的 WebKit 设置对象
        case FLEXGlobalsRowPushNotifications:
            return [[FLEXAPNSViewController alloc] init];
        case FLEXGlobalsRowCount:
            return nil;
    }
    
    return nil;
}

+ (FLEXGlobalsEntryRowAction)globalsEntryRowAction:(FLEXGlobalsRow)row {
    switch (row) {
        case FLEXGlobalsRowRootViewController: {
            // 检查 app delegate 是否响应 -window。如果不响应，则显示一个警告
            return ^(UITableViewController *host) {
                id<UIApplicationDelegate> delegate = UIApplication.sharedApplication.delegate;
                if ([delegate respondsToSelector:@selector(window)]) {
                    UIViewController *explorer = [self explorerViewControllerForObject:
                        delegate.window.rootViewController
                    ];
                    [host.navigationController pushViewController:explorer animated:YES];
                } else {
                    NSString *msg = @"App Delegate 不响应 -window";
                    [FLEXAlert showAlert:@":(" message:msg from:host];
                }
            };
        }
        default: return nil;
    }
}

@end
