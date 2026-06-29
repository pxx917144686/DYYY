//
//  NSUserDefaults+FLEX.h
//  FLEX
//
//  Created by Tanner on 3/10/20.
//  Copyright © 2020 FLEX Team. All rights reserved.
//

#import <Foundation/Foundation.h>

// 只有在 getter 和 setter 方法不够用的情况下才使用这些常量
extern NSString * const kFLEXDefaultsToolbarTopMarginKey;
extern NSString * const kFLEXDefaultsiOSPersistentOSLogKey;
extern NSString * const kFLEXDefaultsHidePropertyIvarsKey;
extern NSString * const kFLEXDefaultsHidePropertyMethodsKey;
extern NSString * const kFLEXDefaultsHidePrivateMethodsKey;
extern NSString * const kFLEXDefaultsShowMethodOverridesKey;
extern NSString * const kFLEXDefaultsHideVariablePreviewsKey;
extern NSString * const kFLEXDefaultsNetworkObserverEnabledKey;
extern NSString * const kFLEXDefaultsNetworkHostDenylistKey;
extern NSString * const kFLEXDefaultsDisableOSLogForceASLKey;
extern NSString * const kFLEXDefaultsAPNSCaptureEnabledKey;
extern NSString * const kFLEXDefaultsRegisterJSONExplorerKey;

/// 所有布尔值偏好设置默认为 NO
@interface NSUserDefaults (FLEX)

- (void)flex_toggleBoolForKey:(NSString *)key;

@property (nonatomic) double flex_toolbarTopMargin;

@property (nonatomic) BOOL flex_networkObserverEnabled;
// 实际上不存储在默认设置中，而是写入文件
@property (nonatomic) NSArray<NSString *> *flex_networkHostDenylist;

/// 是否在启动时将对象浏览器注册为 JSON 查看器
@property (nonatomic) BOOL flex_registerDictionaryJSONViewerOnLaunch;

/// 网络观察器中最后选择的屏幕
@property (nonatomic) NSInteger flex_lastNetworkObserverMode;

/// 禁用 os_log 并重新启用 ASL。可能会破坏 Console.app 输出。
@property (nonatomic) BOOL flex_disableOSLog;
@property (nonatomic) BOOL flex_cacheOSLogMessages;

@property (nonatomic) BOOL flex_enableAPNSCapture;

@property (nonatomic) BOOL flex_explorerHidesPropertyIvars;
@property (nonatomic) BOOL flex_explorerHidesPropertyMethods;
@property (nonatomic) BOOL flex_explorerHidesPrivateMethods;
@property (nonatomic) BOOL flex_explorerShowsMethodOverrides;
@property (nonatomic) BOOL flex_explorerHidesVariablePreviews;

@end
