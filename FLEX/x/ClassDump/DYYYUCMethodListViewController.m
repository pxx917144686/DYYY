#import "DYYYUCMethodListViewController.h"
#import "../Disassembler/DYYYUCDisassembler.h"
#import "../Disassembler/DYYYUCDisasmViewController.h"
#import "DYYYFLEXColor.h"

@interface DYYYUCMethodListViewController () <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;

@property (nonatomic, strong) NSArray *allMethods;
@property (nonatomic, strong) NSArray *filteredMethods;
@property (nonatomic, copy) NSString *currentSearchText;

@property (nonatomic, assign) Class targetClass;
@property (nonatomic, assign) BOOL isClassMethod;
@property (nonatomic, copy) NSString *className;

@end

@implementation DYYYUCMethodListViewController

- (instancetype)initWithClass:(Class)cls isClassMethod:(BOOL)isClassMethod {
    self = [super init];
    if (self) {
        _targetClass = cls;
        _isClassMethod = isClassMethod;
        _className = cls ? NSStringFromClass(cls) : @"Unknown";
        _currentSearchText = @"";
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = DYYYFLEXColor.primaryBackgroundColor;
    self.title = self.className;
    
    UISegmentedControl *segmentedControl = [[UISegmentedControl alloc] initWithItems:@[@"实例方法", @"类方法"]];
    segmentedControl.selectedSegmentIndex = self.isClassMethod ? 1 : 0;
    segmentedControl.tintColor = [UIColor colorWithRed:0.2 green:0.6 blue:1.0 alpha:1.0];
    [segmentedControl addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];
    self.navigationItem.titleView = segmentedControl;
    
    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
    [self.searchBar sizeToFit];
    self.searchBar.frame = CGRectMake(0, 0, self.view.bounds.size.width, self.searchBar.frame.size.height);
    self.searchBar.delegate = self;
    self.searchBar.placeholder = @"搜索方法名...";
    self.searchBar.backgroundColor = DYYYFLEXColor.primaryBackgroundColor;
    self.searchBar.searchBarStyle = UISearchBarStyleMinimal;
    self.searchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.searchBar.autocorrectionType = UITextAutocorrectionTypeNo;
    self.searchBar.tintColor = [UIColor colorWithRed:0.2 green:0.6 blue:1.0 alpha:1.0];
    
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
    self.statusLabel.backgroundColor = DYYYFLEXColor.primaryBackgroundColor;
    [self.view addSubview:self.statusLabel];
    
    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0,
        self.view.bounds.size.width, self.view.bounds.size.height - statusBarHeight)
                                                      style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.backgroundColor = DYYYFLEXColor.primaryBackgroundColor;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    self.tableView.separatorColor = [DYYYFLEXColor secondaryBackgroundColorWithAlpha:0.3];
    self.tableView.rowHeight = 44;
    self.tableView.tableHeaderView = self.searchBar;
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"MethodCell"];
    [self.view addSubview:self.tableView];
    
    [self loadMethods];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    CGFloat width = self.view.bounds.size.width;
    CGFloat height = self.view.bounds.size.height;
    CGFloat statusBarHeight = 30;
    
    self.loadingIndicator.center = CGPointMake(width / 2, height / 2);
    
    CGRect tableFrame = CGRectMake(0, 0, width, height - statusBarHeight);
    self.tableView.frame = tableFrame;
    
    CGRect statusFrame = self.statusLabel.frame;
    statusFrame.size.width = width;
    statusFrame.origin.y = height - statusBarHeight;
    self.statusLabel.frame = statusFrame;
}

- (void)loadMethods {
    Class cls = self.targetClass;
    BOOL isClassMethod = self.isClassMethod;
    
    __weak typeof(self) weakSelf = self;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableArray *methods = [NSMutableArray array];
        
        if (cls) {
            @try {
                unsigned int count = 0;
                Method *methodList = NULL;
                
                if (isClassMethod) {
                    Class metaCls = object_getClass(cls);
                    if (metaCls) {
                        methodList = class_copyMethodList(metaCls, &count);
                    }
                } else {
                    methodList = class_copyMethodList(cls, &count);
                }
                
                if (methodList && count > 0) {
                    for (unsigned int i = 0; i < count; i++) {
                        Method m = methodList[i];
                        if (!m) continue;
                        
                        SEL sel = method_getName(m);
                        if (!sel) continue;
                        
                        NSString *selName = NSStringFromSelector(sel);
                        if (!selName) selName = @"?";
                        
                        IMP imp = method_getImplementation(m);
                        
                        NSDictionary *methodInfo = @{
                            @"name": selName,
                            @"imp": [NSValue valueWithPointer:imp ?: NULL],
                        };
                        [methods addObject:methodInfo];
                    }
                    free(methodList);
                }
            }
            @catch (NSException *exception) {
                NSLog(@"[DYYYUCMethodListViewController] Error loading methods: %@", exception);
            }
        }
        
        if (methods.count > 0) {
            [methods sortUsingDescriptors:@[
                [NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES selector:@selector(caseInsensitiveCompare:)]
            ]];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            
            strongSelf.allMethods = methods;
            strongSelf.filteredMethods = methods;
            
            [strongSelf.loadingIndicator stopAnimating];
            [strongSelf.tableView reloadData];
            [strongSelf updateStatusLabel];
        });
    });
}

