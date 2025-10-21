#import "FLEXDoKitNetworkMonitor.h"
#import <objc/runtime.h>

@interface FLEXDoKitNetworkMonitor ()
@property (nonatomic, strong) NSMutableArray *mutableNetworkRequests;
@property (nonatomic, strong) NSMutableDictionary *mockRules;
@property (nonatomic, assign) BOOL isMockEnabled;
@property (nonatomic, assign) BOOL isMonitoring;
@property (nonatomic, assign) NSTimeInterval networkDelay;
@property (nonatomic, assign) BOOL shouldSimulateError;
@end

@implementation FLEXDoKitNetworkMonitor

+ (instancetype)sharedInstance {
    static FLEXDoKitNetworkMonitor *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _mutableNetworkRequests = [NSMutableArray new];
        _mockRules = [NSMutableDictionary new];
        _isMockEnabled = NO;
        _isMonitoring = NO;
        _networkDelay = 0;
        _shouldSimulateError = NO;
    }
    return self;
}

- (NSMutableArray *)networkRequests {
    return self.mutableNetworkRequests;
}

#pragma mark - 网络监控

- (void)startNetworkMonitoring {
    if (self.isMonitoring) return;
    
    self.isMonitoring = YES;
    
    // Hook NSURLSession
    [self hookNSURLSession];
    
    // Hook NSURLConnection (如果需要支持旧版本)
    [self hookNSURLConnection];
    
    NSLog(@"✅ 网络监控已启动");
}

- (void)stopNetworkMonitoring {
    if (!self.isMonitoring) return;
    
    self.isMonitoring = NO;
    
    // 恢复原始方法
    [self restoreNSURLSession];
    [self restoreNSURLConnection];
    
    NSLog(@"✅ 网络监控已停止");
}

#pragma mark - Method Swizzling

- (void)hookNSURLSession {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class sessionClass = [NSURLSession class];
        
        // Hook dataTaskWithRequest:completionHandler:
        SEL originalSelector = @selector(dataTaskWithRequest:completionHandler:);
        SEL swizzledSelector = @selector(flex_dataTaskWithRequest:completionHandler:);
        
        Method originalMethod = class_getInstanceMethod(sessionClass, originalSelector);
        Method swizzledMethod = class_getInstanceMethod(self.class, swizzledSelector);
        
        if (originalMethod && swizzledMethod) {
            BOOL didAddMethod = class_addMethod(sessionClass,
                                              originalSelector,
                                              method_getImplementation(swizzledMethod),
                                              method_getTypeEncoding(swizzledMethod));
            
            if (didAddMethod) {
                class_replaceMethod(sessionClass,
                                  swizzledSelector,
                                  method_getImplementation(originalMethod),
                                  method_getTypeEncoding(originalMethod));
            } else {
                method_exchangeImplementations(originalMethod, swizzledMethod);
            }
        }
    });
}

- (void)hookNSURLConnection {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class connectionClass = [NSURLConnection class];
        
        // Hook sendAsynchronousRequest:queue:completionHandler:
        SEL originalSelector = @selector(sendAsynchronousRequest:queue:completionHandler:);
        SEL swizzledSelector = @selector(flex_sendAsynchronousRequest:queue:completionHandler:);
        
        Method originalMethod = class_getClassMethod(connectionClass, originalSelector);
        Method swizzledMethod = class_getClassMethod(self.class, swizzledSelector);
        
        if (originalMethod && swizzledMethod) {
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }
    });
}

- (void)restoreNSURLSession {
    // 由于使用了dispatch_once，方法交换是永久的
    // 这里只是标记监控状态，实际的hook不会被撤销
    NSLog(@"✅ NSURLSession hook 状态已更新");
}

- (void)restoreNSURLConnection {
    // 同样，这里只是状态标记
    NSLog(@"✅ NSURLConnection hook 状态已更新");
}

#pragma mark - Swizzled Methods

