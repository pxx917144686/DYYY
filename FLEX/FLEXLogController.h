//
//  FLEXLogController.h
//  FLEX
//
//  Created by Tanner on 3/17/19.
//  Copyright © 2020 FLEX Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DYYYFLEXSystemLogMessage.h"

@protocol FLEXLogController <NSObject>

/// Guaranteed to call back on the main thread.
+ (instancetype)withUpdateHandler:(void(^)(NSArray<DYYYFLEXSystemLogMessage *> *newMessages))newMessagesHandler;

- (BOOL)startMonitoring;

@end
