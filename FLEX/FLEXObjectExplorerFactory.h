// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXObjectExplorerFactory.h
//  Flipboard
//
//  由 Ryan Olson 创建于 5/15/14.
//  版权所有 (c) 2020 FLEX Team。保留所有权利。
//

#import "FLEXGlobalsEntry.h"

#ifndef _FLEXObjectExplorerViewController_h
#import "FLEXObjectExplorerViewController.h"
#else
@class FLEXObjectExplorerViewController;
#endif

NS_ASSUME_NONNULL_BEGIN

@interface FLEXObjectExplorerFactory : NSObject <FLEXGlobalsEntry>

+ (nullable FLEXObjectExplorerViewController *)explorerViewControllerForObject:(nullable id)object;

/// 注册一个特定的浏览器视图控制器类，用于浏览
/// 特定类的对象。调用将覆盖现有的注册。
/// 各个部分必须使用类似 \c forObject: 的方式进行初始化
+ (void)registerExplorerSection:(Class)sectionClass forClass:(Class)objectClass;

@end

NS_ASSUME_NONNULL_END
