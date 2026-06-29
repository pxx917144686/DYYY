#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^CDDumpProgressBlock)(CGFloat progress, NSString *text);
typedef void (^CDDumpCompletionBlock)(NSURL *_Nullable zipURL, NSError *_Nullable error);

@interface CDHeaderDumper : NSObject

/// 批量导出所有类头文件为 ZIP
+ (void)dumpHeadersZipWithProgress:(CDDumpProgressBlock)progress
                        completion:(CDDumpCompletionBlock)completion;

/// 获取指定类的头文件内容
/// @param className 类名
/// @return 头文件字符串，如果类不存在则返回 nil
+ (nullable NSString *)headerForClassName:(NSString *)className;

/// 获取指定类名的 Class 对象
/// @param className 类名
/// @return Class 对象，如果不存在则返回 nil
+ (nullable Class)classForName:(NSString *)className;

/// 获取所有可导出的类名列表（按 Image 分组）
/// @return 数组，每个元素是 NSDictionary，包含 imageName、imagePath、classes(NSArray<NSString *>)
+ (NSArray<NSDictionary *> *)allClassNamesByImage;

/// 获取所有可导出的类名（扁平列表）
+ (NSArray<NSString *> *)allClassNames;

/// 搜索类名
/// @param keyword 搜索关键词
/// @return 匹配的类名列表
+ (NSArray<NSString *> *)searchClassNames:(NSString *)keyword;

@end

NS_ASSUME_NONNULL_END
