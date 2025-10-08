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