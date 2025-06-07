#import "FLEXDoKitH5ViewController.h"
#import "FLEXCompatibility.h"

@interface FLEXDoKitH5ViewController () <WKNavigationDelegate>
@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) UITextField *urlTextField;
@property (nonatomic, strong) UIButton *loadButton;
@property (nonatomic, strong) UIProgressView *progressView;
@property (nonatomic, assign) BOOL isObservingProgress; // ✅ 添加观察状态标记
@end

@implementation FLEXDoKitH5ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"H5任意门";
    self.view.backgroundColor = FLEXSystemBackgroundColor;
    
    [self setupUI];
    [self setupDefaultURLs];
    
    // ✅ 安全添加KVO观察者
    if (!self.isObservingProgress) {
        [self.webView addObserver:self 
                       forKeyPath:@"estimatedProgress" 
                          options:NSKeyValueObservingOptionNew 
                          context:NULL];
        self.isObservingProgress = YES;
    }
}

- (void)setupUI {
    // URL输入框
    self.urlTextField = [[UITextField alloc] init];
    self.urlTextField.placeholder = @"请输入H5页面URL";
    self.urlTextField.borderStyle = UITextBorderStyleRoundedRect;
    self.urlTextField.keyboardType = UIKeyboardTypeURL;
    self.urlTextField.returnKeyType = UIReturnKeyGo;
    [self.urlTextField addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    
    // 加载按钮
    self.loadButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.loadButton setTitle:@"加载" forState:UIControlStateNormal];
    self.loadButton.backgroundColor = [UIColor systemBlueColor];
    [self.loadButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.loadButton.layer.cornerRadius = 8;
    [self.loadButton addTarget:self action:@selector(loadButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    
    // 进度条
    self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    self.progressView.hidden = YES;
    
    // WebView
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    self.webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:config];
    self.webView.navigationDelegate = self;
    
    // 布局
    [self.view addSubview:self.urlTextField];
    [self.view addSubview:self.loadButton];
    [self.view addSubview:self.progressView];
    [self.view addSubview:self.webView];
    
    self.urlTextField.translatesAutoresizingMaskIntoConstraints = NO;
    self.loadButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.progressView.translatesAutoresizingMaskIntoConstraints = NO;
    self.webView.translatesAutoresizingMaskIntoConstraints = NO;
    
    [NSLayoutConstraint activateConstraints:@[
        // URL输入框
        [self.urlTextField.topAnchor constraintEqualToAnchor:FLEXSafeAreaTopAnchor(self) constant:10],
        [self.urlTextField.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.urlTextField.trailingAnchor constraintEqualToAnchor:self.loadButton.leadingAnchor constant:-10],
        [self.urlTextField.heightAnchor constraintEqualToConstant:44],
        
        // 加载按钮
        [self.loadButton.centerYAnchor constraintEqualToAnchor:self.urlTextField.centerYAnchor],
        [self.loadButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [self.loadButton.widthAnchor constraintEqualToConstant:60],
        [self.loadButton.heightAnchor constraintEqualToConstant:44],
        
        // 进度条
        [self.progressView.topAnchor constraintEqualToAnchor:self.urlTextField.bottomAnchor constant:5],
        [self.progressView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.progressView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        
        // WebView
        [self.webView.topAnchor constraintEqualToAnchor:self.progressView.bottomAnchor constant:5],
        [self.webView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.webView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.webView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (void)setupDefaultURLs {
    // 添加一些常用的测试URL
    self.urlTextField.text = @"https://m.baidu.com";
}

- (void)loadButtonTapped {
    NSString *urlString = self.urlTextField.text;
    if (urlString.length == 0) {
        return;
    }
    
    // 自动添加协议
    if (![urlString hasPrefix:@"http://"] && ![urlString hasPrefix:@"https://"]) {
        urlString = [@"https://" stringByAppendingString:urlString];
    }
    
    NSURL *url = [NSURL URLWithString:urlString];
    if (url) {
        NSURLRequest *request = [NSURLRequest requestWithURL:url];
        [self.webView loadRequest:request];
    }
}

- (void)textFieldDidChange:(UITextField *)textField {
    // 可以实现实时搜索建议等功能
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    self.progressView.hidden = NO;
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    self.progressView.hidden = YES;
    self.title = webView.title ?: @"H5任意门";
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    self.progressView.hidden = YES;
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"加载失败" 
                                                                   message:error.localizedDescription 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:@"estimatedProgress"]) {
        self.progressView.progress = self.webView.estimatedProgress;
    }
}

- (void)dealloc {
    // ✅ 确保移除观察者
    if (self.isObservingProgress) {
        @try {
            [self.webView removeObserver:self forKeyPath:@"estimatedProgress"];
        } @catch (NSException *exception) {
            NSLog(@"⚠️ 移除KVO观察者异常: %@", exception.reason);
        }
        self.isObservingProgress = NO;
    }
    
    NSLog(@"🗑️ FLEXDoKitH5ViewController 已释放");
}

@end