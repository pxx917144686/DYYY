#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "AwemeHeaders.h"
#import "DYYYManager.h"

@interface AWEModernLongPressPanelTableViewController (DYYYAdditions)
- (void)showGlobalVideoDebugInfo;
@end

// 全局变量
static AWEAwemeModel *g_savedAwemeModel = nil;

%hook AWELongPressPanelViewGroupModel
%property(nonatomic, assign) BOOL isDYYYCustomGroup;
%end

%hook AWEModernLongPressPanelTableViewController

%new
- (void)refreshCurrentView {
    UIViewController *topVC = [DYYYManager getActiveTopController];
    if ([topVC respondsToSelector:@selector(viewDidLoad)]) {
        [topVC.view setNeedsLayout];
        [topVC.view layoutIfNeeded];
    }
}

%new
- (void)showVideoDebugInfo:(AWEAwemeModel *)awemeModel {
    if (!awemeModel) {
        [DYYYManager showToast:@"无法获取视频信息"];
        return;
    }
    
    NSMutableString *infoText = [NSMutableString string];
    [infoText appendFormat:@"视频ID: %@\n", [awemeModel valueForKey:@"awemeId"] ?: [awemeModel valueForKey:@"ID"] ?: @"未知"];
    [infoText appendFormat:@"作者: %@\n", [awemeModel valueForKey:@"authorName"] ?: [awemeModel valueForKey:@"author.nickname"] ?: @"未知"];
    [infoText appendFormat:@"描述: %@\n", awemeModel.descriptionString ?: @"无"];
    [infoText appendFormat:@"点赞: %@\n", awemeModel.statistics.diggCount ?: @"0"];
    
    AWEVideoModel *videoModel = awemeModel.video;
    if (videoModel) {
        id duration = [videoModel valueForKey:@"duration"];
        if (duration) {
            [infoText appendFormat:@"视频时长: %.2f 秒\n", [duration floatValue]];
        }
        
        id width = [videoModel valueForKey:@"width"];
        id height = [videoModel valueForKey:@"height"];
        if (width && height) {
            [infoText appendFormat:@"视频分辨率: %dx%d\n", [width intValue], [height intValue]];
        }
        
        id frameRate = [videoModel valueForKey:@"frameRate"];
        if (frameRate) {
            [infoText appendFormat:@"视频帧率: %.2f fps\n", [frameRate floatValue]];
        }
        
        id format = [videoModel valueForKey:@"format"];
        if (format) {
            [infoText appendFormat:@"视频格式: %@\n", format];
        }
        
        id size = [videoModel valueForKey:@"size"];
        if (size) {
            [infoText appendFormat:@"视频大小: %.2f MB\n", [size floatValue] / (1024.0 * 1024.0)];
        }
    }
    
    id createTime = [awemeModel valueForKey:@"createTime"];
    if (createTime) {
        [infoText appendFormat:@"上传时间: %@\n", createTime];
    }
    
    id poi = [awemeModel valueForKey:@"poi"];
    if (poi && [poi respondsToSelector:@selector(valueForKey:)]) {
        id poiName = [poi valueForKey:@"name"];
        if (poiName) {
            [infoText appendFormat:@"地理位置: %@\n", poiName];
        }
    }
    
    UIAlertController *alert = [UIAlertController 
                               alertControllerWithTitle:@"视频信息" 
                               message:infoText 
                               preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"关闭" style:UIAlertActionStyleCancel handler:nil]];
    
    UIViewController *topVC = [DYYYManager getActiveTopController];
    [topVC presentViewController:alert animated:YES completion:nil];
}

