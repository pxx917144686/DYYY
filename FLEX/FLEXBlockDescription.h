//
//  FLEXBlockDescription.h
//  FLEX
//
//  创建者：Oliver Letterer，日期：2012-09-01
//  派生自 CTObjectiveCRuntimeAdditions (MIT 许可证)
//  https://github.com/ebf/CTObjectiveCRuntimeAdditions
//
//  版权所有 (c) 2020 FLEX Team-EDV Beratung Föllmer GmbH
//  特此授予任何人免费获得本软件和相关文档文件（“软件”）副本的许可，
//  可以不受限制地处理本软件，包括但不限于使用、复制、修改、合并、
//  发布、分发、再许可和/或销售本软件副本的权利，并允许获得本软件的
//  人这样做，但须符合以下条件：
//  上述版权声明和本许可声明应包含在本软件的所有副本或
//  实质部分中。
//
//  本软件按“原样”提供，不作任何明示或暗示的保证，包括但
//  不限于对适销性、特定用途适用性和非侵权性的保证。在任何情况下，
//  作者或版权持有人均不对任何索赔、损害或其他责任承担任何责任，无论是在
//  合同诉讼、侵权行为还是其他方面，由本软件或本软件的使用或其他交易引起或与之相关。
//
// 遇到问题联系中文翻译作者：pxx917144686

#import <Foundation/Foundation.h>

typedef NS_OPTIONS(NSUInteger, FLEXBlockOptions) {
   FLEXBlockOptionHasCopyDispose = (1 << 25), // 块有复制/释放辅助函数
   FLEXBlockOptionHasCtor        = (1 << 26), // 辅助函数包含 C++ 代码
   FLEXBlockOptionIsGlobal       = (1 << 28), // 块是全局的
   FLEXBlockOptionHasStret       = (1 << 29), // 当 BLOCK_HAS_SIGNATURE 设置时，表示块返回结构体
   FLEXBlockOptionHasSignature   = (1 << 30), // 块有签名
};

NS_ASSUME_NONNULL_BEGIN

#pragma mark - // 分隔符
@interface FLEXBlockDescription : NSObject

+ (instancetype)describing:(id)block;

@property (nonatomic, readonly, nullable) NSMethodSignature *signature;
@property (nonatomic, readonly, nullable) NSString *signatureString;
@property (nonatomic, readonly, nullable) NSString *sourceDeclaration; // 可能的源代码声明
@property (nonatomic, readonly) FLEXBlockOptions flags;
@property (nonatomic, readonly) NSUInteger size;
@property (nonatomic, readonly) NSString *summary; // 摘要
@property (nonatomic, readonly) id block;

- (BOOL)isCompatibleForBlockSwizzlingWithMethodSignature:(NSMethodSignature *)methodSignature;

@end

#pragma mark - // 分隔符
@interface NSBlock : NSObject
- (void)invoke;
@end

NS_ASSUME_NONNULL_END
