#import "DYYYManagerPrivate.h"
#import "DYYYToast.h"
#import "DYYYUtils.h"
#import "DYYYPaths.h"

@implementation DYYYManager (Compose)

#define DYYYLogVideo(format, ...) NSLog((@"[DYYY视频合成] " format), ##__VA_ARGS__)
// 创建视频合成器从多种媒体源
+ (void)createVideoFromMedia:(NSArray<NSString *> *)imageURLs
                  livePhotos:(NSArray<NSDictionary *> *)livePhotos
                      bgmURL:(NSString *)bgmURL
                    progress:(void (^)(NSInteger current, NSInteger total, NSString *status))progressBlock
                  completion:(void (^)(BOOL success, NSString *message))completion {
    DYYYLogVideo(@"开始创建视频 - 图片数量: %lu, 实况照片数量: %lu, 背景音乐: %@", 
                (unsigned long)imageURLs.count, 
                (unsigned long)livePhotos.count, 
                bgmURL.length > 0 ? @"有" : @"无");
                
    if ((imageURLs.count == 0 && livePhotos.count == 0) || 
        (imageURLs == nil && livePhotos == nil)) {
        DYYYLogVideo(@"错误: 没有提供媒体资源");
        if (completion) {
            completion(NO, @"没有提供媒体资源");
        }
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        CGRect screenBounds = [UIScreen mainScreen].bounds;
        DYYYToast *progressView = [[DYYYToast alloc] initWithFrame:screenBounds];
        [progressView show];
        
        progressView.cancelBlock = ^{
            DYYYLogVideo(@"用户取消了视频合成");
            [self cancelAllDownloads];
            if (completion) {
                completion(NO, @"用户取消了操作");
            }
        };
        
        // 创建临时目录
        NSString *mediaPath = [[DYYYPaths tempDir] stringByAppendingPathComponent:@"VideoComposition"];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if ([fileManager fileExistsAtPath:mediaPath]) {
            DYYYLogVideo(@"正在清理旧的临时目录: %@", mediaPath);
            [fileManager removeItemAtPath:mediaPath error:nil];
        }
        
        NSError *dirError = nil;
        [fileManager createDirectoryAtPath:mediaPath withIntermediateDirectories:YES attributes:nil error:&dirError];
        if (dirError) {
            DYYYLogVideo(@"创建临时目录失败: %@", dirError);
            if (completion) {
                completion(NO, @"创建临时文件夹失败");
            }
            return;
        }
        DYYYLogVideo(@"成功创建临时目录: %@", mediaPath);
        
        // 计算总共需要下载的文件数和合成步骤
        NSInteger totalImages = imageURLs.count;
        NSInteger totalLivePhotos = livePhotos.count * 2; // 每个实况照片有2个文件
        NSInteger hasBGM = (bgmURL.length > 0) ? 1 : 0;
        
        // 总步骤：下载所有媒体 + 合成视频 + 保存视频
        NSInteger totalSteps = totalImages + totalLivePhotos + hasBGM + 2;
        __block NSInteger completedSteps = 0;
        
        // 储存下载的媒体文件路径
        NSMutableArray *imageFilePaths = [NSMutableArray array];
        NSMutableArray<NSDictionary *> *livePhotoFilePaths = [NSMutableArray array];
        __block NSString *bgmFilePath = nil;
        
        void (^updateProgress)(NSString *) = ^(NSString *status) {
            float progress = (float)completedSteps / totalSteps;
            dispatch_async(dispatch_get_main_queue(), ^{
                [progressView setProgress:progress];
                DYYYLogVideo(@"进度更新: %.2f%% - %@", progress * 100, status);
                if (progressBlock) {
                    progressBlock(completedSteps, totalSteps, status);
                }
            });
        };
        
        // 第一阶段：下载所有普通图片
        dispatch_group_t imageDownloadGroup = dispatch_group_create();
        updateProgress(@"正在下载图片...");

        for (NSInteger i = 0; i < imageURLs.count; i++) {
            NSString *imageURLString = imageURLs[i];
            NSURL *imageURL = [NSURL URLWithString:imageURLString];
            
            if (!imageURL) {
                DYYYLogVideo(@"图片URL无效: %@", imageURLString);
                completedSteps++;
                updateProgress(@"图片URL无效");
                continue;
            }
            
            dispatch_group_enter(imageDownloadGroup);
            
            // 创建文件路径
            NSString *uniqueID = [NSUUID UUID].UUIDString;
            NSString *imagePath = [mediaPath stringByAppendingPathComponent:[NSString stringWithFormat:@"image_%@.jpg", uniqueID]];
            DYYYLogVideo(@"开始下载图片 %ld/%ld: %@", (long)(i+1), (long)imageURLs.count, imageURLString);
            
            // 配置下载会话
            NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
            NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
            
            NSURLSessionDataTask *imageTask = [session dataTaskWithURL:imageURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                if (error) {
                    DYYYLogVideo(@"下载图片失败 %ld/%ld: %@", (long)(i+1), (long)imageURLs.count, error);
                } else if (!data) {
                    DYYYLogVideo(@"下载图片数据为空 %ld/%ld", (long)(i+1), (long)imageURLs.count);
                } else {
                    NSInteger dataSize = data.length;
                    if ([data writeToFile:imagePath atomically:YES]) {
                        DYYYLogVideo(@"成功下载并保存图片 %ld/%ld: %@ (大小: %.2f KB)", 
                                   (long)(i+1), (long)imageURLs.count, imagePath, dataSize/1024.0);
                        [imageFilePaths addObject:imagePath];
                    } else {
                        DYYYLogVideo(@"保存图片文件失败 %ld/%ld: %@", (long)(i+1), (long)imageURLs.count, imagePath);
                    }
                }
                
                completedSteps++;
                updateProgress([NSString stringWithFormat:@"已下载图片 %ld/%ld", (long)(i+1), (long)imageURLs.count]);
                dispatch_group_leave(imageDownloadGroup);
            }];
            
            [imageTask resume];
        }
        
        // 第二阶段：下载所有实况照片
        dispatch_group_t livePhotoDownloadGroup = dispatch_group_create();
        
        dispatch_group_notify(imageDownloadGroup, dispatch_get_main_queue(), ^{
            DYYYLogVideo(@"第一阶段完成，已下载 %ld 张图片", (long)imageFilePaths.count);
            updateProgress(@"正在下载实况照片...");
            DYYYLogVideo(@"开始第二阶段: 下载实况照片 (%ld 项)", (long)livePhotos.count);
            
            for (NSInteger i = 0; i < livePhotos.count; i++) {
                NSDictionary *livePhoto = livePhotos[i];
                NSString *imageURLString = livePhoto[@"imageURL"];
                NSString *videoURLString = livePhoto[@"videoURL"];
                NSURL *imageURL = [NSURL URLWithString:imageURLString];
                NSURL *videoURL = [NSURL URLWithString:videoURLString];
                
                if (!imageURL || !videoURL) {
                    DYYYLogVideo(@"实况照片URL无效: 图片=%@, 视频=%@", imageURLString, videoURLString);
                    completedSteps += 2;
                    updateProgress(@"实况照片URL无效");
                    continue;
                }
                
                NSString *uniqueID = [NSUUID UUID].UUIDString;
                NSString *imagePath = [mediaPath stringByAppendingPathComponent:[NSString stringWithFormat:@"livephoto_img_%@.jpg", uniqueID]];
                NSString *videoPath = [mediaPath stringByAppendingPathComponent:[NSString stringWithFormat:@"livephoto_vid_%@.mp4", uniqueID]];
                
                // 下载图片部分
                dispatch_group_enter(livePhotoDownloadGroup);
                NSURLSessionConfiguration *imgConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
                NSURLSession *imgSession = [NSURLSession sessionWithConfiguration:imgConfig];
                
                DYYYLogVideo(@"开始下载实况照片图片部分 %ld/%ld: %@", (long)(i+1), (long)livePhotos.count, imageURLString);
                NSURLSessionDataTask *imageTask = [imgSession dataTaskWithURL:imageURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                    if (error) {
                        DYYYLogVideo(@"下载实况照片图片部分失败 %ld/%ld: %@", (long)(i+1), (long)livePhotos.count, error);
                    } else if (!data) {
                        DYYYLogVideo(@"下载实况照片图片数据为空 %ld/%ld", (long)(i+1), (long)livePhotos.count);
                    } else if ([data writeToFile:imagePath atomically:YES]) {
                        DYYYLogVideo(@"成功保存实况照片图片部分 %ld/%ld: %@ (大小: %.2f KB)", 
                                   (long)(i+1), (long)livePhotos.count, imagePath, data.length/1024.0);
                    } else {
                        DYYYLogVideo(@"保存实况照片图片文件失败 %ld/%ld: %@", (long)(i+1), (long)livePhotos.count, imagePath);
                    }
                    
                    completedSteps++;
                    updateProgress([NSString stringWithFormat:@"已下载实况照片(图片) %ld/%ld", (long)(i+1), (long)livePhotos.count]);
                    dispatch_group_leave(livePhotoDownloadGroup);
                }];
                
                // 下载视频部分
                dispatch_group_enter(livePhotoDownloadGroup);
                NSURLSessionConfiguration *vidConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
                NSURLSession *vidSession = [NSURLSession sessionWithConfiguration:vidConfig];
                
                DYYYLogVideo(@"开始下载实况照片视频部分 %ld/%ld: %@", (long)(i+1), (long)livePhotos.count, videoURLString);
                NSURLSessionDataTask *videoTask = [vidSession dataTaskWithURL:videoURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                    if (error) {
                        DYYYLogVideo(@"下载实况照片视频部分失败 %ld/%ld: %@", (long)(i+1), (long)livePhotos.count, error);
                    } else if (!data) {
                        DYYYLogVideo(@"下载实况照片视频数据为空 %ld/%ld", (long)(i+1), (long)livePhotos.count);
                    } else if ([data writeToFile:videoPath atomically:YES]) {
                        DYYYLogVideo(@"成功保存实况照片视频部分 %ld/%ld: %@ (大小: %.2f MB)", 
                                   (long)(i+1), (long)livePhotos.count, videoPath, data.length/(1024.0*1024.0));
                        @synchronized(livePhotoFilePaths) {
                            [livePhotoFilePaths addObject:@{
                                @"image": imagePath,
                                @"video": videoPath
                            }];
                            DYYYLogVideo(@"成功记录实况照片对: 图片=%@, 视频=%@", imagePath, videoPath);
                        }
                    } else {
                        DYYYLogVideo(@"保存实况照片视频文件失败 %ld/%ld: %@", (long)(i+1), (long)livePhotos.count, videoPath);
                    }
                    
                    completedSteps++;
                    updateProgress([NSString stringWithFormat:@"已下载实况照片(视频) %ld/%ld", (long)(i+1), (long)livePhotos.count]);
                    dispatch_group_leave(livePhotoDownloadGroup);
                }];
                
                [imageTask resume];
                [videoTask resume];
            }
            
            // 第三阶段：下载背景音乐
            dispatch_group_t bgmDownloadGroup = dispatch_group_create();
            
            dispatch_group_notify(livePhotoDownloadGroup, dispatch_get_main_queue(), ^{
                DYYYLogVideo(@"第二阶段完成，已下载 %ld 组实况照片", (long)livePhotoFilePaths.count);
                
                if (bgmURL.length > 0) {
                    DYYYLogVideo(@"开始第三阶段: 下载背景音乐 %@", bgmURL);
                    updateProgress(@"正在下载背景音乐...");
                    NSURL *bgmURL_obj = [NSURL URLWithString:bgmURL];
                    
                    if (!bgmURL_obj) {
                        DYYYLogVideo(@"背景音乐URL无效: %@", bgmURL);
                        completedSteps++;
                        updateProgress(@"背景音乐URL无效");
                    } else {
                        dispatch_group_enter(bgmDownloadGroup);
                        
                        // 创建文件路径
                        NSString *uniqueID = [NSUUID UUID].UUIDString;
                        NSString *audioPath = [mediaPath stringByAppendingPathComponent:[NSString stringWithFormat:@"bgm_%@.mp3", uniqueID]];
                        
                        // 配置下载会话
                        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
                        NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
                        
                        NSURLSessionDataTask *audioTask = [session dataTaskWithURL:bgmURL_obj completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                            if (error) {
                                DYYYLogVideo(@"下载背景音乐失败: %@", error);
                            } else if (!data) {
                                DYYYLogVideo(@"下载背景音乐数据为空");
                            } else if ([data writeToFile:audioPath atomically:YES]) {
                                DYYYLogVideo(@"成功保存背景音乐: %@ (大小: %.2f MB)", audioPath, data.length/(1024.0*1024.0));
                                bgmFilePath = audioPath;
                            } else {
                                DYYYLogVideo(@"保存背景音乐文件失败: %@", audioPath);
                            }
                            
                            completedSteps++;
                            updateProgress(@"背景音乐下载完成");
                            dispatch_group_leave(bgmDownloadGroup);
                        }];
                        
                        [audioTask resume];
                    }
                }
                
                // 第四阶段：合成视频
                dispatch_group_notify(bgmDownloadGroup, dispatch_get_main_queue(), ^{
                    DYYYLogVideo(@"第三阶段完成，背景音乐状态: %@", bgmFilePath ? @"已下载" : @"无或下载失败");
                    DYYYLogVideo(@"开始第四阶段: 合成视频");
                    updateProgress(@"正在合成视频...");
                    
                    // 如果没有成功下载任何媒体，则退出
                    if (imageFilePaths.count == 0 && livePhotoFilePaths.count == 0) {
                        DYYYLogVideo(@"错误: 没有成功下载任何媒体文件，取消合成");
                        [progressView dismiss];
                        if (completion) {
                            completion(NO, @"没有成功下载任何媒体文件");
                        }
                        [fileManager removeItemAtPath:mediaPath error:nil];
                        return;
                    }
                    
                    DYYYLogVideo(@"媒体文件统计: %ld张图片, %ld组实况照片, 背景音乐: %@", 
                               (long)imageFilePaths.count, 
                               (long)livePhotoFilePaths.count, 
                               bgmFilePath ? @"有" : @"无");
                    
                    NSString *outputPath = [mediaPath stringByAppendingPathComponent:[NSString stringWithFormat:@"final_%@.mp4", [NSUUID UUID].UUIDString]];
                    DYYYLogVideo(@"视频输出路径: %@", outputPath);
                    
                    // 使用AVFoundation合成视频
                    [self composeVideo:imageFilePaths 
                           livePhotos:livePhotoFilePaths 
                           bgmPath:bgmFilePath 
                           outputPath:outputPath 
                           completion:^(BOOL success) {
                        completedSteps++;
                        if (success) {
                            DYYYLogVideo(@"视频合成成功");
                        } else {
                            DYYYLogVideo(@"视频合成失败");
                        }
                        updateProgress(@"视频合成完成");
                        
                        if (success) {
                            DYYYLogVideo(@"开始保存视频到相册");
                            [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                                [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:[NSURL fileURLWithPath:outputPath]];
                            } completionHandler:^(BOOL success, NSError * _Nullable error) {
                                completedSteps++;
                                
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    progressView.allowSuccessAnimation = success;
                                    [progressView dismiss];
                                    
                                    if (success) {
                                        DYYYLogVideo(@"视频已成功保存到相册");
                                        if (completion) {
                                            completion(YES, @"视频已成功保存到相册");
                                        }
                                    } else {
                                        DYYYLogVideo(@"保存视频到相册失败: %@", error);
                                        if (completion) {
                                            completion(NO, [NSString stringWithFormat:@"保存视频到相册失败: %@", error.localizedDescription]);
                                        }
                                    }
                                    
                                    DYYYLogVideo(@"清理临时文件: %@", mediaPath);
                                    [fileManager removeItemAtPath:mediaPath error:nil];
                                });
                            }];
                        } else {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [progressView dismiss];
                                if (completion) {
                                    completion(NO, @"视频合成失败");
                                }
                                
                                DYYYLogVideo(@"清理临时文件: %@", mediaPath);
                                [fileManager removeItemAtPath:mediaPath error:nil];
                            });
                        }
                    }];
                });
            });
        });
    });
}

