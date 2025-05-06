#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "AwemeHeaders.h"
#import "DYYYManager.h"
#import "FLEXHeaders.h"

// 添加颜色圆圈图像生成函数声明
UIImage *createColorCircleImage(UIColor *color, CGSize size) {
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    [color setFill];
    [[UIColor whiteColor] setStroke];
    UIBezierPath *path = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(1, 1, size.width - 2, size.height - 2)];
    path.lineWidth = 1.0;
    [path fill];
    [path stroke];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

// 为AWEPlayInteractionViewController添加接口声明
@interface AWEPlayInteractionViewController (DYYYAdditions)
- (void)createFluentDesignDraggableMenuWithAwemeModel:(AWEAwemeModel *)awemeModel touchPoint:(CGPoint)touchPoint;
- (void)dismissFluentMenu:(UITapGestureRecognizer *)gesture;
- (void)dismissFluentMenuByButton:(UIButton *)button;
- (void)handleModuleDrag:(UILongPressGestureRecognizer *)gesture;
- (void)handleModuleTap:(UITapGestureRecognizer *)gesture;
- (void)resetModulePositions:(UIButton *)sender;
- (void)showDYYYSettingPanelFromMenuButton:(UIButton *)button;
- (void)dismissDYYYSettingPanel:(UIButton *)button;
- (void)dyyy_avatarTapped:(UITapGestureRecognizer *)gesture;
- (void)dyyy_albumTapped:(UITapGestureRecognizer *)gesture;
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info;
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker;
- (void)refreshDYYYAvatarAndAlbum;
- (void)moduleButtonTouchDown:(UIButton *)sender;
- (void)moduleButtonTouchUp:(UIButton *)sender;
- (void)handleModuleButtonTap:(UIButton *)sender;
- (void)resizeMenuPan:(UIPanGestureRecognizer *)pan;
- (void)customMenuButtonTapped:(UIButton *)button;
- (void)handleDYYYBackgroundColorChanged:(NSNotification *)notification;
- (void)dyyy_handleSettingPanelPan:(UIPanGestureRecognizer *)pan;
- (void)toggleBlurStyle:(UIButton *)button;
- (void)showBlurColorPicker:(UIButton *)button;
- (void)updateBlurEffectWithColor:(UIColor *)color;
- (void)updateColorPickerButtonWithColor:(UIColor *)color;
- (UIImage *)imageWithColor:(UIColor *)color size:(CGSize)size;
- (void)refreshCurrentView;
- (void)showVideoDebugInfo:(AWEAwemeModel *)model;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 140000
- (void)colorPickerViewControllerDidSelectColor:(UIColorPickerViewController *)viewController API_AVAILABLE(ios(14.0));
- (void)colorPickerViewControllerDidFinish:(UIColorPickerViewController *)viewController API_AVAILABLE(ios(14.0));
#endif
@end

%hook AWEPlayInteractionViewController

- (void)onVideoPlayerViewDoubleClicked:(id)arg1 {
    BOOL isSwitchOn = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYDouble"];
    if (!isSwitchOn) {
        %orig;
    }
}

- (void)viewDidLayoutSubviews {
    %orig;
    if (![self.parentViewController isKindOfClass:%c(AWEFeedCellViewController)]) {
        return;
    }
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnableFullScreen"]) {
        CGRect frame = self.view.frame;
        frame.size.height = self.view.superview.frame.size.height - 83;
        self.view.frame = frame;
    }
}

- (void)onPlayer:(id)arg0 didDoubleClick:(id)arg1 {
    BOOL isPopupEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYEnableDoubleOpenAlertController"];
    BOOL isDirectCommentEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYEnableDoubleOpenComment"];

    if (isDirectCommentEnabled) {
        [self performCommentAction];
        return;
    }

    if (isPopupEnabled) {
        AWEAwemeModel *awemeModel = nil;

        if ([self respondsToSelector:@selector(awemeModel)]) {
            awemeModel = [self performSelector:@selector(awemeModel)];
        } else if ([self respondsToSelector:@selector(currentAwemeModel)]) {
            awemeModel = [self performSelector:@selector(currentAwemeModel)];
        } else if ([self respondsToSelector:@selector(getAwemeModel)]) {
            awemeModel = [self performSelector:@selector(getAwemeModel)];
        }

        if (!awemeModel) {
            UIViewController *baseVC = [self valueForKey:@"awemeBaseViewController"];
            if (baseVC && [baseVC respondsToSelector:@selector(model)]) {
                awemeModel = [baseVC performSelector:@selector(model)];
            } else if (baseVC && [baseVC respondsToSelector:@selector(awemeModel)]) {
                awemeModel = [baseVC performSelector:@selector(awemeModel)];
            }
        }

        if (!awemeModel) {
            %orig;
            return;
        }

        [self createFluentDesignDraggableMenuWithAwemeModel:awemeModel touchPoint:[arg1 locationInView:self.view]];
        return;
    }

    %orig;
}

