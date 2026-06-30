//
//  UCClassSearchViewController.m
//  FLEX++
//
//  类名搜索和单类头文件查看器
//

#import "UCClassSearchViewController.h"
#import "UCClassDumpTool.h"
#import "UCMethodListViewController.h"
#import "../Disassembler/UCDisassembler.h"
#import "../Disassembler/UCDisasmViewController.h"
#import "FLEXColor.h"
#import "FLEXResources.h"
#import "FLEXActivityViewController.h"
#import <objc/runtime.h>

#pragma mark - 头文件详情视图控制器

@interface UCClassHeaderDetailViewController : UIViewController <UISearchBarDelegate>

@property (nonatomic, copy) NSString *className;
@property (nonatomic, copy) NSString *headerContent;
@property (nonatomic, strong) UITextView *textView;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, strong) NSString *searchText;
@property (nonatomic, strong) NSArray<NSValue *> *matchRanges;
@property (nonatomic, assign) NSInteger currentMatchIndex;
@property (nonatomic, assign) NSInteger fontSize;
@property (nonatomic, strong) UISearchBar *searchBar;

- (instancetype)initWithClassName:(NSString *)className;

@end

@implementation UCClassHeaderDetailViewController

- (instancetype)initWithClassName:(NSString *)className {
    self = [super init];
    if (self) {
        _className = className ?: @"";
        _fontSize = 11;
        _matchRanges = @[];
        _currentMatchIndex = 0;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = FLEXColor.primaryBackgroundColor;
    self.title = [NSString stringWithFormat:@"%@.h", self.className];
    
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
    
    // 搜索栏 - 放在tableHeaderView位置（这里用textView的inputView不合适，直接放顶部）
    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectZero];
    [self.searchBar sizeToFit];
    self.searchBar.delegate = self;
    self.searchBar.placeholder = @"搜索头文件内容...";
    self.searchBar.backgroundColor = FLEXColor.primaryBackgroundColor;
    self.searchBar.searchBarStyle = UISearchBarStyleMinimal;
    self.searchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.searchBar.autocorrectionType = UITextAutocorrectionTypeNo;
    self.searchBar.tintColor = [UIColor colorWithRed:0.2 green:0.6 blue:1.0 alpha:1.0];
    self.searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.searchBar];
    
    // 加载指示器
    self.loadingIndicator = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.loadingIndicator.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin |
                                              UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    self.loadingIndicator.hidesWhenStopped = YES;
    self.loadingIndicator.center = CGPointMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2);
    [self.view addSubview:self.loadingIndicator];
    [self.loadingIndicator startAnimating];
    
    // 文本视图
    CGFloat topOffset = 44;
    self.textView = [[UITextView alloc] initWithFrame:CGRectMake(0, topOffset,
        self.view.bounds.size.width, self.view.bounds.size.height - topOffset)];
    self.textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.textView.backgroundColor = FLEXColor.primaryBackgroundColor;
    self.textView.textColor = FLEXColor.primaryTextColor;
    self.textView.font = [UIFont fontWithName:@"Menlo-Regular" size:self.fontSize];
    self.textView.editable = NO;
    self.textView.selectable = YES;
    self.textView.textContainerInset = UIEdgeInsetsMake(8, 8, 8, 8);
    self.textView.hidden = YES;
    [self.view addSubview:self.textView];
    
    // 加载头文件
    [self loadHeader];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat width = self.view.bounds.size.width;
    CGFloat height = self.view.bounds.size.height;
    CGFloat safeTop = self.view.safeAreaInsets.top;
    
    // 更新搜索栏
    [self.searchBar sizeToFit];
    CGFloat searchBarHeight = self.searchBar.frame.size.height;
    self.searchBar.frame = CGRectMake(0, safeTop, width, searchBarHeight);
    
    // 更新加载指示器位置
    self.loadingIndicator.center = CGPointMake(width / 2, height / 2);
    
    // 更新文本视图
    CGFloat topOffset = safeTop + searchBarHeight;
    CGRect textFrame = CGRectMake(0, topOffset, width, height - topOffset);
    self.textView.frame = textFrame;
}

