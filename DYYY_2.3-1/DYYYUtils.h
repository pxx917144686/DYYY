#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface DYYYUtils : NSObject

/**
 * 显示 Toast 消息
 * @param message 要显示的消息内容
 */
+ (void)showToast:(NSString *)message;

/**
 * 获取当前显示的顶层视图控制器
 * @return 顶层视图控制器
 */
+ (UIViewController *)topView;

+ (NSUInteger)clearDirectoryContents:(NSString *)directoryPath;

/**
 * 应用毛玻璃效果到指定视图
 * @param view 要应用毛玻璃效果的视图
 * @param userTransparency 用户设置的透明度 (0-1)
 * @param tag 毛玻璃视图的标签
 */
+ (void)applyBlurEffectToView:(UIView *)view transparency:(float)userTransparency blurViewTag:(NSInteger)tag;


/**
 * 递归清除视图及其子视图的背景色
 * @param view 要清除背景的视图
 */
+ (void)clearBackgroundRecursivelyInView:(UIView *)view;

/**
 * 检查是否为深色模式
 * @return 是否为深色模式
 */
+ (BOOL)isDarkMode;

/**
 * 查找指定类的所有子视图
 * @param targetClass 目标类
 * @param container 容器视图
 * @return 找到的子视图数组
 */
+ (NSArray<UIView *> *)findAllSubviewsOfClass:(Class)targetClass inContainer:(UIView *)container;

/**
 * 在主线程安全延迟执行：对 owner 进行弱引用，回调时校验 owner 仍存活
 */
 + (void)dispatchAfter:(NSTimeInterval)delaySeconds owner:(id)owner block:(dispatch_block_t)block;

/**
 * 获取当前活跃的窗口
 * @return 当前活跃的UIWindow
 */
+ (UIWindow *)getActiveWindow;

/**
 * 获取缓存文件路径
 * @param filename 文件名
 * @return 缓存文件的完整路径
 */
+ (NSString *)cachePathForFilename:(NSString *)filename;

/**
 * 在禁用TabBar SwiftUI检查的情况下执行代码块
 * @param block 要执行的代码块
 */
+ (void)executeWithTabBarSwiftUICheckDisabled:(dispatch_block_t)block;

/**
 * 查找指定类的子视图
 * @param targetClass 目标类
 * @param container 容器视图
 * @return 找到的子视图
 */
+ (UIView *)findSubviewOfClass:(Class)targetClass inContainer:(UIView *)container;

/**
 * 应用颜色设置到标签
 * @param label 目标标签
 * @param colorHexString 颜色十六进制字符串
 */
+ (void)applyColorSettingsToLabel:(UILabel *)label colorHexString:(NSString *)colorHexString;

/**
 * 处理并应用IP位置到标签
 * @param label 目标标签
 * @param model 数据模型
 * @param labelColor 标签颜色
 */
+ (void)processAndApplyIPLocationToLabel:(UILabel *)label forModel:(id)model withLabelColor:(NSString *)labelColor;

/**
 * 递归应用文本颜色
 * @param color 文本颜色
 * @param view 目标视图
 * @param shouldExcludeViewBlock 排除视图的判断块
 */
+ (void)applyTextColorRecursively:(UIColor *)color inView:(UIView *)view shouldExcludeViewBlock:(BOOL(^)(UIView *))shouldExcludeViewBlock;

/**
 * 从视图中查找第一个可用的视图控制器
 * @param view 目标视图
 * @return 找到的视图控制器
 */
+ (UIViewController *)firstAvailableViewControllerFromView:(UIView *)view;

/**
 * 从颜色方案十六进制字符串创建颜色
 * @param colorHex 颜色十六进制字符串
 * @param targetWidth 目标宽度
 * @return 创建的颜色
 */
+ (UIColor *)colorFromSchemeHexString:(NSString *)colorHex targetWidth:(CGFloat)targetWidth;

/**
 * 检查容器中是否包含指定类的子视图
 * @param targetClass 目标类
 * @param container 容器视图
 * @return 是否包含
 */
+ (BOOL)containsSubviewOfClass:(Class)targetClass inContainer:(UIView *)container;

/**
 * 在视图控制器中查找指定类的视图控制器
 * @param targetClass 目标类
 * @param viewController 根视图控制器
 * @return 找到的视图控制器
 */
+ (UIViewController *)findViewControllerOfClass:(Class)targetClass inViewController:(UIViewController *)viewController;

/**
 * 格式化文件大小
 * @param size 文件大小（字节）
 * @return 格式化后的大小字符串
 */
+ (NSString *)formattedSize:(long long)size;

/**
 * 获取目录大小
 * @param path 目录路径
 * @return 目录大小（字节）
 */
+ (long long)directorySizeAtPath:(NSString *)path;

/**
 * 移除路径下的所有内容
 * @param path 目标路径
 */
+ (void)removeAllContentsAtPath:(NSString *)path;

/**
 * 是否启用液体玻璃效果
 * @return 是否启用
 */
+ (BOOL)isLiquidGlassEnabled;

@end

#ifdef __cplusplus
extern "C" {
#endif

/**
 * 清除分享URL中的查询参数
 * @param url 需要清理的URL字符串
 * @return 清理后的URL字符串
 */
NSString * _Nullable cleanShareURL(NSString * _Nullable url);

/**
 * 获取当前显示的顶层视图控制器
 * @return 顶层视图控制器
 */
UIViewController * _Nullable topView(void);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END