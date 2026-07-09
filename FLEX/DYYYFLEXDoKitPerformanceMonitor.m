#import "DYYYFLEXDoKitPerformanceMonitor.h"
#import <mach/mach.h>
#import <sys/sysctl.h>
#import <sys/types.h>
#import <sys/time.h>

// 兼容性处理
#ifndef __has_include
#define __has_include(x) 0
#endif

#if __has_include(<ifaddrs.h>)
#import <ifaddrs.h>
#import <net/if.h>
#import <net/if_dl.h>
#define FLEX_NETWORK_MONITORING_AVAILABLE 1
#else
#define FLEX_NETWORK_MONITORING_AVAILABLE 0
#warning "网络监控功能不可用：缺少ifaddrs.h支持"
#endif

@interface DYYYFLEXDoKitPerformanceMonitor ()
@property (nonatomic, strong) CADisplayLink *fpsDisplayLink;
@property (nonatomic, strong) NSTimer *cpuTimer;
@property (nonatomic, strong) NSTimer *memoryTimer;
@property (nonatomic, strong) CADisplayLink *lagDetectionDisplayLink;
@property (nonatomic, strong) NSTimer *networkTimer;
@property (nonatomic, assign) CFTimeInterval lastFPSTime;
@property (nonatomic, assign) CFTimeInterval lastLagCheckTime;
@property (nonatomic, assign) NSInteger fpsCount;
@property (nonatomic, assign) NSInteger lagFrameCount;
@property (nonatomic, assign) uint64_t uploadFlowBytes;
@property (nonatomic, assign) uint64_t downloadFlowBytes;
@end

@implementation DYYYFLEXDoKitPerformanceMonitor

+ (instancetype)sharedInstance {
    static DYYYFLEXDoKitPerformanceMonitor *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (void)startFPSMonitoring {
    if (self.fpsDisplayLink) return;
    
    self.fpsDisplayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(fpsDisplayLinkTick:)];
    [self.fpsDisplayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    self.lastFPSTime = CACurrentMediaTime();
    self.fpsCount = 0;
}

- (void)stopFPSMonitoring {
    [self.fpsDisplayLink invalidate];
    self.fpsDisplayLink = nil;
}

- (void)fpsDisplayLinkTick:(CADisplayLink *)displayLink {
    self.fpsCount++;
    CFTimeInterval currentTime = CACurrentMediaTime();
    CFTimeInterval deltaTime = currentTime - self.lastFPSTime;
    
    if (deltaTime >= 1.0) {
        _currentFPS = self.fpsCount / deltaTime;
        self.fpsCount = 0;
        self.lastFPSTime = currentTime;
        
        // 发送FPS更新通知
        [[NSNotificationCenter defaultCenter] postNotificationName:@"FLEXDoKitFPSUpdated" 
                                                            object:@(self.currentFPS)];
    }
}

- (void)startCPUMonitoring {
    if (self.cpuTimer) return;
    
    self.cpuTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                     target:self
                                                   selector:@selector(updateCPUUsage)
                                                   userInfo:nil
                                                    repeats:YES];
}

- (void)stopCPUMonitoring {
    [self.cpuTimer invalidate];
    self.cpuTimer = nil;
}

- (void)updateCPUUsage {
    thread_act_array_t threads;
    mach_msg_type_number_t threadCount = 0;
    
    if (task_threads(mach_task_self(), &threads, &threadCount) != KERN_SUCCESS) {
        return;
    }
    
    double totalCPU = 0;
    for (int i = 0; i < threadCount; i++) {
        thread_info_data_t threadInfo;
        mach_msg_type_number_t threadInfoCount = THREAD_INFO_MAX;
        
        if (thread_info(threads[i], THREAD_BASIC_INFO, (thread_info_t)threadInfo, &threadInfoCount) == KERN_SUCCESS) {
            thread_basic_info_t basicInfo = (thread_basic_info_t)threadInfo;
            if (!(basicInfo->flags & TH_FLAGS_IDLE)) {
                totalCPU += basicInfo->cpu_usage / (double)TH_USAGE_SCALE * 100.0;
            }
        }
    }
    
    vm_deallocate(mach_task_self(), (vm_offset_t)threads, threadCount * sizeof(thread_t));
    
    _currentCPUUsage = totalCPU;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"FLEXDoKitCPUUpdated" 
                                                        object:@(self.currentCPUUsage)];
}

