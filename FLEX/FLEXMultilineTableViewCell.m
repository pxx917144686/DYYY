// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXMultilineTableViewCell.m
//  FLEX
//
//  由 Ryan Olson 创建于 2/13/15.
//  版权所有 (c) 2020 FLEX Team。保留所有权利。
//

#import "FLEXMultilineTableViewCell.h"
#import "UIView+FLEX_Layout.h"
#import "FLEXUtility.h"

@interface FLEXMultilineTableViewCell ()
@property (nonatomic, readonly) UILabel *_titleLabel;
@property (nonatomic, readonly) UILabel *_subtitleLabel;
@property (nonatomic) BOOL constraintsUpdated;
@end

@implementation FLEXMultilineTableViewCell

- (void)postInit {
    [super postInit];
    
    self.titleLabel.numberOfLines = 0;
    self.subtitleLabel.numberOfLines = 0;
}

+ (UIEdgeInsets)labelInsets {
    return UIEdgeInsetsMake(10.0, 16.0, 10.0, 8.0);
}

+ (CGFloat)preferredHeightWithAttributedText:(NSAttributedString *)attributedText
                                    maxWidth:(CGFloat)contentViewWidth
                                       style:(UITableViewStyle)style
                              showsAccessory:(BOOL)showsAccessory {
    CGFloat labelWidth = contentViewWidth;

    // 在 iOS 8.1 iPhone 6 上观察到的由于附件视图导致的 contentView 插入。
    if (showsAccessory) {
        labelWidth -= 34.0;
    }

    UIEdgeInsets labelInsets = [self labelInsets];
    labelWidth -= (labelInsets.left + labelInsets.right);

    CGSize constrainSize = CGSizeMake(labelWidth, CGFLOAT_MAX);
    CGRect boundingBox = [attributedText
        boundingRectWithSize:constrainSize
        options:NSStringDrawingUsesLineFragmentOrigin
        context:nil
    ];
    CGFloat preferredLabelHeight = FLEXFloor(boundingBox.size.height);
    CGFloat preferredCellHeight = preferredLabelHeight + labelInsets.top + labelInsets.bottom + 1.0;

    return preferredCellHeight;
}

@end


@implementation FLEXMultilineDetailTableViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    return [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdentifier];
}

@end
