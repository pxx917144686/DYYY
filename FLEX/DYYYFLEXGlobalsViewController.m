//
//  DYYYFLEXGlobalsViewController.m
//  Flipboard
//
//  Created by Ryan Olson on 2014-05-03.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

#import "DYYYFLEXGlobalsViewController.h"
#import "DYYYFLEXUtility.h"
#import "DYYYFLEXRuntimeUtility.h"
#import "DYYYFLEXObjcRuntimeViewController.h"
#import "DYYYFLEXKeychainViewController.h"
#import "DYYYFLEXAPNSViewController.h"
#import "DYYYFLEXObjectExplorerViewController.h"
#import "DYYYFLEXObjectExplorerFactory.h"
#import "DYYYFLEXLiveObjectsController.h"
#import "DYYYFLEXFileBrowserController.h"
#import "DYYYFLEXCookiesViewController.h"
#import "DYYYFLEXGlobalsEntry.h"
#import "DYYYFLEXManager+Private.h"
#import "DYYYFLEXSystemLogViewController.h"
#import "DYYYFLEXNetworkMITMViewController.h"
#import "DYYYFLEXAddressExplorerCoordinator.h"
#import "DYYYFLEXGlobalsSection.h"
#import "UIBarButtonItem+FLEX.h"

@interface DYYYFLEXGlobalsViewController ()
// 表视图中仅显示的部分；空部分从此数组中清除。
@property (nonatomic) NSArray<DYYYFLEXGlobalsSection *> *sections;
/// 表视图中的所有部分，无论部分是否为空。
@property (nonatomic, readonly) NSArray<DYYYFLEXGlobalsSection *> *allSections;
@property (nonatomic, readonly) BOOL manuallyDeselectOnAppear;
@end

@implementation DYYYFLEXGlobalsViewController
@dynamic sections, allSections;

#pragma mark - 初始化

+ (NSString *)globalsTitleForSection:(FLEXGlobalsSectionKind)section {
    switch (section) {
        case FLEXGlobalsSectionProcessAndEvents:
            return @"进程与事件";
        case FLEXGlobalsSectionAppShortcuts:
            return @"应用快捷方式";
        case FLEXGlobalsSectionMisc:
            return @"杂项";

        default:
            @throw NSInternalInconsistencyException;
    }
}

+ (DYYYFLEXGlobalsEntry *)globalsEntryForRow:(FLEXGlobalsRow)row {
    switch (row) {
        case FLEXGlobalsRowAppKeychainItems:
            return [DYYYFLEXKeychainViewController flex_concreteGlobalsEntry:row];
        case FLEXGlobalsRowPushNotifications:
            return [DYYYFLEXAPNSViewController flex_concreteGlobalsEntry:row];
        case FLEXGlobalsRowAddressInspector:
            return [DYYYFLEXAddressExplorerCoordinator flex_concreteGlobalsEntry:row];
        case FLEXGlobalsRowBrowseRuntime:
            return [DYYYFLEXObjcRuntimeViewController flex_concreteGlobalsEntry:row];
        case FLEXGlobalsRowLiveObjects:
            return [DYYYFLEXLiveObjectsController flex_concreteGlobalsEntry:row];
        case FLEXGlobalsRowCookies:
            return [DYYYFLEXCookiesViewController flex_concreteGlobalsEntry:row];
        case FLEXGlobalsRowBrowseBundle:
        case FLEXGlobalsRowBrowseContainer:
            return [DYYYFLEXFileBrowserController flex_concreteGlobalsEntry:row];
        case FLEXGlobalsRowSystemLog:
            return [DYYYFLEXSystemLogViewController flex_concreteGlobalsEntry:row];
        case FLEXGlobalsRowNetworkHistory:
            return [DYYYFLEXNetworkMITMViewController flex_concreteGlobalsEntry:row];
        case FLEXGlobalsRowKeyWindow:
        case FLEXGlobalsRowRootViewController:
        case FLEXGlobalsRowProcessInfo:
        case FLEXGlobalsRowAppDelegate:
        case FLEXGlobalsRowUserDefaults:
        case FLEXGlobalsRowMainBundle:
        case FLEXGlobalsRowApplication:
        case FLEXGlobalsRowMainScreen:
        case FLEXGlobalsRowCurrentDevice:
        case FLEXGlobalsRowPasteboard:
        case FLEXGlobalsRowURLSession:
        case FLEXGlobalsRowURLCache:
        case FLEXGlobalsRowNotificationCenter:
        case FLEXGlobalsRowMenuController:
        case FLEXGlobalsRowFileManager:
        case FLEXGlobalsRowTimeZone:
        case FLEXGlobalsRowLocale:
        case FLEXGlobalsRowCalendar:
        case FLEXGlobalsRowMainRunLoop:
        case FLEXGlobalsRowMainThread:
        case FLEXGlobalsRowOperationQueue:
            return [DYYYFLEXObjectExplorerFactory flex_concreteGlobalsEntry:row];
            
        case FLEXGlobalsRowCount:
        default:
            @throw [NSException
                exceptionWithName:NSInternalInconsistencyException
                reason:@"在switch中缺少globals情况" 
                userInfo:nil
            ];
    }
}

