//
//  DYYYFLEXFieldEditorView.m
//  Flipboard
//
//  Created by Ryan Olson on 5/16/14.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

#import "DYYYFLEXFieldEditorView.h"
#import "DYYYFLEXArgumentInputView.h"
#import "DYYYFLEXUtility.h"
#import "DYYYFLEXColor.h"

@interface DYYYFLEXFieldEditorView ()

@property (nonatomic) UILabel *targetDescriptionLabel;
@property (nonatomic) UIView *targetDescriptionDivider;
@property (nonatomic) UILabel *fieldDescriptionLabel;
@property (nonatomic) UIView *fieldDescriptionDivider;

@end

@implementation DYYYFLEXFieldEditorView

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.targetDescriptionLabel = [UILabel new];
        self.targetDescriptionLabel.numberOfLines = 0;
        self.targetDescriptionLabel.font = [[self class] labelFont];
        [self addSubview:self.targetDescriptionLabel];
        
        self.targetDescriptionDivider = [[self class] dividerView];
        [self addSubview:self.targetDescriptionDivider];
        
        self.fieldDescriptionLabel = [UILabel new];
        self.fieldDescriptionLabel.numberOfLines = 0;
        self.fieldDescriptionLabel.font = [[self class] labelFont];
        [self addSubview:self.fieldDescriptionLabel];
        
        self.fieldDescriptionDivider = [[self class] dividerView];
        [self addSubview:self.fieldDescriptionDivider];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    CGFloat horizontalPadding = [[self class] horizontalPadding];
    CGFloat verticalPadding = [[self class] verticalPadding];
    CGFloat dividerLineHeight = [[self class] dividerLineHeight];
    
    CGFloat originY = verticalPadding;
    CGFloat originX = horizontalPadding;
    CGFloat contentWidth = self.bounds.size.width - 2.0 * horizontalPadding;
    CGSize constrainSize = CGSizeMake(contentWidth, CGFLOAT_MAX);
    
    CGSize instanceDescriptionSize = [self.targetDescriptionLabel sizeThatFits:constrainSize];
    self.targetDescriptionLabel.frame = CGRectMake(originX, originY, instanceDescriptionSize.width, instanceDescriptionSize.height);
    originY = CGRectGetMaxY(self.targetDescriptionLabel.frame) + verticalPadding;
    
    self.targetDescriptionDivider.frame = CGRectMake(originX, originY, contentWidth, dividerLineHeight);
    originY = CGRectGetMaxY(self.targetDescriptionDivider.frame) + verticalPadding;
    
    CGSize fieldDescriptionSize = [self.fieldDescriptionLabel sizeThatFits:constrainSize];
    self.fieldDescriptionLabel.frame = CGRectMake(originX, originY, fieldDescriptionSize.width, fieldDescriptionSize.height);
    originY = CGRectGetMaxY(self.fieldDescriptionLabel.frame) + verticalPadding;
    
    self.fieldDescriptionDivider.frame = CGRectMake(originX, originY, contentWidth, dividerLineHeight);
    originY = CGRectGetMaxY(self.fieldDescriptionDivider.frame) + verticalPadding;

    for (UIView *argumentInputView in self.argumentInputViews) {
        CGSize inputViewSize = [argumentInputView sizeThatFits:constrainSize];
        argumentInputView.frame = CGRectMake(originX, originY, inputViewSize.width, inputViewSize.height);
        originY = CGRectGetMaxY(argumentInputView.frame) + verticalPadding;
    }
}

- (void)setBackgroundColor:(UIColor *)backgroundColor {
    [super setBackgroundColor:backgroundColor];
    self.targetDescriptionLabel.backgroundColor = backgroundColor;
    self.fieldDescriptionLabel.backgroundColor = backgroundColor;
}

- (void)setTargetDescription:(NSString *)targetDescription {
    if (![_targetDescription isEqual:targetDescription]) {
        _targetDescription = targetDescription;
        self.targetDescriptionLabel.text = targetDescription;
        [self setNeedsLayout];
    }
}

- (void)setFieldDescription:(NSString *)fieldDescription {
    if (![_fieldDescription isEqual:fieldDescription]) {
        _fieldDescription = fieldDescription;
        self.fieldDescriptionLabel.text = fieldDescription;
        [self setNeedsLayout];
    }
}

- (void)setArgumentInputViews:(NSArray<DYYYFLEXArgumentInputView *> *)argumentInputViews {
    if (![_argumentInputViews isEqual:argumentInputViews]) {
        
        for (DYYYFLEXArgumentInputView *inputView in _argumentInputViews) {
            [inputView removeFromSuperview];
        }
        
        _argumentInputViews = argumentInputViews;
        
        for (DYYYFLEXArgumentInputView *newInputView in argumentInputViews) {
            [self addSubview:newInputView];
        }
        
        [self setNeedsLayout];
    }
}

+ (UIView *)dividerView {
    UIView *dividerView = [UIView new];
    dividerView.backgroundColor = [self dividerColor];
    return dividerView;
}

+ (UIColor *)dividerColor {
    return DYYYFLEXColor.tertiaryBackgroundColor;
}

+ (CGFloat)horizontalPadding {
    return 10.0;
}

+ (CGFloat)verticalPadding {
    return 20.0;
}

+ (UIFont *)labelFont {
    return [UIFont systemFontOfSize:14.0];
}

+ (CGFloat)dividerLineHeight {
    return 1.0;
}

- (CGSize)sizeThatFits:(CGSize)size {
    CGFloat horizontalPadding = [[self class] horizontalPadding];
    CGFloat verticalPadding = [[self class] verticalPadding];
    CGFloat dividerLineHeight = [[self class] dividerLineHeight];
    
    CGFloat height = 0;
    CGFloat availableWidth = size.width - 2.0 * horizontalPadding;
    CGSize constrainSize = CGSizeMake(availableWidth, CGFLOAT_MAX);
    
    height += verticalPadding;
    height += ceil([self.targetDescriptionLabel sizeThatFits:constrainSize].height);
    height += verticalPadding;
    height += dividerLineHeight;
    height += verticalPadding;
    height += ceil([self.fieldDescriptionLabel sizeThatFits:constrainSize].height);
    height += verticalPadding;
    height += dividerLineHeight;
    height += verticalPadding;
    
    for (DYYYFLEXArgumentInputView *inputView in self.argumentInputViews) {
        height += [inputView sizeThatFits:constrainSize].height;
        height += verticalPadding;
    }
    
    return CGSizeMake(size.width, height);
}

@end
