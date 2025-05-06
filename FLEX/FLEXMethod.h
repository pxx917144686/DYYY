// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXMethod.h
//  FLEX
//
//  派生自 MirrorKit。
//  由 Tanner 创建于 6/30/15.
//  版权所有 (c) 2020 FLEX Team。保留所有权利。
//

#import "FLEXRuntimeConstants.h"
#import "FLEXMethodBase.h"

NS_ASSUME_NONNULL_BEGIN

/// 表示类中已存在的具体方法的类。
/// 此类包含用于 swizzling 或调用该方法的辅助方法。
///
/// 如果方法的类型编码不受 `NSMethodSignature` 支持，
/// 则任何初始化程序都将返回 nil。通常，任何返回类型或参数
/// 涉及具有位域或数组的结构的方法都不受支持。
///
/// 我不记得最初编写此代码时为什么没有在基类中包含 \c signature，
/// 但我可能有一个很好的理由。如果我们发现需要，
/// 总是可以将其移回 \c FLEXMethodBase。
@interface FLEXMethod : FLEXMethodBase

/// 默认为实例方法
+ (nullable instancetype)method:(Method)method;
+ (nullable instancetype)method:(Method)method isInstanceMethod:(BOOL)isInstanceMethod;

/// 为给定类上的给定方法构造一个 \c FLEXMethod。
/// @param cls 类，如果是类方法，则为元类
/// @return 新构造的 \c FLEXMethod 对象，如果指定的类或其超类
/// 不包含具有指定选择器的方法，则为 \c nil。
+ (nullable instancetype)selector:(SEL)selector class:(Class)cls;
/// 为给定类上的给定方法构造一个 \c FLEXMethod，
/// 仅当给定类本身定义或覆盖所需方法时。
/// @param cls 类，如果是类方法，则为元类
/// @return 新构造的 \c FLEXMethod 对象，如果 \e 指定的类
/// 未定义或覆盖，或者如果指定的类或其超类不包含
/// 具有指定选择器的方法，则为 \c nil。
+ (nullable instancetype)selector:(SEL)selector implementedInClass:(Class)cls;

@property (nonatomic, readonly) Method            objc_method;
/// 方法的实现。
/// @讨论 设置 \c implementation 将更改实现该方法的整个类
/// 的此方法的实现。它也不会修改该方法的选择器。
@property (nonatomic          ) IMP               implementation;
/// 方法是否是实例方法。
@property (nonatomic, readonly) BOOL              isInstanceMethod;
/// 方法的参数数量。
@property (nonatomic, readonly) NSUInteger        numberOfArguments;
/// 与方法的类型编码对应的 \c NSMethodSignature 对象。
@property (nonatomic, readonly) NSMethodSignature *signature;
/// 与 \e typeEncoding 相同，但参数大小在前，偏移量在类型之后。
@property (nonatomic, readonly) NSString          *signatureString;
/// 方法的返回类型。
@property (nonatomic, readonly) FLEXTypeEncoding  *returnType;
/// 方法的返回大小。
@property (nonatomic, readonly) NSUInteger        returnSize;
/// 包含此方法定义的映像的完整路径，
/// 如果此 ivar 可能是在运行时定义的，则为 \c nil。
@property (nonatomic, readonly) NSString          *imagePath;

/// 类似于 @code - (void)foo:(int)bar @endcode
@property (nonatomic, readonly) NSString *description;
/// 类似于 @code -[Class foo:] @endcode
- (NSString *)debugNameGivenClassName:(NSString *)name;

/// 将接收方法与给定方法进行 Swizzling。
- (void)swapImplementations:(FLEXMethod *)method;

#define FLEXMagicNumber 0xdeadbeef
#define FLEXArg(expr) FLEXMagicNumber,/// @encode(__typeof__(expr)), (__typeof__(expr) []){ expr }

/// 向 \e target 发送消息，并返回其值，如果不适用则返回 \c nil。
/// @讨论 您可以使用此方法发送任何消息。原始返回类型将包装在
/// \c NSNumber 和 \c NSValue 的实例中。\c void 和返回位域的方法返回 \c nil。
/// \c SEL 返回类型使用 \c NSStringFromSelector 转换为字符串。
/// @return 此方法返回的对象，或包含原始返回类型的 \c NSValue 或 \c NSNumber
/// 的实例，或 \c SEL 返回类型的字符串。
- (id)sendMessage:(id)target, ...;
/// 由 \c sendMessage:target, 内部使用。对于 void 方法，将 \c NULL 传递给第一个参数。
- (void)getReturnValue:(void *)retPtr forMessageSend:(id)target, ...;

@end


@interface FLEXMethod (Comparison)

- (NSComparisonResult)compare:(FLEXMethod *)method;

@end

NS_ASSUME_NONNULL_END
