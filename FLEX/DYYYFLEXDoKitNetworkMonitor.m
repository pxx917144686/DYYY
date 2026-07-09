//
//  DYYYFLEXDoKitNetworkMonitor.m
//  FLEX++
//
//  基于 FLEX 原生网络监听能力的增强型网络监控器
//  深度修复：利用 DYYYFLEXNetworkObserver 和 DYYYFLEXNetworkRecorder
//  提供稳定可靠的网络请求监控、Mock 数据、弱网模拟功能
//

#import "DYYYFLEXDoKitNetworkMonitor.h"
#import "DYYYFLEXNetworkObserver.h"
#import "DYYYFLEXNetworkRecorder.h"
#import "DYYYFLEXNetworkTransaction.h"
#import <objc/runtime.h>

// MARK: - 通知名称定义
NSString *const FLEXDoKitNetworkRequestRecordedNotification = @"FLEXDoKitNetworkRequestRecordedNotification";
NSString *const FLEXDoKitNetworkResponseRecordedNotification = @"FLEXDoKitNetworkResponseRecordedNotification";

// MARK: - 关联对象 Key
static const void *kFLEXDoKitMockResponseKey = &kFLEXDoKitMockResponseKey;
static const void *kFLEXDoKitOriginalRequestKey = &kFLEXDoKitOriginalRequestKey;

@interface DYYYFLEXDoKitNetworkMonitor ()
@property (nonatomic, strong) NSMutableArray *mutableNetworkRequests;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableDictionary *> *requestMap;  // requestID -> requestInfo
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSDictionary *> *mockRules;  // key -> rule
@property (nonatomic, assign) BOOL mockEnabled;
@property (nonatomic, assign) BOOL monitoring;
@property (nonatomic, assign) NSTimeInterval networkDelay;
@property (nonatomic, assign) BOOL simulateError;
@property (nonatomic, strong) dispatch_queue_t monitorQueue;
@end

@implementation DYYYFLEXDoKitNetworkMonitor

// MARK: - 单例

+ (instancetype)sharedInstance {
    static DYYYFLEXDoKitNetworkMonitor *instance = nil;
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
        _requestMap = [NSMutableDictionary new];
        _mockRules = [NSMutableDictionary new];
        _mockEnabled = NO;
        _monitoring = NO;
        _networkDelay = 0;
        _simulateError = NO;
        _monitorQueue = dispatch_queue_create("com.flex++.DoKitNetworkMonitor", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

// MARK: - 公共属性

- (NSMutableArray *)networkRequests {
    return self.mutableNetworkRequests;
}

- (BOOL)isMonitoring {
    return _monitoring;
}

- (NSTimeInterval)networkDelay {
    return _networkDelay;
}

- (BOOL)shouldSimulateError {
    return _simulateError;
}

// MARK: - 网络监控控制

- (void)startNetworkMonitoring {
    if (self.monitoring) {
        return;
    }
    
    self.monitoring = YES;
    
    // 启用 FLEX 原生网络监听
    [DYYYFLEXNetworkObserver setEnabled:YES];
    
    // 监听 DYYYFLEXNetworkRecorder 的通知
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleNewTransaction:)
                                                 name:kFLEXNetworkRecorderNewTransactionNotification
                                               object:[DYYYFLEXNetworkRecorder defaultRecorder]];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleTransactionUpdated:)
                                                 name:kFLEXNetworkRecorderTransactionUpdatedNotification
                                               object:[DYYYFLEXNetworkRecorder defaultRecorder]];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleTransactionsCleared:)
                                                 name:kFLEXNetworkRecorderTransactionsClearedNotification
                                               object:[DYYYFLEXNetworkRecorder defaultRecorder]];
    
    // Hook NSURLSession 以支持 Mock 和弱网模拟
    [self hookNSURLSessionMethods];
    
    NSLog(@"✅ FLEXDoKit 网络监控已启动");
}

