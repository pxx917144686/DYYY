#define DYYYConfirmCloseView_DEFINED
#define DYYYUtils_DEFINED
#define DYYYKeywordListView_DEFINED
#define DYYYFilterSettingsView_DEFINED
#define DYYYCustomInputView_DEFINED
#define DYYYBottomAlertView_DEFINED
#define DYYYToast_DEFINED

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "AwemeHeaders.h"
#import "DYYYManager.h"
#import "FLEXHeaders.h"
#import "DYYYConfirmCloseView.h"
#import "DYYYUtils.h"
#import "DYYYKeywordListView.h"
#import "DYYYFilterSettingsView.h"
#import "DYYYCustomInputView.h"
#import "DYYYBottomAlertView.h"
#import "DYYYToast.h"

@interface DYYYCustomInputView : UIView
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UITextField *inputTextField;
@property (nonatomic, strong) UIButton *confirmButton;
@property (nonatomic, strong) UIButton *cancelButton;
@property (nonatomic, copy) void (^onConfirm)(NSString *text);
@property (nonatomic, copy) void (^onCancel)(void);
@property (nonatomic, assign) CGRect originalFrame; 
@property (nonatomic, copy) NSString *defaultText;
@property (nonatomic, copy) NSString *placeholderText;

- (instancetype)initWithTitle:(NSString *)title defaultText:(NSString *)defaultText placeholder:(NSString *)placeholder;
- (instancetype)initWithTitle:(NSString *)title defaultText:(NSString *)defaultText;
- (instancetype)initWithTitle:(NSString *)title;
- (void)show;
- (void)dismiss;
@end

@class DYYYBottomAlertView;
@class DYYYToast;

@interface AWEModernLongPressPanelTableViewController (DYYY_FLEX)
- (void)fixFLEXMenu:(AWEAwemeModel *)awemeModel;
- (NSArray *)applyOriginalArrayFilters:(NSArray *)originalArray;
- (NSArray<NSNumber *> *)calculateButtonDistribution:(NSInteger)totalButtons;
- (AWELongPressPanelViewGroupModel *)createCustomGroup:(NSArray<AWELongPressPanelBaseViewModel *> *)buttons;
@end

// 全局变量
static AWEAwemeModel *g_savedAwemeModel = nil;

%hook AWELongPressPanelViewGroupModel
%property(nonatomic, assign) BOOL isDYYYCustomGroup;
%end

%hook AWEModernLongPressPanelTableViewController

