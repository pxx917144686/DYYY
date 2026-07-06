#import "UCClassSearchViewController.h"
#import "UCClassDumpTool.h"
#import "UCClassHeaderDetailViewController.h"
#import "UCMethodListViewController.h"
#import "../Disassembler/UCDisassembler.h"
#import "../Disassembler/UCDisasmViewController.h"
#import "FLEXColor.h"
#import "FLEXResources.h"
#import "FLEXActivityViewController.h"
#import <objc/runtime.h>

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
    
    if (self.searchMode == UCClassSearchModeDisassembler) {
        self.title = @"选择类进行反汇编";
    } else {
        self.title = @"类头文件搜索";
    }
    
    _hasLoaded = NO;
    _currentSearchText = @"";
    _allClassNames = @[];
    _filteredClassNames = @[];
    
    UIBarButtonItem *done = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemDone
        target:self
        action:@selector(doneAction)];
    self.navigationItem.rightBarButtonItem = done;
    
    self.loadingIndicator = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.loadingIndicator.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin |
                                              UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    self.loadingIndicator.hidesWhenStopped = YES;
    self.loadingIndicator.center = CGPointMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2);
    [self.view addSubview:self.loadingIndicator];
    [self.loadingIndicator startAnimating];
    
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
    
    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectZero];
    [self.searchBar sizeToFit];
    self.searchBar.delegate = self;
    self.searchBar.placeholder = @"输入类名，如 AppDelegate、ViewController...";
    self.searchBar.backgroundColor = FLEXColor.primaryBackgroundColor;
    self.searchBar.searchBarStyle = UISearchBarStyleMinimal;
    self.searchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.searchBar.autocorrectionType = UITextAutocorrectionTypeNo;
    self.searchBar.tintColor = [UIColor colorWithRed:0.2 green:0.6 blue:1.0 alpha:1.0];
    self.searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.searchBar.showsCancelButton = YES;
    
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
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
    
    [self loadClassNames];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    CGFloat width = self.view.bounds.size.width;
    CGFloat height = self.view.bounds.size.height;
    CGFloat safeTop = self.view.safeAreaInsets.top;
    CGFloat statusBarHeight = 30;
    
    self.loadingIndicator.center = CGPointMake(width / 2, height / 2);
    
    CGRect tableFrame = CGRectMake(0, safeTop, width, height - safeTop - statusBarHeight);
    self.tableView.frame = tableFrame;
    
    CGRect statusFrame = self.statusLabel.frame;
    statusFrame.size.width = width;
    statusFrame.origin.y = height - statusBarHeight;
    self.statusLabel.frame = statusFrame;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (self.hasLoaded) {
        [self.tableView reloadData];
    }
}

- (void)loadClassNames {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        NSArray<NSString *> *names = [UCClassDumpTool allClassNames];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.allClassNames = names;
            self.filteredClassNames = names;
            self.hasLoaded = YES;
            
            [self.loadingIndicator stopAnimating];
            
            [self.tableView reloadData];
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
    
    NSString *lowerSearch = searchText.lowercaseString;
    NSArray *allNames = self.allClassNames;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
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
        
        NSMutableArray *results = [NSMutableArray array];
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
    if (!self.hasLoaded) return 0;
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (!self.hasLoaded) return 0;
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
    
    if (self.searchMode == UCClassSearchModeDisassembler) {
        [self showMethodListForClass:className isClassMethod:NO];
    } else {
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
