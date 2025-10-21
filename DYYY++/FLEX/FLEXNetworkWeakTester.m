//
//  FLEXNetworkWeakTester.m
//  FLEX
//
//  Copyright © 2023 FLEX Team. All rights reserved.
//

#import "FLEXNetworkWeakTester.h"
#import <objc/runtime.h>

@interface NSURLSessionConfiguration (FLEXNetworkWeak)
@property (nonatomic, assign) FLEXNetworkWeakType flex_weakType;
@end

@implementation NSURLSessionConfiguration (FLEXNetworkWeak)

- (void)setFlex_weakType:(FLEXNetworkWeakType)flex_weakType {
    objc_setAssociatedObject(self, @selector(flex_weakType), @(flex_weakType), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (FLEXNetworkWeakType)flex_weakType {
    return [objc_getAssociatedObject(self, @selector(flex_weakType)) integerValue];
}

@end

@interface FLEXNetworkWeakTester ()

@property (nonatomic, assign) FLEXNetworkWeakType currentWeakType;
@property (nonatomic, assign) BOOL isSwizzled;
@property (nonatomic, assign) Method originalMethod;
@property (nonatomic, assign) Method swizzledMethod;

@end

@implementation FLEXNetworkWeakTester

+ (instancetype)sharedInstance {
    static FLEXNetworkWeakTester *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[FLEXNetworkWeakTester alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _currentWeakType = FLEXNetworkWeakTypeNone;
        _isSwizzled = NO;
    }
    return self;
}

- (void)startWeakNetworkWithType:(FLEXNetworkWeakType)type {
    self.currentWeakType = type;
    
    if (!self.isSwizzled) {
        [self swizzleNetworkMethods];
        self.isSwizzled = YES;
    }
}

- (void)stopWeakNetwork {
    self.currentWeakType = FLEXNetworkWeakTypeNone;
    
    if (self.isSwizzled) {
        [self unswizzleNetworkMethods];
        self.isSwizzled = NO;
    }
}

- (void)swizzleNetworkMethods {
    // 交换 NSURLSessionConfiguration 的 defaultSessionConfiguration 方法
    Class class = [NSURLSessionConfiguration class];
    SEL originalSelector = @selector(defaultSessionConfiguration);
    SEL swizzledSelector = @selector(flex_defaultSessionConfiguration);
    
    Method originalMethod = class_getClassMethod(class, originalSelector);
    Method swizzledMethod = class_getClassMethod(class, swizzledSelector);
    
    self.originalMethod = originalMethod;
    self.swizzledMethod = swizzledMethod;
    
    method_exchangeImplementations(originalMethod, swizzledMethod);
}

- (void)unswizzleNetworkMethods {
    // 恢复原始实现
    if (self.originalMethod && self.swizzledMethod) {
        method_exchangeImplementations(self.swizzledMethod, self.originalMethod);
    }
}

+ (NSURLSessionConfiguration *)flex_defaultSessionConfiguration {
    // 调用原始的方法（交换后的）
    NSURLSessionConfiguration *config = [self flex_defaultSessionConfiguration];
    
    FLEXNetworkWeakType weakType = [FLEXNetworkWeakTester sharedInstance].currentWeakType;
    config.flex_weakType = weakType;
    
    // 根据弱网类型设置网络参数
    switch (weakType) {
        case FLEXNetworkWeakTypeSlow2G:
            config.timeoutIntervalForRequest = 20.0;
            config.timeoutIntervalForResource = 30.0;
            config.HTTPMaximumConnectionsPerHost = 1;
            break;
            
        case FLEXNetworkWeakType2G:
            config.timeoutIntervalForRequest = 10.0;
            config.timeoutIntervalForResource = 20.0;
            config.HTTPMaximumConnectionsPerHost = 2;
            break;
            
        case FLEXNetworkWeakType3G:
            config.timeoutIntervalForRequest = 6.0;
            config.timeoutIntervalForResource = 15.0;
            config.HTTPMaximumConnectionsPerHost = 4;
            break;
            
        case FLEXNetworkWeakType4G:
            config.timeoutIntervalForRequest = 4.0;
            config.timeoutIntervalForResource = 10.0;
            config.HTTPMaximumConnectionsPerHost = 6;
            break;
            
        case FLEXNetworkWeakTypeWifi:
            config.timeoutIntervalForRequest = 3.0;
            config.timeoutIntervalForResource = 8.0;
            config.HTTPMaximumConnectionsPerHost = 8;
            break;
            
        case FLEXNetworkWeakTypeDisconnect:
            // 设置一个不存在的代理服务器以模拟断网
            config.connectionProxyDictionary = @{
                @"HTTPEnable": @YES,
                @"HTTPProxy": @"127.0.0.1",
                @"HTTPPort": @"1",
            };
            break;
            
        case FLEXNetworkWeakTypeNone:
        default:
            // 保持默认设置
            break;
    }
    
    return config;
}

@end