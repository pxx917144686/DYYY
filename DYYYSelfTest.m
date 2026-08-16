#import "DYYYSelfTest.h"
#import "AwemeHeaders.h"
#import "DYYYCityManager.h"
#import "DYYYManager.h"
#import "DYYYToast.h"
#ifndef DYYY_RELEASE_BUILD
#import "FLEX/x/Decrypt/DYYYDatabaseManager.h"
#endif
#import <objc/runtime.h>

#pragma mark - 测试结果模型

@interface DYYYSelfTestResult : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) NSInteger status; // 0=通过 1=警告 2=失败
@property (nonatomic, copy) NSString *detail;
@end

@implementation DYYYSelfTestResult
@end

#pragma mark - 测试项实现

typedef DYYYSelfTestResult * (^DYYYSelfTestBlock)(void);

static DYYYSelfTestResult *DYYYMakeResult(NSString *name, NSInteger status, NSString *detail) {
    DYYYSelfTestResult *r = [[DYYYSelfTestResult alloc] init];
    r.name = name;
    r.status = status;
    r.detail = detail;
    return r;
}

// 1. 环境检测
static DYYYSelfTestResult *DYYYTestEnvironment(void) {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier] ?: @"未知";
    NSString *process = [[NSProcessInfo processInfo] processName] ?: @"未知";
    NSString *iosVersion = [[UIDevice currentDevice] systemVersion];
    BOOL rootless = [[NSFileManager defaultManager] fileExistsAtPath:@"/var/jb"];

    NSString *detail = [NSString stringWithFormat:@"bundleID=%@\n进程=%@\niOS=%@\nrootless=%@",
                        bundleID, process, iosVersion, rootless ? @"是(/var/jb)" : @"否"];
    return DYYYMakeResult(@"环境检测", 0, detail);
}

// 2. 配置缓存读写与失效
static DYYYSelfTestResult *DYYYTestConfigCache(void) {
    NSString *probeKey = @"DYYYSelfTestProbe";
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:probeKey];
    BOOL cached = DYYYCachedBool(probeKey);
    BOOL raw = [[NSUserDefaults standardUserDefaults] boolForKey:probeKey];

    DYYYConfigCacheInvalidate();
    BOOL cacheCleared = DYYYCachedBool(probeKey) == raw; // 失效后重新读取应仍与 raw 一致

    [[NSUserDefaults standardUserDefaults] removeObjectForKey:probeKey];
    DYYYConfigCacheInvalidate();

    if (cached && cacheCleared) {
        return DYYYMakeResult(@"配置缓存", 0, @"写入/缓存命中/失效重读均正常");
    }
    return DYYYMakeResult(@"配置缓存", 2, [NSString stringWithFormat:@"异常 cached=%d cacheCleared=%d", cached, cacheCleared]);
}

// 3. 逆向助手数据库读写与上限裁剪（发布版不含逆向助手，跳过）
#ifndef DYYY_RELEASE_BUILD
static DYYYSelfTestResult *DYYYTestDatabase(void) {
    DYYYDatabaseManager *db = [DYYYDatabaseManager sharedManager];
    NSString *probeBundle = @"com.dyyy.selftest.probe";
    NSString *probeText = @"selftest-probe";

    // insertDataIntoTable 是异步写入；queryTextsFromTable 是同步查询，天然排在写入后
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
        return DYYYMakeResult(@"逆向助手数据库", 0, @"写入/查询正常（测试数据受 500 条上限自动裁剪）");
    }
    return DYYYMakeResult(@"逆向助手数据库", 2, @"写入后未能查询到测试数据");
}
#endif

// 4. 城市库地址生成
static DYYYSelfTestResult *DYYYTestCityManager(void) {
    DYYYCityManager *mgr = [DYYYCityManager sharedInstance];
    if (!mgr) {
        return DYYYMakeResult(@"城市库", 2, @"DYYYCityManager 单例为空");
    }
    SEL selector = @selector(generateRandomFourLevelAddressForCityCode:showProvince:showCity:showDistrict:showLocation:);
    if (![mgr respondsToSelector:selector]) {
        return DYYYMakeResult(@"城市库", 2, @"缺少属地生成方法");
    }
    @try {
        NSString *addr = [mgr generateRandomFourLevelAddressForCityCode:@"110100" showProvince:YES showCity:YES showDistrict:YES showLocation:YES];
        if (addr.length > 0) {
            return DYYYMakeResult(@"城市库", 0, [NSString stringWithFormat:@"北京属地生成成功: %@", addr]);
        }
        return DYYYMakeResult(@"城市库", 2, @"地址生成为空");
    } @catch (NSException *e) {
        return DYYYMakeResult(@"城市库", 2, [NSString stringWithFormat:@"异常: %@", e.reason]);
    }
}

// 5. 文件系统与 DYYY 目录
static DYYYSelfTestResult *DYYYTestFileSystem(void) {
    NSString *docPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSString *dyyyPath = [docPath stringByAppendingPathComponent:@"DYYY"];
    NSError *err = nil;
    [[NSFileManager defaultManager] createDirectoryAtPath:dyyyPath withIntermediateDirectories:YES attributes:nil error:&err];
    if (err) {
        return DYYYMakeResult(@"文件系统", 2, [NSString stringWithFormat:@"创建 DYYY 目录失败: %@", err.localizedDescription]);
    }
    // 可写性探测
    NSString *probeFile = [dyyyPath stringByAppendingPathComponent:@".selftest"];
    BOOL writable = [@"ok" writeToFile:probeFile atomically:YES encoding:NSUTF8StringEncoding error:&err];
    [[NSFileManager defaultManager] removeItemAtPath:probeFile error:nil];
    if (writable) {
        return DYYYMakeResult(@"文件系统", 0, @"Documents/DYYY 目录可读写");
    }
    return DYYYMakeResult(@"文件系统", 2, [NSString stringWithFormat:@"目录不可写: %@", err.localizedDescription]);
}