- (NSURLSessionDataTask *)flex_dataTaskWithRequest:(NSURLRequest *)request 
                                  completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler {
    
    // 只在监控状态下记录请求
    if (self.isMonitoring) {
        [self recordNetworkRequest:request];
        
        // 检查Mock规则
        if (self.isMockEnabled) {
            NSDictionary *mockResponse = [self checkMockRuleForRequest:request];
            if (mockResponse) {
                [self simulateMockResponse:mockResponse completionHandler:completionHandler];
                return nil; // 返回一个dummy task或者实际的mock task
            }
        }
        
        // 应用网络延迟和错误模拟
        void (^wrappedHandler)(NSData *, NSURLResponse *, NSError *) = ^(NSData *data, NSURLResponse *response, NSError *error) {
            if (self.shouldSimulateError && self.isMonitoring) {
                error = [NSError errorWithDomain:@"FLEXDoKitNetworkError" 
                                           code:500 
                                       userInfo:@{NSLocalizedDescriptionKey: @"模拟网络错误"}];
                data = nil;
                response = nil;
            }
            
            // 记录响应
            if (self.isMonitoring) {
                [self recordNetworkResponse:response data:data error:error forRequest:request];
            }
            
            if (self.networkDelay > 0 && self.isMonitoring) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.networkDelay * NSEC_PER_SEC)), 
                             dispatch_get_main_queue(), ^{
                    if (completionHandler) completionHandler(data, response, error);
                });
            } else {
                if (completionHandler) completionHandler(data, response, error);
            }
        };
        
        // 调用原始方法
        return [self flex_dataTaskWithRequest:request completionHandler:wrappedHandler];
    }
    
    // 监控关闭时，直接调用原始方法
    return [self flex_dataTaskWithRequest:request completionHandler:completionHandler];
}

+ (void)flex_sendAsynchronousRequest:(NSURLRequest *)request 
                               queue:(NSOperationQueue *)queue 
                   completionHandler:(void (^)(NSURLResponse *, NSData *, NSError *))handler {
    
    FLEXDoKitNetworkMonitor *monitor = [FLEXDoKitNetworkMonitor sharedInstance];
    
    if (monitor.isMonitoring) {
        [monitor recordNetworkRequest:request];
        
        void (^wrappedHandler)(NSURLResponse *, NSData *, NSError *) = ^(NSURLResponse *response, NSData *data, NSError *error) {
            [monitor recordNetworkResponse:response data:data error:error forRequest:request];
            if (handler) handler(response, data, error);
        };
        
        [self flex_sendAsynchronousRequest:request queue:queue completionHandler:wrappedHandler];
    } else {
        [self flex_sendAsynchronousRequest:request queue:queue completionHandler:handler];
    }
}

#pragma mark - 请求记录

- (void)recordNetworkRequest:(NSURLRequest *)request {
    if (!request) return;
    
    NSMutableDictionary *requestInfo = [NSMutableDictionary dictionary];
    requestInfo[@"url"] = request.URL.absoluteString ?: @"";
    requestInfo[@"method"] = request.HTTPMethod ?: @"GET";
    requestInfo[@"headers"] = request.allHTTPHeaderFields ?: @{};
    requestInfo[@"timestamp"] = @([[NSDate date] timeIntervalSince1970]);
    
    if (request.HTTPBody) {
        NSString *bodyString = [[NSString alloc] initWithData:request.HTTPBody encoding:NSUTF8StringEncoding];
        requestInfo[@"body"] = bodyString ?: @"<Binary Data>";
    } else {
        requestInfo[@"body"] = @"";
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.mutableNetworkRequests addObject:requestInfo];
        
        // 限制记录数量，防止内存溢出
        if (self.mutableNetworkRequests.count > 1000) {
            [self.mutableNetworkRequests removeObjectAtIndex:0];
        }
        
        // 发送通知
        [[NSNotificationCenter defaultCenter] postNotificationName:@"FLEXDoKitNetworkRequestRecorded" 
                                                            object:requestInfo];
    });
}

