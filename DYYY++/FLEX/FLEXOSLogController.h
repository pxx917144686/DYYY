//
//  FLEXOSLogController.h
//  FLEX
//
//  Created by Tanner on 12/19/18.
//  Copyright © 2020 FLEX Team. All rights reserved.
//

#import "FLEXLogController.h"

#define FLEXOSLogAvailable() (NSProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 10)

/// 用于iOS 10及以上版本的日志控制器。
@interface FLEXOSLogController : NSObject <FLEXLogController>

+ (instancetype)withUpdateHandler:(void(^)(NSArray<FLEXSystemLogMessage *> *newMessages))newMessagesHandler;

- (BOOL)startMonitoring;

/// 日志消息是否需要被记录并保存在后台内存中。
/// 您无需初始化此值，只需更改它。
@property (nonatomic) BOOL persistent;
/// 主要在内部使用，但也被日志视图控制器用来保存
/// 在启用持久化之前创建的消息。
@property (nonatomic) NSMutableArray<FLEXSystemLogMessage *> *messages;

@end
