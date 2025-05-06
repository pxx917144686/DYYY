//
//  FLEXASLLogController.h
//  FLEX
//
//  创建者：Tanner，日期：3/14/19.
//  版权所有 © 2020 FLEX Team。保留所有权利。
//

// 遇到问题联系中文翻译作者：pxx917144686

#import "FLEXLogController.h"

@interface FLEXASLLogController : NSObject <FLEXLogController>

/// 保证在主线程上回调。
+ (instancetype)withUpdateHandler:(void(^)(NSArray<FLEXSystemLogMessage *> *newMessages))newMessagesHandler;

- (BOOL)startMonitoring;

@end
