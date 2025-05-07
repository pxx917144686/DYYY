// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXVariableEditorViewController.h
//  Flipboard
//
//  由 Ryan Olson 创建于 5/16/14.
//  版权所有 (c) 2020 FLEX Team。保留所有权利。
//

#import <UIKit/UIKit.h>

@class FLEXFieldEditorView;
@class FLEXArgumentInputView;

NS_ASSUME_NONNULL_BEGIN

/// 用于编辑或配置一个或多个变量的抽象屏幕。
/// “Target”是编辑操作的目标，“data”是
/// 您希望在执行操作时改变或传递给目标的数据。
/// 操作可以是调用方法、设置实例变量等。
@interface FLEXVariableEditorViewController : UIViewController {
    @protected
    id _target;
    _Nullable id _data;
    void (^_Nullable _commitHandler)(void);
}

/// @param target 操作的目标
/// @param data 与操作关联的数据
/// @param onCommit 数据更改时要执行的操作
+ (instancetype)target:(id)target data:(nullable id)data commitHandler:(void(^_Nullable)(void))onCommit;
/// @param target 操作的目标
/// @param data 与操作关联的数据
/// @param onCommit 数据更改时要执行的操作
- (id)initWithTarget:(id)target data:(nullable id)data commitHandler:(void(^_Nullable)(void))onCommit;

@property (nonatomic, readonly) id target;

/// 便捷访问器，因为许多子类仅使用一个输入视图
@property (nonatomic, readonly, nullable) FLEXArgumentInputView *firstInputView;

@property (nonatomic, readonly) FLEXFieldEditorView *fieldEditorView;
/// 子类可以通过按钮的 \c title 属性更改按钮标题
@property (nonatomic, readonly) UIBarButtonItem *actionButton;

/// 子类应重写以提供“设置”功能。
/// 提交处理程序（如果存在）在此处调用。
- (void)actionButtonPressed:(nullable id)sender;

/// 为给定对象推送一个浏览器视图控制器
/// 或弹出当前视图控制器。
- (void)exploreObjectOrPopViewController:(nullable id)objectOrNil;

@end

NS_ASSUME_NONNULL_END
