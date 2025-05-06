// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXMethodBase.h
//  FLEX
//
//  派生自 MirrorKit。
//  由 Tanner 创建于 7/5/15.
//  版权所有 (c) 2020 FLEX Team。保留所有权利。
//

#import <Foundation/Foundation.h>


/// 方法的基类，包含那些可能尚未添加到类中的方法。
/// 可单独用于向类中添加方法，或从头开始构建新类。
@interface FLEXMethodBase : NSObject {
@protected
    SEL      _selector;
    NSString *_name;
    NSString *_typeEncoding;
    IMP      _implementation;
    
    NSString *_flex_description;
}

/// 构建并返回一个具有给定名称、类型编码和实现的 \c FLEXSimpleMethod 实例。
+ (instancetype)buildMethodNamed:(NSString *)name withTypes:(NSString *)typeEncoding implementation:(IMP)implementation;

/// 方法的选择器。
@property (nonatomic, readonly) SEL      selector;
/// 方法的选择器字符串。
@property (nonatomic, readonly) NSString *selectorString;
/// 与 selectorString 相同。
@property (nonatomic, readonly) NSString *name;
/// 方法的类型编码。
@property (nonatomic, readonly) NSString *typeEncoding;
/// 方法的实现。
@property (nonatomic, readonly) IMP      implementation;

/// 供内部使用
@property (nonatomic) id tag;

@end
