//
//  FLEXNetworkTransactionDetailController.m
//  Flipboard
//
//  Created by Ryan Olson on 2/10/15.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

// 遇到问题联系中文翻译作者：pxx917144686

#import "FLEXColor.h"
#import "FLEXHTTPTransactionDetailController.h"
#import "FLEXNetworkCurlLogger.h"
#import "FLEXNetworkRecorder.h"
#import "FLEXNetworkTransaction.h"
#import "FLEXWebViewController.h"
#import "FLEXImagePreviewViewController.h"
#import "FLEXMultilineTableViewCell.h"
#import "FLEXUtility.h"
#import "FLEXManager+Private.h"
#import "FLEXTableView.h"
#import "UIBarButtonItem+FLEX.h"
#import "NSDateFormatter+FLEX.h"

typedef UIViewController *(^FLEXNetworkDetailRowSelectionFuture)(void);

@interface FLEXNetworkDetailRow : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *detailText;
@property (nonatomic, copy) FLEXNetworkDetailRowSelectionFuture selectionFuture;
@end

@implementation FLEXNetworkDetailRow
@end

@interface FLEXNetworkDetailSection : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSArray<FLEXNetworkDetailRow *> *rows;
@end

@implementation FLEXNetworkDetailSection
@end

@interface FLEXHTTPTransactionDetailController ()

@property (nonatomic, readonly) FLEXHTTPTransaction *transaction;
@property (nonatomic, copy) NSArray<FLEXNetworkDetailSection *> *sections;

@end

@implementation FLEXHTTPTransactionDetailController

+ (instancetype)withTransaction:(FLEXHTTPTransaction *)transaction {
    FLEXHTTPTransactionDetailController *controller = [self new];
    controller.transaction = transaction;
    return controller;
}

- (instancetype)initWithStyle:(UITableViewStyle)style {
    // 强制使用分组样式
    return [super initWithStyle:UITableViewStyleGrouped];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [NSNotificationCenter.defaultCenter addObserver:self
        selector:@selector(handleTransactionUpdatedNotification:)
        name:kFLEXNetworkRecorderTransactionUpdatedNotification
        object:nil
    ];
    self.toolbarItems = @[
        UIBarButtonItem.flex_flexibleSpace,
        [UIBarButtonItem
            flex_itemWithTitle:@"复制cURL请求"
            target:self
            action:@selector(copyButtonPressed:)
        ]
    ];
    
    [self.tableView registerClass:[FLEXMultilineTableViewCell class] forCellReuseIdentifier:kFLEXMultilineCell];
}

- (void)setTransaction:(FLEXHTTPTransaction *)transaction {
    if (![_transaction isEqual:transaction]) {
        _transaction = transaction;
        self.title = [transaction.request.URL lastPathComponent];
        [self rebuildTableSections];
    }
}

- (void)setSections:(NSArray<FLEXNetworkDetailSection *> *)sections {
    if (![_sections isEqual:sections]) {
        _sections = [sections copy];
        [self.tableView reloadData];
    }
}

- (void)rebuildTableSections {
    NSMutableArray<FLEXNetworkDetailSection *> *sections = [NSMutableArray new];

    FLEXNetworkDetailSection *generalSection = [[self class] generalSectionForTransaction:self.transaction];
    if (generalSection.rows.count > 0) {
        [sections addObject:generalSection];
    }
    FLEXNetworkDetailSection *requestHeadersSection = [[self class] requestHeadersSectionForTransaction:self.transaction];
    if (requestHeadersSection.rows.count > 0) {
        [sections addObject:requestHeadersSection];
    }
    FLEXNetworkDetailSection *queryParametersSection = [[self class] queryParametersSectionForTransaction:self.transaction];
    if (queryParametersSection.rows.count > 0) {
        [sections addObject:queryParametersSection];
    }
    FLEXNetworkDetailSection *postBodySection = [[self class] postBodySectionForTransaction:self.transaction];
    if (postBodySection.rows.count > 0) {
        [sections addObject:postBodySection];
    }
    FLEXNetworkDetailSection *responseHeadersSection = [[self class] responseHeadersSectionForTransaction:self.transaction];
    if (responseHeadersSection.rows.count > 0) {
        [sections addObject:responseHeadersSection];
    }

    self.sections = sections;
}

- (void)handleTransactionUpdatedNotification:(NSNotification *)notification {
    FLEXNetworkTransaction *transaction = [[notification userInfo] objectForKey:kFLEXNetworkRecorderUserInfoTransactionKey];
    if (transaction == self.transaction) {
        [self rebuildTableSections];
    }
}

