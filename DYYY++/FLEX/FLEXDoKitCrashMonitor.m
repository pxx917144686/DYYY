#import "FLEXDoKitCrashMonitor.h"
#import <UIKit/UIKit.h>
#import <sys/utsname.h>
#import <execinfo.h>
#import <mach/mach.h>

@implementation FLEXDoKitCrashInfo

- (NSDictionary *)dictionaryRepresentation {
    return @{
        @"type": @(self.type),
        @"reason": self.reason ?: @"",
        @"callStack": self.callStack ?: @[],
        @"timestamp": @([self.timestamp timeIntervalSince1970]),
        @"deviceInfo": self.deviceInfo ?: @{}
    };
}

@end

@interface FLEXDoKitCrashMonitor ()
@property (nonatomic, strong) NSMutableArray<FLEXDoKitCrashInfo *> *mutableCrashLogs;
@property (nonatomic, assign) BOOL isMonitoring;
@property (nonatomic, assign) NSUncaughtExceptionHandler *previousExceptionHandler;
@end

static void flexDoKitSignalHandler(int signal);
static void flexDoKitExceptionHandler(NSException *exception);

@implementation FLEXDoKitCrashMonitor

+ (instancetype)sharedInstance {
    static FLEXDoKitCrashMonitor *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _mutableCrashLogs = [NSMutableArray new];
        _isMonitoring = NO;
        [self loadCrashLogsFromDisk];
    }
    return self;
}

- (NSMutableArray<FLEXDoKitCrashInfo *> *)crashLogs {
    return self.mutableCrashLogs;
}

#pragma mark - 崩溃监控

- (void)startCrashMonitoring {
    if (self.isMonitoring) return;
    
    self.isMonitoring = YES;
    
    // 注册信号处理器
    signal(SIGABRT, flexDoKitSignalHandler);
    signal(SIGILL, flexDoKitSignalHandler);
    signal(SIGSEGV, flexDoKitSignalHandler);
    signal(SIGFPE, flexDoKitSignalHandler);
    signal(SIGBUS, flexDoKitSignalHandler);
    signal(SIGPIPE, flexDoKitSignalHandler);
    
    // 注册异常处理器
    self.previousExceptionHandler = NSGetUncaughtExceptionHandler();
    NSSetUncaughtExceptionHandler(&flexDoKitExceptionHandler);
    
    NSLog(@"崩溃监控已启动");
}

- (void)stopCrashMonitoring {
    if (!self.isMonitoring) return;
    
    self.isMonitoring = NO;
    
    // 恢复之前的异常处理器
    NSSetUncaughtExceptionHandler(self.previousExceptionHandler);
    
    NSLog(@"崩溃监控已停止");
}

#pragma mark - 崩溃处理

static void flexDoKitSignalHandler(int sig) {
    NSArray *callStack = [NSThread callStackSymbols];
    
    FLEXDoKitCrashInfo *crashInfo = [[FLEXDoKitCrashInfo alloc] init];
    crashInfo.type = FLEXDoKitCrashTypeSignal;
    crashInfo.reason = [NSString stringWithFormat:@"Signal %d", sig];
    crashInfo.callStack = callStack;
    crashInfo.timestamp = [NSDate date];
    crashInfo.deviceInfo = [[FLEXDoKitCrashMonitor sharedInstance] getDeviceInfo];
    
    [[FLEXDoKitCrashMonitor sharedInstance] saveCrashInfo:crashInfo];
    
    // 恢复默认信号处理并重新抛出
    signal(sig, SIG_DFL);
    raise(sig);
}

static void flexDoKitExceptionHandler(NSException *exception) {
    NSArray *callStack = [exception callStackSymbols];
    
    FLEXDoKitCrashInfo *crashInfo = [[FLEXDoKitCrashInfo alloc] init];
    crashInfo.type = FLEXDoKitCrashTypeException;
    crashInfo.reason = [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason];
    crashInfo.callStack = callStack;
    crashInfo.timestamp = [NSDate date];
    crashInfo.deviceInfo = [[FLEXDoKitCrashMonitor sharedInstance] getDeviceInfo];
    
    [[FLEXDoKitCrashMonitor sharedInstance] saveCrashInfo:crashInfo];
    
    // 调用之前的异常处理器
    FLEXDoKitCrashMonitor *monitor = [FLEXDoKitCrashMonitor sharedInstance];
    if (monitor.previousExceptionHandler) {
        monitor.previousExceptionHandler(exception);
    }
}

