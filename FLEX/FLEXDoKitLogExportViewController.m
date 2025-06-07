#import "FLEXDoKitLogExportViewController.h"
#import "FLEXCompatibility.h"
#import "FLEXDoKitLogViewer.h"

@interface FLEXDoKitLogExportViewController ()
@property (nonatomic, strong) UITextView *previewTextView;
@property (nonatomic, strong) UIButton *exportButton;
@property (nonatomic, strong) UIButton *shareButton;
@end

@implementation FLEXDoKitLogExportViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"日志导出";
    self.view.backgroundColor = FLEXSystemBackgroundColor;
    
    [self setupUI];
    [self loadLogPreview];
}

- (void)setupUI {
    // 预览文本视图
    self.previewTextView = [[UITextView alloc] init];
    self.previewTextView.editable = NO;
    self.previewTextView.font = [UIFont fontWithName:@"Menlo" size:12];
    self.previewTextView.backgroundColor = [UIColor secondarySystemBackgroundColor];
    
    // 导出按钮
    self.exportButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.exportButton setTitle:@"导出到文件" forState:UIControlStateNormal];
    self.exportButton.backgroundColor = [UIColor systemBlueColor];
    [self.exportButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.exportButton.layer.cornerRadius = 8;
    [self.exportButton addTarget:self action:@selector(exportToFile) forControlEvents:UIControlEventTouchUpInside];
    
    // 分享按钮
    self.shareButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.shareButton setTitle:@"分享日志" forState:UIControlStateNormal];
    self.shareButton.backgroundColor = [UIColor systemGreenColor];
    [self.shareButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.shareButton.layer.cornerRadius = 8;
    [self.shareButton addTarget:self action:@selector(shareLog) forControlEvents:UIControlEventTouchUpInside];
    
    // 布局
    [self.view addSubview:self.previewTextView];
    [self.view addSubview:self.exportButton];
    [self.view addSubview:self.shareButton];
    
    self.previewTextView.translatesAutoresizingMaskIntoConstraints = NO;
    self.exportButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.shareButton.translatesAutoresizingMaskIntoConstraints = NO;
    
    [NSLayoutConstraint activateConstraints:@[
        [self.previewTextView.topAnchor constraintEqualToAnchor:FLEXSafeAreaTopAnchor(self) constant:10],
        [self.previewTextView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:10],
        [self.previewTextView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-10],
        [self.previewTextView.bottomAnchor constraintEqualToAnchor:self.exportButton.topAnchor constant:-20],
        
        [self.exportButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.exportButton.trailingAnchor constraintEqualToAnchor:self.view.centerXAnchor constant:-10],
        [self.exportButton.heightAnchor constraintEqualToConstant:44],
        [self.exportButton.bottomAnchor constraintEqualToAnchor:FLEXSafeAreaBottomAnchor(self) constant:-20],
        
        [self.shareButton.leadingAnchor constraintEqualToAnchor:self.view.centerXAnchor constant:10],
        [self.shareButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.shareButton.heightAnchor constraintEqualToConstant:44],
        [self.shareButton.bottomAnchor constraintEqualToAnchor:FLEXSafeAreaBottomAnchor(self) constant:-20],
    ]];
}

- (void)loadLogPreview {
    FLEXDoKitLogViewer *logViewer = [FLEXDoKitLogViewer sharedInstance];
    NSArray *logs = logViewer.logEntries;
    
    NSMutableString *logContent = [NSMutableString string];
    for (NSDictionary *log in logs) {
        NSString *timestamp = log[@"timestamp"] ?: @"";
        NSString *level = log[@"level"] ?: @"INFO";
        NSString *message = log[@"message"] ?: @"";
        
        [logContent appendFormat:@"[%@] %@: %@\n", timestamp, level, message];
    }
    
    self.previewTextView.text = logContent;
}

- (void)exportToFile {
    NSString *logContent = self.previewTextView.text;
    NSString *fileName = [NSString stringWithFormat:@"flex_logs_%@.txt", 
                         [self currentTimeString]];
    
    // 保存到Documents目录
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = paths.firstObject;
    NSString *filePath = [documentsDirectory stringByAppendingPathComponent:fileName];
    
    NSError *error;
    BOOL success = [logContent writeToFile:filePath 
                                atomically:YES 
                                  encoding:NSUTF8StringEncoding 
                                     error:&error];
    
    if (success) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"导出成功" 
                                                                       message:[NSString stringWithFormat:@"日志已保存到:\n%@", filePath]
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    } else {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"导出失败" 
                                                                       message:error.localizedDescription
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (void)shareLog {
    NSString *logContent = self.previewTextView.text;
    
    UIActivityViewController *activityVC = [[UIActivityViewController alloc] 
                                           initWithActivityItems:@[logContent] 
                                           applicationActivities:nil];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        activityVC.popoverPresentationController.sourceView = self.shareButton;
        activityVC.popoverPresentationController.sourceRect = self.shareButton.bounds;
    }
    
    [self presentViewController:activityVC animated:YES completion:nil];
}

- (NSString *)currentTimeString {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd_HH-mm-ss";
    return [formatter stringFromDate:[NSDate date]];
}

@end