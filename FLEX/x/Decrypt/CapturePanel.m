#import "CapturePanel.h"
#import "DYYYFLEXColor.h"
#import "DYYYFLEXTableViewController.h"
#import "DYYYFLEXNetworkMITMViewController.h"
#import "DYYYFLEXNetworkRecorder.h"
#import "DYYYFLEXNetworkTransaction.h"
#import "DYYYFLEXNetworkTransactionCell.h"
#import "DYYYFLEXNetworkObserver.h"
#import "DYYYFLEXNetworkSettingsController.h"
#import "DYYYFLEXResources.h"
#import "UIBarButtonItem+FLEX.h"
#import "DYYYFLEXHTTPTransactionDetailController.h"
#import "DYYYFLEXActivityViewController.h"
#import "DYYYDatabaseManager.h"
#import "DYYYUCDecryptTool.h"

#pragma mark - 通知名称定义

NSString *const CaptureDataUpdatedNotification = @"CaptureDataUpdatedNotification";
NSString *const CaptureDataUpdatedTableKey = @"tableName";

#pragma mark - 类型定义

typedef NS_ENUM(NSInteger, CaptureTab) {
    CaptureTabNetwork = 0,
    CaptureTabDecrypt,
    CaptureTabKeys,
    CaptureTabCrypto,
};

#pragma mark - 功能开关项

@interface DYYYCaptureSwitchItem : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *switchKey;
@property (nonatomic, copy) NSString *desc;
@property (nonatomic, assign) BOOL defaultValue;
+ (instancetype)itemWithTitle:(NSString *)title key:(NSString *)key desc:(NSString *)desc default:(BOOL)def;
@end

@implementation DYYYCaptureSwitchItem
+ (instancetype)itemWithTitle:(NSString *)title key:(NSString *)key desc:(NSString *)desc default:(BOOL)def {
    DYYYCaptureSwitchItem *item = [DYYYCaptureSwitchItem new];
    item.title = title;
    item.switchKey = key;
    item.desc = desc;
    item.defaultValue = def;
    return item;
}
@end

#pragma mark - 详情视图控制器

@interface DYYYCaptureDetailViewController : UIViewController <UISearchBarDelegate>

@property (nonatomic, copy) NSString *textContent;
@property (nonatomic, copy) NSString *navTitle;
@property (nonatomic, strong) UITextView *textView;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, assign) NSInteger fontSize;
@property (nonatomic, strong) NSString *searchText;
@property (nonatomic, strong) NSArray<NSValue *> *matchRanges;
@property (nonatomic, assign) NSInteger currentMatchIndex;

@end

@implementation DYYYCaptureDetailViewController

- (instancetype)initWithText:(NSString *)text title:(NSString *)title {
    self = [super init];
    if (self) {
        _textContent = text ?: @"";
        _navTitle = title ?: @"详情";
        _fontSize = 11;
        _matchRanges = @[];
        _currentMatchIndex = 0;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = DYYYFLEXColor.primaryBackgroundColor;
    self.title = self.navTitle;
    
    // 导航栏按钮
    UIBarButtonItem *copy = [[UIBarButtonItem alloc]
        initWithTitle:@"复制"
        style:UIBarButtonItemStylePlain
        target:self
        action:@selector(copyAction)];
    
    UIBarButtonItem *share = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemAction
        target:self
        action:@selector(shareAction)];
    
    UIBarButtonItem *font = [[UIBarButtonItem alloc]
        initWithTitle:@"字体"
        style:UIBarButtonItemStylePlain
        target:self
        action:@selector(fontAction)];
    
    self.navigationItem.rightBarButtonItems = @[share, copy, font];
    
    // 搜索栏
    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
    self.searchBar.delegate = self;
    self.searchBar.placeholder = @"搜索内容...";
    self.searchBar.backgroundColor = DYYYFLEXColor.primaryBackgroundColor;
    self.searchBar.searchBarStyle = UISearchBarStyleMinimal;
    
    // 文本视图
    CGFloat topOffset = 44;
    self.textView = [[UITextView alloc] initWithFrame:CGRectMake(0, topOffset,
        self.view.bounds.size.width, self.view.bounds.size.height - topOffset)];
    self.textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.textView.backgroundColor = DYYYFLEXColor.primaryBackgroundColor;
    self.textView.textColor = DYYYFLEXColor.primaryTextColor;
    self.textView.font = [UIFont fontWithName:@"Menlo-Regular" size:self.fontSize];
    self.textView.editable = NO;
    self.textView.selectable = YES;
    self.textView.text = self.textContent;
    self.textView.textContainerInset = UIEdgeInsetsMake(8, 8, 8, 8);
    
    [self.view addSubview:self.searchBar];
    [self.view addSubview:self.textView];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat topInset = self.view.safeAreaInsets.top;
    [self.searchBar sizeToFit];
    self.searchBar.frame = CGRectMake(0, topInset, self.view.bounds.size.width, self.searchBar.frame.size.height);
    self.textView.frame = CGRectMake(0, topInset + self.searchBar.frame.size.height, self.view.bounds.size.width, self.view.bounds.size.height - topInset - self.searchBar.frame.size.height);
}

