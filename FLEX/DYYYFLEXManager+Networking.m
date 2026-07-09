//
//  DYYYFLEXManager+Networking.m
//  FLEX
//
//  Created by Tanner on 2/1/20.
//  Copyright © 2020 FLEX Team. All rights reserved.
//

#import "DYYYFLEXManager+Networking.h"
#import "DYYYFLEXManager+Private.h"
#import "DYYYFLEXNetworkObserver.h"
#import "DYYYFLEXNetworkRecorder.h"
#import "DYYYFLEXObjectExplorerFactory.h"
#import "NSUserDefaults+FLEX.h"

@implementation DYYYFLEXManager (Networking)

+ (void)load {
    if (NSUserDefaults.standardUserDefaults.flex_registerDictionaryJSONViewerOnLaunch) {
        dispatch_async(dispatch_get_main_queue(), ^{
            // Register array/dictionary viewer for JSON responses
            [self.sharedManager setCustomViewerForContentType:@"application/json"
                viewControllerFutureBlock:^UIViewController *(NSData *data) {
                    id jsonObject = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                    if (jsonObject) {
                        return [DYYYFLEXObjectExplorerFactory explorerViewControllerForObject:jsonObject];
                    }
                    return nil;
                }
            ];
        });
    }
}

- (BOOL)isNetworkDebuggingEnabled {
    return DYYYFLEXNetworkObserver.isEnabled;
}

- (void)setNetworkDebuggingEnabled:(BOOL)networkDebuggingEnabled {
    DYYYFLEXNetworkObserver.enabled = networkDebuggingEnabled;
}

- (NSUInteger)networkResponseCacheByteLimit {
    return DYYYFLEXNetworkRecorder.defaultRecorder.responseCacheByteLimit;
}

- (void)setNetworkResponseCacheByteLimit:(NSUInteger)networkResponseCacheByteLimit {
    DYYYFLEXNetworkRecorder.defaultRecorder.responseCacheByteLimit = networkResponseCacheByteLimit;
}

- (NSMutableArray<NSString *> *)networkRequestHostDenylist {
    return DYYYFLEXNetworkRecorder.defaultRecorder.hostDenylist;
}

- (void)setNetworkRequestHostDenylist:(NSMutableArray<NSString *> *)networkRequestHostDenylist {
    DYYYFLEXNetworkRecorder.defaultRecorder.hostDenylist = networkRequestHostDenylist;
}

- (void)setCustomViewerForContentType:(NSString *)contentType
            viewControllerFutureBlock:(FLEXCustomContentViewerFuture)viewControllerFutureBlock {
    NSParameterAssert(contentType.length);
    NSParameterAssert(viewControllerFutureBlock);
    NSAssert(NSThread.isMainThread, @"此方法必须从主线程调用.");

    self.customContentTypeViewers[contentType.lowercaseString] = viewControllerFutureBlock;
}

@end