%new
- (void)fixFLEXMenu:(AWEAwemeModel *)awemeModel {
    // 保存当前视频模型，以防被释放
    g_savedAwemeModel = awemeModel;
    
    // 直接打开 FLEX 调试器
    [[%c(FLEXManager) sharedManager] showExplorer];
}

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

    // 检查主开关状态
    BOOL enableLongPressMain = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYLongPressDownload"];
    
    // 如果主开关未开启，直接返回原始数组
    if (!enableLongPressMain) {
        return originalArray;
    }
    
    // 检查各个单独的功能开关 - 确保键名与设置菜单保持一致
    BOOL enableSaveVideo = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYLongPressSaveVideo"];
    BOOL enableSaveCover = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYLongPressSaveCover"];
    BOOL enableSaveAudio = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYLongPressSaveAudio"];
    BOOL enableSaveCurrentImage = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYLongPressSaveCurrentImage"];
    BOOL enableSaveAllImages = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYLongPressSaveAllImages"];
    BOOL enableCopyText = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYLongPressCopyText"];
    BOOL enableCopyLink = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYLongPressCopyLink"];
    BOOL enableApiDownload = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYLongPressApiDownload"];
    BOOL enableFilterUser = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYLongPressFilterUser"];
    BOOL enableFilterKeyword = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYLongPressFilterTitle"];
    BOOL enableTimerClose = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYLongPressTimerClose"];
    BOOL enableCreateVideo = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYLongPressCreateVideo"];
    BOOL enableFLEX = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYEnableFLEX"];

    // 获取需要隐藏的按钮设置
    BOOL hideDaily = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHidePanelDaily"];
    BOOL hideRecommend = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHidePanelRecommend"];
    BOOL hideNotInterested = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHidePanelNotInterested"];
    BOOL hideReport = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHidePanelReport"];
    BOOL hideSpeed = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHidePanelSpeed"];
    BOOL hideClearScreen = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHidePanelClearScreen"];
    BOOL hideFavorite = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHidePanelFavorite"];
    BOOL hideLater = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHidePanelLater"];
    BOOL hideCast = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHidePanelCast"];
    BOOL hideOpenInPC = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHidePanelOpenInPC"];
    BOOL hideSubtitle = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHidePanelSubtitle"];
    BOOL hideAutoPlay = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHidePanelAutoPlay"];
    BOOL hideSearchImage = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHidePanelSearchImage"];
    BOOL hideListenDouyin = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHidePanelListenDouyin"];
    BOOL hideBackgroundPlay = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHidePanelBackgroundPlay"];
    BOOL hideBiserial = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHidePanelBiserial"];
    BOOL hideTimerclose = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHidePanelTimerClose"];

    AWELongPressPanelViewGroupModel *newGroupModel = [[%c(AWELongPressPanelViewGroupModel) alloc] init];
    [newGroupModel setIsDYYYCustomGroup:YES];
    newGroupModel.groupType = 12;
    newGroupModel.isModern = YES;
    
    NSMutableArray *viewModels = [NSMutableArray array];

    if (enableSaveVideo) {
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
                                  completion:^(BOOL success){
                                    if (success) {
                                      [DYYYManager showToast:@"视频已保存到相册"];
                                    } else {
                                      [DYYYManager showToast:@"视频保存失败"];
                                    }
                                  }];
              }

              AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
              [panelManager dismissWithAnimation:YES completion:nil];
            };

            [viewModels addObject:downloadViewModel];
        }
    }

    if (enableSaveAudio) {
        AWELongPressPanelBaseViewModel *audioViewModel = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        audioViewModel.awemeModel = self.awemeModel;
        audioViewModel.actionType = 668;
        audioViewModel.duxIconName = @"ic_boxarrowdownhigh_outlined";
        audioViewModel.describeString = @"分享音频";

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
    }

    // 保存所有图片/实况功能
    if (enableSaveAllImages && self.awemeModel.awemeType == 68 && self.awemeModel.albumImages.count > 1) {
        AWELongPressPanelBaseViewModel *allImagesViewModel = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        allImagesViewModel.awemeModel = self.awemeModel;
        allImagesViewModel.actionType = 670;
        allImagesViewModel.duxIconName = @"ic_boxarrowdownhigh_outlined";
        allImagesViewModel.describeString = @"保存所有图片";
        // 检查是否有实况照片并更改按钮文字
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
          NSMutableArray *livePhotos = [NSMutableArray array];

          for (AWEImageAlbumImageModel *imageModel in awemeModel.albumImages) {
              if (imageModel.urlList.count > 0) {
                  // 查找非.image后缀的URL
                  NSURL *downloadURL = nil;
                  for (NSString *urlString in imageModel.urlList) {
                      NSURL *url = [NSURL URLWithString:urlString];
                      NSString *pathExtension = [url.path.lowercaseString pathExtension];
                      if (![pathExtension isEqualToString:@"image"]) {
                          downloadURL = url;
                          break;
                      }
                  }

                  if (!downloadURL && imageModel.urlList.count > 0) {
                      downloadURL = [NSURL URLWithString:imageModel.urlList.firstObject];
                  }

                  // 检查是否是实况照片
                  if (imageModel.clipVideo != nil) {
                      NSURL *videoURL = [imageModel.clipVideo.playURL getDYYYSrcURLDownload];
                      [livePhotos addObject:@{@"imageURL" : downloadURL.absoluteString, @"videoURL" : videoURL.absoluteString}];
                  } else {
                      [imageURLs addObject:downloadURL.absoluteString];
                  }
              }
          }

          // 分别处理普通图片和实况照片
          if (livePhotos.count > 0) {
              [DYYYManager downloadAllLivePhotos:livePhotos];
          }

          if (imageURLs.count > 0) {
              [DYYYManager downloadAllImages:imageURLs];
          }

          if (livePhotos.count == 0 && imageURLs.count == 0) {
              [DYYYManager showToast:@"没有找到合适格式的图片"];
          }

          AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
          [panelManager dismissWithAnimation:YES completion:nil];
        };
        [viewModels addObject:allImagesViewModel];
    }

    // 创建视频功能
    if (enableCreateVideo && self.awemeModel.awemeType == 68 && self.awemeModel.albumImages.count > 1) {
        AWELongPressPanelBaseViewModel *createVideoViewModel = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        createVideoViewModel.awemeModel = self.awemeModel;
        createVideoViewModel.actionType = 677;
        createVideoViewModel.duxIconName = @"ic_videosearch_outlined_20";
        createVideoViewModel.describeString = @"制作视频";
        createVideoViewModel.action = ^{
          AWEAwemeModel *awemeModel = self.awemeModel;

          // 收集普通图片URL
          NSMutableArray *imageURLs = [NSMutableArray array];
          // 收集实况照片信息（图片URL+视频URL）
          NSMutableArray *livePhotos = [NSMutableArray array];

          // 获取背景音乐URL
          NSString *bgmURL = nil;
          if (awemeModel.music && awemeModel.music.playURL && awemeModel.music.playURL.originURLList.count > 0) {
              bgmURL = awemeModel.music.playURL.originURLList.firstObject;
          }

          // 处理所有图片和实况
          for (AWEImageAlbumImageModel *imageModel in awemeModel.albumImages) {
              if (imageModel.urlList.count > 0) {
                  // 查找非.image后缀的URL
                  NSString *bestURL = nil;
                  for (NSString *urlString in imageModel.urlList) {
                      NSURL *url = [NSURL URLWithString:urlString];
                      NSString *pathExtension = [url.path.lowercaseString pathExtension];
                      if (![pathExtension isEqualToString:@"image"]) {
                          bestURL = urlString;
                          break;
                      }
                  }

                  if (!bestURL && imageModel.urlList.count > 0) {
                      bestURL = imageModel.urlList.firstObject;
                  }

                  // 如果是实况照片，需要收集图片和视频URL
                  if (imageModel.clipVideo != nil) {
                      NSURL *videoURL = [imageModel.clipVideo.playURL getDYYYSrcURLDownload];
                      if (videoURL) {
                          [livePhotos addObject:@{@"imageURL" : bestURL, @"videoURL" : videoURL.absoluteString}];
                      }
                  } else {
                      // 普通图片
                      [imageURLs addObject:bestURL];
                  }
              }
          }

          // 调用视频创建API
          [DYYYManager createVideoFromMedia:imageURLs
              livePhotos:livePhotos
              bgmURL:bgmURL
              progress:^(NSInteger current, NSInteger total, NSString *status) {
              }
              completion:^(BOOL success, NSString *message) {
            if (success) {
            } else {
                [DYYYManager showToast:[NSString stringWithFormat:@"视频制作失败: %@", message]];
            }
              }];

          AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
          [panelManager dismissWithAnimation:YES completion:nil];
        };
        [viewModels addObject:createVideoViewModel];
    }

    // 复制分享链接功能
    if (enableCopyLink) {
        AWELongPressPanelBaseViewModel *copyShareLink = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        copyShareLink.awemeModel = self.awemeModel;
        copyShareLink.actionType = 672;
        copyShareLink.duxIconName = @"ic_share_outlined";
        copyShareLink.describeString = @"复制链接";
        copyShareLink.action = ^{
          NSString *shareLink = [self.awemeModel valueForKey:@"shareURL"];
          NSString *cleanedURL = cleanShareURL(shareLink);
          [[UIPasteboard generalPasteboard] setString:cleanedURL];
          [DYYYToast showSuccessToastWithMessage:@"分享链接已复制"];
          AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
          [panelManager dismissWithAnimation:YES completion:nil];
        };
        [viewModels addObject:copyShareLink];
    }    

    if (enableApiDownload) {
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
    }

    if (enableFLEX) {
        AWELongPressPanelBaseViewModel *flexViewModel = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        flexViewModel.awemeModel = self.awemeModel;
        flexViewModel.actionType = 675;
        flexViewModel.duxIconName = @"ic_xiaoxihuazhonghua_outlined";
        flexViewModel.describeString = @"FLEX调试";

        // 修改FLEX功能菜单的调用方式
        flexViewModel.action = ^{
            // 保存当前视频模型
            AWEAwemeModel *currentAwemeModel = self.awemeModel;
            
            // 关闭长按面板
            AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
            [panelManager dismissWithAnimation:YES completion:^{
                // 直接调用修复后的FLEX菜单方法
                [self fixFLEXMenu:currentAwemeModel];
            }];
        };

        [viewModels addObject:flexViewModel];
    }

    // 过滤用户功能
    if (enableFilterUser) {
        AWELongPressPanelBaseViewModel *filterKeywords = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        filterKeywords.awemeModel = self.awemeModel;
        filterKeywords.actionType = 674;
        filterKeywords.duxIconName = @"ic_userban_outlined_20";
        filterKeywords.describeString = @"过滤用户";
        filterKeywords.action = ^{
          AWEUserModel *author = self.awemeModel.author;
          NSString *nickname = author.nickname ?: @"未知用户";
          NSString *shortId = author.shortID ?: @"";
          // 创建当前用户的过滤格式 "nickname-shortid"
          NSString *currentUserFilter = [NSString stringWithFormat:@"%@-%@", nickname, shortId];
          // 获取保存的过滤用户列表
          NSString *savedUsers = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYfilterUsers"] ?: @"";
          NSArray *userArray = [savedUsers length] > 0 ? [savedUsers componentsSeparatedByString:@","] : @[];
          BOOL userExists = NO;
          for (NSString *userInfo in userArray) {
              NSArray *components = [userInfo componentsSeparatedByString:@"-"];
              if (components.count >= 2) {
                  NSString *userId = [components lastObject];
                  if ([userId isEqualToString:shortId] && shortId.length > 0) {
                      userExists = YES;
                      break;
                  }
              }
          }
          NSString *actionButtonText = userExists ? @"取消过滤" : @"添加过滤";
          [DYYYBottomAlertView showAlertWithTitle:@"过滤用户视频"
              message:[NSString stringWithFormat:@"用户: %@ (ID: %@)", nickname, shortId]
              cancelButtonText:@"管理过滤列表"
              confirmButtonText:actionButtonText
              cancelAction:^{
            DYYYKeywordListView *keywordListView = [[DYYYKeywordListView alloc] initWithTitle:@"过滤用户列表" keywords:userArray];
            keywordListView.onConfirm = ^(NSArray *users) {
              NSString *userString = [users componentsJoinedByString:@","];
              [[NSUserDefaults standardUserDefaults] setObject:userString forKey:@"DYYYfilterUsers"];
              [[NSUserDefaults standardUserDefaults] synchronize];
              [DYYYManager showToast:@"过滤用户列表已更新"];
            };
            [keywordListView show];
              }
              confirmAction:^{
            // 添加或移除用户过滤
            NSMutableArray *updatedUsers = [NSMutableArray arrayWithArray:userArray];
            if (userExists) {
                // 移除用户
                NSMutableArray *toRemove = [NSMutableArray array];
                for (NSString *userInfo in updatedUsers) {
                    NSArray *components = [userInfo componentsSeparatedByString:@"-"];
                    if (components.count >= 2) {
                        NSString *userId = [components lastObject];
                        if ([userId isEqualToString:shortId]) {
                            [toRemove addObject:userInfo];
                        }
                    }
                }
                [updatedUsers removeObjectsInArray:toRemove];
                [DYYYManager showToast:@"已从过滤列表中移除此用户"];
            } else {
                // 添加用户
                [updatedUsers addObject:currentUserFilter];
                [DYYYManager showToast:@"已添加此用户到过滤列表"];
            }
            // 保存更新后的列表
            NSString *updatedUserString = [updatedUsers componentsJoinedByString:@","];
            [[NSUserDefaults standardUserDefaults] setObject:updatedUserString forKey:@"DYYYfilterUsers"];
            [[NSUserDefaults standardUserDefaults] synchronize];
              }];
        };
        [viewModels addObject:filterKeywords];
    }

    // 过滤文案功能
    if (enableFilterKeyword) {
        AWELongPressPanelBaseViewModel *filterKeywords = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        filterKeywords.awemeModel = self.awemeModel;
        filterKeywords.actionType = 675;
        filterKeywords.duxIconName = @"ic_funnel_outlined_20";
        filterKeywords.describeString = @"过滤文案";
        filterKeywords.action = ^{
          NSString *descText = [self.awemeModel valueForKey:@"descriptionString"];
          if (descText.length > 0) {
              // 获取保存的过滤关键词列表
              NSString *savedKeywords = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYfilterKeywords"] ?: @"";
              NSArray *keywordArray = [savedKeywords length] > 0 ? [savedKeywords componentsSeparatedByString:@","] : @[];
              
              DYYYCustomInputView *inputView = [[DYYYCustomInputView alloc] initWithTitle:@"添加过滤关键词" defaultText:@"" placeholder:@"请输入要过滤的关键词"];
              inputView.onConfirm = ^(NSString *keyword) {
                  if (keyword.length > 0) {
                      NSMutableArray *updatedKeywords = [NSMutableArray arrayWithArray:keywordArray];
                      [updatedKeywords addObject:keyword];
                      NSString *keywordString = [updatedKeywords componentsJoinedByString:@","];
                      [[NSUserDefaults standardUserDefaults] setObject:keywordString forKey:@"DYYYfilterKeywords"];
                      [[NSUserDefaults standardUserDefaults] synchronize];
                      [DYYYManager showToast:@"过滤关键词已添加"];
                  }
              };
              [inputView show];
          } else {
              [DYYYManager showToast:@"该视频没有文案"];
          }
          
          AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
          [panelManager dismissWithAnimation:YES completion:nil];
        };
        [viewModels addObject:filterKeywords];
    }
    
    if (enableTimerClose) {
        AWELongPressPanelBaseViewModel *timerCloseViewModel = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        timerCloseViewModel.awemeModel = self.awemeModel;
        timerCloseViewModel.actionType = 676;
        timerCloseViewModel.duxIconName = @"ic_c_alarm_outlined";
        // 检查是否已有定时任务在运行
        NSNumber *shutdownTime = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYTimerShutdownTime"];
        BOOL hasActiveTimer = shutdownTime != nil && [shutdownTime doubleValue] > [[NSDate date] timeIntervalSince1970];
        timerCloseViewModel.describeString = hasActiveTimer ? @"取消定时" : @"定时关闭";
        timerCloseViewModel.action = ^{
          AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
          [panelManager dismissWithAnimation:YES completion:nil];
          NSNumber *shutdownTime = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYTimerShutdownTime"];
          BOOL hasActiveTimer = shutdownTime != nil && [shutdownTime doubleValue] > [[NSDate date] timeIntervalSince1970];
          if (hasActiveTimer) {
              [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"DYYYTimerShutdownTime"];
              [[NSUserDefaults standardUserDefaults] synchronize];
              [DYYYManager showToast:@"已取消定时关闭任务"];
              return;
          }
          // 读取上次设置的时间
          NSInteger defaultMinutes = [[NSUserDefaults standardUserDefaults] integerForKey:@"DYYYTimerCloseMinutes"];
          if (defaultMinutes <= 0) {
              defaultMinutes = 5;
          }
          NSString *defaultText = [NSString stringWithFormat:@"%ld", (long)defaultMinutes];
          DYYYCustomInputView *inputView = [[DYYYCustomInputView alloc] initWithTitle:@"设置定时关闭时间" defaultText:defaultText placeholder:@"请输入关闭时间(单位:分钟)"];
          inputView.onConfirm = ^(NSString *inputText) {
            NSInteger minutes = [inputText integerValue];
            if (minutes <= 0) {
                minutes = 5;
            }
            // 保存用户设置的时间以供下次使用
            [[NSUserDefaults standardUserDefaults] setInteger:minutes forKey:@"DYYYTimerCloseMinutes"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            NSInteger seconds = minutes * 60;
            NSTimeInterval shutdownTimeValue = [[NSDate date] timeIntervalSince1970] + seconds;
            [[NSUserDefaults standardUserDefaults] setObject:@(shutdownTimeValue) forKey:@"DYYYTimerShutdownTime"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            [DYYYManager showToast:[NSString stringWithFormat:@"抖音将在%ld分钟后关闭...", (long)minutes]];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(seconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
              NSNumber *currentShutdownTime = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYTimerShutdownTime"];
              if (currentShutdownTime != nil && [currentShutdownTime doubleValue] <= [[NSDate date] timeIntervalSince1970]) {
                  [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"DYYYTimerShutdownTime"];
                  [[NSUserDefaults standardUserDefaults] synchronize];
                  // 显示确认关闭弹窗，而不是直接退出
                  DYYYConfirmCloseView *confirmView = [[DYYYConfirmCloseView alloc] initWithTitle:@"定时关闭" message:@"定时关闭时间已到，是否关闭抖音？"];
                  [confirmView show];
              }
            });
          };
          [inputView show];
        };
        [viewModels addObject:timerCloseViewModel];
    }    

    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYEnableAdvancedSettings"] || 
        ![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYEnableAdvancedSettings"]) {
        AWELongPressPanelBaseViewModel *advancedFunctions = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        advancedFunctions.awemeModel = self.awemeModel;
        advancedFunctions.actionType = 674;
        advancedFunctions.duxIconName = @"ic_xiaoxihuazhonghua_outlined";
        advancedFunctions.describeString = @"更多功能";

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

            // 清除抖音设置选项
            [alert addAction:[UIAlertAction actionWithTitle:@"清除抖音设置" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [DYYYBottomAlertView showAlertWithTitle:@"清除抖音设置"
                        message:@"确定要清除抖音所有设置吗？\n这将无法恢复，应用会自动退出！"
                       cancelButtonText:@"取消"
                      confirmButtonText:@"确定"
                       cancelAction:nil
                      confirmAction:^{
                        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
                        if (paths.count > 0) {
                        NSString *preferencesPath = [paths.firstObject stringByAppendingPathComponent:@"Preferences"];
                        NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
                        NSString *plistPath = [preferencesPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist", bundleIdentifier]];

                        NSError *error = nil;
                        [[NSFileManager defaultManager] removeItemAtPath:plistPath error:&error];

                        if (!error) {
                            [DYYYManager showToast:@"抖音设置已清除，应用即将退出"];

                            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                              exit(0);
                            });
                        } else {
                            [DYYYManager showToast:[NSString stringWithFormat:@"清除失败: %@", error.localizedDescription]];
                        }
                        }
                      }];
            }]];

            // 清除插件设置选项
            [alert addAction:[UIAlertAction actionWithTitle:@"清除插件设置" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [DYYYBottomAlertView showAlertWithTitle:@"清除插件设置"
                        message:@"确定要清除所有插件设置吗？\n这将无法恢复！"
                       cancelButtonText:@"取消"
                      confirmButtonText:@"确定"
                       cancelAction:nil
                      confirmAction:^{
                        // 获取所有以DYYY开头的NSUserDefaults键值并清除
                        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                        NSDictionary *allDefaults = [defaults dictionaryRepresentation];

                        for (NSString *key in allDefaults.allKeys) {
                        if ([key hasPrefix:@"DYYY"]) {
                            [defaults removeObjectForKey:key];
                        }
                        }
                        [defaults synchronize];

                        // 显示成功提示
                        [DYYYManager showToast:@"插件设置已清除，请重启应用"];
                      }];
            }]];

            // 清理缓存选项
            [alert addAction:[UIAlertAction actionWithTitle:@"清理缓存" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [DYYYBottomAlertView showAlertWithTitle:@"清理缓存"
                      message:@"确定要清理缓存吗？\n这将删除临时文件和缓存"
                     cancelButtonText:@"取消"
                    confirmButtonText:@"确定"
                     cancelAction:nil
                    confirmAction:^{
                      NSFileManager *fileManager = [NSFileManager defaultManager];
                      NSUInteger totalSize = 0;

                      // 临时目录
                      NSString *tempDir = NSTemporaryDirectory();

                      // Library目录下的缓存目录
                      NSArray<NSString *> *customDirs = @[ @"Caches", @"BDByteCast", @"kitelog" ];
                      NSString *libraryDir = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).firstObject;

                      NSMutableArray<NSString *> *allPaths = [NSMutableArray arrayWithObject:tempDir];
                      for (NSString *sub in customDirs) {
                          NSString *fullPath = [libraryDir stringByAppendingPathComponent:sub];
                          if ([fileManager fileExistsAtPath:fullPath]) {
                          [allPaths addObject:fullPath];
                          }
                      }

                      // 遍历所有目录并清理
                      for (NSString *basePath in allPaths) {
                          totalSize += [DYYYUtils clearDirectoryContents:basePath];
                      }

                      float sizeInMB = totalSize / 1024.0 / 1024.0;
                      NSString *toastMsg = [NSString stringWithFormat:@"已清理 %.2f MB 的缓存", sizeInMB];
                      [DYYYManager showToast:toastMsg];
                    }];
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

    // 如果没有自定义按钮需要添加，直接返回
    if (viewModels.count == 0) {
        return [self applyOriginalArrayFilters:originalArray];
    }

    NSMutableArray<AWELongPressPanelViewGroupModel *> *customGroups = [NSMutableArray array];
    NSInteger totalButtons = viewModels.count;
    
    // 改进的按钮分布逻辑
    NSArray<NSNumber *> *distribution = [self calculateButtonDistribution:totalButtons];
    NSInteger currentIndex = 0;
    
    for (NSNumber *rowCount in distribution) {
        NSInteger count = rowCount.integerValue;
        if (count > 0 && currentIndex < totalButtons) {
            NSRange range = NSMakeRange(currentIndex, MIN(count, totalButtons - currentIndex));
            NSArray<AWELongPressPanelBaseViewModel *> *rowButtons = [viewModels subarrayWithRange:range];
            
            AWELongPressPanelViewGroupModel *rowGroup = [self createCustomGroup:rowButtons];
            [customGroups addObject:rowGroup];
            
            currentIndex += count;
        }
    }
    
    // 对原始数组应用过滤器
    NSArray *filteredOriginalArray = [self applyOriginalArrayFilters:originalArray];
    
    return [customGroups arrayByAddingObjectsFromArray:filteredOriginalArray];
}

