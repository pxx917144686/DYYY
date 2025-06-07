#import "FLEXDoKitLogViewer.h"

@interface FLEXDoKitLogViewer ()
@property (nonatomic, strong) NSMutableArray<FLEXDoKitLogEntry *> *mutableLogEntries;
@property (nonatomic, strong) dispatch_queue_t logQueue;
@end

@implementation FLEXDoKitLogViewer

+ (instancetype)sharedInstance {
    static FLEXDoKitLogViewer *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _mutableLogEntries = [NSMutableArray new];
        _maxLogEntries = 10000;
        _minimumLogLevel = FLEXDoKitLogLevelVerbose;
        _logQueue = dispatch_queue_create("com.flex.dokit.log", DISPATCH_QUEUE_SERIAL);
        
        [self hookNSLog];
    }
    return self;
}

- (NSMutableArray<FLEXDoKitLogEntry *> *)logEntries {
    return self.mutableLogEntries;
}

#pragma mark - NSLog Hook

- (void)hookNSLog {
    // 重定向NSLog输出
    freopen("/tmp/flexdokit.log", "a+", stderr);
    
    // 监听日志文件变化
    [self startLogFileMonitoring];
}

- (void)startLogFileMonitoring {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        NSString *logPath = @"/tmp/flexdokit.log";
        NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:logPath];
        
        if (fileHandle) {
            [fileHandle seekToEndOfFile];
            
            [[NSNotificationCenter defaultCenter] addObserver:self 
                                                     selector:@selector(logFileChanged:) 
                                                         name:NSFileHandleDataAvailableNotification 
                                                       object:fileHandle];
            [fileHandle waitForDataInBackgroundAndNotify];
        }
    });
}

- (void)logFileChanged:(NSNotification *)notification {
    NSFileHandle *fileHandle = notification.object;
    NSData *data = [fileHandle availableData];
    
    if (data.length > 0) {
        NSString *logString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        [self parseLogString:logString];
        [fileHandle waitForDataInBackgroundAndNotify];
    }
}

- (void)parseLogString:(NSString *)logString {
    NSArray *lines = [logString componentsSeparatedByString:@"\n"];
    
    for (NSString *line in lines) {
        if (line.length > 0) {
            [self parseLogLine:line];
        }
    }
}

- (void)parseLogLine:(NSString *)line {
    // 简单的日志解析
    FLEXDoKitLogEntry *entry = [[FLEXDoKitLogEntry alloc] init];
    entry.timestamp = [NSDate date];
    entry.level = FLEXDoKitLogLevelInfo;
    entry.message = line;
    entry.tag = @"NSLog";      // ✅ 现在属性存在了
    entry.file = @"";          // ✅ 现在属性存在了
    entry.line = 0;            // ✅ 现在属性存在了
    
    [self addLogEntry:entry];
}

#pragma mark - 日志记录

- (void)logWithLevel:(FLEXDoKitLogLevel)level 
             message:(NSString *)message 
                 tag:(NSString *)tag 
                file:(NSString *)file 
                line:(NSUInteger)line {
    
    if (level < self.minimumLogLevel) {    // ✅ 现在属性存在了
        return;
    }
    
    FLEXDoKitLogEntry *entry = [[FLEXDoKitLogEntry alloc] init];
    entry.timestamp = [NSDate date];
    entry.level = level;
    entry.message = message;
    entry.tag = tag ?: @"";       // ✅ 现在属性存在了
    entry.file = file ?: @"";     // ✅ 现在属性存在了
    entry.line = line;            // ✅ 现在属性存在了
    
    [self addLogEntry:entry];
}

- (void)addLogEntry:(FLEXDoKitLogEntry *)entry {
    dispatch_async(self.logQueue, ^{
        [self.mutableLogEntries addObject:entry];
        
        // ✅ 修复：使用属性而不是错误的比较
        if (self.mutableLogEntries.count > self.maxLogEntries) {
            [self.mutableLogEntries removeObjectAtIndex:0];
        }
        
        // 发送通知
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"FLEXDoKitLogEntryAdded" object:entry];
        });
    });
}

// ✅ 实现缺失的方法
- (void)addLogWithMessage:(NSString *)message level:(FLEXDoKitLogLevel)level {
    [self logWithLevel:level message:message tag:@"Manual" file:@"" line:0];
}

#pragma mark - 日志管理

- (void)clearLogs {
    dispatch_async(self.logQueue, ^{
        [self.mutableLogEntries removeAllObjects];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"FLEXDoKitLogsCleared" object:nil];
        });
    });
}

- (NSArray<FLEXDoKitLogEntry *> *)filteredLogsWithLevel:(FLEXDoKitLogLevel)level {
    return [self.logEntries filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"level >= %d", level]];
}

- (NSArray<FLEXDoKitLogEntry *> *)filteredLogsWithTag:(NSString *)tag {
    return [self.logEntries filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"tag CONTAINS[cd] %@", tag]];
}

- (NSArray<FLEXDoKitLogEntry *> *)filteredLogsWithSearchText:(NSString *)searchText {
    return [self.logEntries filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"message CONTAINS[cd] %@", searchText]];
}

#pragma mark - 日志导出

- (NSString *)exportLogsAsString {
    NSMutableString *exportString = [NSMutableString string];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";
    
    for (FLEXDoKitLogEntry *entry in self.logEntries) {
        NSString *levelString = [self stringForLogLevel:entry.level];
        NSString *timestamp = [formatter stringFromDate:entry.timestamp];
        
        // ✅ 修复：现在entry.tag属性存在了
        [exportString appendFormat:@"[%@] %@ [%@] %@\n", 
         timestamp, levelString, entry.tag, entry.message];
    }
    
    return [exportString copy];
}

- (BOOL)exportLogsToFile:(NSString *)filePath {
    NSString *logContent = [self exportLogsAsString];
    NSError *error;
    
    BOOL success = [logContent writeToFile:filePath 
                                atomically:YES 
                                  encoding:NSUTF8StringEncoding 
                                     error:&error];
    
    if (!success) {
        NSLog(@"导出日志失败: %@", error.localizedDescription);
    }
    
    return success;
}

- (NSString *)stringForLogLevel:(FLEXDoKitLogLevel)level {
    switch (level) {
        case FLEXDoKitLogLevelVerbose: return @"VERBOSE";
        case FLEXDoKitLogLevelDebug: return @"DEBUG";
        case FLEXDoKitLogLevelInfo: return @"INFO";
        case FLEXDoKitLogLevelWarning: return @"WARNING";
        case FLEXDoKitLogLevelError: return @"ERROR";
        default: return @"UNKNOWN";
    }
}

@end