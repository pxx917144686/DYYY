//
//  UCDisasmViewController.m
//  FLEX++
//
//  反汇编查看器实现
//  稳定版：tableHeaderView搜索栏
//

#import "UCDisasmViewController.h"
#import "UCDisassembler.h"
#import "FLEXColor.h"
#import <mach-o/dyld.h>
#import <objc/runtime.h>

@interface UCDisasmViewController () <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, strong) UILabel *statusLabel;

@property (nonatomic, strong) NSArray *allInstructions;
@property (nonatomic, strong) NSArray *filteredInstructions;
@property (nonatomic, copy) NSString *currentSearchText;

@property (nonatomic, assign) uint64_t startAddress;
@property (nonatomic, assign) NSUInteger codeSize;
@property (nonatomic, copy) NSString *navTitle;

@property (nonatomic, assign) BOOL showBytes;

@end

@implementation UCDisasmViewController

#pragma mark - 初始化

- (instancetype)initWithAddress:(uint64_t)address size:(NSUInteger)size title:(NSString *)title {
    self = [super init];
    if (self) {
        _startAddress = address;
        _codeSize = size;
        _navTitle = title ?: [NSString stringWithFormat:@"0x%llx", address];
        _showBytes = YES;
        _currentSearchText = @"";
    }
    return self;
}

- (instancetype)initWithMethod:(Method)method class:(NSString *)className selector:(NSString *)selectorName {
    if (!method) return nil;
    
    IMP imp = method_getImplementation(method);
    NSString *title = [NSString stringWithFormat:@"%@ %@",
                       className ?: @"Unknown",
                       selectorName ?: @"unknown"];
    
    return [self initWithAddress:(uint64_t)imp size:4096 title:title];
}

- (instancetype)initWithClass:(Class)cls selector:(SEL)selector isClassMethod:(BOOL)isClassMethod {
    if (!cls || !selector) return nil;
    
    Method method = NULL;
    if (isClassMethod) {
        method = class_getClassMethod(cls, selector);
    } else {
        method = class_getInstanceMethod(cls, selector);
    }
    
    NSString *className = NSStringFromClass(cls);
    NSString *selName = NSStringFromSelector(selector);
    NSString *title = [NSString stringWithFormat:@"%@%@ %@",
                       isClassMethod ? @"+" : @"-",
                       className,
                       selName];
    
    return [self initWithMethod:method class:className selector:selName];
}

#pragma mark - 生命周期

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = FLEXColor.primaryBackgroundColor;
    self.title = self.navTitle;
    
    // 导航栏按钮
    UIBarButtonItem *done = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemDone
        target:self
        action:@selector(doneAction)];
    
    UIBarButtonItem *action = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemAction
        target:self
        action:@selector(actionButtonTapped)];
    
    self.navigationItem.rightBarButtonItems = @[done, action];
    
    // 搜索栏
    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
    [self.searchBar sizeToFit];
    self.searchBar.frame = CGRectMake(0, 0, self.view.bounds.size.width, self.searchBar.frame.size.height);
    self.searchBar.delegate = self;
    self.searchBar.placeholder = @"搜索指令、地址...";
    self.searchBar.backgroundColor = FLEXColor.primaryBackgroundColor;
    self.searchBar.searchBarStyle = UISearchBarStyleMinimal;
    self.searchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.searchBar.autocorrectionType = UITextAutocorrectionTypeNo;
    self.searchBar.tintColor = [UIColor colorWithRed:0.2 green:0.6 blue:1.0 alpha:1.0];
    self.searchBar.showsCancelButton = YES;
    
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
    
    // 表格
    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0,
        self.view.bounds.size.width, self.view.bounds.size.height - statusBarHeight)
                                                      style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.backgroundColor = FLEXColor.primaryBackgroundColor;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.rowHeight = 28;
    self.tableView.hidden = YES;
    self.tableView.tableHeaderView = self.searchBar;
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"DisasmCell"];
    [self.view addSubview:self.tableView];
    
    // 后台执行反汇编
    [self performDisassembly];
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

#pragma mark - 反汇编

