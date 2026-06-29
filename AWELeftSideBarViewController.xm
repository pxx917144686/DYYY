#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <CoreLocation/CoreLocation.h>

#define DYYYBottomAlertView_DEFINED
#define DYYYToast_DEFINED
#define DYYYFilterSettingsView_DEFINED
#define DYYYUtils_DEFINED
#define DYYYConfirmCloseView_DEFINED
#define DYYYKeywordListView_DEFINED
#define DYYYCustomInputView_DEFINED

#import "AwemeHeaders.h"
#import "CityManager.h"
#import "DYYYManager.h"
#import "DYYYSettingViewController.h"
#import "DYYYToast.h"
#import "DYYYBottomAlertView.h"
#import "DYYYConfirmCloseView.h"

// UIView 类别扩展，添加辅助方法用于查找视图
@implementation UIView (Helper)
// 递归检查视图及其子视图是否包含指定类名的视图
- (BOOL)containsClassNamed:(NSString *)className {
    if ([[[self class] description] isEqualToString:className]) {
        return YES;
    }
    for (UIView *subview in self.subviews) {
        if ([subview containsClassNamed:className]) {
            return YES;
        }
    }
    return NO;
}

// 递归查找并返回指定类名的视图
- (UIView *)findViewWithClassName:(NSString *)className {
    if ([[[self class] description] isEqualToString:className]) {
        return self;
    }
    for (UIView *subview in self.subviews) {
        UIView *result = [subview findViewWithClassName:className];
        if (result) {
            return result;
        }
    }
    return nil;
}
@end

// 用于保存需要保留的单元格信息的字典
static NSMutableDictionary *keepCellsInfo;

// 定义需要处理的视图类名常量
static NSString *const kAWELeftSideBarTopRightLayoutView = @"AWELeftSideBarTopRightLayoutView";
static NSString *const kAWELeftSideBarFunctionContainerView = @"AWELeftSideBarFunctionContainerView";
static NSString *const kAWELeftSideBarWeatherView = @"AWELeftSideBarWeatherView";

// 定义简化侧边栏功能的 UserDefaults 键名
static NSString *const kStreamlineSidebarKey = @"DYYYStreamlinethesidebar";

// C 函数来处理容器视图布局调整
static void adjustContainerViewLayout(AWELeftSideBarViewController *controller, UICollectionViewCell *containerCell, UICollectionView *collectionView) {
    if (![[NSUserDefaults standardUserDefaults] boolForKey:kStreamlineSidebarKey]) {
        return;
    }

    if (!collectionView || !containerCell)
        return;

    // 查找功能容器视图
    UIView *containerView = [containerCell.contentView findViewWithClassName:kAWELeftSideBarFunctionContainerView];
    if (!containerView)
        return;

    // 计算新的高度，使其更好地适应屏幕
    CGFloat windowHeight = collectionView.window.bounds.size.height;
    CGFloat currentY = [containerCell convertPoint:containerCell.bounds.origin toView:nil].y;
    CGFloat newHeight = windowHeight - currentY - 20;

    // 调整容器视图大小
    CGRect containerFrame = containerView.frame;
    containerFrame.size.height = newHeight;
    containerView.frame = containerFrame;

    // 调整单元格大小
    CGRect cellFrame = containerCell.frame;
    cellFrame.size.height = newHeight;
    containerCell.frame = cellFrame;
}

// 修改左侧边栏视图控制器
%hook AWELeftSideBarViewController

// 视图加载时初始化数据结构
- (void)viewDidLoad {
    %orig;

    if (![[NSUserDefaults standardUserDefaults] boolForKey:kStreamlineSidebarKey]) {
        return;
    }

    if (!keepCellsInfo) {
        keepCellsInfo = [NSMutableDictionary dictionary];
    }
}

// 视图消失时清理数据
- (void)viewDidDisappear:(BOOL)animated {
    %orig;

    if (![[NSUserDefaults standardUserDefaults] boolForKey:kStreamlineSidebarKey]) {
        return;
    }

    [keepCellsInfo removeAllObjects];
}

// 自定义集合视图单元格，隐藏不需要的元素
- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewCell *cell = %orig;

    if (![[NSUserDefaults standardUserDefaults] boolForKey:kStreamlineSidebarKey]) {
        return cell;
    }

    if (!cell)
        return cell;

    @try {
        // 检查单元格是否包含需要保留的视图类型
        BOOL shouldKeep = [cell.contentView containsClassNamed:kAWELeftSideBarTopRightLayoutView] || [cell.contentView containsClassNamed:kAWELeftSideBarFunctionContainerView] ||
                  [cell.contentView containsClassNamed:kAWELeftSideBarWeatherView];

        // 记录当前单元格的保留状态
        NSString *key = [NSString stringWithFormat:@"%ld-%ld", (long)indexPath.section, (long)indexPath.row];
        keepCellsInfo[key] = @(shouldKeep);

        // 处理不需要保留的单元格，将其隐藏并设置大小为零
        if (!shouldKeep) {
            cell.hidden = YES;
            cell.alpha = 0;
            CGRect frame = cell.frame;
            frame.size.width = 0;
            frame.size.height = 0;
            cell.frame = frame;
        } else if ([cell.contentView containsClassNamed:kAWELeftSideBarFunctionContainerView]) {
            // 调用 C 函数来调整容器视图布局
            adjustContainerViewLayout(self, cell, collectionView);
        }
    } @catch (NSException *exception) {
        NSLog(@"Error in cellForItemAtIndexPath: %@", exception);
    }

    return cell;
}

// 自定义单元格大小，隐藏不需要的元素
- (CGSize)collectionView:(UICollectionView *)collectionView layout:(id)layout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    CGSize originalSize = %orig;

    if (![[NSUserDefaults standardUserDefaults] boolForKey:kStreamlineSidebarKey]) {
        return originalSize;
    }

    // 检查单元格是否应该保留
    NSString *key = [NSString stringWithFormat:@"%ld-%ld", (long)indexPath.section, (long)indexPath.row];
    NSNumber *shouldKeep = keepCellsInfo[key];

    // 不需要保留的单元格大小设为零
    if (shouldKeep != nil && ![shouldKeep boolValue]) {
        return CGSizeZero;
    }

    return originalSize;
}

// 自定义分区内边距，优化布局
- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(id)layout insetForSectionAtIndex:(NSInteger)section {
    UIEdgeInsets originalInsets = %orig;

    if (![[NSUserDefaults standardUserDefaults] boolForKey:kStreamlineSidebarKey]) {
        return originalInsets;
    }

    // 检查该分区是否有需要保留的单元格
    BOOL hasKeepCells = NO;
    for (NSString *key in keepCellsInfo.allKeys) {
        if ([key hasPrefix:[NSString stringWithFormat:@"%ld-", (long)section]] && [keepCellsInfo[key] boolValue]) {
            hasKeepCells = YES;
            break;
        }
    }

    // 如果分区没有需要保留的单元格，则内边距设为零
    if (!hasKeepCells) {
        return UIEdgeInsetsZero;
    }

    return originalInsets;
}

%end