%new
- (NSArray<NSNumber *> *)calculateButtonDistribution:(NSInteger)totalButtons {
    // 优化的分布算法
    static NSDictionary<NSNumber *, NSArray<NSNumber *> *> *distributionMap;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        distributionMap = @{
            @1: @[@1],
            @2: @[@2],
            @3: @[@3],
            @4: @[@2, @2],
            @5: @[@3, @2],
            @6: @[@3, @3],
            @7: @[@4, @3],
            @8: @[@4, @4],
            @9: @[@5, @4],
            @10: @[@5, @5]
        };
    });
    
    NSArray<NSNumber *> *distribution = distributionMap[@(totalButtons)];
    if (distribution) {
        return distribution;
    }
    
    // 超过10个按钮的后备方案
    NSMutableArray<NSNumber *> *result = [NSMutableArray array];
    NSInteger remaining = totalButtons;
    while (remaining > 0) {
        NSInteger rowSize = MIN(5, remaining);
        [result addObject:@(rowSize)];
        remaining -= rowSize;
    }
    
    return result;
}

%new
- (AWELongPressPanelViewGroupModel *)createCustomGroup:(NSArray<AWELongPressPanelBaseViewModel *> *)buttons {
    AWELongPressPanelViewGroupModel *group = [[%c(AWELongPressPanelViewGroupModel) alloc] init];
    group.isDYYYCustomGroup = YES;
    group.groupType = (buttons.count <= 3) ? 11 : 12;
    group.isModern = YES;
    group.groupArr = buttons;
    return group;
}