- (void)updateStatusLabel {
    NSUInteger total = self.allMethods.count;
    NSUInteger filtered = self.filteredMethods.count;
    
    if (self.currentSearchText.length > 0) {
        self.statusLabel.text = [NSString stringWithFormat:
            @"找到 %lu 个方法 / 共 %lu 个",
            (unsigned long)filtered, (unsigned long)total];
    } else {
        self.statusLabel.text = [NSString stringWithFormat:
            @"共 %lu 个方法",
            (unsigned long)total];
    }
}

#pragma mark - 分段切换

- (void)segmentChanged:(UISegmentedControl *)sender {
    self.isClassMethod = (sender.selectedSegmentIndex == 1);
    self.currentSearchText = @"";
    self.searchBar.text = @"";
    
    [self.loadingIndicator startAnimating];
    self.allMethods = @[];
    self.filteredMethods = @[];
    [self.tableView reloadData];
    
    [self loadMethods];
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    self.currentSearchText = searchText;
    [self filterWithText:searchText];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    searchBar.text = @"";
    self.currentSearchText = @"";
    self.filteredMethods = self.allMethods;
    [self.tableView reloadData];
    [self updateStatusLabel];
    [searchBar resignFirstResponder];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

- (void)filterWithText:(NSString *)searchText {
    if (searchText.length == 0) {
        self.filteredMethods = self.allMethods;
        [self.tableView reloadData];
        [self updateStatusLabel];
        return;
    }
    
    NSString *lower = searchText.lowercaseString;
    NSMutableArray *filtered = [NSMutableArray array];
    
    for (NSDictionary *method in self.allMethods) {
        NSString *name = method[@"name"];
        if ([name.lowercaseString containsString:lower]) {
            [filtered addObject:method];
        }
    }
    
    self.filteredMethods = filtered;
    [self.tableView reloadData];
    [self updateStatusLabel];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.filteredMethods.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"MethodCell" forIndexPath:indexPath];
    
    if (indexPath.row >= self.filteredMethods.count) {
        return cell;
    }
    
    NSDictionary *methodInfo = self.filteredMethods[indexPath.row];
    NSString *selName = methodInfo[@"name"] ?: @"?";
    
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    if (self.currentSearchText.length > 0) {
        NSString *searchText = self.currentSearchText.lowercaseString;
        NSString *lowerName = selName.lowercaseString;
        NSRange range = [lowerName rangeOfString:searchText];
        
        if (range.location != NSNotFound && range.length > 0) {
            NSMutableAttributedString *attrText = [[NSMutableAttributedString alloc]
                initWithString:selName
                attributes:@{NSFontAttributeName: [UIFont fontWithName:@"Menlo-Regular" size:13],
                             NSForegroundColorAttributeName: DYYYFLEXColor.primaryTextColor}];
            
            [attrText addAttribute:NSForegroundColorAttributeName
                             value:[UIColor colorWithRed:0.2 green:0.6 blue:1.0 alpha:1.0]
                             range:range];
            [attrText addAttribute:NSFontAttributeName
                             value:[UIFont fontWithName:@"Menlo-Bold" size:13]
                             range:range];
            
            cell.textLabel.attributedText = attrText;
        } else {
            cell.textLabel.attributedText = nil;
            cell.textLabel.text = selName;
            cell.textLabel.font = [UIFont fontWithName:@"Menlo-Regular" size:13];
            cell.textLabel.textColor = DYYYFLEXColor.primaryTextColor;
        }
    } else {
        cell.textLabel.attributedText = nil;
        cell.textLabel.text = selName;
        cell.textLabel.font = [UIFont fontWithName:@"Menlo-Regular" size:13];
        cell.textLabel.textColor = DYYYFLEXColor.primaryTextColor;
    }
    
    cell.selectedBackgroundView = [[UIView alloc] init];
    cell.selectedBackgroundView.backgroundColor = [DYYYFLEXColor secondaryBackgroundColorWithAlpha:0.5];
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.row >= self.filteredMethods.count) {
        return;
    }
    
    NSDictionary *methodInfo = self.filteredMethods[indexPath.row];
    NSString *selName = methodInfo[@"name"] ?: @"?";
    NSValue *impValue = methodInfo[@"imp"];
    IMP imp = NULL;
    
    if (impValue) {
        imp = [impValue pointerValue];
    }
    
    if (!imp) {
        UIAlertController *alert = [UIAlertController
            alertControllerWithTitle:@"提示"
            message:@"无法获取方法实现地址，该方法可能是抽象方法或动态方法"
            preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    NSString *title = [NSString stringWithFormat:@"%@[%@ %@]",
                       self.isClassMethod ? @"+" : @"-",
                       self.className, selName];
    
    DYYYUCDisasmViewController *disasmVC = [[DYYYUCDisasmViewController alloc]
        initWithAddress:(uint64_t)imp
                   size:4096
                  title:title];
    
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:disasmVC];
    nav.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:nav animated:YES completion:nil];
}

@end
