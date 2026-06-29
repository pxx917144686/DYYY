#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^UCClassDumpToolProgressBlock)(CGFloat progress, NSString *text);
typedef void (^UCClassDumpToolCompletionBlock)(NSURL * _Nullable zipURL, NSError * _Nullable error);

@interface UCClassDumpTool : NSObject

/// 批量导出所有类头文件为 ZIP
+ (void)dumpHeadersZipWithProgress:(UCClassDumpToolProgressBlock)progress
                        completion:(UCClassDumpToolCompletionBlock)completion;

/// 获取指定类的头文件内容
/// @param className 类名
/// @return 头文件字符串，如果类不存在则返回 nil
+ (nullable NSString *)headerForClassName:(NSString *)className;

/// 获取所有可导出的类名（扁平列表，已排序）
+ (NSArray<NSString *> *)allClassNames;

/// 搜索类名
/// @param keyword 搜索关键词
/// @return 匹配的类名列表
+ (NSArray<NSString *> *)searchClassNames:(NSString *)keyword;

/// 获取所有类名（按 Image 分组）
+ (NSArray<NSDictionary *> *)classNamesByImage;

@end

NS_ASSUME_NONNULL_END