- (void)stopNetworkMonitoring {
    if (!self.monitoring) {
        return;
    }
    
    self.monitoring = NO;
    
    // 移除通知监听
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kFLEXNetworkRecorderNewTransactionNotification
                                                  object:[DYYYFLEXNetworkRecorder defaultRecorder]];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kFLEXNetworkRecorderTransactionUpdatedNotification
                                                  object:[DYYYFLEXNetworkRecorder defaultRecorder]];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kFLEXNetworkRecorderTransactionsClearedNotification
                                                  object:[DYYYFLEXNetworkRecorder defaultRecorder]];
    
    NSLog(@"⏸️ FLEXDoKit 网络监控已停止");
}

- (void)clearAllNetworkRequests {
    dispatch_async(self.monitorQueue, ^{
        [self.mutableNetworkRequests removeAllObjects];
        [self.requestMap removeAllObjects];
    });
    [[DYYYFLEXNetworkRecorder defaultRecorder] clearRecordedActivity];
}

// MARK: - FLEX 通知处理

- (void)handleNewTransaction:(NSNotification *)notification {
    DYYYFLEXNetworkTransaction *transaction = notification.userInfo[kFLEXNetworkRecorderUserInfoTransactionKey];
    
    if (![transaction isKindOfClass:[DYYYFLEXHTTPTransaction class]]) {
        return;
    }
    
    DYYYFLEXHTTPTransaction *httpTransaction = (DYYYFLEXHTTPTransaction *)transaction;
    [self recordNewRequest:httpTransaction];
}

- (void)handleTransactionUpdated:(NSNotification *)notification {
    DYYYFLEXNetworkTransaction *transaction = notification.userInfo[kFLEXNetworkRecorderUserInfoTransactionKey];
    
    if (![transaction isKindOfClass:[DYYYFLEXHTTPTransaction class]]) {
        return;
    }
    
    DYYYFLEXHTTPTransaction *httpTransaction = (DYYYFLEXHTTPTransaction *)transaction;
    [self updateRequestWithTransaction:httpTransaction];
}

- (void)handleTransactionsCleared:(NSNotification *)notification {
    dispatch_async(self.monitorQueue, ^{
        [self.mutableNetworkRequests removeAllObjects];
        [self.requestMap removeAllObjects];
    });
}

// MARK: - 请求记录管理

- (void)recordNewRequest:(DYYYFLEXHTTPTransaction *)transaction {
    dispatch_async(self.monitorQueue, ^{
        NSMutableDictionary *requestInfo = [NSMutableDictionary dictionary];
        requestInfo[@"requestID"] = transaction.requestID ?: @"";
        requestInfo[@"url"] = transaction.request.URL.absoluteString ?: @"";
        requestInfo[@"method"] = transaction.request.HTTPMethod ?: @"GET";
        requestInfo[@"headers"] = transaction.request.allHTTPHeaderFields ?: @{};
        requestInfo[@"timestamp"] = @(transaction.startTime.timeIntervalSince1970);
        requestInfo[@"state"] = @(transaction.state);
        requestInfo[@"requestMechanism"] = transaction.requestMechanism ?: @"";
        
        // 请求体
        NSData *bodyData = transaction.cachedRequestBody;
        if (bodyData) {
            NSString *bodyString = [[NSString alloc] initWithData:bodyData encoding:NSUTF8StringEncoding];
            requestInfo[@"body"] = bodyString ?: @"<Binary Data>";
        } else {
            requestInfo[@"body"] = @"";
        }
        
        // 存储映射
        self.requestMap[transaction.requestID] = requestInfo;
        [self.mutableNetworkRequests insertObject:requestInfo atIndex:0];
        
        // 限制记录数量
        if (self.mutableNetworkRequests.count > 1000) {
            NSDictionary *oldest = self.mutableNetworkRequests.lastObject;
            [self.requestMap removeObjectForKey:oldest[@"requestID"]];
            [self.mutableNetworkRequests removeLastObject];
        }
        
        // 发送通知（主线程）
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:FLEXDoKitNetworkRequestRecordedNotification
                                                                object:requestInfo];
        });
    });
}

