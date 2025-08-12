#import "DYYYPipPlayer.h"
#import <objc/runtime.h>
#import "DYYYManager.h"

@implementation DYYYPipManager

+ (instancetype)sharedManager {
    static DYYYPipManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[DYYYPipManager alloc] init];
    });
    return manager;
}

+ (void)setSharedPipContainer:(DYYYPipContainerView *)container {
    objc_setAssociatedObject(self, @selector(sharedPipContainer), container, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

+ (DYYYPipContainerView *)sharedPipContainer {
    return objc_getAssociatedObject(self, @selector(sharedPipContainer));
}

- (void)createPipWithAwemeModel:(AWEAwemeModel *)awemeModel {
    NSLog(@"DYYY: [1] 创建小窗播放器");
    
    // 获取主窗口
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    if (!keyWindow) {
        keyWindow = [UIApplication sharedApplication].windows.firstObject;
    }
    
    if (!keyWindow) {
        [DYYYManager showToast:@"错误：未找到主窗口"];
        NSLog(@"DYYY: [错误] 未找到主窗口。");
        return;
    }
    
    // 检查是否已有小窗在播放
    DYYYPipContainerView *existingPip = [[self class] sharedPipContainer];
    if (existingPip && existingPip.superview) {
        // 更新现有小窗的内容
        [existingPip updatePipPlayerWithAwemeModel:awemeModel];
        return;
    }
    
    // 获取屏幕尺寸和安全区域
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    CGFloat safeAreaTop = 0;
    if (@available(iOS 11.0, *)) {
        safeAreaTop = keyWindow.safeAreaInsets.top;
    }
    
    CGFloat pipWidth = 160;
    CGFloat pipHeight = 284; // 16:9 比例
    CGFloat margin = 20;
    
    // 计算右上角位置，考虑安全区域
    CGFloat pipX = screenBounds.size.width - pipWidth - margin;
    CGFloat pipY = safeAreaTop + 20; // 安全区域下方
    
    // 创建新的 PIP 容器
    DYYYPipContainerView *pipContainer = [[DYYYPipContainerView alloc] initWithFrame:CGRectMake(pipX, pipY, pipWidth, pipHeight)];
    
    // 设置小窗播放器，使用当前视频模型
    [pipContainer setupPipPlayerWithAwemeModel:awemeModel];
    
    // 保存全局引用
    [[self class] setSharedPipContainer:pipContainer];
    
    // 添加到主窗口
    [keyWindow addSubview:pipContainer];
    
    // 添加阴影效果
    pipContainer.layer.shadowColor = [UIColor blackColor].CGColor;
    pipContainer.layer.shadowOffset = CGSizeMake(0, 2);
    pipContainer.layer.shadowOpacity = 0.3;
    pipContainer.layer.shadowRadius = 8;
}

- (void)closePip {
    DYYYPipContainerView *pipContainer = [[self class] sharedPipContainer];
    if (pipContainer) {
        [pipContainer dyyy_closeAndStopPip];
        [[self class] setSharedPipContainer:nil];
    }
}

@end

@implementation DYYYPipContainerView

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [UIColor clearColor];
        self.layer.cornerRadius = 12;
        self.clipsToBounds = YES;
        self.isPlayingInPip = NO;
        
        // 背景装饰层
        self.mediaDecorationLayer = [[UIView alloc] initWithFrame:self.bounds];
        self.mediaDecorationLayer.backgroundColor = [UIColor blackColor];
        self.mediaDecorationLayer.layer.cornerRadius = 12;
        [self addSubview:self.mediaDecorationLayer];
        
        // 内容容器层
        self.contentContainerLayer = [[UIView alloc] initWithFrame:self.bounds];
        self.contentContainerLayer.layer.cornerRadius = 12;
        self.contentContainerLayer.clipsToBounds = YES;
        [self addSubview:self.contentContainerLayer];
        
        // 其他容器层
        self.danmakuContainerLayer = [[UIView alloc] initWithFrame:self.bounds];
        [self addSubview:self.danmakuContainerLayer];
        
        self.diggAnimationContainer = [[UIView alloc] initWithFrame:self.bounds];
        [self addSubview:self.diggAnimationContainer];
        
        self.operationContainerLayer = [[UIView alloc] initWithFrame:self.bounds];
        [self addSubview:self.operationContainerLayer];
        
        self.floatContainerLayer = [[UIView alloc] initWithFrame:self.bounds];
        [self addSubview:self.floatContainerLayer];
        
        self.keyboardContainerLayer = [[UIView alloc] initWithFrame:self.bounds];
        [self addSubview:self.keyboardContainerLayer];
        
        // 关闭按钮 - 左上角
        UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
        closeButton.frame = CGRectMake(8, 8, 28, 28);
        closeButton.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.8];
        closeButton.layer.cornerRadius = 14;
        [closeButton setTitle:@"×" forState:UIControlStateNormal];
        [closeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        closeButton.titleLabel.font = [UIFont boldSystemFontOfSize:18];
        closeButton.tag = 9998;
        [closeButton addTarget:self action:@selector(dyyy_closeAndStopPip) forControlEvents:UIControlEventTouchUpInside];
        
        closeButton.layer.borderWidth = 1.0;
        closeButton.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.3].CGColor;
        [self addSubview:closeButton];
        
        // 声音控制按钮 - 右上角
        UIButton *soundButton = [UIButton buttonWithType:UIButtonTypeCustom];
        soundButton.frame = CGRectMake(self.bounds.size.width - 36, 8, 28, 28);
        soundButton.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.8];
        soundButton.layer.cornerRadius = 14;
        
        // 默认静音状态，显示静音图标
        if (@available(iOS 13.0, *)) {
            UIImage *mutedImage = [UIImage systemImageNamed:@"speaker.slash.fill"];
            [soundButton setImage:mutedImage forState:UIControlStateNormal];
            soundButton.tintColor = [UIColor whiteColor];
        } else {
            [soundButton setTitle:@"🔇" forState:UIControlStateNormal];
            soundButton.titleLabel.font = [UIFont systemFontOfSize:14];
        }
        
        soundButton.layer.borderWidth = 1.0;
        soundButton.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.3].CGColor;
        
        // 设置可访问性标签
        soundButton.accessibilityLabel = @"切换声音";
        soundButton.tag = 9997;
        
        // 绑定声音切换操作
        [soundButton addTarget:self action:@selector(dyyy_toggleSound) forControlEvents:UIControlEventTouchUpInside];
        
        // 保存引用，用于更新图标
        self.restoreButton = soundButton;
        [self addSubview:soundButton];
        
        // 直接给整个容器添加点击手势，设置代理以避免与按钮冲突
        UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dyyy_handleContainerTap:)];
        tapGesture.numberOfTapsRequired = 1;
        tapGesture.delegate = self;
        [self addGestureRecognizer:tapGesture];
        
        // 拖动手势
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dyyy_handlePipPan:)];
        pan.delegate = self;
        [self addGestureRecognizer:pan];
        
        // 监听应用进入后台和前台的通知
        [[NSNotificationCenter defaultCenter] addObserver:self 
                                                 selector:@selector(handleAppDidEnterBackground) 
                                                     name:UIApplicationDidEnterBackgroundNotification 
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self 
                                                 selector:@selector(handleAppWillEnterForeground) 
                                                     name:UIApplicationWillEnterForegroundNotification 
                                                   object:nil];
    }
    return self;
}

