#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class YYAnimatedImageView;

@interface DYYYUtils : NSObject

#pragma mark - Advertisement Filtering Utilities (广告过滤工具)

/** 使用抖音模型自身的广告判定及明确广告字段识别广告作品。 */
+ (BOOL)isAdvertisementAwemeModel:(id)model;

/** 识别作品模型或搜索结果包装模型中的广告。 */
+ (BOOL)isAdvertisementContainerModel:(id)model;

/** 从列表中移除广告模型；未启用屏蔽广告时原样返回。 */
+ (NSArray *)arrayByRemovingAdvertisements:(id)array;

/** 在作品模型字段尚未完成映射时，从原始响应中识别明确广告标记。 */
+ (BOOL)isAdvertisementRawData:(id)rawData;

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

/**
 * 从指定视图沿 responder 链查找最近的 UIViewController
 * @param view 起始视图
 * @return 找到的视图控制器，未找到返回 nil
 */
+ (UIViewController *)findViewControllerFromView:(UIView *)view;

/**
 * 在视图控制器层级中查找指定类的控制器
 * @param targetClass 目标类
 * @param vc 起始视图控制器
 * @return 找到的视图控制器，未找到返回 nil
 */
+ (UIViewController *)findViewControllerOfClass:(Class)targetClass inViewController:(UIViewController *)vc;

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

#pragma mark - Animated Sticker / GIF Utilities (动图表情/GIF工具)

/**
 * 判断图片是否为带 heif/heic URL 的 BDImage
 */
+ (BOOL)isBDImageWithHeifURL:(UIImage *)image;

/**
 * 从 YYAnimatedImageView 提取帧数组
 */
+ (NSArray *)getImagesFromYYAnimatedImageView:(YYAnimatedImageView *)imageView;

/**
 * 获取 YYAnimatedImageView 动图总时长
 */
+ (CGFloat)getDurationFromYYAnimatedImageView:(YYAnimatedImageView *)imageView;

/**
 * 使用 YYImage 解码动图数据，返回帧图像和总时长
 */
+ (BOOL)framesFromAnimatedData:(NSData *)data
                         scale:(CGFloat)scale
                        images:(NSArray<UIImage *> *_Nullable *)images
                 totalDuration:(CGFloat *_Nullable)totalDuration;

/**
 * 根据帧数组生成 GIF 文件
 */
+ (BOOL)createGIFWithImages:(NSArray *)images duration:(CGFloat)duration path:(NSString *)path progress:(void (^)(float progress))progressBlock;

/**
 * 保存 GIF 到相册并清理临时文件
 */
+ (void)saveGIFToPhotoLibrary:(NSString *)path completion:(void (^)(BOOL success, NSError *error))completion;

/**
 * 保存 GIF(URL) 到相册并删除源文件
 */
+ (void)saveGifToPhotoLibrary:(NSURL *)gifURL completion:(void (^)(BOOL success))completion;

/**
 * 将 HEIC/HEIF 动图转换为 GIF
 */
+ (void)convertHeicToGif:(NSURL *)heicURL completion:(void (^)(NSURL *gifURL, BOOL success))completion;

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

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END