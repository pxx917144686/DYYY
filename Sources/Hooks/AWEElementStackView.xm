#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "DYYYManager.h"
#import "DYYYUtils.h"
#import "AwemeHeaders.h"

// tabHeight 变量声明
static CGFloat tabHeight = 0;

// 获取标签栏高度的函数
static CGFloat getTabBarHeight(void) {
    static CGFloat cachedHeight = 0;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        UIWindow *keyWindow = nil;
        if (@available(iOS 13.0, *)) {
            NSSet *connectedScenes = [UIApplication sharedApplication].connectedScenes;
            for (UIScene *scene in connectedScenes) {
                if ([scene isKindOfClass:[UIWindowScene class]]) {
                    UIWindowScene *windowScene = (UIWindowScene *)scene;
                    for (UIWindow *window in windowScene.windows) {
                        if (window.isKeyWindow) {
                            keyWindow = window;
                            break;
                        }
                    }
                    if (keyWindow) break;
                }
            }
        } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            keyWindow = [UIApplication sharedApplication].keyWindow;
#pragma clang diagnostic pop
        }
        
        if (@available(iOS 11.0, *)) {
            cachedHeight = keyWindow.safeAreaInsets.bottom;
        }
        if (cachedHeight == 0) {
            cachedHeight = 49.0; // 默认标签栏高度
        }
        
        tabHeight = cachedHeight;
    });
    return cachedHeight;
}

// 初始化函数
static void initializeTabHeight(void) __attribute__((constructor));
static void initializeTabHeight(void) {
    tabHeight = getTabBarHeight();
}

// 使用 C 函数处理递归逻辑
static BOOL containsSubviewOfClass(UIView *view, Class targetClass) {
    if ([view isKindOfClass:targetClass]) {
        return YES;
    }
    
    for (UIView *subview in view.subviews) {
        if (containsSubviewOfClass(subview, targetClass)) {
            return YES;
        }
    }
    
    return NO;
}

%hook AWEElementStackView
static CGFloat stream_frame_y = 0;
static CGFloat right_tx = 0;
static CGFloat left_tx = 0;
static CGFloat currentScale = 1.0;

%new
- (UIViewController *)firstAvailableUIViewController {
    UIResponder *responder = [self nextResponder];
    while (responder != nil) {
        if ([responder isKindOfClass:[UIViewController class]]) {
            return (UIViewController *)responder;
        }
        responder = [responder nextResponder];
    }
    return nil;
}

