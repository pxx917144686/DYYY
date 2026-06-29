#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface DYYYFilterSettingsView : UIView

// 确认按钮点击时的回调，参数为选择的文本
@property (nonatomic, copy, nullable) void (^onConfirm)(NSString *selectedText);

// 取消按钮点击时的回调
@property (nonatomic, copy, nullable) void (^onCancel)(void);

// 过滤关键词按钮点击时的回调
@property (nonatomic, copy, nullable) void (^onKeywordFilterTap)(void);

// 初始化方法，接受标题和待分词的文本
- (instancetype)initWithTitle:(NSString *)title text:(NSString *)text;

// 显示对话框
- (void)show;

// 关闭对话框
- (void)dismiss;

/**
 * 初始化方法
 * @param title 标题
 * @param text 初始文本内容
 */
- (instancetype)initWithTitle:(NSString *)title text:(NSString *)text;

/**
 * 显示设置视图
 * @param confirmBlock 确认回调，参数为用户选择/输入的文本
 * @param cancelBlock 取消回调
 */
- (void)showWithConfirmBlock:(void (^)(NSString *selectedText))confirmBlock cancelBlock:(void (^)(void))cancelBlock;

@end

NS_ASSUME_NONNULL_END