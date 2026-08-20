#import "DYYYManagerPrivate.h"
#import <CoreAudioTypes/CoreAudioTypes.h>
#import <CoreMedia/CMMetadata.h>
#import <ImageIO/ImageIO.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <MobileCoreServices/UTCoreTypes.h>
#import <Photos/Photos.h>
#import <objc/message.h>
#import <objc/runtime.h>

#import "DYYYToast.h"
#import "DYYYUtils.h"
#import "DYYYPaths.h"

@interface YYImageFrame : NSObject
@property(nonatomic, strong) UIImage *image;
@property(nonatomic) CGFloat duration;
@end

@interface YYImageDecoder : NSObject
@property(nonatomic, readonly) NSUInteger frameCount;
+ (instancetype)decoderWithData:(NSData *)data scale:(CGFloat)scale;
- (YYImageFrame *)frameAtIndex:(NSUInteger)index decodeForDisplay:(BOOL)decodeForDisplay;
@end

static const NSTimeInterval kDYYYDefaultFrameDelay = 0.1f;

static inline CGFloat DYYYNormalizedDelay(CGFloat delay) {
    if (!isfinite(delay) || delay < 0.01f) {
        return kDYYYDefaultFrameDelay;
    }
    return delay;
}

static YYImageDecoder *DYYYCreateYYDecoderWithData(NSData *data, CGFloat scale) {
    if (!data || data.length == 0) {
        return nil;
    }

    Class decoderClass = NSClassFromString(@"YYImageDecoder");
    if (!decoderClass || ![decoderClass respondsToSelector:@selector(decoderWithData:scale:)]) {
        return nil;
    }

    CGFloat resolvedScale = scale > 0 ? scale : 1.0f;
    id decoderInstance = [(id)decoderClass decoderWithData:data scale:resolvedScale];
    if (![decoderInstance isKindOfClass:decoderClass]) {
        return nil;
    }

    return (YYImageDecoder *)decoderInstance;
}

static NSURL *DYYYTemporaryGIFURLForSourceURL(NSURL *sourceURL) {
    NSString *baseName = sourceURL.lastPathComponent.stringByDeletingPathExtension;
    if (baseName.length == 0) {
        baseName = @"image";
    }
    NSString *fileName = [NSString stringWithFormat:@"%@_%@.gif", baseName, [[NSUUID UUID] UUIDString]];
    NSString *path = [[DYYYPaths tempDir] stringByAppendingPathComponent:fileName];
    return [NSURL fileURLWithPath:path];
}

static BOOL DYYYWriteGIFUsingYYDecoder(YYImageDecoder *decoder, NSURL *gifURL) {
    if (!decoder || decoder.frameCount == 0) {
        return NO;
    }

    NSUInteger frameCount = (NSUInteger)decoder.frameCount;
    CGImageDestinationRef dest = CGImageDestinationCreateWithURL((__bridge CFURLRef)gifURL, kUTTypeGIF, frameCount, NULL);
    if (!dest) {
        return NO;
    }

    NSDictionary *gifProperties = @{(__bridge NSString *)kCGImagePropertyGIFDictionary : @{(__bridge NSString *)kCGImagePropertyGIFLoopCount : @0}};
    CGImageDestinationSetProperties(dest, (__bridge CFDictionaryRef)gifProperties);

    BOOL hasFrame = NO;
    for (NSUInteger i = 0; i < frameCount; i++) {
        YYImageFrame *frame = [decoder frameAtIndex:i decodeForDisplay:YES];
        UIImage *image = frame.image;
        CGImageRef imageRef = image.CGImage;
        if (!imageRef) {
            continue;
        }

        CGFloat delay = DYYYNormalizedDelay(frame.duration);
        NSDictionary *frameProps = @{(__bridge NSString *)kCGImagePropertyGIFDictionary : @{(__bridge NSString *)kCGImagePropertyGIFDelayTime : @(delay)}};
        CGImageDestinationAddImage(dest, imageRef, (__bridge CFDictionaryRef)frameProps);
        hasFrame = YES;
    }

    BOOL success = hasFrame ? CGImageDestinationFinalize(dest) : NO;
    CFRelease(dest);
    return success;
}

static BOOL DYYYConvertAnimatedDataWithYYDecoder(NSData *data, NSURL *gifURL) {
    YYImageDecoder *decoder = DYYYCreateYYDecoderWithData(data, 1.0f);
    if (!decoder) {
        return NO;
    }
    return DYYYWriteGIFUsingYYDecoder(decoder, gifURL);
}

static BOOL DYYYWriteStaticImageToGIF(UIImage *image, NSURL *gifURL) {
    CGImageRef imageRef = image.CGImage;
    if (!imageRef) {
        return NO;
    }

    CGImageDestinationRef dest = CGImageDestinationCreateWithURL((__bridge CFURLRef)gifURL, kUTTypeGIF, 1, NULL);
    if (!dest) {
        return NO;
    }

    NSDictionary *gifProperties = @{(__bridge NSString *)kCGImagePropertyGIFDictionary : @{(__bridge NSString *)kCGImagePropertyGIFLoopCount : @0}};
    CGImageDestinationSetProperties(dest, (__bridge CFDictionaryRef)gifProperties);

    NSDictionary *frameProperties = @{(__bridge NSString *)kCGImagePropertyGIFDictionary : @{(__bridge NSString *)kCGImagePropertyGIFDelayTime : @(kDYYYDefaultFrameDelay)}};
    CGImageDestinationAddImage(dest, imageRef, (__bridge CFDictionaryRef)frameProperties);

    BOOL success = CGImageDestinationFinalize(dest);
    CFRelease(dest);
    return success;
}


@implementation DYYYManager (Download)

+ (void)saveMedia:(NSURL *)mediaURL
        mediaType:(MediaType)mediaType
       completion:(void (^)(void))completion {
  if (mediaType == MediaTypeAudio) {
    return;
  }

  [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
    if (status == PHAuthorizationStatusAuthorized) {
      // 如果是表情包类型，先检查实际格式
      if (mediaType == MediaTypeHeic) {
        // 检测文件的实际格式
        NSString *actualFormat = [self detectFileFormat:mediaURL];

        if ([actualFormat isEqualToString:@"webp"]) {
          // WebP格式处理
          [self convertWebpToGifSafely:mediaURL
                            completion:^(NSURL *gifURL, BOOL success) {
                              if (success && gifURL) {
                                [self
                                    saveGifToPhotoLibrary:gifURL
                                                mediaType:mediaType
                                               completion:^{
                                                 // 清理原始文件
                                                 [[NSFileManager defaultManager]
                                                     removeItemAtPath:mediaURL
                                                                          .path
                                                                error:nil];
                                                 if (completion) {
                                                   completion();
                                                 }
                                               }];
                              } else {
                                [self showToast:@"转换失败"];
                                // 清理临时文件
                                [[NSFileManager defaultManager]
                                    removeItemAtPath:mediaURL.path
                                               error:nil];
                                if (completion) {
                                  completion();
                                }
                              }
                            }];
        } else if ([actualFormat isEqualToString:@"heic"] ||
                   [actualFormat isEqualToString:@"heif"]) {
          // HEIC/HEIF格式处理
          [self convertHeicToGif:mediaURL
                      completion:^(NSURL *gifURL, BOOL success) {
                        if (success && gifURL) {
                          [self saveGifToPhotoLibrary:gifURL
                                            mediaType:mediaType
                                           completion:^{
                                             // 清理原始文件
                                             [[NSFileManager defaultManager]
                                                 removeItemAtPath:mediaURL.path
                                                            error:nil];
                                             if (completion) {
                                               completion();
                                             }
                                           }];
                        } else {
                          [self showToast:@"转换失败"];
                          // 清理临时文件
                          [[NSFileManager defaultManager]
                              removeItemAtPath:mediaURL.path
                                         error:nil];
                          if (completion) {
                            completion();
                          }
                        }
                      }];
        } else if ([actualFormat isEqualToString:@"gif"]) {
          // 已经是GIF格式，直接保存
          [self saveGifToPhotoLibrary:mediaURL
                            mediaType:mediaType
                           completion:completion];
        } else {
          // 其他格式，尝试作为普通图像保存
          [[PHPhotoLibrary sharedPhotoLibrary]
              performChanges:^{
                UIImage *image =
                    [UIImage imageWithContentsOfFile:mediaURL.path];
                if (image) {
                  [PHAssetChangeRequest creationRequestForAssetFromImage:image];
                }
              }
              completionHandler:^(BOOL success, NSError *_Nullable error) {
                if (success) {
                  if (completion) {
                    completion();
                  }
                } else {
                  [self showToast:@"保存失败"];
                }
                // 不管成功失败都清理临时文件
                [[NSFileManager defaultManager] removeItemAtPath:mediaURL.path
                                                           error:nil];
              }];
        }
      } else {
        // 非表情包类型的正常保存流程
        [[PHPhotoLibrary sharedPhotoLibrary]
            performChanges:^{
              if (mediaType == MediaTypeVideo) {
                [PHAssetChangeRequest
                    creationRequestForAssetFromVideoAtFileURL:mediaURL];
              } else {
                UIImage *image =
                    [UIImage imageWithContentsOfFile:mediaURL.path];
                if (image) {
                  [PHAssetChangeRequest creationRequestForAssetFromImage:image];
                }
              }
            }
            completionHandler:^(BOOL success, NSError *_Nullable error) {
              if (success) {

                if (completion) {
                  completion();
                }
              } else {
                [self showToast:@"保存失败"];
              }
              // 不管成功失败都清理临时文件
              [[NSFileManager defaultManager] removeItemAtPath:mediaURL.path
                                                         error:nil];
            }];
      }
    }
  }];
}