// 恢复全屏的方法
- (void)dyyy_restoreFullScreen {
    NSLog(@"DYYY: 开始恢复小窗视频为全屏播放");
    
    if (!self.awemeModel) {
        NSLog(@"DYYY: 恢复失败，awemeModel 为空");
        [DYYYManager showToast:@"恢复播放器失败"];
        [self dyyy_closeAndStopPip];
        return;
    }
    
    // 暂停小窗播放
    [self.pipPlayer pause];
    
    // 通过通知告知主界面切换到小窗中的视频
    [[NSNotificationCenter defaultCenter] postNotificationName:@"DYYYRestorePipVideo" 
                                                        object:nil 
                                                      userInfo:@{@"awemeModel": self.awemeModel}];
    
    // 延迟关闭小窗，确保主界面有时间处理
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self dyyy_closeAndStopPip];
    });
    
    NSLog(@"DYYY: 已发送恢复请求，正在切换到全屏播放");
}

// 声音切换方法
- (void)dyyy_toggleSound {
    if (!self.pipPlayer) {
        NSLog(@"DYYY: 播放器不存在，无法切换声音");
        return;
    }
    
    BOOL currentlyMuted = self.pipPlayer.isMuted;
    
    if (currentlyMuted) {
        // 当前静音，切换到有声音
        self.pipPlayer.muted = NO;
        self.pipPlayer.volume = 1.0;
        
        // 更新按钮图标为有声音状态
        if (@available(iOS 13.0, *)) {
            UIImage *soundImage = [UIImage systemImageNamed:@"speaker.wave.2.fill"];
            [self.restoreButton setImage:soundImage forState:UIControlStateNormal];
        } else {
            [self.restoreButton setTitle:@"🔊" forState:UIControlStateNormal];
        }
        
        self.restoreButton.accessibilityLabel = @"静音";
        NSLog(@"DYYY: 小窗声音已开启");
    } else {
        // 当前有声音，切换到静音
        self.pipPlayer.muted = YES;
        self.pipPlayer.volume = 0.0;
        
        // 更新按钮图标为静音状态
        if (@available(iOS 13.0, *)) {
            UIImage *mutedImage = [UIImage systemImageNamed:@"speaker.slash.fill"];
            [self.restoreButton setImage:mutedImage forState:UIControlStateNormal];
        } else {
            [self.restoreButton setTitle:@"🔇" forState:UIControlStateNormal];
        }
        
        self.restoreButton.accessibilityLabel = @"开启声音";
        NSLog(@"DYYY: 小窗声音已静音");
    }
}

