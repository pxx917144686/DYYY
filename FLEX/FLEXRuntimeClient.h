//
//  FLEXRuntimeClient.h
//  FLEX
//
//  由 Tanner 创建于 3/22/17.
//  版权所有 © 2017 Tanner Bennett. 保留所有权利。
//

#import "FLEXSearchToken.h"
@class FLEXMethod;

/// 接受给定令牌的运行时查询。
@interface FLEXRuntimeClient : NSObject

@property (nonatomic, readonly, class) FLEXRuntimeClient *runtime;

/// 当首次使用 \c FLEXRuntime 时自动调用。
/// 当您认为自该方法首次调用以来已加载库时，
/// 您可以再次调用它。
- (void)reloadLibrariesList;

/// 在尝试调用 \c copySafeClassList 之前，
/// 您必须在主线程上调用此方法。
+ (void)initializeWebKitLegacy;

/// 除非您绝对需要所有类，否则不要调用。这将导致
/// 运行时中的每个类初始化自己，这并不常见。
/// 在调用此方法之前，请在主线程上调用 \c initializeWebKitLegacy。
- (NSArray<Class> *)copySafeClassList;

- (NSArray<Protocol *> *)copyProtocolList;

/// 表示当前加载的库的字符串数组。
@property (nonatomic, readonly) NSArray<NSString *> *imageDisplayNames;

/// "镜像名称"是包的路径
- (NSString *)shortNameForImageName:(NSString *)imageName;
/// "镜像名称"是包的路径
- (NSString *)imageNameForShortName:(NSString *)imageName;

/// @return 用于UI的包名称
- (NSMutableArray<NSString *> *)bundleNamesForToken:(FLEXSearchToken *)token;
/// @return 用于更多查询的包路径
- (NSMutableArray<NSString *> *)bundlePathsForToken:(FLEXSearchToken *)token;
/// @return 类名
- (NSMutableArray<NSString *> *)classesForToken:(FLEXSearchToken *)token
                                      inBundles:(NSMutableArray<NSString *> *)bundlePaths;
/// @return \c FLEXMethods 的列表列表，其中
/// 每个列表对应于给定类之一
- (NSArray<NSMutableArray<FLEXMethod *> *> *)methodsForToken:(FLEXSearchToken *)token
                                                    instance:(NSNumber *)onlyInstanceMethods
                                                   inClasses:(NSArray<NSString *> *)classes;

@end