- (void)performDisassembly {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        UCDisassembler *disasm = [UCDisassembler sharedInstance];
        UCDisasmResult *result = [disasm disassembleAtAddress:self.startAddress size:self.codeSize];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.loadingIndicator stopAnimating];
            self.tableView.hidden = NO;
            
            if (result && result.instructions.count > 0) {
                self.allInstructions = result.instructions;
                self.filteredInstructions = result.instructions;
                [self.tableView reloadData];
                [self updateStatusLabel];
                
                // 滚动到顶部
                if (self.allInstructions.count > 0) {
                    [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]
                                          atScrollPosition:UITableViewScrollPositionTop
                                                  animated:NO];
                }
            } else {
                self.statusLabel.text = [NSString stringWithFormat:
                    @"无法反汇编地址 0x%llx (引擎: %@)",
                    self.startAddress, disasm.engineName];
            }
        });
    });
}

- (void)updateStatusLabel {
    NSString *engine = [UCDisassembler sharedInstance].engineName;
    NSUInteger total = self.allInstructions.count;
    NSUInteger filtered = self.filteredInstructions.count;
    
    if (self.currentSearchText.length > 0) {
        self.statusLabel.text = [NSString stringWithFormat:
            @"%lu / %lu 指令 | 引擎: %@",
            (unsigned long)filtered, (unsigned long)total, engine];
    } else {
        self.statusLabel.text = [NSString stringWithFormat:
            @"共 %lu 条指令 | 引擎: %@",
            (unsigned long)total, engine];
    }
}

#pragma mark - 操作

- (void)doneAction {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)actionButtonTapped {
    UIAlertController *actionSheet = [UIAlertController
        alertControllerWithTitle:@"操作"
        message:nil
        preferredStyle:UIAlertControllerStyleActionSheet];
    
    // 切换显示字节
    NSString *byteTitle = self.showBytes ? @"隐藏机器码" : @"显示机器码";
    [actionSheet addAction:[UIAlertAction actionWithTitle:byteTitle
                                                    style:UIAlertActionStyleDefault
                                                  handler:^(UIAlertAction * _Nonnull action) {
        self.showBytes = !self.showBytes;
        [self.tableView reloadData];
    }]];
    
    // 复制全部
    [actionSheet addAction:[UIAlertAction actionWithTitle:@"复制全部反汇编"
                                                    style:UIAlertActionStyleDefault
                                                  handler:^(UIAlertAction * _Nonnull action) {
        [self copyAllDisassembly];
    }]];
    
    // 跳转到地址
    [actionSheet addAction:[UIAlertAction actionWithTitle:@"跳转到地址..."
                                                    style:UIAlertActionStyleDefault
                                                  handler:^(UIAlertAction * _Nonnull action) {
        [self showJumpToAddressDialog];
    }]];
    
    // 显示函数信息
    [actionSheet addAction:[UIAlertAction actionWithTitle:@"函数信息"
                                                    style:UIAlertActionStyleDefault
                                                  handler:^(UIAlertAction * _Nonnull action) {
        [self showFunctionInfo];
    }]];
    
    [actionSheet addAction:[UIAlertAction actionWithTitle:@"取消"
                                                    style:UIAlertActionStyleCancel
                                                  handler:nil]];
    
    actionSheet.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItems.lastObject;
    
    [self presentViewController:actionSheet animated:YES completion:nil];
}

- (void)copyAllDisassembly {
    NSMutableString *text = [NSMutableString string];
    [text appendFormat:@"// Disassembly of %@\n", self.navTitle];
    [text appendFormat:@"// Engine: %@\n\n", [UCDisassembler sharedInstance].engineName];
    
    for (UCDisasmInstruction *insn in self.allInstructions) {
        if (self.showBytes && insn.bytesHex.length > 0) {
            [text appendFormat:@"0x%llx:  %-24s  %@\n",
             insn.address,
             insn.bytesHex.UTF8String,
             insn.fullText];
        } else {
            [text appendFormat:@"0x%llx:  %@\n",
             insn.address,
             insn.fullText];
        }
    }
    
    UIPasteboard.generalPasteboard.string = text;
    
    UILabel *toast = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 160, 40)];
    toast.center = CGPointMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2);
    toast.backgroundColor = [UIColor colorWithWhite:0 alpha:0.8];
    toast.textColor = [UIColor whiteColor];
    toast.textAlignment = NSTextAlignmentCenter;
    toast.font = [UIFont systemFontOfSize:14];
    toast.text = @"已复制到剪贴板";
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