%new
- (NSArray *)applyOriginalArrayFilters:(NSArray *)originalArray {
    if (originalArray.count == 0) {
        return originalArray;
    }
    
    // 缓存用户默认设置检查
    static BOOL hideDaily = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        hideDaily = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHidePanelDaily"];
    });
    
    if (!hideDaily) {
        return originalArray;
    }
    
    // 应用日常过滤器
    NSMutableArray *modifiedArray = [originalArray mutableCopy];
    if (modifiedArray.count > 0) {
        AWELongPressPanelViewGroupModel *firstGroup = modifiedArray[0];
        if (firstGroup.groupArr.count > 1) {
            NSMutableArray *groupArray = [firstGroup.groupArr mutableCopy];
            
            // 更稳健的日常转发按钮检查
            for (NSInteger i = groupArray.count - 1; i >= 0; i--) {
                NSString *description = [groupArray[i] valueForKey:@"describeString"];
                if ([description isEqualToString:@"转发到日常"]) {
                    [groupArray removeObjectAtIndex:i];
                    break; // 只移除第一个匹配项
                }
            }
            
            firstGroup.groupArr = [groupArray copy];
            modifiedArray[0] = firstGroup;
        }
    }
    
    return [modifiedArray copy];
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

// 隐藏评论分享功能
%hook AWEIMCommentShareUserHorizontalCollectionViewCell