// 检测文件格式的方法
+ (NSString *)detectFileFormat:(NSURL *)fileURL {
  // 读取文件的整个数据或足够的字节用于识别
  NSData *fileData = [NSData dataWithContentsOfURL:fileURL
                                           options:NSDataReadingMappedIfSafe
                                             error:nil];
  if (!fileData || fileData.length < 12) {
    return @"unknown";
  }

  // 转换为字节数组以便检查
  const unsigned char *bytes = [fileData bytes];

  // 检查WebP格式："RIFF" + 4字节 + "WEBP"
  if (bytes[0] == 'R' && bytes[1] == 'I' && bytes[2] == 'F' &&
      bytes[3] == 'F' && bytes[8] == 'W' && bytes[9] == 'E' &&
      bytes[10] == 'B' && bytes[11] == 'P') {
    return @"webp";
  }

  // 检查HEIF/HEIC格式："ftyp" 在第4-7字节位置
  if (bytes[4] == 'f' && bytes[5] == 't' && bytes[6] == 'y' &&
      bytes[7] == 'p') {
    if (fileData.length >= 16) {
      // 检查HEIC品牌
      if (bytes[8] == 'h' && bytes[9] == 'e' && bytes[10] == 'i' &&
          bytes[11] == 'c') {
        return @"heic";
      }
      // 检查HEIF品牌
      if (bytes[8] == 'h' && bytes[9] == 'e' && bytes[10] == 'i' &&
          bytes[11] == 'f') {
        return @"heif";
      }
      // 可能是其他HEIF变体
      return @"heif";
    }
  }

  // 检查GIF格式："GIF87a"或"GIF89a"
  if (bytes[0] == 'G' && bytes[1] == 'I' && bytes[2] == 'F') {
    return @"gif";
  }

  // 检查PNG格式
  if (bytes[0] == 0x89 && bytes[1] == 'P' && bytes[2] == 'N' &&
      bytes[3] == 'G') {
    return @"png";
  }

  // 检查JPEG格式
  if (bytes[0] == 0xFF && bytes[1] == 0xD8) {
    return @"jpeg";
  }

  return @"unknown";
}

// 保存GIF到相册的方法
+ (void)saveGifToPhotoLibrary:(NSURL *)gifURL
                    mediaType:(MediaType)mediaType
                   completion:(void (^)(void))completion {
  [[PHPhotoLibrary sharedPhotoLibrary]
      performChanges:^{
        // 获取GIF数据
        NSData *gifData = [NSData dataWithContentsOfURL:gifURL];
        // 创建相册资源
        PHAssetCreationRequest *request =
            [PHAssetCreationRequest creationRequestForAsset];
        // 实例相册类资源参数
        PHAssetResourceCreationOptions *options =
            [[PHAssetResourceCreationOptions alloc] init];
        // 定义GIF参数
        options.uniformTypeIdentifier = @"com.compuserve.gif";
        // 保存GIF图片
        [request addResourceWithType:PHAssetResourceTypePhoto
                                data:gifData
                             options:options];
      }
      completionHandler:^(BOOL success, NSError *_Nullable error) {
        if (success) {
          if (completion) {
            completion();
          }
        } else {
          [self showToast:@"保存失败"];
        }
        // 不管成功失败都清理临时文件
        [[NSFileManager defaultManager] removeItemAtPath:gifURL.path error:nil];
      }];
}

+ (void)convertWebpToGifSafely:(NSURL *)webpURL
                    completion:
                        (void (^)(NSURL *gifURL, BOOL success))completion {
    if (!webpURL) {
        dispatch_async(dispatch_get_main_queue(), ^{
          if (completion) {
              completion(nil, NO);
          }
        });
        return;
    }

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      NSData *webpData = [NSData dataWithContentsOfURL:webpURL options:NSDataReadingMappedIfSafe error:nil];
      if (!webpData) {
          dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(nil, NO);
            }
          });
          return;
      }

      NSURL *gifURL = DYYYTemporaryGIFURLForSourceURL(webpURL);
      [[NSFileManager defaultManager] removeItemAtURL:gifURL error:nil];

      BOOL success = DYYYConvertAnimatedDataWithYYDecoder(webpData, gifURL);
      if (!success) {
          UIImage *fallbackImage = [UIImage imageWithData:webpData];
          if (fallbackImage) {
              success = DYYYWriteStaticImageToGIF(fallbackImage, gifURL);
          }
      }

      if (!success) {
          [[NSFileManager defaultManager] removeItemAtURL:gifURL error:nil];
      }

      dispatch_async(dispatch_get_main_queue(), ^{
        if (completion) {
            completion(success ? gifURL : nil, success);
        }
      });
    });
}

// 将HEIC转换为GIF的方法
+ (void)convertHeicToGif:(NSURL *)heicURL
              completion:(void (^)(NSURL *gifURL, BOOL success))completion {
  dispatch_async(
      dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // 1. 创建ImageSource
        CGImageSourceRef src =
            CGImageSourceCreateWithURL((__bridge CFURLRef)heicURL, NULL);
        if (!src) {
          dispatch_async(dispatch_get_main_queue(), ^{
            if (completion)
              completion(nil, NO);
          });
          return;
        }

        // 2. 获取帧数
        size_t count = CGImageSourceGetCount(src);
        // 3. 生成GIF路径
        NSString *gifFileName =
            [[heicURL.lastPathComponent stringByDeletingPathExtension]
                stringByAppendingPathExtension:@"gif"];
        NSURL *gifURL = [NSURL
            fileURLWithPath:[[DYYYPaths tempDir]
                                stringByAppendingPathComponent:gifFileName]];

        // 4. GIF属性
        NSDictionary *gifProperties = @{
          (__bridge NSString *)kCGImagePropertyGIFDictionary :
              @{(__bridge NSString *)kCGImagePropertyGIFLoopCount : @0}
        };

        // 5. 创建GIF目标
        CGImageDestinationRef dest = CGImageDestinationCreateWithURL(
            (__bridge CFURLRef)gifURL, kUTTypeGIF, count, NULL);
        if (!dest) {
          CFRelease(src);
          dispatch_async(dispatch_get_main_queue(), ^{
            if (completion)
              completion(nil, NO);
          });
          return;
        }
        CGImageDestinationSetProperties(
            dest, (__bridge CFDictionaryRef)gifProperties);

        // 6. 遍历帧并写入GIF
        for (size_t i = 0; i < count; i++) {
          CGImageRef imgRef = CGImageSourceCreateImageAtIndex(src, i, NULL);

          // 获取帧延迟
          float delayTime = 0.1f;
          CFDictionaryRef properties =
              CGImageSourceCopyPropertiesAtIndex(src, i, NULL);
          if (properties) {
            CFDictionaryRef gifDict =
                CFDictionaryGetValue(properties, kCGImagePropertyGIFDictionary);
            if (gifDict) {
              CFNumberRef delayNum =
                  CFDictionaryGetValue(gifDict, kCGImagePropertyGIFDelayTime);
              if (delayNum)
                CFNumberGetValue(delayNum, kCFNumberFloatType, &delayTime);
            }
            if (delayTime <= 0.01f || delayTime > 10.0f)
              delayTime = 0.1f;
            CFRelease(properties);
          }

          NSDictionary *frameProps = @{
            (__bridge NSString *)kCGImagePropertyGIFDictionary : @{
              (__bridge NSString *)kCGImagePropertyGIFDelayTime : @(delayTime)
            }
          };

          if (imgRef) {
            CGImageDestinationAddImage(dest, imgRef,
                                       (__bridge CFDictionaryRef)frameProps);
            CGImageRelease(imgRef);
          }
        }

        // 7. 完成GIF生成
        BOOL success = CGImageDestinationFinalize(dest);
        CFRelease(dest);
        CFRelease(src);

        dispatch_async(dispatch_get_main_queue(), ^{
          if (completion)
            completion(gifURL, success);
        });
      });
}

+ (void)downloadLivePhoto:(NSURL *)imageURL
                 videoURL:(NSURL *)videoURL
               completion:(void (^)(void))completion {
  // 获取共享实例，确保FileLinks字典存在
  DYYYManager *manager = [DYYYManager shared];
  if (!manager.fileLinks) {
    manager.fileLinks = [NSMutableDictionary dictionary];
  }

  // 为图片和视频URL创建唯一的键
  NSString *uniqueKey =
      [NSString stringWithFormat:@"%@_%@", imageURL.absoluteString,
                                 videoURL.absoluteString];

  // 检查是否已经存在此下载任务
  NSDictionary *existingPaths = manager.fileLinks[uniqueKey];
  if (existingPaths) {
    NSString *imagePath = existingPaths[@"image"];
    NSString *videoPath = existingPaths[@"video"];

    // 使用异步检查以避免主线程阻塞
    dispatch_async(
        dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
          BOOL imageExists =
              [[NSFileManager defaultManager] fileExistsAtPath:imagePath];
          BOOL videoExists =
              [[NSFileManager defaultManager] fileExistsAtPath:videoPath];

          dispatch_async(dispatch_get_main_queue(), ^{
            if (imageExists && videoExists) {
              [[DYYYManager shared] saveLivePhoto:imagePath videoUrl:videoPath];
              if (completion) {
                completion();
              }
              return;
            } else {
              // 文件不完整，需要重新下载
              [self startDownloadLivePhotoProcess:imageURL
                                         videoURL:videoURL
                                        uniqueKey:uniqueKey
                                       completion:completion];
            }
          });
        });
  } else {
    // 没有缓存，直接开始下载
    [self startDownloadLivePhotoProcess:imageURL
                               videoURL:videoURL
                              uniqueKey:uniqueKey
                             completion:completion];
  }
}