- (void)startMemoryMonitoring {
    if (self.memoryTimer) return;
    
    self.memoryTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                        target:self
                                                      selector:@selector(updateMemoryUsage)
                                                      userInfo:nil
                                                       repeats:YES];
}

- (void)stopMemoryMonitoring {
    [self.memoryTimer invalidate];
    self.memoryTimer = nil;
}

- (void)updateMemoryUsage {
    vm_size_t page_size;
    mach_port_t mach_port = mach_host_self();
    host_page_size(mach_port, &page_size);
    
    vm_statistics64_data_t vm_stat;
    mach_msg_type_number_t host_size = sizeof(vm_statistics64_data_t) / sizeof(natural_t);
    host_statistics64(mach_port, HOST_VM_INFO, (host_info64_t)&vm_stat, &host_size);
    
    // 计算内存使用情况（MB）
    uint64_t used_memory = (uint64_t)(vm_stat.active_count + vm_stat.inactive_count + vm_stat.wire_count) * page_size;
    _currentMemoryUsage = used_memory / (1024.0 * 1024.0);
    
    // 发送内存更新通知
    [[NSNotificationCenter defaultCenter] postNotificationName:@"FLEXDoKitMemoryUpdated" 
                                                        object:@(self.currentMemoryUsage)];
}

- (void)startLagDetection {
    // 使用CADisplayLink检测主线程卡顿
    if (self.lagDetectionDisplayLink) {
        [self stopLagDetection];
    }
    
    self.lagDetectionDisplayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(lagDetectionTick:)];
    [self.lagDetectionDisplayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    
    self.lastLagCheckTime = CACurrentMediaTime();
    self.lagFrameCount = 0;
    
    NSLog(@"✅ 卡顿检测已启动");
}

- (void)stopLagDetection {
    if (self.lagDetectionDisplayLink) {
        [self.lagDetectionDisplayLink invalidate];
        self.lagDetectionDisplayLink = nil;
        NSLog(@"✅ 卡顿检测已停止");
    }
}

- (void)lagDetectionTick:(CADisplayLink *)displayLink {
    CFTimeInterval currentTime = CACurrentMediaTime();
    CFTimeInterval deltaTime = currentTime - self.lastLagCheckTime;
    
    // 正常帧率应该是1/60 ≈ 0.0167秒
    if (deltaTime > 0.033) { // 超过2帧时间认为是卡顿
        self.lagFrameCount++;
    }
    
    self.lastLagCheckTime = currentTime;
    
    // 每秒统计一次卡顿情况
    static CFTimeInterval lastReportTime = 0;
    if (currentTime - lastReportTime >= 1.0) {
        if (self.lagFrameCount > 0) {
            NSLog(@"⚠️ 检测到卡顿帧: %ld", (long)self.lagFrameCount);
            
            // 发送卡顿通知
            [[NSNotificationCenter defaultCenter] postNotificationName:@"FLEXDoKitLagDetected" 
                                                                object:@(self.lagFrameCount)];
        }
        
        self.lagFrameCount = 0;
        lastReportTime = currentTime;
    }
}

