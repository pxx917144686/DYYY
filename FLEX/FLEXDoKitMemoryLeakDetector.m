#import "FLEXDoKitMemoryLeakDetector.h"
#import <objc/runtime.h>
#import <UIKit/UIKit.h>

@implementation FLEXDoKitLeakInfo

- (NSString *)formattedDetectionTime {
    if (!self.detectedTime) return @"未知时间";
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateStyle = NSDateFormatterShortStyle;
    formatter.timeStyle = NSDateFormatterShortStyle;
    return [formatter stringFromDate:self.detectedTime];
}

- (NSString *)severityLevel {
    if (self.instanceCount > 100) {
        return @"严重";
    } else if (self.instanceCount > 50) {
        return @"中等";
    } else if (self.instanceCount > 20) {
        return @"轻微";
    } else {
        return @"可疑";
    }
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p> 类名:%@ 实例数:%lu 严重度:%@ 检测时间:%@",
            NSStringFromClass([self class]), self,
            self.className, (unsigned long)self.instanceCount,
            [self severityLevel], [self formattedDetectionTime]];
}

@end

@interface FLEXDoKitMemoryLeakDetector ()
@property (nonatomic, strong) NSMutableArray<FLEXDoKitLeakInfo *> *mutableLeakInfos;
@property (nonatomic, strong) NSTimer *detectionTimer;
@property (nonatomic, strong) NSMutableDictionary *classInstanceCounts;
@property (nonatomic, strong) NSMutableDictionary *previousInstanceCounts;
@end

@implementation FLEXDoKitMemoryLeakDetector

+ (instancetype)sharedInstance {
    static FLEXDoKitMemoryLeakDetector *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _mutableLeakInfos = [NSMutableArray new];
        _classInstanceCounts = [NSMutableDictionary new];
        _previousInstanceCounts = [NSMutableDictionary new];
        _isDetecting = NO;
    }
    return self;
}

- (NSMutableArray<FLEXDoKitLeakInfo *> *)leakInfos {
    return self.mutableLeakInfos;
}

#pragma mark - 内存泄漏检测

- (void)startLeakDetection {
    if (self.isDetecting) return;
    
    self.isDetecting = YES;
    
    // 定时检测
    self.detectionTimer = [NSTimer scheduledTimerWithTimeInterval:10.0
                                                           target:self
                                                         selector:@selector(performLeakDetection)
                                                         userInfo:nil
                                                          repeats:YES];
    
    NSLog(@"内存泄漏检测已启动");
}

- (void)stopLeakDetection {
    if (!self.isDetecting) return;
    
    self.isDetecting = NO;
    
    [self.detectionTimer invalidate];
    self.detectionTimer = nil;
    
    NSLog(@"内存泄漏检测已停止");
}

- (void)performLeakDetection {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        [self detectPotentialLeaks];
    });
}

- (void)detectPotentialLeaks {
    // 获取当前所有类的实例数量
    NSMutableDictionary *currentCounts = [NSMutableDictionary new];
    
    // 遍历所有已注册的类
    unsigned int classCount;
    Class *classes = objc_copyClassList(&classCount);
    
    for (unsigned int i = 0; i < classCount; i++) {
        Class cls = classes[i];
        NSString *className = NSStringFromClass(cls);
        
        // 只检测UIKit和自定义类
        if ([className hasPrefix:@"UI"] || 
            [className hasPrefix:@"NS"] || 
            [className containsString:@"ViewController"] ||
            [className containsString:@"View"]) {
            
            NSUInteger instanceCount = [self getInstanceCountForClass:cls];
            if (instanceCount > 0) {
                currentCounts[className] = @(instanceCount);
            }
        }
    }
    
    free(classes);
    
    // 比较前后实例数量变化
    [self analyzeInstanceCountChanges:currentCounts];
    
    // 更新之前的计数
    self.previousInstanceCounts = [currentCounts mutableCopy];
}

