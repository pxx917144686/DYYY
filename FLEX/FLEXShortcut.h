// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXShortcut.h
//  FLEX
//
//  由 Tanner Bennett 创建于 12/10/19.
//  版权所有 © 2020 FLEX Team。保留所有权利。
//

#import "FLEXObjectExplorer.h"

NS_ASSUME_NONNULL_BEGIN

/// 表示快捷方式分区中的一行。
///
/// 此协议的目的是允许将 \c FLEXShortcutsSection 的一小部分职责
/// 委托给另一个对象，用于单个任意行。
///
/// 创建您自己的快捷方式以将它们附加/前置到类的现有快捷方式列表非常有用。
@protocol FLEXShortcut <FLEXObjectExplorerItem>

- (nonnull  NSString *)titleWith:(id)object;
- (nullable NSString *)subtitleWith:(id)object;
- (nullable void (^)(UIViewController *host))didSelectActionWith:(id)object;
/// 当行被选中时调用
- (nullable UIViewController *)viewerWith:(id)object;
/// 基本上，是否显示详细信息展开指示器
- (UITableViewCellAccessoryType)accessoryTypeWith:(id)object;
/// 如果返回 nil，则使用默认的重用标识符
- (nullable NSString *)customReuseIdentifierWith:(id)object;

@optional
/// 如果附件类型包含 (i) 按钮，则在按下该按钮时调用
- (UIViewController *)editorWith:(id)object forSection:(FLEXTableViewSection *)section;

@end


/// 为 FLEX 元数据对象提供默认行为。也以有限的方式处理字符串。
/// 内部使用。如果您希望使用此对象，请仅传入 \c FLEX* 元数据对象。
@interface FLEXShortcut : NSObject <FLEXShortcut>

/// @param item 一个 \c NSString 或 \c FLEX* 元数据对象。
/// @note 您也可以传递一个符合 \c FLEXShortcut 的对象，
/// 并且该对象将被返回。
+ (id<FLEXShortcut>)shortcutFor:(id)item;

@end


/// 提供 \c FLEXShortcut 协议的快速实现，
/// 允许您为其他所有内容指定静态标题和动态属性。
/// 传递到每个块中的对象是传递到每个 \c FLEXShortcut 方法的对象。
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
