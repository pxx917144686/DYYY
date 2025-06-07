#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// iOS版本检查宏
#define FLEX_AT_LEAST_IOS11 (@available(iOS 11.0, *))
#define FLEX_AT_LEAST_IOS13 (@available(iOS 13.0, *))
#define FLEX_AT_LEAST_IOS14 (@available(iOS 14.0, *))

// 系统颜色兼容性宏
#define FLEXSystemBackgroundColor \
    (FLEX_AT_LEAST_IOS13 ? [UIColor systemBackgroundColor] : [UIColor whiteColor])

#define FLEXSystemBlueColor \
    (FLEX_AT_LEAST_IOS13 ? [UIColor systemBlueColor] : [UIColor colorWithRed:0.0 green:0.478 blue:1.0 alpha:1.0])

#define FLEXSystemRedColor \
    (FLEX_AT_LEAST_IOS13 ? [UIColor systemRedColor] : [UIColor redColor])

#define FLEXSystemGreenColor \
    (FLEX_AT_LEAST_IOS13 ? [UIColor systemGreenColor] : [UIColor colorWithRed:0.0 green:0.8 blue:0.0 alpha:1.0])

#define FLEXSystemOrangeColor \
    (FLEX_AT_LEAST_IOS13 ? [UIColor systemOrangeColor] : [UIColor orangeColor])

#define FLEXSystemGrayColor \
    (FLEX_AT_LEAST_IOS13 ? [UIColor systemGrayColor] : [UIColor colorWithWhite:0.6 alpha:1.0])

#define FLEXSystemYellowColor \
    (FLEX_AT_LEAST_IOS13 ? [UIColor systemYellowColor] : [UIColor yellowColor])

#define FLEXSystemPurpleColor \
    (FLEX_AT_LEAST_IOS13 ? [UIColor systemPurpleColor] : [UIColor purpleColor])

#define FLEXSystemPinkColor \
    (FLEX_AT_LEAST_IOS13 ? [UIColor systemPinkColor] : [UIColor colorWithRed:1.0 green:0.176 blue:0.333 alpha:1.0])

#define FLEXSystemTealColor \
    (FLEX_AT_LEAST_IOS13 ? [UIColor systemTealColor] : [UIColor colorWithRed:0.353 green:0.784 blue:0.98 alpha:1.0])

#define FLEXSystemIndigoColor \
    (FLEX_AT_LEAST_IOS13 ? [UIColor systemIndigoColor] : [UIColor colorWithRed:0.345 green:0.337 blue:0.839 alpha:1.0])

// 文本颜色兼容性宏
#define FLEXLabelColor \
    (FLEX_AT_LEAST_IOS13 ? [UIColor labelColor] : [UIColor blackColor])

#define FLEXSecondaryLabelColor \
    (FLEX_AT_LEAST_IOS13 ? [UIColor secondaryLabelColor] : [UIColor colorWithWhite:0.6 alpha:1.0])

#define FLEXTertiaryLabelColor \
    (FLEX_AT_LEAST_IOS13 ? [UIColor tertiaryLabelColor] : [UIColor colorWithWhite:0.7 alpha:1.0])

#define FLEXQuaternaryLabelColor \
    (FLEX_AT_LEAST_IOS13 ? [UIColor quaternaryLabelColor] : [UIColor colorWithWhite:0.8 alpha:1.0])

// 背景颜色兼容性宏
#define FLEXSecondarySystemBackgroundColor \
    (FLEX_AT_LEAST_IOS13 ? [UIColor secondarySystemBackgroundColor] : [UIColor colorWithWhite:0.95 alpha:1.0])

#define FLEXTertiarySystemBackgroundColor \
    (FLEX_AT_LEAST_IOS13 ? [UIColor tertiarySystemBackgroundColor] : [UIColor colorWithWhite:0.9 alpha:1.0])

#define FLEXSystemGroupedBackgroundColor \
    (FLEX_AT_LEAST_IOS13 ? [UIColor systemGroupedBackgroundColor] : [UIColor colorWithWhite:0.94 alpha:1.0])

