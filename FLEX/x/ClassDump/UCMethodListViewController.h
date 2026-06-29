//
//  UCMethodListViewController.h
//  FLEX++
//
//  方法列表视图控制器
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN

@interface UCMethodListViewController : UIViewController

/// 初始化方法列表
/// @param cls 类
/// @param isClassMethod YES=类方法, NO=实例方法
- (instancetype)initWithClass:(Class)cls isClassMethod:(BOOL)isClassMethod;

@property (nonatomic, weak) UINavigationController *presentingNav;

@end

NS_ASSUME_NONNULL_END