#pragma mark - 操作

- (void)copyAction {
    UIPasteboard.generalPasteboard.string = self.textContent;
    
    // 视觉反馈
    UILabel *toast = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 120, 40)];
    toast.center = CGPointMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2);
    toast.backgroundColor = [UIColor colorWithWhite:0 alpha:0.8];
    toast.textColor = [UIColor whiteColor];
    toast.textAlignment = NSTextAlignmentCenter;
    toast.font = [UIFont systemFontOfSize:14];
    toast.text = @"已复制";
    toast.layer.cornerRadius = 8;
    toast.clipsToBounds = YES;
    toast.alpha = 0;
    [self.view addSubview:toast];
    
    [UIView animateWithDuration:0.2 animations:^{
        toast.alpha = 1;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.3 delay:0.8 options:0 animations:^{
            toast.alpha = 0;
        } completion:^(BOOL finished) {
            [toast removeFromSuperview];
        }];
    }];
}

- (void)shareAction {
    NSArray *items = @[self.textContent];
    UIBarButtonItem *sourceItem = nil;
    if (self.navigationItem.rightBarButtonItems.count > 0) {
        sourceItem = self.navigationItem.rightBarButtonItems.firstObject;
    }
    UIViewController *activityVC = [DYYYFLEXActivityViewController sharing:items source:sourceItem];
    [self presentViewController:activityVC animated:YES completion:nil];
}

- (void)fontAction {
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"字体大小"
        message:nil
        preferredStyle:UIAlertControllerStyleActionSheet];
    
    NSArray *sizes = @[@10, @11, @12, @14, @16, @18, @20];
    for (NSNumber *size in sizes) {
        NSString *title = [NSString stringWithFormat:@"%@ pt", size];
        if (size.integerValue == self.fontSize) {
            title = [title stringByAppendingString:@" ✓"];
        }
        [alert addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            self.fontSize = size.integerValue;
            self.textView.font = [UIFont fontWithName:@"Menlo-Regular" size:self.fontSize];
        }]];
    }
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    
    alert.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItems.lastObject;
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - 搜索

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    self.searchText = searchText;
    [self highlightMatches];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
    [self findNextMatch];
}

- (void)highlightMatches {
    NSString *search = self.searchText.lowercaseString;
    if (search.length == 0) {
        self.textView.attributedText = [[NSAttributedString alloc]
            initWithString:self.textContent
            attributes:@{NSFontAttributeName: [UIFont fontWithName:@"Menlo-Regular" size:self.fontSize],
                         NSForegroundColorAttributeName: DYYYFLEXColor.primaryTextColor}];
        self.matchRanges = @[];
        return;
    }
    
    NSMutableAttributedString *attrText = [[NSMutableAttributedString alloc]
        initWithString:self.textContent
        attributes:@{NSFontAttributeName: [UIFont fontWithName:@"Menlo-Regular" size:self.fontSize],
                     NSForegroundColorAttributeName: DYYYFLEXColor.primaryTextColor}];
    
    NSMutableArray<NSValue *> *ranges = [NSMutableArray array];
    NSString *text = self.textContent.lowercaseString;
    NSRange searchRange = NSMakeRange(0, text.length);
    
    while (searchRange.location < text.length) {
        NSRange foundRange = [text rangeOfString:search options:0 range:searchRange];
        if (foundRange.location == NSNotFound) break;
        
        [ranges addObject:[NSValue valueWithRange:foundRange]];
        [attrText addAttribute:NSBackgroundColorAttributeName
                         value:[UIColor colorWithRed:1.0 green:1.0 blue:0.0 alpha:0.4]
                         range:foundRange];
        
        searchRange.location = foundRange.location + foundRange.length;
        searchRange.length = text.length - searchRange.location;
    }
    
    self.matchRanges = ranges;
    self.currentMatchIndex = 0;
    self.textView.attributedText = attrText;
    
    if (ranges.count > 0) {
        [self scrollToMatch:0];
    }
}

- (void)findNextMatch {
    if (self.matchRanges.count == 0) return;
    
    self.currentMatchIndex = (self.currentMatchIndex + 1) % self.matchRanges.count;
    [self scrollToMatch:self.currentMatchIndex];
}

- (void)scrollToMatch:(NSInteger)index {
    if (index < 0 || index >= self.matchRanges.count) return;
    
    NSRange range = [self.matchRanges[index] rangeValue];
    [self.textView scrollRangeToVisible:range];
}

@end

#pragma mark - 设置视图控制器

@interface DYYYCaptureSettingsVC : DYYYFLEXTableViewController
@property (nonatomic, strong) NSArray<DYYYCaptureSwitchItem *> *switchItems;
@end

@implementation DYYYCaptureSettingsVC

