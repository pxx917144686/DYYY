// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXAlert.h
//  FLEX
//
//  Created by Tanner Bennett on 8/20/19.
//  Copyright © 2020 FLEX Team. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class FLEXAlert, FLEXAlertAction;

typedef void (^FLEXAlertReveal)(void); // 警报显示回调类型 (未使用)
typedef void (^FLEXAlertBuilder)(FLEXAlert *make); // 警报构建器块类型
typedef FLEXAlert * _Nonnull (^FLEXAlertStringProperty)(NSString * _Nullable); // 设置字符串属性的块类型
typedef FLEXAlert * _Nonnull (^FLEXAlertStringArg)(NSString * _Nullable); // 带字符串参数的块类型
typedef FLEXAlert * _Nonnull (^FLEXAlertTextField)(void(^configurationHandler)(UITextField *textField)); // 配置文本框的块类型
typedef FLEXAlertAction * _Nonnull (^FLEXAlertAddAction)(NSString *title); // 添加操作的块类型
typedef FLEXAlertAction * _Nonnull (^FLEXAlertActionStringProperty)(NSString * _Nullable); // 设置操作字符串属性的块类型
typedef FLEXAlertAction * _Nonnull (^FLEXAlertActionProperty)(void); // 设置操作属性的块类型
typedef FLEXAlertAction * _Nonnull (^FLEXAlertActionBOOLProperty)(BOOL); // 设置操作布尔属性的块类型
typedef FLEXAlertAction * _Nonnull (^FLEXAlertActionHandler)(void(^handler)(NSArray<NSString *> *strings)); // 设置操作处理程序的块类型

// 用于构建和显示 UIAlertController 的便捷类
@interface FLEXAlert : NSObject

/// 显示一个带有一个“确定”按钮的简单警报
+ (void)showAlert:(NSString * _Nullable)title message:(NSString * _Nullable)message from:(UIViewController *)viewController;

/// 显示一个仅包含标题、无按钮、持续半秒的简单警报
+ (void)showQuickAlert:(NSString *)title from:(UIViewController *)viewController;

/// 构建并显示一个警报
+ (void)makeAlert:(FLEXAlertBuilder)block showFrom:(UIViewController *)viewController;
/// 构建并显示一个动作表样式的警报
+ (void)makeSheet:(FLEXAlertBuilder)block
         showFrom:(UIViewController *)viewController
           source:(id)viewOrBarItem; // source 可以是 UIView 或 UIBarButtonItem

/// 构建一个警报
+ (UIAlertController *)makeAlert:(FLEXAlertBuilder)block;
/// 构建一个动作表样式的警报
+ (UIAlertController *)makeSheet:(FLEXAlertBuilder)block;

/// 设置警报的标题。
///
/// 连续调用以将字符串附加到标题。
@property (nonatomic, readonly) FLEXAlertStringProperty title;
/// 设置警报的消息。
///
/// 连续调用以将字符串附加到消息。
@property (nonatomic, readonly) FLEXAlertStringProperty message;
/// 添加一个具有给定标题、默认样式且无操作的按钮。
@property (nonatomic, readonly) FLEXAlertAddAction button;
/// 添加一个具有给定（可选）占位符文本的文本字段。
@property (nonatomic, readonly) FLEXAlertStringArg textField;
/// 添加并配置给定的文本字段。
///
/// 如果您需要做的不仅仅是设置占位符，例如
/// 提供委托、使其成为安全输入或更改其他属性，请使用此方法。
@property (nonatomic, readonly) FLEXAlertTextField configuredTextField;

@end

// 用于构建 UIAlertAction 的便捷类
@interface FLEXAlertAction : NSObject

/// 设置操作的标题。
///
/// 连续调用以将字符串附加到标题。
@property (nonatomic, readonly) FLEXAlertActionStringProperty title;
/// 使操作具有破坏性。它以红色文本显示。
@property (nonatomic, readonly) FLEXAlertActionProperty destructiveStyle;
/// 使操作具有取消样式。它有时以较粗的字体显示。
@property (nonatomic, readonly) FLEXAlertActionProperty cancelStyle;
/// 使操作成为首选操作。它以较粗的字体显示。
/// 第一个被设置为首选的操作将用作首选操作。
@property (nonatomic, readonly) FLEXAlertActionProperty preferred;
/// 启用或禁用操作。默认启用。
@property (nonatomic, readonly) FLEXAlertActionBOOLProperty enabled;
/// 为按钮提供一个操作。该操作接受一个文本字段字符串数组。
@property (nonatomic, readonly) FLEXAlertActionHandler handler;
/// 访问底层的 UIAlertAction，如果您需要在
/// 包含的警报显示时更改它。例如，您可能希望根据
/// 警报中某些文本字段的输入来启用或禁用按钮。
/// 每个实例不要调用此方法超过一次。
@property (nonatomic, readonly) UIAlertAction *action;

@end

NS_ASSUME_NONNULL_END