- (void)copyButtonPressed:(id)sender {
    [UIPasteboard.generalPasteboard setString:[FLEXNetworkCurlLogger curlCommandString:_transaction.request]];
    [FLEXAlert showAlert:@"已复制到剪贴板" message:@"cURL请求已复制到剪贴板" from:self];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    FLEXNetworkDetailSection *sectionModel = self.sections[section];
    return sectionModel.rows.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    FLEXNetworkDetailSection *sectionModel = self.sections[section];
    return sectionModel.title;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    FLEXMultilineTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kFLEXMultilineCell forIndexPath:indexPath];

    FLEXNetworkDetailRow *rowModel = [self rowModelAtIndexPath:indexPath];

    if ([rowModel.title isEqualToString:@"请求地址"]) {
        cell.textLabel.text = @"请求";
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@", self.transaction.request.HTTPMethod ?: @"GET", self.transaction.request.URL.absoluteString];
    } else if ([rowModel.title isEqualToString:@"响应大小"]) {
        cell.textLabel.text = @"响应";
        NSString *statusCodeString = @"";
        if ([self.transaction.response isKindOfClass:[NSHTTPURLResponse class]]) {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)self.transaction.response;
            cell.detailTextLabel.text = [NSHTTPURLResponse localizedStringForStatusCode:httpResponse.statusCode];
        } else {
            cell.detailTextLabel.text = @"N/A";
        }
    } else if ([rowModel.title isEqualToString:@"总持续时间"]) {
        cell.textLabel.text = @"持续时间";
        cell.detailTextLabel.text = [FLEXUtility stringFromRequestDuration:self.transaction.duration];
    } else if ([rowModel.title isEqualToString:@"请求体大小"]) {
        cell.textLabel.text = @"大小";
        cell.detailTextLabel.text = [NSByteCountFormatter stringFromByteCount:self.transaction.receivedDataLength countStyle:NSByteCountFormatterCountStyleBinary];
    } else if ([rowModel.title isEqualToString:@"内容类型"]) {
        cell.textLabel.text = @"MIME类型";
        cell.detailTextLabel.text = self.transaction.response.MIMEType;
    } else if ([rowModel.title isEqualToString:@"请求机制"]) {
        cell.textLabel.text = @"机制";
        cell.detailTextLabel.text = self.transaction.requestMechanism;
    } else if ([rowModel.title isEqualToString:@"请求头信息"]) {
        cell.textLabel.text = @"请求头";
    } else if ([rowModel.title isEqualToString:@"查询参数"]) {
        cell.textLabel.text = @"查询参数";
    } else if ([rowModel.title isEqualToString:@"Request Body Parameters"]) {
        cell.textLabel.text = @"POST数据体";
    } else if ([rowModel.title isEqualToString:@"Response Headers"]) {
        cell.textLabel.text = @"响应头";
    } else if ([rowModel.title isEqualToString:@"响应内容"]) {
        cell.textLabel.text = @"查看响应";
    } else if ([rowModel.title isEqualToString:@"复制URL"]) {
        cell.textLabel.text = @"复制URL";
    } else if ([rowModel.title isEqualToString:@"Copy curl"]) {
        cell.textLabel.text = @"复制cURL请求";
    } else if ([rowModel.title isEqualToString:@"共享事务"]) {
        cell.textLabel.text = @"共享事务";
    } else {
        cell.textLabel.text = rowModel.title;
        cell.detailTextLabel.text = rowModel.detailText;
    }

    cell.accessoryType = rowModel.selectionFuture ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
    cell.selectionStyle = rowModel.selectionFuture ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    FLEXNetworkDetailRow *rowModel = [self rowModelAtIndexPath:indexPath];

    UIViewController *viewController = nil;
    if (rowModel.selectionFuture) {
        viewController = rowModel.selectionFuture();
    }

    if ([viewController isKindOfClass:UIAlertController.class]) {
        [self presentViewController:viewController animated:YES completion:nil];
    } else if (viewController) {
        [self.navigationController pushViewController:viewController animated:YES];
    }

    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    FLEXNetworkDetailRow *row = [self rowModelAtIndexPath:indexPath];
    NSAttributedString *attributedText = [[self class] attributedTextForRow:row];
    BOOL showsAccessory = row.selectionFuture != nil;
    return [FLEXMultilineTableViewCell
        preferredHeightWithAttributedText:attributedText
        maxWidth:tableView.bounds.size.width
        style:tableView.style
        showsAccessory:showsAccessory
    ];
}

