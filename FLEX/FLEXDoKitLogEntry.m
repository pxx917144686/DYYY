#import "FLEXDoKitLogEntry.h"

@implementation FLEXDoKitLogEntry

+ (instancetype)entryWithMessage:(NSString *)message level:(FLEXDoKitLogLevel)level {
    FLEXDoKitLogEntry *entry = [[self alloc] init];
    entry.message = message;
    entry.level = level;
    entry.timestamp = [NSDate date];
    entry.tag = @"";           // ✅ 初始化默认值
    entry.file = @"";          // ✅ 初始化默认值
    entry.line = 0;            // ✅ 初始化默认值
    entry.category = @"";      // ✅ 初始化默认值
    return entry;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // ✅ 设置默认值
        _message = @"";
        _level = FLEXDoKitLogLevelInfo;
        _timestamp = [NSDate date];
        _category = @"";
        _tag = @"";
        _file = @"";
        _line = 0;
    }
    return self;
}

- (NSString *)description {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";
    NSString *timeString = [formatter stringFromDate:self.timestamp];
    
    NSString *levelString;
    switch (self.level) {
        case FLEXDoKitLogLevelVerbose: levelString = @"VERBOSE"; break;
        case FLEXDoKitLogLevelDebug: levelString = @"DEBUG"; break;
        case FLEXDoKitLogLevelInfo: levelString = @"INFO"; break;
        case FLEXDoKitLogLevelWarning: levelString = @"WARNING"; break;
        case FLEXDoKitLogLevelError: levelString = @"ERROR"; break;
        default: levelString = @"UNKNOWN"; break;
    }
    
    return [NSString stringWithFormat:@"[%@] %@ [%@] %@", timeString, levelString, self.tag, self.message];
}

@end