// 设置小窗播放器
- (void)setupPipPlayerWithAwemeModel:(AWEAwemeModel *)awemeModel {
    if (!awemeModel) {
        NSLog(@"DYYY: awemeModel 为空，无法设置播放器");
        return;
    }
    
    self.awemeModel = awemeModel;
    
    // 清理之前的内容
    [self cleanupPreviousContent];
    
    NSLog(@"DYYY: 开始设置小窗播放器，视频类型: %ld", (long)awemeModel.awemeType);
    
    // 根据内容类型设置播放器
    if (awemeModel.awemeType == 68) {
        // 图片内容
        [self setupImageContentForAwemeModel:awemeModel];
    } else if (awemeModel.awemeType == 150) {
        // 实况照片
        [self setupLivePhotoContentForAwemeModel:awemeModel];
    } else {
        // 视频内容
        [self setupVideoContentForAwemeModel:awemeModel];
    }
}

// 更新小窗播放器内容
- (void)updatePipPlayerWithAwemeModel:(AWEAwemeModel *)awemeModel {
    if (!awemeModel) return;
    
    // 保存当前声音状态
    BOOL wasMuted = self.pipPlayer ? self.pipPlayer.isMuted : YES;
    
    // 设置新内容
    [self setupPipPlayerWithAwemeModel:awemeModel];
    
    // 恢复声音状态
    if (self.pipPlayer) {
        self.pipPlayer.muted = wasMuted;
    }
}