%new
- (void)createFluentDesignDraggableMenuWithAwemeModel:(AWEAwemeModel *)awemeModel touchPoint:(CGPoint)touchPoint {
    UIViewController *topVC = [DYYYManager getActiveTopController];
    if (!topVC) return;
    for (UIView *view in topVC.view.subviews) {
        if (view.tag == 9527) {
            [view removeFromSuperview];
        }
    }
    // 创建透明背景
    UIView *overlayView = [[UIView alloc] initWithFrame:topVC.view.bounds];
    overlayView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.3]; // 半透明黑色背景
    overlayView.alpha = 0;
    overlayView.tag = 9527;

    // 监听背景色变化
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDYYYBackgroundColorChanged:) name:@"DYYYBackgroundColorChanged" object:nil];

    CGFloat menuHeight = 480;
    CGFloat menuWidth = topVC.view.bounds.size.width;
    CGFloat bottomSafe = 0;
    if (@available(iOS 11.0, *)) {
        bottomSafe = topVC.view.safeAreaInsets.bottom;
    }

    UIView *menuContainer = [[UIView alloc] initWithFrame:CGRectMake(0, topVC.view.bounds.size.height, menuWidth, menuHeight + bottomSafe)];
    menuContainer.layer.cornerRadius = 20;
    menuContainer.clipsToBounds = YES;
    menuContainer.layer.masksToBounds = NO;
    menuContainer.backgroundColor = [UIColor whiteColor]; // 白色弹窗背景
    menuContainer.layer.shadowColor = [UIColor blackColor].CGColor;
    menuContainer.layer.shadowOffset = CGSizeMake(0, -10);
    menuContainer.layer.shadowRadius = 20;
    menuContainer.layer.shadowOpacity = 0.3;
    [overlayView addSubview:menuContainer];

    // 获取保存的颜色
    NSData *colorData = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYBlurEffectColor"];
    UIColor *blurColor = colorData ? [NSKeyedUnarchiver unarchiveObjectWithData:colorData] : nil;
    
    // 决定毛玻璃效果风格
    UIBlurEffectStyle blurStyle = UIBlurEffectStyleLight;
    if (blurColor) {
        CGFloat brightness = 0;
        [blurColor getWhite:&brightness alpha:nil];
        if (brightness < 0.5) {
            // 深色
            if (@available(iOS 13.0, *)) {
                blurStyle = UIBlurEffectStyleSystemMaterialDark;
            } else {
                blurStyle = UIBlurEffectStyleDark;
            }
        }
    } else {
        // 使用默认风格
        BOOL isModernStyle = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnableModern"];
        if (isModernStyle) {
            if (@available(iOS 13.0, *)) {
                blurStyle = UIBlurEffectStyleSystemMaterialDark;
            } else {
                blurStyle = UIBlurEffectStyleDark;
            }
        }
    }

    UIVisualEffectView *contentPanel = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:blurStyle]];
    contentPanel.frame = menuContainer.bounds;
    contentPanel.layer.cornerRadius = 20;
    contentPanel.clipsToBounds = YES;
    [menuContainer addSubview:contentPanel];
    
    // 如果有保存的颜色，应用背景色
    if (blurColor) {
        UIView *colorView = [[UIView alloc] initWithFrame:contentPanel.bounds];
        colorView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        colorView.backgroundColor = [blurColor colorWithAlphaComponent:0.3];
        colorView.tag = 8888;
        [contentPanel.contentView insertSubview:colorView atIndex:0];
    }

    // 头像功能只保留一个，且放在弹窗顶部（headerView之上）
    CGFloat avatarSize = 72;
    UIImageView *avatarImageView = [[UIImageView alloc] initWithFrame:CGRectMake((menuWidth-avatarSize)/2, -avatarSize/2, avatarSize, avatarSize)];
    avatarImageView.layer.cornerRadius = avatarSize/2;
    avatarImageView.clipsToBounds = YES;
    avatarImageView.contentMode = UIViewContentModeScaleAspectFill;

    // 统一读取 DYYYSettingViewController 头像路径
    NSString *avatarPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"DYYYAvatar.jpg"];
    UIImage *avatarImage = [UIImage imageWithContentsOfFile:avatarPath];
    if (!avatarImage) {
        avatarImage = [UIImage systemImageNamed:@"person.circle.fill"];
        avatarImageView.tintColor = [UIColor systemGrayColor];
    }
    avatarImageView.image = avatarImage;
    avatarImageView.userInteractionEnabled = YES;
    UITapGestureRecognizer *avatarTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dyyy_avatarTapped:)];
    [avatarImageView addGestureRecognizer:avatarTap];
    [menuContainer addSubview:avatarImageView]; // 放在menuContainer顶部

    // 头像下方昵称（同步 DYYYSettingViewController 的自定义文本）
    UILabel *avatarLabel = [[UILabel alloc] initWithFrame:CGRectMake((menuWidth-120)/2, avatarImageView.frame.origin.y+avatarSize+2, 120, 18)];
    NSString *customTapText = [[NSUserDefaults standardUserDefaults] stringForKey:@"DYYYAvatarTapText"];
    avatarLabel.text = customTapText.length > 0 ? customTapText : @"pxx917144686";
    avatarLabel.textColor = [UIColor colorWithRed:0.2 green:0.6 blue:1 alpha:1];
    avatarLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    avatarLabel.textAlignment = NSTextAlignmentCenter;
    [menuContainer addSubview:avatarLabel];

    // headerView内移除头像相关代码，只保留菜单按钮和关闭按钮
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, menuWidth, 100)];
    headerView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.1];
    headerView.tag = 100; // 添加标签方便找到
    [contentPanel.contentView addSubview:headerView];

    // 修改为彩色调整大小按钮（右上角）
    UIButton *resizeButton = [UIButton buttonWithType:UIButtonTypeCustom]; // 改为 Custom 类型
    resizeButton.frame = CGRectMake(menuWidth - 130, 20, 30, 30);  // 位置左移，为切换按钮留出空间
    resizeButton.layer.cornerRadius = 15;
    resizeButton.clipsToBounds = YES;

    // 添加渐变背景
    CAGradientLayer *resizeGradient = [CAGradientLayer layer];
    resizeGradient.frame = resizeButton.bounds;
    resizeGradient.cornerRadius = 15;
    resizeGradient.colors = @[
        (id)[UIColor colorWithRed:0.2 green:0.6 blue:1 alpha:0.9].CGColor,
        (id)[UIColor colorWithRed:0.4 green:0.7 blue:1 alpha:0.9].CGColor
    ];
    resizeGradient.startPoint = CGPointMake(0, 0);
    resizeGradient.endPoint = CGPointMake(1, 1);
    [resizeButton.layer insertSublayer:resizeGradient atIndex:0];

    // 单独创建图标视图，添加到按钮上方
    UIImageView *resizeImageView = [[UIImageView alloc] initWithFrame:CGRectMake(5, 5, 20, 20)];
    resizeImageView.contentMode = UIViewContentModeScaleAspectFit;
    UIImage *resizeImage = [UIImage systemImageNamed:@"arrow.up.and.down.circle.fill"];
    resizeImageView.image = [resizeImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    resizeImageView.tintColor = [UIColor whiteColor];
    [resizeButton addSubview:resizeImageView];

    // 添加阴影 - 在父视图添加，避免与圆角冲突
    resizeButton.layer.shadowColor = [UIColor colorWithRed:0.2 green:0.6 blue:1 alpha:0.4].CGColor;
    resizeButton.layer.shadowOffset = CGSizeMake(0, 2);
    resizeButton.layer.shadowRadius = 4;
    resizeButton.layer.shadowOpacity = 0.8;

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(resizeMenuPan:)];
    [resizeButton addGestureRecognizer:pan];
    [resizeButton addTarget:self action:@selector(customMenuButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [headerView addSubview:resizeButton];

    // 在resizeButton旁边添加颜色选择按钮 - 替换原来的切换按钮
    UIButton *colorPickerButton = [UIButton buttonWithType:UIButtonTypeCustom];
    colorPickerButton.frame = CGRectMake(menuWidth - 90, 20, 30, 30); // 放在resizeButton右侧
    colorPickerButton.layer.cornerRadius = 15;
    colorPickerButton.clipsToBounds = YES;

    // 根据保存的颜色创建渐变背景
    CAGradientLayer *toggleGradient = [CAGradientLayer layer];
    toggleGradient.frame = colorPickerButton.bounds;
    toggleGradient.cornerRadius = 15;
    
    // 使用保存的颜色或默认紫色
    UIColor *buttonColor = blurColor ? blurColor : [UIColor colorWithRed:0.5 green:0.3 blue:1.0 alpha:0.9];
    toggleGradient.colors = @[
        (id)[buttonColor colorWithAlphaComponent:0.9].CGColor,
        (id)[buttonColor colorWithAlphaComponent:0.7].CGColor
    ];
    
    toggleGradient.startPoint = CGPointMake(0, 0);
    toggleGradient.endPoint = CGPointMake(1, 1);
    [colorPickerButton.layer insertSublayer:toggleGradient atIndex:0];

    // 单独创建图标视图，添加到按钮上方
    UIImageView *toggleImageView = [[UIImageView alloc] initWithFrame:CGRectMake(5, 5, 20, 20)];
    toggleImageView.contentMode = UIViewContentModeScaleAspectFit;
    UIImage *toggleImage = [UIImage systemImageNamed:@"paintpalette.fill"];  // 更改为取色器图标
    toggleImageView.image = [toggleImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    toggleImageView.tintColor = [UIColor whiteColor];
    [colorPickerButton addSubview:toggleImageView];

    // 添加阴影
    colorPickerButton.layer.shadowColor = [buttonColor colorWithAlphaComponent:0.4].CGColor;
    colorPickerButton.layer.shadowOffset = CGSizeMake(0, 2);
    colorPickerButton.layer.shadowRadius = 4;
    colorPickerButton.layer.shadowOpacity = 0.8;

    // 添加点击事件 - 现在调用颜色选择器
    [colorPickerButton addTarget:self action:@selector(toggleBlurStyle:) forControlEvents:UIControlEventTouchUpInside];

    // 设置按钮标签，用于识别
    colorPickerButton.tag = 200;

    [headerView addSubview:colorPickerButton];

    // 新增关闭按钮，紧挨右侧，使用相同风格
    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeCustom]; // 改为 Custom 类型
    closeButton.frame = CGRectMake(menuWidth - 50, 20, 30, 30);
    closeButton.layer.cornerRadius = 15;
    closeButton.clipsToBounds = YES;

    // 添加渐变背景
    CAGradientLayer *closeGradient = [CAGradientLayer layer];
    closeGradient.frame = closeButton.bounds;
    closeGradient.cornerRadius = 15;
    closeGradient.colors = @[
        (id)[UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:0.9].CGColor,
        (id)[UIColor colorWithRed:1.0 green:0.5 blue:0.5 alpha:0.9].CGColor
    ];
    closeGradient.startPoint = CGPointMake(0, 0);
    closeGradient.endPoint = CGPointMake(1, 1);
    [closeButton.layer insertSublayer:closeGradient atIndex:0];

    // 单独创建图标视图，添加到按钮上方
    UIImageView *closeImageView = [[UIImageView alloc] initWithFrame:CGRectMake(5, 5, 20, 20)];
    closeImageView.contentMode = UIViewContentModeScaleAspectFit;
    UIImage *closeImage = [UIImage systemImageNamed:@"xmark.circle.fill"];
    closeImageView.image = [closeImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    closeImageView.tintColor = [UIColor whiteColor];
    [closeButton addSubview:closeImageView];

    // 添加阴影
    closeButton.layer.shadowColor = [UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:0.4].CGColor;
    closeButton.layer.shadowOffset = CGSizeMake(0, 2);
    closeButton.layer.shadowRadius = 4;
    closeButton.layer.shadowOpacity = 0.8;

    [closeButton addTarget:self action:@selector(dismissFluentMenuByButton:) forControlEvents:UIControlEventTouchUpInside];
    [headerView addSubview:closeButton];

    // 确保按钮显示在最上层
    [headerView bringSubviewToFront:resizeButton];
    [headerView bringSubviewToFront:colorPickerButton];
    [headerView bringSubviewToFront:closeButton];

    // 以下是原有代码...
    // 菜单按钮（彩色）放在左侧，更加高级
    UIButton *menuButton = [UIButton buttonWithType:UIButtonTypeSystem];
    menuButton.frame = CGRectMake(20, 20, 70, 30);
    [menuButton setTitle:@"菜单" forState:UIControlStateNormal];
    menuButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    menuButton.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:1 alpha:0.85];
    [menuButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    menuButton.layer.cornerRadius = 8;
    menuButton.layer.shadowColor = [UIColor colorWithRed:0.2 green:0.6 blue:1 alpha:0.3].CGColor;
    menuButton.layer.shadowOpacity = 0.5;
    menuButton.layer.shadowRadius = 8;
    menuButton.layer.shadowOffset = CGSizeMake(0, 2);
    [menuButton addTarget:self action:@selector(showDYYYSettingPanelFromMenuButton:) forControlEvents:UIControlEventTouchUpInside];
    [headerView addSubview:menuButton];

    BOOL isImageContent = (awemeModel.awemeType == 68);
    UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 100, menuWidth, menuHeight - 100)];
    scrollView.showsVerticalScrollIndicator = YES;
    scrollView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
    [contentPanel.contentView addSubview:scrollView];

    NSMutableArray *menuModules = [NSMutableArray array];
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYDoubleTapDownload"] || ![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYDoubleTapDownload"]) {
        BOOL isLivePhoto = NO;
        AWEImageAlbumImageModel *currentImageModel = nil;
        if (isImageContent) {
            if (awemeModel.currentImageIndex > 0 && awemeModel.currentImageIndex <= awemeModel.albumImages.count) {
                currentImageModel = awemeModel.albumImages[awemeModel.currentImageIndex - 1];
            } else {
                currentImageModel = awemeModel.albumImages.firstObject;
            }
            isLivePhoto = (currentImageModel && currentImageModel.clipVideo != nil);
        }
        NSDictionary *downloadModule = @{
            @"title": isLivePhoto ? @"保存实况照片" : (isImageContent ? @"保存图片" : @"保存视频"),
            @"icon": isLivePhoto ? @"livephoto" : @"arrow.down.circle",
            @"color": isLivePhoto ? @"#FF2D55" : @"#0078D7",
            @"action": ^{
                if (isImageContent) {
                    AWEImageAlbumImageModel *currentImageModel = nil;
                    if (awemeModel.currentImageIndex > 0 && awemeModel.currentImageIndex <= awemeModel.albumImages.count) {
                        currentImageModel = awemeModel.albumImages[awemeModel.currentImageIndex - 1];
                    } else {
                        currentImageModel = awemeModel.albumImages.firstObject;
                    }
                    if (currentImageModel && currentImageModel.clipVideo != nil) {
                        NSURL *photoURL = [NSURL URLWithString:currentImageModel.urlList.firstObject];
                        NSURL *videoURL = [currentImageModel.clipVideo.playURL getDYYYSrcURLDownload];
                        [DYYYManager downloadLivePhoto:photoURL videoURL:videoURL completion:^{
                            [DYYYManager showToast:@"实况照片已保存到相册"];
                        }];
                    } else if (currentImageModel && currentImageModel.urlList.count > 0) {
                        NSURL *url = [NSURL URLWithString:currentImageModel.urlList.firstObject];
                        [DYYYManager downloadMedia:url mediaType:MediaTypeImage completion:^{
                            [DYYYManager showToast:@"图片已保存到相册"];
                        }];
                    }
                } else {
                    AWEVideoModel *videoModel = awemeModel.video;
                    if (videoModel && videoModel.h264URL && videoModel.h264URL.originURLList.count > 0) {
                        NSURL *url = [NSURL URLWithString:videoModel.h264URL.originURLList.firstObject];
                        [DYYYManager downloadMedia:url mediaType:MediaTypeVideo completion:^{
                            [DYYYManager showToast:@"视频已保存到相册"];
                        }];
                    }
                }
            }
        };
        [menuModules addObject:downloadModule];
        if (isImageContent && awemeModel.albumImages.count > 1) {
            BOOL hasLivePhoto = NO;
            for (AWEImageAlbumImageModel *imageModel in awemeModel.albumImages) {
                if (imageModel.clipVideo != nil) {
                    hasLivePhoto = YES;
                    break;
                }
            }
            NSDictionary *downloadAllModule = @{
                @"title": hasLivePhoto ? @"保存所有实况照片" : @"保存所有图片",
                @"icon": hasLivePhoto ? @"rectangle.stack" : @"square.grid.2x2",
                @"color": hasLivePhoto ? @"#FF9500" : @"#00B7C3",
                @"action": ^{
                    if (hasLivePhoto) {
                        NSMutableArray *livePhotos = [NSMutableArray array];
                        for (AWEImageAlbumImageModel *imageModel in awemeModel.albumImages) {
                            if (imageModel.clipVideo != nil && imageModel.urlList.count > 0) {
                                NSURL *photoURL = [NSURL URLWithString:imageModel.urlList.firstObject];
                                NSURL *videoURL = [imageModel.clipVideo.playURL getDYYYSrcURLDownload];
                                [livePhotos addObject:@{@"imageURL": photoURL.absoluteString, @"videoURL": videoURL.absoluteString}];
                            }
                        }
                        if (livePhotos.count > 0) {
                            [DYYYManager downloadAllLivePhotos:livePhotos];
                        } else {
                            [DYYYManager showToast:@"没有发现可下载的实况照片"];
                        }
                    } else {
                        NSMutableArray *imageURLs = [NSMutableArray array];
                        for (AWEImageAlbumImageModel *imageModel in awemeModel.albumImages) {
                            if (imageModel.urlList.count > 0) {
                                [imageURLs addObject:imageModel.urlList.firstObject];
                            }
                        }
                        [DYYYManager downloadAllImages:imageURLs];
                    }
                }
            };
            [menuModules addObject:downloadAllModule];
        }
    }
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYDoubleTapDownloadAudio"] || ![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYDoubleTapDownloadAudio"]) {
        NSDictionary *audioModule = @{
            @"title": @"保存音频",
            @"icon": @"music.note",
            @"color": @"#E3008C",
            @"action": ^{
                AWEMusicModel *musicModel = awemeModel.music;
                if (musicModel && musicModel.playURL && musicModel.playURL.originURLList.count > 0) {
                    NSURL *url = [NSURL URLWithString:musicModel.playURL.originURLList.firstObject];
                    [DYYYManager downloadMedia:url mediaType:MediaTypeAudio completion:^{
                        [DYYYManager showToast:@"音频已保存到相册"];
                    }];
                }
            }
        };
        [menuModules addObject:audioModule];
    }
    NSString *apiKey = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYInterfaceDownload"];
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYDoubleInterfaceDownload"] && apiKey.length > 0) {
        NSDictionary *apiModule = @{
            @"title": @"解析下载",
            @"icon": @"network",
            @"color": @"#4A5568",
            @"action": ^{
                NSString *shareLink = [awemeModel valueForKey:@"shareURL"];
                if (shareLink.length > 0) {
                    [DYYYManager parseAndDownloadVideoWithShareLink:shareLink apiKey:apiKey];
                } else {
                    [DYYYManager showToast:@"无法获取分享链接"];
                }
            }
        };
        [menuModules addObject:apiModule];
    }
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYEnableAdvancedSettings"] || 
        ![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYEnableAdvancedSettings"]) {
        NSDictionary *advancedSettingsModule = @{
            @"title": @"其他功能",
            @"icon": @"gearshape.2.fill",
            @"color": @"#007AFF",
            @"action": ^{
                UIViewController *topVC = [DYYYManager getActiveTopController];
                if (topVC) {
                    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"高级设置" 
                                                                                  message:@"选择高级功能" 
                                                                          preferredStyle:UIAlertControllerStyleActionSheet];
                    
                    [alert addAction:[UIAlertAction actionWithTitle:@"清除缓存" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                        [DYYYManager shared]; 
                        [DYYYManager showToast:@"缓存已清除"];
                    }]];
                    
                    [alert addAction:[UIAlertAction actionWithTitle:@"刷新视图" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                        [self refreshCurrentView];
                        [DYYYManager showToast:@"视图已刷新"];
                    }]];
                    
                    [alert addAction:[UIAlertAction actionWithTitle:@"视频信息" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                        [self showVideoDebugInfo:awemeModel];
                    }]];
                    
                    [alert addAction:[UIAlertAction actionWithTitle:@"强制关闭广告" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"DYYYBlockAllAds"];
                        [[NSUserDefaults standardUserDefaults] synchronize];
                        [DYYYManager showToast:@"已强制关闭广告，重启App生效"];
                    }]];
                    
                    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
                    
                    [topVC presentViewController:alert animated:YES completion:nil];
                }
            }
        };
        [menuModules addObject:advancedSettingsModule];
    }
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYDoubleTapCopyDesc"] || ![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYDoubleTapCopyDesc"]) {
        NSDictionary *copyTextModule = @{
            @"title": @"复制文案",
            @"icon": @"doc.on.doc",
            @"color": @"#5C2D91",
            @"action": ^{
                NSString *descText = [awemeModel valueForKey:@"descriptionString"];
                [[UIPasteboard generalPasteboard] setString:descText];
                [DYYYManager showToast:@"文案已复制到剪贴板"];
            }
        };
        [menuModules addObject:copyTextModule];
    }
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYEnableFLEX"] || 
        ![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYEnableFLEX"]) {
        // 创建FLEX调试功能对象
        NSDictionary *flexModule = @{
            @"title": @"FLEX调试",
            @"icon": @"bug",
            @"color": @"#FF9500",
            @"action": ^{
                // 显示FLEX调试界面
                [[%c(FLEXManager) sharedManager] showExplorer];
            }
        };
        // 使用现有的 menuModules 数组变量
        [menuModules addObject:flexModule];
    }
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYDoubleTapComment"] || ![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYDoubleTapComment"]) {
        NSDictionary *commentModule = @{
            @"title": @"打开评论",
            @"icon": @"text.bubble",
            @"color": @"#107C10",
            @"action": ^{
                [self performCommentAction];
            }
        };
        [menuModules addObject:commentModule];
    }
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYDoubleTapLike"] || ![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYDoubleTapLike"]) {
        NSDictionary *likeModule = @{
            @"title": @"点赞视频",
            @"icon": @"heart",
            @"color": @"#D83B01",
            @"action": ^{
                [self performLikeAction];
            }
        };
        [menuModules addObject:likeModule];
    }
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYDoubleTapshowSharePanel"] || ![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYDoubleTapshowSharePanel"]) {
        NSDictionary *shareModule = @{
            @"title": @"分享视频",
            @"icon": @"square.and.arrow.up",
            @"color": @"#FFB900",
            @"action": ^{
                [self showSharePanel];
            }
        };
        [menuModules addObject:shareModule];
    }
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYDoubleTapshowDislikeOnVideo"] || ![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYDoubleTapshowDislikeOnVideo"]) {
        NSDictionary *dislikeModule = @{
            @"title": @"触发面板",
            @"icon": @"ellipsis",
            @"color": @"#767676",
            @"action": ^{
                [self showDislikeOnVideo];
            }
        };
        [menuModules addObject:dislikeModule];
    }

    // 读取上次保存的顺序
    NSArray *savedOrder = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYModuleOrder"];
    NSMutableArray *orderedModules = [NSMutableArray arrayWithArray:menuModules];
    if (savedOrder && [savedOrder isKindOfClass:[NSArray class]] && savedOrder.count == menuModules.count) {
        NSMutableArray *tmp = [NSMutableArray arrayWithCapacity:menuModules.count];
        for (NSNumber *idx in savedOrder) {
            NSInteger i = [idx integerValue];
            if (i >= 0 && i < menuModules.count) {
                [tmp addObject:menuModules[i]];
            }
        }
        if (tmp.count == menuModules.count) {
            orderedModules = tmp;
        }
    }

    CGFloat moduleWidth = menuWidth - 32; // 两侧留16pt间距
    CGFloat moduleHeight = 64;
    CGFloat spacing = 14;
    int columns = 1;
    int rows = (int)menuModules.count;
    scrollView.contentSize = CGSizeMake(menuWidth, (moduleHeight + spacing) * rows + spacing);

    NSMutableArray *moduleViews = [NSMutableArray array];

    // --- 按顺序布局按钮 ---
    for (int i = 0; i < orderedModules.count; i++) {
        NSDictionary *moduleInfo = orderedModules[i];

        // 创建按钮容器
        UIButton *tileButton = [UIButton buttonWithType:UIButtonTypeCustom];
        tileButton.frame = CGRectMake(16, spacing + i * (moduleHeight + spacing), moduleWidth, moduleHeight);
        tileButton.backgroundColor = [UIColor colorWithWhite:1 alpha:0.13];
        tileButton.layer.cornerRadius = 16;
        tileButton.layer.shadowColor = [UIColor colorWithWhite:0 alpha:0.18].CGColor;
        tileButton.layer.shadowOffset = CGSizeMake(0, 4);
        tileButton.layer.shadowOpacity = 0.18;
        tileButton.layer.shadowRadius = 8;
        tileButton.layer.borderWidth = 0;
        tileButton.tag = i + 100;

        // 渐变背景
        CAGradientLayer *gradientLayer = [CAGradientLayer layer];
        gradientLayer.frame = tileButton.bounds;
        gradientLayer.cornerRadius = 16;
        gradientLayer.colors = @[
            (id)[DYYYManager colorWithHexString:moduleInfo[@"color"]].CGColor,
            (id)[UIColor colorWithWhite:1 alpha:0.13].CGColor
        ];
        gradientLayer.startPoint = CGPointMake(0, 0.5);
        gradientLayer.endPoint = CGPointMake(1, 0.5);
        [tileButton.layer insertSublayer:gradientLayer atIndex:0];

        // 动画
        CABasicAnimation *gradientAnimation = [CABasicAnimation animationWithKeyPath:@"colors"];
        gradientAnimation.fromValue = @[
            (id)[DYYYManager colorWithHexString:moduleInfo[@"color"]].CGColor,
            (id)[UIColor colorWithWhite:1 alpha:0.13].CGColor
        ];
        gradientAnimation.toValue = @[
            (id)[UIColor colorWithWhite:1 alpha:0.13].CGColor,
            (id)[DYYYManager colorWithHexString:moduleInfo[@"color"]].CGColor
        ];
        gradientAnimation.duration = 2.5;
        gradientAnimation.autoreverses = YES;
        gradientAnimation.repeatCount = HUGE_VALF;
        [gradientLayer addAnimation:gradientAnimation forKey:@"gradientAnimation"];

        // 标题调整：右移，为左侧图标留出空间
        [tileButton setTitle:moduleInfo[@"title"] forState:UIControlStateNormal];
        [tileButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        tileButton.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
        tileButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        tileButton.titleEdgeInsets = UIEdgeInsetsMake(0, 64, 0, 24); // 增加左侧边距，为图标留空间

        // 左侧图标 - 修改为彩色图标
        CGFloat iconSize = 32;
        NSString *iconName = moduleInfo[@"icon"];
        UIColor *iconColor = [DYYYManager colorWithHexString:moduleInfo[@"color"]];
        
        // 创建彩色图标容器
        UIView *iconContainer = [[UIView alloc] initWithFrame:CGRectMake(20, (moduleHeight - iconSize) / 2, iconSize, iconSize)];
        iconContainer.backgroundColor = [UIColor colorWithWhite:1 alpha:0.15];
        iconContainer.layer.cornerRadius = iconSize/2;
        [tileButton addSubview:iconContainer];
        
        // 图标视图
        UIImageView *iconView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, iconSize, iconSize)];
        iconView.contentMode = UIViewContentModeScaleAspectFit;
        iconView.tintColor = iconColor; // 使用模块对应的颜色
        
        // 设置彩色系统图标
        UIImage *defaultIcon = [UIImage systemImageNamed:iconName];
        if (defaultIcon) {
            // 使用原始渲染模式以保留图标颜色
            iconView.image = [defaultIcon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        }
        
        [iconContainer addSubview:iconView];
        
        // 右侧添加iOS风格的">"指示器
        UIImageView *chevronView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.right"]];
        chevronView.tintColor = [UIColor lightGrayColor];
        chevronView.contentMode = UIViewContentModeScaleAspectFit;
        chevronView.frame = CGRectMake(moduleWidth - 24, (moduleHeight - 20) / 2, 12, 20);
        [tileButton addSubview:chevronView];

        // 触感动画
        [tileButton addTarget:self action:@selector(moduleButtonTouchDown:) forControlEvents:UIControlEventTouchDown];
        [tileButton addTarget:self action:@selector(moduleButtonTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];

        // 点击事件
        [tileButton addTarget:self action:@selector(handleModuleButtonTap:) forControlEvents:UIControlEventTouchUpInside];
        objc_setAssociatedObject(tileButton, "moduleAction", moduleInfo[@"action"], OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        // 拖拽手势
        UILongPressGestureRecognizer *dragGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleModuleDrag:)];
        dragGesture.minimumPressDuration = 0.1;
        [tileButton addGestureRecognizer:dragGesture];

        [scrollView addSubview:tileButton];
        [moduleViews addObject:tileButton];
    }

    // 保存moduleViews到scrollView
    objc_setAssociatedObject(scrollView, "moduleViews", moduleViews, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissFluentMenu:)];
    [overlayView addGestureRecognizer:tapGesture];

    [topVC.view addSubview:overlayView];

    // 新增：弹窗支持拖动（仿DYYYSettingViewController）
    UIPanGestureRecognizer *dragPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dyyy_handleSettingPanelPan:)];
    [menuContainer addGestureRecognizer:dragPan];

    [UIView animateWithDuration:0.3 animations:^{
        overlayView.alpha = 1;
    }];
    [UIView animateWithDuration:0.35 delay:0 usingSpringWithDamping:0.85 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseOut animations:^{
        CGRect frame = menuContainer.frame;
        frame.origin.y = topVC.view.bounds.size.height - menuHeight - bottomSafe;
        menuContainer.frame = frame;
    } completion:^(BOOL finished) {
        for (int i = 0; i < moduleViews.count; i++) {
            UIView *moduleView = moduleViews[i];
            moduleView.alpha = 0;
            moduleView.transform = CGAffineTransformMakeScale(0.7, 0.7);
            moduleView.layer.shadowOpacity = 0.0;
            [UIView animateWithDuration:0.6
                                  delay:0.08 * i
                 usingSpringWithDamping:0.55
                  initialSpringVelocity:0.6
                                options:UIViewAnimationOptionCurveEaseOut
                             animations:^{
                moduleView.alpha = 1;
                moduleView.transform = CGAffineTransformIdentity;
                moduleView.layer.shadowOpacity = 0.5;
            } completion:nil];
        }
    }];
}

