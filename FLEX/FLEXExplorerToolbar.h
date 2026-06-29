//
//  FLEXExplorerToolbar.h
//  Flipboard
//
//  Created by Ryan Olson on 4/4/14.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

#import <UIKit/UIKit.h>

@class FLEXExplorerToolbarItem;

NS_ASSUME_NONNULL_BEGIN

/// Users of the toolbar can configure the enabled state
/// and event target/actions for each item.
@interface FLEXExplorerToolbar : UIView

/// The items to be displayed in the first row. Defaults to:
/// selectItem, moveItem, hierarchyItem, recentItem, globalsItem, closeItem
@property (nonatomic, copy) NSArray<FLEXExplorerToolbarItem *> *toolbarItems;

/// The items to be displayed in the second row (tool buttons).
@property (nonatomic, copy) NSArray<FLEXExplorerToolbarItem *> *secondRowItems;

/// Toolbar item for selecting views.
@property (nonatomic, readonly) FLEXExplorerToolbarItem *selectItem;

/// Toolbar item for presenting a list with the view hierarchy.
@property (nonatomic, readonly) FLEXExplorerToolbarItem *hierarchyItem;

/// Toolbar item for moving views.
@property (nonatomic, readonly) FLEXExplorerToolbarItem *moveItem;

/// Toolbar item for presenting the currently active tab.
@property (nonatomic, readonly) FLEXExplorerToolbarItem *recentItem;

/// Toolbar item for presenting a screen with various tools for inspecting the app.
@property (nonatomic, readonly) FLEXExplorerToolbarItem *globalsItem;

/// Toolbar item for hiding the explorer.
@property (nonatomic, readonly) FLEXExplorerToolbarItem *closeItem;

/// Toolbar item for class dump (xx.h).
@property (nonatomic, readonly) FLEXExplorerToolbarItem *classdumpItem;

/// Toolbar item for disassembler (反汇编).
@property (nonatomic, readonly) FLEXExplorerToolbarItem *disassemblerItem;

/// Toolbar item for decrypt/capture.
@property (nonatomic, readonly) FLEXExplorerToolbarItem *decryptItem;

/// Toolbar item for simulator.
@property (nonatomic, readonly) FLEXExplorerToolbarItem *simulatorItem;

/// Toolbar item for filza file browser.
@property (nonatomic, readonly) FLEXExplorerToolbarItem *filzaItem;

/// Toolbar item for app protection.
@property (nonatomic, readonly) FLEXExplorerToolbarItem *protectionItem;

/// A view for moving the entire toolbar.
@property (nonatomic, readonly) UIView *dragHandle;

/// A view for moving the entire toolbar (second row).
@property (nonatomic, readonly) UIView *secondRowDragHandle;

/// A color matching the overlay on color on the selected view.
@property (nonatomic) UIColor *selectedViewOverlayColor;

/// Description text for the selected view displayed below the toolbar items.
@property (nonatomic, copy) NSString *selectedViewDescription;

/// Area where details of the selected view are shown.
@property (nonatomic, readonly) UIView *selectedViewDescriptionContainer;

@end

NS_ASSUME_NONNULL_END
