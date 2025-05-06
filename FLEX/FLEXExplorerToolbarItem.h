//
//  FLEXExplorerToolbarItem.h
//  Flipboard
//
//  创建者：Ryan Olson，日期：4/4/14.
//  版权所有 (c) 2020 FLEX Team。保留所有权利。
//
// 遇到问题联系中文翻译作者：pxx917144686

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface FLEXExplorerToolbarItem : UIButton

+ (instancetype)itemWithTitle:(NSString *)title image:(UIImage *)image;

/// @param backupItem 当此项目变为禁用状态时，用于替代此项目的工具栏项目。
/// 没有同级项目的项目在变为禁用状态时表现出预期的行为，并呈灰色显示。
+ (instancetype)itemWithTitle:(NSString *)title image:(UIImage *)image sibling:(nullable FLEXExplorerToolbarItem *)backupItem;

/// 如果工具栏项目有同级项目，则当其变为禁用状态时，该项目将用其同级项目替换自身，
/// 而当其变为启用状态时，则反之亦然。
@property (nonatomic, readonly) FLEXExplorerToolbarItem *sibling;

/// 当工具栏项目具有同级项目并且其变为禁用状态时，同级项目是
/// 应添加到新工具栏或从现有工具栏中移除的视图。此属性
/// 使程序员不必确定是使用 \c item 还是 \c item.sibling
/// 或 \c item.sibling.sibling 等等。是的，同级项目也可以有同级项目，以便
/// 每个变为禁用的项目都可以在其位置显示另一个项目，从而创建
/// 工具栏项目的“堆栈”。此行为对于制作在不同状态下
/// 占据相同空间的按钮非常有用。
///
/// 考虑到这一点，您永远不应直接访问存储的工具栏项目的视图属性，
/// 例如 \c frame 或 \c superview；您应该在 \c currentItem 上访问它们。
/// 如果您尝试修改项目的框架，并且项目本身当前未显示，
/// 而是显示其同级项目，则您的更改可能会被忽略。
///
/// @return 如果此项目具有同级项目并且此项目已禁用，则返回该项目的同级项目的 \c currentItem 的结果，
/// 否则返回此项目。
@property (nonatomic, readonly) FLEXExplorerToolbarItem *currentItem;

@end

NS_ASSUME_NONNULL_END