%new
- (void)handleDYYYBackgroundColorChanged:(NSNotification *)notification {
    UIViewController *topVC = [DYYYManager getActiveTopController];
    for (UIView *view in topVC.view.subviews) {
        if (view.tag == 9527) {
            // 保持半透明黑色背景
            view.backgroundColor = [UIColor colorWithWhite:0 alpha:0.3];
            break;
        }
    }
}

%new
- (void)dismissFluentMenu:(UITapGestureRecognizer *)gesture {
    UIView *overlayView = gesture.view;
    CGPoint location = [gesture locationInView:overlayView];
    UIView *menuContainer = nil;
    for (UIView *subview in overlayView.subviews) {
        if (subview.layer.cornerRadius == 20) {
            menuContainer = subview;
            break;
        }
    }
    if (menuContainer && !CGRectContainsPoint(menuContainer.frame, location)) {
        [UIView animateWithDuration:0.3 animations:^{
            overlayView.alpha = 0;
            CGRect frame = menuContainer.frame;
            frame.origin.y = overlayView.bounds.size.height;
            menuContainer.frame = frame;
        } completion:^(BOOL finished) {
            [overlayView removeFromSuperview];
        }];
    }
}

%new
- (void)dismissFluentMenuByButton:(UIButton *)button {
    UIView *headerView = button.superview;
    if (!headerView) return;
    
    UIView *contentPanel = headerView.superview;
    if (!contentPanel) return;
    
    // 找到menuContainer和overlayView
    UIView *menuContainer = nil;
    UIView *overlayView = nil;
    UIView *currentView = contentPanel;
    
    // 遍历视图层次结构以正确找到overlayView
    while (currentView) {
        if (currentView.tag == 9527) {
            overlayView = currentView;
            break;
        }
        
        if (currentView.layer.cornerRadius == 20) {
            menuContainer = currentView;
        }
        
        currentView = currentView.superview;
    }
    
    if (!overlayView) return;
    if (!menuContainer) menuContainer = contentPanel.superview;
    
    // 移除通知观察者以防止内存泄漏和后续事件处理
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"DYYYBackgroundColorChanged" object:nil];
    
    // 移除所有手势识别器
    NSArray *gestures = [NSArray arrayWithArray:overlayView.gestureRecognizers];
    for (UIGestureRecognizer *gesture in gestures) {
        gesture.enabled = NO;
        [overlayView removeGestureRecognizer:gesture];
    }
    
    // 禁用menuContainer上的手势
    if (menuContainer) {
        gestures = [NSArray arrayWithArray:menuContainer.gestureRecognizers];
        for (UIGestureRecognizer *gesture in gestures) {
            gesture.enabled = NO;
            [menuContainer removeGestureRecognizer:gesture];
        }
    }
    
    // 设置用户交互为NO，防止动画期间的触摸事件
    overlayView.userInteractionEnabled = NO;
    
    [UIView animateWithDuration:0.25 animations:^{
        overlayView.alpha = 0;
        
        if (menuContainer) {
            CGRect frame = menuContainer.frame;
            frame.origin.y = overlayView.bounds.size.height;
            menuContainer.frame = frame;
        }
    } completion:^(BOOL finished) {
        // 确保在主线程中执行视图移除
        dispatch_async(dispatch_get_main_queue(), ^{
            // 移除子视图
            for (UIView *subview in overlayView.subviews) {
                [subview removeFromSuperview];
            }
            [overlayView removeFromSuperview];
        });
    }];
}

