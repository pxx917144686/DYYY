//
//  FLEXHierarchyTableViewCell.m
//  Flipboard
//
//  Created by Ryan Olson on 2014-05-02.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

#import "FLEXHierarchyTableViewCell.h"
#import "FLEXUtility.h"
#import "FLEXResources.h"
#import "FLEXColor.h"

@interface FLEXHierarchyTableViewCell ()

/// 指示视图在层次结构中的深度
@property (nonatomic) UIView *depthIndicatorView;
/// 持有视觉上区分不同视图的颜色
@property (nonatomic) UIImageView *colorCircleImageView;
/// 一个棋盘格模式的视图，用于帮助显示视图的颜色，类似于Photoshop画布
@property (nonatomic) UIView *backgroundColorCheckerPatternView;
/// 棋盘格模式视图的子视图，持有视图的实际颜色
@property (nonatomic) UIView *viewBackgroundColorView;

@end

@implementation FLEXHierarchyTableViewCell

- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier {
    return [self initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdentifier];
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.depthIndicatorView = [UIView new];
        self.depthIndicatorView.backgroundColor = FLEXUtility.hierarchyIndentPatternColor;
        [self.contentView addSubview:self.depthIndicatorView];
        
        UIImage *defaultCircleImage = [FLEXUtility circularImageWithColor:UIColor.blackColor radius:5];
        self.colorCircleImageView = [[UIImageView alloc] initWithImage:defaultCircleImage];
        [self.contentView addSubview:self.colorCircleImageView];
        
        self.textLabel.font = UIFont.flex_defaultTableCellFont;
        self.detailTextLabel.font = UIFont.flex_defaultTableCellFont;
        self.accessoryType = UITableViewCellAccessoryDetailButton;
        
        // 使用基于模式的颜色以简化棋盘格模式的应用
        static UIColor *checkerPatternColor = nil;
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            checkerPatternColor = [UIColor colorWithPatternImage:FLEXResources.checkerPattern];
        });
        
        self.backgroundColorCheckerPatternView = [UIView new];
        self.backgroundColorCheckerPatternView.clipsToBounds = YES;
        self.backgroundColorCheckerPatternView.layer.borderColor = FLEXColor.tertiaryBackgroundColor.CGColor;
        self.backgroundColorCheckerPatternView.layer.borderWidth = 2.f / UIScreen.mainScreen.scale;
        self.backgroundColorCheckerPatternView.backgroundColor = checkerPatternColor;
        [self.contentView addSubview:self.backgroundColorCheckerPatternView];
        self.viewBackgroundColorView = [UIView new];
        [self.backgroundColorCheckerPatternView addSubview:self.viewBackgroundColorView];
    }
    return self;
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    UIColor *originalColour = self.viewBackgroundColorView.backgroundColor;
    [super setHighlighted:highlighted animated:animated];
    
    // UITableViewCell 会将 contentView 中的所有子视图的背景色更改为 clearColor。
    // 我们希望在高亮显示时保留层次结构背景色。
    self.depthIndicatorView.backgroundColor = FLEXUtility.hierarchyIndentPatternColor;
    
    self.viewBackgroundColorView.backgroundColor = originalColour;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    UIColor *originalColour = self.viewBackgroundColorView.backgroundColor;
    [super setSelected:selected animated:animated];
    
    // 参见上面的 setHighlighted。
    self.depthIndicatorView.backgroundColor = FLEXUtility.hierarchyIndentPatternColor;
    
    self.viewBackgroundColorView.backgroundColor = originalColour;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    const CGFloat kContentPadding = 6;
    const CGFloat kDepthIndicatorWidthMultiplier = 4;
    const CGFloat kViewColorIndicatorSize = 22;
    
    const CGRect bounds = self.contentView.bounds;
    const CGFloat centerY = CGRectGetMidY(bounds);
    const CGFloat textLabelCenterY = CGRectGetMidY(self.textLabel.frame);
    
    BOOL hideCheckerView = self.backgroundColorCheckerPatternView.hidden;
    CGFloat maxWidth = CGRectGetMaxX(bounds);
    maxWidth -= (hideCheckerView ? kContentPadding : (kViewColorIndicatorSize + kContentPadding * 2));
    
    CGRect depthIndicatorFrame = self.depthIndicatorView.frame = CGRectMake(
        kContentPadding, 0, self.viewDepth * kDepthIndicatorWidthMultiplier, CGRectGetHeight(bounds)
    );
    
    // 圆圈在深度指示器后面，其中心Y = textLabel的中心Y
    CGRect circleFrame = self.colorCircleImageView.frame;
    circleFrame.origin.x = CGRectGetMaxX(depthIndicatorFrame) + kContentPadding;
    circleFrame.origin.y = FLEXFloor(textLabelCenterY - CGRectGetHeight(circleFrame) / 2.f);
    self.colorCircleImageView.frame = circleFrame;
    
    // 文本标签位于随机颜色圆圈之后，宽度延伸到
    // contentView的边缘或颜色指示器视图前的内边距
    CGRect textLabelFrame = self.textLabel.frame;
    CGFloat textOriginX = CGRectGetMaxX(circleFrame) + kContentPadding;
    textLabelFrame.origin.x = textOriginX;
    textLabelFrame.size.width = maxWidth - textOriginX;
    self.textLabel.frame = textLabelFrame;
    
    // detailTextLabel的前缘与圆圈对齐，
    // 宽度延伸到与textLabel相同的最大X
    CGRect detailTextLabelFrame = self.detailTextLabel.frame;
    CGFloat detailOriginX = circleFrame.origin.x;
    detailTextLabelFrame.origin.x = detailOriginX;
    detailTextLabelFrame.size.width = maxWidth - detailOriginX;
    self.detailTextLabel.frame = detailTextLabelFrame;
    
    // 棋盘格模式视图从textLabel的最大X之后的内边距开始，
    // 并在整个contentView内垂直居中
    self.backgroundColorCheckerPatternView.frame = CGRectMake(
        CGRectGetMaxX(self.textLabel.frame) + kContentPadding,
        centerY - kViewColorIndicatorSize / 2.f,
        kViewColorIndicatorSize,
        kViewColorIndicatorSize
    );
    
    // 背景色视图填充其父视图
    self.viewBackgroundColorView.frame = self.backgroundColorCheckerPatternView.bounds;
    self.backgroundColorCheckerPatternView.layer.cornerRadius = kViewColorIndicatorSize / 2.f;
}

- (void)setRandomColorTag:(UIColor *)randomColorTag {
    if (![_randomColorTag isEqual:randomColorTag]) {
        _randomColorTag = randomColorTag;
        self.colorCircleImageView.image = [FLEXUtility circularImageWithColor:randomColorTag radius:6];
    }
}

- (void)setViewDepth:(NSInteger)viewDepth {
    if (_viewDepth != viewDepth) {
        _viewDepth = viewDepth;
        [self setNeedsLayout];
    }
}

- (UIColor *)indicatedViewColor {
    return self.viewBackgroundColorView.backgroundColor;
}

- (void)setIndicatedViewColor:(UIColor *)color {
    self.viewBackgroundColorView.backgroundColor = color;
    
    // 如果没有背景色，则隐藏棋盘格模式视图
    self.backgroundColorCheckerPatternView.hidden = color == nil;
    [self setNeedsLayout];
}

@end