- (void)recordNetworkResponse:(NSURLResponse *)response 
                         data:(NSData *)data 
                        error:(NSError *)error 
                   forRequest:(NSURLRequest *)request {
    if (!request) return;
    
    // 查找对应的请求记录
    __block NSMutableDictionary *requestInfo = nil;
    [self.mutableNetworkRequests enumerateObjectsWithOptions:NSEnumerationReverse 
                                                   usingBlock:^(NSMutableDictionary *obj, NSUInteger idx, BOOL *stop) {
        if ([obj[@"url"] isEqualToString:request.URL.absoluteString]) {
            requestInfo = obj;
            *stop = YES;
        }
    }];
    
    if (requestInfo) {
        if (response && [response isKindOfClass:[NSHTTPURLResponse class]]) {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            requestInfo[@"statusCode"] = @(httpResponse.statusCode);
            requestInfo[@"responseHeaders"] = httpResponse.allHeaderFields ?: @{};
        }
        
        if (data) {
            NSString *responseString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            requestInfo[@"responseData"] = responseString ?: @"<Binary Data>";
            requestInfo[@"responseSize"] = @(data.length);
        }
        
        if (error) {
            requestInfo[@"error"] = error.localizedDescription ?: @"Unknown Error";
        }
        
        requestInfo[@"duration"] = @([[NSDate date] timeIntervalSince1970] - [requestInfo[@"timestamp"] doubleValue]);
        
        // 发送响应通知
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"FLEXDoKitNetworkResponseRecorded" 
                                                                object:requestInfo];
        });
    }
}

#pragma mark - Mock功能

- (BOOL)isMockEnabled {
    return _isMockEnabled;
}

- (void)enableMockMode {
    _isMockEnabled = YES;
    NSLog(@"✅ Mock模式已启用");
}

- (void)disableMockMode {
    _isMockEnabled = NO;
    NSLog(@"✅ Mock模式已禁用");
}

- (void)addMockRule:(NSDictionary *)rule {
    if (!rule || !rule[@"url"]) return;
    
    NSString *key = [NSString stringWithFormat:@"%@_%@", 
                    rule[@"method"] ?: @"GET", 
                    rule[@"url"]];
    
    [self.mockRules setObject:rule forKey:key];
    NSLog(@"✅ Mock规则已添加: %@", key);
}

- (void)removeMockRule:(NSDictionary *)rule {
    if (!rule || !rule[@"url"]) return;
    
    NSString *key = [NSString stringWithFormat:@"%@_%@", 
                    rule[@"method"] ?: @"GET", 
                    rule[@"url"]];
    
    [self.mockRules removeObjectForKey:key];
    NSLog(@"✅ Mock规则已移除: %@", key);
}

- (NSDictionary *)checkMockRuleForRequest:(NSURLRequest *)request {
    if (!self.isMockEnabled || !request) return nil;
    
    NSString *key = [NSString stringWithFormat:@"%@_%@", 
                    request.HTTPMethod ?: @"GET", 
                    request.URL.absoluteString];
    
    return self.mockRules[key];
}

- (void)simulateMockResponse:(NSDictionary *)mockRule 
           completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler {
    if (!completionHandler) return;
    
    // 模拟响应数据
    NSString *responseString = mockRule[@"responseData"] ?: @"{}";
    NSData *responseData = [responseString dataUsingEncoding:NSUTF8StringEncoding];
    
    // 模拟HTTP响应
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] 
                                  initWithURL:[NSURL URLWithString:mockRule[@"url"]]
                                   statusCode:[mockRule[@"statusCode"] integerValue] ?: 200
                                  HTTPVersion:@"HTTP/1.1"
                                 headerFields:mockRule[@"headers"] ?: @{}];
    
    // 延迟回调以模拟网络延迟
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), 
                  dispatch_get_main_queue(), ^{
        completionHandler(responseData, response, nil);
    });
}

#pragma mark - 弱网模拟

- (void)simulateSlowNetwork:(NSTimeInterval)delay {
    self.networkDelay = delay;
    NSLog(@"✅ 网络延迟设置为: %.1f秒", delay);
}

- (void)simulateNetworkError {
    self.shouldSimulateError = YES;
    NSLog(@"✅ 网络错误模拟已启用");
}

- (void)resetNetworkSimulation {
    self.networkDelay = 0;
    self.shouldSimulateError = NO;
    self.isMockEnabled = NO;
    NSLog(@"✅ 网络模拟已重置");
}

@end