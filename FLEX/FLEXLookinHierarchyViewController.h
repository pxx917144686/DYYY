#import <UIKit/UIKit.h>
#import "FLEXLookinInspector.h"

NS_ASSUME_NONNULL_BEGIN

@interface FLEXLookinHierarchyViewController : UIViewController <FLEXLookinInspectorDelegate>

@property (nonatomic, strong) FLEXLookinInspector *inspector;

@end

NS_ASSUME_NONNULL_END