//
//  DYYYFLEXObjcRuntimeViewController.m
//  FLEX
//
//  Created by Tanner on 3/23/17.
//  Copyright © 2017 Tanner Bennett. All rights reserved.
//

#import "DYYYFLEXObjcRuntimeViewController.h"
#import "DYYYFLEXKeyPathSearchController.h"
#import "DYYYFLEXRuntimeBrowserToolbar.h"
#import "UIGestureRecognizer+Blocks.h"
#import "UIBarButtonItem+FLEX.h"
#import "DYYYFLEXTableView.h"
#import "DYYYFLEXObjectExplorerFactory.h"
#import "DYYYFLEXAlert.h"
#import "DYYYFLEXRuntimeClient.h"
#import <dlfcn.h>

@interface DYYYFLEXObjcRuntimeViewController () <FLEXKeyPathSearchControllerDelegate>

@property (nonatomic, readonly ) DYYYFLEXKeyPathSearchController *keyPathController;
@property (nonatomic, readonly ) UIView *promptView;

@end

@implementation DYYYFLEXObjcRuntimeViewController

#pragma mark - 设置，视图事件

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 长按导航栏以初始化webkit legacy
    //
    // 在搜索所有包之前，我们会自动调用initializeWebKitLegacy
    // 只是为了安全起见（因为在WebKit初始化之前触摸某些类会
    // 在主线程之外的线程上初始化它），但有时您可能会遇到这种崩溃
    // 而无需搜索所有包，当然。
    [self.navigationController.navigationBar addGestureRecognizer:[
        [UILongPressGestureRecognizer alloc]
            initWithTarget:[DYYYFLEXRuntimeClient class]
            action:@selector(initializeWebKitLegacy)
        ]
    ];
    
    [self addToolbarItems:@[FLEXBarButtonItem(@"动态加载()", self, @selector(dlopenPressed:))]];
    
    // 搜索栏相关设置，必须先设置因为这会创建self.searchController
    self.showsSearchBar = YES;
    self.showSearchBarInitially = YES;
    self.activatesSearchBarAutomatically = YES;
    // 在此屏幕上使用pinSearchBar会导致下一个
    // 被推送的视图控制器出现奇怪的视觉问题。
    //
    // self.pinSearchBar = YES;
    self.searchController.searchBar.placeholder = @"UIKit*.UIView.-setFrame:";

    // 搜索控制器相关设置
    // 键路径控制器自动将自己分配为搜索栏的委托
    // 为避免下面的保留循环，使用局部变量
    UISearchBar *searchBar = self.searchController.searchBar;
    DYYYFLEXKeyPathSearchController *keyPathController = [DYYYFLEXKeyPathSearchController delegate:self];
    _keyPathController = keyPathController;
    _keyPathController.toolbar = [DYYYFLEXRuntimeBrowserToolbar toolbarWithHandler:^(NSString *text, BOOL suggestion) {
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

/// 提示用户选择dlopen快捷方式
- (void)dlopenPressed:(id)sender {
    [DYYYFLEXAlert makeAlert:^(DYYYFLEXAlert *make) {
        make.title(@"动态开放库");
        make.message(@"使用输入的路径调用dlopen()。在下面选择一个选项。");
        
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

/// 提示用户输入并执行dlopen
- (void)dlopenWithFormat:(NSString *)format {
    [DYYYFLEXAlert makeAlert:^(DYYYFLEXAlert *make) {
        make.title(@"动态开放库");
        if (format) {
            make.message(@"输入一个框架名称，如CarKit或FrontBoard。");
        } else {
            make.message(@"输入二进制文件的绝对路径。");
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
                [DYYYFLEXAlert makeAlert:^(DYYYFLEXAlert *make) {
                    make.title(@"错误").message(@(dlerror()));
                    make.button(@"关闭").cancelStyle();
                }];
            }
        });
    } showFrom:self];
}

- (void)dlopenInvalidPath {
    [DYYYFLEXAlert makeAlert:^(DYYYFLEXAlert * _Nonnull make) {
        make.title(@"路径或名称太短");
        make.button(@"关闭").cancelStyle();
    } showFrom:self];
}


#pragma mark 委托相关

- (void)didSelectImagePath:(NSString *)path shortName:(NSString *)shortName {
    [DYYYFLEXAlert makeAlert:^(DYYYFLEXAlert *make) {
        make.title(shortName);
        make.message(@"没有与此路径关联的NSBundle：\n\n");
        make.message(path);

        make.button(@"复制路径").handler(^(NSArray<NSString *> *strings) {
            UIPasteboard.generalPasteboard.string = path;
        });
        make.button(@"关闭").cancelStyle();
    } showFrom:self];
}

- (void)didSelectBundle:(NSBundle *)bundle {
    NSParameterAssert(bundle);
    DYYYFLEXObjectExplorerViewController *explorer = [DYYYFLEXObjectExplorerFactory explorerViewControllerForObject:bundle];
    [self.navigationController pushViewController:explorer animated:YES];
}

- (void)didSelectClass:(Class)cls {
    NSParameterAssert(cls);
    DYYYFLEXObjectExplorerViewController *explorer = [DYYYFLEXObjectExplorerFactory explorerViewControllerForObject:cls];
    [self.navigationController pushViewController:explorer animated:YES];
}


#pragma mark - DYYYFLEXGlobalsEntry

+ (NSString *)globalsEntryTitle:(FLEXGlobalsRow)row {
    return @"📚  APP加载库";
}

+ (UIViewController *)globalsEntryViewController:(FLEXGlobalsRow)row {
    UIViewController *controller = [self new];
    controller.title = [self globalsEntryTitle:row];
    return controller;
}

@end