- (NSArray<NSString *> *)sectionIndexTitlesForTableView:(UITableView *)tableView {
    return [NSArray flex_forEachUpTo:self.sections.count map:^id(NSUInteger i) {
        return @"⦁";
    }];
}

- (FLEXNetworkDetailRow *)rowModelAtIndexPath:(NSIndexPath *)indexPath {
    FLEXNetworkDetailSection *sectionModel = self.sections[indexPath.section];
    return sectionModel.rows[indexPath.row];
}

#pragma mark - Cell Copying

- (BOOL)tableView:(UITableView *)tableView shouldShowMenuForRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (BOOL)tableView:(UITableView *)tableView canPerformAction:(SEL)action forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender {
    return action == @selector(copy:);
}

- (void)tableView:(UITableView *)tableView performAction:(SEL)action forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender {
    if (action == @selector(copy:)) {
        FLEXNetworkDetailRow *row = [self rowModelAtIndexPath:indexPath];
        UIPasteboard.generalPasteboard.string = row.detailText;
    }
}

- (UIContextMenuConfiguration *)tableView:(UITableView *)tableView contextMenuConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath point:(CGPoint)point __IOS_AVAILABLE(13.0) {
    return [UIContextMenuConfiguration
        configurationWithIdentifier:nil
        previewProvider:nil
        actionProvider:^UIMenu *(NSArray<UIMenuElement *> *suggestedActions) {
            UIAction *copy = [UIAction
                actionWithTitle:@"复制"
                image:nil
                identifier:nil
                handler:^(__kindof UIAction *action) {
                    FLEXNetworkDetailRow *row = [self rowModelAtIndexPath:indexPath];
                    UIPasteboard.generalPasteboard.string = row.detailText;
                }
            ];
            return [UIMenu
                menuWithTitle:@"" image:nil identifier:nil
                options:UIMenuOptionsDisplayInline
                children:@[copy]
            ];
        }
    ];
}

#pragma mark - View Configuration

+ (NSAttributedString *)attributedTextForRow:(FLEXNetworkDetailRow *)row {
    NSDictionary<NSString *, id> *titleAttributes = @{ NSFontAttributeName : [UIFont fontWithName:@"HelveticaNeue-Medium" size:12.0],
                                                       NSForegroundColorAttributeName : [UIColor colorWithWhite:0.5 alpha:1.0] };
    NSDictionary<NSString *, id> *detailAttributes = @{ NSFontAttributeName : UIFont.flex_defaultTableCellFont,
                                                        NSForegroundColorAttributeName : FLEXColor.primaryTextColor };

    NSString *title = [NSString stringWithFormat:@"%@: ", row.title];
    NSString *detailText = row.detailText ?: @"";
    NSMutableAttributedString *attributedText = [NSMutableAttributedString new];
    [attributedText appendAttributedString:[[NSAttributedString alloc] initWithString:title attributes:titleAttributes]];
    [attributedText appendAttributedString:[[NSAttributedString alloc] initWithString:detailText attributes:detailAttributes]];

    return attributedText;
}

#pragma mark - Table Data Generation