- (instancetype)init {
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        self.title = @"功能设置";
        
        _switchItems = @[
            [DYYYCaptureSwitchItem itemWithTitle:@"总开关" key:@"zongkaiguan" desc:@"控制所有解密/抓包功能" default:NO],
            [DYYYCaptureSwitchItem itemWithTitle:@"网络抓包增强" key:@"zhaiyaokaiguan" desc:@"捕获 URL 响应并自动解密" default:NO],
            [DYYYCaptureSwitchItem itemWithTitle:@"加密算法捕获" key:@"jiamisuanfakaiguan" desc:@"记录 AES/DES/RSA 等算法调用" default:NO],
            [DYYYCaptureSwitchItem itemWithTitle:@"HMAC 密钥捕获" key:@"hanmiyaokaiguan" desc:@"记录 HMAC 密钥和摘要算法" default:NO],
            [DYYYCaptureSwitchItem itemWithTitle:@"SSL 证书捕获" key:@"ssl3kaiguan" desc:@"捕获 SSL/TLS 握手证书" default:NO],
            [DYYYCaptureSwitchItem itemWithTitle:@"代理绕过" key:@"proxy_bypass" desc:@"禁用系统代理检测" default:NO],
            [DYYYCaptureSwitchItem itemWithTitle:@"RSA 加密捕获" key:@"rsa_encrypt" desc:@"记录 RSA 加密操作" default:NO],
            [DYYYCaptureSwitchItem itemWithTitle:@"RSA 解密捕获" key:@"rsa_decrypt" desc:@"记录 RSA 解密操作" default:NO],
            [DYYYCaptureSwitchItem itemWithTitle:@"RSA 签名捕获" key:@"rsa_sign" desc:@"记录 RSA 签名操作" default:NO],
        ];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.backgroundColor = DYYYFLEXColor.primaryBackgroundColor;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 60;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return self.switchItems.count;
    if (section == 1) return 2;
    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return @"功能开关";
    if (section == 1) return @"数据统计";
    return @"数据管理";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *switchCellId = @"SwitchCell";
    static NSString *statCellId = @"StatCell";
    static NSString *buttonCellId = @"ButtonCell";
    
    if (indexPath.section == 0) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:switchCellId];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:switchCellId];
            cell.backgroundColor = DYYYFLEXColor.primaryBackgroundColor;
        }
        
        DYYYCaptureSwitchItem *item = self.switchItems[indexPath.row];
        cell.textLabel.text = item.title;
        cell.textLabel.textColor = DYYYFLEXColor.primaryTextColor;
        cell.detailTextLabel.text = item.desc;
        cell.detailTextLabel.textColor = [UIColor colorWithWhite:0.5 alpha:1.0];
        cell.detailTextLabel.numberOfLines = 0;
        
        UISwitch *sw = [[UISwitch alloc] init];
        sw.onTintColor = [UIColor colorWithRed:0.2 green:0.6 blue:1.0 alpha:1.0];
        sw.tag = indexPath.row;
        [sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
        
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier] ?: @"unknown";
        BOOL isOn = [[DYYYDatabaseManager sharedManager] getSwitch:item.switchKey
                                                      bundleID:bundleID
                                                  defaultValue:item.defaultValue];
        sw.on = isOn;
        
        cell.accessoryView = sw;
        return cell;
    } else if (indexPath.section == 1) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:statCellId];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:statCellId];
            cell.backgroundColor = DYYYFLEXColor.primaryBackgroundColor;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }
        
        DYYYDatabaseManager *db = [DYYYDatabaseManager sharedManager];
        
        if (indexPath.row == 0) {
            cell.textLabel.text = @"解密记录";
            NSArray *records = [db queryAllRecordsFromTable:@"decrypt_data" limit:9999];
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)records.count];
            cell.detailTextLabel.textColor = [UIColor colorWithRed:0.2 green:0.78 blue:0.4 alpha:1.0];
        } else {
            cell.textLabel.text = @"算法调用记录";
            NSArray *records = [db queryAllRecordsFromTable:@"jiamisuanfa" limit:9999];
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)records.count];
            cell.detailTextLabel.textColor = [UIColor colorWithRed:0.78 green:0.4 blue:1.0 alpha:1.0];
        }
        
        cell.textLabel.textColor = DYYYFLEXColor.primaryTextColor;
        return cell;
    } else {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:buttonCellId];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:buttonCellId];
            cell.backgroundColor = DYYYFLEXColor.primaryBackgroundColor;
        }
        cell.textLabel.text = @"清除所有本地数据";
        cell.textLabel.textColor = UIColor.redColor;
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        return cell;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == 2) {
        UIAlertController *alert = [UIAlertController
            alertControllerWithTitle:@"确认清除"
            message:@"将清除所有解密记录、密钥记录、算法记录等本地数据，确定吗？"
            preferredStyle:UIAlertControllerStyleAlert];
        
        [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        [alert addAction:[UIAlertAction actionWithTitle:@"确定清除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull a) {
            DYYYDatabaseManager *db = [DYYYDatabaseManager sharedManager];
            [db clearTable:@"decrypt_data"];
            [db clearTable:@"crypto_keys"];
            [db clearTable:@"jiamisuanfa"];
            [db clearTable:@"url_responses"];
            [db clearTable:@"ssl_certificates"];
            [db clearTable:@"ssl_challenges"];
            [db clearTable:@"rsa_data"];
            
            [self.tableView reloadData];
            
            // 发送数据更新通知
            [[NSNotificationCenter defaultCenter]
                postNotificationName:CaptureDataUpdatedNotification
                object:nil
                userInfo:@{CaptureDataUpdatedTableKey: @"all"}];
            
            UIAlertController *done = [UIAlertController
                alertControllerWithTitle:@"已清除"
                message:@"所有本地数据已清除"
                preferredStyle:UIAlertControllerStyleAlert];
            [done addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:done animated:YES completion:nil];
        }]];
        
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (void)switchChanged:(UISwitch *)sender {
    DYYYCaptureSwitchItem *item = self.switchItems[sender.tag];
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier] ?: @"unknown";
    [[DYYYDatabaseManager sharedManager] setSwitch:item.switchKey
                                      bundleID:bundleID
                                         value:sender.isOn];
    
    NSLog(@"[CaptureSettings] %@ 开关: %@", item.title, sender.isOn ? @"开启" : @"关闭");
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

@end

#pragma mark - 通用列表基类

@interface DYYYCaptureListViewController : DYYYFLEXTableViewController

@property (nonatomic, strong) NSArray *allItems;
@property (nonatomic, strong) NSArray *filteredItems;
@property (nonatomic, copy) NSString *tableName;
@property (nonatomic, strong) NSArray<NSString *> *scopeTitles;
@property (nonatomic) NSInteger currentScope;
@property (nonatomic, copy) UIColor *tintColor;
@property (nonatomic, strong) UILabel *statusLabel;

- (instancetype)initWithTableName:(NSString *)tableName
                       scopeTitles:(NSArray<NSString *> *)scopeTitles
                         tintColor:(UIColor *)tintColor;

- (BOOL)matchesScope:(NSInteger)scope text:(NSString *)text;
- (NSString *)firstLineOfText:(NSString *)text;
- (NSString *)detailOfText:(NSString *)text;
- (UIViewController *)detailViewControllerForItem:(NSDictionary *)item;

@end

@implementation DYYYCaptureListViewController

- (instancetype)initWithTableName:(NSString *)tableName
                       scopeTitles:(NSArray<NSString *> *)scopeTitles
                         tintColor:(UIColor *)tintColor {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        _tableName = [tableName copy];
        _scopeTitles = [scopeTitles copy];
        _tintColor = tintColor;
        _currentScope = 0;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.showsSearchBar = YES;
    self.pinSearchBar = YES;
    self.showSearchBarInitially = NO;

    if (self.scopeTitles.count > 1) {
        self.searchController.searchBar.showsScopeBar = YES;
        self.searchController.searchBar.scopeButtonTitles = self.scopeTitles;
    }

    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.rowHeight = 64;
    self.tableView.backgroundColor = DYYYFLEXColor.primaryBackgroundColor;

    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"CaptureCell"];
    
    // 底部状态栏
    [self setupStatusBar];
    
    // 监听数据更新通知
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleDataUpdate:)
                                                 name:CaptureDataUpdatedNotification
                                               object:nil];

    [self reloadData];
}

