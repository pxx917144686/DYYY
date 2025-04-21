#import <UIKit/UIKit.h>
#import "AwemeHeaders.h"

@interface AWEUIThemeManager : NSObject
@property (nonatomic, assign) BOOL isLightTheme;
@end

@interface DYYYManager : NSObject
//存储文件类行
@property (nonatomic, strong, readonly) NSMutableDictionary<NSString *, NSDictionary *> *fileLinks; 
+ (instancetype)shared;

+ (UIWindow *)getActiveWindow;
+ (UIViewController *)getActiveTopController;
+ (UIColor *)colorWithHexString:(NSString *)hexString;
+ (void)showToast:(NSString *)text;

// 简单的保存方法 - 无错误回调
+ (void)saveMedia:(NSURL *)mediaURL mediaType:(MediaType)mediaType completion:(void (^)(void))completion;

// 新增带错误处理的保存方法
+ (void)saveMedia:(NSURL *)mediaURL mediaType:(MediaType)mediaType withErrorHandling:(void (^)(BOOL success, NSError *error))completion;

// 媒体描述与类型处理
+ (NSString *)getMediaTypeDescription:(MediaType)mediaType;

// 检查照片库权限
+ (void)checkPhotoLibraryPermission:(void (^)(BOOL granted))completion;
// 检查媒体文件是否有效
+ (BOOL)isValidMediaFile:(NSURL *)fileURL;

// 保存不同类型媒体的方法
+ (void)saveImageToPhotoLibrary:(NSURL *)imageURL mediaType:(MediaType)mediaType completion:(void (^)(BOOL success, NSError *error))completion;
+ (void)saveVideoToPhotoLibrary:(NSURL *)videoURL completion:(void (^)(BOOL success, NSError *error))completion;

// 新增带进度的下载方法
+ (void)downloadLivePhoto:(NSURL *)imageURL videoURL:(NSURL *)videoURL completion:(void (^)(void))completion;
+ (void)downloadAllLivePhotos:(NSArray<NSDictionary *> *)livePhotos;
+ (void)downloadAllLivePhotosWithProgress:(NSArray<NSDictionary *> *)livePhotos progress:(void (^)(NSInteger current, NSInteger total))progressBlock completion:(void (^)(NSInteger successCount, NSInteger totalCount))completion;
+ (void)downloadMedia:(NSURL *)url mediaType:(MediaType)mediaType completion:(void (^)(void))completion;
+ (void)downloadMediaWithProgress:(NSURL *)url mediaType:(MediaType)mediaType progress:(void (^)(float progress))progressBlock completion:(void (^)(BOOL success, NSURL *fileURL))completion;
+ (void)cancelAllDownloads;

// 并发下载多个图片
+ (void)downloadAllImages:(NSMutableArray *)imageURLs;
+ (void)downloadAllImagesWithProgress:(NSMutableArray *)imageURLs progress:(void (^)(NSInteger current, NSInteger total))progressBlock completion:(void (^)(NSInteger successCount, NSInteger totalCount))completion;
// 重新实现的LivePhoto保存方法，添加错误处理
- (void)saveLivePhoto:(NSString *)imageSourcePath videoUrl:(NSString *)videoSourcePath completion:(void (^)(BOOL success, NSError *error))completion;
//获取主题状态
+ (BOOL)isDarkMode;

// 为抖音视频添加专用下载方法
+ (void)downloadAwemeVideo:(AWEAwemeModel *)awemeModel completion:(void (^)(BOOL success, NSURL *fileURL, NSError *error))completion;

// 安全获取下载URL的方法
+ (NSURL *)getSafeDownloadURLFromVideoModel:(AWEVideoModel *)videoModel;
+ (NSURL *)getSafeDownloadURLFromURLModel:(URLModel *)urlModel;
+ (NSURL *)getSafeDownloadURLFromAWEURLModel:(AWEURLModel *)urlModel;

// 长按视频下载处理
+ (void)handleLongPressVideoDownload:(AWEAwemeModel *)awemeModel fromViewController:(UIViewController *)viewController;

// 错误处理和状态报告
+ (NSError *)createErrorWithCode:(NSInteger)code message:(NSString *)message;
+ (void)logDownloadStatus:(NSString *)message forAwemeModel:(AWEAwemeModel *)model;

// 检查视频下载权限和条件
+ (BOOL)canDownloadVideo:(AWEAwemeModel *)awemeModel;

// 新增转换和保存GIF的方法
+ (void)convertHeicToGif:(NSURL *)heicURL completion:(void (^)(NSURL *gifURL, BOOL success))completion;
+ (void)convertWebpToGifNative:(NSURL *)webpURL completion:(void (^)(NSURL *gifURL, BOOL success))completion;
+ (void)saveGifToPhotoLibrary:(NSURL *)gifURL mediaType:(MediaType)mediaType completion:(void (^)(void))completion;

// 新增方法
+ (NSArray<NSString *> *)detectQRCodesInImage:(UIImage *)image;
+ (BOOL)aiDetectImageUnsafe:(UIImage *)image;
+ (BOOL)aiDetectVideoUnsafe:(NSURL *)videoURL;
+ (NSData *)smartCompressImage:(UIImage *)image maxSizeKB:(NSInteger)maxKB;
+ (void)saveImagesSerially:(NSArray<NSURL *> *)imageURLs mediaTypes:(NSArray<NSNumber *> *)mediaTypes completion:(void (^)(NSInteger successCount, NSInteger totalCount))completion;
+ (NSDictionary *)extractEXIFMetadata:(NSURL *)fileURL;

// 添加缺失的接口下载方法
+ (void)parseAndDownloadVideoWithShareLink:(NSString *)shareLink apiKey:(NSString *)apiKey;
// 批量资源下载方法
+ (void)batchDownloadResources:(NSArray *)videos images:(NSArray *)images;
@end