- (void)calculateAppLaunchTime {
    // 获取进程启动时间
    struct kinfo_proc proc;
    size_t size = sizeof(proc);
    int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()};
    
    if (sysctl(mib, 4, &proc, &size, NULL, 0) == 0) {
        struct timeval startTime = proc.kp_proc.p_starttime;
        
        // 计算启动到现在的时间
        struct timeval currentTime;
        gettimeofday(&currentTime, NULL);
        
        NSTimeInterval launchTime = (currentTime.tv_sec - startTime.tv_sec) + 
                                   (currentTime.tv_usec - startTime.tv_usec) / 1000000.0;
        
        _appLaunchTime = launchTime;
        
        NSLog(@"📱 应用启动耗时: %.3f秒", launchTime);
        
        // 发送启动时间通知
        [[NSNotificationCenter defaultCenter] postNotificationName:@"FLEXDoKitAppLaunchTimeCalculated" 
                                                            object:@(launchTime)];
    } else {
        NSLog(@"❌ 无法计算应用启动时间");
        _appLaunchTime = 0;
    }
}

- (void)startNetworkMonitoring {
    // 启动网络流量监控
    if (self.networkTimer) return;
    
    self.networkTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                         target:self
                                                       selector:@selector(updateNetworkUsage)
                                                       userInfo:nil
                                                        repeats:YES];
    
    [self resetNetworkCounters];
}

- (void)stopNetworkMonitoring {
    [self.networkTimer invalidate];
    self.networkTimer = nil;
}

- (void)updateNetworkUsage {
#if FLEX_NETWORK_MONITORING_AVAILABLE
    // ✅ 只在支持的平台上编译网络监控代码
    struct ifaddrs *addrs = NULL;
    
    @try {
        if (getifaddrs(&addrs) == 0) {
            struct ifaddrs *cursor = addrs;
            
            uint64_t totalUploadBytes = 0;
            uint64_t totalDownloadBytes = 0;
            
            while (cursor != NULL) {
                // ✅ 检查网络接口类型
                if (cursor->ifa_addr && cursor->ifa_addr->sa_family == AF_LINK) {
                    struct if_data *if_data = (struct if_data *)cursor->ifa_data;
                    if (if_data) {
                        totalUploadBytes += if_data->ifi_obytes;
                        totalDownloadBytes += if_data->ifi_ibytes;
                    }
                }
                cursor = cursor->ifa_next;
            }
            
            // 计算流量速度（字节/秒）
            static uint64_t lastUploadBytes = 0;
            static uint64_t lastDownloadBytes = 0;
            
            if (lastUploadBytes > 0 && lastDownloadBytes > 0) {
                _uploadFlowBytes = totalUploadBytes - lastUploadBytes;
                _downloadFlowBytes = totalDownloadBytes - lastDownloadBytes;
            } else {
                // 首次运行，初始化
                _uploadFlowBytes = 0;
                _downloadFlowBytes = 0;
            }
            
            lastUploadBytes = totalUploadBytes;
            lastDownloadBytes = totalDownloadBytes;
            
            // 发送网络更新通知
            NSDictionary *networkInfo = @{
                @"upload": @(self.uploadFlowBytes),
                @"download": @(self.downloadFlowBytes),
                @"totalUpload": @(totalUploadBytes),
                @"totalDownload": @(totalDownloadBytes)
            };
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:@"FLEXDoKitNetworkUpdated" 
                                                                    object:networkInfo];
            });
            
        } else {
            NSLog(@"⚠️ 获取网络接口信息失败");
        }
        
    } @finally {
        if (addrs) {
            freeifaddrs(addrs);
        }
    }
#else
    // 不支持网络监控的平台
    NSLog(@"⚠️ 当前平台不支持网络监控功能");
    
    // 发送空的网络信息
    NSDictionary *networkInfo = @{
        @"upload": @0,
        @"download": @0,
        @"error": @"不支持网络监控"
    };
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"FLEXDoKitNetworkUpdated" 
                                                            object:networkInfo];
    });
#endif
}

- (void)resetNetworkCounters {
    _uploadFlowBytes = 0;
    _downloadFlowBytes = 0;
}

@end