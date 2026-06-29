//
//  FLEXPerformanceMonitor.m
//  FLEX
//
//  Created based on DoKit performance tools.
//  Copyright © 2023 FLEX Team. All rights reserved.
//

#import "FLEXPerformanceMonitor.h"
#import <mach/mach.h>
#import <sys/sysctl.h>
#import <net/if.h>
#import <net/if_dl.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <ifaddrs.h>

@interface FLEXPerformanceMonitor ()

@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, assign) NSTimeInterval lastTimestamp;
@property (nonatomic, assign) NSInteger frameCount;
@property (nonatomic, assign) float currentFPS;

@property (nonatomic, strong) NSTimer *cpuTimer;
@property (nonatomic, assign) float cpuUsage;

@property (nonatomic, strong) NSTimer *memoryTimer;
@property (nonatomic, assign) double memoryUsage;

@property (nonatomic, strong) NSTimer *networkTimer;
@property (nonatomic, assign) uint64_t lastDownloadBytes;
@property (nonatomic, assign) uint64_t lastUploadBytes;
@property (nonatomic, assign) uint64_t downloadFlowBytes;
@property (nonatomic, assign) uint64_t uploadFlowBytes;

@property (nonatomic, strong) NSDate *classLoadStartTime;
@property (nonatomic, strong) NSMutableDictionary *classLoadTimes;
@property (nonatomic, strong) NSMutableArray *methodProfilingResults;
@property (nonatomic, assign) BOOL isProfilingActive;

// @property (nonatomic, assign) CGFloat fps;
// @property (nonatomic, assign) CGFloat cpuUsage;
// @property (nonatomic, assign) CGFloat memoryUsage;
// @property (nonatomic, assign) CGFloat uploadFlowBytes;
// @property (nonatomic, assign) CGFloat downloadFlowBytes;

@property (nonatomic, strong) CADisplayLink *fpsDisplayLink;
@property (nonatomic, assign) CFTimeInterval lastFPSTime;
@property (nonatomic, assign) NSInteger fpsCount;
@property (nonatomic, strong) NSMutableArray *profilingResults;
@property (nonatomic, assign) BOOL isMethodProfiling;

@end

@implementation FLEXPerformanceMonitor

+ (instancetype)sharedInstance {
    static FLEXPerformanceMonitor *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[FLEXPerformanceMonitor alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _classLoadTimes = [NSMutableDictionary dictionary];
        _methodProfilingResults = [NSMutableArray array];
        _profilingResults = [NSMutableArray array];
        _isProfilingActive = NO;
        _isMethodProfiling = NO;
        
        // 初始化网络流量数据
        _lastDownloadBytes = 0;
        _lastUploadBytes = 0;
        _downloadFlowBytes = 0;
        _uploadFlowBytes = 0;
    }
    return self;
}

#pragma mark - FPS监控

- (void)startFPSMonitoring {
    if (self.fpsDisplayLink) {
        return;
    }
    
    self.fpsDisplayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(fpsDisplayLinkTick:)];
    [self.fpsDisplayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    self.lastFPSTime = CACurrentMediaTime();
    self.fpsCount = 0;
}

- (void)stopFPSMonitoring {
    if (self.fpsDisplayLink) {
        [self.fpsDisplayLink invalidate];
        self.fpsDisplayLink = nil;
    }
}

- (void)fpsDisplayLinkTick:(CADisplayLink *)displayLink {
    if (self.lastFPSTime == 0) {
        self.lastFPSTime = displayLink.timestamp;
        return;
    }
    
    self.fpsCount++;
    
    CFTimeInterval interval = displayLink.timestamp - self.lastFPSTime;
    if (interval >= 1.0) {
        self.currentFPS = self.fpsCount / interval;
        self.fpsCount = 0;
        self.lastFPSTime = displayLink.timestamp;
    }
}

#pragma mark - CPU监控

- (void)startCPUMonitoring {
    if (self.cpuTimer) {
        return;
    }
    
    self.cpuTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                     target:self
                                                   selector:@selector(updateCPUUsage)
                                                   userInfo:nil
                                                    repeats:YES];
}

- (void)stopCPUMonitoring {
    if (self.cpuTimer) {
        [self.cpuTimer invalidate];
        self.cpuTimer = nil;
    }
}