- (void)layoutSubviews {
    %orig;
    UIViewController *vc = [self firstAvailableUIViewController];
    if ([vc isKindOfClass:%c(AWECommentInputViewController)]) {
        NSString *transparentValue = [[NSUserDefaults standardUserDefaults] stringForKey:@"DYYYGlobalTransparency"];
        if (transparentValue.length > 0) {
            CGFloat alphaValue = transparentValue.floatValue;
            if (alphaValue >= 0.0 && alphaValue <= 1.0) {
                self.alpha = alphaValue;
            }
        }
    }
    if ([vc isKindOfClass:%c(AWELiveNewPreStreamViewController)]) {
        NSString *transparentValue = [[NSUserDefaults standardUserDefaults] stringForKey:@"DYYYGlobalTransparency"];
        if (transparentValue.length > 0) {
            CGFloat alphaValue = transparentValue.floatValue;
            if (alphaValue >= 0.0 && alphaValue <= 1.0) {
                self.alpha = alphaValue;
            }
        }
    }
    // 处理视频流直播间文案缩放
    UIResponder *nextResponder = [self nextResponder];
    if ([nextResponder isKindOfClass:[UIView class]]) {
        UIView *parentView = (UIView *)nextResponder;
        UIViewController *viewController = [parentView firstAvailableUIViewController];
        if ([viewController isKindOfClass:%c(AWELiveNewPreStreamViewController)]) {
            NSString *vcScaleValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYNicknameScale"];
            if (vcScaleValue.length > 0) {
                CGFloat scale = [vcScaleValue floatValue];
                self.transform = CGAffineTransformIdentity;
                if (scale > 0 && scale != 1.0) {
                    NSArray *subviews = [self.subviews copy];
                    CGFloat ty = 0;
                    for (UIView *view in subviews) {
                        CGFloat viewHeight = view.frame.size.height;
                        CGFloat contribution = (viewHeight - viewHeight * scale) / 2;
                        ty += contribution;
                    }
                    CGFloat frameWidth = self.frame.size.width;
                    CGFloat tx = (frameWidth - frameWidth * scale) / 2 - frameWidth * (1 - scale);
                    CGAffineTransform newTransform = CGAffineTransformMakeScale(scale, scale);
                    newTransform = CGAffineTransformTranslate(newTransform, tx / scale, ty / scale);
                    self.transform = newTransform;
                }
            }
        }
    }
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnableFullScreen"]) {
        UIResponder *nextResponder = [self nextResponder];
        if ([nextResponder isKindOfClass:[UIView class]]) {
            UIView *parentView = (UIView *)nextResponder;
            UIViewController *viewController = [parentView firstAvailableUIViewController];
            if ([viewController isKindOfClass:%c(AWELiveNewPreStreamViewController)]) {
                CGRect frame = self.frame;
                frame.origin.y -= tabHeight;
                stream_frame_y = frame.origin.y;
                self.frame = frame;
            }
        }
    }

    UIViewController *viewController = [self firstAvailableUIViewController];
    if ([viewController isKindOfClass:%c(AWEPlayInteractionViewController)]) {
        // 先判断是否有accessibilityLabel
        BOOL isRightElement = NO;
        BOOL isLeftElement = NO;

        if (self.accessibilityLabel) {
            if ([self.accessibilityLabel isEqualToString:@"right"]) {
                isRightElement = YES;
            } else if ([self.accessibilityLabel isEqualToString:@"left"]) {
                isLeftElement = YES;
            }
        } else {
            for (UIView *subview in self.subviews) {
                // 使用 C 函数替代 %new 方法
                if (containsSubviewOfClass(subview, %c(AWEPlayInteractionUserAvatarView))) {
                    isRightElement = YES;
                    break;
                }
                if (containsSubviewOfClass(subview, %c(AWEFeedAnchorContainerView))) {
                    isLeftElement = YES;
                    break;
                }
            }
        }

        // 右侧元素的处理逻辑
        if (isRightElement) {
            NSString *scaleValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYElementScale"];
            self.transform = CGAffineTransformIdentity;
            if (scaleValue.length > 0) {
                CGFloat scale = [scaleValue floatValue];
                if (currentScale != scale) {
                    currentScale = scale;
                }
                if (scale > 0 && scale != 1.0) {
                    CGFloat ty = 0;
                    for (UIView *view in self.subviews) {
                        CGFloat viewHeight = view.frame.size.height;
                        CGFloat contribution = (viewHeight - viewHeight * scale) / 2;
                        ty += contribution;
                    }
                    CGFloat frameWidth = self.frame.size.width;
                    right_tx = (frameWidth - frameWidth * scale) / 2;
                    self.transform = CGAffineTransformMake(scale, 0, 0, scale, right_tx, ty);
                } else {
                    self.transform = CGAffineTransformIdentity;
                }
            }
        }
        // 左侧元素的处理逻辑
        else if (isLeftElement) {
            NSString *scaleValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYNicknameScale"];
            if (scaleValue.length > 0) {
                CGFloat scale = [scaleValue floatValue];
                self.transform = CGAffineTransformIdentity;
                if (scale > 0 && scale != 1.0) {
                    NSArray *subviews = [self.subviews copy];
                    CGFloat ty = 0;
                    for (UIView *view in subviews) {
                        CGFloat viewHeight = view.frame.size.height;
                        CGFloat contribution = (viewHeight - viewHeight * scale) / 2;
                        ty += contribution;
                    }
                    CGFloat frameWidth = self.frame.size.width;
                    CGFloat left_tx = (frameWidth - frameWidth * scale) / 2 - frameWidth * (1 - scale);
                    CGAffineTransform newTransform = CGAffineTransformMakeScale(scale, scale);
                    newTransform = CGAffineTransformTranslate(newTransform, left_tx / scale, ty / scale);
                    self.transform = newTransform;
                }
            }
        }
    }
}

- (NSArray<__kindof UIView *> *)arrangedSubviews {
    UIViewController *viewController = [self firstAvailableUIViewController];
    if ([viewController isKindOfClass:%c(AWEPlayInteractionViewController)]) {
        // 先判断是否有accessibilityLabel
        BOOL isLeftElement = NO;

        if (self.accessibilityLabel) {
            if ([self.accessibilityLabel isEqualToString:@"left"]) {
                isLeftElement = YES;
            }
        } else {
            for (UIView *subview in self.subviews) {
                // 使用 C 函数替代 %new 方法
                if (containsSubviewOfClass(subview, %c(AWEFeedAnchorContainerView))) {
                    isLeftElement = YES;
                    break;
                }
            }
        }

        if (isLeftElement) {
            NSString *scaleValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYNicknameScale"];
            if (scaleValue.length > 0) {
                CGFloat scale = [scaleValue floatValue];
                self.transform = CGAffineTransformIdentity;
                if (scale > 0 && scale != 1.0) {
                    NSArray *subviews = [self.subviews copy];
                    CGFloat ty = 0;
                    for (UIView *view in subviews) {
                        CGFloat viewHeight = view.frame.size.height;
                        CGFloat contribution = (viewHeight - viewHeight * scale) / 2;
                        ty += contribution;
                    }
                    CGFloat frameWidth = self.frame.size.width;
                    CGFloat left_tx = (frameWidth - frameWidth * scale) / 2 - frameWidth * (1 - scale);
                    CGAffineTransform newTransform = CGAffineTransformMakeScale(scale, scale);
                    newTransform = CGAffineTransformTranslate(newTransform, left_tx / scale, ty / scale);
                    self.transform = newTransform;
                }
            }
        }
    }

    NSArray *originalSubviews = %orig;
    return originalSubviews;
}

%end