// 设置视频内容
- (void)setupVideoContentForAwemeModel:(AWEAwemeModel *)awemeModel {
    AWEVideoModel *videoModel = awemeModel.video;
    if (!videoModel) {
        NSLog(@"DYYY: 视频模型为空");
        return;
    }
    
    // 获取视频URL
    NSURL *videoURL = nil;
    if (videoModel.playURL && videoModel.playURL.originURLList.count > 0) {
        videoURL = [NSURL URLWithString:videoModel.playURL.originURLList.firstObject];
    } else if (videoModel.h264URL && videoModel.h264URL.originURLList.count > 0) {
        videoURL = [NSURL URLWithString:videoModel.h264URL.originURLList.firstObject];
    }
    
    if (!videoURL) {
        NSLog(@"DYYY: 无法获取视频URL");
        return;
    }
    
    NSLog(@"DYYY: 设置视频播放器，URL: %@", videoURL);
    
    // 创建播放器
    self.pipPlayer = [AVPlayer playerWithURL:videoURL];
    self.pipPlayer.muted = YES; // 默认静音
    
    // 创建播放器层
    self.pipPlayerLayer = [AVPlayerLayer playerLayerWithPlayer:self.pipPlayer];
    self.pipPlayerLayer.frame = self.contentContainerLayer.bounds;
    self.pipPlayerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.contentContainerLayer.layer addSublayer:self.pipPlayerLayer];
    
    // 设置循环播放
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerDidFinishPlaying:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:self.pipPlayer.currentItem];
    
    // 添加播放器观察者
    [self addPlayerObservers];
    
    // 开始播放
    [self.pipPlayer play];
    self.isPlayingInPip = YES;
    
    NSLog(@"DYYY: 视频播放器设置完成");
}

// 设置图片内容
- (void)setupImageContentForAwemeModel:(AWEAwemeModel *)awemeModel {
    // 获取图片URL
    NSArray *imageList = awemeModel.albumImages;
    if (imageList.count == 0) {
        NSLog(@"DYYY: 没有找到图片");
        return;
    }
    
    // 使用第一张图片
    AWEImageAlbumImageModel *imageModel = imageList.firstObject;
    NSString *imageURLString = imageModel.urlList.firstObject;
    if (!imageURLString) {
        NSLog(@"DYYY: 图片URL为空");
        return;
    }
    
    NSURL *imageURL = [NSURL URLWithString:imageURLString];
    
    // 异步加载图片
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSData *imageData = [NSData dataWithContentsOfURL:imageURL];
        UIImage *image = [UIImage imageWithData:imageData];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (image) {
                UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
                imageView.frame = self.contentContainerLayer.bounds;
                imageView.contentMode = UIViewContentModeScaleAspectFill;
                imageView.clipsToBounds = YES;
                [self.contentContainerLayer addSubview:imageView];
                NSLog(@"DYYY: 图片显示完成");
            }
        });
    });
}

// 设置实况照片内容
- (void)setupLivePhotoContentForAwemeModel:(AWEAwemeModel *)awemeModel {
    // 实况照片通常有视频和图片两部分，这里简化处理
    [self setupVideoContentForAwemeModel:awemeModel];
}

// 清理之前的内容
- (void)cleanupPreviousContent {
    // 移除播放器层
    if (self.pipPlayerLayer) {
        [self.pipPlayerLayer removeFromSuperlayer];
        self.pipPlayerLayer = nil;
    }
    
    // 停止播放器
    if (self.pipPlayer) {
        [self.pipPlayer pause];
        [self removePlayerObservers];
        self.pipPlayer = nil;
    }
    
    // 清理容器中的子视图
    for (UIView *subview in self.contentContainerLayer.subviews) {
        [subview removeFromSuperview];
    }
    
    self.isPlayingInPip = NO;
}

// 添加播放器观察者
- (void)addPlayerObservers {
    if (!self.pipPlayer) return;
    
    // 监听播放失败
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerFailedToPlay:)
                                                 name:AVPlayerItemFailedToPlayToEndTimeNotification
                                               object:self.pipPlayer.currentItem];
    
    // 监听播放卡顿
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerStalled:)
                                                 name:AVPlayerItemPlaybackStalledNotification
                                               object:self.pipPlayer.currentItem];
}

// 移除播放器观察者
- (void)removePlayerObservers {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemFailedToPlayToEndTimeNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemPlaybackStalledNotification object:nil];
}

// 播放完成处理
- (void)playerDidFinishPlaying:(NSNotification *)notification {
    // 循环播放
    [self.pipPlayer seekToTime:kCMTimeZero];
    [self.pipPlayer play];
}

// 播放失败处理
- (void)playerFailedToPlay:(NSNotification *)notification {
    NSLog(@"DYYY: 小窗播放失败");
    [DYYYManager showToast:@"小窗播放失败"];
}

// 播放卡顿处理
- (void)playerStalled:(NSNotification *)notification {
    NSLog(@"DYYY: 小窗播放卡顿");
}

