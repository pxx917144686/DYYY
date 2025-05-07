//
//  FLEXKeyboardToolbar.m
//  FLEX
//
//  Created by Tanner on 6/11/17.
//  Copyright © 2017 Tanner Bennett. All rights reserved.
//

// 遇到问题联系中文翻译作者：pxx917144686

#import "FLEXKeyboardToolbar.h"
#import "FLEXUtility.h"

#define kToolbarHeight 44
#define kButtonSpacing 6
#define kScrollViewHorizontalMargins 3

@interface FLEXKeyboardToolbar ()

/// 仿制工具栏的假顶部边框
@property (nonatomic) CALayer      *topBorder;
@property (nonatomic) UIView       *toolbarView;
@property (nonatomic) UIScrollView *scrollView;
@property (nonatomic) UIVisualEffectView *blurView;
/// 当外观设置为`default`时为YES
@property (nonatomic, readonly) BOOL useSystemAppearance;
/// 当当前特性集合设置为暗黑模式且\c useSystemAppearance为YES时为YES
@property (nonatomic, readonly) BOOL usingDarkMode;
@end

@implementation FLEXKeyboardToolbar

+ (instancetype)toolbarWithButtons:(NSArray *)buttons {
    return [[self alloc] initWithButtons:buttons];
}

- (id)initWithButtons:(NSArray *)buttons {
    self = [super initWithFrame:CGRectMake(0, 0, self.window.rootViewController.view.bounds.size.width, kToolbarHeight)];
    if (self) {
        _buttons = [buttons copy];
        
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        
        if (@available(iOS 13, *)) {
            self.appearance = UIKeyboardAppearanceDefault;
        } else {
            self.appearance = UIKeyboardAppearanceLight;
        }
    }
    
    return self;
}

- (void)setAppearance:(UIKeyboardAppearance)appearance {
    _appearance = appearance;
    
    // 如果工具栏存在则移除，因为它将在下面重新创建
    if (self.toolbarView) {
        [self.toolbarView removeFromSuperview];
    }
    
    [self addSubview:self.inputAccessoryView];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    // 布局顶部边框
    CGRect frame = _toolbarView.bounds;
    frame.size.height = 0.5;
    _topBorder.frame = frame;
    
    // 滚动视图 //
    
    frame = CGRectMake(0, 0, self.bounds.size.width, kToolbarHeight);
    CGSize contentSize = self.scrollView.contentSize;
    CGFloat scrollViewWidth = frame.size.width;
    
    // 如果我们的内容尺寸小于滚动视图，
    // 我们希望右对齐所有内容
    if (contentSize.width < scrollViewWidth) {
        // 计算内容尺寸与滚动视图尺寸的差异
        UIEdgeInsets insets = self.scrollView.contentInset;
        CGFloat margin = insets.left + insets.right;
        CGFloat difference = scrollViewWidth - contentSize.width - margin;
        // 更新内容尺寸为滚动视图的完整宽度
        contentSize.width += difference;
        self.scrollView.contentSize = contentSize;
        
        // 按上述差异偏移每个按钮
        // 使每个按钮右对齐显示
        for (UIView *button in self.scrollView.subviews) {
            CGRect f = button.frame;
            f.origin.x += difference;
            button.frame = f;
        }
    }
}

- (UIView *)inputAccessoryView {
    _topBorder       = [CALayer new];
    _topBorder.frame = CGRectMake(0.0, 0.0, self.bounds.size.width, 0.5);
    [self makeScrollView];
    
    UIColor *borderColor = nil, *backgroundColor = nil;
    UIColor *lightColor = [UIColor colorWithHue:216.0/360.0 saturation:0.05 brightness:0.85 alpha:1];
    UIColor *darkColor = [UIColor colorWithHue:220.0/360.0 saturation:0.07 brightness:0.16 alpha:1];
    
    switch (_appearance) {
        case UIKeyboardAppearanceDefault:
            if (@available(iOS 13, *)) {
                borderColor = UIColor.systemBackgroundColor;
                
                if (self.usingDarkMode) {
                    // style = UIBlurEffectStyleSystemThickMaterial;
                    backgroundColor = darkColor;
                } else {
                    // style = UIBlurEffectStyleSystemUltraThinMaterialLight;
                    backgroundColor = lightColor;
                }
                break;
            }
        case UIKeyboardAppearanceLight: {
            borderColor = UIColor.clearColor;
            backgroundColor = lightColor;
            break;
        }
        case UIKeyboardAppearanceDark: {
            borderColor = [UIColor colorWithWhite:0.100 alpha:1.000];
            backgroundColor = darkColor;
            break;
        }
    }
    
    self.toolbarView = [UIView new];
    [self.toolbarView addSubview:self.scrollView];
    [self.toolbarView.layer addSublayer:self.topBorder];
    self.toolbarView.frame = CGRectMake(0, 0, self.bounds.size.width, kToolbarHeight);
    self.toolbarView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    self.backgroundColor = backgroundColor;
    self.topBorder.backgroundColor = borderColor.CGColor;
    
    return self.toolbarView;
}

- (UIScrollView *)makeScrollView {
    UIScrollView *scrollView = [UIScrollView new];
    scrollView.backgroundColor  = UIColor.clearColor;
    scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    scrollView.contentInset     = UIEdgeInsetsMake(
        8.f, kScrollViewHorizontalMargins, 4.f, kScrollViewHorizontalMargins
    );
    scrollView.showsHorizontalScrollIndicator = NO;
    
    self.scrollView = scrollView;
    [self addButtons];
    
    return scrollView;
}

- (void)addButtons {
    NSUInteger originX = 0.f;
    
    CGRect originFrame;
    CGFloat top    = self.scrollView.contentInset.top;
    CGFloat bottom = self.scrollView.contentInset.bottom;
    
    for (FLEXKBToolbarButton *button in self.buttons) {
        button.appearance = self.appearance;
        
        originFrame             = button.frame;
        originFrame.origin.x    = originX;
        originFrame.origin.y    = 0.f;
        originFrame.size.height = kToolbarHeight - (top + bottom);
        button.frame            = originFrame;
        
        [self.scrollView addSubview:button];
        
        // originX跟踪下一个要添加的按钮的原点，
        // 所以在这个循环的每次迭代结束时，我们将其增加
        // 上一个按钮的大小加上一些间距
        originX += button.bounds.size.width + kButtonSpacing;
    }
    
    // 更新contentSize，
    // 设置为最后添加的按钮的最大x值
    CGSize contentSize = self.scrollView.contentSize;
    contentSize.width  = originX - kButtonSpacing;
    self.scrollView.contentSize = contentSize;
    
    // 需要可能的右对齐按钮
    [self setNeedsLayout];
}

- (void)setButtons:(NSArray<FLEXKBToolbarButton *> *)buttons {
    [_buttons makeObjectsPerformSelector:@selector(removeFromSuperview)];
    _buttons = buttons.copy;
    
    [self addButtons];
}

- (BOOL)useSystemAppearance {
    return self.appearance == UIKeyboardAppearanceDefault;
}

- (BOOL)usingDarkMode {
    if (@available(iOS 12, *)) {
        return self.useSystemAppearance && self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }
    
    return self.appearance == UIKeyboardAppearanceDark;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previous {
    if (@available(iOS 12, *)) {
        // 暗黑模式是否被切换？
        if (previous.userInterfaceStyle != self.traitCollection.userInterfaceStyle) {
            if (self.useSystemAppearance) {
                // 使用正确的颜色重新创建背景视图
                self.appearance = self.appearance;
            }
        }
    }
}

@end
