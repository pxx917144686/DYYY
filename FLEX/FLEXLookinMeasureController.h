#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, FLEXLookinMeasureState) {
    FLEXLookinMeasureState_no,        // 没有处于测距模式
    FLEXLookinMeasureState_unlocked,  // 处于测距模式，但未锁定
    FLEXLookinMeasureState_locked     // 处于测距模式，且锁定
};

@interface FLEXLookinMeasureController : NSObject

@property (nonatomic, assign) FLEXLookinMeasureState measureState;
@property (nonatomic, weak) UIView *mainView;
@property (nonatomic, weak) UIView *referenceView;

+ (instancetype)sharedInstance;

// 测量控制
- (void)startMeasuring;
- (void)stopMeasuring;
- (void)lockMeasuring:(BOOL)locked;

@end

NS_ASSUME_NONNULL_END