#define FLEXSecondarySystemGroupedBackgroundColor \
    (FLEX_AT_LEAST_IOS13 ? [UIColor secondarySystemGroupedBackgroundColor] : [UIColor whiteColor])

// 分隔线颜色兼容性宏
#define FLEXSeparatorColor \
    (FLEX_AT_LEAST_IOS13 ? [UIColor separatorColor] : [UIColor colorWithWhite:0.8 alpha:1.0])

#define FLEXOpaqueSeparatorColor \
    (FLEX_AT_LEAST_IOS13 ? [UIColor opaqueSeparatorColor] : [UIColor colorWithWhite:0.7 alpha:1.0])

// 安全区域兼容性函数
static inline NSLayoutYAxisAnchor *FLEXSafeAreaTopAnchor(UIViewController *viewController) {
    if (FLEX_AT_LEAST_IOS11) {
        return viewController.view.safeAreaLayoutGuide.topAnchor;
    } else {
        return viewController.topLayoutGuide.bottomAnchor;
    }
}

static inline NSLayoutYAxisAnchor *FLEXSafeAreaBottomAnchor(UIViewController *viewController) {
    if (FLEX_AT_LEAST_IOS11) {
        return viewController.view.safeAreaLayoutGuide.bottomAnchor;
    } else {
        return viewController.bottomLayoutGuide.topAnchor;
    }
}

static inline NSLayoutXAxisAnchor *FLEXSafeAreaLeadingAnchor(UIViewController *viewController) {
    if (FLEX_AT_LEAST_IOS11) {
        return viewController.view.safeAreaLayoutGuide.leadingAnchor;
    } else {
        return viewController.view.leadingAnchor;
    }
}

static inline NSLayoutXAxisAnchor *FLEXSafeAreaTrailingAnchor(UIViewController *viewController) {
    if (FLEX_AT_LEAST_IOS11) {
        return viewController.view.safeAreaLayoutGuide.trailingAnchor;
    } else {
        return viewController.view.trailingAnchor;
    }
}

// 字体兼容性宏
#define FLEXSystemFontOfSize(size) [UIFont systemFontOfSize:size]
#define FLEXBoldSystemFontOfSize(size) [UIFont boldSystemFontOfSize:size]

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000
#define FLEXMonospacedSystemFontOfSize(size) \
    (FLEX_AT_LEAST_IOS13 ? [UIFont monospacedSystemFontOfSize:size weight:UIFontWeightRegular] : [UIFont fontWithName:@"Courier" size:size])
#else
#define FLEXMonospacedSystemFontOfSize(size) [UIFont fontWithName:@"Courier" size:size]
#endif

// 控件样式兼容性宏
#define FLEXTableViewStyleInsetGrouped \
    (FLEX_AT_LEAST_IOS13 ? UITableViewStyleInsetGrouped : UITableViewStyleGrouped)

// 弹窗样式兼容性宏
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000
#define FLEXAlertControllerStyleActionSheet \
    (FLEX_AT_LEAST_IOS13 ? UIAlertControllerStyleActionSheet : UIAlertControllerStyleActionSheet)
#else
#define FLEXAlertControllerStyleActionSheet UIAlertControllerStyleActionSheet
#endif

// 模糊效果兼容性宏
#define FLEXBlurEffectStyleSystemMaterial \
    (FLEX_AT_LEAST_IOS13 ? UIBlurEffectStyleSystemMaterial : UIBlurEffectStyleLight)

#define FLEXBlurEffectStyleSystemThinMaterial \
    (FLEX_AT_LEAST_IOS13 ? UIBlurEffectStyleSystemThinMaterial : UIBlurEffectStyleExtraLight)

// 键盘外观兼容性宏
#define FLEXKeyboardAppearanceDefault \
    (FLEX_AT_LEAST_IOS13 ? UIKeyboardAppearanceDefault : UIKeyboardAppearanceDefault)

// 状态栏样式兼容性宏
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000
#define FLEXStatusBarStyleDefault \
    (FLEX_AT_LEAST_IOS13 ? UIStatusBarStyleDefault : UIStatusBarStyleDefault)
#else
#define FLEXStatusBarStyleDefault UIStatusBarStyleDefault
#endif