- (void)showJumpToAddressDialog {
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"跳转到地址"
        message:@"输入十六进制地址（如 0x100001234）"
        preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"0x...";
        textField.keyboardType = UIKeyboardTypeASCIICapable;
        textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        textField.autocorrectionType = UITextAutocorrectionTypeNo;
    }];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"跳转" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *addrStr = alert.textFields.firstObject.text;
        if (addrStr.length == 0) return;
        
        unsigned long long addr = 0;
        NSScanner *scanner = [NSScanner scannerWithString:addrStr];
        [scanner scanHexLongLong:&addr];
        
        if (addr > 0) {
            [self jumpToAddress:(uint64_t)addr];
        }
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)jumpToAddress:(uint64_t)address {
    // 二分查找最接近的指令
    NSArray *instructions = self.allInstructions;
    if (instructions.count == 0) return;
    
    NSUInteger left = 0;
    NSUInteger right = instructions.count - 1;
    
    while (left <= right) {
        NSUInteger mid = (left + right) / 2;
        UCDisasmInstruction *insn = instructions[mid];
        
        if (insn.address == address) {
            [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:mid inSection:0]
                                  atScrollPosition:UITableViewScrollPositionMiddle
                                          animated:YES];
            return;
        } else if (insn.address < address) {
            left = mid + 1;
        } else {
            if (mid == 0) break;
            right = mid - 1;
        }
    }
    
    // 滚动到最接近的位置
    NSUInteger targetIndex = MIN(right, instructions.count - 1);
    [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:targetIndex inSection:0]
                          atScrollPosition:UITableViewScrollPositionMiddle
                                  animated:YES];
}

- (void)showFunctionInfo {
    uint64_t addr = self.startAddress;
    NSString *symbol = [UCDisassembler symbolNameAtAddress:addr];
    
    NSMutableString *info = [NSMutableString string];
    [info appendFormat:@"起始地址: 0x%llx\n", addr];
    [info appendFormat:@"指令数: %lu\n", (unsigned long)self.allInstructions.count];
    [info appendFormat:@"反汇编引擎: %@\n", [UCDisassembler sharedInstance].engineName];
    
    if (symbol) {
        [info appendFormat:@"符号名: %@\n", symbol];
    }
    
    // 获取所在镜像
    const char *imagePath = NULL;
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const struct mach_header *header = _dyld_get_image_header(i);
        intptr_t slide = _dyld_get_image_vmaddr_slide(i);
        
        uint64_t imageStart = (uint64_t)header + slide;
        // 粗略估算
        if (addr >= imageStart && addr < imageStart + 0x10000000) {
            imagePath = _dyld_get_image_name(i);
            break;
        }
    }
    
    if (imagePath) {
        [info appendFormat:@"镜像: %s\n", imagePath];
    }
    
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"函数信息"
        message:info
        preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    self.currentSearchText = searchText;
    [self filterWithText:searchText];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    searchBar.text = @"";
    self.currentSearchText = @"";
    self.filteredInstructions = self.allInstructions;
    [self.tableView reloadData];
    [self updateStatusLabel];
    [searchBar resignFirstResponder];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