+ (void)startDownloadLivePhotoProcess:(NSURL *)imageURL
                             videoURL:(NSURL *)videoURL
                            uniqueKey:(NSString *)uniqueKey
                           completion:(void (^)(void))completion {
  // 创建临时目录
  NSString *livePhotoPath =
      [[DYYYPaths tempDir] stringByAppendingPathComponent:@"LivePhoto"];

  NSFileManager *fileManager = [NSFileManager defaultManager];
  if (![fileManager fileExistsAtPath:livePhotoPath]) {
    [fileManager createDirectoryAtPath:livePhotoPath
           withIntermediateDirectories:YES
                            attributes:nil
                                 error:nil];
  }

  // 生成唯一标识符，防止多次调用时文件冲突
  NSString *uniqueID = [NSUUID UUID].UUIDString;
  NSString *imagePath = [livePhotoPath
      stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.heic",
                                                                uniqueID]];
  NSString *videoPath = [livePhotoPath
      stringByAppendingPathComponent:[NSString
                                         stringWithFormat:@"%@.mp4", uniqueID]];

  // 存储文件路径，以便下次下载相同的URL时可以复用
  DYYYManager *manager = [DYYYManager shared];
  [manager.fileLinks setObject:@{@"image" : imagePath, @"video" : videoPath}
                        forKey:uniqueKey];

  dispatch_async(dispatch_get_main_queue(), ^{
    // 创建进度视图
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    DYYYToast *progressView = [[DYYYToast alloc] initWithFrame:screenBounds];
    [progressView show];

    // 优化会话配置
    NSURLSessionConfiguration *configuration =
        [NSURLSessionConfiguration defaultSessionConfiguration];
    configuration.timeoutIntervalForRequest = 60.0; // 增加超时时间
    configuration.timeoutIntervalForResource = 60.0;
    configuration.HTTPMaximumConnectionsPerHost = 10; // 增加并发连接数
    configuration.requestCachePolicy =
        NSURLRequestReloadIgnoringLocalCacheData; // 强制从网络重新下载

    // 使用共享委托的session以节省资源
    NSURLSession *session =
        [NSURLSession sessionWithConfiguration:configuration
                                      delegate:[DYYYManager shared]
                                 delegateQueue:[NSOperationQueue mainQueue]];

    dispatch_group_t group = dispatch_group_create();
    __block BOOL imageDownloaded = NO;
    __block BOOL videoDownloaded = NO;
    __block float imageProgress = 0.0;
    __block float videoProgress = 0.0;

    // 设置单独的下载观察者ID用于进度跟踪
    NSString *imageDownloadID =
        [NSString stringWithFormat:@"image_%@", uniqueID];
    NSString *videoDownloadID =
        [NSString stringWithFormat:@"video_%@", uniqueID];

    // 更新合并进度的定时器
    __block NSTimer *progressTimer = [NSTimer
        scheduledTimerWithTimeInterval:0.1
                               repeats:YES
                                 block:^(NSTimer *_Nonnull timer) {
                                   float totalProgress =
                                       (imageProgress + videoProgress) / 2.0;
                                   [progressView setProgress:totalProgress];

                                   if (imageDownloaded && videoDownloaded) {
                                     [timer invalidate]; // 全部完成时停止定时器
                                   }
                                 }];

    // 下载图片
    dispatch_group_enter(group);
    NSURLRequest *imageRequest = [NSURLRequest requestWithURL:imageURL];
    NSURLSessionDataTask *imageTask =
        [session dataTaskWithRequest:imageRequest
                   completionHandler:^(NSData *_Nullable data,
                                       NSURLResponse *_Nullable response,
                                       NSError *_Nullable error) {
                     if (!error && data) {
                       // 直接写入文件，避免临时文件移动操作
                       if ([data writeToFile:imagePath atomically:YES]) {
                         imageDownloaded = YES;
                         imageProgress = 1.0;
                       }
                     }
                     dispatch_group_leave(group);
                   }];

    // 设置图片下载进度观察
    if ([imageTask respondsToSelector:@selector(taskIdentifier)]) {
      @synchronized(manager) {
        [[manager taskProgressMap] setObject:@(0.0) forKey:imageDownloadID];
      }

      // 使用系统API观察进度 (iOS 11+)
      if (@available(iOS 11.0, *)) {
        [imageTask.progress addObserver:manager
                             forKeyPath:@"fractionCompleted"
                                options:NSKeyValueObservingOptionNew
                                context:(__bridge void *)(imageDownloadID)];
      }
    }

    // 下载视频
    dispatch_group_enter(group);
    NSURLRequest *videoRequest = [NSURLRequest requestWithURL:videoURL];
    NSURLSessionDataTask *videoTask =
        [session dataTaskWithRequest:videoRequest
                   completionHandler:^(NSData *_Nullable data,
                                       NSURLResponse *_Nullable response,
                                       NSError *_Nullable error) {
                     if (!error && data) {
                       // 直接写入文件，避免临时文件移动操作
                       if ([data writeToFile:videoPath atomically:YES]) {
                         videoDownloaded = YES;
                         videoProgress = 1.0;
                       }
                     }
                     dispatch_group_leave(group);
                   }];

    // 设置视频下载进度观察
    if ([videoTask respondsToSelector:@selector(taskIdentifier)]) {
      @synchronized(manager) {
        [[manager taskProgressMap] setObject:@(0.0) forKey:videoDownloadID];
      }

      // 使用系统API观察进度 (iOS 11+)
      if (@available(iOS 11.0, *)) {
        [videoTask.progress addObserver:manager
                             forKeyPath:@"fractionCompleted"
                                options:NSKeyValueObservingOptionNew
                                context:(__bridge void *)(videoDownloadID)];
      }
    }

    // 启动下载任务
    [imageTask resume];
    [videoTask resume];

    // 当两个下载都完成后，保存实况照片
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
      // 停止进度定时器
      [progressTimer invalidate];

      // 移除进度观察
      if (@available(iOS 11.0, *)) {
        if ([imageTask respondsToSelector:@selector(progress)]) {
          [imageTask.progress removeObserver:manager
                                  forKeyPath:@"fractionCompleted"];
        }
        if ([videoTask respondsToSelector:@selector(progress)]) {
          [videoTask.progress removeObserver:manager
                                  forKeyPath:@"fractionCompleted"];
        }
      }

      // 检查文件是否真的存在
      BOOL imageExists =
          [[NSFileManager defaultManager] fileExistsAtPath:imagePath];
      BOOL videoExists =
          [[NSFileManager defaultManager] fileExistsAtPath:videoPath];

      // 隐藏进度视图
      progressView.allowSuccessAnimation = (imageExists && videoExists);
      [progressView dismiss];

      if (imageExists && videoExists) {
        @try {
          // 添加iOS版本检查
          if (@available(iOS 15.0, *)) {
            [[DYYYManager shared] saveLivePhoto:imagePath videoUrl:videoPath];
          }
        } @catch (NSException *exception) {
          // 删除失败的文件
          [[NSFileManager defaultManager] removeItemAtPath:imagePath error:nil];
          [[NSFileManager defaultManager] removeItemAtPath:videoPath error:nil];
          [manager.fileLinks removeObjectForKey:uniqueKey];
          [DYYYManager showToast:@"保存实况照片失败"];
        }
      } else {
        // 清理不完整的文件
        if (imageExists)
          [[NSFileManager defaultManager] removeItemAtPath:imagePath error:nil];
        if (videoExists)
          [[NSFileManager defaultManager] removeItemAtPath:videoPath error:nil];
        [manager.fileLinks removeObjectForKey:uniqueKey];
        [DYYYManager showToast:@"下载实况照片失败"];
      }

      if (completion) {
        completion();
      }
    });
  });
}

// 需要添加KVO回调方法来处理下载进度
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey, id> *)change
                       context:(void *)context {
  if ([keyPath isEqualToString:@"fractionCompleted"] &&
      [object isKindOfClass:[NSProgress class]]) {
    NSString *downloadID = (__bridge NSString *)context;
    if (downloadID) {
      NSProgress *progress = (NSProgress *)object;
      float fractionCompleted = progress.fractionCompleted;
      @synchronized(self) {
        [self.taskProgressMap setObject:@(fractionCompleted) forKey:downloadID];
      }
    }
  } else {
    [super observeValueForKeyPath:keyPath
                         ofObject:object
                           change:change
                          context:context];
  }
}

+ (void)downloadMedia:(NSURL *)url
            mediaType:(MediaType)mediaType
           completion:(void (^)(BOOL success))completion {
  [self downloadMediaWithProgress:url
                        mediaType:mediaType
                         progress:nil
                       completion:^(BOOL success, NSURL *fileURL) {
                         if (success) {
                           if (mediaType == MediaTypeAudio) {
                             dispatch_async(dispatch_get_main_queue(), ^{
                               UIActivityViewController *activityVC =
                                   [[UIActivityViewController alloc]
                                       initWithActivityItems:@[ fileURL ]
                                       applicationActivities:nil];

                               [activityVC
                                   setCompletionWithItemsHandler:^(
                                       UIActivityType _Nullable activityType,
                                       BOOL completed,
                                       NSArray *_Nullable returnedItems,
                                       NSError *_Nullable error) {
                                     [[NSFileManager defaultManager]
                                         removeItemAtURL:fileURL
                                                   error:nil];
                                   }];
                               UIViewController *rootVC =
                                   [UIApplication sharedApplication]
                                       .keyWindow.rootViewController;
                               [rootVC presentViewController:activityVC
                                                    animated:YES
                                                  completion:nil];
                               if (completion) {
                                 completion(YES);
                               }
                             });
                           } else {
                             [self saveMedia:fileURL
                                   mediaType:mediaType
                                  completion:^{
                                    if (completion) {
                                      completion(YES);
                                    }
                                  }];
                           }
                         } else {
                           if (completion) {
                             completion(NO);
                           }
                         }
                       }];
}