+ (NSArray<DYYYFLEXGlobalsSection *> *)defaultGlobalSections {
    static NSMutableArray<DYYYFLEXGlobalsSection *> *sections = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSDictionary<NSNumber *, NSArray<DYYYFLEXGlobalsEntry *> *> *rowsBySection = @{
            @(FLEXGlobalsSectionProcessAndEvents) : @[
                [self globalsEntryForRow:FLEXGlobalsRowNetworkHistory],
                [self globalsEntryForRow:FLEXGlobalsRowSystemLog],
                [self globalsEntryForRow:FLEXGlobalsRowProcessInfo],
                [self globalsEntryForRow:FLEXGlobalsRowLiveObjects],
                [self globalsEntryForRow:FLEXGlobalsRowAddressInspector],
                [self globalsEntryForRow:FLEXGlobalsRowBrowseRuntime],
            ],
            @(FLEXGlobalsSectionAppShortcuts) : @[
                [self globalsEntryForRow:FLEXGlobalsRowBrowseBundle],
                [self globalsEntryForRow:FLEXGlobalsRowBrowseContainer],
                [self globalsEntryForRow:FLEXGlobalsRowMainBundle],
                [self globalsEntryForRow:FLEXGlobalsRowUserDefaults],
                [self globalsEntryForRow:FLEXGlobalsRowAppKeychainItems],
                [self globalsEntryForRow:FLEXGlobalsRowPushNotifications],
                [self globalsEntryForRow:FLEXGlobalsRowApplication],
                [self globalsEntryForRow:FLEXGlobalsRowAppDelegate],
                [self globalsEntryForRow:FLEXGlobalsRowKeyWindow],
                [self globalsEntryForRow:FLEXGlobalsRowRootViewController],
                [self globalsEntryForRow:FLEXGlobalsRowCookies],
            ],
            @(FLEXGlobalsSectionMisc) : @[
                [self globalsEntryForRow:FLEXGlobalsRowPasteboard],
                [self globalsEntryForRow:FLEXGlobalsRowMainScreen],
                [self globalsEntryForRow:FLEXGlobalsRowCurrentDevice],
                [self globalsEntryForRow:FLEXGlobalsRowURLSession],
                [self globalsEntryForRow:FLEXGlobalsRowURLCache],
                [self globalsEntryForRow:FLEXGlobalsRowNotificationCenter],
                [self globalsEntryForRow:FLEXGlobalsRowMenuController],
                [self globalsEntryForRow:FLEXGlobalsRowFileManager],
                [self globalsEntryForRow:FLEXGlobalsRowTimeZone],
                [self globalsEntryForRow:FLEXGlobalsRowLocale],
                [self globalsEntryForRow:FLEXGlobalsRowCalendar],
                [self globalsEntryForRow:FLEXGlobalsRowMainRunLoop],
                [self globalsEntryForRow:FLEXGlobalsRowMainThread],
                [self globalsEntryForRow:FLEXGlobalsRowOperationQueue],
            ]
        };

        sections = [NSMutableArray array];
        for (FLEXGlobalsSectionKind i = FLEXGlobalsSectionProcessAndEvents; i < FLEXGlobalsSectionCount; ++i) {
            NSString *title = [self globalsTitleForSection:i];
            [sections addObject:[DYYYFLEXGlobalsSection title:title rows:rowsBySection[@(i)]]];
        }
    });
    
    return sections;
}


#pragma mark - 重写

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"💪  FLEX";
    self.showsSearchBar = YES;
    self.searchBarDebounceInterval = kFLEXDebounceInstant;
    self.navigationItem.backBarButtonItem = [UIBarButtonItem flex_backItemWithTitle:@"返回"];
    
    _manuallyDeselectOnAppear = NSProcessInfo.processInfo.operatingSystemVersion.majorVersion < 10;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self disableToolbar];
    
    if (self.manuallyDeselectOnAppear) {
        [self.tableView deselectRowAtIndexPath:self.tableView.indexPathForSelectedRow animated:YES];
    }
}

- (NSArray<DYYYFLEXGlobalsSection *> *)makeSections {
    NSMutableArray<DYYYFLEXGlobalsSection *> *sections = [NSMutableArray array];

    [sections addObjectsFromArray:[self.class defaultGlobalSections]];

    return sections;
}

- (DYYYFLEXGlobalsEntry *)globalsEntryAtIndex:(NSInteger)index {
    FLEXGlobalsRow row = [self globalRowAtIndex:index];
    
    // 直接调用类方法，避免重复代码和错误的方法名
    return [[self class] globalsEntryForRow:row];
}

- (FLEXGlobalsRow)globalRowAtIndex:(NSInteger)index {
    // 这里根据项目实际逻辑进行实现，简单示例:
    return (FLEXGlobalsRow)index;
}

@end
