#import "DYYYManagerPrivate.h"
#import <Photos/Photos.h>
#import "DYYYToast.h"
#import "DYYYUtils.h"
#import "DYYYPaths.h"

@implementation DYYYManager (Comment)

+ (void)saveCommentImages:(NSArray *)imageModels
             currentIndex:(NSInteger)currentIndex
               completion:(void (^)(NSInteger successCount, NSInteger livePhotoCount, NSInteger failedCount))completion {
    if (!imageModels || imageModels.count == 0) {
        if (completion) completion(0, 0, 0);
        return;
    }

    // 确定要保存的图片
    NSArray *imagesToSave = nil;
    if (currentIndex >= 0 && currentIndex < (NSInteger)imageModels.count) {
        imagesToSave = @[imageModels[currentIndex]];
    } else {
        imagesToSave = imageModels;
    }

    // 分离普通图片和实况照片
    NSMutableArray *normalImages = [NSMutableArray array];
    NSMutableArray *livePhotos = [NSMutableArray array];

    for (id imageModel in imagesToSave) {
        @try {
            // 获取图片 URL - originUrl 和 mediumUrl 都是 AWEURLModel 类型
            NSString *imageUrlStr = nil;

            // 首先尝试 originUrl
            AWEURLModel *originUrlModel = [imageModel valueForKey:@"originUrl"];
            if (originUrlModel) {
                NSArray *urlList = [originUrlModel originURLList];
                if (urlList && urlList.count > 0) {
                    imageUrlStr = urlList.firstObject;
                }
            }

            // 如果 originUrl 没有获取到，尝试 mediumUrl
            if (!imageUrlStr) {
                AWEURLModel *mediumUrlModel = [imageModel valueForKey:@"mediumUrl"];
                if (mediumUrlModel) {
                    NSArray *urlList = [mediumUrlModel originURLList];
                    if (urlList && urlList.count > 0) {
                        imageUrlStr = urlList.firstObject;
                    }
                }
            }

            NSLog(@"[DYYY] 评论图片URL: %@", imageUrlStr);

            if (!imageUrlStr || imageUrlStr.length == 0) {
                NSLog(@"[DYYY] 无法获取图片URL，imageModel: %@", imageModel);
                continue;
            }

            // 检查是否是实况照片
            id livePhotoModel = [imageModel valueForKey:@"livePhotoModel"];
            if (livePhotoModel) {
                NSArray *videoUrls = [livePhotoModel valueForKey:@"videoUrl"];
                if (videoUrls && videoUrls.count > 0) {
                    NSString *videoUrlStr = videoUrls.firstObject;
                    if (videoUrlStr && videoUrlStr.length > 0) {
                        [livePhotos addObject:@{
                            @"imageURL": imageUrlStr,
                            @"videoURL": videoUrlStr
                        }];
                        continue;
                    }
                }
            }

            // 普通图片
            [normalImages addObject:imageUrlStr];
        } @catch (NSException *e) {
            NSLog(@"[DYYY] 解析评论图片失败: %@", e);
        }
    }

    NSLog(@"[DYYY] 解析完成: 普通图片=%lu, 实况照片=%lu", (unsigned long)normalImages.count, (unsigned long)livePhotos.count);

    if (normalImages.count == 0 && livePhotos.count == 0) {
        if (completion) completion(0, 0, (NSInteger)imagesToSave.count);
        return;
    }

    __block NSInteger successCount = 0;
    __block NSInteger livePhotoCount = 0;
    __block NSInteger failedCount = 0;

    dispatch_group_t group = dispatch_group_create();

    // 保存普通图片
    if (normalImages.count > 0) {
        dispatch_group_enter(group);
        [self downloadAllImagesWithProgress:[normalImages mutableCopy]
                                   progress:nil
                                 completion:^(NSInteger imgSuccess, NSInteger imgTotal) {
            successCount += imgSuccess;
            failedCount += (imgTotal - imgSuccess);
            dispatch_group_leave(group);
        }];
    }

    // 保存实况照片
    if (livePhotos.count > 0) {
        dispatch_group_enter(group);
        [self downloadAllLivePhotosWithProgress:livePhotos
                                       progress:nil
                                     completion:^(NSInteger lpSuccess, NSInteger lpTotal) {
            successCount += lpSuccess;
            livePhotoCount = lpSuccess;
            failedCount += (lpTotal - lpSuccess);
            dispatch_group_leave(group);
        }];
    }

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        if (completion) {
            completion(successCount, livePhotoCount, failedCount);
        }
    });
}