- (void)filterWithText:(NSString *)searchText {
    if (searchText.length == 0) {
        self.filteredInstructions = self.allInstructions;
    } else {
        NSString *lower = searchText.lowercaseString;
        NSMutableArray *filtered = [NSMutableArray array];
        
        for (UCDisasmInstruction *insn in self.allInstructions) {
            BOOL match = NO;
            
            // 搜索助记符
            if (insn.mnemonic.lowercaseString && [insn.mnemonic.lowercaseString containsString:lower]) {
                match = YES;
            }
            // 搜索操作数
            else if (insn.operands.lowercaseString && [insn.operands.lowercaseString containsString:lower]) {
                match = YES;
            }
            // 搜索地址
            else if ([insn.fullText.lowercaseString containsString:lower]) {
                match = YES;
            }
            
            if (match) {
                [filtered addObject:insn];
            }
        }
        
        self.filteredInstructions = filtered;
    }
    
    [self.tableView reloadData];
    [self updateStatusLabel];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.filteredInstructions.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"DisasmCell" forIndexPath:indexPath];
    
    if (indexPath.row >= self.filteredInstructions.count) {
        return cell;
    }
    
    UCDisasmInstruction *insn = self.filteredInstructions[indexPath.row];
    
    NSMutableString *text = [NSMutableString string];
    
    // 地址
    [text appendFormat:@"0x%016llx  ", insn.address];
    
    // 机器码
    if (self.showBytes) {
        NSString *bytes = insn.bytesHex ?: @"";
        [text appendFormat:@"%-24s", bytes.UTF8String];
    }
    
    // 指令
    if (insn.isValid) {
        NSString *mnemonic = insn.mnemonic ?: @"";
        NSString *operands = insn.operands ?: @"";
        
        // 分支指令用不同颜色
        if (insn.isCall) {
            // 调用指令 - 蓝色
            cell.textLabel.textColor = [UIColor colorWithRed:0.2 green:0.6 blue:1.0 alpha:1.0];
        } else if (insn.isReturn) {
            // 返回指令 - 红色
            cell.textLabel.textColor = [UIColor colorWithRed:1.0 green:0.4 blue:0.4 alpha:1.0];
        } else if (insn.isBranch) {
            // 分支指令 - 紫色
            cell.textLabel.textColor = [UIColor colorWithRed:0.8 green:0.4 blue:1.0 alpha:1.0];
        } else {
            cell.textLabel.textColor = FLEXColor.primaryTextColor;
        }
        
        [text appendFormat:@"%@    %@", mnemonic, operands];
    } else {
        cell.textLabel.textColor = [UIColor colorWithWhite:0.5 alpha:1.0];
        [text appendString:insn.fullText ?: @"??"];
    }
    
    cell.textLabel.text = text;
    cell.textLabel.font = [UIFont fontWithName:@"Menlo-Regular" size:11];
    cell.backgroundColor = indexPath.row % 2 == 0 ?
        FLEXColor.primaryBackgroundColor :
        [FLEXColor secondaryBackgroundColorWithAlpha:0.2];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.row >= self.filteredInstructions.count) {
        return;
    }
    
    UCDisasmInstruction *insn = self.filteredInstructions[indexPath.row];
    
    NSMutableString *detail = [NSMutableString string];
    [detail appendFormat:@"地址: 0x%llx\n", insn.address];
    [detail appendFormat:@"大小: %lu 字节\n", (unsigned long)insn.size];
    [detail appendFormat:@"机器码: %@\n", insn.bytesHex ?: @""];
    [detail appendFormat:@"指令: %@\n", insn.fullText ?: @""];
    [detail appendFormat:@"助记符: %@\n", insn.mnemonic ?: @""];
    [detail appendFormat:@"操作数: %@\n", insn.operands ?: @""];
    
    if (insn.isBranch && insn.branchTarget > 0) {
        [detail appendFormat:@"分支目标: 0x%llx\n", insn.branchTarget];
    }
    
    NSString *symbol = [UCDisassembler symbolNameAtAddress:insn.address];
    if (symbol) {
        [detail appendFormat:@"符号: %@\n", symbol];
    }
    
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"指令详情"
        message:detail
        preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"复制地址"
                                             style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction * _Nonnull action) {
        UIPasteboard.generalPasteboard.string =
            [NSString stringWithFormat:@"0x%llx", insn.address];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"复制指令"
                                             style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction * _Nonnull action) {
        UIPasteboard.generalPasteboard.string = insn.fullText ?: @"";
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"确定"
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

@end
