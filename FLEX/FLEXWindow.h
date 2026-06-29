//
//  FLEXWindow.h
//  Flipboard
//
//  由 Ryan Olson 创建于 4/13/14.
//  版权所有 (c) 2020 FLEX Team. 保留所有权利。
//

#import <UIKit/UIKit.h>

@protocol FLEXWindowEventDelegate <NSObject>

- (BOOL)shouldHandleTouchAtPoint:(CGPoint)pointInWindow;
- (BOOL)canBecomeKeyWindow;

@end

#pragma mark -
@interface FLEXWindow : UIWindow

@property (nonatomic, weak) id <FLEXWindowEventDelegate> eventDelegate;

/// 跟踪此窗口以便在关闭模态后恢复键窗口。
/// 我们需要在模态展示后成为键窗口，以便正确捕获输入。
/// 如果我们只是显示工具栏，我们希望应用程序的主窗口保持为键窗口，
/// 这样我们就不会干扰输入、状态栏等。
@property (nonatomic, readonly) UIWindow *previousKeyWindow;

@end