// 视频合成核心方法
+ (void)composeVideo:(NSArray<NSString *> *)imageFiles
          livePhotos:(NSArray<NSDictionary *> *)livePhotoFiles
             bgmPath:(NSString *)bgmPath
          outputPath:(NSString *)outputPath
          completion:(void (^)(BOOL success))completion {
    // 视频尺寸（标准1080p）
    CGSize videoSize = CGSizeMake(1080, 1920);
    DYYYLogVideo(@"开始合成视频 - 目标尺寸: %.0fx%.0f", videoSize.width, videoSize.height);
    DYYYLogVideo(@"媒体源: %ld张图片, %ld组实况照片, 背景音乐: %@", 
               (long)imageFiles.count, (long)livePhotoFiles.count, bgmPath ? @"有" : @"无");
    
    dispatch_group_t processingGroup = dispatch_group_create();
    
    // 存储所有媒体片段信息
    NSMutableArray *mediaSegments = [NSMutableArray array];
    
    // 处理静态图片 - 先将所有图片转换为临时视频片段
    for (NSInteger i = 0; i < imageFiles.count; i++) {
        NSString *imagePath = imageFiles[i];
        if (![[NSFileManager defaultManager] fileExistsAtPath:imagePath]) {
            DYYYLogVideo(@"错误: 图片文件不存在: %@", imagePath);
            continue;
        }
        
        UIImage *image = [UIImage imageWithContentsOfFile:imagePath];
        if (!image) {
            DYYYLogVideo(@"错误: 无法加载图片: %@", imagePath);
            continue;
        }
        DYYYLogVideo(@"处理图片 %ld/%ld: 尺寸 %.0fx%.0f", 
                   (long)(i+1), (long)imageFiles.count, image.size.width, image.size.height);
        
        // 创建临时视频文件路径
        NSString *tempVideoPath = [[DYYYPaths tempDir] stringByAppendingPathComponent:
                                  [NSString stringWithFormat:@"temp_img_%@.mp4", [NSUUID UUID].UUIDString]];
        
        dispatch_group_enter(processingGroup);
        
        // 使用Core Animation创建静态图片视频
        [self createVideoFromImage:image duration:5.0 outputPath:tempVideoPath completion:^(BOOL success) {
            if (success) {
                @synchronized(mediaSegments) {
                    [mediaSegments addObject:@{
                        @"type": @"image",
                        @"path": tempVideoPath,
                        @"duration": @5.0
                    }];
                    DYYYLogVideo(@"成功创建图片视频片段 %ld/%ld: %@", 
                               (long)(i+1), (long)imageFiles.count, tempVideoPath);
                }
            } else {
                DYYYLogVideo(@"错误: 创建图片视频片段失败 %ld/%ld", (long)(i+1), (long)imageFiles.count);
            }
            dispatch_group_leave(processingGroup);
        }];
    }
    
    // 处理实况照片 - 收集所有视频路径信息
    for (NSInteger i = 0; i < livePhotoFiles.count; i++) {
        NSDictionary *livePhoto = livePhotoFiles[i];
        NSString *imagePath = livePhoto[@"image"];
        NSString *videoPath = livePhoto[@"video"];
        
        DYYYLogVideo(@"处理实况照片 %ld/%ld: 图片=%@, 视频=%@", 
                   (long)(i+1), (long)livePhotoFiles.count, imagePath, videoPath);
        
        if (![[NSFileManager defaultManager] fileExistsAtPath:videoPath]) {
            DYYYLogVideo(@"错误: 实况照片视频不存在: %@", videoPath);
            continue;
        }
        
        [mediaSegments addObject:@{
            @"type": @"video",
            @"path": videoPath
        }];
        DYYYLogVideo(@"成功添加实况照片视频片段 %ld/%ld", (long)(i+1), (long)livePhotoFiles.count);
    }
    
    // 等待所有临时视频处理完成
    dispatch_group_notify(processingGroup, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        DYYYLogVideo(@"所有媒体处理完成，共有 %ld 个可用片段", (long)mediaSegments.count);
        
        if (mediaSegments.count == 0) {
            DYYYLogVideo(@"错误: 没有有效的媒体片段可以合成");
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(NO);
                });
            }
            return;
        }
        
        // 创建AVMutableComposition作为容器
        DYYYLogVideo(@"开始创建视频合成容器");
        AVMutableComposition *composition = [AVMutableComposition composition];
        AVMutableVideoComposition *videoComposition = [AVMutableVideoComposition videoComposition];
        videoComposition.frameDuration = CMTimeMake(1, 30); // 30fps
        videoComposition.renderSize = videoSize;
        
        // 创建视频轨道
        AVMutableCompositionTrack *videoTrack = [composition addMutableTrackWithMediaType:AVMediaTypeVideo 
                                                                         preferredTrackID:kCMPersistentTrackID_Invalid];
        if (!videoTrack) {
            DYYYLogVideo(@"错误: 无法创建视频轨道");
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(NO);
                });
            }
            return;
        }
        
        // 创建音频轨道
        AVMutableCompositionTrack *audioTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio
                                                                         preferredTrackID:kCMPersistentTrackID_Invalid];
        if (!audioTrack) {
            DYYYLogVideo(@"错误: 无法创建音频轨道");
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(NO);
                });
            }
            return;
        }
        
        // 添加背景音乐
        __block CMTime currentTime = kCMTimeZero;
        if (bgmPath && [[NSFileManager defaultManager] fileExistsAtPath:bgmPath]) {
            DYYYLogVideo(@"添加背景音乐: %@", bgmPath);
            AVAsset *audioAsset = [AVAsset assetWithURL:[NSURL fileURLWithPath:bgmPath]];
            AVAssetTrack *audioAssetTrack = [[audioAsset tracksWithMediaType:AVMediaTypeAudio] firstObject];
            
            if (audioAssetTrack) {
                // 先处理所有视频片段以确定总时长
                CMTime totalDuration = kCMTimeZero;
                for (NSDictionary *segment in mediaSegments) {
                    NSString *segmentPath = segment[@"path"];
                    AVAsset *asset = [AVAsset assetWithURL:[NSURL fileURLWithPath:segmentPath]];
                    totalDuration = CMTimeAdd(totalDuration, asset.duration);
                }
                
                // 循环播放背景音乐直到覆盖整个视频时长
                CMTime audioDuration = audioAsset.duration;
                CMTime currentAudioTime = kCMTimeZero;
                
                if (CMTimeCompare(audioDuration, totalDuration) < 0) {
                    DYYYLogVideo(@"背景音乐时长(%.2f秒)小于视频时长(%.2f秒)，将循环播放", 
                               CMTimeGetSeconds(audioDuration), 
                               CMTimeGetSeconds(totalDuration));
                    
                    while (CMTimeCompare(currentAudioTime, totalDuration) < 0) {
                        // 确定当前片段的时长（如果到达视频末尾则截断）
                        CMTime remainingTime = CMTimeSubtract(totalDuration, currentAudioTime);
                        CMTime segmentDuration = audioDuration;
                        
                        if (CMTimeCompare(remainingTime, audioDuration) < 0) {
                            segmentDuration = remainingTime;
                        }
                        
                        // 插入音频片段
                        NSError *audioError = nil;
                        [audioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, segmentDuration)
                                           ofTrack:audioAssetTrack
                                            atTime:currentAudioTime
                                             error:&audioError];
                        
                        if (audioError) {
                            DYYYLogVideo(@"添加背景音乐循环片段失败: %@", audioError);
                            break;
                        }
                        
                        DYYYLogVideo(@"添加背景音乐循环片段 - 位置: %.2f秒, 时长: %.2f秒", 
                                  CMTimeGetSeconds(currentAudioTime),
                                  CMTimeGetSeconds(segmentDuration));
                        
                        // 更新当前音频时间点
                        currentAudioTime = CMTimeAdd(currentAudioTime, segmentDuration);
                    }
                    
                    DYYYLogVideo(@"成功添加循环背景音乐，总时长: %.2f秒", CMTimeGetSeconds(currentAudioTime));
                } else {
                    // 音乐长度足够，直接添加
                    NSError *audioError = nil;
                    [audioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, totalDuration)
                                       ofTrack:audioAssetTrack
                                        atTime:kCMTimeZero
                                         error:&audioError];
                    
                    if (audioError) {
                        DYYYLogVideo(@"添加背景音乐失败: %@", audioError);
                    } else {
                        DYYYLogVideo(@"成功添加背景音乐，时长: %.2f秒", CMTimeGetSeconds(totalDuration));
                    }
                }
            } else {
                DYYYLogVideo(@"错误: 背景音乐没有有效的音轨");
            }
        }
        
        NSMutableArray *instructions = [NSMutableArray array];
        
        // 处理所有媒体片段（按顺序）
        DYYYLogVideo(@"开始按顺序处理 %ld 个媒体片段", (long)mediaSegments.count);
        for (NSInteger i = 0; i < mediaSegments.count; i++) {
            NSDictionary *segment = mediaSegments[i];
            NSString *segmentType = segment[@"type"];
            NSString *segmentPath = segment[@"path"];
            
            DYYYLogVideo(@"处理片段 %ld/%ld: 类型=%@, 路径=%@", 
                       (long)(i+1), (long)mediaSegments.count, segmentType, segmentPath);
            
            AVAsset *asset = [AVAsset assetWithURL:[NSURL fileURLWithPath:segmentPath]];
            NSArray<AVAssetTrack *> *videoTracks = [asset tracksWithMediaType:AVMediaTypeVideo];
            
            if (videoTracks.count == 0) {
                DYYYLogVideo(@"错误: 媒体片段没有视频轨道: %@", segmentPath);
                continue;
            }
            
            AVAssetTrack *assetVideoTrack = videoTracks.firstObject;
            CMTime assetDuration = asset.duration;
            DYYYLogVideo(@"片段 %ld/%ld: 时长=%.2f秒, 尺寸=%.0fx%.0f", 
                       (long)(i+1), (long)mediaSegments.count, 
                       CMTimeGetSeconds(assetDuration),
                       assetVideoTrack.naturalSize.width,
                       assetVideoTrack.naturalSize.height);
            
            // 插入视频片段
            NSError *insertError = nil;
            [videoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, assetDuration)
                                ofTrack:assetVideoTrack
                                 atTime:currentTime
                                  error:&insertError];
            
            if (insertError) {
                DYYYLogVideo(@"插入视频片段失败: %@", insertError);
                continue;
            } else {
                DYYYLogVideo(@"成功插入视频片段 %ld/%ld 到位置 %.2f秒", 
                           (long)(i+1), (long)mediaSegments.count, 
                           CMTimeGetSeconds(currentTime));
            }
            
            // 创建视频合成指令
            AVMutableVideoCompositionInstruction *instruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
            instruction.timeRange = CMTimeRangeMake(currentTime, assetDuration);
            
            AVMutableVideoCompositionLayerInstruction *layerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:videoTrack];
            
            // 计算适当的视频变换
            CGAffineTransform transform = [self transformForAssetTrack:assetVideoTrack targetSize:videoSize];
            [layerInstruction setTransform:transform atTime:currentTime];
            
            instruction.layerInstructions = @[layerInstruction];
            [instructions addObject:instruction];
            DYYYLogVideo(@"添加合成指令: 时间范围=%.2f到%.2f秒", 
                       CMTimeGetSeconds(currentTime), 
                       CMTimeGetSeconds(CMTimeAdd(currentTime, assetDuration)));
            
            
            // 更新时间点
            currentTime = CMTimeAdd(currentTime, assetDuration);
        }
        
        // 设置合成指令
        videoComposition.instructions = instructions;
        DYYYLogVideo(@"设置了 %ld 个视频合成指令，总时长: %.2f秒", 
                   (long)instructions.count, CMTimeGetSeconds(currentTime));
        
        // 检查是否有内容需要导出
        if (instructions.count == 0 || CMTimeGetSeconds(currentTime) < 0.1) {
            DYYYLogVideo(@"错误: 没有足够的内容可以导出");
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(NO);
                });
            }
            
            for (NSDictionary *segment in mediaSegments) {
                if ([segment[@"type"] isEqualToString:@"image"]) {
                    [[NSFileManager defaultManager] removeItemAtPath:segment[@"path"] error:nil];
                    DYYYLogVideo(@"清理临时图片视频文件: %@", segment[@"path"]);
                }
            }
            return;
        }
        
        // 设置导出会话
        DYYYLogVideo(@"创建视频导出会话，使用最高质量编码");
        AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:composition presetName:AVAssetExportPresetHighestQuality];
        if (!exportSession) {
            DYYYLogVideo(@"错误: 创建导出会话失败");
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(NO);
                });
            }
            return;
        }
        
        exportSession.videoComposition = videoComposition;
        exportSession.outputURL = [NSURL fileURLWithPath:outputPath];
        exportSession.outputFileType = AVFileTypeMPEG4;
        exportSession.shouldOptimizeForNetworkUse = YES;
        
        // 导出视频
        DYYYLogVideo(@"开始导出视频到: %@", outputPath);
        [exportSession exportAsynchronouslyWithCompletionHandler:^{
            for (NSDictionary *segment in mediaSegments) {
                if ([segment[@"type"] isEqualToString:@"image"]) {
                    NSError *removeError = nil;
                    [[NSFileManager defaultManager] removeItemAtPath:segment[@"path"] error:&removeError];
                    if (removeError) {
                        DYYYLogVideo(@"清理临时文件失败: %@, 错误: %@", segment[@"path"], removeError);
                    } else {
                        DYYYLogVideo(@"清理临时图片视频文件: %@", segment[@"path"]);
                    }
                }
            }
                        switch (exportSession.status) {
                case AVAssetExportSessionStatusCompleted: {
                    DYYYLogVideo(@"视频导出成功: %@", outputPath);
                    
                    NSDictionary *fileAttrs = [[NSFileManager defaultManager] attributesOfItemAtPath:outputPath error:nil];
                    if (fileAttrs) {
                        unsigned long long fileSize = [fileAttrs fileSize];
                        DYYYLogVideo(@"导出视频大小: %.2f MB", fileSize / (1024.0 * 1024.0));
                    }
                    
                    if (completion) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            completion(YES);
                        });
                    }
                    break;
                }
                
                case AVAssetExportSessionStatusFailed: {
                    DYYYLogVideo(@"导出视频失败: %@", exportSession.error);
                    if (completion) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            completion(NO);
                        });
                    }
                    break;
                }
                
                case AVAssetExportSessionStatusCancelled: {
                    DYYYLogVideo(@"导出视频被取消");
                    if (completion) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            completion(NO);
                        });
                    }
                    break;
                }
                    
                default: {
                    DYYYLogVideo(@"导出视频结束，状态码: %ld", (long)exportSession.status);
                    if (completion) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            completion(NO);
                        });
                    }
                    break;
                }
            }
        }];
    });
}