- (void)layoutSubviews {
    %orig;

    // 根据设置决定是否隐藏评论分享功能
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideCommentShareToFriends"]) {
        self.hidden = YES;
    } else {
        self.hidden = NO;
    }
}

%end

%hook AWEIMCommentShareUserHorizontalSectionController

- (CGSize)sizeForItemAtIndex:(NSInteger)index model:(id)model collectionViewSize:(CGSize)size {
    // 如果设置了隐藏评论分享功能，返回零大小
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideCommentShareToFriends"]) {
        return CGSizeZero;
    }
    return %orig;
}

- (void)configCell:(id)cell index:(NSInteger)index model:(id)model {
    // 如果设置了隐藏评论分享功能，不进行配置
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideCommentShareToFriends"]) {
        return;
    }
    %orig;
}

%end

// 定义过滤设置的钩子组
%group DYYYFilterSetterGroup

%hook HOOK_TARGET_OWNER_CLASS

- (void)setModelsArray:(id)arg1 {
    // 检查参数是否为数组类型
    if (![arg1 isKindOfClass:[NSArray class]]) {
        %orig(arg1);
        return;
    }

    NSArray *inputArray = (NSArray *)arg1;
    NSMutableArray *filteredArray = nil;

    // 遍历数组中的每个项目
    for (id item in inputArray) {
        NSString *className = NSStringFromClass([item class]);

        // 根据类名和用户设置决定是否过滤
        BOOL shouldFilter = ([className isEqualToString:@"AWECommentIMSwiftImpl.CommentLongPressPanelForwardElement"] &&
                     [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideCommentLongPressDaily"]) ||

                    ([className isEqualToString:@"AWECommentLongPressPanelSwiftImpl.CommentLongPressPanelCopyElement"] &&
                     [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideCommentLongPressCopy"]) ||

                    ([className isEqualToString:@"AWECommentLongPressPanelSwiftImpl.CommentLongPressPanelSaveImageElement"] &&
                     [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideCommentLongPressSaveImage"]) ||

                    ([className isEqualToString:@"AWECommentLongPressPanelSwiftImpl.CommentLongPressPanelReportElement"] &&
                     [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideCommentLongPressReport"]) ||

                    ([className isEqualToString:@"AWECommentStudioSwiftImpl.CommentLongPressPanelVideoReplyElement"] &&
                     [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideCommentLongPressVideoReply"]) ||

                    ([className isEqualToString:@"AWECommentSearchSwiftImpl.CommentLongPressPanelPictureSearchElement"] &&
                     [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideCommentLongPressPictureSearch"]) ||

                    ([className isEqualToString:@"AWECommentSearchSwiftImpl.CommentLongPressPanelSearchElement"] &&
                     [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideCommentLongPressSearch"]);

        // 如果需要过滤，创建过滤后的数组
        if (shouldFilter) {
            if (!filteredArray) {
                filteredArray = [NSMutableArray arrayWithCapacity:inputArray.count];
                for (id keepItem in inputArray) {
                    if (keepItem == item)
                        break;
                    [filteredArray addObject:keepItem];
                }
            }
            continue;
        }

        // 将不需要过滤的项加入到过滤后的数组
        if (filteredArray) {
            [filteredArray addObject:item];
        }
    }

    // 如果有过滤操作，使用过滤后的数组，否则使用原始数组
    if (filteredArray) {
        %orig([filteredArray copy]);
    } else {
        %orig(arg1);
    }
}

%end
%end

// 评论长按面板过滤器初始化
%ctor {
    // 设置长按功能默认值
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYLongPressDownload"] == nil) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"DYYYLongPressDownload"];
    }
    
    // 常用子开关默认值
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYLongPressSaveVideo"] == nil) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"DYYYLongPressSaveVideo"];
    }
    
    // 初始化默认的钩子组
    %init(_ungrouped);
    
    // 获取评论长按面板的目标类
    Class ownerClass = objc_getClass("AWECommentLongPressPanelSwiftImpl.CommentLongPressPanelNormalSectionViewModel");
    if (ownerClass) {
        %init(DYYYFilterSetterGroup, HOOK_TARGET_OWNER_CLASS = ownerClass);
    }
}