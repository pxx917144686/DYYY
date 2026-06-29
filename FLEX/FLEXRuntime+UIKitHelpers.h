//
//  FLEXRuntime+UIKitHelpers.h
//  FLEX
//
//  由 Tanner Bennett 创建于 12/16/19.
//  版权所有 © 2020 FLEX Team. 保留所有权利。
//

#import <UIKit/UIKit.h>
#import "FLEXProperty.h"
#import "FLEXIvar.h"
#import "FLEXMethod.h"
#import "FLEXProtocol.h"
#import "FLEXTableViewSection.h"

@class FLEXObjectExplorerDefaults;

/// 对象浏览器屏幕的模型对象采用此协议
/// 以便响应用户默认设置的更改
@protocol FLEXObjectExplorerItem <NSObject>
/// 当前浏览器设置。在设置更改时设置。
@property (nonatomic) FLEXObjectExplorerDefaults *defaults;

/// 对于确保支持编辑的属性和实例变量为YES，对于所有方法为NO。
@property (nonatomic, readonly) BOOL isEditable;
/// 对于实例变量为NO，对于支持的方法和属性为YES
@property (nonatomic, readonly) BOOL isCallable;
@end

@protocol FLEXRuntimeMetadata <FLEXObjectExplorerItem>
/// 用作行的主标题
- (NSString *)description;
/// 用于比较元数据对象的唯一性
@property (nonatomic, readonly) NSString *name;

/// 供内部使用
@property (nonatomic) id tag;

/// 如果不适用，应返回 \c nil
- (id)currentValueWithTarget:(id)object;
/// 用作属性、实例变量或方法的副标题或描述
- (NSString *)previewWithTarget:(id)object;
/// 对于方法，是方法调用屏幕。对于其他所有内容，是对象浏览器。
- (UIViewController *)viewerWithTarget:(id)object;
/// 对于方法和协议为nil。对于其他所有内容，是字段编辑器屏幕。
/// 提交任何更改时，重新加载给定的部分。
- (UIViewController *)editorWithTarget:(id)object section:(FLEXTableViewSection *)section;
/// 用于确定向用户呈现哪些可能的交互
- (UITableViewCellAccessoryType)suggestedAccessoryTypeWithTarget:(id)object;
/// 返回nil以使用默认的重用标识符
- (NSString *)reuseIdentifierWithTarget:(id)object;

/// 要放在上下文菜单第一部分的操作数组。
- (NSArray<UIAction *> *)additionalActionsWithTarget:(id)object sender:(UIViewController *)sender API_AVAILABLE(ios(13.0));
/// 一个数组，每2个元素是一个键值对。键是描述
/// 要复制的内容，如"名称"，值是将被复制的内容。
- (NSArray<NSString *> *)copiableMetadataWithTarget:(id)object;
/// 如果属性和实例变量持有一个对象，则返回该对象的地址。
- (NSString *)contextualSubtitleWithTarget:(id)object;

@end

// 即使一个属性是只读的，它仍然可能是可编辑的
// 通过setter方法。除非属性是用类初始化的，
// 否则检查isEditable将不会反映这一点。
@interface FLEXProperty (UIKitHelpers) <FLEXRuntimeMetadata> @end
@interface FLEXIvar (UIKitHelpers) <FLEXRuntimeMetadata> @end
@interface FLEXMethodBase (UIKitHelpers) <FLEXRuntimeMetadata> @end
@interface FLEXMethod (UIKitHelpers) <FLEXRuntimeMetadata> @end
@interface FLEXProtocol (UIKitHelpers) <FLEXRuntimeMetadata> @end

typedef NS_ENUM(NSUInteger, FLEXStaticMetadataRowStyle) {
    FLEXStaticMetadataRowStyleSubtitle,
    FLEXStaticMetadataRowStyleKeyValue,
    FLEXStaticMetadataRowStyleDefault = FLEXStaticMetadataRowStyleSubtitle,
};

/// 以静态键值对信息的形式显示一个小行。
@interface FLEXStaticMetadata : NSObject <FLEXRuntimeMetadata>

+ (instancetype)style:(FLEXStaticMetadataRowStyle)style title:(NSString *)title string:(NSString *)string;
+ (instancetype)style:(FLEXStaticMetadataRowStyle)style title:(NSString *)title number:(NSNumber *)number;

+ (NSArray<FLEXStaticMetadata *> *)classHierarchy:(NSArray<Class> *)classes;

@end


/// 这被分配给每个元数据的 \c tag 属性。

