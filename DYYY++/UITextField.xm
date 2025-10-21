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



// 底栏高度
static CGFloat tabHeight = 0;

static void DYYYAddCustomViewToParent(UIView *parentView, float transparency) {
	if (!parentView)
		return;

	parentView.backgroundColor = [UIColor clearColor];

	UIVisualEffectView *existingBlurView = nil;
	for (UIView *subview in parentView.subviews) {
		if ([subview isKindOfClass:[UIVisualEffectView class]] && subview.tag == 999) {
			existingBlurView = (UIVisualEffectView *)subview;
			break;
		}
	}

	BOOL darkModeEnabled = isDarkMode();
	UIBlurEffectStyle blurStyle = darkModeEnabled ? UIBlurEffectStyleDark : UIBlurEffectStyleLight;

	if (transparency <= 0 || transparency > 1) {
		transparency = 0.5;
	}

	if (!existingBlurView) {
		UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:blurStyle];
		UIVisualEffectView *blurEffectView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
		blurEffectView.frame = parentView.bounds;
		blurEffectView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		blurEffectView.alpha = transparency;
		blurEffectView.tag = 999;

		UIView *overlayView = [[UIView alloc] initWithFrame:parentView.bounds];
		CGFloat alpha = darkModeEnabled ? 0.2 : 0.1;
		overlayView.backgroundColor = [UIColor colorWithWhite:(darkModeEnabled ? 0 : 1) alpha:alpha];
		overlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		[blurEffectView.contentView addSubview:overlayView];

		[parentView insertSubview:blurEffectView atIndex:0];
	} else {
		UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:blurStyle];
		[existingBlurView setEffect:blurEffect];
		existingBlurView.alpha = transparency;

		for (UIView *subview in existingBlurView.contentView.subviews) {
			CGFloat alpha = darkModeEnabled ? 0.2 : 0.1;
			subview.backgroundColor = [UIColor colorWithWhite:(darkModeEnabled ? 0 : 1) alpha:alpha];
		}

		[parentView insertSubview:existingBlurView atIndex:0];
	}
}