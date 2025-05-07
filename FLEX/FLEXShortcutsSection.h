// filepath: FLEXShortcutsSection.h
// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXShortcutsSection.h
//  FLEX
//
//  由 Tanner Bennett 创建于 8/29/19.
//  版权所有 © 2020 FLEX Team。保留所有权利。
//

#import "FLEXTableViewSection.h"
#import "FLEXObjectInfoSection.h"
@class FLEXProperty, FLEXIvar, FLEXMethod;

NS_ASSUME_NONNULL_BEGIN

/// 自定义对象“快捷方式”的抽象基类，其中每一行都可能有某种操作。分区标题为“快捷方式”。
///
/// 仅当您需要带有纯文本标题和/或副标题的简单快捷方式时，才应子类化此类。
/// 此类将自动适当地配置每个单元格。由于这旨在作为静态分区，
/// 因此子类仅需要实现 \c viewControllerToPushForRow: 和/或 \c didSelectRowAction: 方法。
///
/// 如果您使用 \c forObject:rows:numberOfLines: 创建分区，
/// 则它将自动为作为属性/实例变量/方法的行从 \c viewControllerToPushForRow: 提供视图控制器。
@interface FLEXShortcutsSection : FLEXTableViewSection <FLEXObjectInfoSection>

/// 使用 \c kFLEXDefaultCell
+ (instancetype)forObject:(id)objectOrClass rowTitles:(nullable NSArray<NSString *> *)titles;
/// 对于非空副标题使用 \c kFLEXDetailCell，否则使用 \c kFLEXDefaultCell
+ (instancetype)forObject:(id)objectOrClass
                rowTitles:(nullable NSArray<NSString *> *)titles
             rowSubtitles:(nullable NSArray<NSString *> *)subtitles;

/// 对于给定标题的行使用 \c kFLEXDefaultCell，否则对于任何其他允许的对象使用 \c kFLEXDetailCell。
///
/// 对于作为属性/实例变量/方法的行，该分区会自动从 \c viewControllerToPushForRow: 提供视图控制器。
///
/// @param rows 一个混合数组，包含以下任何内容：
/// - 任何符合 \c FLEXShortcut 的对象
/// - 一个 \c NSString
/// - 一个 \c FLEXProperty
/// - 一个 \c FLEXIvar
/// - 一个 \c FLEXMethodBase（当然包括 \c FLEXMethod）
/// 传递后三者之一将提供到该属性/实例变量/方法的快捷方式。
+ (instancetype)forObject:(id)objectOrClass rows:(nullable NSArray *)rows;

/// 与 \c forObject:rows: 相同，但给定的行会前置到已为对象类注册的快捷方式之前。
/// \c forObject:rows: 完全不使用已注册的快捷方式。
+ (instancetype)forObject:(id)objectOrClass additionalRows:(nullable NSArray *)rows;

/// 使用为对象类注册的快捷方式调用 \c forObject:rows:。
/// @return 如果对象根本没有注册快捷方式，则返回一个空分区。
+ (instancetype)forObject:(id)objectOrClass;

/// 子类 \e 可以重写此方法以隐藏某些行的展开指示器。
/// 默认情况下，所有行都会显示它，除非您使用 \c forObject:rowTitles:rowSubtitles: 对其进行初始化。
///
/// 当您隐藏展开指示器时，该行不可选。
- (UITableViewCellAccessoryType)accessoryTypeForRow:(NSInteger)row;

/// 标题和副标题标签的行数。默认为 1。
@property (nonatomic, readonly) NSInteger numberOfLines;
/// 用于初始化此分区的对象。
@property (nonatomic, readonly) id object;

/// 是否应在配置单元格时始终计算动态副标题。
/// 默认为 NO。对显式传递的静态副标题没有影响。
@property (nonatomic) BOOL cacheSubtitles;

/// 此快捷方式分区是否覆盖默认分区。
/// 子类不应重写此方法。要在默认快捷方式分区旁边提供第二个分区，请使用 \c forObject:rows:
/// @return 如果使用 \c forObject: 或 \c forObject:additionalRows: 初始化，则为 \c NO
@property (nonatomic, readonly) BOOL isNewSection;

@end

@class FLEXShortcutsFactory;
typedef FLEXShortcutsFactory *_Nonnull(^FLEXShortcutsFactoryNames)(NSArray *names);
typedef void (^FLEXShortcutsFactoryTarget)(Class targetClass);

/// 下面的块属性应像 SnapKit 或 Masonry 一样使用。
/// \c FLEXShortcutsSection.append.properties(@[@"frame",@"bounds"]).forClass(UIView.class);
///
/// 要在启动时安全地注册您自己的类，请子类化此类，
/// 重写 \c +load，并在 \c self 上调用适当的方法
@interface FLEXShortcutsFactory : NSObject

/// 按以下顺序返回给定对象的所有已注册快捷方式列表：
/// 属性、实例变量、方法。
///
/// 此方法会向上遍历对象的类层次结构，直到找到已注册的内容。
/// 这允许您在类层次结构的不同部分显示同一对象的不同快捷方式。
///
/// 例如，UIView 可能注册了一个 -layer 快捷方式。但是如果您正在检查 UIControl，
/// 您可能不关心图层或其他 UIView 特定的内容；您可能更希望看到为此控件注册的目标操作，
/// 因此您会将该属性或实例变量注册到 UIControl，
/// 并且您仍然可以通过单击浏览器视图控制器屏幕顶部的 UIView“镜头”来查看 UIView 注册的快捷方式。
+ (NSArray *)shortcutsForObjectOrClass:(id)objectOrClass;

@property (nonatomic, readonly, class) FLEXShortcutsFactory *append;
@property (nonatomic, readonly, class) FLEXShortcutsFactory *prepend;
@property (nonatomic, readonly, class) FLEXShortcutsFactory *replace;

@property (nonatomic, readonly) FLEXShortcutsFactoryNames properties;
/// 不要尝试同时设置 \c classProperties 和 \c ivars 或其他实例相关的内容。
@property (nonatomic, readonly) FLEXShortcutsFactoryNames classProperties;
@property (nonatomic, readonly) FLEXShortcutsFactoryNames ivars;
@property (nonatomic, readonly) FLEXShortcutsFactoryNames methods;
/// 不要尝试同时设置 \c classMethods 和 \c ivars 或其他实例相关的内容。
@property (nonatomic, readonly) FLEXShortcutsFactoryNames classMethods;

/// 接受目标类。如果传递常规类对象，快捷方式将出现在实例上。
/// 如果传递元类对象，快捷方式将在浏览类对象时出现。
///
/// 例如，默认情况下，一些类方法快捷方式会添加到 NSObject 元类中，
/// 以便您在浏览类对象时可以看到 +alloc 和 +new。
/// 如果您希望在浏览实例时显示这些快捷方式，则应将它们传递给上面的 classMethods 方法。
@property (nonatomic, readonly) FLEXShortcutsFactoryTarget forClass;

@end

NS_ASSUME_NONNULL_END
