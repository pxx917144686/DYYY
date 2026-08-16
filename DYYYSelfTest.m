#import "DYYYSelfTest.h"
#import "AwemeHeaders.h"
#import "DYYYManager.h"
#import "DYYYCityManager.h"
#import "DYYYToast.h"
#import "DYYYPipPlayer.h"
#import "DYYYScreenshot.h"
#import "DYYYFloatSpeedButton.h"
#import "DYYYCrashCatcher.h"
#import "DYYYPaths.h"
#ifndef DYYY_RELEASE_BUILD
#import "FLEX/x/Decrypt/DYYYDatabaseManager.h"
#endif
#import <objc/runtime.h>

// 城市库单参数属地方法（头文件仅声明 5 参数版，实际实现为单参数，与 DYYY.xm 用法一致）
@interface DYYYCityManager (DYYYSelfTestSingleParam)
- (NSString *)generateRandomFourLevelAddressForCityCode:(NSString *)cityCode;
@end

#pragma mark - 结果模型

@interface DYYYSelfTestResult : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) NSInteger status; // 0=通过 1=警告 2=失败
@property (nonatomic, copy) NSString *detail;
@end

@implementation DYYYSelfTestResult
@end

typedef DYYYSelfTestResult * (^DYYYSelfTestBlock)(void);

static DYYYSelfTestResult *DYYYMakeResult(NSString *name, NSInteger status, NSString *detail) {
    DYYYSelfTestResult *r = [[DYYYSelfTestResult alloc] init];
    r.name = name;
    r.status = status;
    r.detail = detail;
    return r;
}

// 类存在性检测辅助：全部存在=✅，部分缺失=⚠️（抖音版本差异属正常）
static DYYYSelfTestResult *DYYYCheckClasses(NSString *name, NSArray<NSString *> *classNames) {
    NSMutableString *missing = [NSMutableString string];
    for (NSString *className in classNames) {
        if (!NSClassFromString(className)) {
            [missing appendFormat:@"%@; ", className];
        }
    }
    if (missing.length == 0) {
        return DYYYMakeResult(name, 0, [NSString stringWithFormat:@"全部 %lu 个关键类存在", (unsigned long)classNames.count]);
    }
    return DYYYMakeResult(name, 1, [NSString stringWithFormat:@"缺失类: %@(部分缺失可能是抖音版本差异, 相关功能失效)", missing]);
}

#pragma mark - 测试项

// 1. 环境检测（真实版本字符串避开系统版本伪装 hook）
static DYYYSelfTestResult *DYYYTestEnvironment(void) {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier] ?: @"未知";
    NSString *process = [[NSProcessInfo processInfo] processName] ?: @"未知";
    // operatingSystemVersionString 未被伪装 hook 拦截，含真实 Build 号
    NSString *versionString = [[NSProcessInfo processInfo] operatingSystemVersionString];
    BOOL rootless = [[NSFileManager defaultManager] fileExistsAtPath:@"/var/jb"];

    id spoofObj = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYSpoofLiquidGlass"];
    BOOL spoofEnabled = spoofObj ? [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYSpoofLiquidGlass"] : YES;

#ifdef DYYY_RELEASE_BUILD
    NSString *buildType = @"发布版";
#else
    NSString *buildType = @"调试版";
#endif

    NSString *detail = [NSString stringWithFormat:
        @"bundleID=%@\n进程=%@\n真实系统版本: %@\nrootless=%@\n构建版本: %@\n系统版本伪装: %@",
        bundleID, process, versionString, rootless ? @"是(/var/jb)" : @"否", buildType,
        spoofEnabled ? @"开启(对外显示 26.0)" : @"关闭"];
    return DYYYMakeResult(@"环境检测", 0, detail);
}

