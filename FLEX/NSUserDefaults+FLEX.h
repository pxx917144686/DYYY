// 遇到问题联系中文翻译作者：pxx917144686
//
//  NSUserDefaults+FLEX.h
//  FLEX
//
//  由 Tanner 创建于 3/10/20.
//  版权所有 © 2020 FLEX Team。保留所有权利。
//

#import <Foundation/Foundation.h>

// 仅当 getter 和 setter 因某种原因不够好时才使用这些
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

/// 所有 BOOL 类型的偏好设置默认为 NO
@interface NSUserDefaults (FLEX)

- (void)flex_toggleBoolForKey:(NSString *)key;

@property (nonatomic) double flex_toolbarTopMargin; // 工具栏顶部边距
@property (nonatomic) BOOL flex_networkObserverEnabled; // 网络观察器已启用
// 实际上并未存储在 defaults 中，而是写入文件
@property (nonatomic) NSArray<NSString *> *flex_networkHostDenylist; // 网络主机黑名单
/// 是否在启动时将对象浏览器注册为 JSON 查看器
@property (nonatomic) BOOL flex_registerDictionaryJSONViewerOnLaunch; // 启动时注册JSON查看器
/// 网络观察器中最后选择的屏幕
@property (nonatomic) NSInteger flex_lastNetworkObserverMode; // 上次网络观察器模式
/// 禁用 os_log 并重新启用 ASL。可能会中断 Console.app 的输出。
@property (nonatomic) BOOL flex_disableOSLog; // 禁用系统日志 (os_log)
@property (nonatomic) BOOL flex_cacheOSLogMessages; // 缓存系统日志 (OSLog) 消息
@property (nonatomic) BOOL flex_enableAPNSCapture; // 启用APNS捕获
@property (nonatomic) BOOL flex_explorerHidesPropertyIvars; // 对象浏览器隐藏属性的成员变量
@property (nonatomic) BOOL flex_explorerHidesPropertyMethods; // 对象浏览器隐藏属性方法
@property (nonatomic) BOOL flex_explorerHidesPrivateMethods; // 对象浏览器隐藏私有方法
@property (nonatomic) BOOL flex_explorerShowsMethodOverrides; // 对象浏览器显示方法覆盖
@property (nonatomic) BOOL flex_explorerHidesVariablePreviews; // 对象浏览器隐藏变量预览

@end