- (void)updateCPUUsage {
    thread_act_array_t threads;
    mach_msg_type_number_t threadCount = 0;
    
    kern_return_t kr = task_threads(mach_task_self(), &threads, &threadCount);
    if (kr != KERN_SUCCESS) {
        self.cpuUsage = 0.0;
        return;
    }
    
    float totalCPU = 0.0;
    
    for (unsigned int i = 0; i < threadCount; i++) {
        thread_info_data_t threadInfo;
        thread_basic_info_t threadBasicInfo;
        mach_msg_type_number_t threadInfoCount = THREAD_INFO_MAX;
        
        kr = thread_info(threads[i], THREAD_BASIC_INFO, (thread_info_t)threadInfo, &threadInfoCount);
        if (kr == KERN_SUCCESS) {
            threadBasicInfo = (thread_basic_info_t)threadInfo;
            
            if (!(threadBasicInfo->flags & TH_FLAGS_IDLE)) {
                totalCPU += threadBasicInfo->cpu_usage / (float)TH_USAGE_SCALE * 100.0;
            }
        }
    }
    
    vm_deallocate(mach_task_self(), (vm_offset_t)threads, threadCount * sizeof(thread_t));
    
    self.cpuUsage = totalCPU;
}

#pragma mark - 内存监控

- (void)startMemoryMonitoring {
    if (self.memoryTimer) {
        return;
    }
    
    self.memoryTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                        target:self
                                                      selector:@selector(updateMemoryUsage)
                                                      userInfo:nil
                                                       repeats:YES];
}

- (void)stopMemoryMonitoring {
    if (self.memoryTimer) {
        [self.memoryTimer invalidate];
        self.memoryTimer = nil;
    }
}

- (void)updateMemoryUsage {
    struct task_basic_info info;
    mach_msg_type_number_t size = sizeof(info);
    kern_return_t kr = task_info(mach_task_self(),
                                TASK_BASIC_INFO,
                                (task_info_t)&info,
                                &size);
    
    if (kr == KERN_SUCCESS) {
        self.memoryUsage = info.resident_size / 1024.0 / 1024.0; // MB
    } else {
        self.memoryUsage = 0.0;
    }
}

#pragma mark - 网络监控

- (void)startNetworkMonitoring {
    if (self.networkTimer) {
        return;
    }
    
    self.networkTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                         target:self
                                                       selector:@selector(updateNetworkUsage)
                                                       userInfo:nil
                                                        repeats:YES];
}

- (void)stopNetworkMonitoring {
    if (self.networkTimer) {
        [self.networkTimer invalidate];
        self.networkTimer = nil;
    }
}

- (void)updateNetworkUsage {
    struct ifaddrs *addrs;
    const struct ifaddrs *cursor;
    
    uint64_t totalDownload = 0;
    uint64_t totalUpload = 0;
    
    if (getifaddrs(&addrs) == 0) {
        cursor = addrs;
        while (cursor != NULL) {
            if (cursor->ifa_addr && cursor->ifa_addr->sa_family == AF_LINK) {
                const struct if_data *ifa_data = (struct if_data *)cursor->ifa_data;
                if (ifa_data != NULL) {
                    totalDownload += ifa_data->ifi_ibytes;
                    totalUpload += ifa_data->ifi_obytes;
                }
            }
            cursor = cursor->ifa_next;
        }
        freeifaddrs(addrs);
    }
    
    if (self.lastDownloadBytes > 0) {
        self.downloadFlowBytes = totalDownload - self.lastDownloadBytes;
        self.uploadFlowBytes = totalUpload - self.lastUploadBytes;
    }
    
    self.lastDownloadBytes = totalDownload;
    self.lastUploadBytes = totalUpload;
}

#pragma mark - 所有监控控制

- (void)startAllMonitoring {
    [self startFPSMonitoring];
    [self startCPUMonitoring];
    [self startMemoryMonitoring];
    [self startNetworkMonitoring];
}

- (void)stopAllMonitoring {
    [self stopFPSMonitoring];
    [self stopCPUMonitoring];
    [self stopMemoryMonitoring];
    [self stopNetworkMonitoring];
}

#pragma mark - 类加载时间跟踪

- (void)startTrackingClassLoadTime {
    self.classLoadStartTime = [NSDate date];
}

- (NSArray *)getClassLoadTimeInfo {
    return [self.classLoadTimes allValues];
}

#pragma mark - 方法性能分析

- (void)startMethodProfiling {
    self.isMethodProfiling = YES;
    [self.profilingResults removeAllObjects];
}

- (void)stopMethodProfiling {
    self.isMethodProfiling = NO;
}

- (NSArray *)getProfilingResults {
    return [self.profilingResults copy];
}

@end