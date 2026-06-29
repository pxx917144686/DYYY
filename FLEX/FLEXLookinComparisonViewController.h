#import <UIKit/UIKit.h>
#import "FLEXLookinInspector.h"

NS_ASSUME_NONNULL_BEGIN

@interface FLEXLookinComparisonViewController : UIViewController

@property (nonatomic, strong) NSArray<NSArray<FLEXLookinViewNode *> *> *snapshots;

@end

NS_ASSUME_NONNULL_END