- (void)loadHeader {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *header = [UCClassDumpTool headerForClassName:self.className];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.loadingIndicator stopAnimating];
            self.textView.hidden = NO;
            
            if (header.length > 0) {
                self.headerContent = header;
                self.textView.text = header;
            } else {
                self.textView.text = [NSString stringWithFormat:@"// 错误: 无法找到类 %@ 的头文件\n// 请确认类名是否正确", self.className];
                self.textView.textColor = [UIColor redColor];
            }
        });
    });
}

#pragma mark - 操作

- (void)copyAction {
    if (self.headerContent.length == 0) return;
    
    UIPasteboard.generalPasteboard.string = self.headerContent;
    
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
    if (self.headerContent.length == 0) return;
    
    NSString *fileName = [NSString stringWithFormat:@"%@.h", self.className];
    NSString *tmpPath = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
    NSError *writeError = nil;
    BOOL success = [self.headerContent writeToFile:tmpPath atomically:YES encoding:NSUTF8StringEncoding error:&writeError];
    if (!success) {
        NSLog(@"Failed to write file: %@", writeError);
        return;
    }
    NSURL *fileURL = [NSURL fileURLWithPath:tmpPath];
    
    UIViewController *activityVC = [FLEXActivityViewController sharing:@[fileURL] source:self.navigationItem.rightBarButtonItems.firstObject];
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
            [self refreshHighlight];
        }]];
    }
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    
    alert.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItems.lastObject;
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    self.searchText = searchText;
    [self refreshHighlight];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

#pragma mark - 搜索高亮

- (void)refreshHighlight {
    if (self.headerContent.length == 0) return;
    
    NSString *search = self.searchText.lowercaseString;
    if (search.length == 0) {
        self.textView.attributedText = [[NSAttributedString alloc]
            initWithString:self.headerContent
            attributes:@{NSFontAttributeName: [UIFont fontWithName:@"Menlo-Regular" size:self.fontSize],
                         NSForegroundColorAttributeName: FLEXColor.primaryTextColor}];
        self.matchRanges = @[];
        return;
    }
    
    NSMutableAttributedString *attrText = [[NSMutableAttributedString alloc]
        initWithString:self.headerContent
        attributes:@{NSFontAttributeName: [UIFont fontWithName:@"Menlo-Regular" size:self.fontSize],
                     NSForegroundColorAttributeName: FLEXColor.primaryTextColor}];
    
    NSMutableArray<NSValue *> *ranges = [NSMutableArray array];
    NSString *text = self.headerContent.lowercaseString;
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

#pragma mark - 类搜索视图控制器

@interface UCClassSearchViewController () <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) NSArray<NSString *> *allClassNames;
@property (nonatomic, strong) NSArray<NSString *> *filteredClassNames;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, assign) BOOL hasLoaded;
@property (nonatomic, copy) NSString *currentSearchText;

@end

@implementation UCClassSearchViewController