// 一般信息部分
+ (FLEXNetworkDetailSection *)generalSectionForTransaction:(FLEXHTTPTransaction *)transaction {
    NSMutableArray<FLEXNetworkDetailRow *> *rows = [NSMutableArray new];

    FLEXNetworkDetailRow *requestURLRow = [FLEXNetworkDetailRow new];
    requestURLRow.title = @"请求地址";
    requestURLRow.detailText = transaction.request.URL.absoluteString;

    FLEXNetworkDetailRow *requestMethodRow = [FLEXNetworkDetailRow new];
    requestMethodRow.title = @"请求方法";
    requestMethodRow.detailText = transaction.request.HTTPMethod;

    FLEXNetworkDetailRow *requestBodySizeRow = [FLEXNetworkDetailRow new];
    requestBodySizeRow.title = @"请求体大小";
    requestBodySizeRow.detailText = [NSByteCountFormatter 
        stringFromByteCount:transaction.cachedRequestBody.length 
        countStyle:NSByteCountFormatterCountStyleBinary
    ];

    // 响应相关
    FLEXNetworkDetailRow *responseSizeRow = [FLEXNetworkDetailRow new];
    responseSizeRow.title = @"响应大小";
    responseSizeRow.detailText = [NSByteCountFormatter 
        stringFromByteCount:transaction.receivedDataLength 
        countStyle:NSByteCountFormatterCountStyleBinary
    ];

    FLEXNetworkDetailRow *mimeTypeRow = [FLEXNetworkDetailRow new];
    mimeTypeRow.title = @"内容类型";
    mimeTypeRow.detailText = transaction.response.MIMEType;

    FLEXNetworkDetailRow *mechanismRow = [FLEXNetworkDetailRow new];
    mechanismRow.title = @"请求机制";
    mechanismRow.detailText = transaction.requestMechanism;

    // 错误信息
    if (transaction.error) {
        FLEXNetworkDetailRow *errorRow = [FLEXNetworkDetailRow new];
        errorRow.title = @"错误信息";
        errorRow.detailText = transaction.error.localizedDescription;
        [rows addObject:errorRow];
    }

    // 响应体相关
    FLEXNetworkDetailRow *responseBodyRow = [FLEXNetworkDetailRow new];
    responseBodyRow.title = @"响应内容";
    NSData *responseData = [FLEXNetworkRecorder.defaultRecorder 
        cachedResponseBodyForTransaction:transaction
    ];
    if (responseData.length > 0) {
        responseBodyRow.detailText = @"点击查看";
    } else {
        BOOL emptyResponse = transaction.receivedDataLength == 0;
        responseBodyRow.detailText = emptyResponse ? @"空响应" : @"未缓存";
    }
    [rows addObject:responseBodyRow];

    [rows addObject:requestURLRow];
    [rows addObject:requestMethodRow];
    [rows addObject:requestBodySizeRow];
    [rows addObject:responseSizeRow];
    [rows addObject:mimeTypeRow];
    [rows addObject:mechanismRow];
    [rows addObject:responseBodyRow];

    // 创建并返回 section
    FLEXNetworkDetailSection *section = [FLEXNetworkDetailSection new];
    section.title = @"常规信息";
    section.rows = rows;
    return section;
}

// 请求头部分 
+ (FLEXNetworkDetailSection *)requestHeadersSectionForTransaction:(FLEXHTTPTransaction *)transaction {
    FLEXNetworkDetailSection *section = [FLEXNetworkDetailSection new];
    section.title = @"请求头信息";
    section.rows = [self networkDetailRowsFromDictionary:transaction.request.allHTTPHeaderFields];
    return section;
}

// 查询参数部分
+ (FLEXNetworkDetailSection *)queryParametersSectionForTransaction:(FLEXHTTPTransaction *)transaction {
    FLEXNetworkDetailSection *section = [FLEXNetworkDetailSection new];
    section.title = @"查询参数";
    NSArray<NSURLQueryItem *> *queries = [FLEXUtility itemsFromQueryString:transaction.request.URL.query];
    section.rows = [self networkDetailRowsFromQueryItems:queries];
    return section;
}

