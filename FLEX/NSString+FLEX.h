// 遇到问题联系中文翻译作者：pxx917144686
//
//  NSString+FLEX.h
//  FLEX
//
//  由 Tanner 创建于 3/26/17.
//  版权所有 © 2017 Tanner Bennett。保留所有权利。
//

#import "FLEXRuntimeConstants.h"

@interface NSString (FLEXTypeEncoding)

///@return 此类型是否以 const 说明符开头
@property (nonatomic, readonly) BOOL flex_typeIsConst; // 类型是否为常量
/// @return 类型编码中第一个非 const 说明符的字符
@property (nonatomic, readonly) FLEXTypeEncoding flex_firstNonConstType; // 首个非 const 类型字符
/// @return 如果是指针，则返回指针说明符之后的类型编码中的第一个字符
@property (nonatomic, readonly) FLEXTypeEncoding flex_pointeeType; // 指针指向的类型字符
/// @return 此类型是否是任何类型的 Objective-C 对象，即使它是 const
@property (nonatomic, readonly) BOOL flex_typeIsObjectOrClass; // 类型是否为对象或类
/// @return 如果类型编码的形式为 \c @"MYClass"，则返回此类型编码中命名的类
@property (nonatomic, readonly) Class flex_typeClass; // 类型对应的类
/// 包括 C 字符串和选择器以及常规指针
@property (nonatomic, readonly) BOOL flex_typeIsNonObjcPointer; // 类型是否为非 OC 指针

@end

@interface NSString (KeyPaths)

- (NSString *)flex_stringByRemovingLastKeyPathComponent;
- (NSString *)flex_stringByReplacingLastKeyPathComponent:(NSString *)replacement;

@end
