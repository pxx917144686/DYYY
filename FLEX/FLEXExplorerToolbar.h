//
//  FLEXExplorerToolbar.h
//  Flipboard
//
//  创建者：Ryan Olson，日期：4/4/14.
//  版权所有 (c) 2020 FLEX Team。保留所有权利。
//
// 遇到问题联系中文翻译作者：pxx917144686

#import <UIKit/UIKit.h>

@class FLEXExplorerToolbarItem;

NS_ASSUME_NONNULL_BEGIN

/// 工具栏的用户可以为每个项目配置启用状态和事件目标/操作。
@interface FLEXExplorerToolbar : UIView

/// 要在工具栏中显示的项目。默认为：
/// globalsItem, hierarchyItem, selectItem, moveItem, closeItem
@property (nonatomic, copy) NSArray<FLEXExplorerToolbarItem *> *toolbarItems;

/// 用于选择视图的工具栏项目。
@property (nonatomic, readonly) FLEXExplorerToolbarItem *selectItem;

/// 用于显示视图层级列表的工具栏项目。
@property (nonatomic, readonly) FLEXExplorerToolbarItem *hierarchyItem;

/// 用于移动视图的工具栏项目。
/// 它的 \c sibling 是 \c lastTabItem
@property (nonatomic, readonly) FLEXExplorerToolbarItem *moveItem;

/// 用于显示当前活动选项卡的工具栏项目。
@property (nonatomic, readonly) FLEXExplorerToolbarItem *recentItem;

/// 用于显示包含各种应用程序检查工具的屏幕的工具栏项目。
@property (nonatomic, readonly) FLEXExplorerToolbarItem *globalsItem;

/// 用于隐藏浏览器的工具栏项目。
@property (nonatomic, readonly) FLEXExplorerToolbarItem *closeItem;

/// 用于移动整个工具栏的视图。
/// 工具栏的用户可以附加平移手势识别器来决定如何重新定位工具栏。
@property (nonatomic, readonly) UIView *dragHandle;

/// 与选定视图上的覆盖颜色匹配的颜色。
@property (nonatomic) UIColor *selectedViewOverlayColor;

/// 显示在工具栏项目下方的选定视图的描述文本。
@property (nonatomic, copy) NSString *selectedViewDescription;

/// 显示选定视图详细信息的区域
/// 工具栏的用户可以附加点击手势识别器以显示其他详细信息。
@property (nonatomic, readonly) UIView *selectedViewDescriptionContainer;

@end

NS_ASSUME_NONNULL_END