+ (instancetype)searchViewControllerWithMode:(UCClassSearchMode)mode {
    UCClassSearchViewController *vc = [[UCClassSearchViewController alloc] init];
    vc.searchMode = mode;
    return vc;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _searchMode = UCClassSearchModeClassDump;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = FLEXColor.primaryBackgroundColor;
    
    // 根据模式设置标题
    if (self.searchMode == UCClassSearchModeDisassembler) {
        self.title = @"选择类进行反汇编";
    } else {
        self.title = @"类头文件搜索";
    }
    
    _hasLoaded = NO;
    _currentSearchText = @"";
    _allClassNames = @[];
    _filteredClassNames = @[];
    
    // 导航栏
    UIBarButtonItem *done = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemDone
        target:self
        action:@selector(doneAction)];
    self.navigationItem.rightBarButtonItem = done;
    
    // 加载指示器
    self.loadingIndicator = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.loadingIndicator.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin |
                                              UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    self.loadingIndicator.hidesWhenStopped = YES;
    self.loadingIndicator.center = CGPointMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2);
    [self.view addSubview:self.loadingIndicator];
    [self.loadingIndicator startAnimating];
    
    // 底部状态栏
    CGFloat statusBarHeight = 30;
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(0,
        self.view.bounds.size.height - statusBarHeight,
        self.view.bounds.size.width, statusBarHeight)];
    self.statusLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.font = [UIFont systemFontOfSize:11];
    self.statusLabel.textColor = [UIColor colorWithWhite:0.5 alpha:1.0];
    self.statusLabel.backgroundColor = FLEXColor.primaryBackgroundColor;
    [self.view addSubview:self.statusLabel];
    
    // 搜索栏
    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectZero];
    [self.searchBar sizeToFit];
    self.searchBar.frame = CGRectMake(0, 0, self.view.bounds.size.width, self.searchBar.frame.size.height);
    self.searchBar.delegate = self;
    self.searchBar.placeholder = @"输入类名，如 AppDelegate、ViewController...";
    self.searchBar.backgroundColor = FLEXColor.primaryBackgroundColor;
    self.searchBar.searchBarStyle = UISearchBarStyleMinimal;
    self.searchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.searchBar.autocorrectionType = UITextAutocorrectionTypeNo;
    self.searchBar.tintColor = [UIColor colorWithRed:0.2 green:0.6 blue:1.0 alpha:1.0];
    self.searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.searchBar.showsCancelButton = YES;
    
    // 表格
    CGFloat statusH = statusBarHeight;
    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0,
        self.view.bounds.size.width, self.view.bounds.size.height - statusH)
                                                      style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.backgroundColor = FLEXColor.primaryBackgroundColor;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    self.tableView.separatorColor = [FLEXColor secondaryBackgroundColorWithAlpha:0.3];
    self.tableView.rowHeight = 44;
    self.tableView.tableHeaderView = self.searchBar;
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"ClassCell"];
    [self.view addSubview:self.tableView];
    
    // 后台加载类名列表
    [self loadClassNames];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    CGFloat width = self.view.bounds.size.width;
    CGFloat height = self.view.bounds.size.height;
    CGFloat statusBarHeight = 30;
    
    // 更新加载指示器位置
    self.loadingIndicator.center = CGPointMake(width / 2, height / 2);
    
    // 更新表格
    CGRect tableFrame = CGRectMake(0, 0, width, height - statusBarHeight);
    self.tableView.frame = tableFrame;
    
    // 更新状态栏
    CGRect statusFrame = self.statusLabel.frame;
    statusFrame.size.width = width;
    statusFrame.origin.y = height - statusBarHeight;
    self.statusLabel.frame = statusFrame;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (void)loadClassNames {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        NSArray<NSString *> *names = [UCClassDumpTool allClassNames];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.allClassNames = names;
            self.filteredClassNames = names;
            self.hasLoaded = YES;
            
            [self.loadingIndicator stopAnimating];
            
            // 强制刷新表格，确保内容正确显示
            [self.tableView reloadData];
            [self.tableView setNeedsLayout];
            [self.tableView layoutIfNeeded];
            
            [self updateStatusLabel];
        });
    });
}

- (void)updateStatusLabel {
    NSInteger total = self.allClassNames.count;
    NSInteger filtered = self.filteredClassNames.count;
    
    if (self.currentSearchText.length > 0) {
        self.statusLabel.text = [NSString stringWithFormat:@"找到 %lu 个匹配 / 共 %lu 个类", (long)filtered, (long)total];
    } else {
        self.statusLabel.text = [NSString stringWithFormat:@"共 %lu 个类 - 输入关键词搜索", (long)total];
    }
}

#pragma mark - 操作