%new
- (void)extractVideoHashtags:(AWEAwemeModel *)awemeModel {
    if (!awemeModel) {
        [DYYYManager showToast:@"无法获取视频信息"];
        return;
    }
    
    NSArray *textExtra = [awemeModel valueForKey:@"textExtra"];
    NSMutableArray *hashtags = [NSMutableArray array];
    
    for (NSDictionary *extra in textExtra) {
        NSString *hashtagName = extra[@"hashtagName"];
        if (hashtagName.length > 0) {
            [hashtags addObject:[NSString stringWithFormat:@"#%@", hashtagName]];
        }
    }
    
    if (hashtags.count > 0) {
        NSString *hashtagString = [hashtags componentsJoinedByString:@" "];
        [[UIPasteboard generalPasteboard] setString:hashtagString];
        [DYYYManager showToast:@"视频标签已复制到剪贴板"];
    } else {
        [DYYYManager showToast:@"未找到视频标签"];
    }
}

%new
- (void)shareToThirdParty:(AWEAwemeModel *)awemeModel {
    if (!awemeModel) {
        [DYYYManager showToast:@"无法获取视频信息"];
        return;
    }
    
    NSString *shareLink = [awemeModel valueForKey:@"shareURL"];
    if (shareLink.length == 0) {
        [DYYYManager showToast:@"无法获取分享链接"];
        return;
    }
    
    NSArray *items = @[shareLink];
    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:items applicationActivities:nil];
    
    UIViewController *topVC = [DYYYManager getActiveTopController];
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        activityVC.popoverPresentationController.sourceView = topVC.view;
        activityVC.popoverPresentationController.sourceRect = CGRectMake(topVC.view.bounds.size.width / 2,
                                                                       topVC.view.bounds.size.height / 2,
                                                                       0, 0);
    }
    
    [topVC presentViewController:activityVC animated:YES completion:nil];
}

%new
- (void)showGlobalVideoDebugInfo {
    if (!g_savedAwemeModel) {
        [DYYYManager showToast:@"无法获取视频信息"];
        return;
    }
    
    NSMutableString *infoText = [NSMutableString string];
    [infoText appendFormat:@"视频ID: %@\n", [g_savedAwemeModel valueForKey:@"awemeId"] ?: [g_savedAwemeModel valueForKey:@"ID"] ?: @"未知"];
    [infoText appendFormat:@"作者: %@\n", [g_savedAwemeModel valueForKey:@"authorName"] ?: [g_savedAwemeModel valueForKey:@"author.nickname"] ?: @"未知"];
    [infoText appendFormat:@"描述: %@\n", g_savedAwemeModel.descriptionString ?: @"无"];
    [infoText appendFormat:@"点赞: %@\n", g_savedAwemeModel.statistics.diggCount ?: @"0"];
    
    AWEVideoModel *videoModel = g_savedAwemeModel.video;
    if (videoModel) {
        id duration = [videoModel valueForKey:@"duration"];
        if (duration) {
            [infoText appendFormat:@"视频时长: %.2f 秒\n", [duration floatValue]];
        }
        
        id width = [videoModel valueForKey:@"width"];
        id height = [videoModel valueForKey:@"height"];
        if (width && height) {
            [infoText appendFormat:@"视频分辨率: %dx%d\n", [width intValue], [height intValue]];
        }
        
        id frameRate = [videoModel valueForKey:@"frameRate"];
        if (frameRate) {
            [infoText appendFormat:@"视频帧率: %.2f fps\n", [frameRate floatValue]];
        }
        
        id format = [videoModel valueForKey:@"format"];
        if (format) {
            [infoText appendFormat:@"视频格式: %@\n", format];
        }
        
        id size = [videoModel valueForKey:@"size"];
        if (size) {
            [infoText appendFormat:@"视频大小: %.2f MB\n", [size floatValue] / (1024.0 * 1024.0)];
        }
    }
    
    id createTime = [g_savedAwemeModel valueForKey:@"createTime"];
    if (createTime) {
        [infoText appendFormat:@"上传时间: %@\n", createTime];
    }
    
    id poi = [g_savedAwemeModel valueForKey:@"poi"];
    if (poi && [poi respondsToSelector:@selector(valueForKey:)]) {
        id poiName = [poi valueForKey:@"name"];
        if (poiName) {
            [infoText appendFormat:@"地理位置: %@\n", poiName];
        }
    }
    
    UIAlertController *alert = [UIAlertController 
                               alertControllerWithTitle:@"视频信息" 
                               message:infoText 
                               preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"关闭" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        // 操作完成后释放全局引用
        g_savedAwemeModel = nil;
    }]];
    
    UIViewController *topVC = [DYYYManager getActiveTopController];
    [topVC presentViewController:alert animated:YES completion:nil];
}

