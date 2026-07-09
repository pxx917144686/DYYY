//
//  DYYYFLEXExplorerToolbar.m
//  Flipboard
//
//  Created by Ryan Olson on 4/4/14.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

#import "DYYYFLEXColor.h"
#import "DYYYFLEXExplorerToolbar.h"
#import "DYYYFLEXExplorerToolbarItem.h"
#import "DYYYFLEXResources.h"
#import "DYYYFLEXUtility.h"

// x功能模块
#import "x/ClassDump/DYYYUCClassDumpTool.h"
#import "x/filza/DYYYUCFilzaTool.h"
#import "x/Decrypt/DYYYUCDecryptTool.h"
#import "x/AppProtection/DYYYUCAppProtectionTool.h"

@interface DYYYFLEXExplorerToolbar ()

@property (nonatomic, readwrite) DYYYFLEXExplorerToolbarItem *globalsItem;
@property (nonatomic, readwrite) DYYYFLEXExplorerToolbarItem *hierarchyItem;
@property (nonatomic, readwrite) DYYYFLEXExplorerToolbarItem *selectItem;
@property (nonatomic, readwrite) DYYYFLEXExplorerToolbarItem *recentItem;
@property (nonatomic, readwrite) DYYYFLEXExplorerToolbarItem *moveItem;
@property (nonatomic, readwrite) DYYYFLEXExplorerToolbarItem *closeItem;
@property (nonatomic, readwrite) UIView *dragHandle;

@property (nonatomic) UIImageView *dragHandleImageView;

@property (nonatomic) UIView *selectedViewDescriptionContainer;
@property (nonatomic) UIView *selectedViewDescriptionSafeAreaContainer;
@property (nonatomic) UIView *selectedViewColorIndicator;
@property (nonatomic) UILabel *selectedViewDescriptionLabel;

@property (nonatomic,readwrite) UIView *backgroundView;

// 第二行
@property (nonatomic, readwrite) UIView *secondRowDragHandle;
@property (nonatomic) UIImageView *secondRowDragHandleImageView;
@property (nonatomic, readwrite) DYYYFLEXExplorerToolbarItem *classdumpItem;
@property (nonatomic, readwrite) DYYYFLEXExplorerToolbarItem *disassemblerItem;
@property (nonatomic, readwrite) DYYYFLEXExplorerToolbarItem *decryptItem;
@property (nonatomic, readwrite) DYYYFLEXExplorerToolbarItem *filzaItem;
@property (nonatomic, readwrite) DYYYFLEXExplorerToolbarItem *protectionItem;
@property (nonatomic) UIView *secondRowBackground;

@end

@implementation DYYYFLEXExplorerToolbar

