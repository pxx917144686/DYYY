// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXArgumentInputViewFactory.h
//  FLEXInjected
//
//  创建者：Ryan Olson，日期：6/15/14.
//
//

#import <Foundation/Foundation.h>
#import "FLEXArgumentInputSwitchView.h" // 虽然这里导入了 SwitchView，但工厂类本身与它没有直接的强依赖关系，只是可能创建它

@interface FLEXArgumentInputViewFactory : NSObject

/// 转发到 argumentInputViewForTypeEncoding:currentValue:，currentValue 为 nil。
+ (FLEXArgumentInputView *)argumentInputViewForTypeEncoding:(const char *)typeEncoding;

/// 用于创建最适合该类型的参数输入视图子类的主工厂方法。
+ (FLEXArgumentInputView *)argumentInputViewForTypeEncoding:(const char *)typeEncoding currentValue:(id)currentValue;

/// 一种检查方法，用于判断是否应尝试编辑给定类型编码和值的字段。
/// 在决定是编辑还是浏览属性、实例变量或 NSUserDefaults 值时非常有用。
+ (BOOL)canEditFieldWithTypeEncoding:(const char *)typeEncoding currentValue:(id)currentValue;

/// 为自定义结构类型启用显示 ivar 名称
+ (void)registerFieldNames:(NSArray<NSString *> *)names forTypeEncoding:(NSString *)typeEncoding;

@end