// 2. 配置缓存读写与失效
static DYYYSelfTestResult *DYYYTestConfigCache(void) {
    NSString *probeKey = @"DYYYSelfTestProbe";
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:probeKey];
    BOOL cached = DYYYCachedBool(probeKey);

    DYYYConfigCacheInvalidate();
    BOOL reRead = DYYYCachedBool(probeKey);

    [[NSUserDefaults standardUserDefaults] removeObjectForKey:probeKey];
    DYYYConfigCacheInvalidate();

    if (cached && reRead) {
        return DYYYMakeResult(@"配置缓存", 0, @"写入/缓存命中/失效重读均正常");
    }
    return DYYYMakeResult(@"配置缓存", 2, [NSString stringWithFormat:@"异常 cached=%d reRead=%d", cached, reRead]);
}

// 3. 播放页 Hook 类
static DYYYSelfTestResult *DYYYTestPlaybackHooks(void) {
    return DYYYCheckClasses(@"播放页 Hook", @[
        @"AWEPlayInteractionViewController",
        @"AWEAwemePlayVideoViewController",
        @"AWEPlayInteractionTimestampElement",
        @"AWEStoryProgressContainerView",
        @"AWEPlayInteractionProgressContainerView",
        @"AWEDPlayerProgressContainerView",
        @"AWEPlayerPlayControlHandler"
    ]);
}

// 4. feed 功能类与配置
static DYYYSelfTestResult *DYYYTestFeedHooks(void) {
    DYYYSelfTestResult *classResult = DYYYCheckClasses(@"feed 功能", @[
        @"AWEFeedVideoButton",
        @"AWEListDataController",
        @"AWENormalModeTabBar",
        @"AWEAwemeModel"
    ]);
    if (classResult.status != 0) {
        return classResult;
    }
    BOOL noAds = DYYYCachedBool(@"DYYYNoAds");
    BOOL skipLive = DYYYCachedBool(@"DYYYisSkipLive");
    return DYYYMakeResult(@"feed 功能", 0,
        [NSString stringWithFormat:@"关键类全部存在; 去广告=%@, 过滤直播=%@", noAds ? @"开" : @"关", skipLive ? @"开" : @"关"]);
}

// 5. 倍速/清屏模块
static DYYYSelfTestResult *DYYYTestSpeedClear(void) {
    DYYYFloatingSpeedButton *button = getSpeedButton();
    BOOL clearButtonClassExists = NSClassFromString(@"DYYYFloatClearButton") != nil;
    BOOL speedEnabled = DYYYCachedBool(@"DYYYEnableFloatSpeedButton");
    BOOL clearEnabled = DYYYCachedBool(@"DYYYEnableFloatClearButton");

    NSString *detail = [NSString stringWithFormat:
        @"倍速按钮=%@(开关%@), 清屏按钮类=%@(开关%@)",
        button ? @"已创建" : @"未创建", speedEnabled ? @"开" : @"关",
        clearButtonClassExists ? @"存在" : @"缺失", clearEnabled ? @"开" : @"关"];

    // 特性分别校验：两开关全关是合法配置(功能未启用)，不判失败
    if (!clearButtonClassExists) {
        return DYYYMakeResult(@"倍速/清屏", 2, [NSString stringWithFormat:@"%@; 清屏按钮类缺失", detail]);
    }
    if (speedEnabled && !button) {
        return DYYYMakeResult(@"倍速/清屏", 1, [NSString stringWithFormat:@"%@; 倍速开启但按钮未创建(进入播放页后创建属正常)", detail]);
    }
    return DYYYMakeResult(@"倍速/清屏", 0, detail);
}

// 6. 长按面板/评论类
static DYYYSelfTestResult *DYYYTestPanelComment(void) {
    return DYYYCheckClasses(@"长按面板/评论", @[
        @"AWEModernLongPressPanelTableViewController",
        @"AWELongPressPanelManager",
        @"AWECommentPanelHeaderSwiftImpl.CommentHeaderGeneralView",
        @"AWECommentInputViewSwiftImpl.CommentInputContainerView"
    ]);
}

