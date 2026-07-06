#import <UIKit/UIKit.h>
#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN

@interface UCMethodListViewController : UIViewController

- (instancetype)initWithClass:(Class)cls isClassMethod:(BOOL)isClassMethod;

@property (nonatomic, weak) UINavigationController *presentingNav;

@end

NS_ASSUME_NONNULL_END
