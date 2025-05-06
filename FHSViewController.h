// 遇到问题联系中文翻译作者：pxx917144686
//
//  FHSViewController.h
//  FLEX
//
//  Created by Tanner Bennett on 1/6/20.
//  Copyright © 2020 FLEX Team. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 视图控制器，用于显示视图层次结构的 3D 快照。
/// "FHS" 代表 "FLEX (view) hierarchy snapshot"（FLEX 视图层次结构快照）。
@interface FHSViewController : UIViewController

/// 当您想要快照一组窗口时使用此方法。
+ (instancetype)snapshotWindows:(NSArray<UIWindow *> *)windows;
/// 当您想要快照视图层次结构的特定部分时使用此方法。
+ (instancetype)snapshotView:(UIView *)view;
/// 当您想要强调屏幕上的特定视图时使用此方法。
/// 这些视图必须与选定视图位于同一个窗口中。
+ (instancetype)snapshotViewsAtTap:(NSArray<UIView *> *)viewsAtTap selectedView:(UIView *)view;

/// 当前在 3D 视图中选中的视图。
@property (nonatomic, nullable) UIView *selectedView;

@end

NS_ASSUME_NONNULL_END