+ (void)downloadMediaWithProgress:(NSURL *)url
                        mediaType:(MediaType)mediaType
                         progress:(void (^)(float progress))progressBlock
                       completion:
                           (void (^)(BOOL success, NSURL *fileURL))completion {
  dispatch_async(dispatch_get_main_queue(), ^{
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    DYYYToast *progressView = [[DYYYToast alloc] initWithFrame:screenBounds];

    NSString *downloadID = [NSUUID UUID].UUIDString;
    DYYYManager *manager = [DYYYManager shared];

    @synchronized(manager) {
      [manager.progressViews setObject:progressView forKey:downloadID];
    }

    [progressView show];

    [manager setCompletionBlock:completion forDownloadID:downloadID];
    [manager setMediaType:mediaType forDownloadID:downloadID];

    NSURLSessionConfiguration *configuration =
        [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session =
        [NSURLSession sessionWithConfiguration:configuration
                                      delegate:manager
                                 delegateQueue:[NSOperationQueue mainQueue]];

    NSURLSessionDownloadTask *downloadTask = [session downloadTaskWithURL:url];

    @synchronized(manager) {
      [manager.downloadTasks setObject:downloadTask forKey:downloadID];
      [manager.taskProgressMap setObject:@0.0 forKey:downloadID];
    }

    [downloadTask resume];
  });
}

+ (NSString *)getMediaTypeDescription:(MediaType)mediaType {
  switch (mediaType) {
  case MediaTypeVideo:
    return @"视频";
  case MediaTypeImage:
    return @"图片";
  case MediaTypeAudio:
    return @"音频";
  case MediaTypeHeic:
    return @"表情包";
  default:
    return @"文件";
  }
}

// 取消所有下载
+ (void)cancelAllDownloads {
  DYYYManager *manager = [DYYYManager shared];
  NSArray *downloadIDs = nil;
  NSMutableArray *tasksToCancel = [NSMutableArray array];
  NSMutableArray *progressViewsToDismiss = [NSMutableArray array];

  @synchronized(manager) {
    downloadIDs = [manager.downloadTasks allKeys];
    for (NSString *downloadID in downloadIDs) {
      NSURLSessionDownloadTask *task = manager.downloadTasks[downloadID];
      if (task) {
        [tasksToCancel addObject:task];
      }
      DYYYToast *progressView = manager.progressViews[downloadID];
      if (progressView) {
        [progressViewsToDismiss addObject:progressView];
      }
    }
  }

  for (NSURLSessionDownloadTask *task in tasksToCancel) {
    [task cancel];
  }

  for (DYYYToast *progressView in progressViewsToDismiss) {
    [progressView dismiss];
  }

  NSString *livePhotoPath = [[DYYYPaths tempDir] stringByAppendingPathComponent:@"LivePhotoBatch"];
  NSFileManager *fileManager = [NSFileManager defaultManager];
  if ([fileManager fileExistsAtPath:livePhotoPath]) {
    NSError *error = nil;
    [fileManager removeItemAtPath:livePhotoPath error:&error];
    if (error) {
      NSLog(@"清理实况照片临时目录失败: %@", error.localizedDescription);
    }
  }
  
  NSString *generalLivePhotoPath = [[DYYYPaths tempDir] stringByAppendingPathComponent:@"LivePhoto"];
  if ([fileManager fileExistsAtPath:generalLivePhotoPath]) {
    NSError *error = nil;
    [fileManager removeItemAtPath:generalLivePhotoPath error:&error];
    if (error) {
      NSLog(@"清理LivePhoto临时目录失败: %@", error.localizedDescription);
    }
  }

  @synchronized(manager) {
    [manager.downloadTasks removeAllObjects];
    [manager.progressViews removeAllObjects];
  }
}

+ (void)downloadAllImages:(NSMutableArray *)imageURLs {
  if (imageURLs.count == 0) {
    return;
  }

  [self downloadAllImagesWithProgress:imageURLs
                             progress:nil
                           completion:^(NSInteger successCount,
                                        NSInteger totalCount){
                           }];
}

+ (void)downloadAllImagesWithProgress:(NSMutableArray *)imageURLs
                             progress:(void (^)(NSInteger current,
                                                NSInteger total))progressBlock
                           completion:
                               (void (^)(NSInteger successCount,
                                         NSInteger totalCount))completion {
  if (imageURLs.count == 0) {
    if (completion) {
      completion(0, 0);
    }
    return;
  }

  dispatch_async(dispatch_get_main_queue(), ^{
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    DYYYToast *progressView = [[DYYYToast alloc] initWithFrame:screenBounds];
    NSString *batchID = [NSUUID UUID].UUIDString;
    DYYYManager *manager = [DYYYManager shared];

    @synchronized(manager) {
      [manager.progressViews setObject:progressView forKey:batchID];
    }

    [progressView show];

    __block NSInteger successCount = 0;
    NSInteger totalCount = imageURLs.count;

    if ([progressView respondsToSelector:@selector(setCancelBlock:)]) {
      [progressView performSelector:@selector(setCancelBlock:) withObject:^{
        progressView.isCancelled = YES;
        [progressView dismiss];
        [self cancelAllDownloads];
        if (completion) {
          completion(successCount, totalCount);
        }
      }];
    }

    [manager setBatchInfo:batchID
               totalCount:totalCount
            progressBlock:progressBlock
          completionBlock:completion];

    for (NSString *urlString in imageURLs) {
      NSURL *url = [NSURL URLWithString:urlString];
      if (!url) {
        [manager incrementCompletedAndUpdateProgressForBatch:batchID
                                                     success:NO];
        continue;
      }

      NSString *downloadID = [NSUUID UUID].UUIDString;
      [manager associateDownload:downloadID withBatchID:batchID];
      NSURLSessionConfiguration *configuration =
          [NSURLSessionConfiguration defaultSessionConfiguration];
      NSURLSession *session =
          [NSURLSession sessionWithConfiguration:configuration
                                        delegate:manager
                                   delegateQueue:[NSOperationQueue mainQueue]];

      NSURLSessionDownloadTask *downloadTask =
          [session downloadTaskWithURL:url];

      @synchronized(manager) {
        [manager.downloadTasks setObject:downloadTask forKey:downloadID];
        [manager.taskProgressMap setObject:@0.0 forKey:downloadID];
      }
      [manager setMediaType:MediaTypeImage forDownloadID:downloadID];
      [downloadTask resume];
    }
  });
}

// 设置批量下载信息
- (void)setBatchInfo:(NSString *)batchID
          totalCount:(NSInteger)totalCount
       progressBlock:(void (^)(NSInteger current, NSInteger total))progressBlock
     completionBlock:(void (^)(NSInteger successCount,
                               NSInteger totalCount))completionBlock {
  @synchronized(self) {
    [self.batchTotalCountMap setObject:@(totalCount) forKey:batchID];
    [self.batchCompletedCountMap setObject:@(0) forKey:batchID];
    [self.batchSuccessCountMap setObject:@(0) forKey:batchID];

    if (progressBlock) {
      [self.batchProgressBlocks setObject:[progressBlock copy] forKey:batchID];
    }

    if (completionBlock) {
      [self.batchCompletionBlocks setObject:[completionBlock copy]
                                     forKey:batchID];
    }
  }
}

// 关联单个下载到批量下载
- (void)associateDownload:(NSString *)downloadID
              withBatchID:(NSString *)batchID {
  @synchronized(self) {
    [self.downloadToBatchMap setObject:batchID forKey:downloadID];
  }
}

// 批量下载完成计数并更新进度
- (void)incrementCompletedAndUpdateProgressForBatch:(NSString *)batchID
                                            success:(BOOL)success {
  @synchronized(self) {
    NSNumber *completedCountNum = self.batchCompletedCountMap[batchID];
    NSInteger completedCount =
        completedCountNum ? [completedCountNum integerValue] + 1 : 1;
    [self.batchCompletedCountMap setObject:@(completedCount) forKey:batchID];

    if (success) {
      NSNumber *successCountNum = self.batchSuccessCountMap[batchID];
      NSInteger successCount =
          successCountNum ? [successCountNum integerValue] + 1 : 1;
      [self.batchSuccessCountMap setObject:@(successCount) forKey:batchID];
    }

    NSNumber *totalCountNum = self.batchTotalCountMap[batchID];
    NSInteger totalCount = totalCountNum ? [totalCountNum integerValue] : 0;

    DYYYToast *progressView = self.progressViews[batchID];
    if (progressView) {
      float progress = totalCount > 0 ? (float)completedCount / totalCount : 0;
      [progressView setProgress:progress];
    }

    void (^progressBlock)(NSInteger current, NSInteger total) =
        self.batchProgressBlocks[batchID];
    if (progressBlock) {
      progressBlock(completedCount, totalCount);
    }

    if (completedCount >= totalCount) {
      NSInteger successCount =
          [self.batchSuccessCountMap[batchID] integerValue];

      void (^completionBlock)(NSInteger successCount, NSInteger totalCount) =
          self.batchCompletionBlocks[batchID];
      if (completionBlock) {
        completionBlock(successCount, totalCount);
      }

      progressView.allowSuccessAnimation = (successCount > 0);
      [progressView dismiss];
      [self.progressViews removeObjectForKey:batchID];

      // 清理批量下载相关信息
      [self.batchCompletedCountMap removeObjectForKey:batchID];
      [self.batchSuccessCountMap removeObjectForKey:batchID];
      [self.batchTotalCountMap removeObjectForKey:batchID];
      [self.batchProgressBlocks removeObjectForKey:batchID];
      [self.batchCompletionBlocks removeObjectForKey:batchID];

      // 移除关联的下载ID
      NSArray *downloadIDs = [self.downloadToBatchMap allKeysForObject:batchID];
      for (NSString *downloadID in downloadIDs) {
        [self.downloadToBatchMap removeObjectForKey:downloadID];
      }
    }
  }
}

// 保存完成回调
- (void)setCompletionBlock:(void (^)(BOOL success, NSURL *fileURL))completion
             forDownloadID:(NSString *)downloadID {
  if (completion) {
    @synchronized(self) {
      [self.completionBlocks setObject:[completion copy] forKey:downloadID];
    }
  }
}

// 保存媒体类型
- (void)setMediaType:(MediaType)mediaType forDownloadID:(NSString *)downloadID {
  @synchronized(self) {
    [self.mediaTypeMap setObject:@(mediaType) forKey:downloadID];
  }
}

#pragma mark - NSURLSessionDownloadDelegate

- (void)URLSession:(NSURLSession *)session
                 downloadTask:(NSURLSessionDownloadTask *)downloadTask
                 didWriteData:(int64_t)bytesWritten
            totalBytesWritten:(int64_t)totalBytesWritten
    totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
  if (totalBytesExpectedToWrite <= 0) {
    return;
  }

  float progress = (float)totalBytesWritten / totalBytesExpectedToWrite;

  dispatch_async(dispatch_get_main_queue(), ^{
    NSString *downloadIDForTask = nil;

    @synchronized(self) {
      for (NSString *key in self.downloadTasks.allKeys) {
        NSURLSessionDownloadTask *task = self.downloadTasks[key];
        if (task == downloadTask) {
          downloadIDForTask = key;
          break;
        }
      }

      if (downloadIDForTask) {
        [self.taskProgressMap setObject:@(progress) forKey:downloadIDForTask];
      }
    }

    if (downloadIDForTask) {
      DYYYToast *progressView = nil;
      @synchronized(self) {
        progressView = self.progressViews[downloadIDForTask];
      }
      if (progressView) {
        if (!progressView.isCancelled) {
          [progressView setProgress:progress];
        }
      }
    }
  });
}

