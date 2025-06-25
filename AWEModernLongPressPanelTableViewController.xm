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

// 自定义分类声明
@interface AWELongPressPanelViewGroupModel (DYYY)
@property (nonatomic, assign) BOOL isDYYYCustomGroup;
@end

@interface AWEModernLongPressPanelTableViewController (DYYY_FLEX)
- (void)fixFLEXMenu:(AWEAwemeModel *)awemeModel;
- (NSArray *)applyOriginalArrayFilters:(NSArray *)originalArray;
- (NSArray<NSNumber *> *)calculateButtonDistribution:(NSInteger)totalButtons;
- (AWELongPressPanelViewGroupModel *)createCustomGroup:(NSArray<AWELongPressPanelBaseViewModel *> *)buttons;
@end

// 颜色选择器声明
@interface AWEModernLongPressPanelTableViewController (DYYY_ColorPicker)
- (void)showColorPicker;
- (void)colorPickerViewControllerDidFinish:(UIColorPickerViewController *)viewController;
- (void)colorPickerViewControllerDidSelectColor:(UIColorPickerViewController *)viewController;
@end

@interface AWEModernLongPressPanelTableViewController (DYYY_ColorPicker_Declare)
- (void)refreshPanelColor;
@end

@interface AWEModernLongPressPanelTableViewController (DYYYBackgroundColorView)
@property (nonatomic, strong) UIView *dyyy_backgroundColorView;
@end

// 属性声明
%hook AWELongPressPanelViewGroupModel
%property(nonatomic, assign) BOOL isDYYYCustomGroup;
%end

%hook UIVisualEffectView

- (void)dyyy_layoutSubviews {
    %orig; // 调用原始 layoutSubviews

    // 颜色参数
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    CGFloat red = [defaults floatForKey:@"DYYYPanelColorRed"];
    CGFloat green = [defaults floatForKey:@"DYYYPanelColorGreen"];
    CGFloat blue = [defaults floatForKey:@"DYYYPanelColorBlue"];
    CGFloat alpha = [defaults floatForKey:@"DYYYPanelColorAlpha"];
    alpha = MAX(alpha, 0.1);
    UIColor *customColor = [UIColor colorWithRed:red green:green blue:blue alpha:alpha];

    // 移除旧的颜色覆盖层
    for (UIView *overlay in self.contentView.subviews) {
        if (overlay.tag == 9999) {
            [overlay removeFromSuperview];
        }
    }
    // 添加新的
    UIView *colorOverlay = [[UIView alloc] initWithFrame:self.bounds];
    colorOverlay.tag = 9999;
    colorOverlay.backgroundColor = customColor;
    colorOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.contentView addSubview:colorOverlay];
    [self.contentView bringSubviewToFront:colorOverlay];
}

%end

// 功能组
%group ColorPickerGroup

%hook AWEModernLongPressPanelTableViewController

%new
- (void)refreshPanelColor {
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYPanelUseCustomColor"] ||
        ![[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYEnableColorPicker"]) {
        return;
    }
    NSArray *groups = nil;
    if ([self respondsToSelector:@selector(dataArray)]) {
        groups = [self performSelector:@selector(dataArray)];
    } else if ([self respondsToSelector:@selector(valueForKey:)]) {
        groups = [self valueForKey:@"dataArray"];
    }
    if (![groups isKindOfClass:[NSArray class]]) return;
    BOOL hasCustomGroup = NO;
    for (AWELongPressPanelViewGroupModel *group in groups) {
        if ([group isDYYYCustomGroup]) {
            hasCustomGroup = YES;
            break;
        }
    }
    if (!hasCustomGroup) return;

    // 延迟执行，确保UI层级已加载
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        CGFloat red = [defaults floatForKey:@"DYYYPanelColorRed"];
        CGFloat green = [defaults floatForKey:@"DYYYPanelColorGreen"];
        CGFloat blue = [defaults floatForKey:@"DYYYPanelColorBlue"];
        CGFloat alpha = [defaults floatForKey:@"DYYYPanelColorAlpha"];
        alpha = MAX(alpha, 0.1);
        UIColor *customColor = [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
        UIView *panelView = self.view;
        if (!panelView) return;
        for (UIView *subview in panelView.subviews) {
            if ([subview isKindOfClass:[UIVisualEffectView class]]) {
                UIVisualEffectView *blurView = (UIVisualEffectView *)subview;
                // 移除旧的颜色覆盖层
                for (UIView *overlay in blurView.contentView.subviews) {
                    if (overlay.tag == 9999) {
                        [overlay removeFromSuperview];
                    }
                }
                // 添加新的颜色覆盖层
                UIView *colorOverlay = [[UIView alloc] initWithFrame:blurView.bounds];
                colorOverlay.tag = 9999;
                colorOverlay.backgroundColor = customColor;
                colorOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                [blurView.contentView addSubview:colorOverlay];
                [blurView.contentView bringSubviewToFront:colorOverlay];
                break;
            }
        }
    });
}