// 6. Hook 生效性：关键类存在性 + NSDictionary hook 命中检测
static DYYYSelfTestResult *DYYYTestHookPresence(void) {
    NSMutableString *missing = [NSMutableString string];
    for (NSString *name in @[@"AWEPlayInteractionViewController",
                             @"AWEFeedVideoButton",
                             @"AWEListDataController",
                             @"AWENormalModeTabBar",
                             @"AWEUserModel"]) {
        if (!NSClassFromString(name)) {
            [missing appendFormat:@"%@; ", name];
        }
    }
#ifndef DYYY_RELEASE_BUILD
    // 逆向助手抓包协议类仅调试版存在
    if (!NSClassFromString(@"DYYYIZXURLCaptureProtocol")) {
        [missing appendString:@"DYYYIZXURLCaptureProtocol; "];
    }
#endif

    // NSDictionary hook 命中检测：class cluster 子类若覆盖 objectForKey:
    // 则 %hook NSDictionary 会被绕过（实例走子类 IMP）
    Method clsMethod = class_getInstanceMethod([NSDictionary class], @selector(objectForKey:));
    IMP clsIMP = clsMethod ? method_getImplementation(clsMethod) : NULL;
    NSDictionary *probe = @{@"k": @"v"};
    Class instanceClass = object_getClass(probe);
    IMP instanceIMP = class_getMethodImplementation(instanceClass, @selector(objectForKey:));
    BOOL dictHookReachable = (clsIMP && instanceIMP == clsIMP);

    if (missing.length == 0 && dictHookReachable) {
        return DYYYMakeResult(@"Hook 生效性", 0, @"关键类全部存在; NSDictionary hook 可命中(cluster 未绕过)");
    }
    NSString *detail = [NSString stringWithFormat:@"%@%@", missing.length ? [@"缺失类: " stringByAppendingString:missing] : @"",
                        dictHookReachable ? @"" : @"NSDictionary hook 疑似被 cluster 绕过"];
    return DYYYMakeResult(@"Hook 生效性", 2, detail);
}

// 7. 网络可达性（可选项，失败仅警告）
static DYYYSelfTestResult *DYYYTestNetwork(void) {
    __block NSInteger status = 1;
    __block NSString *detail = @"未验证";
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://www.apple.com"]];
    req.HTTPMethod = @"HEAD";
    req.timeoutInterval = 10;
    [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
        if (!e && [r isKindOfClass:[NSHTTPURLResponse class]]) {
            NSInteger code = ((NSHTTPURLResponse *)r).statusCode;
            status = 0;
            detail = [NSString stringWithFormat:@"HTTP %ld", (long)code];
        } else {
            detail = [NSString stringWithFormat:@"失败: %@", e.localizedDescription];
        }
        dispatch_semaphore_signal(sem);
    }] resume];
    dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(12 * NSEC_PER_SEC)));
    return DYYYMakeResult(@"网络可达性", status, detail);
}

#pragma mark - 执行与报告

@implementation DYYYSelfTest

+ (void)runAndPresentReportFromViewController:(UIViewController *)viewController {
    [DYYYManager showToast:@"自检中…"];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableArray *tests = [NSMutableArray arrayWithArray:@[
            ^DYYYSelfTestResult *(void){ return DYYYTestEnvironment(); },
            ^DYYYSelfTestResult *(void){ return DYYYTestConfigCache(); }
        ]];
#ifndef DYYY_RELEASE_BUILD
        [tests addObject:^DYYYSelfTestResult *(void){ return DYYYTestDatabase(); }];
#endif
        [tests addObjectsFromArray:@[
            ^DYYYSelfTestResult *(void){ return DYYYTestCityManager(); },
            ^DYYYSelfTestResult *(void){ return DYYYTestFileSystem(); },
            ^DYYYSelfTestResult *(void){ return DYYYTestHookPresence(); },
            ^DYYYSelfTestResult *(void){ return DYYYTestNetwork(); }
        ]];

        NSMutableArray<DYYYSelfTestResult *> *results = [NSMutableArray array];
        for (NSUInteger i = 0; i < tests.count; i++) {
            DYYYSelfTestBlock test = (DYYYSelfTestBlock)tests[i];
            @autoreleasepool {
                @try {
                    [results addObject:test()];
                } @catch (NSException *e) {
                    [results addObject:DYYYMakeResult(@"未知测试项", 2, [NSString stringWithFormat:@"异常: %@", e.reason])];
                }
            }
        }

        NSUInteger pass = 0, warn = 0, fail = 0;
        NSMutableString *report = [NSMutableString string];
        for (DYYYSelfTestResult *r in results) {
            NSString *mark = r.status == 0 ? @"✅" : (r.status == 1 ? @"⚠️" : @"❌");
            if (r.status == 0) pass++;
            else if (r.status == 1) warn++;
            else fail++;
            [report appendFormat:@"%@ %@\n%@\n\n", mark, r.name, r.detail];
        }
        [report appendFormat:@"—— 通过 %lu / 警告 %lu / 失败 %lu ——", (unsigned long)pass, (unsigned long)warn, (unsigned long)fail];

        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"DYYY++ 一键自检报告"
                                                                           message:report
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
            [viewController presentViewController:alert animated:YES completion:nil];
        });
    });
}

@end