- (void)setupStatusBar {
    UIView *footerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.tableView.bounds.size.width, 30)];
    footerView.backgroundColor = DYYYFLEXColor.primaryBackgroundColor;
    
    self.statusLabel = [[UILabel alloc] initWithFrame:footerView.bounds];
    self.statusLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.font = [UIFont systemFontOfSize:11];
    self.statusLabel.textColor = [UIColor colorWithWhite:0.5 alpha:1.0];
    [footerView addSubview:self.statusLabel];
    
    self.tableView.tableFooterView = footerView;
}

- (void)updateStatusLabel {
    NSInteger total = self.allItems.count;
    NSInteger filtered = self.filteredItems.count;
    
    NSString *text;
    if (self.searchController.searchBar.text.length > 0 || self.currentScope > 0) {
        text = [NSString stringWithFormat:@"显示 %lu 条 / 共 %lu 条", (long)filtered, (long)total];
    } else {
        text = [NSString stringWithFormat:@"共 %lu 条记录", (long)total];
    }
    
    self.statusLabel.text = text;
}

- (void)handleDataUpdate:(NSNotification *)notification {
    NSString *table = notification.userInfo[CaptureDataUpdatedTableKey];
    if ([table isEqualToString:@"all"] || [table isEqualToString:self.tableName]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self reloadData];
        });
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadData];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)reloadData {
    // 数据库查询放到后台线程，避免卡顿
    NSString *tableName = self.tableName;
    NSString *searchText = self.searchController.searchBar.text;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray *items = [[DYYYDatabaseManager sharedManager]
            queryAllRecordsFromTable:tableName limit:500];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.allItems = items;
            [self filterContentForSearchText:searchText];
            [self.tableView reloadData];
            [self updateStatusLabel];
        });
    });
}