%new
- (void)handleModuleDrag:(UILongPressGestureRecognizer *)gesture {
    UIButton *draggedBtn = (UIButton *)gesture.view;
    UIScrollView *scrollView = (UIScrollView *)draggedBtn.superview;
    NSMutableArray *moduleViews = objc_getAssociatedObject(scrollView, "moduleViews");
    static CGPoint dragStartPoint;
    static CGPoint btnOrigin;
    static NSInteger fromIndex;
    static BOOL isDragging = NO;

    CGFloat menuWidth = scrollView.superview.superview.frame.size.width;
    CGFloat moduleWidth = menuWidth - 32;
    CGFloat moduleHeight = 64;
    CGFloat spacing = 14;

    switch (gesture.state) {
        case UIGestureRecognizerStateBegan: {
            dragStartPoint = [gesture locationInView:scrollView];
            btnOrigin = draggedBtn.frame.origin;
            fromIndex = [moduleViews indexOfObject:draggedBtn];
            isDragging = YES;
            [scrollView bringSubviewToFront:draggedBtn];
            [UIView animateWithDuration:0.15 animations:^{
                draggedBtn.transform = CGAffineTransformMakeScale(1.08, 1.08);
                draggedBtn.layer.shadowColor = [UIColor colorWithRed:0.2 green:0.6 blue:1 alpha:0.5].CGColor;
                draggedBtn.layer.shadowOffset = CGSizeMake(0, 12);
                draggedBtn.layer.shadowOpacity = 0.9;
                draggedBtn.layer.shadowRadius = 24;
                draggedBtn.alpha = 0.93;
            }];
            if (@available(iOS 10.0, *)) {
                UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
                [generator prepare];
                [generator impactOccurred];
            }
            break;
        }
        case UIGestureRecognizerStateChanged: {
            if (!isDragging) break;
            CGPoint now = [gesture locationInView:scrollView];
            CGFloat offsetY = now.y - dragStartPoint.y;
            CGRect newFrame = draggedBtn.frame;
            newFrame.origin.y = btnOrigin.y + offsetY;
            draggedBtn.frame = newFrame;

            // 计算拖动中心点对应的目标index
            CGFloat dragCenterY = CGRectGetMidY(draggedBtn.frame);
            NSInteger toIndex = fromIndex;
            for (NSInteger i = 0; i < moduleViews.count; i++) {
                if (moduleViews[i] == draggedBtn) continue;
                UIButton *btn = moduleViews[i];
                CGFloat btnCenterY = CGRectGetMidY(btn.frame);
                if (dragCenterY > btnCenterY && i > fromIndex) {
                    toIndex = i;
                } else if (dragCenterY < btnCenterY && i < fromIndex) {
                    toIndex = i;
                    break;
                }
            }
            if (toIndex != fromIndex && toIndex >= 0 && toIndex < moduleViews.count) {
                // 交换数组顺序
                [moduleViews removeObjectAtIndex:fromIndex];
                [moduleViews insertObject:draggedBtn atIndex:toIndex];

                // 动画调整所有按钮位置
                [UIView animateWithDuration:0.18 animations:^{
                    for (NSInteger i = 0; i < moduleViews.count; i++) {
                        UIButton *btn = moduleViews[i];
                        if (btn != draggedBtn) {
                            btn.frame = CGRectMake(16, spacing + i * (moduleHeight + spacing), moduleWidth, moduleHeight);
                        }
                    }
                }];
                if (@available(iOS 10.0, *)) {
                    UISelectionFeedbackGenerator *selectGen = [[UISelectionFeedbackGenerator alloc] init];
                    [selectGen prepare];
                    [selectGen selectionChanged];
                }
                fromIndex = toIndex;
                btnOrigin = draggedBtn.frame.origin;
            }
            break;
        }
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled: {
            if (!isDragging) break;
            // 回弹所有按钮
            [UIView animateWithDuration:0.25 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0.2 options:UIViewAnimationOptionCurveEaseOut animations:^{
                for (NSInteger i = 0; i < moduleViews.count; i++) {
                    UIButton *btn = moduleViews[i];
                    btn.frame = CGRectMake(16, spacing + i * (moduleHeight + spacing), moduleWidth, moduleHeight);
                    btn.transform = CGAffineTransformIdentity;
                    btn.layer.shadowOpacity = 0.5;
                    btn.layer.shadowRadius = 12;
                    btn.alpha = 1.0;
                }
            } completion:nil];
            // 保存顺序
            NSMutableArray *orderArr = [NSMutableArray array];
            for (UIButton *btn in moduleViews) {
                NSNumber *tagNum = @(btn.tag - 100);
                [orderArr addObject:tagNum];
            }
            [[NSUserDefaults standardUserDefaults] setObject:orderArr forKey:@"DYYYModuleOrder"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            isDragging = NO;
            break;
        }
        default:
            break;
    }
}

%new
- (void)handleModuleTap:(UITapGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateRecognized) {
        UIView *moduleView = gesture.view;
        [UIView animateWithDuration:0.1 animations:^{
            moduleView.transform = CGAffineTransformMakeScale(0.95, 0.95);
            moduleView.backgroundColor = [UIColor colorWithWhite:1 alpha:0.2];
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:0.2 delay:0 usingSpringWithDamping:0.6 initialSpringVelocity:0.2 options:UIViewAnimationOptionCurveEaseOut animations:^{
                moduleView.transform = CGAffineTransformIdentity;
                moduleView.backgroundColor = [UIColor colorWithWhite:1 alpha:0.1];
            } completion:nil];
        }];
        if (@available(iOS 10.0, *)) {
            UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
            [generator prepare];
            [generator impactOccurred];
        }
        void (^action)(void) = objc_getAssociatedObject(moduleView, "moduleAction");
        if (action) {
            UIView *overlayView = nil;
            UIView *view = moduleView;
            while (view) {
                if (view.tag == 9527) {
                    overlayView = view;
                    break;
                }
                view = view.superview;
            }
            UIView *menuContainer = moduleView;
            while (menuContainer && menuContainer.layer.cornerRadius != 20) {
                menuContainer = menuContainer.superview;
            }
            if (overlayView && menuContainer) {
                [UIView animateWithDuration:0.3 animations:^{
                    overlayView.alpha = 0;
                    CGRect frame = menuContainer.frame;
                    frame.origin.y = overlayView.bounds.size.height;
                    menuContainer.frame = frame;
                } completion:^(BOOL finished) {
                    [overlayView removeFromSuperview];
                    action();
                }];
            } else {
                action();
            }
        }
    }
}