// 7. 下载/保存模块
static DYYYSelfTestResult *DYYYTestDownload(void) {
    DYYYManager *mgr = [DYYYManager shared];
    if (!mgr) {
        return DYYYMakeResult(@"下载/保存", 2, @"DYYYManager 单例为空");
    }
    NSMutableString *missing = [NSMutableString string];
    NSArray<NSString *> *selectors = @[
        @"saveMedia:mediaType:completion:",
        @"downloadMedia:mediaType:completion:",
        @"downloadLivePhoto:videoURL:completion:",
        @"createVideoFromMedia:livePhotos:bgmURL:progress:completion:",
        @"saveCommentImages:currentIndex:completion:"
    ];
    for (NSString *selName in selectors) {
        if (![mgr respondsToSelector:NSSelectorFromString(selName)]) {
            [missing appendFormat:@"%@; ", selName];
        }
    }
    if (missing.length == 0) {
        return DYYYMakeResult(@"下载/保存", 0, @"核心方法全部可用(下载/保存/实况/合成/评论图片)");
    }
    return DYYYMakeResult(@"下载/保存", 2, [NSString stringWithFormat:@"缺失方法: %@", missing]);
}

// 8. 城市属地
static DYYYSelfTestResult *DYYYTestCity(void) {
    DYYYCityManager *mgr = [DYYYCityManager sharedInstance];
    if (!mgr) {
        return DYYYMakeResult(@"城市属地", 2, @"DYYYCityManager 单例为空");
    }
    @try {
        NSString *addr = [mgr generateRandomFourLevelAddressForCityCode:@"110100"];
        NSString *customCode = DYYYCachedString(@"DYYYCustomCityCode");
        if (addr.length > 0) {
            return DYYYMakeResult(@"城市属地", 0,
                [NSString stringWithFormat:@"北京属地生成成功: %@\n自定义属地码: %@", addr, customCode.length ? customCode : @"(未设置)"]);
        }
        return DYYYMakeResult(@"城市属地", 2, @"地址生成为空");
    } @catch (NSException *e) {
        return DYYYMakeResult(@"城市属地", 2, [NSString stringWithFormat:@"异常: %@", e.reason]);
    }
}

// 9. 社交统计
static DYYYSelfTestResult *DYYYTestSocialStats(void) {
    DYYYSelfTestResult *classResult = DYYYCheckClasses(@"社交统计", @[
        @"AWEUserModel",
        @"AWEProfileSocialStatisticView"
    ]);
    if (classResult.status != 0) {
        return classResult;
    }
    BOOL enabled = DYYYCachedBool(@"DYYYEnableSocialStatsCustom");
    NSString *followers = DYYYCachedString(@"DYYYCustomFollowers");
    NSString *likes = DYYYCachedString(@"DYYYCustomLikes");
    return DYYYMakeResult(@"社交统计", 0,
        [NSString stringWithFormat:@"关键类存在; 开关=%@, 粉丝=%@, 获赞=%@",
         enabled ? @"开" : @"关",
         followers.length ? followers : @"(未设置)", likes.length ? likes : @"(未设置)"]);
}

// 10. 时间格式
static DYYYSelfTestResult *DYYYTestDateTime(void) {
    BOOL showDateTime = DYYYCachedBool(@"DYYYShowDateTime");
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
    });
    formatter.dateFormat = @"yyyy-MM-dd HH:mm";
    NSString *formatted = [formatter stringFromDate:[NSDate date]];
    if (formatted.length > 0) {
        return DYYYMakeResult(@"时间格式", 0,
            [NSString stringWithFormat:@"开关=%@, 格式化示例: %@", showDateTime ? @"开" : @"关", formatted]);
    }
    return DYYYMakeResult(@"时间格式", 2, @"NSDateFormatter 格式化失败");
}

// 11. 画中画
static DYYYSelfTestResult *DYYYTestPip(void) {
    if (!NSClassFromString(@"DYYYPipManager")) {
        return DYYYMakeResult(@"画中画", 2, @"DYYYPipManager 类缺失");
    }
    if ([DYYYPipManager respondsToSelector:@selector(handlePipButtonWithAwemeModel:)]) {
        return DYYYMakeResult(@"画中画", 0, @"DYYYPipManager 与处理入口可用");
    }
    return DYYYMakeResult(@"画中画", 2, @"缺少 handlePipButtonWithAwemeModel: 方法");
}

