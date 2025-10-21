#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "DYYYManager.h"
#import "DYYYUtils.h"
#import "AwemeHeaders.h"


/**
 * AFDPrivacyHalfScreenViewController
 * 用于为隐私半屏视图控制器添加暗黑模式支持
 */

/**
 * 更新界面元素以适应暗黑模式
 * 
 * 该方法根据当前系统的暗黑模式状态，动态调整视图控制器中各UI元素的颜色：
 * - 内容视图背景色：暗黑模式下为深灰色，正常模式下为白色
 * - 标题文本颜色：暗黑模式下为白色，正常模式下为黑色
 * - 内容文本颜色：暗黑模式下为浅灰色，正常模式下为深灰色
 * - 左侧取消按钮：暗黑模式下使用深色背景和浅色文字，正常模式下使用浅色背景和深色文字
 */

/**
 * 重写viewDidLoad方法
 * 
 * 在视图加载完成后调用原始实现，然后更新UI以适应当前的暗黑模式状态
 */

/**
 * 重写viewWillAppear:方法
 * 
 * 在视图即将显示时调用原始实现，然后更新UI以适应当前的暗黑模式状态，
 * 确保每次视图显示时都能正确应用暗黑模式设置
 */

/**
 * 重写配置方法
 * 
 * 在视图控制器完成所有元素配置后，调用更新暗黑模式外观的方法，
 * 确保所有新配置的UI元素都能正确应用暗黑模式设置
 * 
 * @param imageView 图标图像视图
 * @param lockImage 锁定图标
 * @param defaultLockState 默认锁定状态
 * @param titleText 标题文本
 * @param contentText 内容文本
 * @param leftButtonText 左侧按钮文本
 * @param rightButtonText 右侧按钮文本
 * @param rightBtnBlock 右侧按钮点击回调
 * @param leftBtnBlock 左侧按钮点击回调
 */
%hook AFDPrivacyHalfScreenViewController

%new
- (void)updateDarkModeAppearance {
	BOOL isDarkMode = [DYYYManager isDarkMode];

	UIView *contentView = self.view.subviews.count > 1 ? self.view.subviews[1] : nil;
	if (contentView) {
		if (isDarkMode) {
			contentView.backgroundColor = [UIColor colorWithRed:0.13 green:0.13 blue:0.13 alpha:1.0];
		} else {
			contentView.backgroundColor = [UIColor whiteColor];
		}
	}

	// 修改标题文本颜色
	if (self.titleLabel) {
		if (isDarkMode) {
			self.titleLabel.textColor = [UIColor whiteColor];
		} else {
			self.titleLabel.textColor = [UIColor blackColor];
		}
	}

	// 修改内容文本颜色
	if (self.contentLabel) {
		if (isDarkMode) {
			self.contentLabel.textColor = [UIColor lightGrayColor];
		} else {
			self.contentLabel.textColor = [UIColor darkGrayColor];
		}
	}

	// 修改左侧按钮颜色和文字颜色
	if (self.leftCancelButton) {
		if (isDarkMode) {
			[self.leftCancelButton setBackgroundColor:[UIColor colorWithRed:0.25 green:0.25 blue:0.25 alpha:1.0]]; // 暗色模式按钮背景色
			[self.leftCancelButton setTitleColor:[UIColor lightGrayColor] forState:UIControlStateNormal];	       // 暗色模式文字颜色
		} else {
			[self.leftCancelButton setBackgroundColor:[UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:1.0]]; // 默认按钮背景色
			[self.leftCancelButton setTitleColor:[UIColor darkTextColor] forState:UIControlStateNormal];	    // 默认文字颜色
		}
	}
}

- (void)viewDidLoad {
	%orig;
	[self updateDarkModeAppearance];
}

- (void)viewWillAppear:(BOOL)animated {
	%orig;
	[self updateDarkModeAppearance];
}

- (void)configWithImageView:(UIImageView *)imageView
		  lockImage:(UIImage *)lockImage
	   defaultLockState:(BOOL)defaultLockState
	     titleLabelText:(NSString *)titleText
	   contentLabelText:(NSString *)contentText
       leftCancelButtonText:(NSString *)leftButtonText
     rightConfirmButtonText:(NSString *)rightButtonText
       rightBtnClickedBlock:(void (^)(void))rightBtnBlock
     leftButtonClickedBlock:(void (^)(void))leftBtnBlock {

	%orig;
	[self updateDarkModeAppearance];
}

%end