#pragma mark - 评论语音下载/分享

+ (void)downloadAndShareCommentAudio:(NSString *)audioContent
                            userName:(NSString *)userName
                          createTime:(NSNumber *)createTime {
    if (!audioContent || audioContent.length == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [DYYYUtils showToast:@"语音内容为空"];
        });
        return;
    }

    NSData *jsonData = [audioContent dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error = nil;
    NSDictionary *audioDict = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];

    if (error || !audioDict) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [DYYYUtils showToast:@"语音数据解析失败"];
        });
        NSLog(@"[DYYY] 解析语音 JSON 失败: %@", error);
        return;
    }

    NSArray *videoList = audioDict[@"video_list"];
    if (!videoList || videoList.count == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [DYYYUtils showToast:@"未找到语音URL"];
        });
        return;
    }

    NSDictionary *videoInfo = videoList.firstObject;
    NSString *audioURLString = videoInfo[@"main_url"];
    if (!audioURLString || audioURLString.length == 0) {
        audioURLString = videoInfo[@"backup_url"];
    }

    if (!audioURLString || audioURLString.length == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [DYYYUtils showToast:@"语音URL无效"];
        });
        return;
    }

    NSURL *audioURL = [NSURL URLWithString:audioURLString];
    if (!audioURL) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [DYYYUtils showToast:@"语音URL格式错误"];
        });
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [DYYYUtils showToast:@"正在下载语音..."];
    });

    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];

    NSURLSessionDownloadTask *downloadTask = [session downloadTaskWithURL:audioURL completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [DYYYUtils showToast:[NSString stringWithFormat:@"下载失败: %@", error.localizedDescription]];
            });
            NSLog(@"[DYYY] 下载语音失败: %@", error);
            return;
        }

        if (!location) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [DYYYUtils showToast:@"下载失败：无效的文件"];
            });
            return;
        }

        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
        NSTimeInterval timestamp = (createTime && [createTime doubleValue] > 0) ? [createTime doubleValue] : [[NSDate date] timeIntervalSince1970];
        NSDate *commentDate = [NSDate dateWithTimeIntervalSince1970:timestamp];
        NSString *timeString = [formatter stringFromDate:commentDate];
        timeString = [timeString stringByReplacingOccurrencesOfString:@":" withString:@"-"];
        timeString = [timeString stringByReplacingOccurrencesOfString:@" " withString:@"_"];

        NSString *safeUserName = userName ?: @"未知用户";
        safeUserName = [safeUserName stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
        safeUserName = [safeUserName stringByReplacingOccurrencesOfString:@"\\" withString:@"_"];

        NSString *fileName = [NSString stringWithFormat:@"%@_%@.m4a", safeUserName, timeString];
        NSString *tempDir = [DYYYPaths tempDir];
        NSString *targetPath = [tempDir stringByAppendingPathComponent:fileName];

        NSError *moveError = nil;
        [[NSFileManager defaultManager] removeItemAtPath:targetPath error:nil];
        [[NSFileManager defaultManager] moveItemAtPath:location.path toPath:targetPath error:&moveError];

        if (moveError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [DYYYUtils showToast:@"文件保存失败"];
            });
            NSLog(@"[DYYY] 移动文件失败: %@", moveError);
            return;
        }

        NSURL *fileURL = [NSURL fileURLWithPath:targetPath];

        dispatch_async(dispatch_get_main_queue(), ^{
            UIViewController *topVC = [DYYYUtils topView];
            if (!topVC) {
                [DYYYUtils showToast:@"无法显示分享界面"];
                return;
            }

            UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[fileURL] applicationActivities:nil];

            activityVC.completionWithItemsHandler = ^(UIActivityType activityType, BOOL completed, NSArray *returnedItems, NSError *activityError) {
                [[NSFileManager defaultManager] removeItemAtPath:targetPath error:nil];

                if (completed) {
                    [DYYYUtils showToast:@"分享成功"];
                } else if (activityError) {
                    [DYYYUtils showToast:@"分享失败"];
                }
            };

            if ([activityVC respondsToSelector:@selector(popoverPresentationController)]) {
                activityVC.popoverPresentationController.sourceView = topVC.view;
                activityVC.popoverPresentationController.sourceRect = CGRectMake(topVC.view.bounds.size.width / 2, topVC.view.bounds.size.height / 2, 0, 0);
            }

            [topVC presentViewController:activityVC animated:YES completion:nil];
        });
    }];

    [downloadTask resume];
}