%new
- (void)resetModulePositions:(UIButton *)sender {
    if (@available(iOS 10.0, *)) {
        UINotificationFeedbackGenerator *generator = [[UINotificationFeedbackGenerator alloc] init];
        [generator prepare];
        [generator notificationOccurred:UINotificationFeedbackTypeSuccess];
    }
    UIView *menuContainer = sender.superview.superview.superview;
    UIScrollView *scrollView = nil;
    // 修正：contentPanel 需为 UIVisualEffectView，contentView 属性属于 UIVisualEffectView
    UIView *realContentView = menuContainer;
    if ([menuContainer isKindOfClass:[UIVisualEffectView class]]) {
        realContentView = ((UIVisualEffectView *)menuContainer).contentView;
    }
    for (UIView *sub in realContentView.subviews) {
        if ([sub isKindOfClass:[UIScrollView class]]) {
            scrollView = (UIScrollView *)sub;
            break;
        }
    }
    if (!scrollView) return;
    NSArray *moduleViews = objc_getAssociatedObject(scrollView, "moduleViews");
    if (!moduleViews) return;
    // 获取menuWidth
    CGFloat menuWidth = scrollView.superview.superview.frame.size.width;
    CGFloat moduleWidth = menuWidth - 32; // 两侧留16pt间距
    CGFloat moduleHeight = 64;
    CGFloat spacing = 14;
    int columns = 1;
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"DYYYModuleOrder"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [UIView animateWithDuration:0.5 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0.2 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        for (int i = 0; i < moduleViews.count; i++) {
            UIView *moduleView = moduleViews[i];
            int row = i / columns;
            int col = i % columns;
            CGFloat xPos = spacing + col * (moduleWidth + spacing);
            CGFloat yPos = spacing + row * (moduleHeight + spacing);
            moduleView.frame = CGRectMake(xPos, yPos, moduleWidth, moduleHeight);
        }
    } completion:nil];
    [UIView animateWithDuration:0.5 animations:^{
        sender.transform = CGAffineTransformMakeRotation(M_PI * 2);
    } completion:^(BOOL finished) {
        sender.transform = CGAffineTransformIdentity;
    }];
}