#pragma mark - 搜索过滤

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    [self filterContentForSearchText:searchController.searchBar.text];
    [self.tableView reloadData];
    [self updateStatusLabel];
}

- (void)searchBar:(UISearchBar *)searchBar selectedScopeButtonIndexDidChange:(NSInteger)selectedScope {
    self.currentScope = selectedScope;
    [self filterContentForSearchText:searchBar.text];
    [self.tableView reloadData];
    [self updateStatusLabel];
}

- (void)filterContentForSearchText:(NSString *)searchText {
    NSString *search = searchText.lowercaseString;
    NSMutableArray *result = [NSMutableArray array];

    for (NSDictionary *item in self.allItems) {
        NSString *text = item[@"longText"] ?: @"";

        if (self.currentScope > 0) {
            if (![self matchesScope:self.currentScope text:text]) {
                continue;
            }
        }

        if (search.length > 0) {
            if (![text.lowercaseString containsString:search]) {
                continue;
            }
        }

        [result addObject:item];
    }

    self.filteredItems = result;
}

- (BOOL)matchesScope:(NSInteger)scope text:(NSString *)text {
    return YES;
}

#pragma mark - TableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.filteredItems.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"CaptureCell" forIndexPath:indexPath];

    NSDictionary *item = self.filteredItems[indexPath.row];
    NSString *text = item[@"longText"] ?: @"";
    NSString *time = item[@"timestamp"] ?: @"";

    cell.textLabel.text = [self firstLineOfText:text];
    cell.textLabel.font = [UIFont boldSystemFontOfSize:12];
    cell.textLabel.textColor = self.tintColor;
    cell.textLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;

    cell.detailTextLabel.text = [self detailOfText:text];
    cell.detailTextLabel.font = [UIFont fontWithName:@"Menlo-Regular" size:10];
    cell.detailTextLabel.textColor = DYYYFLEXColor.primaryTextColor;
    cell.detailTextLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;

    cell.backgroundColor = DYYYFLEXColor.primaryBackgroundColor;
    cell.selectedBackgroundView = [[UIView alloc] init];
    cell.selectedBackgroundView.backgroundColor = [DYYYFLEXColor secondaryBackgroundColorWithAlpha:0.5];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    NSDictionary *item = self.filteredItems[indexPath.row];
    UIViewController *detail = [self detailViewControllerForItem:item];
    [self.navigationController pushViewController:detail animated:YES];
}

- (UIViewController *)detailViewControllerForItem:(NSDictionary *)item {
    NSString *text = item[@"longText"] ?: @"";
    return [[DYYYCaptureDetailViewController alloc] initWithText:text title:@"详情"];
}

#pragma mark - 辅助

- (NSString *)firstLineOfText:(NSString *)text {
    if (text.length == 0) return @"";
    NSRange r = [text rangeOfString:@"\n"];
    if (r.location != NSNotFound) {
        NSString *line = [text substringToIndex:r.location];
        if (line.length > 90) return [line substringToIndex:90];
        return line;
    }
    if (text.length > 90) return [text substringToIndex:90];
    return text;
}