// 关闭并停止小窗播放
- (void)dyyy_closeAndStopPip {
    NSLog(@"DYYY: 关闭小窗播放");
    
    // 清理资源
    [self cleanupPreviousContent];
    
    // 移除通知观察者
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    // 从父视图移除
    [self removeFromSuperview];
    
    // 清理全局引用
    [DYYYPipManager setSharedPipContainer:nil];
}

// 拖动手势处理
- (void)dyyy_handlePipPan:(UIPanGestureRecognizer *)pan {
    CGPoint translation = [pan translationInView:self.superview];
    
    if (pan.state == UIGestureRecognizerStateBegan) {
        // 记录初始中心点
        objc_setAssociatedObject(self, @selector(dyyy_handlePipPan:), [NSValue valueWithCGPoint:self.center], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    
    NSValue *originValue = objc_getAssociatedObject(self, @selector(dyyy_handlePipPan:));
    CGPoint originCenter = originValue ? [originValue CGPointValue] : self.center;
    CGPoint newCenter = CGPointMake(originCenter.x + translation.x, originCenter.y + translation.y);
    
    // 限制小窗不超出父视图边界
    CGFloat halfW = self.bounds.size.width / 2.0;
    CGFloat halfH = self.bounds.size.height / 2.0;
    CGFloat minX = halfW, maxX = self.superview.bounds.size.width - halfW;
    CGFloat minY = halfH, maxY = self.superview.bounds.size.height - halfH;
    
    newCenter.x = MAX(minX, MIN(maxX, newCenter.x));
    newCenter.y = MAX(minY, MIN(maxY, newCenter.y));
    
    self.center = newCenter;
    
    if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
        // 结束时重置 translation
        [pan setTranslation:CGPointZero inView:self.superview];
    }
}

// 容器点击处理
- (void)dyyy_handleContainerTap:(UITapGestureRecognizer *)tap {
    CGPoint location = [tap locationInView:self];
    
    // 检查关闭按钮区域
    CGRect closeButtonArea = CGRectMake(0, 0, 44, 44);
    if (CGRectContainsPoint(closeButtonArea, location)) {
        return;
    }
    
    // 检查声音按钮区域
    CGRect soundButtonArea = CGRectMake(self.bounds.size.width - 44, 0, 44, 44);
    if (CGRectContainsPoint(soundButtonArea, location)) {
        return;
    }
    
    // 切换控制按钮显示
    [self dyyy_toggleControlButtons];
}

// 切换控制按钮的显示/隐藏
- (void)dyyy_toggleControlButtons {
    static BOOL buttonsVisible = YES;
    
    [UIView animateWithDuration:0.3 animations:^{
        self.restoreButton.alpha = buttonsVisible ? 0.0 : 1.0;
        
        // 查找关闭按钮并切换显示
        for (UIView *subview in self.subviews) {
            if ([subview isKindOfClass:[UIButton class]] && subview != self.restoreButton) {
                subview.alpha = buttonsVisible ? 0.0 : 1.0;
            }
        }
    }];
    
    buttonsVisible = !buttonsVisible;
    
    // 如果隐藏了按钮，3秒后自动显示
    if (!buttonsVisible) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (!buttonsVisible) {
                [self dyyy_toggleControlButtons];
            }
        });
    }
}

// 手势代理方法
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    CGPoint location = [touch locationInView:self];
    
    if ([gestureRecognizer isKindOfClass:[UITapGestureRecognizer class]]) {
        // 关闭按钮区域
        CGRect closeButtonArea = CGRectMake(0, 0, 44, 44);
        if (CGRectContainsPoint(closeButtonArea, location)) {
            return NO;
        }
        
        // 声音按钮区域
        CGRect soundButtonArea = CGRectMake(self.bounds.size.width - 44, 0, 44, 44);
        if (CGRectContainsPoint(soundButtonArea, location)) {
            return NO;
        }
    }
    
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return NO;
}

// 进入后台时暂停播放
- (void)handleAppDidEnterBackground {
    if (self.pipPlayer) {
        [self.pipPlayer pause];
        NSLog(@"DYYY: 抖音进入后台，小窗播放已暂停");
    }
}