- (void)updateRequestWithTransaction:(DYYYFLEXHTTPTransaction *)transaction {
    dispatch_async(self.monitorQueue, ^{
        NSMutableDictionary *requestInfo = self.requestMap[transaction.requestID];
        if (!requestInfo) {
            return;
        }
        
        // 更新状态
        requestInfo[@"state"] = @(transaction.state);
        
        // 更新响应信息
        if (transaction.response) {
            if ([transaction.response isKindOfClass:[NSHTTPURLResponse class]]) {
                NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)transaction.response;
                requestInfo[@"statusCode"] = @(httpResponse.statusCode);
                requestInfo[@"responseHeaders"] = httpResponse.allHeaderFields ?: @{};
            }
            requestInfo[@"MIMEType"] = transaction.response.MIMEType ?: @"";
        }
        
        // 更新数据长度
        requestInfo[@"receivedDataLength"] = @(transaction.receivedDataLength);
        
        // 更新延迟和时长
        if (transaction.latency > 0) {
            requestInfo[@"latency"] = @(transaction.latency);
        }
        if (transaction.duration > 0) {
            requestInfo[@"duration"] = @(transaction.duration);
        }
        
        // 错误信息
        if (transaction.error) {
            requestInfo[@"error"] = transaction.error.localizedDescription ?: @"Unknown Error";
            requestInfo[@"errorCode"] = @(transaction.error.code);
        }
        
        // 响应体（如果已完成）
        if (transaction.state == FLEXNetworkTransactionStateFinished ||
            transaction.state == FLEXNetworkTransactionStateFailed) {
            NSData *responseBody = [[DYYYFLEXNetworkRecorder defaultRecorder] cachedResponseBodyForTransaction:transaction];
            if (responseBody) {
                NSString *responseString = [[NSString alloc] initWithData:responseBody encoding:NSUTF8StringEncoding];
                requestInfo[@"responseData"] = responseString ?: @"<Binary Data>";
                requestInfo[@"responseSize"] = @(responseBody.length);
            }
        }
        
        // 发送通知（主线程）
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:FLEXDoKitNetworkResponseRecordedNotification
                                                                object:requestInfo];
        });
    });
}

// MARK: - Mock 功能

- (BOOL)isMockEnabled {
    return _mockEnabled;
}

- (void)enableMockMode {
    _mockEnabled = YES;
    NSLog(@"✅ Mock 模式已启用");
}

- (void)disableMockMode {
    _mockEnabled = NO;
    NSLog(@"❌ Mock 模式已禁用");
}

- (void)addMockRule:(NSDictionary *)rule {
    if (!rule || !rule[@"url"]) {
        return;
    }
    
    NSString *key = [self mockKeyForURL:rule[@"url"] method:rule[@"method"] ?: @"GET"];
    self.mockRules[key] = rule;
    NSLog(@"✅ Mock 规则已添加: %@", key);
}

- (void)removeMockRule:(NSDictionary *)rule {
    if (!rule || !rule[@"url"]) {
        return;
    }
    
    NSString *key = [self mockKeyForURL:rule[@"url"] method:rule[@"method"] ?: @"GET"];
    [self.mockRules removeObjectForKey:key];
    NSLog(@"🗑️ Mock 规则已移除: %@", key);
}

- (NSDictionary *)allMockRules {
    return self.mockRules.copy;
}

- (NSString *)mockKeyForURL:(NSString *)url method:(NSString *)method {
    return [NSString stringWithFormat:@"%@_%@", method.uppercaseString, url];
}

- (NSDictionary *)matchingMockRuleForRequest:(NSURLRequest *)request {
    if (!_mockEnabled || !request) {
        return nil;
    }
    
    NSString *method = request.HTTPMethod ?: @"GET";
    NSString *url = request.URL.absoluteString ?: @"";
    
    // 精确匹配
    NSString *exactKey = [self mockKeyForURL:url method:method];
    NSDictionary *rule = self.mockRules[exactKey];
    if (rule) {
        return rule;
    }
    
    // 前缀匹配
    __block NSDictionary *matchedRule = nil;
    [self.mockRules enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary *rule, BOOL *stop) {
        NSString *ruleURL = rule[@"url"];
        if (ruleURL && [url hasPrefix:ruleURL]) {
            matchedRule = rule;
            *stop = YES;
        }
    }];
    
    return matchedRule;
}

// MARK: - 弱网模拟