// 显示系统原生颜色选择器
%new
- (void)showColorPicker {
    if (@available(iOS 14.0, *)) {
        // 获取当前保存的颜色（如果有）
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        CGFloat red = [defaults floatForKey:@"DYYYPanelColorRed"] ?: 0.0;
        CGFloat green = [defaults floatForKey:@"DYYYPanelColorGreen"] ?: 0.0;
        CGFloat blue = [defaults floatForKey:@"DYYYPanelColorBlue"] ?: 0.0;
        CGFloat alpha = [defaults floatForKey:@"DYYYPanelColorAlpha"] ?: 1.0;
        
        UIColor *selectedColor = [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
        
        // 创建系统原生颜色选择器
        UIColorPickerViewController *colorPicker = [[UIColorPickerViewController alloc] init];
        // 手动设置代理而不是通过协议声明
        [colorPicker setValue:self forKey:@"delegate"];
        colorPicker.selectedColor = selectedColor;
        colorPicker.supportsAlpha = YES; // 支持透明度调整
        
        // 显示颜色选择器
        UIViewController *topVC = [DYYYManager getActiveTopController];
        [topVC presentViewController:colorPicker animated:YES completion:nil];
    } else {
        // iOS 14以下版本提示
        [DYYYManager showToast:@"需要iOS 14以上系统才能使用此功能"];
    }
}

- (void)viewDidLoad {
    %orig;
    // 初始化背景视图，只添加一次
    if (!self.dyyy_backgroundColorView) {
        UIView *bgView = [[UIView alloc] initWithFrame:self.view.bounds];
        bgView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        bgView.userInteractionEnabled = NO;
        [self.view insertSubview:bgView atIndex:0];
        self.dyyy_backgroundColorView = bgView;
    }
    // 恢复上次保存的颜色
    NSData *colorData = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYBackgroundColor"];
    if (colorData) {
        UIColor *savedColor = [NSKeyedUnarchiver unarchiveObjectWithData:colorData];
        if (savedColor) {
            self.dyyy_backgroundColorView.backgroundColor = savedColor;
        }
    }
    // 只添加一次监听
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleBackgroundColorChanged)
                                                     name:@"DYYYBackgroundColorChanged"
                                                   object:nil];
    });
}

