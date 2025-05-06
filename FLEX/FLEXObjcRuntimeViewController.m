// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXObjcRuntimeViewController.m
//  FLEX
//
//  Created by Tanner on 3/23/17.
//  Copyright © 2017 Tanner Bennett. All rights reserved.
//

#import "FLEXObjcRuntimeViewController.h"
#import "FLEXKeyPathSearchController.h"
#import "FLEXRuntimeBrowserToolbar.h"
#import "UIGestureRecognizer+Blocks.h"
#import "UIBarButtonItem+FLEX.h"
#import "FLEXTableView.h"
#import "FLEXObjectExplorerFactory.h"
#import "FLEXAlert.h"
#import "FLEXRuntimeClient.h"
#import <dlfcn.h>

@interface FLEXObjcRuntimeViewController () <FLEXKeyPathSearchControllerDelegate>

@property (nonatomic, readonly ) FLEXKeyPathSearchController *keyPathController;
@property (nonatomic, readonly ) UIView *promptView;

@end

@implementation FLEXObjcRuntimeViewController

#pragma mark - 设置和视图事件

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 长按导航栏以初始化 WebKit 旧版
    //
    // 为了安全起见，在搜索所有 bundles 之前，我们会自动调用 initializeWebKitLegacy（因为在 WebKit 初始化之前接触某些类会在主线程以外的线程上初始化它），
    // 但有时当然也会在不搜索所有 bundles 的情况下遇到此崩溃。
    [self.navigationController.navigationBar addGestureRecognizer:[
        [UILongPressGestureRecognizer alloc]
            initWithTarget:[FLEXRuntimeClient class]
            action:@selector(initializeWebKitLegacy)
        ]
    ];
    
    [self addToolbarItems:@[FLEXBarButtonItem(@"dlopen()", self, @selector(dlopenPressed:))]];
    
    // 搜索栏相关，必须放在最前面，因为它会创建 self.searchController
    self.showsSearchBar = YES;
    self.showSearchBarInitially = YES;
    self.activatesSearchBarAutomatically = YES;
    // 在此屏幕上使用 pinSearchBar 会导致下一个被推入的视图控制器出现奇怪的视觉问题。
    //
    // self.pinSearchBar = YES;
    self.searchController.searchBar.placeholder = @"UIKit*.UIView.-setFrame:";

    // 搜索控制器相关
    // 键路径控制器自动将自身指定为搜索栏的委托
    // 为避免下面的保留环，请使用局部变量
    UISearchBar *searchBar = self.searchController.searchBar;
    FLEXKeyPathSearchController *keyPathController = [FLEXKeyPathSearchController delegate:self];
    _keyPathController = keyPathController;
    _keyPathController.toolbar = [FLEXRuntimeBrowserToolbar toolbarWithHandler:^(NSString *text, BOOL suggestion) {
        if (suggestion) {
            [keyPathController didSelectKeyPathOption:text];
        } else {
            [keyPathController didPressButton:text insertInto:searchBar];
        }
    } suggestions:keyPathController.suggestions];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView deselectRowAtIndexPath:self.tableView.indexPathForSelectedRow animated:YES];
}


#pragma mark dlopen

/// 提示用户选择 dlopen 快捷方式
- (void)dlopenPressed:(id)sender {
    [FLEXAlert makeAlert:^(FLEXAlert *make) {
        make.title(@"动态开放库");
        make.message(@"使用输入的路径调用dlopen（）。在下面选择一个选项。");
        
        make.button(@"系统框架").handler(^(NSArray<NSString *> *_) {
            [self dlopenWithFormat:@"/System/Library/Frameworks/%@.framework/%@"];
        });
        make.button(@"系统私有框架").handler(^(NSArray<NSString *> *_) {
            [self dlopenWithFormat:@"/System/Library/PrivateFrameworks/%@.framework/%@"];
        });
        make.button(@"任意二进制").handler(^(NSArray<NSString *> *_) {
            [self dlopenWithFormat:nil];
        });
        
        make.button(@"取消").cancelStyle();
    } showFrom:self];
}

/// 提示用户输入并执行 dlopen
- (void)dlopenWithFormat:(NSString *)format {
    [FLEXAlert makeAlert:^(FLEXAlert *make) {
        make.title(@"动态开放库");
        if (format) {
            make.message(@"通过一个框架名称，如CarKit或FrontBoard。");
        } else {
            make.message(@"Pass in an absolute path to a binary.");
        }
        
        make.textField(format ? @"ARKit" : @"/System/Library/Frameworks/ARKit.framework/ARKit");
        
        make.button(@"取消").cancelStyle();
        make.button(@"打开").destructiveStyle().handler(^(NSArray<NSString *> *strings) {
            NSString *path = strings[0];
            
            if (path.length < 2) {
                [self dlopenInvalidPath];
            } else if (format) {
                path = [NSString stringWithFormat:format, path, path];
            }
            
            if (!dlopen(path.UTF8String, RTLD_NOW)) {
                [FLEXAlert makeAlert:^(FLEXAlert *make) {
                    make.title(@"Error").message(@(dlerror()));
                    make.button(@"Dismiss").cancelStyle();
                }];
            }
        });
    } showFrom:self];
}

- (void)dlopenInvalidPath {
    [FLEXAlert makeAlert:^(FLEXAlert * _Nonnull make) {
        make.title(@"路径或名称太短");
        make.button(@"Dismiss").cancelStyle();
    } showFrom:self];
}


#pragma mark 委托相关

- (void)didSelectImagePath:(NSString *)path shortName:(NSString *)shortName {
    [FLEXAlert makeAlert:^(FLEXAlert *make) {
        make.title(shortName);
        make.message(@"此路径没有关联的 NSBundle：\n\n");
        make.message(path);

        make.button(@"复制路径").handler(^(NSArray<NSString *> *strings) {
            UIPasteboard.generalPasteboard.string = path;
        });
        make.button(@"Dismiss").cancelStyle();
    } showFrom:self];
}

- (void)didSelectBundle:(NSBundle *)bundle {
    NSParameterAssert(bundle);
    FLEXObjectExplorerViewController *explorer = [FLEXObjectExplorerFactory explorerViewControllerForObject:bundle];
    [self.navigationController pushViewController:explorer animated:YES];
}

- (void)didSelectClass:(Class)cls {
    NSParameterAssert(cls);
    FLEXObjectExplorerViewController *explorer = [FLEXObjectExplorerFactory explorerViewControllerForObject:cls];
    [self.navigationController pushViewController:explorer animated:YES];
}


#pragma mark - FLEXGlobalsEntry

+ (NSString *)globalsEntryTitle:(FLEXGlobalsRow)row {
    return @"📚  APP加载库";
}

+ (UIViewController *)globalsEntryViewController:(FLEXGlobalsRow)row {
    UIViewController *controller = [self new];
    controller.title = [self globalsEntryTitle:row];
    return controller;
}

@end