- (NSUInteger)getInstanceCountForClass:(Class)cls {
    NSUInteger count = 0;
    
    // 使用objc_getClassList和objc_getAssociatedObject等方法
    // 这里简化实现，实际项目中可能需要更复杂的内存检测逻辑
    
    // 获取所有对象实例（简化版本）
    size_t size = class_getInstanceSize(cls);
    if (size > 0) {
        // 这里应该实现更精确的实例计数逻辑
        // 由于objc runtime限制，这里提供一个模拟实现
        count = arc4random() % 10; // 模拟数据
    }
    
    return count;
}

- (void)analyzeInstanceCountChanges:(NSDictionary *)currentCounts {
    for (NSString *className in currentCounts.allKeys) {
        NSUInteger currentCount = [currentCounts[className] unsignedIntegerValue];
        NSUInteger previousCount = [self.previousInstanceCounts[className] unsignedIntegerValue];
        
        // 检测实例数量持续增长的类（可能存在泄漏）
        if (currentCount > previousCount && currentCount > 10) {
            [self detectLeakForClass:className currentCount:currentCount previousCount:previousCount];
        }
    }
}

- (void)detectLeakForClass:(NSString *)className currentCount:(NSUInteger)currentCount previousCount:(NSUInteger)previousCount {
    // 检查是否已经报告过这个类的泄漏
    BOOL alreadyReported = NO;
    for (FLEXDoKitLeakInfo *info in self.mutableLeakInfos) {
        if ([info.className isEqualToString:className]) {
            // 更新现有记录
            info.instanceCount = currentCount;
            info.detectedTime = [NSDate date];
            alreadyReported = YES;
            break;
        }
    }
    
    if (!alreadyReported) {
        // 创建新的泄漏信息
        FLEXDoKitLeakInfo *leakInfo = [[FLEXDoKitLeakInfo alloc] init];
        leakInfo.className = className;
        leakInfo.instanceCount = currentCount;
        leakInfo.detectedTime = [NSDate date];
        leakInfo.suspiciousInstances = [self getSuspiciousInstancesForClass:className];
        
        [self.mutableLeakInfos addObject:leakInfo];
        
        // 发送通知
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"FLEXDoKitMemoryLeakDetected" object:leakInfo];
        });
        
        NSLog(@"检测到可能的内存泄漏: %@ (实例数: %lu)", className, (unsigned long)currentCount);
    }
}

- (NSArray *)getSuspiciousInstancesForClass:(NSString *)className {
    // 获取可疑实例的简化实现
    // 实际实现需要更复杂的内存分析
    return @[];
}

#pragma mark - ViewController生命周期监控

- (void)startViewControllerLeakDetection {
    // Hook ViewController的生命周期方法
    [self hookViewControllerMethods];
}

- (void)hookViewControllerMethods {
    // Hook viewDidDisappear
    Class vcClass = [UIViewController class];
    
    Method originalMethod = class_getInstanceMethod(vcClass, @selector(viewDidDisappear:));
    Method swizzledMethod = class_getInstanceMethod([self class], @selector(flex_viewDidDisappear:));
    
    if (originalMethod && swizzledMethod) {
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
}

- (void)flex_viewDidDisappear:(BOOL)animated {
    // 调用原始方法
    [self flex_viewDidDisappear:animated];
    
    // 检测ViewController是否在应该被释放时仍然存在
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self) {
            NSString *className = NSStringFromClass([self class]);
            NSLog(@"警告: %@ 在viewDidDisappear后5秒仍然存在，可能存在内存泄漏", className);
            
            // 创建泄漏报告
            FLEXDoKitLeakInfo *leakInfo = [[FLEXDoKitLeakInfo alloc] init];
            leakInfo.className = className;
            leakInfo.instanceCount = 1;
            leakInfo.detectedTime = [NSDate date];
            
            [[[FLEXDoKitMemoryLeakDetector sharedInstance] mutableLeakInfos] addObject:leakInfo];
            
            [[NSNotificationCenter defaultCenter] postNotificationName:@"FLEXDoKitMemoryLeakDetected" object:leakInfo];
        }
    });
}

#pragma mark - 泄漏信息管理

- (void)clearLeakInfos {
    [self.mutableLeakInfos removeAllObjects];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"FLEXDoKitLeakInfosCleared" object:nil];
}

@end