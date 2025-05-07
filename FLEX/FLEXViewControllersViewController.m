// filepath: FLEXViewControllersViewController.m
//
//  FLEXViewControllersViewController.m
//  FLEX
//
//  Created by Tanner Bennett on 2/13/20.
//  Copyright © 2020 FLEX Team. All rights reserved.
// 遇到问题联系中文翻译作者：pxx917144686

#import "FLEXViewControllersViewController.h"
#import "FLEXObjectExplorerFactory.h"
#import "FLEXUtility.h"
#import "FLEXTableViewSection.h"
#import "FLEXMutableListSection.h"

@interface FLEXViewControllersViewController ()
@property (nonatomic) NSArray<UIViewController *> *controllers;
@property (nonatomic) FLEXMutableListSection *section;
@end

@implementation FLEXViewControllersViewController
@dynamic sections, allSections;

+ (instancetype)controllersForViews:(NSArray<UIView *> *)views {
    return [[self alloc] initWithViews:views];
}

- (id)initWithViews:(NSArray<UIView *> *)views {
    self = [self initWithStyle:UITableViewStylePlain];
    if (self) {
        _controllers = [views flex_mapped:^id(UIView *view, NSUInteger idx) {
            return [FLEXUtility viewControllerForView:view];
        }];
    }
    
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"点击处的视图控制器";
    self.showsSearchBar = YES;
    [self disableToolbar];
}

- (NSArray<FLEXTableViewSection *> *)makeSections {
    _section = [FLEXMutableListSection list:self.controllers
        cellConfiguration:^(UITableViewCell *cell, UIViewController *controller, NSInteger row) {
            cell.textLabel.text = [NSString
                stringWithFormat:@"%@ — %p", NSStringFromClass(controller.class), controller
            ];
            cell.detailTextLabel.text = controller.view.description;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.textLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    } filterMatcher:^BOOL(NSString *filterText, UIViewController *controller) {
        return [NSStringFromClass(controller.class) localizedCaseInsensitiveContainsString:filterText];
    }];
    
    self.section.selectionHandler = ^(UIViewController *host, UIViewController *controller) {
        [host.navigationController pushViewController:
            [FLEXObjectExplorerFactory explorerViewControllerForObject:controller]
        animated:YES];
    };
    
    self.section.customTitle = @"视图控制器";
    return @[self.section];
}


#pragma mark - 私有

- (void)dismissAnimated {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
