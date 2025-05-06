// filepath: FLEXWindow.h
// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXWindow.h
//  Flipboard
//
//  由 Ryan Olson 创建于 4/13/14.
//  版权所有 (c) 2020 FLEX Team。保留所有权利。
//

#import <UIKit/UIKit.h>

@protocol FLEXWindowEventDelegate <NSObject>

- (BOOL)shouldHandleTouchAtPoint:(CGPoint)pointInWindow;
- (BOOL)canBecomeKeyWindow;

@end

#pragma mark -
@interface FLEXWindow : UIWindow

@property (nonatomic, weak) id <FLEXWindowEventDelegate> eventDelegate;

/// 进行跟踪，以便在关闭模态窗口后恢复主窗口。
/// 我们需要在模态演示后成为主窗口，以便正确捕获输入。
/// 如果我们只是显示工具栏，我们希望主应用程序的窗口保持主窗口状态，
/// 以免干扰输入、状态栏等。
@property (nonatomic, readonly) UIWindow *previousKeyWindow;

@end
