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

// 状态：0=通过 ✅ 1=警告 ⚠️ 2=失败 ❌ 3=信息 ℹ️（抖音版本差异提示，不计入警告数）
typedef NS_ENUM(NSInteger, DYYYSelfTestStatus) {
    DYYYSelfTestStatusPass = 0,
    DYYYSelfTestStatusWarn = 1,
    DYYYSelfTestStatusFail = 2,
    DYYYSelfTestStatusInfo = 3,
};

static DYYYSelfTestResult *DYYYMakeResult(NSString *name, NSInteger status, NSString *detail) {
    DYYYSelfTestResult *r = [[DYYYSelfTestResult alloc] init];
    r.name = name;
    r.status = status;
    r.detail = detail;
    return r;
}

// 类存在性检测：核心类缺失=⚠️(1)；可选类缺失=ℹ️(3，抖音版本差异非插件问题)
static DYYYSelfTestResult *DYYYCheckClassesWithOptional(NSString *name,
                                                         NSArray<NSString *> *coreNames,
                                                         NSArray<NSString *> *optionalNames) {
    NSMutableString *missingCore = [NSMutableString string];
    NSMutableString *missingOptional = [NSMutableString string];
    for (NSString *className in coreNames) {
        if (!NSClassFromString(className)) {
            [missingCore appendFormat:@"%@; ", className];
        }
    }
    for (NSString *className in optionalNames) {
        if (!NSClassFromString(className)) {
            [missingOptional appendFormat:@"%@; ", className];
        }
    }
    if (missingCore.length == 0 && missingOptional.length == 0) {
        return DYYYMakeResult(name, DYYYSelfTestStatusPass,
            [NSString stringWithFormat:@"全部 %lu 个关键类存在", (unsigned long)(coreNames.count + optionalNames.count)]);
    }
    if (missingCore.length > 0) {
        return DYYYMakeResult(name, DYYYSelfTestStatusWarn,
            [NSString stringWithFormat:@"缺失核心类: %@相关功能失效", missingCore]);
    }
    return DYYYMakeResult(name, DYYYSelfTestStatusInfo,
        [NSString stringWithFormat:@"版本差异类缺失: %@(抖音版本差异, 非插件问题; 对应定制功能本版不生效)", missingOptional]);
}

// 类存在性检测（无可选类时的便捷入口）
static DYYYSelfTestResult *DYYYCheckClasses(NSString *name, NSArray<NSString *> *classNames) {
    return DYYYCheckClassesWithOptional(name, classNames, @[]);
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
    return DYYYCheckClassesWithOptional(@"播放页 Hook",
        @[@"AWEPlayInteractionViewController",
          @"AWEAwemePlayVideoViewController",
          @"AWEPlayInteractionTimestampElement",
          @"AWEStoryProgressContainerView",
          @"AWEPlayInteractionProgressContainerView",
          @"AWEDPlayerProgressContainerView"],
        @[@"AWEPlayerPlayControlHandler"]);
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
    // 清屏按钮实际类名为 DYYYHideUIButton（DYYYFloatClearButton.xm 定义）
    BOOL clearButtonClassExists = NSClassFromString(@"DYYYHideUIButton") != nil;
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
    return DYYYCheckClassesWithOptional(@"长按面板/评论",
        @[@"AWEModernLongPressPanelTableViewController",
          @"AWELongPressPanelManager",
          @"AWECommentInputViewSwiftImpl.CommentInputContainerView"],
        @[@"AWECommentPanelHeaderSwiftImpl.CommentHeaderGeneralView"]);
}

