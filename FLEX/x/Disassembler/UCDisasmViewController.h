//
//  UCDisasmViewController.h
//  FLEX++
//
//  反汇编查看器
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN

@interface UCDisasmViewController : UIViewController

/// 从指定地址开始反汇编
- (instancetype)initWithAddress:(uint64_t)address
                           size:(NSUInteger)size
                          title:(nullable NSString *)title;

/// 反汇编指定方法
- (instancetype)initWithMethod:(Method)method
                         class:(nullable NSString *)className
                      selector:(nullable NSString *)selectorName;

/// 反汇编指定类的方法
- (instancetype)initWithClass:(Class)cls
                     selector:(SEL)selector
               isClassMethod:(BOOL)isClassMethod;

@end

NS_ASSUME_NONNULL_END
