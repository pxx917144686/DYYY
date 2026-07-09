//
//  FLEXNetworkTransactionDetailController.m
//  Flipboard
//
//  Created by Ryan Olson on 2/10/15.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

#import "DYYYFLEXColor.h"
#import "DYYYFLEXHTTPTransactionDetailController.h"
#import "DYYYFLEXNetworkCurlLogger.h"
#import "DYYYFLEXNetworkRecorder.h"
#import "DYYYFLEXNetworkTransaction.h"
#import "DYYYFLEXWebViewController.h"
#import "DYYYFLEXImagePreviewViewController.h"
#import "DYYYFLEXMultilineTableViewCell.h"
#import "DYYYFLEXUtility.h"
#import "DYYYFLEXManager+Private.h"
#import "DYYYFLEXTableView.h"
#import "UIBarButtonItem+FLEX.h"
#import "NSDateFormatter+FLEX.h"

typedef UIViewController *(^FLEXNetworkDetailRowSelectionFuture)(void);

@interface DYYYFLEXNetworkDetailRow : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *detailText;
@property (nonatomic, copy) FLEXNetworkDetailRowSelectionFuture selectionFuture;
@end

@implementation DYYYFLEXNetworkDetailRow
@end

@interface DYYYFLEXNetworkDetailSection : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSArray<DYYYFLEXNetworkDetailRow *> *rows;
@end

@implementation DYYYFLEXNetworkDetailSection
@end

@interface DYYYFLEXHTTPTransactionDetailController ()

@property (nonatomic, readonly) DYYYFLEXHTTPTransaction *transaction;
@property (nonatomic, copy) NSArray<DYYYFLEXNetworkDetailSection *> *sections;

@end

@implementation DYYYFLEXHTTPTransactionDetailController

+ (instancetype)withTransaction:(DYYYFLEXHTTPTransaction *)transaction {
    DYYYFLEXHTTPTransactionDetailController *controller = [self new];
    controller.transaction = transaction;
    return controller;
}

- (instancetype)initWithStyle:(UITableViewStyle)style {
    // Force grouped style
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
            flex_itemWithTitle:@"复制 curl"
            target:self
            action:@selector(copyButtonPressed:)
        ]
    ];
    
    [self.tableView registerClass:[DYYYFLEXMultilineTableViewCell class] forCellReuseIdentifier:kFLEXMultilineCell];
}

- (void)setTransaction:(DYYYFLEXHTTPTransaction *)transaction {
    if (![_transaction isEqual:transaction]) {
        _transaction = transaction;
        self.title = [transaction.request.URL lastPathComponent];
        [self rebuildTableSections];
    }
}

- (void)setSections:(NSArray<DYYYFLEXNetworkDetailSection *> *)sections {
    if (![_sections isEqual:sections]) {
        _sections = [sections copy];
        [self.tableView reloadData];
    }
}

- (void)rebuildTableSections {
    NSMutableArray<DYYYFLEXNetworkDetailSection *> *sections = [NSMutableArray new];

    DYYYFLEXNetworkDetailSection *generalSection = [[self class] generalSectionForTransaction:self.transaction];
    if (generalSection.rows.count > 0) {
        [sections addObject:generalSection];
    }
    DYYYFLEXNetworkDetailSection *requestHeadersSection = [[self class] requestHeadersSectionForTransaction:self.transaction];
    if (requestHeadersSection.rows.count > 0) {
        [sections addObject:requestHeadersSection];
    }
    DYYYFLEXNetworkDetailSection *queryParametersSection = [[self class] queryParametersSectionForTransaction:self.transaction];
    if (queryParametersSection.rows.count > 0) {
        [sections addObject:queryParametersSection];
    }
    DYYYFLEXNetworkDetailSection *postBodySection = [[self class] postBodySectionForTransaction:self.transaction];
    if (postBodySection.rows.count > 0) {
        [sections addObject:postBodySection];
    }
    DYYYFLEXNetworkDetailSection *responseHeadersSection = [[self class] responseHeadersSectionForTransaction:self.transaction];
    if (responseHeadersSection.rows.count > 0) {
        [sections addObject:responseHeadersSection];
    }

    self.sections = sections;
}

