// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXManager+Private.h
//  PebbleApp
//
//  由 Javier Soto 创建于 7/26/14.
//  版权所有 (c) 2020 FLEX Team。保留所有权利。
//

#import "FLEXManager.h"
#import "FLEXWindow.h"

@class FLEXGlobalsEntry, FLEXExplorerViewController;

@interface FLEXManager (Private)

@property (nonatomic, readonly) FLEXWindow *explorerWindow;
@property (nonatomic, readonly) FLEXExplorerViewController *explorerViewController;

/// 用户已注册的 FLEXGlobalsEntry 对象数组。
@property (nonatomic, readonly) NSMutableArray<FLEXGlobalsEntry *> *userGlobalEntries;
@property (nonatomic, readonly) NSMutableDictionary<NSString *, FLEXCustomContentViewerFuture> *customContentTypeViewers;

@end
