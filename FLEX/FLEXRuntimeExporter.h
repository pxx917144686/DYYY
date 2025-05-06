// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXRuntimeExporter.h
//  FLEX
//
//  由 Tanner Bennett 创建于 3/26/20.
//  版权所有 (c) 2020 FLEX Team。保留所有权利。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 一个用于将所有运行时元数据导出到 SQLite 数据库的类。
//API_AVAILABLE(ios(10.0))
@interface FLEXRuntimeExporter : NSObject

+ (void)createRuntimeDatabaseAtPath:(NSString *)path
                    progressHandler:(void(^)(NSString *status))progress
                         completion:(void(^)(NSString *_Nullable error))completion;

+ (void)createRuntimeDatabaseAtPath:(NSString *)path
                          forImages:(nullable NSArray<NSString *> *)images
                    progressHandler:(void(^)(NSString *status))progress
                         completion:(void(^)(NSString *_Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