// 下载完成的代理方法
- (void)URLSession:(NSURLSession *)session
                 downloadTask:(NSURLSessionDownloadTask *)downloadTask
    didFinishDownloadingToURL:(NSURL *)location {
  NSString *downloadIDForTask = nil;
  NSString *batchID = nil;
  BOOL isBatchDownload = NO;
  MediaType mediaType = MediaTypeImage;

  @synchronized(self) {
    for (NSString *key in self.downloadTasks.allKeys) {
      NSURLSessionDownloadTask *task = self.downloadTasks[key];
      if (task == downloadTask) {
        downloadIDForTask = key;
        break;
      }
    }

    if (!downloadIDForTask) {
      return;
    }

    batchID = self.downloadToBatchMap[downloadIDForTask];
    isBatchDownload = (batchID != nil);

    NSNumber *mediaTypeNumber = self.mediaTypeMap[downloadIDForTask];
    if (mediaTypeNumber) {
      mediaType = (MediaType)[mediaTypeNumber integerValue];
    }
  }

  NSString *fileName = [downloadTask.originalRequest.URL lastPathComponent];

  if (!fileName.pathExtension.length) {
    switch (mediaType) {
    case MediaTypeVideo:
      fileName = [fileName stringByAppendingPathExtension:@"mp4"];
      break;
    case MediaTypeImage:
      fileName = [fileName stringByAppendingPathExtension:@"jpg"];
      break;
    case MediaTypeAudio:
      fileName = [fileName stringByAppendingPathExtension:@"mp3"];
      break;
    case MediaTypeHeic:
      fileName = [fileName stringByAppendingPathExtension:@"heic"];
      break;
    }
  }

  NSURL *tempDir = [NSURL fileURLWithPath:[DYYYPaths tempDir]];
  NSURL *destinationURL = [tempDir URLByAppendingPathComponent:fileName];

  NSError *moveError;
  if ([[NSFileManager defaultManager] fileExistsAtPath:destinationURL.path]) {
    [[NSFileManager defaultManager] removeItemAtURL:destinationURL error:nil];
  }

  [[NSFileManager defaultManager] moveItemAtURL:location
                                          toURL:destinationURL
                                          error:&moveError];

  if (isBatchDownload) {
    if (!moveError) {
      [DYYYManager saveMedia:destinationURL
                   mediaType:mediaType
                  completion:^{
                    [[DYYYManager shared]
                        incrementCompletedAndUpdateProgressForBatch:batchID
                                                            success:YES];
                  }];
    } else {
      [[DYYYManager shared] incrementCompletedAndUpdateProgressForBatch:batchID
                                                                success:NO];
    }

    @synchronized(self) {
      [self.downloadTasks removeObjectForKey:downloadIDForTask];
      [self.taskProgressMap removeObjectForKey:downloadIDForTask];
      [self.mediaTypeMap removeObjectForKey:downloadIDForTask];
    }
  } else {
    void (^completionBlock)(BOOL success, NSURL *fileURL) = nil;
    @synchronized(self) {
      completionBlock = self.completionBlocks[downloadIDForTask];
    }

    dispatch_async(dispatch_get_main_queue(), ^{
      DYYYToast *progressView = nil;
      BOOL wasCancelled = NO;

      @synchronized(self) {
        progressView = self.progressViews[downloadIDForTask];
        wasCancelled = progressView.isCancelled;

        [self.progressViews removeObjectForKey:downloadIDForTask];
        [self.downloadTasks removeObjectForKey:downloadIDForTask];
        [self.taskProgressMap removeObjectForKey:downloadIDForTask];
        [self.completionBlocks removeObjectForKey:downloadIDForTask];
        [self.mediaTypeMap removeObjectForKey:downloadIDForTask];
      }

      progressView.allowSuccessAnimation = !moveError;
      [progressView dismiss];

      if (wasCancelled) {
        return;
      }

      if (!moveError) {
        if (completionBlock) {
          completionBlock(YES, destinationURL);
        }
      } else {
        if (completionBlock) {
          completionBlock(NO, nil);
        }
      }
    });
  }
}

- (void)URLSession:(NSURLSession *)session
                    task:(NSURLSessionTask *)task
    didCompleteWithError:(NSError *)error {
  if (!error) {
    return;
  }

  NSString *downloadIDForTask = nil;
  NSString *batchID = nil;
  BOOL isBatchDownload = NO;

  @synchronized(self) {
    for (NSString *key in self.downloadTasks.allKeys) {
      NSURLSessionTask *existingTask = self.downloadTasks[key];
      if (existingTask == task) {
        downloadIDForTask = key;
        break;
      }
    }

    if (!downloadIDForTask) {
      return;
    }

    batchID = self.downloadToBatchMap[downloadIDForTask];
    isBatchDownload = (batchID != nil);
  }

  if (isBatchDownload) {
    [[DYYYManager shared] incrementCompletedAndUpdateProgressForBatch:batchID
                                                              success:NO];

    @synchronized(self) {
      [self.downloadTasks removeObjectForKey:downloadIDForTask];
      [self.taskProgressMap removeObjectForKey:downloadIDForTask];
      [self.mediaTypeMap removeObjectForKey:downloadIDForTask];
      [self.downloadToBatchMap removeObjectForKey:downloadIDForTask];
    }
  } else {
    void (^completionBlock)(BOOL success, NSURL *fileURL) = nil;
    @synchronized(self) {
      completionBlock = self.completionBlocks[downloadIDForTask];
    }

    dispatch_async(dispatch_get_main_queue(), ^{
      DYYYToast *progressView = nil;

      @synchronized(self) {
        progressView = self.progressViews[downloadIDForTask];

        [self.progressViews removeObjectForKey:downloadIDForTask];
        [self.downloadTasks removeObjectForKey:downloadIDForTask];
        [self.taskProgressMap removeObjectForKey:downloadIDForTask];
        [self.completionBlocks removeObjectForKey:downloadIDForTask];
        [self.mediaTypeMap removeObjectForKey:downloadIDForTask];
      }

      [progressView dismiss];

      if (error.code != NSURLErrorCancelled) {
        [DYYYManager showToast:@"下载失败"];
      }

      if (completionBlock) {
        completionBlock(NO, nil);
      }
    });
  }
}

// MARK: 以下都是创建保存实况的调用方法
- (void)saveLivePhoto:(NSString *)imageSourcePath
             videoUrl:(NSString *)videoSourcePath {
  // 首先检查iOS版本
  if (@available(iOS 15.0, *)) {
    // iOS 15及更高版本使用原有的实现
    NSURL *photoURL = [NSURL fileURLWithPath:imageSourcePath];
    NSURL *videoURL = [NSURL fileURLWithPath:videoSourcePath];
    BOOL available = [PHAssetCreationRequest supportsAssetResourceTypes:@[
      @(PHAssetResourceTypePhoto), @(PHAssetResourceTypePairedVideo)
    ]];
    if (!available) {
      return;
    }
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
      if (status != PHAuthorizationStatusAuthorized) {
        return;
      }
      NSString *identifier = [NSUUID UUID].UUIDString;
      [self useAssetWriter:photoURL
                     video:videoURL
                identifier:identifier
                  complete:^(BOOL success, NSString *photoFile,
                             NSString *videoFile, NSError *error) {
                    NSURL *photo = [NSURL fileURLWithPath:photoFile];
                    NSURL *video = [NSURL fileURLWithPath:videoFile];
                    [[PHPhotoLibrary sharedPhotoLibrary]
                        performChanges:^{
                          PHAssetCreationRequest *request =
                              [PHAssetCreationRequest creationRequestForAsset];
                          [request addResourceWithType:PHAssetResourceTypePhoto
                                               fileURL:photo
                                               options:nil];
                          [request
                              addResourceWithType:PHAssetResourceTypePairedVideo
                                          fileURL:video
                                          options:nil];
                        }
                        completionHandler:^(BOOL success,
                                            NSError *_Nullable error) {
                          dispatch_async(dispatch_get_main_queue(), ^{
                            if (success) {
                              // 删除临时文件
                              [[NSFileManager defaultManager]
                                  removeItemAtPath:imageSourcePath
                                             error:nil];
                              [[NSFileManager defaultManager]
                                  removeItemAtPath:videoSourcePath
                                             error:nil];
                              [[NSFileManager defaultManager]
                                  removeItemAtPath:photoFile
                                             error:nil];
                              [[NSFileManager defaultManager]
                                  removeItemAtPath:videoFile
                                             error:nil];
                            }
                          });
                        }];
                  }];
    }];
  } else {
    dispatch_async(dispatch_get_main_queue(), ^{
      [DYYYManager
          showToast:@"当前iOS版本不支持实况照片，将分别保存图片和视频"];
    });
  }
}

- (void)useAssetWriter:(NSURL *)photoURL
                 video:(NSURL *)videoURL
            identifier:(NSString *)identifier
              complete:(void (^)(BOOL success, NSString *photoFile,
                                 NSString *videoFile, NSError *error))complete {
  NSString *photoName = [photoURL lastPathComponent];
  NSString *photoFile = [self filePathFromTmp:photoName];
  [self addMetadataToPhoto:photoURL outputFile:photoFile identifier:identifier];
  NSString *videoName = [videoURL lastPathComponent];
  NSString *videoFile = [self filePathFromTmp:videoName];
  [self addMetadataToVideo:videoURL outputFile:videoFile identifier:identifier];
  if (!DYYYManager.shared->group)
    return;
  dispatch_group_notify(DYYYManager.shared->group, dispatch_get_main_queue(), ^{
    [self finishWritingTracksWithPhoto:photoFile
                                 video:videoFile
                              complete:complete];
  });
}
- (void)finishWritingTracksWithPhoto:(NSString *)photoFile
                               video:(NSString *)videoFile
                            complete:(void (^)(BOOL success,
                                               NSString *photoFile,
                                               NSString *videoFile,
                                               NSError *error))complete {
  [DYYYManager.shared->reader cancelReading];
  [DYYYManager.shared->writer finishWritingWithCompletionHandler:^{
    if (complete)
      complete(YES, photoFile, videoFile, nil);
  }];
}
- (void)addMetadataToPhoto:(NSURL *)photoURL
                outputFile:(NSString *)outputFile
                identifier:(NSString *)identifier {
  NSMutableData *data = [NSData dataWithContentsOfURL:photoURL].mutableCopy;
  UIImage *image = [UIImage imageWithData:data];
  CGImageRef imageRef = image.CGImage;
  NSDictionary *imageMetadata = @{
    (NSString *)kCGImagePropertyMakerAppleDictionary : @{@"17" : identifier}
  };
  CGImageDestinationRef dest = CGImageDestinationCreateWithData(
      (CFMutableDataRef)data, kUTTypeJPEG, 1, nil);
  CGImageDestinationAddImage(dest, imageRef, (CFDictionaryRef)imageMetadata);
  CGImageDestinationFinalize(dest);
  [data writeToFile:outputFile atomically:YES];
}

