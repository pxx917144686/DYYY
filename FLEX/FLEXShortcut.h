//
//  FLEXShortcut.h
//  FLEX
//
//  由 Tanner Bennett 创建于 12/10/19.
//  版权所有 © 2020 FLEX Team. 保留所有权利。
//

#import "FLEXObjectExplorer.h"

NS_ASSUME_NONNULL_BEGIN

/// 表示快捷方式部分中的一行。
///
/// 此协议的目的是允许将 \c FLEXShortcutsSection 
/// 的一小部分职责委托给另一个对象，用于单个任意行。
///
/// 创建自己的快捷方式并将它们附加/前置到
/// 类的现有快捷方式列表中非常有用。
@protocol FLEXShortcut <FLEXObjectExplorerItem>

- (nonnull  NSString *)titleWith:(id)object;
- (nullable NSString *)subtitleWith:(id)object;
- (nullable void (^)(UIViewController *host))didSelectActionWith:(id)object;
/// 当行被选中时调用
- (nullable UIViewController *)viewerWith:(id)object;
/// 基本上，是否显示详细信息指示器
- (UITableViewCellAccessoryType)accessoryTypeWith:(id)object;
/// 如果返回 nil，则使用默认重用标识符
- (nullable NSString *)customReuseIdentifierWith:(id)object;

@optional
/// 如果附件类型包含 (i) 按钮，则在按下 (i) 按钮时调用
- (UIViewController *)editorWith:(id)object forSection:(FLEXTableViewSection *)section;

@end


/// 为 FLEX 元数据对象提供默认行为。也以有限的方式适用于字符串。
/// 内部使用。如果您希望使用此对象，只传入 \c FLEX* 元数据对象。
@interface FLEXShortcut : NSObject <FLEXShortcut>

/// @param item 一个 \c NSString 或 \c FLEX* 元数据对象。
/// @note 您也可以传递一个符合 \c FLEXShortcut 的对象，
/// 这种情况下将返回该对象本身。
+ (id<FLEXShortcut>)shortcutFor:(id)item;

@end


/// 提供 \c FLEXShortcut 协议的快速简单实现，
/// 允许您指定静态标题和其他所有内容的动态属性。
/// 传递给每个块的对象是传递给每个 \c FLEXShortcut 方法的对象。
///
/// 不支持 \c -editorWith: 方法。
@interface FLEXActionShortcut : NSObject <FLEXShortcut>

+ (instancetype)title:(NSString *)title
             subtitle:(nullable NSString *(^)(id object))subtitleFuture
               viewer:(nullable UIViewController *(^)(id object))viewerFuture
        accessoryType:(nullable UITableViewCellAccessoryType(^)(id object))accessoryTypeFuture;

+ (instancetype)title:(NSString *)title
             subtitle:(nullable NSString *(^)(id object))subtitleFuture
     selectionHandler:(nullable void (^)(UIViewController *host, id object))tapAction
        accessoryType:(nullable UITableViewCellAccessoryType(^)(id object))accessoryTypeFuture;

@end

NS_ASSUME_NONNULL_END