// 颜色选择器完成时，立即设置背景色并保存
%new
- (void)colorPickerViewControllerDidFinish:(UIColorPickerViewController *)viewController {
    UIColor *color = viewController.selectedColor;
    CGFloat r, g, b, a;
    [color getRed:&r green:&g blue:&b alpha:&a];
    [[NSUserDefaults standardUserDefaults] setFloat:r forKey:@"DYYYPanelColorRed"];
    [[NSUserDefaults standardUserDefaults] setFloat:g forKey:@"DYYYPanelColorGreen"];
    [[NSUserDefaults standardUserDefaults] setFloat:b forKey:@"DYYYPanelColorBlue"];
    [[NSUserDefaults standardUserDefaults] setFloat:a forKey:@"DYYYPanelColorAlpha"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    // 刷新面板
    UITableView *tableView = nil;
    if ([self respondsToSelector:@selector(tableView)]) {
        tableView = [self performSelector:@selector(tableView)];
    } else {
        tableView = [self valueForKey:@"tableView"];
    }
    [tableView reloadData];
}

// 颜色选择器实时选择时，立即设置背景色并保存
%new
- (void)colorPickerViewControllerDidSelectColor:(UIColorPickerViewController *)viewController {
    UIColor *color = viewController.selectedColor;
    self.dyyy_backgroundColorView.backgroundColor = color;
    NSData *colorData = [NSKeyedArchiver archivedDataWithRootObject:color];
    [[NSUserDefaults standardUserDefaults] setObject:colorData forKey:@"DYYYBackgroundColor"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"DYYYBackgroundColorChanged" object:nil];
    [self refreshPanelColor]; // 立即刷新
}

// 通知回调，刷新依赖颜色的UI
%new
- (void)handleBackgroundColorChanged {
    NSData *colorData = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYBackgroundColor"];
    if (colorData) {
        UIColor *color = [NSKeyedUnarchiver unarchiveObjectWithData:colorData];
        self.dyyy_backgroundColorView.backgroundColor = color;
    }
}

%new
- (void)dyyy_handlePanelColorChanged {
    // 实时刷新颜色
    [self refreshPanelColor];
}

%new
- (void)fixFLEXMenu:(AWEAwemeModel *)awemeModel {    
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

- (NSArray *)dataArray {
    NSArray *originalArray = %orig;
    if (!originalArray) {
        originalArray = @[];
    }

    // 检查是否启用了任意长按功能
    BOOL hasAnyFeatureEnabled = NO;
    // 检查各个单独的功能开关
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
    // 添加颜色选择器开关检查
    BOOL enableColorPicker = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYEnableColorPicker"];

    // 检查是否有任何功能启用
    hasAnyFeatureEnabled = enableSaveVideo || enableSaveCover || enableSaveAudio || enableSaveCurrentImage || enableSaveAllImages || 
                           enableCopyText || enableCopyLink || enableApiDownload || enableFilterUser || enableFilterKeyword || 
                           enableTimerClose || enableCreateVideo || enableFLEX || enableColorPicker;

    // 获取需要隐藏的按钮设置
    BOOL hideDaily = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideDaily"];
    BOOL hideRecommend = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideRecommend"];
    BOOL hideNotInterested = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideNotInterested"];
    BOOL hideReport = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideReport"];
    BOOL hideSpeed = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideSpeed"];
    BOOL hideClearScreen = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideClearScreen"];
    BOOL hideFavorite = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideFavorite"];
    BOOL hideLater = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideLater"];
    BOOL hideCast = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideCast"];
    BOOL hideOpenInPC = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideOpenInPC"];
    BOOL hideSubtitle = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideSubtitle"];
    BOOL hideAutoPlay = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideAutoPlay"];
    BOOL hideSearchImage = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideSearchImage"];
    BOOL hideListenDouyin = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideListenDouyin"];
    BOOL hideBackgroundPlay = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideBackgroundPlay"];
    BOOL hideBiserial = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideBiserial"];
    BOOL hideTimerclose = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideTimerclose"];

    // 存储处理后的原始组
    NSMutableArray *modifiedOriginalGroups = [NSMutableArray array];

    // 处理原始面板，收集所有未被隐藏的官方按钮
    for (id group in originalArray) {
        if ([group isKindOfClass:%c(AWELongPressPanelViewGroupModel)]) {
            AWELongPressPanelViewGroupModel *groupModel = (AWELongPressPanelViewGroupModel *)group;
            NSMutableArray *filteredGroupArr = [NSMutableArray array];

            for (id item in groupModel.groupArr) {
                if ([item isKindOfClass:%c(AWELongPressPanelBaseViewModel)]) {
                    AWELongPressPanelBaseViewModel *viewModel = (AWELongPressPanelBaseViewModel *)item;
                    NSString *descString = viewModel.describeString;
                    // 根据描述字符串判断按钮类型并决定是否保留
                    BOOL shouldHide = NO;
                    if ([descString isEqualToString:@"转发到日常"] && hideDaily) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"推荐"] && hideRecommend) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"不感兴趣"] && hideNotInterested) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"举报"] && hideReport) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"倍速"] && hideSpeed) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"清屏播放"] && hideClearScreen) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"缓存视频"] && hideFavorite) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"添加至稍后再看"] && hideLater) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"投屏"] && hideCast) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"电脑/Pad打开"] && hideOpenInPC) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"弹幕"] && hideSubtitle) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"弹幕开关"] && hideSubtitle) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"弹幕设置"] && hideSubtitle) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"自动连播"] && hideAutoPlay) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"识别图片"] && hideSearchImage) {
                        shouldHide = YES;
                    } else if (([descString isEqualToString:@"听抖音"] || [descString isEqualToString:@"后台听"] || [descString isEqualToString:@"听视频"]) && hideListenDouyin) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"后台播放设置"] && hideBackgroundPlay) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"首页双列快捷入口"] && hideBiserial) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"定时关闭"] && hideTimerclose) {
                        shouldHide = YES;
                    }

                    if (!shouldHide) {
                        [filteredGroupArr addObject:viewModel];
                    }
                }
            }

            // 如果过滤后的组不为空，则保存原始组结构
            if (filteredGroupArr.count > 0) {
                AWELongPressPanelViewGroupModel *newGroup = [[%c(AWELongPressPanelViewGroupModel) alloc] init];
                newGroup.isDYYYCustomGroup = YES;
                newGroup.groupType = groupModel.groupType;
                newGroup.isModern = YES;
                newGroup.groupArr = filteredGroupArr;
                [modifiedOriginalGroups addObject:newGroup];
            }
        }
    }

    // 如果没有任何功能启用，仅使用官方按钮
    if (!hasAnyFeatureEnabled) {
        // 直接返回修改后的原始组
        return modifiedOriginalGroups;
    }

    // 创建自定义功能按钮
    NSMutableArray *viewModels = [NSMutableArray array];

    BOOL isNewLivePhoto = NO;
    if (self.awemeModel.video) {
        // 尝试通过类型和属性判断
        if (self.awemeModel.awemeType == 2) { // type=2表示实况照片类型
            isNewLivePhoto = YES;
        }
        // 备选方法：检查是否有动画帧属性
        else if ([self.awemeModel.video respondsToSelector:@selector(animatedImageVideoInfo)] && 
                 [self.awemeModel.video valueForKey:@"animatedImageVideoInfo"] != nil) {
            isNewLivePhoto = YES;
        }
        // 最后尝试检查awemeType的额外值
        else if ([self.awemeModel respondsToSelector:@selector(isLongPressAnimatedCover)] &&
                 [[self.awemeModel valueForKey:@"isLongPressAnimatedCover"] boolValue]) {
            isNewLivePhoto = YES;
        }
    }

    // 视频下载功能 (非实况照片才显示)
    if (enableSaveVideo && self.awemeModel.awemeType != 68 && !isNewLivePhoto) {
        AWELongPressPanelBaseViewModel *downloadViewModel = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        downloadViewModel.awemeModel = self.awemeModel;
        downloadViewModel.actionType = 666;
        downloadViewModel.duxIconName = @"ic_boxarrowdownhigh_outlined";
        downloadViewModel.describeString = @"保存视频";
        downloadViewModel.action = ^{
          AWEAwemeModel *awemeModel = self.awemeModel;
          AWEVideoModel *videoModel = awemeModel.video;

          if (videoModel && videoModel.bitrateModels && videoModel.bitrateModels.count > 0) {
              // 优先使用bitrateModels中的最高质量版本
              id highestQualityModel = videoModel.bitrateModels.firstObject;
              NSArray *urlList = nil;
              id playAddrObj = [highestQualityModel valueForKey:@"playAddr"];

              if ([playAddrObj isKindOfClass:%c(AWEURLModel)]) {
                  AWEURLModel *playAddrModel = (AWEURLModel *)playAddrObj;
                  urlList = playAddrModel.originURLList;
              }

              if (urlList && urlList.count > 0) {
                  NSURL *url = [NSURL URLWithString:urlList.firstObject];
                  [DYYYManager downloadMedia:url
                               mediaType:MediaTypeVideo
                              completion:^(BOOL success){
                              }];
              } else {
                  // 备用方法：直接使用h264URL
                  if (videoModel.h264URL && videoModel.h264URL.originURLList.count > 0) {
                      NSURL *url = [NSURL URLWithString:videoModel.h264URL.originURLList.firstObject];
                      [DYYYManager downloadMedia:url
                                   mediaType:MediaTypeVideo
                                  completion:^(BOOL success){
                                  }];
                  }
              }
          }
          AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
          [panelManager dismissWithAnimation:YES completion:nil];
        };
        [viewModels addObject:downloadViewModel];
    }

    //  新版实况照片保存
    if (enableSaveVideo && self.awemeModel.awemeType != 68 && isNewLivePhoto) {
        AWELongPressPanelBaseViewModel *livePhotoViewModel = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        livePhotoViewModel.awemeModel = self.awemeModel;
        livePhotoViewModel.actionType = 679;
        livePhotoViewModel.duxIconName = @"ic_boxarrowdownhigh_outlined";
        livePhotoViewModel.describeString = @"保存实况";
        livePhotoViewModel.action = ^{
          AWEAwemeModel *awemeModel = self.awemeModel;
          AWEVideoModel *videoModel = awemeModel.video;

          // 使用封面URL作为图片URL
          NSURL *imageURL = nil;
          if (videoModel.coverURL && videoModel.coverURL.originURLList.count > 0) {
              imageURL = [NSURL URLWithString:videoModel.coverURL.originURLList.firstObject];
          }

          // 视频URL从视频模型获取
          NSURL *videoURL = nil;
          if (videoModel && videoModel.playURL && videoModel.playURL.originURLList.count > 0) {
              videoURL = [NSURL URLWithString:videoModel.playURL.originURLList.firstObject];
          } else if (videoModel && videoModel.h264URL && videoModel.h264URL.originURLList.count > 0) {
              videoURL = [NSURL URLWithString:videoModel.h264URL.originURLList.firstObject];
          }

          // 下载实况照片
          if (imageURL && videoURL) {
              [DYYYManager downloadLivePhoto:imageURL
                            videoURL:videoURL
                          completion:^{
                          }];
          }

          AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
          [panelManager dismissWithAnimation:YES completion:nil];
        };
        [viewModels addObject:livePhotoViewModel];
    }

    // 当前图片/实况下载功能
    if (enableSaveCurrentImage && self.awemeModel.awemeType == 68 && self.awemeModel.albumImages.count > 0) {
        AWELongPressPanelBaseViewModel *imageViewModel = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        imageViewModel.awemeModel = self.awemeModel;
        imageViewModel.actionType = 669;
        imageViewModel.duxIconName = @"ic_boxarrowdownhigh_outlined";

        if (self.awemeModel.albumImages.count == 1) {
            imageViewModel.describeString = @"保存图片";
        } else {
            imageViewModel.describeString = @"保存当前图片";
        }

        AWEImageAlbumImageModel *currimge = self.awemeModel.albumImages[self.awemeModel.currentImageIndex - 1];
        if (currimge.clipVideo != nil) {
            if (self.awemeModel.albumImages.count == 1) {
                imageViewModel.describeString = @"保存实况";
            } else {
                imageViewModel.describeString = @"保存当前实况";
            }
        }
        imageViewModel.action = ^{
          // 修复了此处逻辑，完全使用原始实现
          AWEAwemeModel *awemeModel = self.awemeModel;
          AWEImageAlbumImageModel *currentImageModel = nil;
          if (awemeModel.currentImageIndex > 0 && awemeModel.currentImageIndex <= awemeModel.albumImages.count) {
              currentImageModel = awemeModel.albumImages[awemeModel.currentImageIndex - 1];
          } else {
              currentImageModel = awemeModel.albumImages.firstObject;
          }
          
          // 查找非.image后缀的URL
          NSURL *downloadURL = nil;
          for (NSString *urlString in currentImageModel.urlList) {
              NSURL *url = [NSURL URLWithString:urlString];
              NSString *pathExtension = [url.path.lowercaseString pathExtension];
              if (![pathExtension isEqualToString:@"image"]) {
                  downloadURL = url;
                  break;
              }
          }

          if (currentImageModel.clipVideo != nil) {
              NSURL *videoURL = [currentImageModel.clipVideo.playURL getDYYYSrcURLDownload];
              [DYYYManager downloadLivePhoto:downloadURL
                            videoURL:videoURL
                          completion:^{
                          }];
          } else if (currentImageModel && currentImageModel.urlList.count > 0) {
              if (downloadURL) {
                  [DYYYManager downloadMedia:downloadURL
                               mediaType:MediaTypeImage
                              completion:^(BOOL success) {
                                if (success) {
                                } else {
                                    [DYYYManager showToast:@"图片保存已取消"];
                                }
                              }];
              } else {
                  [DYYYManager showToast:@"没有找到合适格式的图片"];
              }
          }
          AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
          [panelManager dismissWithAnimation:YES completion:nil];
        };
        [viewModels addObject:imageViewModel];
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

    // 接口解析功能
    NSString *apiKey = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYInterfaceDownload"];
    if (enableApiDownload && apiKey.length > 0) {
        AWELongPressPanelBaseViewModel *apiDownload = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        apiDownload.awemeModel = self.awemeModel;
        apiDownload.actionType = 673;
        apiDownload.duxIconName = @"ic_cloudarrowdown_outlined_20";
        apiDownload.describeString = @"接口解析";
        apiDownload.action = ^{
          NSString *shareLink = [self.awemeModel valueForKey:@"shareURL"];
          if (shareLink.length == 0) {
              [DYYYManager showToast:@"无法获取分享链接"];
              return;
          }
          // 使用封装的方法进行解析下载
          [DYYYManager parseAndDownloadVideoWithShareLink:shareLink apiKey:apiKey];
          AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
          [panelManager dismissWithAnimation:YES completion:nil];
        };
        [viewModels addObject:apiDownload];
    }

    // 封面下载功能
    if (enableSaveCover && self.awemeModel.awemeType != 68) {
        AWELongPressPanelBaseViewModel *coverViewModel = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        coverViewModel.awemeModel = self.awemeModel;
        coverViewModel.actionType = 667;
        coverViewModel.duxIconName = @"ic_boxarrowdownhigh_outlined";
        coverViewModel.describeString = @"保存封面";
        coverViewModel.action = ^{
          AWEAwemeModel *awemeModel = self.awemeModel;
          AWEVideoModel *videoModel = awemeModel.video;
          if (videoModel && videoModel.coverURL && videoModel.coverURL.originURLList.count > 0) {
              NSURL *url = [NSURL URLWithString:videoModel.coverURL.originURLList.firstObject];
              [DYYYManager downloadMedia:url
                               mediaType:MediaTypeImage
                              completion:^(BOOL success) {
                                if (success) {
                                } else {
                                    [DYYYManager showToast:@"封面保存已取消"];
                                }
                              }];
          }
          AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
          [panelManager dismissWithAnimation:YES completion:nil];
        };
        [viewModels addObject:coverViewModel];
    }

    // 音频下载功能
    if (enableSaveAudio) {
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
    }

    // 创建视频功能
    if (enableCreateVideo && self.awemeModel.awemeType == 68) {
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

    // 复制文案功能
    if (enableCopyText) {
        AWELongPressPanelBaseViewModel *copyText = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        copyText.awemeModel = self.awemeModel;
        copyText.actionType = 671;
        copyText.duxIconName = @"ic_xiaoxihuazhonghua_outlined";
        copyText.describeString = @"复制文案";
        copyText.action = ^{
          NSString *descText = [self.awemeModel valueForKey:@"descriptionString"];
          [[UIPasteboard generalPasteboard] setString:descText];
          [DYYYManager showToast:@"文案已复制"];
          AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
          [panelManager dismissWithAnimation:YES completion:nil];
        };
        [viewModels addObject:copyText];
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
          [DYYYManager showToast:@"分享链接已复制"];
          AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
          [panelManager dismissWithAnimation:YES completion:nil];
        };
        [viewModels addObject:copyShareLink];
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
          
          UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"过滤用户视频" 
                                                                                  message:[NSString stringWithFormat:@"用户: %@ (ID: %@)", nickname, shortId]
                                                                           preferredStyle:UIAlertControllerStyleAlert];
          
          [alertController addAction:[UIAlertAction actionWithTitle:@"管理过滤列表" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
            DYYYKeywordListView *keywordListView = [[DYYYKeywordListView alloc] initWithTitle:@"过滤用户列表" keywords:userArray];
            keywordListView.onConfirm = ^(NSArray *users) {
              NSString *userString = [users componentsJoinedByString:@","];
              [[NSUserDefaults standardUserDefaults] setObject:userString forKey:@"DYYYfilterUsers"];
              [[NSUserDefaults standardUserDefaults] synchronize];
              [DYYYManager showToast:@"过滤用户列表已更新"];
            };
            [keywordListView show];
          }]];
          
          [alertController addAction:[UIAlertAction actionWithTitle:actionButtonText style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
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
          }]];
          
          UIViewController *topVC = [DYYYManager getActiveTopController];
          [topVC presentViewController:alertController animated:YES completion:nil];
          
          AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
          [panelManager dismissWithAnimation:YES completion:nil];
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
          DYYYFilterSettingsView *filterView = [[DYYYFilterSettingsView alloc] initWithTitle:@"过滤关键词调整" text:descText];
          filterView.onConfirm = ^(NSString *selectedText) {
            if (selectedText.length > 0) {
                NSString *currentKeywords = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYfilterKeywords"] ?: @"";
                NSString *newKeywords;
                if (currentKeywords.length > 0) {
                    newKeywords = [NSString stringWithFormat:@"%@,%@", currentKeywords, selectedText];
                } else {
                    newKeywords = selectedText;
                }
                [[NSUserDefaults standardUserDefaults] setObject:newKeywords forKey:@"DYYYfilterKeywords"];
                [[NSUserDefaults standardUserDefaults] synchronize];
                [DYYYManager showToast:[NSString stringWithFormat:@"已添加过滤词: %@", selectedText]];
            }
          };
          // 设置过滤关键词按钮回调
          filterView.onKeywordFilterTap = ^{
            // 获取保存的关键词
            NSString *savedKeywords = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYfilterKeywords"] ?: @"";
            NSArray *keywordArray = [savedKeywords length] > 0 ? [savedKeywords componentsSeparatedByString:@","] : @[];
            // 创建并显示关键词列表视图
            DYYYKeywordListView *keywordListView = [[DYYYKeywordListView alloc] initWithTitle:@"设置过滤关键词" keywords:keywordArray];
            // 设置确认回调
            keywordListView.onConfirm = ^(NSArray *keywords) {
              // 将关键词数组转换为逗号分隔的字符串
              NSString *keywordString = [keywords componentsJoinedByString:@","];
              // 保存到用户默认设置
              [[NSUserDefaults standardUserDefaults] setObject:keywordString forKey:@"DYYYfilterKeywords"];
              [[NSUserDefaults standardUserDefaults] synchronize];
              // 显示提示
              [DYYYManager showToast:@"过滤关键词已更新"];
            };
            // 显示关键词列表视图
            [keywordListView show];
          };
          [filterView show];
          AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
          [panelManager dismissWithAnimation:YES completion:nil];
        };
        [viewModels addObject:filterKeywords];
    }

    // 定时关闭功能
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

    // FLEX调试功能
    if (enableFLEX) {
        AWELongPressPanelBaseViewModel *flexViewModel = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        flexViewModel.awemeModel = self.awemeModel;
        flexViewModel.actionType = 675;
        flexViewModel.duxIconName = @"ic_xiaoxihuazhonghua_outlined";
        flexViewModel.describeString = @"FLEX调试";
        flexViewModel.action = ^{            
            // 关闭长按面板
            AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
            [panelManager dismissWithAnimation:YES completion:^{
                [self fixFLEXMenu:self.awemeModel];
            }];
        };
        [viewModels addObject:flexViewModel];
    }
    
    // 添加面板颜色选择器
    if (enableColorPicker) {
        AWELongPressPanelBaseViewModel *colorPickerViewModel = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        colorPickerViewModel.awemeModel = self.awemeModel;
        colorPickerViewModel.actionType = 699; // 自定义操作类型
        colorPickerViewModel.duxIconName = @"ic_xiaoxihuazhonghua_outlined";
        colorPickerViewModel.describeString = @"面板颜色";
        colorPickerViewModel.action = ^{
            // 关闭长按面板
            AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
            [panelManager dismissWithAnimation:YES completion:^{
                // 显示iOS原生颜色选择器
                [self showColorPicker];
            }];
        };
        [viewModels addObject:colorPickerViewModel];
    }

    // 创建自定义组
    NSMutableArray *customGroups = [NSMutableArray array];
    NSInteger totalButtons = viewModels.count;

    // 根据按钮总数确定每行的按钮数
    NSInteger firstRowCount = 0;
    NSInteger secondRowCount = 0;

    // 确定分配方式与原代码相同
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

    // 创建第一行
    if (firstRowCount > 0) {
        NSArray<AWELongPressPanelBaseViewModel *> *firstRowButtons = [viewModels subarrayWithRange:NSMakeRange(0, firstRowCount)];
        AWELongPressPanelViewGroupModel *firstRowGroup = [[%c(AWELongPressPanelViewGroupModel) alloc] init];
        firstRowGroup.isDYYYCustomGroup = YES;
        firstRowGroup.groupType = (firstRowCount <= 3) ? 11 : 12;
        firstRowGroup.isModern = YES;
        firstRowGroup.groupArr = firstRowButtons;
        [customGroups addObject:firstRowGroup];
    }

    // 创建第二行
    if (secondRowCount > 0) {
        NSArray<AWELongPressPanelBaseViewModel *> *secondRowButtons = [viewModels subarrayWithRange:NSMakeRange(firstRowCount, secondRowCount)];
        AWELongPressPanelViewGroupModel *secondRowGroup = [[%c(AWELongPressPanelViewGroupModel) alloc] init];
        secondRowGroup.isDYYYCustomGroup = YES;
        secondRowGroup.groupType = (secondRowCount <= 3) ? 11 : 12;
        secondRowGroup.isModern = YES;
        secondRowGroup.groupArr = secondRowButtons;
        [customGroups addObject:secondRowGroup];
    }

    // 准备最终结果数组
    NSMutableArray *resultArray = [NSMutableArray arrayWithArray:customGroups];

    // 添加修改后的原始组
    [resultArray addObjectsFromArray:modifiedOriginalGroups];

    return resultArray;
}