// 12. 截图
static DYYYSelfTestResult *DYYYTestScreenshot(void) {
    if (!NSClassFromString(@"DYYYScreenshot")) {
        return DYYYMakeResult(@"截图", 2, @"DYYYScreenshot 类缺失");
    }
    if ([DYYYScreenshot respondsToSelector:@selector(captureFullScreenshot:)] &&
        [DYYYScreenshot respondsToSelector:@selector(takeScreenshot)]) {
        return DYYYMakeResult(@"截图", 0, @"截屏/全屏捕获方法可用");
    }
    return DYYYMakeResult(@"截图", 2, @"截图方法缺失");
}

// 13. ABTest
static DYYYSelfTestResult *DYYYTestABTest(void) {
    Class mgrClass = NSClassFromString(@"AWEABTestManager");
    if (!mgrClass) {
        return DYYYMakeResult(@"ABTest", 1, @"AWEABTestManager 类缺失(该版本无此类属正常)");
    }
    if ([mgrClass instancesRespondToSelector:@selector(abTestData)]) {
        return DYYYMakeResult(@"ABTest", 0, @"AWEABTestManager 可用(仅检测, 未修改数据)");
    }
    return DYYYMakeResult(@"ABTest", 1, @"类存在但无 abTestData 方法");
}

// 14. 文件系统
static DYYYSelfTestResult *DYYYTestFileSystem(void) {
    NSString *dyyyPath = [DYYYPaths dyyyRootDir];
    NSError *err = nil;
    [[NSFileManager defaultManager] createDirectoryAtPath:dyyyPath withIntermediateDirectories:YES attributes:nil error:&err];
    if (err) {
        return DYYYMakeResult(@"文件系统", 2, [NSString stringWithFormat:@"创建 DYYY 目录失败: %@", err.localizedDescription]);
    }
    NSString *probeFile = [[DYYYPaths tempDir] stringByAppendingPathComponent:@".selftest"];
    [[NSFileManager defaultManager] createDirectoryAtPath:[DYYYPaths tempDir] withIntermediateDirectories:YES attributes:nil error:nil];
    BOOL writable = [@"ok" writeToFile:probeFile atomically:YES encoding:NSUTF8StringEncoding error:&err];
    [[NSFileManager defaultManager] removeItemAtPath:probeFile error:nil];
    if (writable) {
        return DYYYMakeResult(@"文件系统", 0, @"Documents/DYYY 分类目录可读写");
    }
    return DYYYMakeResult(@"文件系统", 2, [NSString stringWithFormat:@"目录不可写: %@", err.localizedDescription]);
}

// 15. 逆向助手数据库（发布版不含，跳过）
#ifndef DYYY_RELEASE_BUILD
static DYYYSelfTestResult *DYYYTestDatabase(void) {
    DYYYDatabaseManager *db = [DYYYDatabaseManager sharedManager];
    NSString *probeBundle = @"com.dyyy.selftest.probe";
    NSString *probeText = @"selftest-probe";

    [db insertDataIntoTable:@"zhaiyao" bundleID:probeBundle text:probeText];
    NSArray<NSString *> *texts = [db queryTextsFromTable:@"zhaiyao" bundleID:probeBundle];

    BOOL written = NO;
    for (NSString *t in texts) {
        if ([t isEqualToString:probeText]) {
            written = YES;
            break;
        }
    }

    if (written) {
        return DYYYMakeResult(@"逆向助手数据库", 0, @"写入/查询正常(测试数据受 500 条上限自动裁剪)");
    }
    return DYYYMakeResult(@"逆向助手数据库", 2, @"写入后未能查询到测试数据");
}

static DYYYSelfTestResult *DYYYTestFlexEntry(void) {
    return DYYYCheckClasses(@"FLEX 调试工具", @[
        @"DYYYFLEXManager",
        @"DYYYIZXURLCaptureProtocol"
    ]);
}
#endif