// 7. 下载/保存模块
static DYYYSelfTestResult *DYYYTestDownload(void) {
    DYYYManager *mgr = [DYYYManager shared];
    if (!mgr) {
        return DYYYMakeResult(@"下载/保存", 2, @"DYYYManager 单例为空");
    }
    // 核心方法均为 + 类方法，须用类对象检测
    NSMutableString *missing = [NSMutableString string];
    NSArray<NSString *> *selectors = @[
        @"saveMedia:mediaType:completion:",
        @"downloadMedia:mediaType:completion:",
        @"downloadLivePhoto:videoURL:completion:",
        @"createVideoFromMedia:livePhotos:bgmURL:progress:completion:",
        @"saveCommentImages:currentIndex:completion:"
    ];
    for (NSString *selName in selectors) {
        if (![[mgr class] respondsToSelector:NSSelectorFromString(selName)]) {
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
@property (nonatomic, strong) UIProgressView *progressView;
@property (nonatomic, strong) UIView *glassCardView;
@property (nonatomic, strong) CAGradientLayer *liquidGradient;
@property (nonatomic, assign) NSUInteger totalCount;
@property (nonatomic, assign) NSUInteger runningIndex;
@property (nonatomic, assign) BOOL finished;
@property (nonatomic, assign) BOOL refreshScheduled;
@property (atomic, assign) BOOL isExiting;
@end

@implementation DYYYSelfTestViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"自检中…";
    self.view.backgroundColor = [UIColor clearColor];
    self.isExiting = NO;

    self.results = [NSMutableArray array];

    [self setupNavigationBarAppearance];

    UIBarButtonItem *closeButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                 target:self
                                                                                 action:@selector(closeTapped)];
    self.navigationItem.leftBarButtonItem = closeButton;

    UIBarButtonItem *copyButton = [[UIBarButtonItem alloc] initWithTitle:@"复制报告"
                                                                   style:UIBarButtonItemStylePlain
                                                                  target:self
                                                                   action:@selector(copyReport)];
    self.navigationItem.rightBarButtonItem = copyButton;

    UIView *dimmingView = [[UIView alloc] initWithFrame:self.view.bounds];
    dimmingView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    dimmingView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.18];
    [self.view addSubview:dimmingView];

    self.glassCardView = [[UIView alloc] initWithFrame:CGRectInset(self.view.bounds, 14, 14)];
    self.glassCardView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.glassCardView.backgroundColor = [UIColor clearColor];
    self.glassCardView.layer.cornerRadius = 22;
    self.glassCardView.layer.masksToBounds = NO;
    self.glassCardView.layer.shadowColor = [UIColor blackColor].CGColor;
    self.glassCardView.layer.shadowOffset = CGSizeMake(0, 10);
    self.glassCardView.layer.shadowOpacity = 0.18;
    self.glassCardView.layer.shadowRadius = 18;

    UIVisualEffectView *glassBlurView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial]];
    glassBlurView.frame = self.glassCardView.bounds;
    glassBlurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    glassBlurView.layer.cornerRadius = 22;
    glassBlurView.clipsToBounds = YES;
    [self.glassCardView addSubview:glassBlurView];

    UIView *liquidOverlayView = [[UIView alloc] initWithFrame:glassBlurView.bounds];
    liquidOverlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    liquidOverlayView.backgroundColor = [UIColor clearColor];
    liquidOverlayView.userInteractionEnabled = NO;
    self.liquidGradient = [CAGradientLayer layer];
    CAGradientLayer *liquidGradient = self.liquidGradient;
    liquidGradient.frame = liquidOverlayView.bounds;
    liquidGradient.cornerRadius = 22;
    liquidGradient.colors = @[(id)[[UIColor systemBlueColor] colorWithAlphaComponent:0.22].CGColor,
                              (id)[UIColor clearColor].CGColor];
    liquidGradient.startPoint = CGPointMake(0.0, 0.0);
    liquidGradient.endPoint = CGPointMake(1.0, 1.0);
    [liquidOverlayView.layer addSublayer:liquidGradient];
    [glassBlurView.contentView insertSubview:liquidOverlayView atIndex:0];

    self.tableView = [[UITableView alloc] initWithFrame:glassBlurView.contentView.bounds style:UITableViewStyleGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 60;
    [glassBlurView.contentView addSubview:self.tableView];
    [self.view addSubview:self.glassCardView];

    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 82)];
    headerView.backgroundColor = [UIColor clearColor];

    self.summaryLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 14, headerView.bounds.size.width - 32, 24)];
    self.summaryLabel.textAlignment = NSTextAlignmentCenter;
    self.summaryLabel.font = [UIFont boldSystemFontOfSize:16];
    self.summaryLabel.textColor = [UIColor labelColor];
    self.summaryLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.summaryLabel.text = @"开始自检…";

    self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    self.progressView.frame = CGRectMake(16, 46, headerView.bounds.size.width - 32, 4);
    self.progressView.progress = 0.0;
    self.progressView.tintColor = [UIColor systemBlueColor];
    self.progressView.trackTintColor = [UIColor separatorColor];
    self.progressView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [headerView addSubview:self.summaryLabel];
    [headerView addSubview:self.progressView];
    self.tableView.tableHeaderView = headerView;

    [self startTests];
}