- (void)addMetadataToVideo:(NSURL *)videoURL
                outputFile:(NSString *)outputFile
                identifier:(NSString *)identifier {
  NSError *error = nil;
  AVAsset *videoAsset = [AVAsset assetWithURL:videoURL];
  AVAssetReader *assetReader = [AVAssetReader assetReaderWithAsset:videoAsset
                                                             error:&error];
  if (error) {
    return;
  }
  NSMutableArray<AVMetadataItem *> *metadata = videoAsset.metadata.mutableCopy;
  AVMetadataItem *item = [self createContentIdentifierMetadataItem:identifier];
  [metadata addObject:item];
  NSURL *videoFileURL = [NSURL fileURLWithPath:outputFile];
  [self deleteFile:outputFile];
  AVAssetWriter *assetWriter =
      [AVAssetWriter assetWriterWithURL:videoFileURL
                               fileType:AVFileTypeQuickTimeMovie
                                  error:&error];
  if (error) {
    return;
  }
  [assetWriter setMetadata:metadata];
  NSArray<AVAssetTrack *> *tracks = [videoAsset tracks];
  for (AVAssetTrack *track in tracks) {
    NSDictionary *readerOutputSettings = nil;
    NSDictionary *writerOuputSettings = nil;
    if ([track.mediaType isEqualToString:AVMediaTypeAudio]) {
      readerOutputSettings = @{AVFormatIDKey : @(kAudioFormatLinearPCM)};
      writerOuputSettings = @{
        AVFormatIDKey : @(kAudioFormatMPEG4AAC),
        AVSampleRateKey : @(44100),
        AVNumberOfChannelsKey : @(2),
        AVEncoderBitRateKey : @(128000)
      };
    }
    AVAssetReaderTrackOutput *output = [AVAssetReaderTrackOutput
        assetReaderTrackOutputWithTrack:track
                         outputSettings:readerOutputSettings];
    AVAssetWriterInput *input =
        [AVAssetWriterInput assetWriterInputWithMediaType:track.mediaType
                                           outputSettings:writerOuputSettings];
    if ([assetReader canAddOutput:output] && [assetWriter canAddInput:input]) {
      [assetReader addOutput:output];
      [assetWriter addInput:input];
    }
  }
  AVAssetWriterInput *input = [self createStillImageTimeAssetWriterInput];
  AVAssetWriterInputMetadataAdaptor *adaptor =
      [AVAssetWriterInputMetadataAdaptor
          assetWriterInputMetadataAdaptorWithAssetWriterInput:input];
  if ([assetWriter canAddInput:input]) {
    [assetWriter addInput:input];
  }
  [assetWriter startWriting];
  [assetWriter startSessionAtSourceTime:kCMTimeZero];
  [assetReader startReading];
  AVMetadataItem *timedItem = [self createStillImageTimeMetadataItem];
  CMTimeRange timedRange = CMTimeRangeMake(kCMTimeZero, CMTimeMake(1, 100));
  AVTimedMetadataGroup *timedMetadataGroup =
      [[AVTimedMetadataGroup alloc] initWithItems:@[ timedItem ]
                                        timeRange:timedRange];
  [adaptor appendTimedMetadataGroup:timedMetadataGroup];
  DYYYManager.shared->reader = assetReader;
  DYYYManager.shared->writer = assetWriter;
  DYYYManager.shared->queue =
      dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
  DYYYManager.shared->group = dispatch_group_create();
  for (NSInteger i = 0; i < assetReader.outputs.count; ++i) {
    dispatch_group_enter(DYYYManager.shared->group);
    [self writeTrack:i];
  }
}

- (void)writeTrack:(NSInteger)trackIndex {
  AVAssetReaderOutput *output = DYYYManager.shared->reader.outputs[trackIndex];
  AVAssetWriterInput *input = DYYYManager.shared->writer.inputs[trackIndex];

  [input
      requestMediaDataWhenReadyOnQueue:DYYYManager.shared->queue
                            usingBlock:^{
                              while (input.readyForMoreMediaData) {
                                AVAssetReaderStatus status =
                                    DYYYManager.shared->reader.status;
                                CMSampleBufferRef buffer = NULL;
                                if ((status == AVAssetReaderStatusReading) &&
                                    (buffer = [output copyNextSampleBuffer])) {
                                  BOOL success =
                                      [input appendSampleBuffer:buffer];
                                  CFRelease(buffer);
                                  if (!success) {

                                    [input markAsFinished];
                                    dispatch_group_leave(
                                        DYYYManager.shared->group);
                                    return;
                                  }
                                } else {
                                  if (status == AVAssetReaderStatusReading) {

                                  } else if (status ==
                                             AVAssetReaderStatusCompleted) {

                                  } else if (status ==
                                             AVAssetReaderStatusCancelled) {

                                  } else if (status ==
                                             AVAssetReaderStatusFailed) {
                                  }
                                  [input markAsFinished];
                                  dispatch_group_leave(
                                      DYYYManager.shared->group);
                                  return;
                                }
                              }
                            }];
}
- (AVMetadataItem *)createContentIdentifierMetadataItem:(NSString *)identifier {
  AVMutableMetadataItem *item = [AVMutableMetadataItem metadataItem];
  item.keySpace = AVMetadataKeySpaceQuickTimeMetadata;
  item.key = AVMetadataQuickTimeMetadataKeyContentIdentifier;
  item.value = identifier;
  return item;
}

- (AVAssetWriterInput *)createStillImageTimeAssetWriterInput {
  NSArray *spec = @[ @{
    (NSString *)
    kCMMetadataFormatDescriptionMetadataSpecificationKey_Identifier :
        @"mdta/com.apple.quicktime.still-image-time",
    (NSString *)kCMMetadataFormatDescriptionMetadataSpecificationKey_DataType :
        (NSString *)kCMMetadataBaseDataType_SInt8
  } ];
  CMFormatDescriptionRef desc = NULL;
  CMMetadataFormatDescriptionCreateWithMetadataSpecifications(
      kCFAllocatorDefault, kCMMetadataFormatType_Boxed,
      (__bridge CFArrayRef)spec, &desc);
  AVAssetWriterInput *input =
      [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeMetadata
                                         outputSettings:nil
                                       sourceFormatHint:desc];
  return input;
}

- (AVMetadataItem *)createStillImageTimeMetadataItem {
  AVMutableMetadataItem *item = [AVMutableMetadataItem metadataItem];
  item.keySpace = AVMetadataKeySpaceQuickTimeMetadata;
  item.key = @"com.apple.quicktime.still-image-time";
  item.value = @(-1);
  item.dataType = (NSString *)kCMMetadataBaseDataType_SInt8;
  return item;
}
- (NSString *)filePathFromTmp:(NSString *)filename {
  NSString *tempPath = [DYYYPaths tempDir];
  NSString *filePath = [tempPath stringByAppendingPathComponent:filename];
  return filePath;
}

- (void)deleteFile:(NSString *)file {
  NSFileManager *fm = [NSFileManager defaultManager];
  if ([fm fileExistsAtPath:file]) {
    [fm removeItemAtPath:file error:nil];
  }
}