- (id)init {
    return [self initWithFrame:CGRectZero];
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // Background - 与原始FLEX一致
        self.backgroundView = [UIView new];
        self.backgroundView.backgroundColor = [DYYYFLEXColor secondaryBackgroundColorWithAlpha:0.95];
        [self addSubview:self.backgroundView];

        // Drag handle - 第一行
        self.dragHandle = [UIView new];
        self.dragHandle.backgroundColor = UIColor.clearColor;
        self.dragHandleImageView = [[UIImageView alloc] initWithImage:DYYYFLEXResources.dragHandle];
        self.dragHandleImageView.tintColor = [DYYYFLEXColor.iconColor colorWithAlphaComponent:0.666];
        [self.dragHandle addSubview:self.dragHandleImageView];
        [self addSubview:self.dragHandle];
        
        // Buttons - 第一行（最近和移动是独立的两个按钮）
        self.globalsItem   = [DYYYFLEXExplorerToolbarItem itemWithTitle:@"菜单" image:DYYYFLEXResources.globalsIcon];
        self.hierarchyItem = [DYYYFLEXExplorerToolbarItem itemWithTitle:@"视图" image:DYYYFLEXResources.hierarchyIcon];
        self.selectItem    = [DYYYFLEXExplorerToolbarItem itemWithTitle:@"选择" image:DYYYFLEXResources.selectIcon];
        self.recentItem    = [DYYYFLEXExplorerToolbarItem itemWithTitle:@"最近" image:DYYYFLEXResources.recentIcon];
        self.moveItem      = [DYYYFLEXExplorerToolbarItem itemWithTitle:@"移动" image:DYYYFLEXResources.moveIcon];
        self.closeItem     = [DYYYFLEXExplorerToolbarItem itemWithTitle:@"关闭" image:DYYYFLEXResources.closeIcon];
        
        // 第二行 Drag handle - 先添加到底层
        self.secondRowDragHandle = [UIView new];
        self.secondRowDragHandle.backgroundColor = UIColor.clearColor;
        self.secondRowDragHandleImageView = [[UIImageView alloc] initWithImage:DYYYFLEXResources.dragHandle];
        self.secondRowDragHandleImageView.tintColor = [DYYYFLEXColor.iconColor colorWithAlphaComponent:0.666];
        [self.secondRowDragHandle addSubview:self.secondRowDragHandleImageView];
        
        // 第二行背景 - 包含 dragHandle 和按钮
        self.secondRowBackground = [[UIView alloc] init];
        self.secondRowBackground.backgroundColor = [DYYYFLEXColor secondaryBackgroundColorWithAlpha:0.95];
        [self.secondRowBackground addSubview:self.secondRowDragHandle];
        [self addSubview:self.secondRowBackground];
        
        // Buttons - 第二行
        self.classdumpItem  = [DYYYFLEXExplorerToolbarItem itemWithTitle:@"xx.h" image:[UIImage systemImageNamed:@"doc.text.fill"]];
        self.disassemblerItem = [DYYYFLEXExplorerToolbarItem itemWithTitle:@"反汇编" image:[UIImage systemImageNamed:@"cpu.fill"]];
        self.decryptItem    = [DYYYFLEXExplorerToolbarItem itemWithTitle:@"抓取" image:[UIImage systemImageNamed:@"lock.open.fill"]];
        self.filzaItem      = [DYYYFLEXExplorerToolbarItem itemWithTitle:@"Filza" image:[UIImage systemImageNamed:@"folder.fill"]];
        self.protectionItem = [DYYYFLEXExplorerToolbarItem itemWithTitle:@"保护" image:[UIImage systemImageNamed:@"shield.fill"]];
        // 第二行最后一个位置用空白占位，不放按钮

        // Selected view box //
        
        self.selectedViewDescriptionContainer = [UIView new];
        self.selectedViewDescriptionContainer.backgroundColor = [DYYYFLEXColor tertiaryBackgroundColorWithAlpha:0.95];
        self.selectedViewDescriptionContainer.hidden = YES;
        [self addSubview:self.selectedViewDescriptionContainer];

        self.selectedViewDescriptionSafeAreaContainer = [UIView new];
        self.selectedViewDescriptionSafeAreaContainer.backgroundColor = UIColor.clearColor;
        [self.selectedViewDescriptionContainer addSubview:self.selectedViewDescriptionSafeAreaContainer];
        
        self.selectedViewColorIndicator = [UIView new];
        self.selectedViewColorIndicator.backgroundColor = UIColor.redColor;
        [self.selectedViewDescriptionSafeAreaContainer addSubview:self.selectedViewColorIndicator];
        
        self.selectedViewDescriptionLabel = [UILabel new];
        self.selectedViewDescriptionLabel.backgroundColor = UIColor.clearColor;
        self.selectedViewDescriptionLabel.font = [[self class] descriptionLabelFont];
        [self.selectedViewDescriptionSafeAreaContainer addSubview:self.selectedViewDescriptionLabel];
        
        // toolbarItems - 第一行（6个按钮：菜单、视图、选择、最近、移动、关闭）
        self.toolbarItems = @[_globalsItem, _hierarchyItem, _selectItem, _recentItem, _moveItem, _closeItem];
        
        // secondRowItems - 第二行（6个按钮+空白=7列）
        self.secondRowItems = @[_classdumpItem, _disassemblerItem, _decryptItem, _filzaItem, _protectionItem];
    }

    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];


    CGRect safeArea = [self safeArea];
    const CGFloat kToolbarItemHeight = [[self class] toolbarItemHeight];
    CGFloat totalWidth = CGRectGetWidth(safeArea);
    
    // 7列布局：dragHandle | 6个按钮（所有列宽度相同）
    const NSInteger kTotalColumns = 7;
    CGFloat columnWidth = FLEXFloor(totalWidth / kTotalColumns);
    
    // 第一行 Drag Handle
    self.dragHandle.frame = CGRectMake(0, 0, columnWidth, kToolbarItemHeight);
    CGRect dragHandleImageFrame = self.dragHandleImageView.frame;
    dragHandleImageFrame.origin.x = FLEXFloor((columnWidth - dragHandleImageFrame.size.width) / 2.0);
    dragHandleImageFrame.origin.y = FLEXFloor((kToolbarItemHeight - dragHandleImageFrame.size.height) / 2.0);
    self.dragHandleImageView.frame = dragHandleImageFrame;
    
    // 第一行按钮
    CGFloat originX = columnWidth;
    CGFloat originY = 0;
    CGFloat height = kToolbarItemHeight;
    
    for (NSInteger i = 0; i < self.toolbarItems.count; i++) {
        DYYYFLEXExplorerToolbarItem *toolbarItem = self.toolbarItems[i];
        toolbarItem.currentItem.frame = CGRectMake(originX, originY, columnWidth, height);
        originX += columnWidth;
    }
    
    self.backgroundView.frame = CGRectMake(0, 0, totalWidth, kToolbarItemHeight);
    
    // 第二行背景
    CGFloat secondRowY = kToolbarItemHeight;
    self.secondRowBackground.frame = CGRectMake(0, secondRowY, totalWidth, kToolbarItemHeight);
    
    // 第二行 Drag Handle (在secondRowBackground坐标系中)
    self.secondRowDragHandle.frame = CGRectMake(0, 0, columnWidth, kToolbarItemHeight);
    CGRect secondRowDragHandleImageFrame = self.secondRowDragHandleImageView.frame;
    secondRowDragHandleImageFrame.origin.x = FLEXFloor((columnWidth - secondRowDragHandleImageFrame.size.width) / 2.0);
    secondRowDragHandleImageFrame.origin.y = FLEXFloor((kToolbarItemHeight - secondRowDragHandleImageFrame.size.height) / 2.0);
    self.secondRowDragHandleImageView.frame = secondRowDragHandleImageFrame;
    
    // 第二行按钮（在secondRowBackground坐标系中，dragHandle之后）
    // 注意：按钮已经在setSecondRowItems中添加到secondRowBackground，这里只更新frame
    originX = columnWidth;
    for (NSInteger i = 0; i < self.secondRowItems.count; i++) {
        DYYYFLEXExplorerToolbarItem *toolbarItem = self.secondRowItems[i];
        toolbarItem.currentItem.frame = CGRectMake(originX, 0, columnWidth, height);
        originX += columnWidth;
    }
    
    const CGFloat kSelectedViewColorDiameter = [[self class] selectedViewColorIndicatorDiameter];
    const CGFloat kDescriptionLabelHeight = [[self class] descriptionLabelHeight];
    const CGFloat kHorizontalPadding = [[self class] horizontalPadding];
    const CGFloat kDescriptionVerticalPadding = [[self class] descriptionVerticalPadding];
    const CGFloat kDescriptionContainerHeight = [[self class] descriptionContainerHeight];
    
    CGFloat bottomY = kToolbarItemHeight * 2;
    
    CGRect descriptionContainerFrame = CGRectZero;
    descriptionContainerFrame.size.width = CGRectGetWidth(self.bounds);
    descriptionContainerFrame.size.height = kDescriptionContainerHeight;
    descriptionContainerFrame.origin.x = CGRectGetMinX(self.bounds);
    descriptionContainerFrame.origin.y = kToolbarItemHeight * 2;
    self.selectedViewDescriptionContainer.frame = descriptionContainerFrame;

    CGRect descriptionSafeAreaContainerFrame = CGRectZero;
    descriptionSafeAreaContainerFrame.size.width = CGRectGetWidth(safeArea);
    descriptionSafeAreaContainerFrame.size.height = kDescriptionContainerHeight;
    descriptionSafeAreaContainerFrame.origin.x = CGRectGetMinX(safeArea) - CGRectGetMinX(self.bounds);
    descriptionSafeAreaContainerFrame.origin.y = 0;
    self.selectedViewDescriptionSafeAreaContainer.frame = descriptionSafeAreaContainerFrame;

    // Selected View Color
    CGRect selectedViewColorFrame = CGRectZero;
    selectedViewColorFrame.size.width = kSelectedViewColorDiameter;
    selectedViewColorFrame.size.height = kSelectedViewColorDiameter;
    selectedViewColorFrame.origin.x = kHorizontalPadding;
    selectedViewColorFrame.origin.y = FLEXFloor((kDescriptionContainerHeight - kSelectedViewColorDiameter) / 2.0);
    self.selectedViewColorIndicator.frame = selectedViewColorFrame;
    self.selectedViewColorIndicator.layer.cornerRadius = ceil(selectedViewColorFrame.size.height / 2.0);
    
    // Selected View Description
    CGRect descriptionLabelFrame = CGRectZero;
    CGFloat descriptionOriginX = CGRectGetMaxX(selectedViewColorFrame) + kHorizontalPadding;
    descriptionLabelFrame.size.height = kDescriptionLabelHeight;
    descriptionLabelFrame.origin.x = descriptionOriginX;
    descriptionLabelFrame.origin.y = kDescriptionVerticalPadding;
    descriptionLabelFrame.size.width = CGRectGetMaxX(self.selectedViewDescriptionContainer.bounds) - kHorizontalPadding - descriptionOriginX;
    self.selectedViewDescriptionLabel.frame = descriptionLabelFrame;
}