- (void)setupNavigationBarAppearance {
    if (@available(iOS 13.0, *)) {
        UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
        [appearance configureWithTransparentBackground];
        appearance.backgroundEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
        appearance.backgroundColor = [UIColor clearColor];
        appearance.shadowColor = [UIColor clearColor];

        UINavigationBar *navigationBar = self.navigationController.navigationBar;
        navigationBar.standardAppearance = appearance;
        navigationBar.scrollEdgeAppearance = appearance;
        navigationBar.translucent = YES;
        navigationBar.backgroundColor = [UIColor clearColor];
        navigationBar.tintColor = [UIColor labelColor];
        navigationBar.titleTextAttributes = @{NSForegroundColorAttributeName: [UIColor labelColor]};
    }
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if (self.liquidGradient) {
        self.liquidGradient.frame = self.liquidGradient.superlayer.bounds;
    }
}

- (void)closeTapped {
    self.isExiting = YES;
    self.finished = YES;
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    self.isExiting = YES;
    self.finished = YES;
}

- (void)dealloc {
    self.tableView.delegate = nil;
    self.tableView.dataSource = nil;
}

- (void)copyReport {
    NSMutableString *report = [NSMutableString stringWithFormat:@"DYYY++ 自检报告 (%@)\n\n", [NSDate date]];
    for (DYYYSelfTestResult *r in self.results) {
        NSString *mark = (r.status == DYYYSelfTestStatusPass) ? @"✅" :
                         (r.status == DYYYSelfTestStatusWarn) ? @"⚠️" :
                         (r.status == DYYYSelfTestStatusInfo) ? @"ℹ️" : @"❌";
        [report appendFormat:@"%@ %@\n%@\n\n", mark, r.name, r.detail];
    }
    if (self.finished) {
        [report appendFormat:@"—— %@ ——", self.summaryLabel.text];
    }
    [UIPasteboard generalPasteboard].string = report;
    [DYYYManager showToast:@"自检报告已复制"];
}

- (void)scheduleTableRefresh {
    if (self.isExiting || self.finished || self.refreshScheduled) {
        return;
    }
    self.refreshScheduled = YES;
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.08 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || strongSelf.isExiting) {
            return;
        }
        strongSelf.refreshScheduled = NO;
        if (!strongSelf.finished) {
            [strongSelf.tableView reloadData];
        }
    });
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
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf || strongSelf.isExiting) {
                break;
            }
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
                if (!strongSelf || strongSelf.isExiting || strongSelf.finished) return;
                [strongSelf.results addObject:result];
                strongSelf.runningIndex = i + 1;
                strongSelf.summaryLabel.text = [NSString stringWithFormat:@"自检中 %lu/%lu",
                                                (unsigned long)strongSelf.runningIndex,
                                                (unsigned long)strongSelf.totalCount];
                [strongSelf.progressView setProgress:(CGFloat)strongSelf.runningIndex / (CGFloat)strongSelf.totalCount
                                            animated:YES];
                [strongSelf scheduleTableRefresh];
            });
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf || strongSelf.isExiting || strongSelf.finished) return;
            strongSelf.finished = YES;
            [strongSelf.progressView setProgress:1.0 animated:YES];
            NSUInteger pass = 0, warn = 0, fail = 0, info = 0;
            for (DYYYSelfTestResult *r in strongSelf.results) {
                if (r.status == DYYYSelfTestStatusPass) pass++;
                else if (r.status == DYYYSelfTestStatusWarn) warn++;
                else if (r.status == DYYYSelfTestStatusInfo) info++;
                else fail++;
            }
            strongSelf.title = @"自检完成";
            if (info > 0) {
                strongSelf.summaryLabel.text = [NSString stringWithFormat:
                    @"✅ %lu / ⚠️ %lu / ❌ %lu / ℹ️ %lu（共 %lu 项）",
                    (unsigned long)pass, (unsigned long)warn, (unsigned long)fail,
                    (unsigned long)info, (unsigned long)strongSelf.results.count];
            } else {
                strongSelf.summaryLabel.text = [NSString stringWithFormat:
                    @"✅ %lu / ⚠️ %lu / ❌ %lu（共 %lu 项）",
                    (unsigned long)pass, (unsigned long)warn, (unsigned long)fail,
                    (unsigned long)strongSelf.results.count];
            }
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
    cell.backgroundColor = [UIColor clearColor];
    cell.contentView.backgroundColor = [UIColor clearColor];

    if (indexPath.row < self.results.count) {
        DYYYSelfTestResult *result = self.results[indexPath.row];
        NSString *mark = (result.status == DYYYSelfTestStatusPass) ? @"✅" :
                         (result.status == DYYYSelfTestStatusWarn) ? @"⚠️" :
                         (result.status == DYYYSelfTestStatusInfo) ? @"ℹ️" : @"❌";
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
    nav.modalPresentationStyle = UIModalPresentationOverFullScreen;
    nav.view.backgroundColor = [UIColor clearColor];
    [viewController presentViewController:nav animated:YES completion:nil];
}

@end