// 创建从静态图片生成的视频片段
+ (void)createVideoFromImage:(UIImage *)image 
                    duration:(float)duration 
                  outputPath:(NSString *)outputPath 
                  completion:(void (^)(BOOL success))completion {
    // 视频尺寸和参数
    CGSize videoSize = CGSizeMake(1080, 1920);
    NSInteger frameRate = 30;
    
    NSError *error = nil;
    // 设置视频写入器
    AVAssetWriter *videoWriter = [[AVAssetWriter alloc] initWithURL:[NSURL fileURLWithPath:outputPath]
                                                           fileType:AVFileTypeMPEG4
                                                              error:&error];
    if (error) {
        NSLog(@"创建视频写入器失败: %@", error);
        if (completion) completion(NO);
        return;
    }
    
    // 配置视频设置
    NSDictionary *videoSettings = @{
        AVVideoCodecKey: AVVideoCodecTypeH264,
        AVVideoWidthKey: @(videoSize.width),
        AVVideoHeightKey: @(videoSize.height),
        AVVideoCompressionPropertiesKey: @{
            AVVideoAverageBitRateKey: @(6000000),
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
        }
    };
    
    AVAssetWriterInput *writerInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo
                                                                         outputSettings:videoSettings];
    writerInput.expectsMediaDataInRealTime = YES;
    
    // 创建像素缓冲区适配器
    NSDictionary *sourcePixelBufferAttributes = @{
        (NSString*)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32ARGB),
        (NSString*)kCVPixelBufferWidthKey: @(videoSize.width),
        (NSString*)kCVPixelBufferHeightKey: @(videoSize.height)
    };
    
    AVAssetWriterInputPixelBufferAdaptor *adaptor = [AVAssetWriterInputPixelBufferAdaptor
                                                    assetWriterInputPixelBufferAdaptorWithAssetWriterInput:writerInput
                                                    sourcePixelBufferAttributes:sourcePixelBufferAttributes];
    
    [videoWriter addInput:writerInput];
    [videoWriter startWriting];
    [videoWriter startSessionAtSourceTime:kCMTimeZero];
    
    // 不再调整图片大小，只在需要时适配
    // UIImage *resizedImage = [self resizeImage:image toSize:videoSize];
    
    // 创建上下文并绘制图像
    CVPixelBufferRef pixelBuffer = NULL;
    CVPixelBufferPoolCreatePixelBuffer(NULL, adaptor.pixelBufferPool, &pixelBuffer);
    
    if (pixelBuffer == NULL) {
        // 如果池创建失败，手动创建像素缓冲区
        NSDictionary *pixelBufferAttributes = @{
            (NSString*)kCVPixelBufferCGImageCompatibilityKey: @YES,
            (NSString*)kCVPixelBufferCGBitmapContextCompatibilityKey: @YES,
            (NSString*)kCVPixelBufferWidthKey: @(videoSize.width),
            (NSString*)kCVPixelBufferHeightKey: @(videoSize.height)
        };
        CVPixelBufferCreate(kCFAllocatorDefault, videoSize.width, videoSize.height,
                          kCVPixelFormatType_32ARGB, (__bridge CFDictionaryRef)pixelBufferAttributes, &pixelBuffer);
    }
    
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    void *pxdata = CVPixelBufferGetBaseAddress(pixelBuffer);
    
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pxdata, videoSize.width, videoSize.height, 8, CVPixelBufferGetBytesPerRow(pixelBuffer), rgbColorSpace, (CGBitmapInfo)kCGImageAlphaPremultipliedFirst);
    
    // 填充背景
    CGContextSetFillColorWithColor(context, [UIColor blackColor].CGColor);
    CGContextFillRect(context, CGRectMake(0, 0, videoSize.width, videoSize.height));
    
    // 居中绘制图像，保持原始比例
    CGRect drawRect = [self rectForImageAspectFit:image.size inSize:videoSize];
    CGContextDrawImage(context, drawRect, image.CGImage);
    
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    
    // 计算帧数
    NSInteger totalFrames = duration * frameRate;
    
    // 写入每一帧
    dispatch_queue_t queue = dispatch_queue_create("com.dyyy.videoframe", DISPATCH_QUEUE_SERIAL);
    dispatch_async(queue, ^{
        BOOL success = YES;
        for (int i = 0; i < totalFrames; i++) {
            if (writerInput.readyForMoreMediaData) {
                CMTime frameTime = CMTimeMake(i, frameRate);
                success = [adaptor appendPixelBuffer:pixelBuffer withPresentationTime:frameTime];
                if (!success) {
                    NSLog(@"无法写入像素缓冲区");
                    break;
                }
            } else {
                // 如果写入器未准备好，等待
                usleep(10000);
                i--;
            }
        }
        
        // 完成视频写入
        [writerInput markAsFinished];
        [videoWriter finishWritingWithCompletionHandler:^{
            if (pixelBuffer) {
                CVPixelBufferRelease(pixelBuffer);
            }
            
            if (videoWriter.status == AVAssetWriterStatusCompleted) {
                if (completion) completion(YES);
            } else {
                NSLog(@"写入视频失败: %@", videoWriter.error);
                if (completion) completion(NO);
            }
        }];
    });
}