#pragma mark - Setter Overrides

- (void)setToolbarItems:(NSArray<DYYYFLEXExplorerToolbarItem *> *)toolbarItems {
    if (_toolbarItems == toolbarItems) {
        return;
    }
    
    for (DYYYFLEXExplorerToolbarItem *item in _toolbarItems) {
        [item.currentItem removeFromSuperview];
    }
    
    // 第一行有6个按钮：菜单、视图、选择、最近、移动、关闭
    if (toolbarItems.count > 6) {
        toolbarItems = [toolbarItems subarrayWithRange:NSMakeRange(0, 6)];
    }

    for (DYYYFLEXExplorerToolbarItem *item in toolbarItems) {
        [self addSubview:item.currentItem];
    }

    _toolbarItems = toolbarItems.copy;

    [self setNeedsLayout];
    [self layoutIfNeeded];
}

- (void)setSecondRowItems:(NSArray<DYYYFLEXExplorerToolbarItem *> *)secondRowItems {
    if (_secondRowItems == secondRowItems) {
        return;
    }
    
    for (DYYYFLEXExplorerToolbarItem *item in _secondRowItems) {
        [item.currentItem removeFromSuperview];
    }
    
    if (secondRowItems.count > 6) {
        secondRowItems = [secondRowItems subarrayWithRange:NSMakeRange(0, 6)];
    }
    
    for (DYYYFLEXExplorerToolbarItem *item in secondRowItems) {
        [self.secondRowBackground addSubview:item.currentItem];
    }
    
    _secondRowItems = secondRowItems.copy;
    [self setNeedsLayout];
}

