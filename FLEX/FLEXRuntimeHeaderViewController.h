#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface FLEXRuntimeHeaderViewController : UIViewController

/// 指定一个 Objective-C 类以显示其运行时头信息
@property (nonatomic, strong) Class classObject;

/// 初始化方法
+ (instancetype)withClass:(Class)cls;

@end

NS_ASSUME_NONNULL_END