- (void)saveCrashInfo:(FLEXDoKitCrashInfo *)crashInfo {
    [self.mutableCrashLogs addObject:crashInfo];
    
    // 限制崩溃日志数量
    if (self.mutableCrashLogs.count > 100) {
        [self.mutableCrashLogs removeObjectAtIndex:0];
    }
    
    [self saveCrashLogsToDisk];
    
    // 发送通知
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"FLEXDoKitCrashDetected" object:crashInfo];
    });
}

- (NSDictionary *)getDeviceInfo {
    struct utsname systemInfo;
    uname(&systemInfo);
    
    return @{
        @"device": [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding],
        @"system": [NSString stringWithFormat:@"%@ %@", [UIDevice currentDevice].systemName, [UIDevice currentDevice].systemVersion],
        @"app_version": [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"Unknown",
        @"build": [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"] ?: @"Unknown",
        @"memory": [self getMemoryInfo],
        @"timestamp": @([[NSDate date] timeIntervalSince1970])
    };
}

- (NSDictionary *)getMemoryInfo {
    struct mach_task_basic_info info;
    mach_msg_type_number_t size = MACH_TASK_BASIC_INFO_COUNT;
    
    kern_return_t result = task_info(mach_task_self(), MACH_TASK_BASIC_INFO, (task_info_t)&info, &size);
    if (result == KERN_SUCCESS) {
        return @{
            @"used": @(info.resident_size),
            @"virtual": @(info.virtual_size)
        };
    }
    
    return @{};
}

#pragma mark - 数据持久化

- (void)saveCrashLogsToDisk {
    NSArray *crashData = [self.mutableCrashLogs valueForKey:@"dictionaryRepresentation"];
    NSString *filePath = [self crashLogsFilePath];
    [crashData writeToFile:filePath atomically:YES];
}

- (void)loadCrashLogsFromDisk {
    NSString *filePath = [self crashLogsFilePath];
    NSArray *crashData = [NSArray arrayWithContentsOfFile:filePath];
    
    if (crashData) {
        for (NSDictionary *crashDict in crashData) {
            FLEXDoKitCrashInfo *crashInfo = [[FLEXDoKitCrashInfo alloc] init];
            // 从字典恢复崩溃信息
            crashInfo.type = [crashDict[@"type"] integerValue];
            crashInfo.reason = crashDict[@"reason"];
            crashInfo.callStack = crashDict[@"callStack"];
            crashInfo.timestamp = [NSDate dateWithTimeIntervalSince1970:[crashDict[@"timestamp"] doubleValue]];
            crashInfo.deviceInfo = crashDict[@"deviceInfo"];
            
            [self.mutableCrashLogs addObject:crashInfo];
        }
    }
}

- (NSString *)crashLogsFilePath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    return [documentsDirectory stringByAppendingPathComponent:@"FLEXDoKitCrashLogs.plist"];
}

#pragma mark - 崩溃日志管理

- (void)clearCrashLogs {
    [self.mutableCrashLogs removeAllObjects];
    [self saveCrashLogsToDisk];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"FLEXDoKitCrashLogsCleared" object:nil];
}

- (NSString *)exportCrashLogsAsString {
    NSMutableString *exportString = [NSMutableString string];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    
    for (FLEXDoKitCrashInfo *crashInfo in self.mutableCrashLogs) {
        [exportString appendFormat:@"=== 崩溃日志 ===\n"];
        [exportString appendFormat:@"时间: %@\n", [formatter stringFromDate:crashInfo.timestamp]];
        [exportString appendFormat:@"类型: %@\n", [self stringForCrashType:crashInfo.type]];
        [exportString appendFormat:@"原因: %@\n", crashInfo.reason];
        [exportString appendFormat:@"设备信息: %@\n", crashInfo.deviceInfo];
        [exportString appendFormat:@"调用栈:\n"];
        
        for (NSString *symbol in crashInfo.callStack) {
            [exportString appendFormat:@"  %@\n", symbol];
        }
        
        [exportString appendString:@"\n\n"];
    }
    
    return [exportString copy];
}

- (NSString *)stringForCrashType:(FLEXDoKitCrashType)type {
    switch (type) {
        case FLEXDoKitCrashTypeSignal:
            return @"信号崩溃";
        case FLEXDoKitCrashTypeException:
            return @"异常崩溃";
        case FLEXDoKitCrashTypeKVO:
            return @"KVO崩溃";
        case FLEXDoKitCrashTypeUnrecognizedSelector:
            return @"未识别选择器";
        default:
            return @"未知类型";
    }
}

@end