+ (void)downloadAllLivePhotos:(NSArray<NSDictionary *> *)livePhotos {
  if (livePhotos.count == 0) {
    return;
  }

  [self downloadAllLivePhotosWithProgress:livePhotos
                                 progress:nil
                               completion:^(NSInteger successCount,
                                            NSInteger totalCount){
                               }];
}
+ (void)downloadAllLivePhotosWithProgress:(NSArray<NSDictionary *> *)livePhotos
                                 progress:(void (^)(NSInteger current, NSInteger total))progressBlock
                               completion:(void (^)(NSInteger successCount, NSInteger totalCount))completion {
    if (livePhotos.count == 0) {
        if (completion) {
            completion(0, 0);
        }
        return;
    }

    // 检查iOS版本是否支持实况照片
    BOOL supportsLivePhoto = NO;
    if (@available(iOS 15.0, *)) {
        supportsLivePhoto = YES;
    }

    if (!supportsLivePhoto) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showToast:@"当前iOS版本不支持实况照片"];
            if (completion) {
                completion(0, livePhotos.count);
            }
        });
        return;
    }

    // 创建进度显示UI
    dispatch_async(dispatch_get_main_queue(), ^{
        CGRect screenBounds = [UIScreen mainScreen].bounds;
        DYYYToast *progressView = [[DYYYToast alloc] initWithFrame:screenBounds];
        [progressView show];

        if ([progressView respondsToSelector:@selector(setCancelBlock:)]) {
            [progressView performSelector:@selector(setCancelBlock:) withObject:^{
          progressView.isCancelled = YES;
          [progressView dismiss];
          [self cancelAllDownloads];
          if (completion) {
              completion(0, livePhotos.count);
          }
            }];
        }

        NSMutableArray<NSDictionary *> *downloadedFiles = [NSMutableArray arrayWithCapacity:livePhotos.count];
        for (int i = 0; i < livePhotos.count; i++) {
            [downloadedFiles addObject:@{@"imageURL": livePhotos[i][@"imageURL"], 
                                        @"videoURL": livePhotos[i][@"videoURL"],
                                        @"imagePath": [NSNull null],
                                        @"videoPath": [NSNull null]}];
        }

        // 进度计算 - 为三个阶段分配权重
        NSInteger totalSteps = livePhotos.count * 10; // 每个实况照片总共10步(4+4+2)
        __block NSInteger completedSteps = 0;
        
        // 创建临时目录
        NSString *livePhotoPath = [[DYYYPaths tempDir] stringByAppendingPathComponent:@"LivePhotoBatch"];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        [fileManager createDirectoryAtPath:livePhotoPath withIntermediateDirectories:YES attributes:nil error:nil];

        // 更新进度的block
        void (^updateProgress)(NSString *)= ^(NSString *statusText){
            float progress = (float)completedSteps / totalSteps;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [progressView setProgress:progress];
                if (progressBlock) {
                    progressBlock(completedSteps, totalSteps);
                }
            });
        };

        // 下载完成后的处理
        void (^finishProcess)(void) = ^{
            __block NSInteger successCount = 0;
            
            // 请求相册权限
            [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
                if (status == PHAuthorizationStatusAuthorized) {

                    dispatch_queue_t processQueue = dispatch_queue_create("com.dyyy.livephoto.process", DISPATCH_QUEUE_SERIAL);
                    dispatch_group_t saveGroup = dispatch_group_create();
                    
                    NSInteger validFileCount = 0;
                    for (NSDictionary *fileInfo in downloadedFiles) {
                        NSString *imagePath = fileInfo[@"imagePath"];
                        NSString *videoPath = fileInfo[@"videoPath"];
                        
                        if (![imagePath isKindOfClass:[NSNull class]] && 
                            ![videoPath isKindOfClass:[NSNull class]] &&
                            [fileManager fileExistsAtPath:imagePath] && 
                            [fileManager fileExistsAtPath:videoPath]) {
                            validFileCount++;
                        }
                    }
                    
                    if (validFileCount == 0) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [progressView dismiss];
                            [fileManager removeItemAtPath:livePhotoPath error:nil];
                            if (completion) {
                                completion(0, livePhotos.count);
                            }
                        });
                        return;
                    }
                    
                    __block NSInteger processedCount = 0;
                    
                    for (NSDictionary *fileInfo in downloadedFiles) {
                        NSString *imagePath = fileInfo[@"imagePath"];
                        NSString *videoPath = fileInfo[@"videoPath"];
                        
                        if (![imagePath isKindOfClass:[NSNull class]] && 
                            ![videoPath isKindOfClass:[NSNull class]] &&
                            [fileManager fileExistsAtPath:imagePath] && 
                            [fileManager fileExistsAtPath:videoPath]) {
                            
                            dispatch_group_enter(saveGroup);
                            
                            dispatch_async(processQueue, ^{
                                // 生成唯一标识符
                                NSString *identifier = [NSUUID UUID].UUIDString;
                                
                                // 创建每个任务的专属实例变量，避免共享变量冲突
                                AVAssetReader *localReader = nil;
                                AVAssetWriter *localWriter = nil;
                                dispatch_queue_t localQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
                                dispatch_group_t localGroup = dispatch_group_create();
                                
                                // 处理照片和元数据
                                NSString *photoName = [imagePath lastPathComponent];
                                NSString *photoFile = [[DYYYManager shared] filePathFromTmp:photoName];
                                [[DYYYManager shared] addMetadataToPhoto:[NSURL fileURLWithPath:imagePath] 
                                                              outputFile:photoFile 
                                                             identifier:identifier];
                                
                                // 处理视频和元数据
                                NSString *videoName = [videoPath lastPathComponent];
                                NSString *videoFile = [[DYYYManager shared] filePathFromTmp:videoName];
                                
                                // 使用本地变量而非全局共享变量
                                [[DYYYManager shared] addMetadataToVideoWithLocalVars:[NSURL fileURLWithPath:videoPath]
                                                                          outputFile:videoFile
                                                                         identifier:identifier
                                                                           reader:&localReader
                                                                           writer:&localWriter
                                                                            queue:localQueue
                                                                            group:localGroup
                                                                         complete:^(BOOL success, NSString *photoFile, NSString *videoFile, NSError *error) {
                                    if (success) {
                                        NSURL *photo = [NSURL fileURLWithPath:photoFile];
                                        NSURL *video = [NSURL fileURLWithPath:videoFile];
                                        
                                        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                                            PHAssetCreationRequest *request = [PHAssetCreationRequest creationRequestForAsset];
                                            [request addResourceWithType:PHAssetResourceTypePhoto fileURL:photo options:nil];
                                            [request addResourceWithType:PHAssetResourceTypePairedVideo fileURL:video options:nil];
                                        } completionHandler:^(BOOL success, NSError *_Nullable error) {
                                            if (success) {
                                                successCount++;
                                            }
                                            
                                            NSArray *filesToDelete = @[imagePath, videoPath, photoFile, videoFile];
                                            for (NSString *path in filesToDelete) {
                                                [fileManager removeItemAtPath:path error:nil];
                                            }
                                            
                                            // 增加进度步数
                                            processedCount++;
                                            completedSteps += 2; // 每完成一个合成任务增加2步
                                            updateProgress([NSString stringWithFormat:@"已合成 %ld/%ld", (long)processedCount, (long)validFileCount]);
                                            
                                            dispatch_group_leave(saveGroup);
                                        }];
                                    } else {
                                        [fileManager removeItemAtPath:imagePath error:nil];
                                        [fileManager removeItemAtPath:videoPath error:nil];
                                        if (photoFile) [fileManager removeItemAtPath:photoFile error:nil];
                                        if (videoFile) [fileManager removeItemAtPath:videoFile error:nil];
                                        
                                        // 增加进度步数（即使失败也增加）
                                        processedCount++;
                                        completedSteps += 2;
                                        updateProgress([NSString stringWithFormat:@"已合成 %ld/%ld", (long)processedCount, (long)validFileCount]);
                                        
                                        dispatch_group_leave(saveGroup);
                                    }
                                }];
                            });
                        }
                    }
                    
                    dispatch_group_notify(saveGroup, dispatch_get_main_queue(), ^{
                        progressView.allowSuccessAnimation = (successCount > 0);
                        [progressView dismiss];
                        
                        [fileManager removeItemAtPath:livePhotoPath error:nil];
                        
                        if (completion) {
                            completion(successCount, livePhotos.count);
                        }
                    });
                } else {
                    // 没有相册权限
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [progressView dismiss];
                        [self showToast:@"没有相册权限，无法保存实况照片"];
                        
                        [fileManager removeItemAtPath:livePhotoPath error:nil];
                        
                        if (completion) {
                            completion(0, livePhotos.count);
                        }
                    });
                }
            }];
        };

        // 第一阶段：批量下载所有图片
        dispatch_group_t imageDownloadGroup = dispatch_group_create();
        updateProgress(@"正在下载图片...");
        
        for (NSInteger i = 0; i < livePhotos.count; i++) {
            NSDictionary *livePhoto = downloadedFiles[i];
            NSString *imageURLString = livePhoto[@"imageURL"];
            NSURL *imageURL = [NSURL URLWithString:imageURLString];
            
            if (!imageURL) {
                completedSteps += 4; // 图片下载占4步
                continue;
            }
            
            dispatch_group_enter(imageDownloadGroup);
            
            // 创建文件路径
            NSString *uniqueID = [NSUUID UUID].UUIDString;
            NSString *imagePath = [livePhotoPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.heic", uniqueID]];
            
            // 配置下载会话
            NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
            configuration.timeoutIntervalForRequest = 60.0;
            NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
            
            NSURLSessionDataTask *imageTask = [session dataTaskWithURL:imageURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                if (!error && data) {
                    if ([data writeToFile:imagePath atomically:YES]) {
                        NSMutableDictionary *updatedInfo = [downloadedFiles[i] mutableCopy];
                        updatedInfo[@"imagePath"] = imagePath;
                        downloadedFiles[i] = updatedInfo;
                    }
                }
                
                completedSteps += 4; // 图片下载占4步
                updateProgress([NSString stringWithFormat:@"已下载图片 %ld/%ld", (long)(i+1), (long)livePhotos.count]);
                dispatch_group_leave(imageDownloadGroup);
            }];
            
            [imageTask resume];
        }
        
        // 所有图片下载完成后，开始下载视频
        dispatch_group_notify(imageDownloadGroup, dispatch_get_main_queue(), ^{
            updateProgress(@"正在下载视频...");
            
            dispatch_group_t videoDownloadGroup = dispatch_group_create();
            
            for (NSInteger i = 0; i < livePhotos.count; i++) {
                NSDictionary *fileInfo = downloadedFiles[i];
                
                // 只处理图片下载成功的项
                if ([fileInfo[@"imagePath"] isKindOfClass:[NSNull class]]) {
                    completedSteps += 4; // 视频下载占4步
                    continue;
                }
                
                NSString *videoURLString = fileInfo[@"videoURL"];
                NSURL *videoURL = [NSURL URLWithString:videoURLString];
                
                if (!videoURL) {
                    completedSteps += 4; // 视频下载占4步
                    continue;
                }
                
                dispatch_group_enter(videoDownloadGroup);
                
                // 使用与图片相同的ID但不同的扩展名
                NSString *imagePath = fileInfo[@"imagePath"];
                NSString *baseName = [[imagePath lastPathComponent] stringByDeletingPathExtension];
                NSString *videoPath = [livePhotoPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.mp4", baseName]];
                
                // 配置下载会话
                NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
                configuration.timeoutIntervalForRequest = 60.0;
                NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
                
                NSURLSessionDataTask *videoTask = [session dataTaskWithURL:videoURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                    if (!error && data) {
                        if ([data writeToFile:videoPath atomically:YES]) {
                            NSMutableDictionary *updatedInfo = [downloadedFiles[i] mutableCopy];
                            updatedInfo[@"videoPath"] = videoPath;
                            downloadedFiles[i] = updatedInfo;
                        }
                    }
                    
                    completedSteps += 4; // 视频下载占4步
                    updateProgress([NSString stringWithFormat:@"已下载视频 %ld/%ld", (long)(i+1), (long)livePhotos.count]);
                    dispatch_group_leave(videoDownloadGroup);
                }];
                
                [videoTask resume];
            }
            
            // 所有视频下载完成后，开始合成实况照片
            dispatch_group_notify(videoDownloadGroup, dispatch_get_main_queue(), ^{
                finishProcess();
            });
        });
    });
}

// 使用本地变量处理视频
- (void)addMetadataToVideoWithLocalVars:(NSURL *)videoURL
                             outputFile:(NSString *)outputFile
                            identifier:(NSString *)identifier
                                reader:(AVAssetReader **)readerPtr
                                writer:(AVAssetWriter **)writerPtr
                                 queue:(dispatch_queue_t)workQueue
                                 group:(dispatch_group_t)workGroup
                              complete:(void (^)(BOOL success, NSString *photoFile, NSString *videoFile, NSError *error))complete {
    NSError *error = nil;
    AVAsset *videoAsset = [AVAsset assetWithURL:videoURL];
    AVAssetReader *assetReader = [AVAssetReader assetReaderWithAsset:videoAsset error:&error];
    if (error) {
        if (complete) complete(NO, nil, nil, error);
        return;
    }
    
    *readerPtr = assetReader;
    
    NSMutableArray<AVMetadataItem *> *metadata = videoAsset.metadata.mutableCopy;
    AVMetadataItem *item = [self createContentIdentifierMetadataItem:identifier];
    [metadata addObject:item];
    NSURL *videoFileURL = [NSURL fileURLWithPath:outputFile];
    [self deleteFile:outputFile];
    
    AVAssetWriter *assetWriter = [AVAssetWriter assetWriterWithURL:videoFileURL fileType:AVFileTypeQuickTimeMovie error:&error];
    if (error) {
        if (complete) complete(NO, nil, nil, error);
        return;
    }
    
    *writerPtr = assetWriter;
    [assetWriter setMetadata:metadata];
    
    NSArray<AVAssetTrack *> *tracks = [videoAsset tracks];
    for (AVAssetTrack *track in tracks) {
        NSDictionary *readerOutputSettings = nil;
        NSDictionary *writerOuputSettings = nil;
        if ([track.mediaType isEqualToString:AVMediaTypeAudio]) {
            readerOutputSettings = @{AVFormatIDKey : @(kAudioFormatLinearPCM)};
            writerOuputSettings = @{
                AVFormatIDKey : @(kAudioFormatMPEG4AAC),
                AVSampleRateKey : @(44100),
                AVNumberOfChannelsKey : @(2),
                AVEncoderBitRateKey : @(128000)
            };
        }
        
        AVAssetReaderTrackOutput *output = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:track outputSettings:readerOutputSettings];
        AVAssetWriterInput *input = [AVAssetWriterInput assetWriterInputWithMediaType:track.mediaType outputSettings:writerOuputSettings];
        
        if ([assetReader canAddOutput:output] && [assetWriter canAddInput:input]) {
            [assetReader addOutput:output];
            [assetWriter addInput:input];
        }
    }
    
    AVAssetWriterInput *input = [self createStillImageTimeAssetWriterInput];
    AVAssetWriterInputMetadataAdaptor *adaptor = [AVAssetWriterInputMetadataAdaptor assetWriterInputMetadataAdaptorWithAssetWriterInput:input];
    if ([assetWriter canAddInput:input]) {
        [assetWriter addInput:input];
    }
    
    [assetWriter startWriting];
    [assetWriter startSessionAtSourceTime:kCMTimeZero];
    [assetReader startReading];
    
    AVMetadataItem *timedItem = [self createStillImageTimeMetadataItem];
    CMTimeRange timedRange = CMTimeRangeMake(kCMTimeZero, CMTimeMake(1, 100));
    AVTimedMetadataGroup *timedMetadataGroup = [[AVTimedMetadataGroup alloc] initWithItems:@[ timedItem ] timeRange:timedRange];
    [adaptor appendTimedMetadataGroup:timedMetadataGroup];
    
    for (NSInteger i = 0; i < assetReader.outputs.count; ++i) {
        dispatch_group_enter(workGroup);
        [self writeTrackWithLocalVars:i reader:assetReader writer:assetWriter queue:workQueue group:workGroup];
    }
    
    dispatch_group_notify(workGroup, dispatch_get_main_queue(), ^{
        [assetReader cancelReading];
        [assetWriter finishWritingWithCompletionHandler:^{
            AVAssetWriterStatus status = assetWriter.status;
            if (status == AVAssetWriterStatusCompleted) {
                NSString *photoName = [[videoURL lastPathComponent] stringByDeletingPathExtension];
                NSString *photoFile = [self filePathFromTmp:[photoName stringByAppendingPathExtension:@"heic"]];
                if (complete) complete(YES, photoFile, outputFile, nil);
            } else {
                if (complete) complete(NO, nil, nil, assetWriter.error);
            }
        }];
    });
}