- (NSArray *)dataArray {
    NSArray *originalArray = %orig;

    if (!originalArray) {
        originalArray = @[];
    }

    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYLongPressDownload"] && ![[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYCopyText"]) {
        return originalArray;
    }

    AWELongPressPanelViewGroupModel *newGroupModel = [[%c(AWELongPressPanelViewGroupModel) alloc] init];
    [newGroupModel setIsDYYYCustomGroup:YES];
    newGroupModel.groupType = 12;
    newGroupModel.isModern = YES;
    
    NSMutableArray *viewModels = [NSMutableArray array];

    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYLongPressDownload"]) {
        if (self.awemeModel.awemeType != 68) {
            AWELongPressPanelBaseViewModel *downloadViewModel = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
            downloadViewModel.awemeModel = self.awemeModel;
            downloadViewModel.actionType = 666;
            downloadViewModel.duxIconName = @"ic_boxarrowdownhigh_outlined";
            downloadViewModel.describeString = @"保存视频";

            downloadViewModel.action = ^{
              AWEAwemeModel *awemeModel = self.awemeModel;
              AWEVideoModel *videoModel = awemeModel.video;
              AWEMusicModel *musicModel = awemeModel.music;

              if (videoModel && videoModel.h264URL && videoModel.h264URL.originURLList.count > 0) {
                  NSURL *url = [NSURL URLWithString:videoModel.h264URL.originURLList.firstObject];
                  [DYYYManager downloadMedia:url
                           mediaType:MediaTypeVideo
                          completion:^{
                            [DYYYManager showToast:@"视频已保存到相册"];
                          }];
              }

              AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
              [panelManager dismissWithAnimation:YES completion:nil];
            };

            [viewModels addObject:downloadViewModel];
        }

        AWELongPressPanelBaseViewModel *audioViewModel = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        audioViewModel.awemeModel = self.awemeModel;
        audioViewModel.actionType = 668;
        audioViewModel.duxIconName = @"ic_boxarrowdownhigh_outlined";
        audioViewModel.describeString = @"保存音频";

        audioViewModel.action = ^{
          AWEAwemeModel *awemeModel = self.awemeModel;
          AWEMusicModel *musicModel = awemeModel.music;

          if (musicModel && musicModel.playURL && musicModel.playURL.originURLList.count > 0) {
              NSURL *url = [NSURL URLWithString:musicModel.playURL.originURLList.firstObject];
              [DYYYManager downloadMedia:url mediaType:MediaTypeAudio completion:nil];
          }

          AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
          [panelManager dismissWithAnimation:YES completion:nil];
        };

        [viewModels addObject:audioViewModel];

        if (self.awemeModel.awemeType == 68 && self.awemeModel.albumImages.count > 0) {
            AWELongPressPanelBaseViewModel *imageViewModel = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
            imageViewModel.awemeModel = self.awemeModel;
            imageViewModel.actionType = 669;
            imageViewModel.duxIconName = @"ic_boxarrowdownhigh_outlined";
            imageViewModel.describeString = @"保存当前图片";

            AWEImageAlbumImageModel *currimge = self.awemeModel.albumImages[self.awemeModel.currentImageIndex - 1];
            if (currimge.clipVideo != nil) {
                imageViewModel.describeString = @"保存当前实况";
            }
            imageViewModel.action = ^{
              AWEAwemeModel *awemeModel = self.awemeModel;
              AWEImageAlbumImageModel *currentImageModel = nil;

              if (awemeModel.currentImageIndex > 0 && awemeModel.currentImageIndex <= awemeModel.albumImages.count) {
                  currentImageModel = awemeModel.albumImages[awemeModel.currentImageIndex - 1];
              } else {
                  currentImageModel = awemeModel.albumImages.firstObject;
              }
              if (currimge.clipVideo != nil) {
                  NSURL *url = [NSURL URLWithString:currentImageModel.urlList.firstObject];
                  NSURL *videoURL = [currimge.clipVideo.playURL getDYYYSrcURLDownload];

                  [DYYYManager downloadLivePhoto:url
                            videoURL:videoURL
                              completion:^{
                            [DYYYManager showToast:@"实况照片已保存到相册"];
                              }];
              } else if (currentImageModel && currentImageModel.urlList.count > 0) {
                  NSURL *url = [NSURL URLWithString:currentImageModel.urlList.firstObject];
                  [DYYYManager downloadMedia:url
                           mediaType:MediaTypeImage
                          completion:^{
                            [DYYYManager showToast:@"图片已保存到相册"];
                          }];
              }

              AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
              [panelManager dismissWithAnimation:YES completion:nil];
            };

            [viewModels addObject:imageViewModel];

            if (self.awemeModel.albumImages.count > 1) {
                AWELongPressPanelBaseViewModel *allImagesViewModel = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
                allImagesViewModel.awemeModel = self.awemeModel;
                allImagesViewModel.actionType = 670;
                allImagesViewModel.duxIconName = @"ic_boxarrowdownhigh_outlined";
                allImagesViewModel.describeString = @"保存所有图片";

                BOOL hasLivePhoto = NO;
                for (AWEImageAlbumImageModel *imageModel in self.awemeModel.albumImages) {
                    if (imageModel.clipVideo != nil) {
                        hasLivePhoto = YES;
                        break;
                    }
                }

                if (hasLivePhoto) {
                    allImagesViewModel.describeString = @"保存所有实况";
                }

                allImagesViewModel.action = ^{
                  AWEAwemeModel *awemeModel = self.awemeModel;
                  NSMutableArray *imageURLs = [NSMutableArray array];

                  for (AWEImageAlbumImageModel *imageModel in awemeModel.albumImages) {
                      if (imageModel.urlList.count > 0) {
                          [imageURLs addObject:imageModel.urlList.firstObject];
                      }
                  }

                  BOOL hasLivePhoto = NO;
                  for (AWEImageAlbumImageModel *imageModel in awemeModel.albumImages) {
                      if (imageModel.clipVideo != nil) {
                          hasLivePhoto = YES;
                          break;
                      }
                  }

                  if (hasLivePhoto) {
                      NSMutableArray *livePhotos = [NSMutableArray array];
                      for (AWEImageAlbumImageModel *imageModel in awemeModel.albumImages) {
                          if (imageModel.urlList.count > 0 && imageModel.clipVideo != nil) {
                              NSURL *photoURL = [NSURL URLWithString:imageModel.urlList.firstObject];
                              NSURL *videoURL = [imageModel.clipVideo.playURL getDYYYSrcURLDownload];

                              [livePhotos addObject:@{@"imageURL" : photoURL.absoluteString, @"videoURL" : videoURL.absoluteString}];
                          }
                      }

                      [DYYYManager downloadAllLivePhotos:livePhotos];
                  } else if (imageURLs.count > 0) {
                      [DYYYManager downloadAllImages:imageURLs];
                  }

                  AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
                  [panelManager dismissWithAnimation:YES completion:nil];
                };

                [viewModels addObject:allImagesViewModel];
            }
        }
    }

    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYCopyText"]) {
        AWELongPressPanelBaseViewModel *copyText = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        copyText.awemeModel = self.awemeModel;
        copyText.actionType = 671;
        copyText.duxIconName = @"ic_xiaoxihuazhonghua_outlined";
        copyText.describeString = @"复制文案";

        copyText.action = ^{
          NSString *descText = [self.awemeModel valueForKey:@"descriptionString"];
          [[UIPasteboard generalPasteboard] setString:descText];
          [DYYYManager showToast:@"文案已复制到剪贴板"];

          AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
          [panelManager dismissWithAnimation:YES completion:nil];
        };

        [viewModels addObject:copyText];

        AWELongPressPanelBaseViewModel *copyShareLink = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        copyShareLink.awemeModel = self.awemeModel;
        copyShareLink.actionType = 672;
        copyShareLink.duxIconName = @"ic_share_outlined";
        copyShareLink.describeString = @"复制链接";

        copyShareLink.action = ^{
          NSString *shareLink = [self.awemeModel valueForKey:@"shareURL"];
          [[UIPasteboard generalPasteboard] setString:shareLink];
          [DYYYManager showToast:@"分享链接已复制到剪贴板"];

          AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
          [panelManager dismissWithAnimation:YES completion:nil];
        };

        [viewModels addObject:copyShareLink];
    }

    NSString *apiKey = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYInterfaceDownload"];
    if (apiKey.length > 0) {
        AWELongPressPanelBaseViewModel *apiDownload = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        apiDownload.awemeModel = self.awemeModel;
        apiDownload.actionType = 673;
        apiDownload.duxIconName = @"ic_cloudarrowdown_outlined_20";
        apiDownload.describeString = @"解析下载";

        apiDownload.action = ^{
          NSString *shareLink = [self.awemeModel valueForKey:@"shareURL"];
          if (shareLink.length == 0) {
              [DYYYManager showToast:@"无法获取分享链接"];
              return;
          }

          [DYYYManager parseAndDownloadVideoWithShareLink:shareLink apiKey:apiKey];

          AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
          [panelManager dismissWithAnimation:YES completion:nil];
        };

        [viewModels addObject:apiDownload];
    }
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYEnableAdvancedSettings"] || 
        ![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYEnableAdvancedSettings"]) {
        AWELongPressPanelBaseViewModel *advancedFunctions = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        advancedFunctions.awemeModel = self.awemeModel;
        advancedFunctions.actionType = 674;
        advancedFunctions.duxIconName = @"ic_xiaoxihuazhonghua_outlined";
        advancedFunctions.describeString = @"更多功能";

        // 修改"更多功能"的 action 块
        advancedFunctions.action = ^{
            // 获取当前面板管理器
            AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
            
            // 创建一个强引用的临时副本
            AWEAwemeModel *currentAwemeModel = self.awemeModel;
            // 保存到全局变量中以防止被释放
            g_savedAwemeModel = currentAwemeModel;
            
            // 先关闭面板，使用 completion 回调在关闭后再显示弹窗
            [panelManager dismissWithAnimation:YES completion:^{
                UIAlertController *alert = [UIAlertController 
                                    alertControllerWithTitle:@"更多功能" 
                                    message:@"请选择功能" 
                                    preferredStyle:UIAlertControllerStyleActionSheet];
                
                [alert addAction:[UIAlertAction actionWithTitle:@"清除缓存" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    [DYYYManager shared]; 
                    [DYYYManager showToast:@"缓存已清除"];
                }]];

                [alert addAction:[UIAlertAction actionWithTitle:@"刷新视图" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    // 使用 DYYYManager 中的方法直接刷新视图，避免使用 self
                    UIViewController *topVC = [DYYYManager getActiveTopController];
                    if ([topVC respondsToSelector:@selector(viewDidLoad)]) {
                        [topVC.view setNeedsLayout];
                        [topVC.view layoutIfNeeded];
                    }
                    [DYYYManager showToast:@"视图已刷新"];
                }]];

                [alert addAction:[UIAlertAction actionWithTitle:@"视频信息" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    // 避免使用 self.showGlobalVideoDebugInfo 方法
                    // 直接在这里实现视频信息显示逻辑
                    
                    if (!g_savedAwemeModel) {
                        [DYYYManager showToast:@"无法获取视频信息"];
                        return;
                    }
                    
                    NSMutableString *infoText = [NSMutableString string];
                    [infoText appendFormat:@"视频ID: %@\n", [g_savedAwemeModel valueForKey:@"awemeId"] ?: [g_savedAwemeModel valueForKey:@"ID"] ?: @"未知"];
                    [infoText appendFormat:@"作者: %@\n", [g_savedAwemeModel valueForKey:@"authorName"] ?: [g_savedAwemeModel valueForKey:@"author.nickname"] ?: @"未知"];
                    [infoText appendFormat:@"描述: %@\n", g_savedAwemeModel.descriptionString ?: @"无"];
                    [infoText appendFormat:@"点赞: %@\n", g_savedAwemeModel.statistics.diggCount ?: @"0"];
                    
                    AWEVideoModel *videoModel = g_savedAwemeModel.video;
                    if (videoModel) {
                        id duration = [videoModel valueForKey:@"duration"];
                        if (duration) {
                            [infoText appendFormat:@"视频时长: %.2f 秒\n", [duration floatValue]];
                        }
                        
                        id width = [videoModel valueForKey:@"width"];
                        id height = [videoModel valueForKey:@"height"];
                        if (width && height) {
                            [infoText appendFormat:@"视频分辨率: %dx%d\n", [width intValue], [height intValue]];
                        }
                        
                        id frameRate = [videoModel valueForKey:@"frameRate"];
                        if (frameRate) {
                            [infoText appendFormat:@"视频帧率: %.2f fps\n", [frameRate floatValue]];
                        }
                        
                        id format = [videoModel valueForKey:@"format"];
                        if (format) {
                            [infoText appendFormat:@"视频格式: %@\n", format];
                        }
                        
                        id size = [videoModel valueForKey:@"size"];
                        if (size) {
                            [infoText appendFormat:@"视频大小: %.2f MB\n", [size floatValue] / (1024.0 * 1024.0)];
                        }
                    }
                    
                    id createTime = [g_savedAwemeModel valueForKey:@"createTime"];
                    if (createTime) {
                        [infoText appendFormat:@"上传时间: %@\n", createTime];
                    }
                    
                    id poi = [g_savedAwemeModel valueForKey:@"poi"];
                    if (poi && [poi respondsToSelector:@selector(valueForKey:)]) {
                        id poiName = [poi valueForKey:@"name"];
                        if (poiName) {
                            [infoText appendFormat:@"地理位置: %@\n", poiName];
                        }
                    }
                    
                    UIAlertController *videoInfoAlert = [UIAlertController 
                                                alertControllerWithTitle:@"视频信息" 
                                                message:infoText 
                                                preferredStyle:UIAlertControllerStyleAlert];
                    
                    [videoInfoAlert addAction:[UIAlertAction actionWithTitle:@"关闭" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                        // 操作完成后释放全局引用
                        g_savedAwemeModel = nil;
                    }]];
                    
                    UIViewController *topVC = [DYYYManager getActiveTopController];
                    [topVC presentViewController:videoInfoAlert animated:YES completion:nil];
                }]];

                [alert addAction:[UIAlertAction actionWithTitle:@"强制关闭广告" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"DYYYBlockAllAds"];
                    [[NSUserDefaults standardUserDefaults] synchronize];
                    [DYYYManager showToast:@"已强制关闭广告，重启App生效"];
                }]];

                [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
                
                UIViewController *topVC = [DYYYManager getActiveTopController];
                if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
                    alert.popoverPresentationController.sourceView = topVC.view;
                    alert.popoverPresentationController.sourceRect = CGRectMake(topVC.view.bounds.size.width / 2, 
                                                                            topVC.view.bounds.size.height / 2, 
                                                                            0, 0);
                }
                
                [topVC presentViewController:alert animated:YES completion:nil];
            }];
        };
        
        [viewModels addObject:advancedFunctions];
    }

    NSMutableArray<AWELongPressPanelViewGroupModel *> *customGroups = [NSMutableArray array];
    NSInteger totalButtons = viewModels.count;
    NSInteger firstRowCount = 0;
    NSInteger secondRowCount = 0;
    
    if (totalButtons <= 2) {
        firstRowCount = totalButtons;
    } else if (totalButtons <= 4) {
        firstRowCount = totalButtons / 2;
        secondRowCount = totalButtons - firstRowCount;
    } else if (totalButtons <= 5) {
        firstRowCount = 3;
        secondRowCount = totalButtons - firstRowCount;
    } else if (totalButtons <= 6) {
        firstRowCount = 4;
        secondRowCount = totalButtons - firstRowCount;
    } else if (totalButtons <= 8) {
        firstRowCount = 4;
        secondRowCount = totalButtons - firstRowCount;
    } else {
        firstRowCount = 5;
        secondRowCount = totalButtons - firstRowCount;
    }
    
    if (firstRowCount > 0) {
        NSArray<AWELongPressPanelBaseViewModel *> *firstRowButtons = [viewModels subarrayWithRange:NSMakeRange(0, firstRowCount)];
        
        AWELongPressPanelViewGroupModel *firstRowGroup = [[%c(AWELongPressPanelViewGroupModel) alloc] init];
        firstRowGroup.isDYYYCustomGroup = YES;
        firstRowGroup.groupType = (firstRowCount <= 3) ? 11 : 12;
        firstRowGroup.isModern = YES;
        firstRowGroup.groupArr = firstRowButtons;
        [customGroups addObject:firstRowGroup];
    }
    
    if (secondRowCount > 0) {
        NSArray<AWELongPressPanelBaseViewModel *> *secondRowButtons = [viewModels subarrayWithRange:NSMakeRange(firstRowCount, secondRowCount)];
        
        AWELongPressPanelViewGroupModel *secondRowGroup = [[%c(AWELongPressPanelViewGroupModel) alloc] init];
        secondRowGroup.isDYYYCustomGroup = YES;
        secondRowGroup.groupType = (secondRowCount <= 3) ? 11 : 12;
        secondRowGroup.isModern = YES;
        secondRowGroup.groupArr = secondRowButtons;
        [customGroups addObject:secondRowGroup];
    }
    
    if (originalArray.count > 0 && [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHidePanelDaily"]) {
        NSMutableArray *modifiedArray = [originalArray mutableCopy];
        AWELongPressPanelViewGroupModel *firstGroup = modifiedArray[0];
        if (firstGroup.groupArr.count > 1) {
            NSMutableArray *groupArray = [firstGroup.groupArr mutableCopy];
            if ([[groupArray[1] valueForKey:@"describeString"] isEqualToString:@"转发到日常"]) {
                [groupArray removeObjectAtIndex:1];
            }
            firstGroup.groupArr = groupArray;
            modifiedArray[0] = firstGroup;
        }
        originalArray = modifiedArray;
    }

    return [customGroups arrayByAddingObjectsFromArray:originalArray];
}