// 应用自定义颜色设置
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    [self refreshPanelColor];
    
    // 检查是否开启颜色设置且有自定义颜色
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYPanelUseCustomColor"] &&
        [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYEnableColorPicker"]) {
        
        // 获取保存的颜色值
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        CGFloat red = [defaults floatForKey:@"DYYYPanelColorRed"];
        CGFloat green = [defaults floatForKey:@"DYYYPanelColorGreen"];
        CGFloat blue = [defaults floatForKey:@"DYYYPanelColorBlue"];
        CGFloat alpha = [defaults floatForKey:@"DYYYPanelColorAlpha"];
        
        // 确保alpha不为0，至少有一点透明度
        alpha = MAX(alpha, 0.1);
        
        // 创建颜色
        UIColor *customColor = [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
        
        // 添加日志用于调试
        NSLog(@"DYYY: viewWillAppear应用颜色 - R:%.2f G:%.2f B:%.2f A:%.2f", red, green, blue, alpha);
        
        // 应用颜色到背景
        UIView *panelView = self.view;
        if (!panelView) {
            NSLog(@"DYYY: 面板视图为空");
            return;
        }
        
        // 查找视觉效果视图
        for (UIView *subview in panelView.subviews) {
            if ([subview isKindOfClass:[UIVisualEffectView class]]) {
                UIVisualEffectView *blurView = (UIVisualEffectView *)subview;
                NSLog(@"DYYY: 找到模糊效果视图");
                
                // 清除旧的颜色视图
                for (UIView *overlayView in blurView.contentView.subviews) {
                    if (overlayView.tag == 9999) {
                        [overlayView removeFromSuperview];
                        NSLog(@"DYYY: 移除旧的颜色覆盖层");
                    }
                }
                
                // 添加颜色覆盖层
                UIView *colorOverlay = [[UIView alloc] initWithFrame:blurView.bounds];
                colorOverlay.tag = 9999;
                colorOverlay.backgroundColor = customColor;
                colorOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                [blurView.contentView addSubview:colorOverlay];
                
                // 确保覆盖层在最前面
                [blurView.contentView bringSubviewToFront:colorOverlay];
                NSLog(@"DYYY: 添加新的颜色覆盖层");
                break;
            }
        }
    }
}

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    [self refreshPanelColor];

    // swizzle UIVisualEffectView的layoutSubviews，只做一次
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class blurClass = objc_getClass("UIVisualEffectView");
        Method origMethod = class_getInstanceMethod(blurClass, @selector(layoutSubviews));
        Method newMethod = class_getInstanceMethod(blurClass, @selector(dyyy_layoutSubviews));
        method_exchangeImplementations(origMethod, newMethod);
    });
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
    
    // 修改这里的键名，删除"Panel"
    BOOL hideDaily = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideDaily"];
    BOOL hideRecommend = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideRecommend"];
    BOOL hideNotInterested = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideNotInterested"];
    BOOL hideReport = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideReport"];
    BOOL hideSpeed = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideSpeed"];
    BOOL hideClearScreen = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideClearScreen"];
    BOOL hideFavorite = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideFavorite"];
    BOOL hideLater = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideLater"];
    BOOL hideCast = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideCast"];
    BOOL hideOpenInPC = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideOpenInPC"];
    BOOL hideSubtitle = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideSubtitle"];
    BOOL hideAutoPlay = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideAutoPlay"];
    BOOL hideSearchImage = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideSearchImage"];
    BOOL hideListenDouyin = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideListenDouyin"];
    BOOL hideBackgroundPlay = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideBackgroundPlay"];
    BOOL hideBiserial = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideBiserial"];
    BOOL hideTimerclose = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideTimerclose"];
    
    // 创建修改后的结果数组
    NSMutableArray *modifiedArray = [NSMutableArray array];
    
    // 处理每个组
    for (id group in originalArray) {
        if ([group isKindOfClass:%c(AWELongPressPanelViewGroupModel)]) {
            AWELongPressPanelViewGroupModel *groupModel = (AWELongPressPanelViewGroupModel *)group;
            NSMutableArray *filteredGroupArr = [NSMutableArray array];
            
            // 过滤每个组内的项
            for (id item in groupModel.groupArr) {
                if ([item isKindOfClass:%c(AWELongPressPanelBaseViewModel)]) {
                    AWELongPressPanelBaseViewModel *viewModel = (AWELongPressPanelBaseViewModel *)item;
                    NSString *descString = viewModel.describeString;
                    
                    // 检查是否需要隐藏
                    BOOL shouldHide = NO;
                    if ([descString isEqualToString:@"转发到日常"] && hideDaily) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"推荐"] && hideRecommend) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"不感兴趣"] && hideNotInterested) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"举报"] && hideReport) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"倍速"] && hideSpeed) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"清屏播放"] && hideClearScreen) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"缓存视频"] && hideFavorite) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"添加至稍后再看"] && hideLater) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"投屏"] && hideCast) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"电脑/Pad打开"] && hideOpenInPC) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"弹幕"] && hideSubtitle) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"弹幕开关"] && hideSubtitle) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"弹幕设置"] && hideSubtitle) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"自动连播"] && hideAutoPlay) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"识别图片"] && hideSearchImage) {
                        shouldHide = YES;
                    } else if (([descString isEqualToString:@"听抖音"] || [descString isEqualToString:@"后台听"] || [descString isEqualToString:@"听视频"]) && hideListenDouyin) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"后台播放设置"] && hideBackgroundPlay) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"首页双列快捷入口"] && hideBiserial) {
                        shouldHide = YES;
                    } else if ([descString isEqualToString:@"定时关闭"] && hideTimerclose) {
                        shouldHide = YES;
                    }
                    
                    if (!shouldHide) {
                        [filteredGroupArr addObject:viewModel];
                    }
                }
            }
            
            // 如果过滤后的组不为空，添加到结果中
            if (filteredGroupArr.count > 0) {
                AWELongPressPanelViewGroupModel *newGroup = [[%c(AWELongPressPanelViewGroupModel) alloc] init];
                newGroup.isDYYYCustomGroup = YES; // 确保标记为自定义组
                newGroup.groupType = groupModel.groupType;
                newGroup.isModern = YES; // 确保标记为现代风格
                newGroup.groupArr = filteredGroupArr;
                [modifiedArray addObject:newGroup];
            }
        }
    }
    
    return modifiedArray;
}