- (NSString *)detailOfText:(NSString *)text {
    if (text.length == 0) return @"";
    NSArray *lines = [text componentsSeparatedByString:@"\n"];
    NSMutableString *preview = [NSMutableString string];
    NSInteger count = 0;
    for (NSString *line in lines) {
        NSString *t = [line stringByTrimmingCharactersInSet:
            [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (t.length == 0) continue;
        count++;
        if (count == 1) continue;
        if (count > 3) break;
        if (preview.length > 0) [preview appendString:@" | "];
        if (t.length > 60) t = [t substringToIndex:60];
        [preview appendString:t];
    }
    return preview;
}

@end

#pragma mark - 解密列表

@interface DYYYCaptureDecryptListVC : DYYYCaptureListViewController
@end

@implementation DYYYCaptureDecryptListVC

- (instancetype)init {
    return [self initWithTableName:@"decrypt_data"
                       scopeTitles:@[@"全部", @"自动解密", @"JS解码", @"HTTPS", @"RSA"]
                         tintColor:[UIColor colorWithRed:0.2 green:0.78 blue:0.4 alpha:1.0]];
}

- (BOOL)matchesScope:(NSInteger)scope text:(NSString *)text {
    NSString *low = text.lowercaseString;
    switch (scope) {
        case 1: return [low containsString:@"自动解密"] || [low containsString:@"autodecrypt"];
        case 2: return [low containsString:@"js"] || [low containsString:@"eval("] ||
                        [low containsString:@"混淆"] || [low containsString:@"解码"];
        case 3: return [low containsString:@"https"] || [low containsString:@"http/"] ||
                        [low containsString:@"响应"];
        case 4: return [low containsString:@"rsa"] || [low containsString:@"seckey"];
        default: return YES;
    }
}

- (UIViewController *)detailViewControllerForItem:(NSDictionary *)item {
    NSString *text = item[@"longText"] ?: @"";
    return [[DYYYCaptureDetailViewController alloc] initWithText:text title:@"解密详情"];
}

@end

#pragma mark - 密钥列表

@interface DYYYCaptureKeyListVC : DYYYCaptureListViewController
@end

@implementation DYYYCaptureKeyListVC

- (instancetype)init {
    return [self initWithTableName:@"crypto_keys"
                       scopeTitles:@[@"全部", @"AES", @"DES", @"RSA", @"HMAC", @"PBKDF2"]
                         tintColor:[UIColor colorWithRed:1.0 green:0.55 blue:0.1 alpha:1.0]];
}

- (BOOL)matchesScope:(NSInteger)scope text:(NSString *)text {
    NSString *low = text.lowercaseString;
    switch (scope) {
        case 1: return [low containsString:@"aes"];
        case 2: return [low containsString:@"des"] && ![low containsString:@"3des"];
        case 3: return [low containsString:@"rsa"];
        case 4: return [low containsString:@"hmac"];
        case 5: return [low containsString:@"pbkdf2"];
        default: return YES;
    }
}

- (UIViewController *)detailViewControllerForItem:(NSDictionary *)item {
    NSString *text = item[@"longText"] ?: @"";
    return [[DYYYCaptureDetailViewController alloc] initWithText:text title:@"密钥详情"];
}

@end

#pragma mark - 算法列表

@interface DYYYCaptureCryptoListVC : DYYYCaptureListViewController
@end

@implementation DYYYCaptureCryptoListVC

- (instancetype)init {
    return [self initWithTableName:@"jiamisuanfa"
                       scopeTitles:@[@"全部", @"加密", @"解密", @"哈希", @"HMAC", @"签名"]
                         tintColor:[UIColor colorWithRed:0.78 green:0.4 blue:1.0 alpha:1.0]];
}

- (BOOL)matchesScope:(NSInteger)scope text:(NSString *)text {
    NSString *low = text.lowercaseString;
    switch (scope) {
        case 1: return [low containsString:@"encrypt"] || [text containsString:@"加密操作"];
        case 2: return [low containsString:@"decrypt"] || [text containsString:@"解密操作"];
        case 3: return [low containsString:@"md5"] || [low containsString:@"sha"] ||
                        [low containsString:@"cc_md5"] || [low containsString:@"cc_sha"] ||
                        [text containsString:@"摘要"] || [text containsString:@"Hash"];
        case 4: return [low containsString:@"hmac"] || [low containsString:@"cchmac"];
        case 5: return [low containsString:@"sign"] || [text containsString:@"签名"];
        default: return YES;
    }
}

- (UIViewController *)detailViewControllerForItem:(NSDictionary *)item {
    NSString *text = item[@"longText"] ?: @"";
    return [[DYYYCaptureDetailViewController alloc] initWithText:text title:@"算法详情"];
}

@end

#pragma mark - 主面板容器

@interface DYYYCapturePanelViewController () <UIPageViewControllerDataSource, UIPageViewControllerDelegate>

@property (nonatomic, strong) UISegmentedControl *segment;
@property (nonatomic, strong) UIPageViewController *pageVC;
@property (nonatomic, strong) NSArray *viewControllers;
@property (nonatomic) NSInteger currentIndex;

@end

@implementation DYYYCapturePanelViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = DYYYFLEXColor.primaryBackgroundColor;
    self.title = @"逆向助手";
    
    UIBarButtonItem *close = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemDone
        target:self
        action:@selector(closeAction)];
    self.navigationItem.leftBarButtonItem = close;

    _segment = [[UISegmentedControl alloc] initWithItems:@[@"网络", @"解密", @"密钥", @"算法"]];
    self.segment.selectedSegmentIndex = 0;
    self.segment.tintColor = [UIColor colorWithRed:0.2 green:0.6 blue:1.0 alpha:1.0];
    [self.segment addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];
    self.navigationItem.titleView = self.segment;

    DYYYFLEXNetworkMITMViewController *networkVC = [[DYYYFLEXNetworkMITMViewController alloc] init];
    DYYYCaptureDecryptListVC *decryptVC = [[DYYYCaptureDecryptListVC alloc] init];
    DYYYCaptureKeyListVC *keyVC = [[DYYYCaptureKeyListVC alloc] init];
    DYYYCaptureCryptoListVC *cryptoVC = [[DYYYCaptureCryptoListVC alloc] init];

    _viewControllers = @[networkVC, decryptVC, keyVC, cryptoVC];
    _currentIndex = 0;

    _pageVC = [[UIPageViewController alloc]
        initWithTransitionStyle:UIPageViewControllerTransitionStyleScroll
        navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal
        options:nil];
    self.pageVC.dataSource = self;
    self.pageVC.delegate = self;
    [self.pageVC setViewControllers:@[networkVC]
                         direction:UIPageViewControllerNavigationDirectionForward
                          animated:NO
                        completion:nil];

    [self addChildViewController:self.pageVC];
    [self.view addSubview:self.pageVC.view];
    self.pageVC.view.frame = self.view.bounds;
    self.pageVC.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.pageVC didMoveToParentViewController:self];
    
    [self updateRightBarButtonItems];
    
    // 延迟执行重量级操作放到后台线程，避免进入时卡顿
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // 确保解密 hook 已安装（放到后台线程）
        [DYYYUCDecryptTool installDecryptHooksIfNeeded];
        
        // 确保 FLEX 网络监听已启用
        if (!DYYYFLEXNetworkObserver.isEnabled) {
            DYYYFLEXNetworkObserver.enabled = YES;
        }
    });
    
    // 延迟显示首次弹窗，等界面渲染完成后再显示（避免卡顿）
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self showFirstLaunchAlertIfNeeded];
    });
}