%new
- (void)showDYYYSettingPanelFromMenuButton:(UIButton *)button {
    // 复用 DYYY.xm 里 UIWindow 的双指长按弹窗逻辑
    UIViewController *topVC = [DYYYManager getActiveTopController];
    if (topVC) {
        UIViewController *settingVC = [[NSClassFromString(@"DYYYSettingViewController") alloc] init];
        if (settingVC) {
            BOOL isIPad = UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad;
            if (@available(iOS 15.0, *)) {
                if (!isIPad) {
                    settingVC.modalPresentationStyle = UIModalPresentationPageSheet;
                } else {
                    settingVC.modalPresentationStyle = UIModalPresentationFullScreen;
                }
            } else {
                settingVC.modalPresentationStyle = UIModalPresentationFullScreen;
            }

            // 全屏时加关闭按钮
            if (settingVC.modalPresentationStyle == UIModalPresentationFullScreen) {
                UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
                [closeButton setTitle:@"关闭" forState:UIControlStateNormal];
                closeButton.translatesAutoresizingMaskIntoConstraints = NO;
                [settingVC.view addSubview:closeButton];
                [NSLayoutConstraint activateConstraints:@[
                    [closeButton.trailingAnchor constraintEqualToAnchor:settingVC.view.trailingAnchor constant:-10],
                    [closeButton.topAnchor constraintEqualToAnchor:settingVC.view.topAnchor constant:40],
                    [closeButton.widthAnchor constraintEqualToConstant:80],
                    [closeButton.heightAnchor constraintEqualToConstant:40]
                ]];
                [closeButton addTarget:self action:@selector(dismissDYYYSettingPanel:) forControlEvents:UIControlEventTouchUpInside];
            }

            // 顶部小横条
            UIView *handleBar = [[UIView alloc] init];
            handleBar.backgroundColor = [UIColor whiteColor];
            handleBar.layer.cornerRadius = 2.5;
            handleBar.translatesAutoresizingMaskIntoConstraints = NO;
            [settingVC.view addSubview:handleBar];
            [NSLayoutConstraint activateConstraints:@[
                [handleBar.centerXAnchor constraintEqualToAnchor:settingVC.view.centerXAnchor],
                [handleBar.topAnchor constraintEqualToAnchor:settingVC.view.topAnchor constant:8],
                [handleBar.widthAnchor constraintEqualToConstant:40],
                [handleBar.heightAnchor constraintEqualToConstant:5]
            ]];

            [topVC presentViewController:settingVC animated:YES completion:nil];
        }
    }
}

%new
- (void)dismissDYYYSettingPanel:(UIButton *)button {
    [button.superview.window.rootViewController dismissViewControllerAnimated:YES completion:nil];
}

%new
- (void)dyyy_avatarTapped:(UITapGestureRecognizer *)gesture {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.allowsEditing = YES;
    picker.delegate = (id)self;
    picker.modalPresentationStyle = UIModalPresentationFullScreen;
    picker.view.tag = 10001; // 标记为头像
    [[DYYYManager getActiveTopController] presentViewController:picker animated:YES completion:nil];
}

%new
- (void)dyyy_albumTapped:(UITapGestureRecognizer *)gesture {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.allowsEditing = YES;
    picker.delegate = (id)self;
    picker.modalPresentationStyle = UIModalPresentationFullScreen;
    picker.view.tag = 10002; // 标记为相册图片
    [[DYYYManager getActiveTopController] presentViewController:picker animated:YES completion:nil];
}

%new
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info {
    UIImage *image = info[UIImagePickerControllerEditedImage] ?: info[UIImagePickerControllerOriginalImage];
    if (picker.view.tag == 10001) {
        // 头像
        NSString *avatarPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"DYYYAvatar.jpg"];
        [UIImageJPEGRepresentation(image, 0.92) writeToFile:avatarPath atomically:YES];
        [[picker presentingViewController] dismissViewControllerAnimated:YES completion:^{
            // 刷新弹窗头像
            [self refreshDYYYAvatarAndAlbum];
            // 通知设置页刷新头像
            [[NSNotificationCenter defaultCenter] postNotificationName:@"DYYYAvatarChanged" object:nil];
        }];
    } else if (picker.view.tag == 10002) {
        // 自定义相册图片
        NSString *albumPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/DYYY_custom_album_image.png"];
        [UIImagePNGRepresentation(image) writeToFile:albumPath atomically:YES];
        [[NSUserDefaults standardUserDefaults] setObject:albumPath forKey:@"DYYYCustomAlbumImagePath"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [[picker presentingViewController] dismissViewControllerAnimated:YES completion:^{
            [self refreshDYYYAvatarAndAlbum];
        }];
    } else {
        [[picker presentingViewController] dismissViewControllerAnimated:YES completion:nil];
    }
}

%new
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [[picker presentingViewController] dismissViewControllerAnimated:YES completion:nil];
}

%new
- (void)refreshDYYYAvatarAndAlbum {
    UIViewController *topVC = [DYYYManager getActiveTopController];
    UIView *overlayView = nil;
    for (UIView *view in topVC.view.subviews) {
        if (view.tag == 9527) {
            overlayView = view;
            break;
        }
    }
    if (!overlayView) return;
    // 刷新头像和昵称
    for (UIView *sub in overlayView.subviews) {
        for (UIView *subsub in sub.subviews) {
            if ([subsub isKindOfClass:[UIImageView class]]) {
                UIImageView *imgView = (UIImageView *)subsub;
                if (imgView.frame.size.width == 72) {
                    NSString *avatarPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"DYYYAvatar.jpg"];
                    UIImage *avatarImage = [UIImage imageWithContentsOfFile:avatarPath];
                    if (!avatarImage) avatarImage = [UIImage systemImageNamed:@"person.circle.fill"];
                    imgView.image = avatarImage;
                }
            }
            if ([subsub isKindOfClass:[UILabel class]]) {
                UILabel *label = (UILabel *)subsub;
                if (label.frame.size.width == 120) {
                    NSString *customTapText = [[NSUserDefaults standardUserDefaults] stringForKey:@"DYYYAvatarTapText"];
                    label.text = customTapText.length > 0 ? customTapText : @"pxx917144686";
                }
            }
        }
    }
}

%new
- (void)moduleButtonTouchDown:(UIButton *)sender {
    [UIView animateWithDuration:0.1 animations:^{
        sender.transform = CGAffineTransformMakeScale(0.96, 0.96);
        sender.alpha = 0.85;
    }];
}

%new
- (void)moduleButtonTouchUp:(UIButton *)sender {
    [UIView animateWithDuration:0.22 delay:0 usingSpringWithDamping:0.5 initialSpringVelocity:0.7 options:0 animations:^{
        sender.transform = CGAffineTransformIdentity;
        sender.alpha = 1.0;
    } completion:nil];
}

%new
- (void)handleModuleButtonTap:(UIButton *)sender {
    if (@available(iOS 10.0, *)) {
        UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [generator prepare];
        [generator impactOccurred];
    }
    void (^action)(void) = objc_getAssociatedObject(sender, "moduleAction");
    if (action) {
        // 关闭弹窗动画
        UIView *overlayView = nil;
        UIView *view = sender;
        while (view) {
            if (view.tag == 9527) {
                overlayView = view;
                break;
            }
            view = view.superview;
        }
        UIView *menuContainer = sender;
        while (menuContainer && menuContainer.layer.cornerRadius != 20) {
            menuContainer = menuContainer.superview;
        }
        if (overlayView && menuContainer) {
            [UIView animateWithDuration:0.3 animations:^{
                overlayView.alpha = 0;
                CGRect frame = menuContainer.frame;
                frame.origin.y = overlayView.bounds.size.height;
                menuContainer.frame = frame;
            } completion:^(BOOL finished) {
                [overlayView removeFromSuperview];
                action();
            }];
        } else {
            action();
        }
    }
}

%new
- (void)resizeMenuPan:(UIPanGestureRecognizer *)pan {
    UIView *resizeBtn = pan.view;
    UIView *headerView = resizeBtn.superview;
    UIView *contentPanel = headerView.superview.superview;
    UIView *menuContainer = contentPanel.superview;
    UIView *overlayView = menuContainer.superview;
    CGPoint translation = [pan translationInView:overlayView];
    static CGFloat startHeight = 0;
    
    // 修正：获取真实内容视图并使用它查找scrollView
    UIView *realContentView = contentPanel;
    if ([contentPanel isKindOfClass:[UIVisualEffectView class]]) {
        realContentView = ((UIVisualEffectView *)contentPanel).contentView;
    }
    
    // 查找scrollView并使用它
    UIScrollView *scrollView = nil;
    for (UIView *sub in realContentView.subviews) {
        if ([sub isKindOfClass:[UIScrollView class]]) {
            scrollView = (UIScrollView *)sub;
            break;
        }
    }
    
    CGFloat minHeight = 240;
    CGFloat maxHeight = overlayView.bounds.size.height - 80;
    CGFloat headerHeight = headerView.frame.size.height;
    CGFloat avatarHeight = 72 + 18 + 8;
    CGFloat safeBottom = 0;
    if (@available(iOS 11.0, *)) {
        safeBottom = overlayView.safeAreaInsets.bottom;
    }
    
    // 完整实现此方法，确保使用scrollView和safeBottom变量
    if (pan.state == UIGestureRecognizerStateBegan) {
        startHeight = menuContainer.frame.size.height;
    } else if (pan.state == UIGestureRecognizerStateChanged) {
        CGFloat newHeight = startHeight - translation.y;
        newHeight = MAX(minHeight, MIN(newHeight, maxHeight));
        
        CGRect frame = menuContainer.frame;
        frame.size.height = newHeight + safeBottom; 
        frame.origin.y = overlayView.bounds.size.height - newHeight;
        menuContainer.frame = frame;
        
        contentPanel.frame = menuContainer.bounds;
        
        // 调整滚动视图的高度
        if (scrollView) {
            scrollView.frame = CGRectMake(0, headerHeight, menuContainer.frame.size.width, newHeight - headerHeight);
        }
    }
}