- (void)simulateSlowNetwork:(NSTimeInterval)delay {
    _networkDelay = delay;
    NSLog(@"⏱️ 网络延迟设置为: %.1f 秒", delay);
}

- (void)simulateNetworkError {
    _simulateError = YES;
    NSLog(@"💥 网络错误模拟已启用");
}

- (void)resetNetworkSimulation {
    _networkDelay = 0;
    _simulateError = NO;
    _mockEnabled = NO;
    NSLog(@"🔄 网络模拟已重置");
}

// MARK: - NSURLSession Hook (用于 Mock 和弱网模拟)

- (void)hookNSURLSessionMethods {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class sessionClass = [NSURLSession class];
        
        // Hook dataTaskWithRequest:completionHandler:
        [self hookSelector:@selector(dataTaskWithRequest:completionHandler:)
                   onClass:sessionClass
              withBlock:^id(NSURLSession *session, NSURLRequest *request, void (^completionHandler)(NSData *, NSURLResponse *, NSError *)) {
            return [self hooked_dataTaskWithRequest:request
                                              session:session
                                  completionHandler:completionHandler];
        }];
        
        // Hook dataTaskWithURL:completionHandler:
        [self hookSelector:@selector(dataTaskWithURL:completionHandler:)
                   onClass:sessionClass
              withBlock:^id(NSURLSession *session, NSURL *url, void (^completionHandler)(NSData *, NSURLResponse *, NSError *)) {
            NSURLRequest *request = [NSURLRequest requestWithURL:url];
            return [self hooked_dataTaskWithRequest:request
                                              session:session
                                  completionHandler:completionHandler];
        }];
        
        // Hook uploadTaskWithRequest:fromData:completionHandler:
        [self hookSelector:@selector(uploadTaskWithRequest:fromData:completionHandler:)
                   onClass:sessionClass
              withBlock:^id(NSURLSession *session, NSURLRequest *request, NSData *bodyData, void (^completionHandler)(NSData *, NSURLResponse *, NSError *)) {
            return [self hooked_uploadTaskWithRequest:request
                                                 fromData:bodyData
                                                  session:session
                                        completionHandler:completionHandler];
        }];
    });
}

- (void)hookSelector:(SEL)originalSelector onClass:(Class)targetClass withBlock:(id)replacementBlock {
    SEL swizzledSelector = NSSelectorFromString([NSString stringWithFormat:@"flexdokit_%@", NSStringFromSelector(originalSelector)]);
    
    Method originalMethod = class_getInstanceMethod(targetClass, originalSelector);
    if (!originalMethod) {
        NSLog(@"⚠️ 无法找到方法 %@ on %@", NSStringFromSelector(originalSelector), targetClass);
        return;
    }
    
    IMP newIMP = imp_implementationWithBlock(replacementBlock);
    
    BOOL didAddMethod = class_addMethod(targetClass,
                                        swizzledSelector,
                                        newIMP,
                                        method_getTypeEncoding(originalMethod));
    
    if (didAddMethod) {
        Method swizzledMethod = class_getInstanceMethod(targetClass, swizzledSelector);
        method_exchangeImplementations(originalMethod, swizzledMethod);
    } else {
        class_replaceMethod(targetClass,
                           originalSelector,
                           newIMP,
                           method_getTypeEncoding(originalMethod));
    }
}

- (NSURLSessionDataTask *)hooked_dataTaskWithRequest:(NSURLRequest *)request
                                             session:(NSURLSession *)session
                                   completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler {
    // 检查 Mock 规则
    NSDictionary *mockRule = [self matchingMockRuleForRequest:request];
    if (mockRule) {
        [self handleMockResponse:mockRule
                     forRequest:request
              completionHandler:completionHandler];
        // 返回一个占位 task
        NSURLSessionDataTask *dummyTask = [session dataTaskWithRequest:request];
        return dummyTask;
    }
    
    // 应用弱网模拟
    void (^wrappedHandler)(NSData *, NSURLResponse *, NSError *) = ^(NSData *data, NSURLResponse *response, NSError *error) {
        [self applyNetworkSimulationWithData:data
                                     response:response
                                        error:error
                           completionHandler:completionHandler];
    };
    
    // 调用原始方法
    SEL originalSelector = @selector(dataTaskWithRequest:completionHandler:);
    SEL swizzledSelector = NSSelectorFromString(@"flexdokit_dataTaskWithRequest:completionHandler:");
    
    NSURLSessionDataTask * (*originalIMP)(id, SEL, NSURLRequest *, void (^)(NSData *, NSURLResponse *, NSError *)) = 
        (void *)class_getMethodImplementation([session class], swizzledSelector);
    
    if (originalIMP) {
        return originalIMP(session, swizzledSelector, request, wrappedHandler);
    }
    
    return nil;
}

