// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXNetworkTransactionCell.m
//  Flipboard
//
//  Created by Ryan Olson on 2/8/15.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

#import "FLEXColor.h"
#import "FLEXNetworkTransactionCell.h"
#import "FLEXNetworkTransaction.h"
#import "FLEXUtility.h"
#import "FLEXResources.h"

NSString * const kFLEXNetworkTransactionCellIdentifier = @"kFLEXNetworkTransactionCellIdentifier";

@interface FLEXNetworkTransactionCell ()

@property (nonatomic) UIImageView *thumbnailImageView;
@property (nonatomic) UILabel *nameLabel;
@property (nonatomic) UILabel *pathLabel;
@property (nonatomic) UILabel *transactionDetailsLabel;

@end

@implementation FLEXNetworkTransactionCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

        self.nameLabel = [UILabel new];
        self.nameLabel.font = UIFont.flex_defaultTableCellFont;
        [self.contentView addSubview:self.nameLabel];

        self.pathLabel = [UILabel new];
        self.pathLabel.font = UIFont.flex_defaultTableCellFont;
        self.pathLabel.textColor = [UIColor colorWithWhite:0.4 alpha:1.0];
        self.pathLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
        [self.contentView addSubview:self.pathLabel];

        self.thumbnailImageView = [UIImageView new];
        self.thumbnailImageView.layer.borderColor = UIColor.blackColor.CGColor;
        self.thumbnailImageView.layer.borderWidth = 1.0;
        self.thumbnailImageView.contentMode = UIViewContentModeScaleAspectFit;
        [self.contentView addSubview:self.thumbnailImageView];

        self.transactionDetailsLabel = [UILabel new];
        self.transactionDetailsLabel.font = [UIFont systemFontOfSize:10.0];
        self.transactionDetailsLabel.textColor = [UIColor colorWithWhite:0.65 alpha:1.0];
        [self.contentView addSubview:self.transactionDetailsLabel];
    }
    return self;
}

- (void)setTransaction:(FLEXNetworkTransaction *)transaction {
    if (_transaction != transaction) {
        _transaction = transaction;
        [self setNeedsLayout];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];

    const CGFloat kVerticalPadding = 8.0;
    const CGFloat kLeftPadding = 10.0;
    const CGFloat kImageDimension = 32.0;

    CGFloat thumbnailOriginY = round((self.contentView.bounds.size.height - kImageDimension) / 2.0);
    self.thumbnailImageView.frame = CGRectMake(kLeftPadding, thumbnailOriginY, kImageDimension, kImageDimension);
    self.thumbnailImageView.image = self.transaction.thumbnail;

    CGFloat textOriginX = CGRectGetMaxX(self.thumbnailImageView.frame) + kLeftPadding;
    CGFloat availableTextWidth = self.contentView.bounds.size.width - textOriginX;

    self.nameLabel.text = [self nameLabelText];
    CGSize nameLabelPreferredSize = [self.nameLabel sizeThatFits:CGSizeMake(availableTextWidth, CGFLOAT_MAX)];
    self.nameLabel.frame = CGRectMake(textOriginX, kVerticalPadding, availableTextWidth, nameLabelPreferredSize.height);
    self.nameLabel.textColor = self.transaction.displayAsError ? UIColor.redColor : FLEXColor.primaryTextColor;

    self.pathLabel.text = [self pathLabelText];
    CGSize pathLabelPreferredSize = [self.pathLabel sizeThatFits:CGSizeMake(availableTextWidth, CGFLOAT_MAX)];
    CGFloat pathLabelOriginY = ceil((self.contentView.bounds.size.height - pathLabelPreferredSize.height) / 2.0);
    self.pathLabel.frame = CGRectMake(textOriginX, pathLabelOriginY, availableTextWidth, pathLabelPreferredSize.height);

    self.transactionDetailsLabel.text = [self transactionDetailsLabelText];
    CGSize transactionLabelPreferredSize = [self.transactionDetailsLabel sizeThatFits:CGSizeMake(availableTextWidth, CGFLOAT_MAX)];
    CGFloat transactionDetailsOriginX = textOriginX;
    CGFloat transactionDetailsLabelOriginY = CGRectGetMaxY(self.contentView.bounds) - kVerticalPadding - transactionLabelPreferredSize.height;
    CGFloat transactionDetailsLabelWidth = self.contentView.bounds.size.width - transactionDetailsOriginX;
    self.transactionDetailsLabel.frame = CGRectMake(transactionDetailsOriginX, transactionDetailsLabelOriginY, transactionDetailsLabelWidth, transactionLabelPreferredSize.height);
}

- (NSString *)nameLabelText {
    return self.transaction.primaryDescription;
}

- (NSString *)pathLabelText {
    return self.transaction.secondaryDescription;
}

- (NSString *)transactionDetailsLabelText {
    NSMutableArray<NSString *> *detailComponents = [NSMutableArray array];

    if (self.transaction.state == FLEXNetworkTransactionStateFinished || 
        self.transaction.state == FLEXNetworkTransactionStateFailed) {
        // 添加状态中文翻译
        if (self.transaction.state == FLEXNetworkTransactionStateFailed) {
            [detailComponents addObject:@"失败"];
        } else {
            [detailComponents addObject:@"完成"];  
        }
        // 修改为先判断是否为 NSHTTPURLResponse 类型
        NSString *statusCodeString = @"";
        if ([self.transaction.response isKindOfClass:[NSHTTPURLResponse class]]) {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)self.transaction.response;
            statusCodeString = [NSString stringWithFormat:@"%@ %@",
                @(httpResponse.statusCode),
                [NSHTTPURLResponse localizedStringForStatusCode:httpResponse.statusCode]
            ];
        }
        [detailComponents addObject:statusCodeString];

    } else {
        // 其他状态翻译
        NSString *state = [self.class readableStringFromTransactionState:self.transaction.state];
        [detailComponents addObject:state];
    }
    return [detailComponents componentsJoinedByString:@" · "];
}

+ (CGFloat)preferredCellHeight {
    return 65.0;
}

+ (NSString *)reuseID {
    return kFLEXNetworkTransactionCellIdentifier;
}

@end
