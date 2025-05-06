// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXManager+Networking.h
//  FLEX
//
//  由 Tanner 创建于 2/1/20.
//  版权所有 © 2020 FLEX Team。保留所有权利。
//

#import "FLEXManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface FLEXManager (Networking)

/// 如果此属性设置为 YES，FLEX 将在符合协议的类上 swizzle NSURLConnection*Delegate 和 NSURLSession*Delegate 方法。
/// 这使您可以从 FLEX 主菜单查看网络活动历史记录。
/// 完整的响应会临时保存在大小受限的缓存中，并且在内存压力下可能会被删减。
@property (nonatomic, getter=isNetworkDebuggingEnabled) BOOL networkDebuggingEnabled;

/// 如果从未设置，则默认为 25 MB。此处设置的值会在应用程序启动时保留。
/// 响应缓存使用 NSCache，因此在应用程序内存不足时，它可能会在达到限制之前清除。
@property (nonatomic) NSUInteger networkResponseCacheByteLimit;

/// 主机以该数组中某个排除条目结尾的请求将不会被记录（例如 google.com）。
/// 不需要通配符或子域条目（例如 google.com 将匹配 google.com 下的任何子域）。
/// 用于删除通常比较嘈杂的请求，例如您不感兴趣跟踪的分析请求。
@property (nonatomic) NSMutableArray<NSString *> *networkRequestHostDenylist;

/// 为特定内容类型设置自定义查看器。
/// @param contentType Mime 类型，如 application/json
/// @param viewControllerFutureBlock 查看器（视图控制器）创建块
/// @注意 此方法必须从主线程调用。
/// viewControllerFutureBlock 将从主线程调用，并且可能不返回 nil。
/// @注意 传递的块将被复制并在应用程序的整个生命周期内保留，您可能需要使用 __weak 引用。
- (void)setCustomViewerForContentType:(NSString *)contentType
            viewControllerFutureBlock:(FLEXCustomContentViewerFuture)viewControllerFutureBlock;

- (void)showObjectExplorer;
- (void)showClassHierarchy;
- (void)showRuntimeBrowser;

@end

NS_ASSUME_NONNULL_END
