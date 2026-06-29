//
//  FLEXShortcutsSection.h
//  FLEX
//
//  由 Tanner Bennett 创建于 8/29/19.
//  版权所有 © 2020 FLEX Team. 保留所有权利。
//

#import "FLEXTableViewSection.h"
#import "FLEXObjectInfoSection.h"
@class FLEXProperty, FLEXIvar, FLEXMethod;

NS_ASSUME_NONNULL_BEGIN

/// 自定义对象"快捷方式"的抽象基类，其中每一行
/// 可能都有一些操作。区段标题为"快捷方式"。
///
/// 仅当您需要带有纯标题和/或副标题的简单快捷方式时，
/// 才应子类化此类。此类将自动适当地配置每个单元格。
/// 由于这是作为静态区段设计的，子类应该只需要实现
/// \c viewControllerToPushForRow: 和/或 \c didSelectRowAction: 方法。
///
/// 如果您使用 \c forObject:rows:numberOfLines: 创建该区段，
/// 则它将自动为作为属性/实例变量/方法的行
/// 从 \c viewControllerToPushForRow: 提供视图控制器。
@interface FLEXShortcutsSection : FLEXTableViewSection <FLEXObjectInfoSection>

/// 使用 \c kFLEXDefaultCell
+ (instancetype)forObject:(id)objectOrClass rowTitles:(nullable NSArray<NSString *> *)titles;
/// 对非空副标题使用 \c kFLEXDetailCell，否则使用 \c kFLEXDefaultCell
+ (instancetype)forObject:(id)objectOrClass
                rowTitles:(nullable NSArray<NSString *> *)titles
             rowSubtitles:(nullable NSArray<NSString *> *)subtitles;

/// 对于给定标题的行使用 \c kFLEXDefaultCell，
/// 否则为任何其他允许的对象使用 \c kFLEXDetailCell。
///
/// 该区段将自动为作为属性/实例变量/方法的行
/// 从 \c viewControllerToPushForRow: 提供视图控制器。
///
/// @param rows 包含以下任何内容的混合数组：
/// - 任何遵循 \c FLEXShortcut 的对象
/// - 一个 \c NSString
/// - 一个 \c FLEXProperty
/// - 一个 \c FLEXIvar
/// - 一个 \c FLEXMethodBase（当然包括 \c FLEXMethod）
/// 传递后三者之一将提供对该属性/实例变量/方法的快捷方式。
+ (instancetype)forObject:(id)objectOrClass rows:(nullable NSArray *)rows;

/// 与 \c forObject:rows: 相同，但给定的行会被前置
/// 到已经为对象的类注册的快捷方式之前。
/// \c forObject:rows: 根本不使用已注册的快捷方式。
+ (instancetype)forObject:(id)objectOrClass additionalRows:(nullable NSArray *)rows;

/// 使用对象类的已注册快捷方式调用 \c forObject:rows:。
/// @return 如果对象根本没有注册快捷方式，则返回空区段。
+ (instancetype)forObject:(id)objectOrClass;

/// 子类\e 可以重写这个方法来隐藏某些行的
/// 信息指示器。默认情况下它对所有行都显示，
/// 除非您使用 \c forObject:rowTitles:rowSubtitles: 初始化它。
///
/// 当您隐藏信息指示器时，该行不可选择。
- (UITableViewCellAccessoryType)accessoryTypeForRow:(NSInteger)row;

/// 标题和副标题标签的行数。默认为1。
@property (nonatomic, readonly) NSInteger numberOfLines;
/// 用于初始化此区段的对象。
@property (nonatomic, readonly) id object;

/// 是否应该在配置单元格时始终计算动态副标题。
/// 默认为 NO。对显式传递的静态副标题没有影响。
@property (nonatomic) BOOL cacheSubtitles;

/// 此快捷方式区段是否覆盖默认区段。
/// 子类不应重写此方法。要在默认快捷方式区段旁边
/// 提供第二个区段，请使用 \c forObject:rows:
/// @return 如果使用 \c forObject: 或 \c forObject:additionalRows: 初始化，则为 \c NO
@property (nonatomic, readonly) BOOL isNewSection;

@end

@class FLEXShortcutsFactory;
typedef FLEXShortcutsFactory *_Nonnull(^FLEXShortcutsFactoryNames)(NSArray *names);
typedef void (^FLEXShortcutsFactoryTarget)(Class targetClass);

/// 下面的块属性的使用方式类似于 SnapKit 或 Masonry。
/// \c FLEXShortcutsSection.append.properties(@[@"frame",@"bounds"]).forClass(UIView.class);
///
/// 要在启动时安全地注册您自己的类，请子类化此类，
/// 重写 \c +load，并在 \c self 上调用适当的方法
@interface FLEXShortcutsFactory : NSObject

/// 按此顺序返回给定对象的所有已注册快捷方式列表：
/// 属性、实例变量、方法。
///
/// 此方法遍历对象的类层次结构，直到找到
/// 已注册的内容。这允许您在类层次结构的
/// 不同部分为同一对象显示不同的快捷方式。
///
/// 例如，UIView 可能已注册了一个 -layer 快捷方式。但如果
/// 您正在检查一个 UIControl，您可能不关心 layer 或其他
/// UIView 特定的东西；您可能更想看到为此控件注册的
/// 目标-操作，因此您会将该属性或实例变量注册到 UIControl，
/// 您仍然可以通过点击资源管理器视图控制器屏幕顶部的
/// UIView "镜头"来查看 UIView 注册的快捷方式。
+ (NSArray *)shortcutsForObjectOrClass:(id)objectOrClass;

@property (nonatomic, readonly, class) FLEXShortcutsFactory *append;
@property (nonatomic, readonly, class) FLEXShortcutsFactory *prepend;
@property (nonatomic, readonly, class) FLEXShortcutsFactory *replace;

@property (nonatomic, readonly) FLEXShortcutsFactoryNames properties;
/// 不要尝试同时设置 \c classProperties 和 \c ivars 或其他实例内容。
@property (nonatomic, readonly) FLEXShortcutsFactoryNames classProperties;
@property (nonatomic, readonly) FLEXShortcutsFactoryNames ivars;
@property (nonatomic, readonly) FLEXShortcutsFactoryNames methods;
/// 不要尝试同时设置 \c classMethods 和 \c ivars 或其他实例内容。
@property (nonatomic, readonly) FLEXShortcutsFactoryNames classMethods;

/// 接受目标类。如果您传递一个普通类对象，
/// 快捷方式将出现在实例上。如果您传递一个元类对象，
/// 快捷方式将在探索类对象时出现。
///
/// 例如，默认情况下，一些类方法快捷方式被添加到 NSObject 元
/// 类，以便您可以在探索类对象时看到 +alloc 和 +new。
/// 如果您希望这些在探索实例时显示，您可以将它们
/// 传递给上面的 classMethods 方法。
@property (nonatomic, readonly) FLEXShortcutsFactoryTarget forClass;

@end

NS_ASSUME_NONNULL_END
