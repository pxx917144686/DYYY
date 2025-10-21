#import <UIKit/UIKit.h>
#import "FLEXTableViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface FLEXMachOClassBrowserViewController : FLEXTableViewController

@property (nonatomic, strong) NSArray<NSString *> *classNames;
@property (nonatomic, copy) NSString *imagePath;

@end

NS_ASSUME_NONNULL_END