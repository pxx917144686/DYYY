// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXOSLogController.h
//  FLEX
//
//  由 Tanner 创建于 12/19/18.
//  版权所有 © 2020 FLEX Team。保留所有权利。
//

#import "FLEXLogController.h"

#define FLEXOSLogAvailable() (NSProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 10)

/// 用于 iOS 10 及更高版本的日志控制器。
@interface FLEXOSLogController : NSObject <FLEXLogController>

+ (instancetype)withUpdateHandler:(void(^)(NSArray<FLEXSystemLogMessage *> *newMessages))newMessagesHandler;

- (BOOL)startMonitoring;

/// 日志消息是否要在后台记录并保存在内存中。
/// 您不需要初始化此值，只需更改它即可。
@property (nonatomic) BOOL persistent;
/// 主要在内部使用，但也由日志 VC 用于持久化
/// 在启用持久化之前创建的消息。
@property (nonatomic) NSMutableArray<FLEXSystemLogMessage *> *messages;

@end