// 回到前台时恢复播放
- (void)handleAppWillEnterForeground {
    if (self.pipPlayer && self.isPlayingInPip) {
        [self.pipPlayer play];
        NSLog(@"DYYY: 抖音回到前台，小窗播放已恢复");
    }
}

// 获取视频ID
- (NSString *)getAwemeId {
    if (self.awemeModel) {
        if ([self.awemeModel respondsToSelector:@selector(awemeId)]) {
            return [self.awemeModel awemeId];
        } else if ([self.awemeModel respondsToSelector:@selector(awemeID)]) {
            return [self.awemeModel awemeID];
        }
    }
    return nil;
}

- (void)dealloc {
    [self cleanupPreviousContent];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end

// UIView 快照扩展
@implementation UIView (DYYYSnapshot)

- (UIImage *)dyyy_snapshotImage {
    UIGraphicsBeginImageContextWithOptions(self.bounds.size, NO, [UIScreen mainScreen].scale);
    [self drawViewHierarchyInRect:self.bounds afterScreenUpdates:NO];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

@end

// 添加长按面板相关的方法
@implementation DYYYPipManager (LongPressPanel)

// 处理PIP按钮点击
+ (void)handlePipButtonWithAwemeModel:(AWEAwemeModel *)awemeModel {
    NSLog(@"DYYY: PIP 按钮被点击");
    
    if (!awemeModel) {
        [DYYYManager showToast:@"无法获取视频信息"];
        return;
    }
    
    // 检查PIP功能是否启用
    BOOL pipEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYLongPressDownload"] &&
                      [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYLongPressPip"];
    
    if (!pipEnabled) {
        [DYYYManager showToast:@"小窗播放功能未启用"];
        return;
    }
    
    // 使用DYYYPipManager创建小窗
    [[DYYYPipManager sharedManager] createPipWithAwemeModel:awemeModel];
    [DYYYManager showToast:@"已开启小窗播放"];
}

// 恢复PIP视频到全屏
+ (void)handleRestorePipVideo:(NSNotification *)notification {
    AWEAwemeModel *awemeModel = notification.userInfo[@"awemeModel"];
    NSString *awemeId = nil;
    
    if ([awemeModel respondsToSelector:@selector(awemeId)]) {
        awemeId = [awemeModel performSelector:@selector(awemeId)];
    } else if ([awemeModel respondsToSelector:@selector(awemeID)]) {
        awemeId = [awemeModel performSelector:@selector(awemeID)];
    }
    
    if (!awemeId || !awemeModel) {
        NSLog(@"DYYY: 恢复失败，视频信息无效");
        return;
    }
    
    // 确保在主线程执行
    dispatch_async(dispatch_get_main_queue(), ^{
        // 查找当前的播放控制器
        id playController = [self findPlayInteractionControllerInVC:[DYYYManager getActiveTopController]];
        
        if (!playController) {
            // 备用方法：通过主窗口查找
            UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
            if (!keyWindow) {
                keyWindow = [UIApplication sharedApplication].windows.firstObject;
            }
            
            if (keyWindow) {
                playController = [self findPlayInteractionControllerInView:keyWindow];
            }
        }
        
        if (playController) {
            NSLog(@"DYYY: 找到播放控制器，执行视频切换");
            
            // 获取当前播放的视频ID
            AWEAwemeModel *currentModel = [playController valueForKey:@"awemeModel"];
            NSString *currentVideoId = nil;
            if ([currentModel respondsToSelector:@selector(awemeId)]) {
                currentVideoId = [currentModel performSelector:@selector(awemeId)];
            } else if ([currentModel respondsToSelector:@selector(awemeID)]) {
                currentVideoId = [currentModel performSelector:@selector(awemeID)];
            }
            
            // 比较视频ID，只有不同才切换
            if (!currentVideoId || ![currentVideoId isEqualToString:awemeId]) {
                NSLog(@"DYYY: 开始切换视频: %@ -> %@", currentVideoId ?: @"unknown", awemeId);
                
                // 使用通知方式强制刷新播放器
                [[NSNotificationCenter defaultCenter] postNotificationName:@"DYYYForceRefreshPlayer"
                                                                    object:nil
                                                                  userInfo:@{
                                                                      @"awemeModel": awemeModel,
                                                                      @"action": @"refresh",
                                                                      @"source": @"pipRestore"
                                                                  }];
                
                // 确保设置了正确的模型
                if ([playController respondsToSelector:@selector(setAwemeModel:)]) {
                    [playController setAwemeModel:awemeModel];
                }
                
                [DYYYManager showToast:@"已恢复小窗视频到全屏"];
            } else {
                NSLog(@"DYYY: 主界面已是目标视频，无需切换");
                [DYYYManager showToast:@"已是当前视频"];
            }
        } else {
            NSLog(@"DYYY: 未找到播放控制器，使用备用方法");
            // 备用方法：通过通知强制刷新
            [[NSNotificationCenter defaultCenter] postNotificationName:@"DYYYForceRefreshPlayer"
                                                                object:nil
                                                              userInfo:@{
                                                                  @"awemeModel": awemeModel,
                                                                  @"action": @"restore",
                                                                  @"source": @"pipFallback"
                                                              }];
        }
    });
}

// 处理视频切换
+ (void)handleVideoChange:(NSNotification *)notification {
    AWEAwemeModel *awemeModel = notification.userInfo[@"awemeModel"];
    
    if (!awemeModel) return;
    
    // 如果有活跃的小窗，更新小窗内容
    DYYYPipContainerView *existingPip = [self sharedPipContainer];
    if (existingPip && existingPip.superview) {
        NSString *currentPipId = [existingPip getAwemeId];
        NSString *newVideoId = nil;
        
        if ([awemeModel respondsToSelector:@selector(awemeId)]) {
            newVideoId = [awemeModel performSelector:@selector(awemeId)];
        } else if ([awemeModel respondsToSelector:@selector(awemeID)]) {
            newVideoId = [awemeModel performSelector:@selector(awemeID)];
        }
        
        // 如果是不同的视频，更新小窗内容
        if (newVideoId && ![newVideoId isEqualToString:currentPipId]) {
            NSLog(@"DYYY: 主视频切换，更新小窗内容：%@ -> %@", currentPipId, newVideoId);
            [existingPip updatePipPlayerWithAwemeModel:awemeModel];
        }
    }
}

// 查找播放控制器
+ (id)findPlayInteractionControllerInVC:(UIViewController *)vc {
    if (!vc) return nil;
    
    // 检查当前控制器
    if ([vc isKindOfClass:NSClassFromString(@"AWEPlayInteractionViewController")]) {
        return vc;
    }
    
    // 递归检查子控制器
    for (UIViewController *childVC in vc.childViewControllers) {
        id found = [self findPlayInteractionControllerInVC:childVC];
        if (found) return found;
    }
    
    // 检查presented控制器
    if (vc.presentedViewController) {
        id found = [self findPlayInteractionControllerInVC:vc.presentedViewController];
        if (found) return found;
    }
    
    return nil;
}

+ (id)findPlayInteractionControllerInView:(UIView *)view {
    if (!view) return nil;
    
    // 检查视图的控制器
    UIViewController *vc = [view nextResponder];
    while (vc && ![vc isKindOfClass:[UIViewController class]]) {
        vc = [vc nextResponder];
    }
    
    if ([vc isKindOfClass:NSClassFromString(@"AWEPlayInteractionViewController")]) {
        return vc;
    }
    
    // 递归检查子视图
    for (UIView *subview in view.subviews) {
        id found = [self findPlayInteractionControllerInView:subview];
        if (found) return found;
    }
    
    return nil;
}

@end

// 添加通知监听器初始化
@implementation DYYYPipManager (Notifications)

+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // 监听PIP恢复通知
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleRestorePipVideo:)
                                                     name:@"DYYYRestorePipVideo"
                                                   object:nil];
        
        // 监听视频切换通知
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleVideoChange:)
                                                     name:@"AWEPlayInteractionVideoDidChange"
                                                   object:nil];
    });
}

@end