// 16. 网络可达性（douyin.com 5s 超时，⚠️ 容错）
static DYYYSelfTestResult *DYYYTestNetwork(void) {
    __block NSInteger status = 1;
    __block NSString *detail = @"未验证";
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://www.douyin.com"]];
    req.HTTPMethod = @"HEAD";
    req.timeoutInterval = 5;
    [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
        if (!e && [r isKindOfClass:[NSHTTPURLResponse class]]) {
            NSInteger code = ((NSHTTPURLResponse *)r).statusCode;
            status = 0;
            detail = [NSString stringWithFormat:@"HTTP %ld", (long)code];
        } else {
            detail = [NSString stringWithFormat:@"请求失败: %@", e.localizedDescription ?: @"超时"];
        }
        dispatch_semaphore_signal(sem);
    }] resume];
    dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.5 * NSEC_PER_SEC)));
    if (!status) {
        return DYYYMakeResult(@"网络可达性", status, detail);
    }
    if ([detail isEqualToString:@"未验证"]) {
        detail = @"请求超时(5s)";
    }
    return DYYYMakeResult(@"网络可达性", status, detail);
}

// 17. 崩溃日志抓取
static DYYYSelfTestResult *DYYYTestCrashCatcher(void) {
    NSArray<NSString *> *logs = [DYYYCrashCatcher savedLogFilePaths];
    BOOL dirExists = [[NSFileManager defaultManager] fileExistsAtPath:[DYYYPaths logsDir]];
    if (dirExists) {
        return DYYYMakeResult(@"崩溃日志抓取", 0,
            [NSString stringWithFormat:@"已安装, 日志平铺于 DYYY/Logs(保留最近 3 份), 已有 %lu 份", (unsigned long)logs.count]);
    }
    return DYYYMakeResult(@"崩溃日志抓取", 2, @"日志目录未创建");
}

#pragma mark - 实时自检页面

@interface DYYYSelfTestViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray<DYYYSelfTestResult *> *results;
@property (nonatomic, strong) UILabel *summaryLabel;
@property (nonatomic, assign) NSUInteger totalCount;
@property (nonatomic, assign) NSUInteger runningIndex;
@property (nonatomic, assign) BOOL finished;
@end

@implementation DYYYSelfTestViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"自检中…";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    self.results = [NSMutableArray array];

    UIBarButtonItem *closeButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                 target:self
                                                                                 action:@selector(closeTapped)];
    self.navigationItem.leftBarButtonItem = closeButton;

    UIBarButtonItem *copyButton = [[UIBarButtonItem alloc] initWithTitle:@"复制报告"
                                                                   style:UIBarButtonItemStylePlain
                                                                  target:self
                                                                  action:@selector(copyReport)];
    self.navigationItem.rightBarButtonItem = copyButton;

    self.summaryLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
    self.summaryLabel.textAlignment = NSTextAlignmentCenter;
    self.summaryLabel.font = [UIFont systemFontOfSize:14];
    self.summaryLabel.textColor = [UIColor secondaryLabelColor];
    self.summaryLabel.text = @"开始自检…";

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.tableHeaderView = self.summaryLabel;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 60;
    [self.view addSubview:self.tableView];

    [self startTests];
}

- (void)closeTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)copyReport {
    NSMutableString *report = [NSMutableString stringWithFormat:@"DYYY++ 自检报告 (%@)\n\n", [NSDate date]];
    for (DYYYSelfTestResult *r in self.results) {
        NSString *mark = r.status == 0 ? @"✅" : (r.status == 1 ? @"⚠️" : @"❌");
        [report appendFormat:@"%@ %@\n%@\n\n", mark, r.name, r.detail];
    }
    if (self.finished) {
        [report appendFormat:@"—— %@ ——", self.summaryLabel.text];
    }
    [UIPasteboard generalPasteboard].string = report;
    [DYYYManager showToast:@"自检报告已复制"];
}

