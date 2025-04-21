#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "AwemeHeaders.h"
#import "DYYYManager.h"

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
- (void)showDYYYColorPickerFromMenuButton:(UIButton *)button;
- (void)handleDYYYBackgroundColorChanged:(NSNotification *)notification;
- (void)dyyy_handleSettingPanelPan:(UIPanGestureRecognizer *)pan;
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
    NSData *colorData = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYBackgroundColor"];
    UIColor *customBgColor = colorData ? [NSKeyedUnarchiver unarchiveObjectWithData:colorData] : [UIColor colorWithWhite:0 alpha:0.4];
    UIView *overlayView = [[UIView alloc] initWithFrame:topVC.view.bounds];
    overlayView.backgroundColor = customBgColor;
    overlayView.alpha = 0;
    overlayView.tag = 9527;

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
    menuContainer.backgroundColor = [UIColor clearColor];
    menuContainer.layer.shadowColor = [UIColor blackColor].CGColor;
    menuContainer.layer.shadowOffset = CGSizeMake(0, -10);
    menuContainer.layer.shadowRadius = 20;
    menuContainer.layer.shadowOpacity = 0.3;
    [overlayView addSubview:menuContainer];

    UIVisualEffectView *contentPanel = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterialDark]];
    contentPanel.frame = menuContainer.bounds;
    contentPanel.layer.cornerRadius = 20;
    contentPanel.clipsToBounds = YES;
    [menuContainer addSubview:contentPanel];

    CGFloat avatarSize = 72;
    UIImageView *avatarImageView = [[UIImageView alloc] initWithFrame:CGRectMake((menuWidth-avatarSize)/2, -avatarSize/2, avatarSize, avatarSize)];
    avatarImageView.layer.cornerRadius = avatarSize/2;
    avatarImageView.clipsToBounds = YES;
    avatarImageView.contentMode = UIViewContentModeScaleAspectFill;

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
    [menuContainer addSubview:avatarImageView];

    UILabel *avatarLabel = [[UILabel alloc] initWithFrame:CGRectMake((menuWidth-120)/2, avatarImageView.frame.origin.y+avatarSize+2, 120, 18)];
    NSString *customTapText = [[NSUserDefaults standardUserDefaults] stringForKey:@"DYYYAvatarTapText"];
    avatarLabel.text = customTapText.length > 0 ? customTapText : @"pxx917144686";
    avatarLabel.textColor = [UIColor colorWithRed:0.2 green:0.6 blue:1 alpha:1];
    avatarLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    avatarLabel.textAlignment = NSTextAlignmentCenter;
    [menuContainer addSubview:avatarLabel];

    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, menuWidth, 100)];
    headerView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.1];
    [contentPanel.contentView addSubview:headerView];

    UIButton *resizeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    resizeButton.frame = CGRectMake(menuWidth - 90, 20, 30, 30);
    UIImage *resizeImage = [UIImage systemImageNamed:@"arrow.up.and.down.circle.fill"];
    [resizeButton setImage:resizeImage forState:UIControlStateNormal];
    resizeButton.tintColor = [UIColor colorWithRed:0.2 green:0.6 blue:1 alpha:0.95];
    resizeButton.backgroundColor = [UIColor clearColor];
    resizeButton.layer.cornerRadius = 15;
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(resizeMenuPan:)];
    [resizeButton addGestureRecognizer:pan];
    [resizeButton addTarget:self action:@selector(customMenuButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [headerView addSubview:resizeButton];

    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    closeButton.frame = CGRectMake(menuWidth - 50, 20, 30, 30);
    UIImage *closeImage = [UIImage systemImageNamed:@"xmark.circle.fill"];
    [closeButton setImage:closeImage forState:UIControlStateNormal];
    closeButton.tintColor = [UIColor colorWithRed:0.2 green:0.6 blue:1 alpha:0.95];
    closeButton.backgroundColor = [UIColor clearColor];
    closeButton.layer.cornerRadius = 15;
    [closeButton addTarget:self action:@selector(dismissFluentMenuByButton:) forControlEvents:UIControlEventTouchUpInside];
    [headerView addSubview:closeButton];

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

    UIButton *colorButton = [UIButton buttonWithType:UIButtonTypeSystem];
    colorButton.frame = CGRectMake(100, 20, 30, 30);
    UIImage *paletteImage = [UIImage systemImageNamed:@"paintpalette.fill"];
    [colorButton setImage:paletteImage forState:UIControlStateNormal];
    colorButton.tintColor = [UIColor colorWithRed:0.2 green:0.6 blue:1 alpha:0.95];
    colorButton.backgroundColor = [UIColor clearColor];
    colorButton.layer.cornerRadius = 15;
    [colorButton addTarget:self action:@selector(showDYYYColorPickerFromMenuButton:) forControlEvents:UIControlEventTouchUpInside];
    [headerView addSubview:colorButton];

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
            @"title": @"接口保存",
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

    CGFloat moduleWidth = menuWidth - 32;
    CGFloat moduleHeight = 64;
    CGFloat spacing = 14;
    int columns = 1;
    int rows = (int)menuModules.count;
    scrollView.contentSize = CGSizeMake(menuWidth, (moduleHeight + spacing) * rows + spacing);

    NSMutableArray *moduleViews = [NSMutableArray array];

    for (int i = 0; i < orderedModules.count; i++) {
        NSDictionary *moduleInfo = orderedModules[i];

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

        [tileButton setTitle:moduleInfo[@"title"] forState:UIControlStateNormal];
        [tileButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        tileButton.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
        tileButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        tileButton.titleEdgeInsets = UIEdgeInsetsMake(0, 24, 0, 56);

        CGFloat iconSize = 32;
        UIImage *icon = [UIImage systemImageNamed:moduleInfo[@"icon"]];
        UIImageView *iconView = [[UIImageView alloc] initWithImage:[icon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
        iconView.tintColor = [UIColor whiteColor];
        iconView.contentMode = UIViewContentModeScaleAspectFit;
        iconView.frame = CGRectMake(moduleWidth - iconSize - 24, (moduleHeight - iconSize) / 2, iconSize, iconSize);
        iconView.userInteractionEnabled = NO;
        [tileButton addSubview:iconView];

        [tileButton addTarget:self action:@selector(moduleButtonTouchDown:) forControlEvents:UIControlEventTouchDown];
        [tileButton addTarget:self action:@selector(moduleButtonTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];

        [tileButton addTarget:self action:@selector(handleModuleButtonTap:) forControlEvents:UIControlEventTouchUpInside];
        objc_setAssociatedObject(tileButton, "moduleAction", moduleInfo[@"action"], OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        UILongPressGestureRecognizer *dragGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleModuleDrag:)];
        dragGesture.minimumPressDuration = 0.1;
        [tileButton addGestureRecognizer:dragGesture];

        [scrollView addSubview:tileButton];
        [moduleViews addObject:tileButton];
    }

    objc_setAssociatedObject(scrollView, "moduleViews", moduleViews, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissFluentMenu:)];
    [overlayView addGestureRecognizer:tapGesture];

    [topVC.view addSubview:overlayView];

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
- (void)showDYYYColorPickerFromMenuButton:(UIButton *)button {
    if (@available(iOS 14.0, *)) {
        UIColorPickerViewController *picker = [[UIColorPickerViewController alloc] init];
        NSData *colorData = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYBackgroundColor"];
        UIColor *currentColor = colorData ? [NSKeyedUnarchiver unarchiveObjectWithData:colorData] : [UIColor colorWithWhite:0 alpha:0.4];
        picker.selectedColor = currentColor;
        picker.delegate = (id)self;
        picker.modalPresentationStyle = UIModalPresentationPopover;
        UIViewController *topVC = [DYYYManager getActiveTopController];
        [topVC presentViewController:picker animated:YES completion:nil];
        UIPopoverPresentationController *popover = picker.popoverPresentationController;
        if (popover) {
            popover.sourceView = button;
            popover.sourceRect = button.bounds;
            popover.permittedArrowDirections = UIPopoverArrowDirectionAny;
        }
    } else {
        [DYYYManager showToast:@"需iOS 14+支持原生调色板"];
    }
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 140000
- (void)colorPickerViewControllerDidSelectColor:(UIColorPickerViewController *)viewController {
    UIColor *color = viewController.selectedColor;
    NSData *colorData = [NSKeyedArchiver archivedDataWithRootObject:color];
    [[NSUserDefaults standardUserDefaults] setObject:colorData forKey:@"DYYYBackgroundColor"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"DYYYBackgroundColorChanged" object:nil];
}
- (void)colorPickerViewControllerDidFinish:(UIColorPickerViewController *)viewController {
    if ([self respondsToSelector:@selector(colorPickerViewControllerDidSelectColor:)]) {
        [(id)self colorPickerViewControllerDidSelectColor:viewController];
    }
}
#endif

%new
- (void)handleDYYYBackgroundColorChanged:(NSNotification *)notification {
    UIViewController *topVC = [DYYYManager getActiveTopController];
    for (UIView *view in topVC.view.subviews) {
        if (view.tag == 9527) {
            NSData *colorData = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYBackgroundColor"];
            UIColor *customBgColor = colorData ? [NSKeyedUnarchiver unarchiveObjectWithData:colorData] : [UIColor colorWithWhite:0 alpha:0.4];
            view.backgroundColor = customBgColor;
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
    UIView *contentPanel = headerView.superview.superview;
    UIView *menuContainer = contentPanel.superview;
    UIView *overlayView = menuContainer.superview;
    [UIView animateWithDuration:0.3 animations:^{
        overlayView.alpha = 0;
        CGRect frame = menuContainer.frame;
        frame.origin.y = overlayView.bounds.size.height;
        menuContainer.frame = frame;
    } completion:^(BOOL finished) {
        [overlayView removeFromSuperview];
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
                [moduleViews removeObjectAtIndex:fromIndex];
                [moduleViews insertObject:draggedBtn atIndex:toIndex];

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
    CGFloat menuWidth = scrollView.superview.superview.frame.size.width;
    CGFloat moduleWidth = menuWidth - 32;
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
    picker.view.tag = 10001;
    [[DYYYManager getActiveTopController] presentViewController:picker animated:YES completion:nil];
}

%new
- (void)dyyy_albumTapped:(UITapGestureRecognizer *)gesture {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.allowsEditing = YES;
    picker.delegate = (id)self;
    picker.modalPresentationStyle = UIModalPresentationFullScreen;
    picker.view.tag = 10002;
    [[DYYYManager getActiveTopController] presentViewController:picker animated:YES completion:nil];
}

%new
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info {
    UIImage *image = info[UIImagePickerControllerEditedImage] ?: info[UIImagePickerControllerOriginalImage];
    if (picker.view.tag == 10001) {
        NSString *avatarPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"DYYYAvatar.jpg"];
        [UIImageJPEGRepresentation(image, 0.92) writeToFile:avatarPath atomically:YES];
        [[picker presentingViewController] dismissViewControllerAnimated:YES completion:^{
            [self refreshDYYYAvatarAndAlbum];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"DYYYAvatarChanged" object:nil];
        }];
    } else if (picker.view.tag == 10002) {
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
    CGFloat minHeight = 240;
    CGFloat maxHeight = overlayView.bounds.size.height - 80;
    CGFloat headerHeight = headerView.frame.size.height;
    CGFloat avatarHeight = 72 + 18 + 8;
    CGFloat safeBottom = 0;
    if (@available(iOS 11.0, *)) {
        safeBottom = overlayView.safeAreaInsets.bottom;
    }
    if (pan.state == UIGestureRecognizerStateBegan) {
        startHeight = menuContainer.frame.size.height;
    } else if (pan.state == UIGestureRecognizerStateChanged) {
        CGFloat newHeight = startHeight - translation.y;
        CGFloat contentNeedHeight = scrollView ? scrollView.contentSize.height : 0;
        CGFloat smartMin = headerHeight + avatarHeight + MIN(contentNeedHeight, maxHeight * 0.6) + safeBottom + 24;
        CGFloat smartMax = maxHeight;
        newHeight = MAX(MIN(newHeight, smartMax), MAX(minHeight, smartMin));
        CGRect frame = menuContainer.frame;
        frame.origin.y = overlayView.bounds.size.height - newHeight;
        frame.size.height = newHeight;
        menuContainer.frame = frame;
        contentPanel.frame = menuContainer.bounds;
        if (scrollView) {
            CGFloat scrollH = newHeight - headerHeight;
            scrollView.frame = CGRectMake(0, headerHeight, menuContainer.frame.size.width, MAX(0, scrollH));
        }
    } else if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
        CGFloat contentNeedHeight = scrollView ? scrollView.contentSize.height : 0;
        CGFloat smartTarget = headerHeight + avatarHeight + contentNeedHeight + safeBottom + 24;
        CGFloat smartMax = maxHeight;
        CGFloat smartMin = headerHeight + avatarHeight + MIN(contentNeedHeight, maxHeight * 0.6) + safeBottom + 24;
        CGFloat targetHeight;
        if (contentNeedHeight < maxHeight * 0.5) {
            targetHeight = MAX(minHeight, smartMin);
        } else if (smartTarget > smartMax * 0.95) {
            targetHeight = smartMax;
        } else {
            targetHeight = smartTarget;
        }
        [UIView animateWithDuration:0.25 animations:^{
            CGRect frame = menuContainer.frame;
            frame.origin.y = overlayView.bounds.size.height - targetHeight;
            frame.size.height = targetHeight;
            menuContainer.frame = frame;
            contentPanel.frame = menuContainer.bounds;
            if (scrollView) {
                CGFloat scrollH = targetHeight - headerHeight;
                scrollView.frame = CGRectMake(0, headerHeight, menuContainer.frame.size.width, MAX(0, scrollH));
            }
        }];
    }
}

%new
- (void)customMenuButtonTapped:(UIButton *)button {
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
        frame.size.height = maxHeight;
        menuContainer.frame = frame;
        contentPanel.frame = menuContainer.bounds;
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
            CGFloat scrollH = maxHeight - headerHeight;
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
    CGFloat maxY = overlayView.bounds.size.height - 100;

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
            [UIView animateWithDuration:0.25 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0.3 options:UIViewAnimationOptionCurveEaseOut animations:^{
                CGRect frame = menuContainer.frame;
                frame.origin.y = minY;
                menuContainer.frame = frame;
            } completion:nil];
        }
        isDragging = NO;
    }
}

%end