// 处理视频曲目的写入
- (void)writeTrackWithLocalVars:(NSInteger)trackIndex 
                         reader:(AVAssetReader *)assetReader
                         writer:(AVAssetWriter *)assetWriter
                          queue:(dispatch_queue_t)workQueue
                          group:(dispatch_group_t)workGroup {
    AVAssetReaderOutput *output = assetReader.outputs[trackIndex];
    AVAssetWriterInput *input = assetWriter.inputs[trackIndex];

    [input requestMediaDataWhenReadyOnQueue:workQueue usingBlock:^{
        while (input.readyForMoreMediaData) {
            AVAssetReaderStatus status = assetReader.status;
            CMSampleBufferRef buffer = NULL;
            if ((status == AVAssetReaderStatusReading) && (buffer = [output copyNextSampleBuffer])) {
                BOOL success = [input appendSampleBuffer:buffer];
                CFRelease(buffer);
                if (!success) {
                    [input markAsFinished];
                    dispatch_group_leave(workGroup);
                    return;
                }
            } else {
                [input markAsFinished];
                dispatch_group_leave(workGroup);
                return;
            }
        }
    }];
}

+ (void)parseAndDownloadVideoWithShareLink:(NSString *)shareLink
                                    apiKey:(NSString *)apiKey {
  if (shareLink.length == 0 || apiKey.length == 0) {
    [self showToast:@"分享链接或API密钥无效"];
    return;
  }

  NSString *apiUrl = [NSString
      stringWithFormat:@"%@%@", apiKey,
                       [shareLink
                           stringByAddingPercentEncodingWithAllowedCharacters:
                               [NSCharacterSet URLQueryAllowedCharacterSet]]];

  NSURL *url = [NSURL URLWithString:apiUrl];
  NSURLRequest *request = [NSURLRequest requestWithURL:url];
  NSURLSession *session = [NSURLSession sharedSession];

  NSURLSessionDataTask *dataTask = [session
      dataTaskWithRequest:request
        completionHandler:^(NSData *data, NSURLResponse *response,
                            NSError *error) {
          dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
              [self showToast:[NSString
                                  stringWithFormat:@"接口请求失败: %@",
                                                   error.localizedDescription]];
              return;
            }

            NSError *jsonError;
            NSDictionary *json =
                [NSJSONSerialization JSONObjectWithData:data
                                                options:0
                                                  error:&jsonError];
            if (jsonError) {
              [self showToast:@"解析接口返回数据失败"];
              return;
            }

            NSInteger code = [json[@"code"] integerValue];
            if (code != 0 && code != 200) {
              [self showToast:[NSString stringWithFormat:@"接口返回错误: %@",
                                                         json[@"msg"]
                                                             ?: @"未知错误"]];
              return;
            }

            NSDictionary *dataDict = json[@"data"];
            if (!dataDict) {
              [self showToast:@"接口返回数据为空"];
              return;
            }
            NSArray *videos = dataDict[@"videos"];
            NSArray *images = dataDict[@"images"];
            NSArray *videoList = dataDict[@"video_list"];
            BOOL hasVideos =
                [videos isKindOfClass:[NSArray class]] && videos.count > 0;
            BOOL hasImages =
                [images isKindOfClass:[NSArray class]] && images.count > 0;
            BOOL hasVideoList = [videoList isKindOfClass:[NSArray class]] &&
                                videoList.count > 0;
            BOOL shouldShowQualityOptions =
                [[NSUserDefaults standardUserDefaults]
                    boolForKey:@"DYYYShowAllVideoQuality"];

            // 如果启用了显示清晰度选项，并且存在 videoList，则弹出选择面板
            if (shouldShowQualityOptions && hasVideoList) {
              AWEUserActionSheetView *actionSheet =
                  [[NSClassFromString(@"AWEUserActionSheetView") alloc] init];
              NSMutableArray *actions = [NSMutableArray array];

              for (NSDictionary *videoDict in videoList) {
                NSString *url = videoDict[@"url"];
                NSString *level = videoDict[@"level"];
                if (url.length > 0 && level.length > 0) {
                  AWEUserSheetAction *qualityAction = [NSClassFromString(
                      @"AWEUserSheetAction")
                      actionWithTitle:level
                              imgName:nil
                              handler:^{
                                NSURL *videoDownloadUrl =
                                    [NSURL URLWithString:url];
                                [self
                                    downloadMedia:videoDownloadUrl
                                        mediaType:MediaTypeVideo
                                       completion:^(BOOL success) {
                                         if (success) {
                                         } else {
                                           [self showToast:
                                                     [NSString
                                                         stringWithFormat:
                                                             @"已取消保存 (%@)",
                                                             level]];
                                         }
                                       }];
                              }];
                  [actions addObject:qualityAction];
                }
              }

              // 附加批量下载选项（如果开启清晰度选项 + 有视频/图片）
              if (hasVideos || hasImages) {
                AWEUserSheetAction *batchDownloadAction =
                    [NSClassFromString(@"AWEUserSheetAction")
                        actionWithTitle:@"批量下载所有资源"
                                imgName:nil
                                handler:^{
                                  [self batchDownloadResources:videos
                                                        images:images];
                                }];
                [actions addObject:batchDownloadAction];
              }

              if (actions.count > 0) {
                [actionSheet setActions:actions];
                [actionSheet show];
                return;
              }
            }

            // 如果未开启清晰度选项，但有 video_list，自动下载第一个清晰度
            if (!shouldShowQualityOptions && hasVideoList) {
              NSDictionary *firstVideo = videoList.firstObject;
              NSString *url = firstVideo[@"url"];
              NSString *level = firstVideo[@"level"] ?: @"默认清晰度";

              if (url.length > 0) {
                NSURL *videoDownloadUrl = [NSURL URLWithString:url];
                [self downloadMedia:videoDownloadUrl
                          mediaType:MediaTypeVideo
                         completion:^(BOOL success) {
                           if (success) {
                           } else {
                             [self showToast:[NSString stringWithFormat:
                                                           @"已取消保存 (%@)",
                                                           level]];
                           }
                         }];
                return;
              }
            }

            [self batchDownloadResources:videos images:images];
          });
        }];

  [dataTask resume];
}

+ (void)batchDownloadResources:(NSArray *)videos images:(NSArray *)images {
  BOOL hasVideos = [videos isKindOfClass:[NSArray class]] && videos.count > 0;
  BOOL hasImages = [images isKindOfClass:[NSArray class]] && images.count > 0;

  NSMutableArray<id> *videoFiles =
      [NSMutableArray arrayWithCapacity:videos.count];
  NSMutableArray<id> *imageFiles =
      [NSMutableArray arrayWithCapacity:images.count];
  for (NSInteger i = 0; i < videos.count; i++)
    [videoFiles addObject:[NSNull null]];
  for (NSInteger i = 0; i < images.count; i++)
    [imageFiles addObject:[NSNull null]];

  dispatch_group_t downloadGroup = dispatch_group_create();

  if (hasVideos) {
    for (NSInteger i = 0; i < videos.count; i++) {
      NSDictionary *videoDict = videos[i];
      NSString *videoUrl = videoDict[@"url"];
      if (videoUrl.length == 0) {
        continue;
      }
      dispatch_group_enter(downloadGroup);
      NSURL *videoDownloadUrl = [NSURL URLWithString:videoUrl];
      [self downloadMediaWithProgress:videoDownloadUrl
                            mediaType:MediaTypeVideo
                             progress:nil
                           completion:^(BOOL success, NSURL *fileURL) {
                             if (success && fileURL) {
                               @synchronized(videoFiles) {
                                 videoFiles[i] = fileURL;
                               }
                             }
                             dispatch_group_leave(downloadGroup);
                           }];
    }
  }

  if (hasImages) {
    for (NSInteger i = 0; i < images.count; i++) {
      NSString *imageUrl = images[i];
      if (imageUrl.length == 0) {
        continue;
      }
      dispatch_group_enter(downloadGroup);
      NSURL *imageDownloadUrl = [NSURL URLWithString:imageUrl];
      [self downloadMediaWithProgress:imageDownloadUrl
                            mediaType:MediaTypeImage
                             progress:nil
                           completion:^(BOOL success, NSURL *fileURL) {
                             if (success && fileURL) {
                               @synchronized(imageFiles) {
                                 imageFiles[i] = fileURL;
                               }
                             }
                             dispatch_group_leave(downloadGroup);
                           }];
    }
  }

  dispatch_group_notify(downloadGroup, dispatch_get_main_queue(), ^{
    for (id file in videoFiles) {
      if ([file isKindOfClass:[NSURL class]]) {
        [self saveMedia:(NSURL *)file mediaType:MediaTypeVideo completion:nil];
      }
    }

    for (id file in imageFiles) {
      if ([file isKindOfClass:[NSURL class]]) {
        [self saveMedia:(NSURL *)file mediaType:MediaTypeImage completion:nil];
      }
    }
  });
}

@end