- (void)handleTransactionUpdatedNotification:(NSNotification *)notification {
    DYYYFLEXNetworkTransaction *transaction = [[notification userInfo] objectForKey:kFLEXNetworkRecorderUserInfoTransactionKey];
    if (transaction == self.transaction) {
        [self rebuildTableSections];
    }
}

- (void)copyButtonPressed:(id)sender {
    [UIPasteboard.generalPasteboard setString:[DYYYFLEXNetworkCurlLogger curlCommandString:_transaction.request]];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    DYYYFLEXNetworkDetailSection *sectionModel = self.sections[section];
    return sectionModel.rows.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    DYYYFLEXNetworkDetailSection *sectionModel = self.sections[section];
    return sectionModel.title;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DYYYFLEXMultilineTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kFLEXMultilineCell forIndexPath:indexPath];

    DYYYFLEXNetworkDetailRow *rowModel = [self rowModelAtIndexPath:indexPath];

    cell.textLabel.attributedText = [[self class] attributedTextForRow:rowModel];
    cell.accessoryType = rowModel.selectionFuture ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
    cell.selectionStyle = rowModel.selectionFuture ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    DYYYFLEXNetworkDetailRow *rowModel = [self rowModelAtIndexPath:indexPath];

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
    DYYYFLEXNetworkDetailRow *row = [self rowModelAtIndexPath:indexPath];
    NSAttributedString *attributedText = [[self class] attributedTextForRow:row];
    BOOL showsAccessory = row.selectionFuture != nil;
    return [DYYYFLEXMultilineTableViewCell
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

- (DYYYFLEXNetworkDetailRow *)rowModelAtIndexPath:(NSIndexPath *)indexPath {
    DYYYFLEXNetworkDetailSection *sectionModel = self.sections[indexPath.section];
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
        DYYYFLEXNetworkDetailRow *row = [self rowModelAtIndexPath:indexPath];
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
                    DYYYFLEXNetworkDetailRow *row = [self rowModelAtIndexPath:indexPath];
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

+ (NSAttributedString *)attributedTextForRow:(DYYYFLEXNetworkDetailRow *)row {
    NSDictionary<NSString *, id> *titleAttributes = @{ NSFontAttributeName : [UIFont fontWithName:@"HelveticaNeue-Medium" size:12.0],
                                                       NSForegroundColorAttributeName : [UIColor colorWithWhite:0.5 alpha:1.0] };
    NSDictionary<NSString *, id> *detailAttributes = @{ NSFontAttributeName : UIFont.flex_defaultTableCellFont,
                                                        NSForegroundColorAttributeName : DYYYFLEXColor.primaryTextColor };

    NSString *title = [NSString stringWithFormat:@"%@: ", row.title];
    NSString *detailText = row.detailText ?: @"";
    NSMutableAttributedString *attributedText = [NSMutableAttributedString new];
    [attributedText appendAttributedString:[[NSAttributedString alloc] initWithString:title attributes:titleAttributes]];
    [attributedText appendAttributedString:[[NSAttributedString alloc] initWithString:detailText attributes:detailAttributes]];

    return attributedText;
}

#pragma mark - 表格数据生成

+ (DYYYFLEXNetworkDetailSection *)generalSectionForTransaction:(DYYYFLEXHTTPTransaction *)transaction {
    NSMutableArray<DYYYFLEXNetworkDetailRow *> *rows = [NSMutableArray new];

    DYYYFLEXNetworkDetailRow *requestURLRow = [DYYYFLEXNetworkDetailRow new];
    requestURLRow.title = @"请求URL";
    NSURL *url = transaction.request.URL;
    requestURLRow.detailText = url.absoluteString;
    requestURLRow.selectionFuture = ^{
        UIViewController *urlWebViewController = [[DYYYFLEXWebViewController alloc] initWithURL:url];
        urlWebViewController.title = url.absoluteString;
        return urlWebViewController;
    };
    [rows addObject:requestURLRow];

    DYYYFLEXNetworkDetailRow *requestMethodRow = [DYYYFLEXNetworkDetailRow new];
    requestMethodRow.title = @"请求方法";
    requestMethodRow.detailText = transaction.request.HTTPMethod;
    [rows addObject:requestMethodRow];

    if (transaction.cachedRequestBody.length > 0) {
        DYYYFLEXNetworkDetailRow *postBodySizeRow = [DYYYFLEXNetworkDetailRow new];
        postBodySizeRow.title = @"请求体大小";
        postBodySizeRow.detailText = [NSByteCountFormatter stringFromByteCount:transaction.cachedRequestBody.length countStyle:NSByteCountFormatterCountStyleBinary];
        [rows addObject:postBodySizeRow];

        DYYYFLEXNetworkDetailRow *postBodyRow = [DYYYFLEXNetworkDetailRow new];
        postBodyRow.title = @"请求体";
        postBodyRow.detailText = @"点击查看";
        postBodyRow.selectionFuture = ^UIViewController * () {
            // 如果可以就显示请求体
            NSString *contentType = [transaction.request valueForHTTPHeaderField:@"Content-Type"];
            NSData *body = [self postBodyDataForTransaction:transaction];
            UIViewController *detailViewController = [self detailViewControllerForMIMEType:contentType data:body];
            if (detailViewController) {
                detailViewController.title = @"请求体";
                return detailViewController;
            }

            // 不能显示请求体，提醒用户
            return [DYYYFLEXAlert makeAlert:^(DYYYFLEXAlert *make) {
                if (!body) {
                    make.title(@"空HTTP体");
                } else {
                    make.title(@"无法查看HTTP体数据");
                    make.message(@"FLEX没有适用于此MIME类型的请求体数据查看器: ");
                }
                
                make.message(contentType);
                make.button(@"关闭").cancelStyle();
            }];
        };

        [rows addObject:postBodyRow];
    }

    NSString *statusCodeString = [DYYYFLEXUtility statusCodeStringFromURLResponse:transaction.response];
    if (statusCodeString.length > 0) {
        DYYYFLEXNetworkDetailRow *statusCodeRow = [DYYYFLEXNetworkDetailRow new];
        statusCodeRow.title = @"状态码";
        statusCodeRow.detailText = statusCodeString;
        [rows addObject:statusCodeRow];
    }

    if (transaction.error) {
        DYYYFLEXNetworkDetailRow *errorRow = [DYYYFLEXNetworkDetailRow new];
        errorRow.title = @"错误";
        errorRow.detailText = transaction.error.localizedDescription;
        [rows addObject:errorRow];
    }

    DYYYFLEXNetworkDetailRow *responseBodyRow = [DYYYFLEXNetworkDetailRow new];
    responseBodyRow.title = @"响应体";
    NSData *responseData = [DYYYFLEXNetworkRecorder.defaultRecorder cachedResponseBodyForTransaction:transaction];
    if (responseData.length > 0) {
        responseBodyRow.detailText = @"点击查看";

        // 避免对响应数据的长期强引用，以防我们需要从缓存中清除它
        weakify(responseData)
        responseBodyRow.selectionFuture = ^UIViewController *() { strongify(responseData)

            // 如果可以就显示响应
            NSString *contentType = transaction.response.MIMEType;
            if (responseData) {
                UIViewController *bodyDetails = [self detailViewControllerForMIMEType:contentType data:responseData];
                if (bodyDetails) {
                    bodyDetails.title = @"响应";
                    return bodyDetails;
                }
            }

            // 无法显示响应，提醒用户
            return [DYYYFLEXAlert makeAlert:^(DYYYFLEXAlert *make) {
                make.title(@"无法查看响应");
                if (responseData) {
                    make.message(@"没有查看器支持的内容类型: ").message(contentType);
                } else {
                    make.message(@"响应已从缓存中清除");
                }
                make.button(@"确定").cancelStyle();
            }];
        };
    } else {
        BOOL emptyResponse = transaction.receivedDataLength == 0;
        responseBodyRow.detailText = emptyResponse ? @"空" : @"不在缓存中";
    }

    [rows addObject:responseBodyRow];

    DYYYFLEXNetworkDetailRow *responseSizeRow = [DYYYFLEXNetworkDetailRow new];
    responseSizeRow.title = @"响应大小";
    responseSizeRow.detailText = [NSByteCountFormatter stringFromByteCount:transaction.receivedDataLength countStyle:NSByteCountFormatterCountStyleBinary];
    [rows addObject:responseSizeRow];

    DYYYFLEXNetworkDetailRow *mimeTypeRow = [DYYYFLEXNetworkDetailRow new];
    mimeTypeRow.title = @"MIME类型";
    mimeTypeRow.detailText = transaction.response.MIMEType;
    [rows addObject:mimeTypeRow];

    DYYYFLEXNetworkDetailRow *mechanismRow = [DYYYFLEXNetworkDetailRow new];
    mechanismRow.title = @"机制";
    mechanismRow.detailText = transaction.requestMechanism;
    [rows addObject:mechanismRow];

    DYYYFLEXNetworkDetailRow *localStartTimeRow = [DYYYFLEXNetworkDetailRow new];
    localStartTimeRow.title = [NSString stringWithFormat:@"开始时间 (%@)", [NSTimeZone.localTimeZone abbreviationForDate:transaction.startTime]];
    localStartTimeRow.detailText = [NSDateFormatter flex_stringFrom:transaction.startTime format:FLEXDateFormatVerbose];
    [rows addObject:localStartTimeRow];

    DYYYFLEXNetworkDetailRow *utcStartTimeRow = [DYYYFLEXNetworkDetailRow new];
    utcStartTimeRow.title = @"开始时间 (UTC)";
    utcStartTimeRow.detailText = [NSDateFormatter flex_stringFrom:transaction.startTime format:FLEXDateFormatVerbose];
    [rows addObject:utcStartTimeRow];

    DYYYFLEXNetworkDetailRow *unixStartTime = [DYYYFLEXNetworkDetailRow new];
    unixStartTime.title = @"Unix开始时间";
    unixStartTime.detailText = [NSString stringWithFormat:@"%f", [transaction.startTime timeIntervalSince1970]];
    [rows addObject:unixStartTime];

    DYYYFLEXNetworkDetailRow *durationRow = [DYYYFLEXNetworkDetailRow new];
    durationRow.title = @"总持续时间";
    durationRow.detailText = [DYYYFLEXUtility stringFromRequestDuration:transaction.duration];
    [rows addObject:durationRow];

    DYYYFLEXNetworkDetailRow *latencyRow = [DYYYFLEXNetworkDetailRow new];
    latencyRow.title = @"延迟";
    latencyRow.detailText = [DYYYFLEXUtility stringFromRequestDuration:transaction.latency];
    [rows addObject:latencyRow];

    DYYYFLEXNetworkDetailSection *generalSection = [DYYYFLEXNetworkDetailSection new];
    generalSection.title = @"常规";
    generalSection.rows = rows;

    return generalSection;
}

+ (DYYYFLEXNetworkDetailSection *)requestHeadersSectionForTransaction:(DYYYFLEXHTTPTransaction *)transaction {
    DYYYFLEXNetworkDetailSection *requestHeadersSection = [DYYYFLEXNetworkDetailSection new];
    requestHeadersSection.title = @"请求头";
    requestHeadersSection.rows = [self networkDetailRowsFromDictionary:transaction.request.allHTTPHeaderFields];

    return requestHeadersSection;
}

+ (DYYYFLEXNetworkDetailSection *)postBodySectionForTransaction:(DYYYFLEXHTTPTransaction *)transaction {
    DYYYFLEXNetworkDetailSection *postBodySection = [DYYYFLEXNetworkDetailSection new];
    postBodySection.title = @"请求体参数";
    if (transaction.cachedRequestBody.length > 0) {
        NSString *contentType = [transaction.request valueForHTTPHeaderField:@"Content-Type"];
        if ([contentType hasPrefix:@"application/x-www-form-urlencoded"]) {
            NSData *body = [self postBodyDataForTransaction:transaction];
            NSString *bodyString = [[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding];
            postBodySection.rows = [self networkDetailRowsFromQueryItems:[DYYYFLEXUtility itemsFromQueryString:bodyString]];
        }
    }
    return postBodySection;
}

+ (DYYYFLEXNetworkDetailSection *)queryParametersSectionForTransaction:(DYYYFLEXHTTPTransaction *)transaction {
    NSArray<NSURLQueryItem *> *queries = [DYYYFLEXUtility itemsFromQueryString:transaction.request.URL.query];
    DYYYFLEXNetworkDetailSection *querySection = [DYYYFLEXNetworkDetailSection new];
    querySection.title = @"查询参数";
    querySection.rows = [self networkDetailRowsFromQueryItems:queries];

    return querySection;
}

+ (DYYYFLEXNetworkDetailSection *)responseHeadersSectionForTransaction:(DYYYFLEXHTTPTransaction *)transaction {
    DYYYFLEXNetworkDetailSection *responseHeadersSection = [DYYYFLEXNetworkDetailSection new];
    responseHeadersSection.title = @"响应头";
    if ([transaction.response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)transaction.response;
        responseHeadersSection.rows = [self networkDetailRowsFromDictionary:httpResponse.allHeaderFields];
    }
    return responseHeadersSection;
}

+ (NSArray<DYYYFLEXNetworkDetailRow *> *)networkDetailRowsFromDictionary:(NSDictionary<NSString *, id> *)dictionary {
    NSMutableArray<DYYYFLEXNetworkDetailRow *> *rows = [NSMutableArray new];
    NSArray<NSString *> *sortedKeys = [dictionary.allKeys sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    
    for (NSString *key in sortedKeys) {
        id value = dictionary[key];
        DYYYFLEXNetworkDetailRow *row = [DYYYFLEXNetworkDetailRow new];
        row.title = key;
        row.detailText = [value description];
        [rows addObject:row];
    }

    return rows.copy;
}

+ (NSArray<DYYYFLEXNetworkDetailRow *> *)networkDetailRowsFromQueryItems:(NSArray<NSURLQueryItem *> *)items {
    // Sort the items by name
    items = [items sortedArrayUsingComparator:^NSComparisonResult(NSURLQueryItem *item1, NSURLQueryItem *item2) {
        return [item1.name caseInsensitiveCompare:item2.name];
    }];

    NSMutableArray<DYYYFLEXNetworkDetailRow *> *rows = [NSMutableArray new];
    for (NSURLQueryItem *item in items) {
        DYYYFLEXNetworkDetailRow *row = [DYYYFLEXNetworkDetailRow new];
        row.title = item.name;
        row.detailText = item.value;
        [rows addObject:row];
    }

    return [rows copy];
}

+ (UIViewController *)detailViewControllerForMIMEType:(NSString *)mimeType data:(NSData *)data {
    if (!data) {
        return nil; // An alert will be presented in place of this screen
    }
    
    FLEXCustomContentViewerFuture makeCustomViewer = DYYYFLEXManager.sharedManager.customContentTypeViewers[mimeType.lowercaseString];

    if (makeCustomViewer) {
        UIViewController *viewer = makeCustomViewer(data);

        if (viewer) {
            return viewer;
        }
    }

    // FIXME (RKO): Don't rely on UTF8 string encoding
    UIViewController *detailViewController = nil;
    if ([DYYYFLEXUtility isValidJSONData:data]) {
        NSString *prettyJSON = [DYYYFLEXUtility prettyJSONStringFromData:data];
        if (prettyJSON.length > 0) {
            detailViewController = [[DYYYFLEXWebViewController alloc] initWithText:prettyJSON];
        }
    } else if ([mimeType hasPrefix:@"image/"]) {
        UIImage *image = [UIImage imageWithData:data];
        detailViewController = [DYYYFLEXImagePreviewViewController forImage:image];
    } else if ([mimeType isEqual:@"application/x-plist"]) {
        id propertyList = [NSPropertyListSerialization propertyListWithData:data options:0 format:NULL error:NULL];
        detailViewController = [[DYYYFLEXWebViewController alloc] initWithText:[propertyList description]];
    }

    // Fall back to trying to show the response as text
    if (!detailViewController) {
        NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (text.length > 0) {
            detailViewController = [[DYYYFLEXWebViewController alloc] initWithText:text];
        }
    }
    return detailViewController;
}

+ (NSData *)postBodyDataForTransaction:(DYYYFLEXHTTPTransaction *)transaction {
    NSData *bodyData = transaction.cachedRequestBody;
    if (bodyData.length > 0 && [DYYYFLEXUtility hasCompressedContentEncoding:transaction.request]) {
        bodyData = [DYYYFLEXUtility inflatedDataFromCompressedData:bodyData];
    }
    return bodyData;
}

@end
