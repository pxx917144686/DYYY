//
//  FLEXH5DoorViewController.m
//  FLEX
//
//  Created for DoKit integration
//

#import "FLEXH5DoorViewController.h"
#import "FLEXAlert.h"

@interface FLEXH5DoorViewController () <UITextFieldDelegate>

@property (nonatomic, strong) UITextField *urlTextField;
@property (nonatomic, strong) NSMutableArray<NSString *> *historyURLs;

@end

@implementation FLEXH5DoorViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"H5任意门";
    
    // 加载历史记录
    self.historyURLs = [NSMutableArray arrayWithArray:[[NSUserDefaults standardUserDefaults] objectForKey:@"FLEX_H5DoorHistory"] ?: @[]];
    
    // 设置导航栏按钮
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] 
        initWithBarButtonSystemItem:UIBarButtonSystemItemAdd 
        target:self 
        action:@selector(addNewURL)];
    
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"URLCell"];
}

- (void)addNewURL {
    [FLEXAlert makeAlert:^(FLEXAlert *make) {
        make.title(@"输入URL");
        make.configuredTextField(^(UITextField *textField) {
            textField.placeholder = @"https://example.com";
            textField.keyboardType = UIKeyboardTypeURL;
            textField.autocorrectionType = UITextAutocorrectionTypeNo;
            textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
            self.urlTextField = textField;
        });
        
        make.button(@"打开").handler(^(NSArray<NSString *> *strings) {
            NSString *url = self.urlTextField.text;
            if (url.length > 0) {
                // 保存到历史记录
                if (![self.historyURLs containsObject:url]) {
                    [self.historyURLs insertObject:url atIndex:0];
                    // 限制历史记录数量
                    if (self.historyURLs.count > 20) {
                        [self.historyURLs removeLastObject];
                    }
                    [[NSUserDefaults standardUserDefaults] setObject:self.historyURLs forKey:@"FLEX_H5DoorHistory"];
                    [[NSUserDefaults standardUserDefaults] synchronize];
                    [self.tableView reloadData];
                }
                
                // 打开URL
                [self openURL:url];
            }
        });
        
        make.button(@"取消").cancelStyle();
    } showFrom:self];
}

- (void)openURL:(NSString *)urlString {
    // 验证并标准化URL
    if (![urlString hasPrefix:@"http://"] && ![urlString hasPrefix:@"https://"]) {
        urlString = [@"https://" stringByAppendingString:urlString];
    }
    
    NSURL *url = [NSURL URLWithString:urlString];
    if (url) {
        // 使用SFSafariViewController或直接打开URL
        if (@available(iOS 9.0, *)) {
            // 此处应使用SFSafariViewController，但需要导入SafariServices框架
            // 简化起见，直接使用openURL方式
            [[UIApplication sharedApplication] openURL:url];
        } else {
            [[UIApplication sharedApplication] openURL:url];
        }
    } else {
        [FLEXAlert showAlert:@"无效URL" message:@"请输入有效的URL地址" from:self];
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.historyURLs.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"URLCell" forIndexPath:indexPath];
    
    cell.textLabel.text = self.historyURLs[indexPath.row];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSString *urlString = self.historyURLs[indexPath.row];
    [self openURL:urlString];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [self.historyURLs removeObjectAtIndex:indexPath.row];
        [[NSUserDefaults standardUserDefaults] setObject:self.historyURLs forKey:@"FLEX_H5DoorHistory"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }
}

@end