- (void)startTests {
    NSMutableArray *tests = [NSMutableArray arrayWithArray:@[
        ^DYYYSelfTestResult *(void){ return DYYYTestEnvironment(); },
        ^DYYYSelfTestResult *(void){ return DYYYTestConfigCache(); },
        ^DYYYSelfTestResult *(void){ return DYYYTestPlaybackHooks(); },
        ^DYYYSelfTestResult *(void){ return DYYYTestFeedHooks(); },
        ^DYYYSelfTestResult *(void){ return DYYYTestSpeedClear(); },
        ^DYYYSelfTestResult *(void){ return DYYYTestPanelComment(); },
        ^DYYYSelfTestResult *(void){ return DYYYTestDownload(); },
        ^DYYYSelfTestResult *(void){ return DYYYTestCity(); },
        ^DYYYSelfTestResult *(void){ return DYYYTestSocialStats(); },
        ^DYYYSelfTestResult *(void){ return DYYYTestDateTime(); },
        ^DYYYSelfTestResult *(void){ return DYYYTestPip(); },
        ^DYYYSelfTestResult *(void){ return DYYYTestScreenshot(); },
        ^DYYYSelfTestResult *(void){ return DYYYTestABTest(); },
        ^DYYYSelfTestResult *(void){ return DYYYTestFileSystem(); }
    ]];
#ifndef DYYY_RELEASE_BUILD
    [tests addObject:^DYYYSelfTestResult *(void){ return DYYYTestDatabase(); }];
    [tests addObject:^DYYYSelfTestResult *(void){ return DYYYTestFlexEntry(); }];
#endif
    [tests addObject:^DYYYSelfTestResult *(void){ return DYYYTestCrashCatcher(); }];
    [tests addObject:^DYYYSelfTestResult *(void){ return DYYYTestNetwork(); }];

    self.totalCount = tests.count;
    self.runningIndex = 0;
    // 初始占位行：进行中
    [self.tableView reloadData];

    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        for (NSUInteger i = 0; i < tests.count; i++) {
            DYYYSelfTestBlock test = (DYYYSelfTestBlock)tests[i];
            DYYYSelfTestResult *result = nil;
            @autoreleasepool {
                @try {
                    result = test();
                } @catch (NSException *e) {
                    result = DYYYMakeResult(@"未知测试项", 2, [NSString stringWithFormat:@"异常: %@", e.reason]);
                }
            }
            if (!result) {
                result = DYYYMakeResult(@"未知测试项", 2, @"测试返回空");
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) return;
                [strongSelf.results addObject:result];
                strongSelf.runningIndex = i + 1;
                strongSelf.title = [NSString stringWithFormat:@"自检中 %lu/%lu",
                                    (unsigned long)strongSelf.runningIndex,
                                    (unsigned long)strongSelf.totalCount];
                [strongSelf.tableView reloadData];
            });
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            strongSelf.finished = YES;
            NSUInteger pass = 0, warn = 0, fail = 0;
            for (DYYYSelfTestResult *r in strongSelf.results) {
                if (r.status == 0) pass++;
                else if (r.status == 1) warn++;
                else fail++;
            }
            strongSelf.title = @"自检完成";
            strongSelf.summaryLabel.text = [NSString stringWithFormat:
                @"✅ %lu / ⚠️ %lu / ❌ %lu（共 %lu 项）",
                (unsigned long)pass, (unsigned long)warn, (unsigned long)fail,
                (unsigned long)strongSelf.results.count];
            [strongSelf.tableView reloadData];
        });
    });
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.results.count < self.totalCount) {
        return self.results.count + 1; // 加进行中占位行
    }
    return self.results.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"SelfTestCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }

    if (indexPath.row < self.results.count) {
        DYYYSelfTestResult *result = self.results[indexPath.row];
        NSString *mark = result.status == 0 ? @"✅" : (result.status == 1 ? @"⚠️" : @"❌");
        cell.textLabel.text = [NSString stringWithFormat:@"%@ %@", mark, result.name];
        cell.detailTextLabel.text = result.detail;
        cell.detailTextLabel.numberOfLines = 0;
        cell.textLabel.textColor = [UIColor labelColor];
        cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    } else {
        cell.textLabel.text = @"⏳ 检测中…";
        cell.detailTextLabel.text = @"正在执行下一项";
        cell.textLabel.textColor = [UIColor systemOrangeColor];
        cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    }
    return cell;
}

@end

#pragma mark - 入口

@implementation DYYYSelfTest

+ (void)presentFromViewController:(UIViewController *)viewController {
    DYYYSelfTestViewController *testVC = [[DYYYSelfTestViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:testVC];
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    [viewController presentViewController:nav animated:YES completion:nil];
}

@end
