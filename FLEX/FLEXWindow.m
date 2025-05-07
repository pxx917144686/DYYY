// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXWindow.m
//  Flipboard
//
//  由 Ryan Olson 创建于 4/13/14.
//  版权所有 (c) 2020 FLEX Team。保留所有权利。
//

#import "FLEXWindow.h"
#import "FLEXUtility.h"
#import <objc/runtime.h>

@implementation FLEXWindow

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // 有些应用程序的窗口位于 UIWindowLevelStatusBar + n。
        // 如果我们将窗口级别设置得太高，就会挡住 UIAlertView。
        // 需要在保持在应用程序窗口之上和保持在警报之下之间取得平衡。
        self.windowLevel = UIWindowLevelAlert - 1;
    }
    return self;
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    return [self.eventDelegate shouldHandleTouchAtPoint:point];
}

- (BOOL)shouldAffectStatusBarAppearance {
    return [self isKeyWindow];
}

- (BOOL)canBecomeKeyWindow {
    return [self.eventDelegate canBecomeKeyWindow];
}

- (void)makeKeyWindow {
    _previousKeyWindow = FLEXUtility.appKeyWindow;
    [super makeKeyWindow];
}

- (void)resignKeyWindow {
    [super resignKeyWindow];
    _previousKeyWindow = nil;
}

+ (void)initialize {
    // 这会在运行时添加一个方法（超类覆盖），从而为我们提供所需的状态栏行为。
    // FLEX 窗口旨在成为一个通常不影响其下方应用程序的覆盖层。
    // 大多数情况下，我们希望应用程序的主窗口控制状态栏行为。
    // 由于它是私有 API，因此在运行时使用混淆的选择器完成。但是无论如何您都不应该将其发布到 App Store...
    NSString *canAffectSelectorString = [@[@"_can", @"Affect", @"Status", @"Bar", @"Appearance"] componentsJoinedByString:@""];
    SEL canAffectSelector = NSSelectorFromString(canAffectSelectorString);
    Method shouldAffectMethod = class_getInstanceMethod(self, @selector(shouldAffectStatusBarAppearance));
    IMP canAffectImplementation = method_getImplementation(shouldAffectMethod);
    class_addMethod(self, canAffectSelector, canAffectImplementation, method_getTypeEncoding(shouldAffectMethod));

    // 还有一个...
    NSString *canBecomeKeySelectorString = [NSString stringWithFormat:@"_%@", NSStringFromSelector(@selector(canBecomeKeyWindow))];
    SEL canBecomeKeySelector = NSSelectorFromString(canBecomeKeySelectorString);
    Method canBecomeKeyMethod = class_getInstanceMethod(self, @selector(canBecomeKeyWindow));
    IMP canBecomeKeyImplementation = method_getImplementation(canBecomeKeyMethod);
    class_addMethod(self, canBecomeKeySelector, canBecomeKeyImplementation, method_getTypeEncoding(canBecomeKeyMethod));
}

@end