- (void)showFirstLaunchAlertIfNeeded {
    // 检查是否已经显示过首次提示
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier] ?: @"unknown";
    NSString *hasShownKey = [NSString stringWithFormat:@"capture_first_shown_%@", bundleID];
    BOOL hasShown = [[NSUserDefaults standardUserDefaults] boolForKey:hasShownKey];
    
    if (hasShown) {
        return;
    }
    
    // 显示功能开关引导弹窗
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"逆向助手"
        message:@"欢迎使用逆向助手！\n\n请选择需要启用的功能："
        preferredStyle:UIAlertControllerStyleAlert];
    
    // 添加总开关说明
    [alert addAction:[UIAlertAction actionWithTitle:@"全部启用 (推荐)" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self enableAllFeatures:YES];
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:hasShownKey];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"仅启用网络抓包" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self enableNetworkOnly];
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:hasShownKey];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"前往设置" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self settingsTapped];
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:hasShownKey];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"暂不设置" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:hasShownKey];
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)enableAllFeatures:(BOOL)enable {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier] ?: @"unknown";
    DYYYDatabaseManager *db = [DYYYDatabaseManager sharedManager];
    
    NSArray *allSwitches = @[@"zongkaiguan", @"zhaiyaokaiguan", @"jiamisuanfakaiguan",
                              @"hanmiyaokaiguan", @"rsa_encrypt", @"rsa_decrypt", @"rsa_sign"];
    
    for (NSString *key in allSwitches) {
        [db setSwitch:key bundleID:bundleID value:enable];
    }
    
    NSLog(@"[CapturePanel] 所有功能已%@", enable ? @"启用" : @"禁用");
}

- (void)enableNetworkOnly {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier] ?: @"unknown";
    DYYYDatabaseManager *db = [DYYYDatabaseManager sharedManager];
    
    [db setSwitch:@"zongkaiguan" bundleID:bundleID value:YES];
    [db setSwitch:@"zhaiyaokaiguan" bundleID:bundleID value:YES];
    [db setSwitch:@"jiamisuanfakaiguan" bundleID:bundleID value:NO];
    [db setSwitch:@"hanmiyaokaiguan" bundleID:bundleID value:NO];
    [db setSwitch:@"ssl3kaiguan" bundleID:bundleID value:NO];
    [db setSwitch:@"rsa_encrypt" bundleID:bundleID value:NO];
    [db setSwitch:@"rsa_decrypt" bundleID:bundleID value:NO];
    [db setSwitch:@"rsa_sign" bundleID:bundleID value:NO];
    
    NSLog(@"[CapturePanel] 仅启用网络抓包功能");
}

- (void)updateRightBarButtonItems {
    UIBarButtonItem *settings = [[UIBarButtonItem alloc]
        initWithImage:DYYYFLEXResources.gearIcon
        style:UIBarButtonItemStylePlain
        target:self
        action:@selector(settingsTapped)];
    
    UIBarButtonItem *trash = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemTrash
        target:self
        action:@selector(trashTapped)];
    trash.tintColor = UIColor.redColor;
    
    self.navigationItem.rightBarButtonItems = @[trash, settings];
}

