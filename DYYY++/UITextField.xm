#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "DYYYManager.h"
#import "DYYYUtils.h"
#import "AwemeHeaders.h"

static BOOL isDarkMode() {
	if (@available(iOS 13.0, *)) {
		return UITraitCollection.currentTraitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
	}
	return NO;
}


// ===== 键盘外观适配 =====
%hook UITextField

- (void)willMoveToWindow:(UIWindow *)newWindow {
	%orig;
	if (newWindow) {
		// 根据当前是否为深色模式来设置键盘样式
		BOOL darkModeEnabled = isDarkMode();
		self.keyboardAppearance = darkModeEnabled ? UIKeyboardAppearanceDark : UIKeyboardAppearanceLight;
	}
}

- (BOOL)becomeFirstResponder {
	// 当输入框获取焦点时设置键盘样式
	BOOL darkModeEnabled = isDarkMode();
	self.keyboardAppearance = darkModeEnabled ? UIKeyboardAppearanceDark : UIKeyboardAppearanceLight;
	return %orig;
}

%end