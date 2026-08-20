#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

#ifdef __cplusplus
extern "C" {
#endif

/// 当前是否应使用暗色语义色。优先读取抖音的 AWEUIThemeManager，
/// 避免系统 trait 被抖音窗口 override 成浅色后误判。
BOOL DYYYThemeIsDark(void);

UIColor *DYYYThemeBackgroundColor(void);
UIColor *DYYYThemeSurfaceColor(void);
UIColor *DYYYThemePrimaryTextColor(void);
UIColor *DYYYThemeSecondaryTextColor(void);
UIColor *DYYYThemeSeparatorColor(void);
UIColor *DYYYThemeAccentColor(void);

UIBlurEffectStyle DYYYThemeBlurStyle(void);
CGFloat DYYYThemeBlurAlpha(void);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
