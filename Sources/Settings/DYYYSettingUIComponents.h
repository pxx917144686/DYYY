#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface DYYYSliderRelay : NSObject
@property (nonatomic, copy) void (^block)(UISlider *slider);
- (void)changed:(UISlider *)sender;
@end

@interface DYYYSliderViewController : UIViewController
- (instancetype)initWithTitle:(NSString *)title
                        value:(NSInteger)value
                   completion:(void (^)(NSInteger value))completion;
@end

NS_ASSUME_NONNULL_END
