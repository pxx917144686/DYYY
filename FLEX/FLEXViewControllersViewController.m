//
//  FLEXViewControllersViewController.m
//  FLEX
//
//  由 Tanner Bennett 创建于 2/13/20.
//  版权所有 © 2020 FLEX Team. 保留所有权利。
//

#import "FLEXViewControllersViewController.h"
#import "FLEXObjectExplorerFactory.h"
#import "FLEXMutableListSection.h"
#import "FLEXUtility.h"

@interface FLEXViewControllersViewController ()
@property (nonatomic, readonly) FLEXMutableListSection *section;
@property (nonatomic, readonly) NSArray<UIViewController *> *controllers;
@end

@implementation FLEXViewControllersViewController
@dynamic sections, allSections;

#pragma mark - 初始化

+ (instancetype)controllersForViews:(NSArray<UIView *> *)views {
    return [[self alloc] initWithViews:views];
}

- (id)initWithViews:(NSArray<UIView *> *)views {
    NSParameterAssert(views.count);
    
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
                stringWithFormat:@"%@ — %p", NSStringFromClass(controller.class), controller
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


#pragma mark - 私有方法

- (void)dismissAnimated {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