+ (FLEXNetworkDetailSection *)postBodySectionForTransaction:(FLEXHTTPTransaction *)transaction {
    FLEXNetworkDetailSection *postBodySection = [FLEXNetworkDetailSection new];
    postBodySection.title = @"POST数据体";
    if (transaction.cachedRequestBody.length > 0) {
        NSString *contentType = [transaction.request valueForHTTPHeaderField:@"Content-Type"];
        if ([contentType hasPrefix:@"application/x-www-form-urlencoded"]) {
            NSData *body = [self postBodyDataForTransaction:transaction];
            NSString *bodyString = [[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding];
            postBodySection.rows = [self networkDetailRowsFromQueryItems:[FLEXUtility itemsFromQueryString:bodyString]];
        }
    }
    return postBodySection;
}

+ (FLEXNetworkDetailSection *)responseHeadersSectionForTransaction:(FLEXHTTPTransaction *)transaction {
    FLEXNetworkDetailSection *responseHeadersSection = [FLEXNetworkDetailSection new];
    responseHeadersSection.title = @"响应头";
    if ([transaction.response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)transaction.response;
        responseHeadersSection.rows = [self networkDetailRowsFromDictionary:httpResponse.allHeaderFields];
    }
    return responseHeadersSection;
}

+ (NSArray<FLEXNetworkDetailRow *> *)networkDetailRowsFromDictionary:(NSDictionary<NSString *, id> *)dictionary {
    NSMutableArray<FLEXNetworkDetailRow *> *rows = [NSMutableArray new];
    NSArray<NSString *> *sortedKeys = [dictionary.allKeys sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    
    for (NSString *key in sortedKeys) {
        id value = dictionary[key];
        FLEXNetworkDetailRow *row = [FLEXNetworkDetailRow new];
        row.title = key;
        row.detailText = [value description];
        [rows addObject:row];
    }

    return rows.copy;
}

+ (NSArray<FLEXNetworkDetailRow *> *)networkDetailRowsFromQueryItems:(NSArray<NSURLQueryItem *> *)items {
    // 按名称排序项目
    items = [items sortedArrayUsingComparator:^NSComparisonResult(NSURLQueryItem *item1, NSURLQueryItem *item2) {
        return [item1.name caseInsensitiveCompare:item2.name];
    }];

    NSMutableArray<FLEXNetworkDetailRow *> *rows = [NSMutableArray new];
    for (NSURLQueryItem *item in items) {
        FLEXNetworkDetailRow *row = [FLEXNetworkDetailRow new];
        row.title = item.name;
        row.detailText = item.value;
        [rows addObject:row];
    }

    return [rows copy];
}

+ (UIViewController *)detailViewControllerForMIMEType:(NSString *)mimeType data:(NSData *)data {
    if (!data) {
        return nil; // 将在此屏幕位置显示一个警告
    }
    
    FLEXCustomContentViewerFuture makeCustomViewer = FLEXManager.sharedManager.customContentTypeViewers[mimeType.lowercaseString];

    if (makeCustomViewer) {
        UIViewController *viewer = makeCustomViewer(data);

        if (viewer) {
            return viewer;
        }
    }

    // 待修复 (RKO): 不要依赖UTF8字符编码
    UIViewController *detailViewController = nil;
    if ([FLEXUtility isValidJSONData:data]) {
        NSString *prettyJSON = [FLEXUtility prettyJSONStringFromData:data];
        if (prettyJSON.length > 0) {
            detailViewController = [[FLEXWebViewController alloc] initWithText:prettyJSON];
        }
    } else if ([mimeType hasPrefix:@"image/"]) {
        UIImage *image = [UIImage imageWithData:data];
        detailViewController = [FLEXImagePreviewViewController forImage:image];
    } else if ([mimeType isEqual:@"application/x-plist"]) {
        id propertyList = [NSPropertyListSerialization propertyListWithData:data options:0 format:NULL error:NULL];
        detailViewController = [[FLEXWebViewController alloc] initWithText:[propertyList description]];
    }

    // 回退到尝试将响应显示为文本
    if (!detailViewController) {
        NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (text.length > 0) {
            detailViewController = [[FLEXWebViewController alloc] initWithText:text];
        }
    }
    return detailViewController;
}

+ (NSData *)postBodyDataForTransaction:(FLEXHTTPTransaction *)transaction {
    NSData *bodyData = transaction.cachedRequestBody;
    if (bodyData.length > 0 && [FLEXUtility hasCompressedContentEncoding:transaction.request]) {
        bodyData = [FLEXUtility inflatedDataFromCompressedData:bodyData];
    }
    return bodyData;
}

- (NSArray<FLEXNetworkDetailRow *> *)timeDetails {
    NSMutableArray *rows = [NSMutableArray array];

    FLEXNetworkDetailRow *localStartTimeRow = [FLEXNetworkDetailRow new];
    localStartTimeRow.title = [NSString stringWithFormat:@"开始时间 (%@)", 
        [NSTimeZone.localTimeZone abbreviationForDate:self.transaction.startTime]
    ];
    localStartTimeRow.detailText = [NSDateFormatter flex_stringFrom:self.transaction.startTime format:FLEXDateFormatPreciseClock];
    [rows addObject:localStartTimeRow];

    FLEXNetworkDetailRow *utcStartTimeRow = [FLEXNetworkDetailRow new];
    utcStartTimeRow.title = @"开始时间 (UTC)";
    utcStartTimeRow.detailText = [NSDateFormatter flex_stringFrom:self.transaction.startTime format:FLEXDateFormatPreciseClock];
    [rows addObject:utcStartTimeRow];

    FLEXNetworkDetailRow *durationRow = [FLEXNetworkDetailRow new];
    durationRow.title = @"总持续时间";
    durationRow.detailText = [FLEXUtility stringFromRequestDuration:self.transaction.duration];
    [rows addObject:durationRow];

    return rows;
}

@end
