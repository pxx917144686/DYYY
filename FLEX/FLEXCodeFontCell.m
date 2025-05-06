//
//  FLEXCodeFontCell.m
//  FLEX
//
//  创建者：Tanner，日期：12/27/19.
//  版权所有 © 2020 FLEX Team。保留所有权利。
//
// 遇到问题联系中文翻译作者：pxx917144686

#import "FLEXCodeFontCell.h"
#import "UIFont+FLEX.h"

@implementation FLEXCodeFontCell

- (void)postInit {
    [super postInit];
    
    self.titleLabel.font = UIFont.flex_codeFont;
    self.subtitleLabel.font = UIFont.flex_codeFont;

    self.titleLabel.adjustsFontSizeToFitWidth = YES;
    self.titleLabel.minimumScaleFactor = 0.9;
    self.subtitleLabel.adjustsFontSizeToFitWidth = YES;
    self.subtitleLabel.minimumScaleFactor = 0.75;
    
    // iOS 11 之前禁用多行
    if (@available(iOS 11, *)) {
        self.subtitleLabel.numberOfLines = 5;
    } else {
        self.titleLabel.numberOfLines = 1;
        self.subtitleLabel.numberOfLines = 1;
    }
}

@end
