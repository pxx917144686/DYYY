// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXNetworkObserver.h
//  派生自：
//
//  PDAFNetworkDomainController.h
//  PonyDebugger
//
//  由 Mike Lewis 创建于 2/27/12.
//
//  根据一项或多项贡献者许可协议授权给 Square, Inc.。
//  有关 Square, Inc. 授权给您的条款，请参阅随此作品分发的 LICENSE 文件。
//

#import <Foundation/Foundation.h>

FOUNDATION_EXTERN NSString *const kFLEXNetworkObserverEnabledStateChangedNotification;

/// 此类通过 swizzle NSURLConnection 和 NSURLSession 委托方法来观察 URL 加载系统中的事件。
/// 高级网络事件将发送到默认的 FLEXNetworkRecorder 实例，该实例维护请求历史记录并缓存响应主体。
@interface FLEXNetworkObserver : NSObject

/// 首次启用观察器时会发生 Swizzling。
/// 如果不需要网络调试，这可以减少 FLEX 的影响。
/// 注意：此设置在应用程序启动之间保持不变。
@property (nonatomic, class, getter=isEnabled) BOOL enabled;

@end