// 缩放图片到指定尺寸
+ (UIImage *)resizeImage:(UIImage *)image toSize:(CGSize)size {
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    [image drawInRect:CGRectMake(0, 0, size.width, size.height)];
    UIImage *resizedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return resizedImage ?: image;
}

+ (CGRect)rectForImageAspectFit:(CGSize)imageSize inSize:(CGSize)containerSize {
    CGFloat hScale = containerSize.width / imageSize.width;
    CGFloat vScale = containerSize.height / imageSize.height;
    CGFloat scale = MIN(hScale, vScale); // 使用MIN而不是MAX来保持原始比例
    
    CGFloat newWidth = imageSize.width * scale;
    CGFloat newHeight = imageSize.height * scale;
    
    CGFloat x = (containerSize.width - newWidth) / 2.0;
    CGFloat y = (containerSize.height - newHeight) / 2.0;
    
    return CGRectMake(x, y, newWidth, newHeight);
}

// 计算视频轨道的变换（保持原始比例）
+ (CGAffineTransform)transformForAssetTrack:(AVAssetTrack *)track targetSize:(CGSize)targetSize {
    CGSize trackSize = CGSizeApplyAffineTransform(track.naturalSize, track.preferredTransform);
    trackSize = CGSizeMake(fabs(trackSize.width), fabs(trackSize.height));
    
    CGFloat xScale = targetSize.width / trackSize.width;
    CGFloat yScale = targetSize.height / trackSize.height;
    CGFloat scale = MIN(xScale, yScale); // 使用MIN而不是MAX来保持原始比例
    
    CGAffineTransform transform = track.preferredTransform;
    transform = CGAffineTransformConcat(transform, CGAffineTransformMakeScale(scale, scale));
    
    // 居中显示
    CGFloat xOffset = (targetSize.width - trackSize.width * scale) / 2.0;
    CGFloat yOffset = (targetSize.height - trackSize.height * scale) / 2.0;
    transform = CGAffineTransformConcat(transform, CGAffineTransformMakeTranslation(xOffset, yOffset));
    
    return transform;
}

@end