%end

%hook AWELongPressPanelViewGroupModel

%new
- (void)setIsDYYYCustomGroup:(BOOL)isCustom {
    objc_setAssociatedObject(self, @selector(isDYYYCustomGroup), @(isCustom), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

%new
- (BOOL)isDYYYCustomGroup {
    NSNumber *value = objc_getAssociatedObject(self, @selector(isDYYYCustomGroup));
    return [value boolValue];
}

%end

%hook AWEModernLongPressHorizontalSettingCell

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)layout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    if (self.longPressViewGroupModel && [self.longPressViewGroupModel isDYYYCustomGroup]) {
        if (self.dataArray && indexPath.item < self.dataArray.count) {
            CGFloat totalWidth = collectionView.bounds.size.width;
            NSInteger itemCount = self.dataArray.count;
            CGFloat itemWidth = totalWidth / itemCount;
            return CGSizeMake(itemWidth, 73);
        }
        return CGSizeMake(73, 73);
    }

    return %orig;
}

%end

%hook AWEModernLongPressInteractiveCell

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)layout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    if (self.longPressViewGroupModel && [self.longPressViewGroupModel isDYYYCustomGroup]) {
        if (self.dataArray && indexPath.item < self.dataArray.count) {
            NSInteger itemCount = self.dataArray.count;
            CGFloat totalWidth = collectionView.bounds.size.width - 12 * (itemCount - 1);
            CGFloat itemWidth = totalWidth / itemCount;
            return CGSizeMake(itemWidth, 73);
        }
        return CGSizeMake(73, 73);
    }

    return %orig;
}

%end
