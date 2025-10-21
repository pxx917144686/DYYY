//
//  FLEXObjectExplorerViewController.h
//  Flipboard
//
//  Created by Ryan Olson on 2014-05-03.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
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
/// 探索器视图控制器使用 \c FLEXObjectExplorer 提供对象的描述，
/// 并列出它的属性、实例变量、方法及其父类。
/// 在描述下方和属性之前，某些类（如UIViews）会显示一些快捷方式。
/// 在最底部，有一个选项可以查看其他引用正在探索的对象的对象列表。
@interface FLEXObjectExplorerViewController : FLEXFilteringTableViewController

/// 为此对象使用默认的 \c FLEXShortcutsSection 作为自定义部分。
+ (instancetype)exploringObject:(id)objectOrClass;
/// 除非您提供自定义部分，否则没有自定义部分。
+ (instancetype)exploringObject:(id)objectOrClass customSection:(nullable FLEXTableViewSection *)customSection;
/// 除非您提供一些自定义部分，否则没有自定义部分。
+ (instancetype)exploringObject:(id)objectOrClass
                 customSections:(nullable NSArray<FLEXTableViewSection *> *)customSections;

/// 正在探索的对象，可能是类的实例或类本身。
@property (nonatomic, readonly) id object;
/// 该对象为探索器视图控制器提供对象的元数据。
@property (nonatomic, readonly) FLEXObjectExplorer *explorer;

/// 初始化部分对象列表时调用一次。
///
/// 子类可以重写此方法来添加、删除或重新排列探索器的部分。
- (NSArray<FLEXTableViewSection *> *)makeSections;

/// 是否允许显示/深入查看实例变量和属性的当前值。默认为YES。
@property (nonatomic, readonly) BOOL canHaveInstanceState;

/// 是否允许深入查看实例方法的方法调用接口。默认为YES。
@property (nonatomic, readonly) BOOL canCallInstanceMethods;

/// 如果自定义部分数据使描述变得多余，子类可以选择隐藏它。默认为YES。
@property (nonatomic, readonly) BOOL shouldShowDescription;

@end

NS_ASSUME_NONNULL_END