- (void)setSelectedViewOverlayColor:(UIColor *)selectedViewOverlayColor {
    if (![_selectedViewOverlayColor isEqual:selectedViewOverlayColor]) {
        _selectedViewOverlayColor = selectedViewOverlayColor;
        self.selectedViewColorIndicator.backgroundColor = selectedViewOverlayColor;
    }
}

- (void)setSelectedViewDescription:(NSString *)selectedViewDescription {
    if (![_selectedViewDescription isEqualToString:selectedViewDescription]) {
        _selectedViewDescription = selectedViewDescription;
        self.selectedViewDescriptionLabel.text = selectedViewDescription;
        BOOL showDescription = selectedViewDescription.length > 0;
        self.selectedViewDescriptionContainer.hidden = !showDescription;
    }
}


#pragma mark - Sizing Convenience Methods

+ (UIFont *)descriptionLabelFont {
    return [UIFont systemFontOfSize:12.0];
}

+ (CGFloat)toolbarItemHeight {
    return 44.0;
}

+ (CGFloat)dragHandleWidth {
    return DYYYFLEXResources.dragHandle.size.width;
}

+ (CGFloat)descriptionLabelHeight {
    return ceil([[self descriptionLabelFont] lineHeight]);
}

+ (CGFloat)descriptionVerticalPadding {
    return 2.0;
}

+ (CGFloat)descriptionContainerHeight {
    return [self descriptionVerticalPadding] * 2.0 + [self descriptionLabelHeight];
}

+ (CGFloat)selectedViewColorIndicatorDiameter {
    return ceil([self descriptionLabelHeight] / 2.0);
}

+ (CGFloat)horizontalPadding {
    return 11.0;
}

- (CGSize)sizeThatFits:(CGSize)size {
    CGFloat height = 0.0;
    height += [[self class] toolbarItemHeight];
    height += [[self class] toolbarItemHeight];
    height += [[self class] descriptionContainerHeight];
    return CGSizeMake(size.width, height);
}

- (CGRect)safeArea {
    CGRect safeArea = self.bounds;
    if (@available(iOS 11.0, *)) {
        safeArea = UIEdgeInsetsInsetRect(self.bounds, self.safeAreaInsets);
    }

    return safeArea;
}

@end
