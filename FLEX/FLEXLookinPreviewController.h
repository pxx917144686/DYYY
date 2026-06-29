#import <UIKit/UIKit.h>
#import "FLEXLookinDisplayItem.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, FLEXLookinPreviewDimension) {
    FLEXLookinPreviewDimension2D = 0,
    FLEXLookinPreviewDimension3D = 1
};

@interface FLEXLookinPreviewController : UIViewController <UIScrollViewDelegate>  // ✅ 添加协议声明

@property (nonatomic, assign) FLEXLookinPreviewDimension previewDimension;
@property (nonatomic, assign) CGFloat previewScale;
@property (nonatomic, assign) CGPoint rotation;
@property (nonatomic, assign) CGPoint translation;
@property (nonatomic, assign) CGFloat zInterspace;

// ✅ 纯iOS功能
- (void)renderWithDisplayItems:(NSArray<FLEXLookinDisplayItem *> *)items;
- (void)setDimension:(FLEXLookinPreviewDimension)dimension animated:(BOOL)animated;
- (void)setRotation:(CGPoint)rotation animated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END