- (void)doneAction {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    self.currentSearchText = searchText;
    [self filterWithText:searchText];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    searchBar.text = @"";
    self.currentSearchText = @"";
    self.filteredClassNames = self.allClassNames;
    [self.tableView reloadData];
    [self updateStatusLabel];
    [searchBar resignFirstResponder];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

#pragma mark - 搜索过滤

- (void)filterWithText:(NSString *)searchText {
    if (searchText.length == 0) {
        self.filteredClassNames = self.allClassNames;
        [self.tableView reloadData];
        [self updateStatusLabel];
        return;
    }
    
    // 后台线程搜索，避免卡顿
    NSArray *allNames = self.allClassNames;
    NSString *lowerSearch = searchText.lowercaseString;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableArray *results = [NSMutableArray array];
        
        // 先匹配前缀（优先级更高）
        NSMutableArray *prefixMatches = [NSMutableArray array];
        NSMutableArray *containsMatches = [NSMutableArray array];
        
        for (NSString *name in allNames) {
            NSString *lowerName = name.lowercaseString;
            if ([lowerName hasPrefix:lowerSearch]) {
                [prefixMatches addObject:name];
            } else if ([lowerName containsString:lowerSearch]) {
                [containsMatches addObject:name];
            }
        }
        
        [results addObjectsFromArray:prefixMatches];
        [results addObjectsFromArray:containsMatches];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.filteredClassNames = results;
            [self.tableView reloadData];
            [self updateStatusLabel];
        });
    });
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.filteredClassNames.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ClassCell" forIndexPath:indexPath];
    
    NSString *className = nil;
    if (indexPath.row < self.filteredClassNames.count) {
        className = self.filteredClassNames[indexPath.row];
    }
    
    cell.backgroundColor = FLEXColor.primaryBackgroundColor;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    // 搜索结果高亮匹配部分
    if (self.currentSearchText.length > 0 && className) {
        NSString *searchText = self.currentSearchText.lowercaseString;
        NSString *lowerName = className.lowercaseString;
        NSRange range = [lowerName rangeOfString:searchText];
        
        if (range.location != NSNotFound) {
            NSMutableAttributedString *attrText = [[NSMutableAttributedString alloc]
                initWithString:className
                attributes:@{NSFontAttributeName: [UIFont fontWithName:@"Menlo-Regular" size:13],
                             NSForegroundColorAttributeName: FLEXColor.primaryTextColor}];
            
            [attrText addAttribute:NSForegroundColorAttributeName
                             value:[UIColor colorWithRed:0.2 green:0.6 blue:1.0 alpha:1.0]
                             range:range];
            [attrText addAttribute:NSFontAttributeName
                             value:[UIFont fontWithName:@"Menlo-Bold" size:13]
                             range:range];
            
            cell.textLabel.attributedText = attrText;
        } else {
            cell.textLabel.attributedText = nil;
            cell.textLabel.text = className;
            cell.textLabel.font = [UIFont fontWithName:@"Menlo-Regular" size:13];
            cell.textLabel.textColor = FLEXColor.primaryTextColor;
        }
    } else {
        // 无搜索词时，直接设置 text
        cell.textLabel.attributedText = nil;
        cell.textLabel.text = className;
        cell.textLabel.font = [UIFont fontWithName:@"Menlo-Regular" size:13];
        cell.textLabel.textColor = FLEXColor.primaryTextColor;
    }
    
    cell.selectedBackgroundView = [[UIView alloc] init];
    cell.selectedBackgroundView.backgroundColor = [FLEXColor secondaryBackgroundColorWithAlpha:0.5];
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSString *className = nil;
    if (indexPath.row < self.filteredClassNames.count) {
        className = self.filteredClassNames[indexPath.row];
    }
    
    if (className) {
        [self openClassHeader:className];
    }
}

- (void)openClassHeader:(NSString *)className {
    if (className.length == 0) return;
    
    // 根据模式直接打开对应内容
    if (self.searchMode == UCClassSearchModeDisassembler) {
        // 反汇编模式：直接进入方法列表，用户选择方法后反汇编
        [self showMethodListForClass:className isClassMethod:NO];
    } else {
        // 类头文件模式：直接显示头文件
        UCClassHeaderDetailViewController *detailVC = [[UCClassHeaderDetailViewController alloc]
            initWithClassName:className];
        [self.navigationController pushViewController:detailVC animated:YES];
    }
}

- (void)showMethodListForClass:(NSString *)className isClassMethod:(BOOL)isClassMethod {
    if (className.length == 0) return;
    Class cls = objc_getClass(className.UTF8String);
    if (!cls) {
        UIAlertController *alert = [UIAlertController
            alertControllerWithTitle:@"错误"
            message:[NSString stringWithFormat:@"找不到类 %@", className]
            preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    UCMethodListViewController *methodListVC = [[UCMethodListViewController alloc]
        initWithClass:cls isClassMethod:isClassMethod];
    methodListVC.presentingNav = self.navigationController;
    
    [self.navigationController pushViewController:methodListVC animated:YES];
}

@end