#pragma mark - 动图表情保存

+ (void)saveAnimatedSticker:(YYAnimatedImageView *)targetStickerView {
    if (!targetStickerView) {
        [DYYYUtils showToast:@"无法获取表情视图"];
        return;
    }
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
      dispatch_async(dispatch_get_main_queue(), ^{
        if (status != PHAuthorizationStatusAuthorized) {
            [DYYYUtils showToast:@"需要相册权限才能保存"];
            return;
        }
        if ([DYYYUtils isBDImageWithHeifURL:targetStickerView.image]) {
            [self saveHeifSticker:targetStickerView];
            return;
        }
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
          NSArray *images = [DYYYUtils getImagesFromYYAnimatedImageView:targetStickerView];
          CGFloat duration = [DYYYUtils getDurationFromYYAnimatedImageView:targetStickerView];
          if (!images || images.count == 0) {
              dispatch_async(dispatch_get_main_queue(), ^{
                [DYYYUtils showToast:@"无法获取表情帧"];
              });
              return;
          }
          NSString *tempPath = [[DYYYPaths tempDir] stringByAppendingPathComponent:[NSString stringWithFormat:@"sticker_%ld.gif", (long)[[NSDate date] timeIntervalSince1970]]];
          BOOL success = [DYYYUtils createGIFWithImages:images
                                               duration:duration
                                                   path:tempPath
                                               progress:^(float progress){
                                               }];
          dispatch_async(dispatch_get_main_queue(), ^{
            if (!success) {
                return;
            }
            [DYYYUtils saveGIFToPhotoLibrary:tempPath
                                  completion:^(BOOL saved, NSError *error) {
                               if (saved) {
                                   [DYYYToast showSuccessToastWithMessage:@"已保存到相册"];
                               } else {
                                   NSString *errorMsg = error ? error.localizedDescription : @"未知错误";
                                   [DYYYUtils showToast:[NSString stringWithFormat:@"保存失败: %@", errorMsg]];
                               }
                             }];
          });
        });
      });
    }];
}

+ (void)saveHeifSticker:(YYAnimatedImageView *)stickerView {
    UIImage *image = stickerView.image;
    NSURL *heifURL = [image performSelector:@selector(bd_webURL)];
    if (!heifURL) {
        [DYYYUtils showToast:@"无法获取表情URL"];
        return;
    }
    [DYYYUtils convertHeicToGif:heifURL
                     completion:^(NSURL *gifURL, BOOL success) {
                         if (!success || !gifURL) {
                             [DYYYUtils showToast:@"表情转换失败"];
                             return;
                         }
                         [[PHPhotoLibrary sharedPhotoLibrary]
                             performChanges:^{
                               PHAssetCreationRequest *request = [PHAssetCreationRequest creationRequestForAsset];
                               [request addResourceWithType:PHAssetResourceTypePhoto fileURL:gifURL options:nil];
                             }
                             completionHandler:^(BOOL success, NSError *_Nullable error) {
                               dispatch_async(dispatch_get_main_queue(), ^{
                                 if (success) {
                                     [DYYYToast showSuccessToastWithMessage:@"已保存到相册"];
                                 } else {
                                     NSString *errorMsg = error ? error.localizedDescription : @"未知错误";
                                     [DYYYUtils showToast:[NSString stringWithFormat:@"保存失败: %@", errorMsg]];
                                 }
                                 NSError *removeError = nil;
                                 [[NSFileManager defaultManager] removeItemAtURL:gifURL error:&removeError];
                                 if (removeError) {
                                     NSLog(@"删除临时转换文件失败: %@", removeError);
                                 }
                               });
                             }];
                       }];
}

@end
