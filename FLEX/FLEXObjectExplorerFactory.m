//
//  FLEXObjectExplorerFactory.m
//  Flipboard
//
//  Created by Ryan Olson on 5/15/14.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

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

@implementation FLEXObjectExplorerFactory
static NSMutableDictionary<id<NSCopying>, Class> *classesToRegisteredSections = nil;

+ (void)initialize {
    if (self == [FLEXObjectExplorerFactory class]) {
        // 不要在这里使用字符串键
        // 我们需要使用类作为键，因为我们无法
        // 区分类的名称和元类的名称。
        // 这些映射是按类对象而不是按类名进行的。
        //
        // 例如，如果我们使用类名，这将导致
        // 对象浏览器试图为UIColor类对象渲染颜色预览，
        // 而类对象本身不是颜色。
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
    // 不能浏览nil
    if (!object) {
        return nil;
    }

    // 如果我们被给予一个对象，这将查找它的类层次结构
    // 直到找到一个注册。这将适用于KVC类，
    // 因为它们是原始类的子类，而不是兄弟类。
    // 如果我们给定一个对象，object_getClass将返回一个元类，
    // 同样的事情也会发生。FLEXClassShortcuts是NSObject的默认
    // 快捷方式部分。
    //
    // TODO: 将其重命名为FLEXNSObjectShortcuts或类似名称？
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
        
        // 如果该部分"替换"了默认的快捷方式部分，
        // 则仅返回该部分。否则，返回此部分
        // 和默认快捷方式部分。
        if (isFLEXShortcutSection && ![customSection isNewSection]) {
            sections = @[customSection];
        } else {
            // 自定义部分将在快捷方式之前
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

+ (NSString *)globalsEntryTitle:(FLEXGlobalsRow)row  {
    switch (row) {
        case FLEXGlobalsRowAppDelegate:
            return @"🎟  应用程序委托";
        case FLEXGlobalsRowKeyWindow:
            return @"🔑  关键窗口";
        case FLEXGlobalsRowRootViewController:
            return @"🌴  根视图控制器";
        case FLEXGlobalsRowProcessInfo:
            return @"🚦  进程信息";
        case FLEXGlobalsRowUserDefaults:
            return @"💾  偏好配置";
        case FLEXGlobalsRowMainBundle:
            return @"📦  查看MainBundle";
        case FLEXGlobalsRowApplication:
            return @"🚀  用户界面应用程序.共享应用程序";
        case FLEXGlobalsRowMainScreen:
            return @"💻  用户界面屏幕.主屏幕";
        case FLEXGlobalsRowCurrentDevice:
            return @"📱  用户界面设备.当前设备";
        case FLEXGlobalsRowPasteboard:
            return @"📋  UI粘贴板.通用粘贴板";
        case FLEXGlobalsRowURLSession:
            return @"📡  NSURL会议.sharedSession";
        case FLEXGlobalsRowURLCache:
            return @"⏳  NSURL缓存.共享URL缓存";
        case FLEXGlobalsRowNotificationCenter:
            return @"🔔  NS通知中心.默认中心";
        case FLEXGlobalsRowMenuController:
            return @"📎  UI菜单控制器.共享菜单控制器";
        case FLEXGlobalsRowFileManager:
            return @"🗄  NS文件管理器.默认管理器";
        case FLEXGlobalsRowTimeZone:
            return @"🌎  NS时区.系统时区";
        case FLEXGlobalsRowLocale:
            return @"🗣  NS发生地点.当前本地";
        case FLEXGlobalsRowCalendar:
            return @"📅  NS日历.当前日历";
        case FLEXGlobalsRowMainRunLoop:
            return @"🏃🏻‍♂️  NS运行循环.主运行循环";
        case FLEXGlobalsRowMainThread:
            return @"🧵  NS纱线.主线程";
        case FLEXGlobalsRowOperationQueue:
            return @"📚  NS队列操作.主队列";
        default: return nil;
    }
}

+ (UIViewController *)globalsEntryViewController:(FLEXGlobalsRow)row  {
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
        case FLEXGlobalsRowSystemLog:
        case FLEXGlobalsRowLiveObjects:
        case FLEXGlobalsRowAddressInspector:
        case FLEXGlobalsRowCookies:
        case FLEXGlobalsRowBrowseRuntime:
        case FLEXGlobalsRowAppKeychainItems:
        case FLEXGlobalsRowPushNotifications:
        case FLEXGlobalsRowBrowseBundle:
        case FLEXGlobalsRowBrowseContainer:
        case FLEXGlobalsRowCount:
            return nil;
    }
    
    return nil;
}

+ (FLEXGlobalsEntryRowAction)globalsEntryRowAction:(FLEXGlobalsRow)row {
    switch (row) {
        case FLEXGlobalsRowRootViewController: {
            // 检查应用程序委托是否响应-window。如果不是，则显示警报
            return ^(UITableViewController *host) {
                id<UIApplicationDelegate> delegate = UIApplication.sharedApplication.delegate;
                if ([delegate respondsToSelector:@selector(window)]) {
                    UIViewController *explorer = [self explorerViewControllerForObject:
                        delegate.window.rootViewController
                    ];
                    [host.navigationController pushViewController:explorer animated:YES];
                } else {
                    NSString *msg = @"应用程序委托不响应-window";
                    [FLEXAlert showAlert:@":(" message:msg from:host];
                }
            };
        }
        default: return nil;
    }
}

@end
