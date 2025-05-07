// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXManager+Networking.m
//  FLEX
//
//  由 Tanner 创建于 2/1/20.
//  版权所有 © 2020 FLEX Team。保留所有权利。

#import "FLEXManager+Networking.h"
#import "FLEXManager+Private.h"
#import "FLEXNetworkObserver.h"
#import "FLEXNetworkRecorder.h"
#import "FLEXObjectExplorerFactory.h"
#import "NSUserDefaults+FLEX.h"
#import "FLEXAlert.h"
#import "FLEXGlobalsViewController.h"
#import "FLEXNavigationController.h"
#import "FLEXObjcRuntimeViewController.h"

@implementation FLEXManager (Networking)

+ (void)load {
    if (NSUserDefaults.standardUserDefaults.flex_registerDictionaryJSONViewerOnLaunch) {
        dispatch_async(dispatch_get_main_queue(), ^{
            // 为 JSON 响应注册数组/字典查看器
            [self.sharedManager setCustomViewerForContentType:@"application/json"
                viewControllerFutureBlock:^UIViewController *(NSData *data) {
                    id jsonObject = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                    if (jsonObject) {
                        return [FLEXObjectExplorerFactory explorerViewControllerForObject:jsonObject];
                    }
                    return nil;
                }
            ];
        });
    }
}

- (BOOL)isNetworkDebuggingEnabled {
    return FLEXNetworkObserver.isEnabled;
}

- (void)setNetworkDebuggingEnabled:(BOOL)networkDebuggingEnabled {
    FLEXNetworkObserver.enabled = networkDebuggingEnabled;
}

- (NSUInteger)networkResponseCacheByteLimit {
    return FLEXNetworkRecorder.defaultRecorder.responseCacheByteLimit;
}

- (void)setNetworkResponseCacheByteLimit:(NSUInteger)networkResponseCacheByteLimit {
    FLEXNetworkRecorder.defaultRecorder.responseCacheByteLimit = networkResponseCacheByteLimit;
}

- (NSMutableArray<NSString *> *)networkRequestHostDenylist {
    return FLEXNetworkRecorder.defaultRecorder.hostDenylist;
}

- (void)setNetworkRequestHostDenylist:(NSMutableArray<NSString *> *)networkRequestHostDenylist {
    FLEXNetworkRecorder.defaultRecorder.hostDenylist = networkRequestHostDenylist;
}

- (void)setCustomViewerForContentType:(NSString *)contentType
            viewControllerFutureBlock:(FLEXCustomContentViewerFuture)viewControllerFutureBlock {
    NSParameterAssert(contentType.length);
    NSParameterAssert(viewControllerFutureBlock);
    NSAssert(NSThread.isMainThread, @"此方法必须从主线程调用.");

    self.customContentTypeViewers[contentType.lowercaseString] = viewControllerFutureBlock;
}

- (void)registerCustomViewerForContentType:(NSString *)contentType
                     viewControllerFuture:(FLEXCustomContentViewerFuture)viewControllerFutureBlock {
    NSParameterAssert(contentType.length);
    NSAssert(NSThread.isMainThread, @"该方法必须在主线程调用.");

    self.customContentTypeViewers[contentType.lowercaseString] = viewControllerFutureBlock;
}

- (void)showExplorerMenu {
    [FLEXAlert makeAlert:^(FLEXAlert *make) {
        make.title(@"浏览器选项");
        make.button(@"查看所有对象").handler(^(NSArray<NSString *> *strings) {
            [self showObjectExplorer];
        });
        make.button(@"查看类层级").handler(^(NSArray<NSString *> *strings) {
            [self showClassHierarchy]; 
        });
        make.button(@"查看运行时信息").handler(^(NSArray<NSString *> *strings) {
            [self showRuntimeBrowser];
        });
        make.button(@"取消").cancelStyle();
    } showFrom:self.explorerViewController];
}

- (void)showObjectExplorer {
    // 显示对象浏览器
    UIViewController *explorer = [FLEXObjectExplorerFactory explorerViewControllerForObject:self];
    [self presentEmbeddedTool:explorer completion:nil];
}

- (void)showClassHierarchy {
    // 显示类层次结构
    UIViewController *explorer = [FLEXObjectExplorerFactory explorerViewControllerForObject:[self class]];
    [self presentEmbeddedTool:explorer completion:nil];
}

- (void)showRuntimeBrowser {
    // 显示运行时浏览器
    UIViewController *browser = [[FLEXObjcRuntimeViewController alloc] init];
    [self presentEmbeddedTool:browser completion:nil];
}

@end
