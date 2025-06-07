#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface FLEXLookinMeasureResultView : UIView

- (void)showMeasureResultWithMainView:(UIView *)mainView referenceView:(UIView *)referenceView;
- (void)hideMeasureResult;

@end

NS_ASSUME_NONNULL_END