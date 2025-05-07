// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXManager.h
//  Flipboard
//
//  由 Ryan Olson 创建于 4/4/14.
//  版权所有 (c) 2020 FLEX Team。保留所有权利。
//

#import "FLEXExplorerToolbar.h"

NS_ASSUME_NONNULL_BEGIN

@interface FLEXManager : NSObject

@property (nonatomic, readonly, class) FLEXManager *sharedManager;

@property (nonatomic, readonly) BOOL isHidden;
@property (nonatomic, readonly) FLEXExplorerToolbar *toolbar;

- (void)showExplorer;
- (void)hideExplorer;
- (void)toggleExplorer;

/// 以编程方式关闭 FLEX 显示的任何工具，仅保留工具栏可见。
- (void)dismissAnyPresentedTools:(void (^_Nullable)(void))completion;

/// 以编程方式在 FLEX 工具栏顶部显示某些内容。
/// 此方法将自动关闭任何当前显示的工具，
/// 因此您无需自己调用 \c dismissAnyPresentedTools:。
- (void)presentTool:(UINavigationController *(^)(void))viewControllerFuture
         completion:(void (^_Nullable)(void))completion;

/// 以编程方式使用给定的视图控制器显示一个新的导航控制器。
/// 完成块将传递此新的导航控制器。
- (void)presentEmbeddedTool:(UIViewController *)viewController
                 completion:(void (^_Nullable)(UINavigationController *))completion;

/// 以编程方式显示一个新的导航控制器，用于浏览给定的对象。
/// 完成块将传递此新的导航控制器。
- (void)presentObjectExplorer:(id)object completion:(void (^_Nullable)(UINavigationController *))completion;

/// 当默认选择的场景不是您希望显示浏览器的场景时，使用此选项在特定场景中显示浏览器。
- (void)showExplorerFromScene:(UIWindowScene *)scene API_AVAILABLE(ios(13.0));

#pragma mark - 其他

/// 默认数据库密码默认为 \c nil。
/// 将此设置为您希望数据库打开时使用的密码。
@property (copy, nonatomic) NSString *defaultSqliteDatabasePassword;

@end


typedef UIViewController * _Nullable(^FLEXCustomContentViewerFuture)(NSData *data);

NS_ASSUME_NONNULL_END