%new
- (void)customMenuButtonTapped:(UIButton *)button {
    // 最大化弹窗
    UIView *headerView = button.superview;
    UIView *contentPanel = headerView.superview.superview;
    UIView *menuContainer = contentPanel.superview;
    UIView *overlayView = menuContainer.superview;
    CGFloat maxHeight = overlayView.bounds.size.height - 80;
    CGFloat safeBottom = 0;
    if (@available(iOS 11.0, *)) {
        safeBottom = overlayView.safeAreaInsets.bottom;
    }
    
    [UIView animateWithDuration:0.25 animations:^{
        CGRect frame = menuContainer.frame;
        frame.origin.y = overlayView.bounds.size.height - maxHeight;
        frame.size.height = maxHeight + safeBottom; // 使用safeBottom调整高度
        menuContainer.frame = frame;
        contentPanel.frame = menuContainer.bounds;
        
        // 同步调整scrollView高度
        UIScrollView *scrollView = nil;
        UIView *realContentView = contentPanel;
        if ([contentPanel isKindOfClass:[UIVisualEffectView class]]) {
            realContentView = ((UIVisualEffectView *)contentPanel).contentView;
        }
        for (UIView *sub in realContentView.subviews) {
            if ([sub isKindOfClass:[UIScrollView class]]) {
                scrollView = (UIScrollView *)sub;
                break;
            }
        }
        if (scrollView) {
            CGFloat headerHeight = headerView.frame.size.height;
            CGFloat scrollH = maxHeight - headerHeight + safeBottom; // 加上safeBottom
            scrollView.frame = CGRectMake(0, headerHeight, menuContainer.frame.size.width, MAX(0, scrollH));
        }
    }];
}

%new
- (void)dyyy_handleSettingPanelPan:(UIPanGestureRecognizer *)pan {
    UIView *menuContainer = pan.view;
    UIView *overlayView = menuContainer.superview;
    static CGFloat startY = 0;
    static CGFloat startOriginY = 0;
    static BOOL isDragging = NO;
    CGFloat minY = overlayView.bounds.size.height - menuContainer.frame.size.height;
    CGFloat maxY = overlayView.bounds.size.height - 100; // 最多拖到屏幕底部上方100px

    if (pan.state == UIGestureRecognizerStateBegan) {
        startY = [pan locationInView:overlayView].y;
        startOriginY = menuContainer.frame.origin.y;
        isDragging = YES;
    } else if (pan.state == UIGestureRecognizerStateChanged && isDragging) {
        CGFloat currentY = [pan locationInView:overlayView].y;
        CGFloat deltaY = currentY - startY;
        CGFloat newOriginY = startOriginY + deltaY;
        newOriginY = MAX(minY, MIN(newOriginY, maxY));
        CGRect frame = menuContainer.frame;
        frame.origin.y = newOriginY;
        menuContainer.frame = frame;
    } else if ((pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) && isDragging) {
        CGFloat velocityY = [pan velocityInView:overlayView].y;
        CGFloat currentOriginY = menuContainer.frame.origin.y;
        CGFloat threshold = overlayView.bounds.size.height - menuContainer.frame.size.height / 2;
        // 如果下拉速度较快或拖动到一半以下，则关闭弹窗
        if (velocityY > 800 || currentOriginY > threshold) {
            [UIView animateWithDuration:0.25 animations:^{
                CGRect frame = menuContainer.frame;
                frame.origin.y = overlayView.bounds.size.height;
                menuContainer.frame = frame;
                overlayView.alpha = 0;
            } completion:^(BOOL finished) {
                [overlayView removeFromSuperview];
            }];
        } else {
            // 回弹到顶部
            [UIView animateWithDuration:0.25 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0.3 options:UIViewAnimationOptionCurveEaseOut animations:^{
                CGRect frame = menuContainer.frame;
                frame.origin.y = minY;
                menuContainer.frame = frame;
            } completion:nil];
        }
        isDragging = NO;
    }
}

%new
- (void)toggleBlurStyle:(UIButton *)button {
    // 弹出颜色选择器
    [self showBlurColorPicker:button];
}

