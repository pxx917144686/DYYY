#import "FLEXManager+ThreeFingerTap.h"
#import "FLEXManager.h"
#import "UIGestureRecognizer+Blocks.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// 用于持有手势识别器的静态变量，防止重复添加
static UILongPressGestureRecognizer *flex_threeFingerLongPressGesture = nil;

@implementation FLEXManager (ThreeFingerTap)

+ (void)load {
    // 确保在主线程执行，并且在应用启动和UI设置完毕后
    if ([NSThread isMainThread]) {
        [self flex_setupGesture];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self flex_setupGesture];
        });
    }
}

+ (void)flex_setupGesture {
    UIWindow *targetWindow = [self flex_findTargetWindow];

    if (!targetWindow) {
        // 如果没有找到窗口，稍后重试。这可能在 +load 执行过早时发生。
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self flex_setupGesture];
        });
        return;
    }

    // 检查手势是否已添加到此窗口，以防止重复
    for (UIGestureRecognizer *existingGesture in targetWindow.gestureRecognizers) {
        if (existingGesture == flex_threeFingerLongPressGesture) {
            // 确保手势在正确的视图上
            if (existingGesture.view == targetWindow) {
                 return; // 已添加
            } else {
                // 如果手势在错误的视图上，移除它
                [existingGesture.view removeGestureRecognizer:existingGesture];
                flex_threeFingerLongPressGesture = nil; // 将其置nil以便重新创建
            }
        }
    }
    
    // 如果我们有一个旧的手势在不同的窗口上，移除它。
    if (flex_threeFingerLongPressGesture && flex_threeFingerLongPressGesture.view != targetWindow) {
        [flex_threeFingerLongPressGesture.view removeGestureRecognizer:flex_threeFingerLongPressGesture];
        flex_threeFingerLongPressGesture = nil;
    }


    if (!flex_threeFingerLongPressGesture) {
        flex_threeFingerLongPressGesture = [UILongPressGestureRecognizer flex_action:^(UIGestureRecognizer *gesture) {
            if (gesture.state == UIGestureRecognizerStateBegan) {
                if ([FLEXManager sharedManager]) {
                    [[FLEXManager sharedManager] toggleExplorer];
                }
            }
        }];
        
        flex_threeFingerLongPressGesture.numberOfTouchesRequired = 3;
        // 可选：如果默认的0.5秒不合适，可以设置最小按压时长
        // flex_threeFingerLongPressGesture.minimumPressDuration = 0.8; // 例如0.8秒
    }

    // 确保手势未添加到其他视图
    if (flex_threeFingerLongPressGesture.view && flex_threeFingerLongPressGesture.view != targetWindow) {
        [flex_threeFingerLongPressGesture.view removeGestureRecognizer:flex_threeFingerLongPressGesture];
    }
    
    if (flex_threeFingerLongPressGesture.view != targetWindow) {
        [targetWindow addGestureRecognizer:flex_threeFingerLongPressGesture];
    }
}

+ (UIWindow *)flex_findTargetWindow {
    UIWindow *applicationWindow = nil;

    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive && [scene isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *windowScene = (UIWindowScene *)scene;
                for (UIWindow *window in windowScene.windows) {
                    // 优先选择一个非FLEXWindow的key window
                    if (window.isKeyWindow && ![NSStringFromClass(window.class) isEqualToString:@"FLEXWindow"]) {
                        applicationWindow = window;
                        break;
                    }
                }
                if (applicationWindow) break;

                // 备选：活动场景中的任何key window
                if (!applicationWindow) {
                    for (UIWindow *window in windowScene.windows) {
                        if (window.isKeyWindow) {
                            applicationWindow = window;
                            break;
                        }
                    }
                }
                if (applicationWindow) break;
                
                // 备选：活动场景中的第一个非FLEXWindow
                 if (!applicationWindow) {
                    for (UIWindow *window in windowScene.windows) {
                        if (![NSStringFromClass(window.class) isEqualToString:@"FLEXWindow"]) {
                            applicationWindow = window;
                            break;
                        }
                    }
                }
                if (applicationWindow) break;
            }
        }
    }

    // iOS < 13 或通过场景未找到合适窗口时的备选方案
    if (!applicationWindow) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        NSArray<UIWindow *> *windows = [UIApplication sharedApplication].windows;
        for (UIWindow *window in windows) {
            if (window.isKeyWindow && ![NSStringFromClass(window.class) isEqualToString:@"FLEXWindow"]) {
                applicationWindow = window;
                break;
            }
        }
        // 如果上面的尝试失败了，就获取当前的keyWindow（有可能是FLEXWindow）
        if (!applicationWindow) {
            applicationWindow = [UIApplication sharedApplication].keyWindow;
        }
        
        // 如果获取到的keyWindow是FLEXWindow，尝试寻找其他非FLEXWindow且可见的窗口
        if (applicationWindow && [NSStringFromClass(applicationWindow.class) isEqualToString:@"FLEXWindow"]) {
            UIWindow* fallbackWindow = nil;
            for (UIWindow *window in windows) {
                if (![NSStringFromClass(window.class) isEqualToString:@"FLEXWindow"] && !window.isHidden) {
                    fallbackWindow = window; // 找到一个可用的非FLEX窗口
                    if (window.isKeyWindow) { // 如果这个窗口恰好也是key window，优先使用
                        applicationWindow = window;
                        break;
                    }
                }
            }
            if (![NSStringFromClass(applicationWindow.class) isEqualToString:@"FLEXWindow"] || !fallbackWindow) {
                 // 如果applicationWindow仍然是FLEXWindow，或者没有找到fallbackWindow，则保持原样
            } else {
                applicationWindow = fallbackWindow; // 使用找到的非FLEX窗口
            }
        }
        #pragma clang diagnostic pop
    }
    
    return applicationWindow;
}

@end