// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXObjectInfoSection.h
//  FLEX
//
//  由 Tanner Bennett 创建于 8/28/19.
//  版权所有 © 2020 FLEX Team。保留所有权利。
//

#import <Foundation/Foundation.h>

/// \c FLEXTableViewSection 本身并不知道正在浏览的对象。
/// 子类可能需要此信息来提供有关对象的有用信息。与其
/// 在类层次结构中添加抽象类，子类可以遵循此协议
/// 以表明它们初始化所需的唯一信息是正在浏览的对象。
@protocol FLEXObjectInfoSection <NSObject>

+ (instancetype)forObject:(id)object;

@end