%new
- (void)showBlurColorPicker:(UIButton *)button {
    if (@available(iOS 14.0, *)) {
        UIColorPickerViewController *picker = [[UIColorPickerViewController alloc] init];
        // 从用户默认设置中获取当前的毛玻璃背景色
        NSData *colorData = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYBlurEffectColor"];
        UIColor *currentColor = colorData ? [NSKeyedUnarchiver unarchiveObjectWithData:colorData] : [UIColor systemBackgroundColor];
        picker.selectedColor = currentColor;
        picker.delegate = (id)self;
        
        // 实时更新 - 开启连续更新模式
        picker.supportsAlpha = YES;
        
        // 设置标题和说明
        picker.title = @"选择毛玻璃效果颜色";
        
        // 使用半屏模式弹出（适配不同设备）
        if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
            picker.modalPresentationStyle = UIModalPresentationPopover;
            picker.popoverPresentationController.sourceView = button;
            picker.popoverPresentationController.sourceRect = button.bounds;
        } else {
            picker.modalPresentationStyle = UIModalPresentationPageSheet;
        }
        
        // 执行触感反馈
        if (@available(iOS 10.0, *)) {
            UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
            [generator prepare];
            [generator impactOccurred];
        }
        
        // 呈现颜色选择器视图控制器
        [[DYYYManager getActiveTopController] presentViewController:picker animated:YES completion:nil];
    } else {
        // iOS 14以下的设备，使用替代的选择器
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"选择毛玻璃效果样式"
                                                                       message:nil
                                                                preferredStyle:UIAlertControllerStyleActionSheet];
        
        // 添加预定义颜色选项
        NSArray<NSDictionary *> *colors = @[
            @{@"name": @"浅色", @"color": [UIColor whiteColor]},
            @{@"name": @"深色", @"color": [UIColor darkGrayColor]},
            @{@"name": @"蓝色", @"color": [UIColor systemBlueColor]},
            @{@"name": @"红色", @"color": [UIColor systemRedColor]},
            @{@"name": @"绿色", @"color": [UIColor systemGreenColor]},
            @{@"name": @"紫色", @"color": [UIColor systemPurpleColor]},
            @{@"name": @"橙色", @"color": [UIColor systemOrangeColor]},
            @{@"name": @"粉色", @"color": [UIColor systemPinkColor]},
            @{@"name": @"黄色", @"color": [UIColor systemYellowColor]},
            @{@"name": @"青色", @"color": [UIColor cyanColor]}
        ];
        
        for (NSDictionary *colorInfo in colors) {
            NSString *name = colorInfo[@"name"];
            UIColor *color = colorInfo[@"color"];
            UIAlertAction *action = [UIAlertAction actionWithTitle:name style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                // 应用所选颜色
                [self updateBlurEffectWithColor:color];
                
                // 保存用户选择
                NSData *colorData = [NSKeyedArchiver archivedDataWithRootObject:color];
                [[NSUserDefaults standardUserDefaults] setObject:colorData forKey:@"DYYYBlurEffectColor"];
                [[NSUserDefaults standardUserDefaults] synchronize];
                
                // 立即更新颜色选择按钮
                [self updateColorPickerButtonWithColor:color];
                
                // 触感反馈
                if (@available(iOS 10.0, *)) {
                    UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
                    [generator prepare];
                    [generator impactOccurred];
                }
            }];
            
            // 添加颜色指示图标 - 使用全局辅助函数替代实例方法
            UIImage *colorImage = createColorCircleImage(color, CGSizeMake(20, 20));
            [action setValue:colorImage forKey:@"image"];
            [alert addAction:action];
        }
        
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
        [alert addAction:cancelAction];
        
        if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
            alert.popoverPresentationController.sourceView = button;
            alert.popoverPresentationController.sourceRect = button.bounds;
        }
        
        [[DYYYManager getActiveTopController] presentViewController:alert animated:YES completion:nil];
    }
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 140000
%new
- (void)colorPickerViewControllerDidSelectColor:(UIColorPickerViewController *)viewController {
    if (@available(iOS 14.0, *)) {
        UIColor *color = viewController.selectedColor;
        
        // 立即应用颜色效果
        [self updateBlurEffectWithColor:color];
        
        // 保存用户选择
        NSData *colorData = [NSKeyedArchiver archivedDataWithRootObject:color];
        [[NSUserDefaults standardUserDefaults] setObject:colorData forKey:@"DYYYBlurEffectColor"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        // 立即更新颜色选择按钮的外观
        [self updateColorPickerButtonWithColor:color];
        
        // 触感反馈
        if (@available(iOS 10.0, *)) {
            UISelectionFeedbackGenerator *generator = [[UISelectionFeedbackGenerator alloc] init];
            [generator prepare];
            [generator selectionChanged];
        }
    }
}

%new
- (void)colorPickerViewControllerDidFinish:(UIColorPickerViewController *)viewController {
    // 颜色选择器关闭时，确保使用最终选择的颜色
    if (@available(iOS 14.0, *)) {
        UIColor *finalColor = viewController.selectedColor;
        [self updateBlurEffectWithColor:finalColor];
        
        // 保存用户选择
        NSData *colorData = [NSKeyedArchiver archivedDataWithRootObject:finalColor];
        [[NSUserDefaults standardUserDefaults] setObject:colorData forKey:@"DYYYBlurEffectColor"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}
#endif

%new
- (void)updateColorPickerButtonWithColor:(UIColor *)color {
    UIViewController *topVC = [DYYYManager getActiveTopController];
    for (UIView *view in topVC.view.subviews) {
        if (view.tag == 9527) {
            for (UIView *subview in view.subviews) {
                // 找到按钮容器
                if ([subview isKindOfClass:[UIVisualEffectView class]]) {
                    UIVisualEffectView *blurView = (UIVisualEffectView *)subview;
                    for (UIView *contentSubview in blurView.contentView.subviews) {
                        if (contentSubview.tag == 100) { // headerView
                            for (UIView *headerSubview in contentSubview.subviews) {
                                if ([headerSubview isKindOfClass:[UIButton class]] && headerSubview.tag == 200) { // 颜色选择按钮
                                    UIButton *colorButton = (UIButton *)headerSubview;
                                    
                                    // 更新按钮图标颜色
                                    for (UIView *btnSubview in colorButton.subviews) {
                                        if ([btnSubview isKindOfClass:[UIImageView class]]) {
                                            UIImageView *imageView = (UIImageView *)btnSubview;
                                            imageView.tintColor = [UIColor whiteColor]; // 确保图标保持白色清晰可见
                                        }
                                    }
                                    
                                    // 更新渐变背景
                                    for (CALayer *layer in colorButton.layer.sublayers) {
                                        if ([layer isKindOfClass:[CAGradientLayer class]]) {
                                            CAGradientLayer *gradientLayer = (CAGradientLayer *)layer;
                                            
                                            // 动画过渡到新颜色
                                            CABasicAnimation *colorAnimation = [CABasicAnimation animationWithKeyPath:@"colors"];
                                            colorAnimation.fromValue = gradientLayer.colors;
                                            colorAnimation.toValue = @[
                                                (id)[color colorWithAlphaComponent:0.9].CGColor,
                                                (id)[color colorWithAlphaComponent:0.7].CGColor
                                            ];
                                            colorAnimation.duration = 0.3;
                                            colorAnimation.removedOnCompletion = YES;
                                            colorAnimation.fillMode = kCAFillModeForwards;
                                            [gradientLayer addAnimation:colorAnimation forKey:@"colorAnimation"];
                                            
                                            // 更新实际颜色值
                                            gradientLayer.colors = @[
                                                (id)[color colorWithAlphaComponent:0.9].CGColor,
                                                (id)[color colorWithAlphaComponent:0.7].CGColor
                                            ];
                                            
                                            // 更新阴影颜色
                                            colorButton.layer.shadowColor = [color colorWithAlphaComponent:0.4].CGColor;
                                        }
                                    }
                                    break;
                                }
                            }
                            break;
                        }
                    }
                    break;
                }
            }
            break;
        }
    }
}

%new
- (void)updateBlurEffectWithColor:(UIColor *)color {
    // 获取视图层次
    UIViewController *topVC = [DYYYManager getActiveTopController];
    for (UIView *view in topVC.view.subviews) {
        if (view.tag == 9527) {
            for (UIView *subview in view.subviews) {
                // 查找毛玻璃效果视图
                if ([subview isKindOfClass:[UIVisualEffectView class]]) {
                    UIVisualEffectView *blurView = (UIVisualEffectView *)subview;
                    
                    // 处理不同的颜色以创建不同风格的毛玻璃效果
                    UIBlurEffect *blurEffect;
                    
                    // 确定最合适的模糊效果风格
                    UIBlurEffectStyle style = UIBlurEffectStyleLight;
                    CGFloat brightness = 0;
                    [color getWhite:&brightness alpha:nil];
                    
                    if (brightness < 0.5) {
                        // 深色
                        if (@available(iOS 13.0, *)) {
                            style = UIBlurEffectStyleSystemMaterialDark;
                        } else {
                            style = UIBlurEffectStyleDark;
                        }
                    } else {
                        // 浅色
                        if (@available(iOS 13.0, *)) {
                            style = UIBlurEffectStyleSystemMaterialLight;
                        } else {
                            style = UIBlurEffectStyleLight;
                        }
                    }
                    
                    blurEffect = [UIBlurEffect effectWithStyle:style];
                    
                    // 应用新的毛玻璃效果 - 使用更短的动画时间
                    [UIView transitionWithView:blurView 
                                      duration:0.2
                                       options:UIViewAnimationOptionTransitionCrossDissolve
                                    animations:^{
                                        [blurView setEffect:blurEffect];
                                        
                                        // 添加一个背景色层让毛玻璃效果带有所选颜色
                                        UIView *colorView = [blurView viewWithTag:8888];
                                        if (!colorView) {
                                            colorView = [[UIView alloc] initWithFrame:blurView.bounds];
                                            colorView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                                            colorView.tag = 8888;
                                            [blurView.contentView insertSubview:colorView atIndex:0];
                                        }
                                        colorView.backgroundColor = [color colorWithAlphaComponent:0.3];
                                    } 
                                    completion:nil];
                    
                    // 立即更新颜色选择按钮
                    [self updateColorPickerButtonWithColor:color];
                    
                    break;
                }
            }
            break;
        }
    }
}

%new
- (UIImage *)imageWithColor:(UIColor *)color size:(CGSize)size {
    UIGraphicsBeginImageContextWithOptions(size, YES, 0);
    [color setFill];
    [[UIColor whiteColor] setStroke];
    UIBezierPath *path = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(1, 1, size.width - 2, size.height - 2)];
    path.lineWidth = 1.0;
    [path fill];
    [path stroke];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

%new
- (void)refreshCurrentView {
    UIViewController *topVC = [DYYYManager getActiveTopController];
    if ([topVC isKindOfClass:%c(AWEFeedTableViewVC)]) {
        [topVC.view setNeedsLayout];
        [topVC.view layoutIfNeeded];
    }
}

%new
- (void)showVideoDebugInfo:(AWEAwemeModel *)model {
    if (!model) {
        [DYYYManager showToast:@"无法获取视频信息"];
        return;
    }
    
    NSMutableString *debugInfo = [NSMutableString string];
    
    // 视频ID - 尝试使用不同的属性名
    NSString *videoId = [model valueForKey:@"aweme_id"] ?: [model valueForKey:@"awemeId"] ?: [model valueForKey:@"ID"] ?: @"未知";
    [debugInfo appendFormat:@"视频ID: %@\n", videoId];
    
    // 视频时长 - 使用顶层属性videoDuration
    [debugInfo appendFormat:@"视频时长: %.1f秒\n", model.videoDuration/1000.0];
    
    if (model.video) {
        // 视频分辨率、比特率和格式 - 使用valueForKey安全获取
        NSNumber *width = [model.video valueForKey:@"width"];
        NSNumber *height = [model.video valueForKey:@"height"];
        if (width && height) {
            [debugInfo appendFormat:@"视频分辨率: %@x%@\n", width, height];
        } else {
            [debugInfo appendString:@"视频分辨率: 未知\n"];
        }
        
        NSNumber *bitrate = [model.video valueForKey:@"bitrate"];
        if (bitrate) {
            [debugInfo appendFormat:@"视频比特率: %@\n", bitrate];
        } else {
            [debugInfo appendString:@"视频比特率: 未知\n"];
        }
        
        NSString *format = [model.video valueForKey:@"format"];
        [debugInfo appendFormat:@"视频格式: %@\n", format ?: @"未知"];
    }
    
    [debugInfo appendFormat:@"视频类型: %@\n", @(model.awemeType)];
    
    // 点赞状态 - 尝试不同的属性名
    BOOL isLiked = NO;
    if ([model respondsToSelector:@selector(isDigg)]) {
        isLiked = [model performSelector:@selector(isDigg)];
    } else if ([model respondsToSelector:@selector(userDigg)]) {
        isLiked = [model performSelector:@selector(userDigg)];
    } else if ([model respondsToSelector:@selector(userHasDigg)]) {
        isLiked = [model performSelector:@selector(userHasDigg)];
    }
    [debugInfo appendFormat:@"是否已点赞: %@\n", isLiked ? @"是" : @"否"];
    
    // 统计信息
    if (model.statistics) {
        [debugInfo appendFormat:@"点赞数: %@\n", model.statistics.diggCount ?: @"0"];
        
        // 评论数 - 尝试不同的属性名
        NSNumber *commentCount = [model.statistics valueForKey:@"commentCount"] ?: 
                                [model.statistics valueForKey:@"comment_count"] ?: 
                                @0;
        [debugInfo appendFormat:@"评论数: %@\n", commentCount];
    }
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"视频调试信息" 
                                                                   message:debugInfo 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"复制信息" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [[UIPasteboard generalPasteboard] setString:debugInfo];
        [DYYYManager showToast:@"调试信息已复制"];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"关闭" style:UIAlertActionStyleCancel handler:nil]];
    
    [[DYYYManager getActiveTopController] presentViewController:alert animated:YES completion:nil];
}

%end
