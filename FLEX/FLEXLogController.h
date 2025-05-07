// 遇到问题联系中文翻译作者：pxx917144686

//
//  FLEXLogController.h
//  FLEX
//
//  创建者：Tanner，日期：2019年3月17日
//  版权所有 © 2020 FLEX 团队。保留所有权利。

#import <Foundation/Foundation.h>
#import "FLEXSystemLogMessage.h"

@protocol FLEXLogController <NSObject>

/// 保证在主线程回调。
+ (instancetype)withUpdateHandler:(void(^)(NSArray<FLEXSystemLogMessage *> *newMessages))newMessagesHandler;

- (BOOL)startMonitoring;

@end
