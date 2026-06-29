#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface FLEXDoKitVisualTools : NSObject

+ (instancetype)sharedInstance;

// 颜色吸管
- (void)startColorPicker;
- (void)stopColorPicker;

// 对齐标尺
- (void)showRuler;
- (void)hideRuler;

// 视图边框
- (void)showViewBorders;
- (void)hideViewBorders;

// 布局边界
- (void)showLayoutBounds;
- (void)hideLayoutBounds;

@end

NS_ASSUME_NONNULL_END