- (NSURLSessionUploadTask *)hooked_uploadTaskWithRequest:(NSURLRequest *)request
                                                fromData:(NSData *)bodyData
                                                 session:(NSURLSession *)session
                                       completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler {
    // 检查 Mock 规则
    NSDictionary *mockRule = [self matchingMockRuleForRequest:request];
    if (mockRule) {
        [self handleMockResponse:mockRule
                     forRequest:request
              completionHandler:completionHandler];
        NSURLSessionUploadTask *dummyTask = [session uploadTaskWithRequest:request fromData:bodyData];
        return dummyTask;
    }
    
    // 应用弱网模拟
    void (^wrappedHandler)(NSData *, NSURLResponse *, NSError *) = ^(NSData *data, NSURLResponse *response, NSError *error) {
        [self applyNetworkSimulationWithData:data
                                     response:response
                                        error:error
                           completionHandler:completionHandler];
    };
    
    // 调用原始方法
    SEL originalSelector = @selector(uploadTaskWithRequest:fromData:completionHandler:);
    SEL swizzledSelector = NSSelectorFromString(@"flexdokit_uploadTaskWithRequest:fromData:completionHandler:");
    
    NSURLSessionUploadTask * (*originalIMP)(id, SEL, NSURLRequest *, NSData *, void (^)(NSData *, NSURLResponse *, NSError *)) = 
        (void *)class_getMethodImplementation([session class], swizzledSelector);
    
    if (originalIMP) {
        return originalIMP(session, swizzledSelector, request, bodyData, wrappedHandler);
    }
    
    return nil;
}

- (void)handleMockResponse:(NSDictionary *)mockRule
                forRequest:(NSURLRequest *)request
         completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler {
    if (!completionHandler) {
        return;
    }
    
    // 构造 Mock 响应
    NSString *responseString = mockRule[@"responseData"] ?: @"{}";
    NSData *responseData = [responseString dataUsingEncoding:NSUTF8StringEncoding];
    
    NSInteger statusCode = [mockRule[@"statusCode"] integerValue] ?: 200;
    NSDictionary *headers = mockRule[@"headers"] ?: @{};
    
    NSHTTPURLResponse *mockResponse = [[NSHTTPURLResponse alloc]
        initWithURL:request.URL
        statusCode:statusCode
        HTTPVersion:@"HTTP/1.1"
        headerFields:headers];
    
    NSTimeInterval delay = [mockRule[@"delay"] doubleValue] ?: 0.1;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        if (completionHandler) {
            completionHandler(responseData, mockResponse, nil);
        }
    });
}

- (void)applyNetworkSimulationWithData:(NSData *)data
                              response:(NSURLResponse *)response
                                 error:(NSError *)error
                     completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler {
    if (!completionHandler) {
        return;
    }
    
    NSData *finalData = data;
    NSURLResponse *finalResponse = response;
    NSError *finalError = error;
    
    // 模拟网络错误
    if (_simulateError && !error) {
        finalError = [NSError errorWithDomain:@"FLEXDoKitNetworkError"
                                          code:500
                                      userInfo:@{NSLocalizedDescriptionKey: @"模拟网络错误"}];
        finalData = nil;
        finalResponse = nil;
    }
    
    // 模拟网络延迟
    if (_networkDelay > 0) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_networkDelay * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            completionHandler(finalData, finalResponse, finalError);
        });
    } else {
        completionHandler(finalData, finalResponse, finalError);
    }
}

// MARK: - 生命周期

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
