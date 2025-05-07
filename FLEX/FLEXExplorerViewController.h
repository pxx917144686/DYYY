//
//  FLEXExplorerViewController.h
//  Flipboard
//
//  创建者：Ryan Olson，日期：4/4/14.
//  版权所有 (c) 2020 FLEX Team。保留所有权利。
//

// 遇到问题联系中文翻译作者：pxx917144686

#import "FLEXExplorerToolbar.h"

@class FLEXWindow;
@protocol FLEXExplorerViewControllerDelegate;

/// 管理 FLEX 工具栏的视图控制器。
@interface FLEXExplorerViewController : UIViewController

@property (nonatomic, weak) id <FLEXExplorerViewControllerDelegate> delegate;
@property (nonatomic, readonly) BOOL wantsWindowToBecomeKey;

@property (nonatomic, readonly) FLEXExplorerToolbar *explorerToolbar;

- (BOOL)shouldReceiveTouchAtWindowPoint:(CGPoint)pointInWindowCoordinates;

/// @brief 用于显示（或关闭）模态视图控制器（“工具”），
/// 通常通过按下工具栏中的按钮触发。
///
/// 如果已显示某个工具，此方法仅将其关闭并调用完成回调。
/// 如果未显示任何工具，则显示 @code future() @endcode 并调用完成回调。
- (void)toggleToolWithViewControllerProvider:(UINavigationController *(^)(void))future
                                  completion:(void (^)(void))completion;

/// @brief 用于显示（或关闭）模态视图控制器（“工具”），
/// 通常通过按下工具栏中的按钮触发。
///
/// 如果已显示某个工具，此方法会将其关闭并显示给定的工具。
/// 一旦工具显示完毕，便会调用完成回调。
- (void)presentTool:(UINavigationController *(^)(void))future
         completion:(void (^)(void))completion;

// 键盘快捷键助手

- (void)toggleSelectTool;
- (void)toggleMoveTool;
- (void)toggleViewsTool;
- (void)toggleMenuTool;

/// @return 如果浏览器使用按键执行操作，则返回 YES，否则返回 NO
- (BOOL)handleDownArrowKeyPressed;
/// @return 如果浏览器使用按键执行操作，则返回 YES，否则返回 NO
- (BOOL)handleUpArrowKeyPressed;
/// @return 如果浏览器使用按键执行操作，则返回 YES，否则返回 NO
- (BOOL)handleRightArrowKeyPressed;
/// @return 如果浏览器使用按键执行操作，则返回 YES，否则返回 NO
- (BOOL)handleLeftArrowKeyPressed;

@end

#pragma mark -
@protocol FLEXExplorerViewControllerDelegate <NSObject>
- (void)explorerViewControllerDidFinish:(FLEXExplorerViewController *)explorerViewController;
@end
