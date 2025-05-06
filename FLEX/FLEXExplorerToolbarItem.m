//
//  FLEXExplorerToolbarItem.m
//  Flipboard
//
//  创建者：Ryan Olson，日期：4/4/14.
//  版权所有 (c) 2020 FLEX Team。保留所有权利。
//
// 遇到问题联系中文翻译作者：pxx917144686

#import "FLEXColor.h"
#import "FLEXExplorerToolbarItem.h"
#import "FLEXUtility.h"

@interface FLEXExplorerToolbarItem ()

@property (nonatomic) FLEXExplorerToolbarItem *sibling;
@property (nonatomic, copy) NSString *title;
@property (nonatomic) UIImage *image;

@property (nonatomic, readonly, class) UIColor *defaultBackgroundColor;
@property (nonatomic, readonly, class) UIColor *highlightedBackgroundColor;
@property (nonatomic, readonly, class) UIColor *selectedBackgroundColor;

@end

@implementation FLEXExplorerToolbarItem

#pragma mark - Public // 公共方法

+ (instancetype)itemWithTitle:(NSString *)title image:(UIImage *)image {
    return [self itemWithTitle:title image:image sibling:nil];
}

+ (instancetype)itemWithTitle:(NSString *)title image:(UIImage *)image sibling:(FLEXExplorerToolbarItem *)backupItem {
    NSParameterAssert(title); NSParameterAssert(image);
    
    FLEXExplorerToolbarItem *toolbarItem = [self buttonWithType:UIButtonTypeCustom];
    toolbarItem.sibling = backupItem;
    toolbarItem.title = title;
    toolbarItem.image = image;
    toolbarItem.tintColor = FLEXColor.iconColor;
    toolbarItem.backgroundColor = self.defaultBackgroundColor;
    toolbarItem.titleLabel.font = [UIFont systemFontOfSize:12.0];
    [toolbarItem setTitle:title forState:UIControlStateNormal];
    [toolbarItem setImage:image forState:UIControlStateNormal];
    [toolbarItem setTitleColor:FLEXColor.primaryTextColor forState:UIControlStateNormal];
    [toolbarItem setTitleColor:FLEXColor.deemphasizedTextColor forState:UIControlStateDisabled];
    return toolbarItem;
}

- (FLEXExplorerToolbarItem *)currentItem {
    if (!self.enabled && self.sibling) {
        return self.sibling.currentItem;
    }
    
    return self;
}


#pragma mark - Display Defaults // 显示默认值

+ (NSDictionary<NSString *, id> *)titleAttributes {
    return @{ NSFontAttributeName : [UIFont systemFontOfSize:12.0] };
}

+ (UIColor *)highlightedBackgroundColor {
    return FLEXColor.toolbarItemHighlightedColor;
}

+ (UIColor *)selectedBackgroundColor {
    return FLEXColor.toolbarItemSelectedColor;
}

+ (UIColor *)defaultBackgroundColor {
    return UIColor.clearColor;
}

+ (CGFloat)topMargin {
    return 2.0;
}


#pragma mark - State Changes // 状态变更

- (void)setHighlighted:(BOOL)highlighted {
    super.highlighted = highlighted;
    [self updateColors];
}

- (void)setSelected:(BOOL)selected {
    super.selected = selected;
    [self updateColors];
}

- (void)setEnabled:(BOOL)enabled {
    if (self.enabled != enabled) {
        if (self.sibling) {
            if (enabled) { // 用我自己替换同级项
                UIView *superview = self.sibling.superview;
                [self.sibling removeFromSuperview];
                self.frame = self.sibling.frame;
                [superview addSubview:self];
            } else { // 用同级项替换我自己
                UIView *superview = self.superview;
                [self removeFromSuperview];
                self.sibling.frame = self.frame;
                [superview addSubview:self.sibling];
            }
        }
        
        super.enabled = enabled;
    }
}

+ (id)_selectedIndicatorImage { return nil; }

- (void)updateColors {
    // 背景颜色
    if (self.highlighted) {
        self.backgroundColor = self.class.highlightedBackgroundColor;
    } else if (self.selected) {
        self.backgroundColor = self.class.selectedBackgroundColor;
    } else {
        self.backgroundColor = self.class.defaultBackgroundColor;
    }
}


#pragma mark - UIButton Layout Overrides // UIButton 布局覆盖

- (CGRect)titleRectForContentRect:(CGRect)contentRect {
    NSDictionary *attrs = [[self class] titleAttributes];
    // 底部对齐并居中。
    CGRect titleRect = CGRectZero;
    CGSize titleSize = [self.title boundingRectWithSize:contentRect.size
                                                options:0
                                             attributes:attrs
                                                context:nil].size;
    titleSize = CGSizeMake(ceil(titleSize.width), ceil(titleSize.height));
    titleRect.size = titleSize;
    titleRect.origin.y = contentRect.origin.y + CGRectGetMaxY(contentRect) - titleSize.height;
    titleRect.origin.x = contentRect.origin.x + FLEXFloor((contentRect.size.width - titleSize.width) / 2.0);
    return titleRect;
}

- (CGRect)imageRectForContentRect:(CGRect)contentRect {
    CGSize imageSize = self.image.size;
    CGRect titleRect = [self titleRectForContentRect:contentRect];
    CGFloat availableHeight = contentRect.size.height - titleRect.size.height - [[self class] topMargin];
    CGFloat originY = [[self class] topMargin] + FLEXFloor((availableHeight - imageSize.height) / 2.0);
    CGFloat originX = FLEXFloor((contentRect.size.width - imageSize.width) / 2.0);
    CGRect imageRect = CGRectMake(originX, originY, imageSize.width, imageSize.height);
    return imageRect;
}

@end
