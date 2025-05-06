//
//  FLEXCarouselCell.m
//  FLEX
//
//  创建者：Tanner Bennett，日期：7/17/19.
//  Copyright © 2020 FLEX Team. All rights reserved.
//
// 遇到问题联系中文翻译作者：pxx917144686

#import "FLEXCarouselCell.h"
#import "FLEXColor.h"
#import "UIView+FLEX_Layout.h"

@interface FLEXCarouselCell ()
@property (nonatomic, readonly) UILabel *titleLabel;
@property (nonatomic, readonly) UIView *selectionIndicatorStripe;
@property (nonatomic) BOOL constraintsInstalled;
@end

@implementation FLEXCarouselCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _titleLabel = [UILabel new];
        _selectionIndicatorStripe = [UIView new];

        self.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        self.selectionIndicatorStripe.backgroundColor = self.tintColor;
        if (@available(iOS 10, *)) {
            self.titleLabel.adjustsFontForContentSizeCategory = YES;
        }

        [self.contentView addSubview:self.titleLabel];
        [self.contentView addSubview:self.selectionIndicatorStripe];

        [self installConstraints];

        [self updateAppearance];
    }

    return self;
}

- (void)updateAppearance {
    self.selectionIndicatorStripe.hidden = !self.selected;

    if (self.selected) {
        self.titleLabel.textColor = self.tintColor;
    } else {
        self.titleLabel.textColor = FLEXColor.deemphasizedTextColor;
    }
}

#pragma mark Public // 公共方法

- (NSString *)title {
    return self.titleLabel.text;
}

- (void)setTitle:(NSString *)title {
    self.titleLabel.text = title;
    [self.titleLabel sizeToFit];
    [self setNeedsLayout];
}

#pragma mark Overrides // 覆盖方法

- (void)prepareForReuse {
    [super prepareForReuse];
    [self updateAppearance];
}

- (void)installConstraints {
    CGFloat stripeHeight = 2;

    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.selectionIndicatorStripe.translatesAutoresizingMaskIntoConstraints = NO;

    UIView *superview = self.contentView;
    [self.titleLabel flex_pinEdgesToSuperviewWithInsets:UIEdgeInsetsMake(10, 15, 8 + stripeHeight, 15)];

    [self.selectionIndicatorStripe.leadingAnchor constraintEqualToAnchor:superview.leadingAnchor].active = YES;
    [self.selectionIndicatorStripe.bottomAnchor constraintEqualToAnchor:superview.bottomAnchor].active = YES;
    [self.selectionIndicatorStripe.trailingAnchor constraintEqualToAnchor:superview.trailingAnchor].active = YES;
    [self.selectionIndicatorStripe.heightAnchor constraintEqualToConstant:stripeHeight].active = YES;
}

- (void)setSelected:(BOOL)selected {
    super.selected = selected;
    [self updateAppearance];
}

@end
