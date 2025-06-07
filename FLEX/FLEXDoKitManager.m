#import "FLEXDoKitManager.h"
#import "FLEXDoKitFloatingWindow.h"

@interface FLEXDoKitManager ()
@property (nonatomic, strong) FLEXDoKitFloatingWindow *floatingWindow;
@property (nonatomic, strong) NSMutableDictionary *toolsRegistry;
@end

@implementation FLEXDoKitManager

+ (instancetype)sharedInstance {
    static FLEXDoKitManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _registeredTools = [NSMutableArray new];
        _toolsRegistry = [NSMutableDictionary new];
        _isFloatingWindowEnabled = YES;
    }
    return self;
}

- (void)registerTool:(Class)toolClass withName:(NSString *)name category:(NSString *)category {
    NSDictionary *toolInfo = @{
        @"class": toolClass,
        @"name": name,
        @"category": category
    };
    [self.registeredTools addObject:toolInfo];
    self.toolsRegistry[name] = toolInfo;
}

- (void)unregisterToolWithName:(NSString *)name {
    NSDictionary *toolInfo = self.toolsRegistry[name];
    if (toolInfo) {
        [self.registeredTools removeObject:toolInfo];
        [self.toolsRegistry removeObjectForKey:name];
    }
}

- (void)showFloatingWindow {
    if (!self.floatingWindow) {
        self.floatingWindow = [[FLEXDoKitFloatingWindow alloc] init];
    }
    [self.floatingWindow show];
}

- (void)hideFloatingWindow {
    [self.floatingWindow hide];
}

- (void)startTool:(NSString *)toolName {
    NSDictionary *toolInfo = self.toolsRegistry[toolName];
    if (toolInfo) {
        NSLog(@"🔧 启动工具: %@", toolName);
        Class toolClass = toolInfo[@"class"];
        if (toolClass) {
            // 实例化工具类
            id toolInstance = [[toolClass alloc] init];
            if ([toolInstance respondsToSelector:@selector(start)]) {
                [toolInstance performSelector:@selector(start)];
            }
        }
    } else {
        NSLog(@"❌ 工具未找到: %@", toolName);
    }
}

- (void)stopTool:(NSString *)toolName {
    NSDictionary *toolInfo = self.toolsRegistry[toolName];
    if (toolInfo) {
        NSLog(@"⏹️ 停止工具: %@", toolName);
        Class toolClass = toolInfo[@"class"];
        if (toolClass) {
            // 实例化工具类
            id toolInstance = [[toolClass alloc] init];
            if ([toolInstance respondsToSelector:@selector(stop)]) {
                [toolInstance performSelector:@selector(stop)];
            }
        }
    } else {
        NSLog(@"❌ 工具未找到: %@", toolName);
    }
}

@end