// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXObjectExplorerViewController.h
//  Flipboard
//
//  由 Ryan Olson 创建于 2014-05-03.
//  版权所有 (c) 2020 FLEX Team。保留所有权利。
//

#ifndef _FLEXObjectExplorerViewController_h
#define _FLEXObjectExplorerViewController_h
#endif

#import "FLEXFilteringTableViewController.h"
#import "FLEXObjectExplorer.h"
@class FLEXTableViewSection;

NS_ASSUME_NONNULL_BEGIN

/// 一个显示对象或类信息的类。
///
/// 浏览器视图控制器使用 \c FLEXObjectExplorer 来提供对象的描述，
/// 并列出其属性、实例变量、方法及其超类。
/// 在描述下方和属性之前，会显示某些类（如 UIView）的一些快捷方式。
/// 在最底部，有一个选项可以查看发现引用正在浏览的对象的其他对象的列表。
@interface FLEXObjectExplorerViewController : FLEXFilteringTableViewController

/// 使用此对象的默认 \c FLEXShortcutsSection 作为自定义部分。
+ (instancetype)exploringObject:(id)objectOrClass;
/// 除非您提供一个，否则没有自定义部分。
+ (instancetype)exploringObject:(id)objectOrClass customSection:(nullable FLEXTableViewSection *)customSection;
/// 除非您提供一些，否则没有自定义部分。
+ (instancetype)exploringObject:(id)objectOrClass
                 customSections:(nullable NSArray<FLEXTableViewSection *> *)customSections;

/// 正在浏览的对象，可能是一个类的实例或类本身。
@property (nonatomic, readonly) id object;
/// 此对象为浏览器视图控制器提供对象的元数据。
@property (nonatomic, readonly) FLEXObjectExplorer *explorer;

/// 调用一次以初始化部分对象列表。
///
/// 子类可以重写此方法以添加、删除或重新排列浏览器的各个部分。
- (NSArray<FLEXTableViewSection *> *)makeSections;

/// 是否允许显示/深入查看实例变量和属性的当前值。默认为 YES。
@property (nonatomic, readonly) BOOL canHaveInstanceState;

/// 是否允许深入查看实例方法的方法调用界面。默认为 YES。
@property (nonatomic, readonly) BOOL canCallInstanceMethods;

/// 如果自定义部分数据使描述变得多余，子类可以选择隐藏它。默认为 YES。
@property (nonatomic, readonly) BOOL shouldShowDescription;

@end

NS_ASSUME_NONNULL_END