- (void)settingsTapped {
    DYYYCaptureSettingsVC *settings = [[DYYYCaptureSettingsVC alloc] init];
    settings.title = @"功能设置";
    
    UIBarButtonItem *done = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemDone
        target:self
        action:@selector(settingsDoneTapped)];
    settings.navigationItem.rightBarButtonItem = done;
    
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:settings];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)settingsDoneTapped {
    [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
    
    // 刷新各列表数据
    for (UIViewController *vc in self.viewControllers) {
        if ([vc isKindOfClass:[DYYYCaptureListViewController class]]) {
            [(DYYYCaptureListViewController *)vc reloadData];
        }
    }
}

- (void)trashTapped {
    NSString *title = nil;
    NSString *msg = nil;
    void (^action)(void) = nil;
    
    switch (self.currentIndex) {
        case CaptureTabNetwork: {
            title = @"清除网络记录";
            msg = @"确定清除所有网络抓包记录？";
            action = ^{
                [DYYYFLEXNetworkRecorder.defaultRecorder clearRecordedActivity];
            };
            break;
        }
        case CaptureTabDecrypt: {
            title = @"清除解密记录";
            msg = @"确定清除所有解密记录？";
            action = ^{
                [[DYYYDatabaseManager sharedManager] clearTable:@"decrypt_data"];
                DYYYCaptureDecryptListVC *vc = self.viewControllers[CaptureTabDecrypt];
                [vc reloadData];
                
                [[NSNotificationCenter defaultCenter]
                    postNotificationName:CaptureDataUpdatedNotification
                    object:nil
                    userInfo:@{CaptureDataUpdatedTableKey: @"decrypt_data"}];
            };
            break;
        }
        case CaptureTabKeys: {
            title = @"清除密钥记录";
            msg = @"确定清除所有密钥记录？";
            action = ^{
                [[DYYYDatabaseManager sharedManager] clearTable:@"crypto_keys"];
                DYYYCaptureKeyListVC *vc = self.viewControllers[CaptureTabKeys];
                [vc reloadData];
                
                [[NSNotificationCenter defaultCenter]
                    postNotificationName:CaptureDataUpdatedNotification
                    object:nil
                    userInfo:@{CaptureDataUpdatedTableKey: @"crypto_keys"}];
            };
            break;
        }
        case CaptureTabCrypto: {
            title = @"清除算法记录";
            msg = @"确定清除所有加密算法调用记录？";
            action = ^{
                [[DYYYDatabaseManager sharedManager] clearTable:@"jiamisuanfa"];
                DYYYCaptureCryptoListVC *vc = self.viewControllers[CaptureTabCrypto];
                [vc reloadData];
                
                [[NSNotificationCenter defaultCenter]
                    postNotificationName:CaptureDataUpdatedNotification
                    object:nil
                    userInfo:@{CaptureDataUpdatedTableKey: @"jiamisuanfa"}];
            };
            break;
        }
    }
    
    if (!title) return;
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull a) {
        if (action) action();
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)segmentChanged:(UISegmentedControl *)sender {
    NSInteger newIndex = sender.selectedSegmentIndex;
    if (newIndex == self.currentIndex) return;

    UIPageViewControllerNavigationDirection direction =
        (newIndex > self.currentIndex) ?
        UIPageViewControllerNavigationDirectionForward :
        UIPageViewControllerNavigationDirectionReverse;

    UIViewController *vc = self.viewControllers[newIndex];
    [self.pageVC setViewControllers:@[vc]
                         direction:direction
                          animated:YES
                        completion:^(BOOL finished) {
        self.currentIndex = newIndex;
        [self updateRightBarButtonItems];
    }];
}

#pragma mark - UIPageViewControllerDataSource

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController
      viewControllerBeforeViewController:(UIViewController *)viewController {
    NSInteger index = [self.viewControllers indexOfObject:viewController];
    if (index == 0 || index == NSNotFound) return nil;
    return self.viewControllers[index - 1];
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController
       viewControllerAfterViewController:(UIViewController *)viewController {
    NSInteger index = [self.viewControllers indexOfObject:viewController];
    if (index == NSNotFound || index >= self.viewControllers.count - 1) return nil;
    return self.viewControllers[index + 1];
}

#pragma mark - UIPageViewControllerDelegate

- (void)pageViewController:(UIPageViewController *)pageViewController
        didFinishAnimating:(BOOL)finished
   previousViewControllers:(NSArray<UIViewController *> *)previousViewControllers
       transitionCompleted:(BOOL)completed {
    if (completed) {
        UIViewController *current = pageViewController.viewControllers.firstObject;
        NSInteger index = [self.viewControllers indexOfObject:current];
        if (index != NSNotFound) {
            self.currentIndex = index;
            self.segment.selectedSegmentIndex = index;
            [self updateRightBarButtonItems];
        }
    }
}

- (void)closeAction {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

#pragma mark - C 入口函数

void IZXShowDecryptPanelNow(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = nil;
        for (UIWindow *window in UIApplication.sharedApplication.windows) {
            if (window.isKeyWindow) {
                keyWindow = window;
                break;
            }
        }
        if (!keyWindow) keyWindow = UIApplication.sharedApplication.windows.firstObject;
        if (!keyWindow) return;

        UIViewController *rootVC = keyWindow.rootViewController;
        while (rootVC.presentedViewController) {
            rootVC = rootVC.presentedViewController;
        }

        DYYYCapturePanelViewController *panel = [[DYYYCapturePanelViewController alloc] init];
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:panel];
        nav.modalPresentationStyle = UIModalPresentationFullScreen;
        [rootVC presentViewController:nav animated:YES completion:nil];
    });
}