%end

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

%hook AWEIMCommentShareUserHorizontalCollectionViewCell

- (void)layoutSubviews {
    %orig;

    id groupModel = nil;
    if ([self respondsToSelector:@selector(longPressViewGroupModel)]) {
        groupModel = [self performSelector:@selector(longPressViewGroupModel)];
    } else {
        groupModel = [self valueForKey:@"longPressViewGroupModel"];
    }
    if (groupModel && [groupModel isDYYYCustomGroup]) {
        UIView *contentView = nil;
        if ([self respondsToSelector:@selector(contentView)]) {
            contentView = [self performSelector:@selector(contentView)];
        } else {
            contentView = [self valueForKey:@"contentView"];
        }
        for (UIView *subview in contentView.subviews) {
            if ([subview isKindOfClass:[UIVisualEffectView class]]) {
                UIVisualEffectView *blurView = (UIVisualEffectView *)subview;
                // 移除旧的颜色层
                for (UIView *overlay in blurView.contentView.subviews) {
                    if (overlay.tag == 9999) {
                        [overlay removeFromSuperview];
                    }
                }
                // 读取颜色
                NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                CGFloat red = [defaults floatForKey:@"DYYYPanelColorRed"];
                CGFloat green = [defaults floatForKey:@"DYYYPanelColorGreen"];
                CGFloat blue = [defaults floatForKey:@"DYYYPanelColorBlue"];
                CGFloat alpha = [defaults floatForKey:@"DYYYPanelColorAlpha"];
                alpha = MAX(alpha, 0.1);
                UIColor *customColor = [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
                // 添加新颜色层
                UIView *colorOverlay = [[UIView alloc] initWithFrame:blurView.bounds];
                colorOverlay.tag = 9999;
                colorOverlay.backgroundColor = customColor;
                colorOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                [blurView.contentView addSubview:colorOverlay];
                [blurView.contentView bringSubviewToFront:colorOverlay];
            }
        }
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

%ctor {
    // 设置长按功能默认值
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYLongPressDownload"] == nil) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"DYYYLongPressDownload"];
    }
    
    // 常用子开关默认值
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYLongPressSaveVideo"] == nil) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"DYYYLongPressSaveVideo"];
    }
    
    // 添加颜色选择器默认值
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYEnableColorPicker"] == nil) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"DYYYEnableColorPicker"];
    }
    
    // 初始化默认的钩子组
    %init(_ungrouped);
    
    // 初始化颜色选择器钩子组
    %init(ColorPickerGroup);
    
    // 检查评论面板类 - 先尝试第一个类名，不存在时再尝试备用类名
    Class ownerClass = objc_getClass("AWECommentLongPressPanelSwiftImpl.CommentLongPressPanelNormalSectionViewModel");
    if (!ownerClass) {
        // 如果第一个类不存在，尝试备用类名
        ownerClass = objc_getClass("AWECommentLongPressPanel.NormalSectionViewModel");
    }
    
    // 只在找到可用的类时初始化过滤器组
    if (ownerClass) {
        NSLog(@"DYYY: 成功找到评论面板类: %@", NSStringFromClass(ownerClass));
        // 使用正确的方式初始化
        %init(DYYYFilterSetterGroup, HOOK_TARGET_OWNER_CLASS=ownerClass);
    } else {
        NSLog(@"DYYY: 未找到任何评论面板类，无法初始化过滤器组");
    }
}