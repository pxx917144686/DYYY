#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface FLEXDoKitFloatingWindow : UIWindow

@property (nonatomic, assign) BOOL isDragging;
@property (nonatomic, assign) CGPoint lastPanPoint;

- (void)show;
- (void)hide;

@end

NS_ASSUME_NONNULL_END