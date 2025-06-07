#import "FLEXAPITestViewController.h"

@interface FLEXAPITestViewController () <UITextViewDelegate>
@property (nonatomic, strong) UITextView *urlTextView;
@property (nonatomic, strong) UISegmentedControl *methodSegment;
@property (nonatomic, strong) UITextView *headersTextView;
@property (nonatomic, strong) UITextView *bodyTextView;
@property (nonatomic, strong) UITextView *responseTextView;
@property (nonatomic, strong) UIButton *sendButton;
@end

@implementation FLEXAPITestViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"API测试";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    
    [self setupUI];
}

- (void)setupUI {
    // URL输入
    UILabel *urlLabel = [[UILabel alloc] init];
    urlLabel.text = @"URL:";
    urlLabel.font = [UIFont boldSystemFontOfSize:16];
    
    self.urlTextView = [[UITextView alloc] init];
    self.urlTextView.font = [UIFont systemFontOfSize:14];
    self.urlTextView.layer.borderWidth = 1;
    self.urlTextView.layer.borderColor = [UIColor lightGrayColor].CGColor;
    self.urlTextView.layer.cornerRadius = 8;
    self.urlTextView.text = @"https://httpbin.org/json";
    
    // HTTP方法选择
    UILabel *methodLabel = [[UILabel alloc] init];
    methodLabel.text = @"方法:";
    methodLabel.font = [UIFont boldSystemFontOfSize:16];
    
    self.methodSegment = [[UISegmentedControl alloc] initWithItems:@[@"GET", @"POST", @"PUT", @"DELETE"]];
    self.methodSegment.selectedSegmentIndex = 0;
    
    // 请求头
    UILabel *headersLabel = [[UILabel alloc] init];
    headersLabel.text = @"请求头 (JSON格式):";
    headersLabel.font = [UIFont boldSystemFontOfSize:16];
    
    self.headersTextView = [[UITextView alloc] init];
    self.headersTextView.font = [UIFont systemFontOfSize:14];
    self.headersTextView.layer.borderWidth = 1;
    self.headersTextView.layer.borderColor = [UIColor lightGrayColor].CGColor;
    self.headersTextView.layer.cornerRadius = 8;
    self.headersTextView.text = @"{\n  \"Content-Type\": \"application/json\"\n}";
    
    // 请求体
    UILabel *bodyLabel = [[UILabel alloc] init];
    bodyLabel.text = @"请求体:";
    bodyLabel.font = [UIFont boldSystemFontOfSize:16];
    
    self.bodyTextView = [[UITextView alloc] init];
    self.bodyTextView.font = [UIFont systemFontOfSize:14];
    self.bodyTextView.layer.borderWidth = 1;
    self.bodyTextView.layer.borderColor = [UIColor lightGrayColor].CGColor;
    self.bodyTextView.layer.cornerRadius = 8;
    self.bodyTextView.text = @"{\n  \"test\": \"data\"\n}";
    
    // 发送按钮
    self.sendButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.sendButton setTitle:@"发送请求" forState:UIControlStateNormal];
    self.sendButton.backgroundColor = [UIColor systemBlueColor];
    [self.sendButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.sendButton.layer.cornerRadius = 8;
    [self.sendButton addTarget:self action:@selector(sendRequest) forControlEvents:UIControlEventTouchUpInside];
    
    // 响应结果
    UILabel *responseLabel = [[UILabel alloc] init];
    responseLabel.text = @"响应结果:";
    responseLabel.font = [UIFont boldSystemFontOfSize:16];
    
    self.responseTextView = [[UITextView alloc] init];
    self.responseTextView.font = [UIFont fontWithName:@"Courier" size:12];
    self.responseTextView.layer.borderWidth = 1;
    self.responseTextView.layer.borderColor = [UIColor lightGrayColor].CGColor;
    self.responseTextView.layer.cornerRadius = 8;
    self.responseTextView.editable = NO;
    self.responseTextView.backgroundColor = [UIColor colorWithRed:0.95 green:0.95 blue:0.95 alpha:1.0];
    
    // 创建滚动视图和堆栈视图
    UIScrollView *scrollView = [[UIScrollView alloc] init];
    UIStackView *stackView = [[UIStackView alloc] initWithArrangedSubviews:@[
        urlLabel, self.urlTextView,
        methodLabel, self.methodSegment,
        headersLabel, self.headersTextView,
        bodyLabel, self.bodyTextView,
        self.sendButton,
        responseLabel, self.responseTextView
    ]];
    
    stackView.axis = UILayoutConstraintAxisVertical;
    stackView.spacing = 8;
    
    [scrollView addSubview:stackView];
    [self.view addSubview:scrollView];
    
    // 约束
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    stackView.translatesAutoresizingMaskIntoConstraints = NO;
    
    [NSLayoutConstraint activateConstraints:@[
        [scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        
        [stackView.topAnchor constraintEqualToAnchor:scrollView.topAnchor constant:16],
        [stackView.leadingAnchor constraintEqualToAnchor:scrollView.leadingAnchor constant:16],
        [stackView.trailingAnchor constraintEqualToAnchor:scrollView.trailingAnchor constant:-16],
        [stackView.bottomAnchor constraintEqualToAnchor:scrollView.bottomAnchor constant:-16],
        [stackView.widthAnchor constraintEqualToAnchor:scrollView.widthAnchor constant:-32],
        
        [self.urlTextView.heightAnchor constraintEqualToConstant:60],
        [self.headersTextView.heightAnchor constraintEqualToConstant:80],
        [self.bodyTextView.heightAnchor constraintEqualToConstant:100],
        [self.sendButton.heightAnchor constraintEqualToConstant:44],
        [self.responseTextView.heightAnchor constraintEqualToConstant:200]
    ]];
}

- (void)sendRequest {
    // ✅ 修复：使用正确的方法调用
    NSString *urlString = [self.urlTextView.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (urlString.length == 0) {
        [self showAlert:@"请输入URL"];
        return;
    }
    
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        [self showAlert:@"URL格式错误"];
        return;
    }
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    
    // 设置HTTP方法
    NSString *method = [self.methodSegment titleForSegmentAtIndex:self.methodSegment.selectedSegmentIndex];
    request.HTTPMethod = method;
    
    // 设置请求头
    // ✅ 修复：使用正确的方法调用
    NSString *headersString = [self.headersTextView.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (headersString.length > 0) {
        NSError *error;
        NSDictionary *headers = [NSJSONSerialization JSONObjectWithData:[headersString dataUsingEncoding:NSUTF8StringEncoding]
                                                               options:0
                                                                 error:&error];
        if (headers && [headers isKindOfClass:[NSDictionary class]]) {
            for (NSString *key in headers.allKeys) {
                [request setValue:headers[key] forHTTPHeaderField:key];
            }
        } else if (error) {
            [self showAlert:[NSString stringWithFormat:@"请求头JSON格式错误: %@", error.localizedDescription]];
            return;
        }
    }
    
    // 设置请求体
    // ✅ 修复：使用正确的方法调用
    NSString *bodyString = [self.bodyTextView.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (bodyString.length > 0 && ![method isEqualToString:@"GET"]) {
        request.HTTPBody = [bodyString dataUsingEncoding:NSUTF8StringEncoding];
    }
    
    // 发送请求
    self.sendButton.enabled = NO;
    [self.sendButton setTitle:@"发送中..." forState:UIControlStateNormal];
    self.responseTextView.text = @"请求发送中...";
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.sendButton.enabled = YES;
            [self.sendButton setTitle:@"发送请求" forState:UIControlStateNormal];
            
            if (error) {
                self.responseTextView.text = [NSString stringWithFormat:@"请求失败:\n%@", error.localizedDescription];
            } else {
                NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                NSString *responseString = @"";
                
                if (data) {
                    responseString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    
                    // 尝试格式化JSON
                    NSError *jsonError;
                    id jsonObject = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
                    if (jsonObject && !jsonError) {
                        NSData *formattedData = [NSJSONSerialization dataWithJSONObject:jsonObject 
                                                                               options:NSJSONWritingPrettyPrinted 
                                                                                 error:nil];
                        if (formattedData) {
                            responseString = [[NSString alloc] initWithData:formattedData encoding:NSUTF8StringEncoding];
                        }
                    }
                }
                
                self.responseTextView.text = [NSString stringWithFormat:@"状态码: %ld\n\n响应内容:\n%@", 
                                            (long)httpResponse.statusCode, 
                                            responseString ?: @"(无响应数据)"];
            }
        });
    }];
    
    [task resume];
}

- (void)showAlert:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" 
                                                                   message:message 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end