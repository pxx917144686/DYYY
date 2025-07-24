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



@interface DYYYPipContainerView : UIView <UIGestureRecognizerDelegate>
@property (nonatomic, strong) UIView *mediaDecorationLayer;
@property (nonatomic, strong) UIView *contentContainerLayer;
@property (nonatomic, strong) UIView *danmakuContainerLayer;
@property (nonatomic, strong) UIView *diggAnimationContainer;
@property (nonatomic, strong) UIView *operationContainerLayer;
@property (nonatomic, strong) UIView *floatContainerLayer;
@property (nonatomic, strong) UIView *keyboardContainerLayer;
@property (nonatomic, strong) UIButton *restoreButton;
@property (nonatomic, weak) UIView *originalParentView;
@property (nonatomic, assign) CGRect originalFrame;
@property (nonatomic, weak) UIView *playerView;
@property (nonatomic, strong) AWEAwemeModel *awemeModel; // 保存当前播放的视频模型
@property (nonatomic, strong) AVPlayer *pipPlayer; // 小窗专用播放器
@property (nonatomic, strong) AVPlayerLayer *pipPlayerLayer; // 小窗播放器层
@property (nonatomic, assign) BOOL isPlayingInPip; // 是否正在小窗播放
- (void)dyyy_restoreFullScreen; // 方法声明
- (NSString *)getAwemeId; // 获取视频ID的方法声明
@end

@interface AWEAwemeModel (DYYYExtension)
- (NSString *)awemeId;
- (NSString *)awemeID;
@end

@interface NSObject (DYYYLongPressExtension)
- (void)setAwemeModel:(AWEAwemeModel *)awemeModel;
- (BOOL)dyyy_isSameAwemeModel:(AWEAwemeModel *)model1 target:(AWEAwemeModel *)model2;
- (void)dyyy_refreshPlayerWithAwemeModel:(AWEAwemeModel *)awemeModel;
- (void)dyyy_tryRefreshPlayerView:(AWEAwemeModel *)awemeModel;
- (void)dyyy_switchToAwemeModel:(NSNotification *)notification;
- (void)dyyy_handleForceRefreshPlayer:(NSNotification *)notification;
- (void)dyyy_forceRefreshPlayer:(AWEAwemeModel *)awemeModel;
- (UIView *)dyyy_findPlayerView:(UIView *)view;
- (NSString *)dyyy_getAwemeId:(AWEAwemeModel *)model;
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

// 方法定义
- (id)dyyy_searchPlayControllerInVC:(UIViewController *)vc {
    if (!vc) return nil;
    
    Class targetClass = NSClassFromString(@"AWEPlayInteractionViewController");
    if (!targetClass) {
        NSLog(@"DYYY: AWEPlayInteractionViewController 类不存在");
        return nil;
    }
    
    // 检查当前控制器
    if ([vc isKindOfClass:targetClass]) {
        return vc;
    }
    
    // 检查子控制器
    for (UIViewController *child in vc.childViewControllers) {
        id found = [self dyyy_searchPlayControllerInVC:child];
        if (found) return found;
    }
    
    // 检查呈现的控制器
    if (vc.presentedViewController) {
        id found = [self dyyy_searchPlayControllerInVC:vc.presentedViewController];
        if (found) return found;
    }
    
    // 通过视图响应链查找
    return [self dyyy_searchPlayControllerInView:vc.view];
}

+ (id)dyyy_findPlayInteractionControllerInVC:(UIViewController *)vc {
    if (!vc) return nil;
    
    Class targetClass = NSClassFromString(@"AWEPlayInteractionViewController");
    if (!targetClass) {
        NSLog(@"DYYY: AWEPlayInteractionViewController 类不存在");
        return nil;
    }
    
    // 检查自身是否为播放控制器
    if ([vc isKindOfClass:targetClass]) {
        NSLog(@"DYYY: 直接找到播放控制器: %@", [vc class]);
        return vc; // 返回 id 类型
    }
    
    // 检查是否为特定Feed相关控制器
    NSArray *feedControllerClasses = @[@"AWEFeedTableViewController", @"AWEFeedRootViewController", 
                                      @"AWEFeedContainerViewController", @"AWEAwemePlayVideoViewController"];
    for (NSString *className in feedControllerClasses) {
        if ([NSStringFromClass([vc class]) containsString:className]) {
            NSLog(@"DYYY: 找到Feed相关控制器: %@", [vc class]);
        }
    }
    
    // 递归检查子控制器
    for (UIViewController *childVC in vc.childViewControllers) {
        id found = [self dyyy_findPlayInteractionControllerInVC:childVC];
        if (found) {
            return found;
        }
    }
    
    // 检查视图中可能嵌入的控制器
    id foundInView = [self dyyy_findPlayInteractionControllerInView:vc.view];
    if (foundInView) {
        return foundInView;
    }
    
    // 检查呈现的控制器
    if (vc.presentedViewController) {
        id found = [self dyyy_findPlayInteractionControllerInVC:vc.presentedViewController];
        if (found) return found;
    }
    
    // 检查父控制器
    if (vc.presentingViewController) {
        id found = [self dyyy_findPlayInteractionControllerInVC:vc.presentingViewController];
        if (found) return found;
    }
    
    return nil;
}

+ (id)dyyy_findPlayInteractionControllerInView:(UIView *)view {
    if (!view) return nil;
    
    Class targetClass = NSClassFromString(@"AWEPlayInteractionViewController");
    if (!targetClass) return nil;
    
    // 首先检查这个视图的下一个响应者
    UIResponder *responder = view.nextResponder;
    while (responder) {
        if ([responder isKindOfClass:targetClass]) {
            NSLog(@"DYYY: 在响应者链中找到播放器控制器: %@", [responder class]);
            return responder; // 返回 id 类型
        }
        responder = responder.nextResponder;
    }
    
    // 检查是否是TTPlayerView或相关视图
    if ([NSStringFromClass([view class]) containsString:@"TTPlayerView"] ||
        [NSStringFromClass([view class]) containsString:@"VideoPlayer"]) {
        NSLog(@"DYYY: 找到播放器视图: %@", [view class]);
        // 从播放器视图向上查找控制器
        UIResponder *playerResponder = view;
        while (playerResponder) {
            if ([playerResponder isKindOfClass:targetClass]) {
                return playerResponder;
            }
            playerResponder = playerResponder.nextResponder;
        }
    }
    
    // 递归检查子视图
    for (UIView *subview in view.subviews) {
        // 优先检查AWEFeed相关视图
        if ([NSStringFromClass([subview class]) containsString:@"AWEFeed"] ||
            [NSStringFromClass([subview class]) containsString:@"Player"] ||
            [NSStringFromClass([subview class]) containsString:@"Video"]) {
            id found = [self dyyy_findPlayInteractionControllerInView:subview];
            if (found) return found;
        }
    }
    
    // 再检查所有其他子视图
    for (UIView *subview in view.subviews) {
        id found = [self dyyy_findPlayInteractionControllerInView:subview];
        if (found) return found;
    }
    
    return nil;
}

// 通过视图查找播放控制器
- (id)dyyy_searchPlayControllerInView:(UIView *)view {
    if (!view) return nil;
    
    Class targetClass = NSClassFromString(@"AWEPlayInteractionViewController");
    if (!targetClass) return nil;
    
    // 检查响应链
    UIResponder *responder = view.nextResponder;
    while (responder) {
        if ([responder isKindOfClass:targetClass]) {
            return responder;
        }
        responder = responder.nextResponder;
    }
    
    // 递归检查子视图
    for (UIView *subview in view.subviews) {
        id found = [self dyyy_searchPlayControllerInView:subview];
        if (found) return found;
    }
    
    return nil;
}

// 查找当前播放控制器
- (id)dyyy_findCurrentPlayController {
    // 通过顶层控制器
    UIViewController *topVC = [DYYYManager getActiveTopController];
    id playController = [self dyyy_searchPlayControllerInVC:topVC];
    
    if (playController) {
        return playController;
    }
    
    // 通过主窗口
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    if (!keyWindow) {
        keyWindow = [UIApplication sharedApplication].windows.firstObject;
    }
    
    if (keyWindow) {
        playController = [self dyyy_searchPlayControllerInView:keyWindow];
        if (playController) {
            return playController;
        }
    }
    
    // 遍历所有窗口
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        playController = [self dyyy_searchPlayControllerInView:window];
        if (playController) {
            return playController;
        }
    }
    
    return nil;
}

// 修改手势代理方法，避免按钮区域触发整体点击
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    CGPoint location = [touch locationInView:self];
    
    if ([gestureRecognizer isKindOfClass:[UITapGestureRecognizer class]]) {
        // 关闭按钮区域
        CGRect closeButtonArea = CGRectMake(0, 0, 44, 44);
        if (CGRectContainsPoint(closeButtonArea, location)) {
            return NO;
        }
        
        // 声音按钮区域 - 右上角
        CGRect soundButtonArea = CGRectMake(self.bounds.size.width - 44, 0, 44, 44);
        if (CGRectContainsPoint(soundButtonArea, location)) {
            return NO; // 让声音按钮自己处理
        }
    }
    
    return YES;
}
// 容器点击处理，排除恢复按钮区域
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
        return; // 让声音按钮处理
    }
    
    // 这里可以 添加其他功能，比如显示/隐藏控制按钮
    [self dyyy_toggleControlButtons];
}

// 切换控制按钮的显示/隐藏
- (void)dyyy_toggleControlButtons {
    static BOOL buttonsVisible = YES;
    
    [UIView animateWithDuration:0.3 animations:^{
        self.restoreButton.alpha = buttonsVisible ? 0.0 : 1.0; // 声音按钮
        
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

// 单击手势处理方法
- (void)dyyy_handleSingleTap:(UITapGestureRecognizer *)tap {
    // 触发声音切换
    [self dyyy_toggleSound];
}

// 延迟恢复方法，避免与关闭操作冲突
- (void)dyyy_restoreFullScreenWithDelay {
    // 短暂延迟确保不与其他操作冲突
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self dyyy_toggleSound]; // 切换声音
    });
}

// 手势代理方法，允许多个手势同时识别
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    // 拖动和点击不能同时进行
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

// 处理点击恢复手势
- (void)dyyy_handleTapToRestore:(UITapGestureRecognizer *)tap {
    // 只有在点击时才恢复，拖动时不恢复
    CGPoint location = [tap locationInView:self];
    
    // 检查是否点击在关闭按钮上
    UIButton *closeButton = nil;
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UIButton class]]) {
            UIButton *button = (UIButton *)subview;
            if ([button.titleLabel.text isEqualToString:@"×"]) {
                closeButton = button;
                break;
            }
        }
    }
    
    if (closeButton && CGRectContainsPoint(closeButton.frame, location)) {
        // 点击在关闭按钮上，不处理恢复
        return;
    }
    
    NSLog(@"DYYY: 小窗被点击，准备恢复全屏播放");
    [self dyyy_restoreFullScreen];
}

// 方法：设置小窗播放的视频
- (void)setupPipPlayerWithAwemeModel:(AWEAwemeModel *)awemeModel {
    self.awemeModel = awemeModel;
    
    // 清理之前的播放器和图片视图
    [self cleanupPreviousContent];
    
    // 根据内容类型选择不同的处理方式
    if (awemeModel.awemeType == 68) {
        // 图片集合类型
        [self setupImageContentForAwemeModel:awemeModel];
    } else if (awemeModel.awemeType == 2) {
        // iPhone 动图类型 (Live Photo)
        [self setupLivePhotoForAwemeModel:awemeModel];
    } else {
        // 视频类型
        [self setupVideoContentForAwemeModel:awemeModel];
    }
    
    self.isPlayingInPip = YES;
    NSLog(@"DYYY: 小窗内容设置完成，类型: %ld", (long)awemeModel.awemeType);
}

// 清理之前的内容
- (void)cleanupPreviousContent {
    // 清理播放器
    if (self.pipPlayer) {
        [self.pipPlayer pause];
        self.pipPlayer = nil;
    }
    
    // 清理播放器层
    if (self.pipPlayerLayer) {
        [self.pipPlayerLayer removeFromSuperlayer];
        self.pipPlayerLayer = nil;
    }
    
    // 清理所有子视图
    for (UIView *subview in self.contentContainerLayer.subviews) {
        [subview removeFromSuperview];
    }
    
    // 清理所有子图层
    NSArray *sublayers = [self.contentContainerLayer.layer.sublayers copy];
    for (CALayer *layer in sublayers) {
        [layer removeFromSuperlayer];
    }
}

// 设置图片内容
- (void)setupImageContentForAwemeModel:(AWEAwemeModel *)awemeModel {
    if (!awemeModel.albumImages || awemeModel.albumImages.count == 0) {
        NSLog(@"DYYY: 没有找到图片内容");
        return;
    }
    
    // 获取当前显示的图片
    AWEImageAlbumImageModel *currentImage = nil;
    if (awemeModel.currentImageIndex > 0 && awemeModel.currentImageIndex <= awemeModel.albumImages.count) {
        currentImage = awemeModel.albumImages[awemeModel.currentImageIndex - 1];
    } else {
        currentImage = awemeModel.albumImages.firstObject;
    }
    
    if (!currentImage || !currentImage.urlList || currentImage.urlList.count == 0) {
        NSLog(@"DYYY: 当前图片无效");
        return;
    }
    
    // 查找最佳图片URL
    NSString *imageURLString = nil;
    for (NSString *urlString in currentImage.urlList) {
        NSURL *url = [NSURL URLWithString:urlString];
        NSString *pathExtension = [url.path.lowercaseString pathExtension];
        if (![pathExtension isEqualToString:@"image"]) {
            imageURLString = urlString;
            break;
        }
    }
    
    if (!imageURLString && currentImage.urlList.count > 0) {
        imageURLString = currentImage.urlList.firstObject;
    }
    
    if (!imageURLString) {
        NSLog(@"DYYY: 无法获取图片URL");
        return;
    }
    
    // 异步加载图片
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSData *imageData = [NSData dataWithContentsOfURL:[NSURL URLWithString:imageURLString]];
        UIImage *image = [UIImage imageWithData:imageData];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (image) {
                UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
                imageView.frame = self.contentContainerLayer.bounds;
                imageView.contentMode = UIViewContentModeScaleAspectFill;
                imageView.clipsToBounds = YES;
                [self.contentContainerLayer addSubview:imageView];
                NSLog(@"DYYY: 图片内容已设置");
            } else {
                NSLog(@"DYYY: 图片加载失败");
            }
        });
    });
}

// 设置 Live Photo 内容
- (void)setupLivePhotoForAwemeModel:(AWEAwemeModel *)awemeModel {
    // 先设置封面图片
    if (awemeModel.video && awemeModel.video.coverURL && awemeModel.video.coverURL.originURLList.count > 0) {
        NSString *coverURLString = awemeModel.video.coverURL.originURLList.firstObject;
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSData *imageData = [NSData dataWithContentsOfURL:[NSURL URLWithString:coverURLString]];
            UIImage *coverImage = [UIImage imageWithData:imageData];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if (coverImage) {
                    UIImageView *coverImageView = [[UIImageView alloc] initWithImage:coverImage];
                    coverImageView.frame = self.contentContainerLayer.bounds;
                    coverImageView.contentMode = UIViewContentModeScaleAspectFill;
                    coverImageView.clipsToBounds = YES;
                    [self.contentContainerLayer addSubview:coverImageView];
                    NSLog(@"DYYY: Live Photo 封面已设置");
                }
            });
        });
    }
    
    // 如果有视频URL，设置静音视频播放
    if (awemeModel.video && awemeModel.video.playURL && awemeModel.video.playURL.originURLList.count > 0) {
        [self setupVideoContentForAwemeModel:awemeModel];
    }
}

// 方法：更新小窗播放的视频
- (void)updatePipPlayerWithAwemeModel:(AWEAwemeModel *)awemeModel {
    if (!awemeModel) return;
    
    NSLog(@"DYYY: 开始更新小窗内容，类型: %ld", (long)awemeModel.awemeType);
    
    // 记住当前的声音设置
    BOOL wasMuted = self.pipPlayer ? self.pipPlayer.isMuted : YES;
    CGFloat currentVolume = self.pipPlayer ? self.pipPlayer.volume : 0.0;
    
    // 移除旧的监听器
    [self removePlayerObservers];
    
    // 重新设置内容
    [self setupPipPlayerWithAwemeModel:awemeModel];
    
    // 恢复之前的声音设置
    if (self.pipPlayer) {
        self.pipPlayer.muted = wasMuted;
        self.pipPlayer.volume = currentVolume;
        
        // 更新按钮图标
        if (wasMuted) {
            if (@available(iOS 13.0, *)) {
                UIImage *mutedImage = [UIImage systemImageNamed:@"speaker.slash.fill"];
                [self.restoreButton setImage:mutedImage forState:UIControlStateNormal];
            } else {
                [self.restoreButton setTitle:@"🔇" forState:UIControlStateNormal];
            }
            self.restoreButton.accessibilityLabel = @"开启声音";
        } else {
            if (@available(iOS 13.0, *)) {
                UIImage *soundImage = [UIImage systemImageNamed:@"speaker.wave.2.fill"];
                [self.restoreButton setImage:soundImage forState:UIControlStateNormal];
            } else {
                [self.restoreButton setTitle:@"🔊" forState:UIControlStateNormal];
            }
            self.restoreButton.accessibilityLabel = @"静音";
        }
    }
    
    NSLog(@"DYYY: 小窗内容更新完成，声音设置已保持");
}

// 设置视频内容（静音且保持播放稳定）
- (void)setupVideoContentForAwemeModel:(AWEAwemeModel *)awemeModel {
    AWEVideoModel *videoModel = awemeModel.video;
    if (!videoModel) {
        NSLog(@"DYYY: 没有视频模型");
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
    
    // 创建小窗专用播放器
    self.pipPlayer = [AVPlayer playerWithURL:videoURL];
    
    // **默认设置为静音**
    self.pipPlayer.volume = 0.0;
    self.pipPlayer.muted = YES;
    
    // 设置播放器属性以保持稳定播放
    if (@available(iOS 10.0, *)) {
        self.pipPlayer.automaticallyWaitsToMinimizeStalling = NO;
    }
    
    // 创建播放器层
    self.pipPlayerLayer = [AVPlayerLayer playerLayerWithPlayer:self.pipPlayer];
    self.pipPlayerLayer.frame = self.contentContainerLayer.bounds;
    self.pipPlayerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.contentContainerLayer.layer addSublayer:self.pipPlayerLayer];
    
    // 监听播放器状态变化
    [self addPlayerObservers];
    
    // 开始播放
    [self.pipPlayer play];
    
    // 确保声音按钮显示正确的静音图标
    if (@available(iOS 13.0, *)) {
        UIImage *mutedImage = [UIImage systemImageNamed:@"speaker.slash.fill"];
        [self.restoreButton setImage:mutedImage forState:UIControlStateNormal];
    } else {
        [self.restoreButton setTitle:@"🔇" forState:UIControlStateNormal];
    }
    self.restoreButton.accessibilityLabel = @"开启声音";
    
    NSLog(@"DYYY: 视频播放器设置完成（默认静音）");
}

// 添加播放器监听器以保持稳定播放
- (void)addPlayerObservers {
    if (!self.pipPlayer) return;
    
    // 监听播放器状态
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handlePlayerDidFinishPlaying:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:self.pipPlayer.currentItem];
    
    // 监听播放失败
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handlePlayerFailedToPlay:)
                                                 name:AVPlayerItemFailedToPlayToEndTimeNotification
                                               object:self.pipPlayer.currentItem];
    
    // 监听播放暂停
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handlePlayerStalled:)
                                                 name:AVPlayerItemPlaybackStalledNotification
                                               object:self.pipPlayer.currentItem];
}

// 移除播放器监听器
- (void)removePlayerObservers {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemFailedToPlayToEndTimeNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemPlaybackStalledNotification object:nil];
}

// 处理播放完成 - 循环播放
- (void)handlePlayerDidFinishPlaying:(NSNotification *)notification {
    if (self.pipPlayer && self.isPlayingInPip) {
        [self.pipPlayer seekToTime:kCMTimeZero];
        [self.pipPlayer play];
        NSLog(@"DYYY: 小窗视频循环播放");
    }
}

// 处理播放失败
- (void)handlePlayerFailedToPlay:(NSNotification *)notification {
    NSLog(@"DYYY: 小窗视频播放失败，尝试重新播放");
    if (self.pipPlayer && self.isPlayingInPip) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.pipPlayer play];
        });
    }
}

// 处理播放卡顿
- (void)handlePlayerStalled:(NSNotification *)notification {
    NSLog(@"DYYY: 小窗视频播放卡顿，尝试恢复");
    if (self.pipPlayer && self.isPlayingInPip) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.pipPlayer play];
        });
    }
}


// 关闭方法 - 清理所有资源
- (void)dyyy_closeAndStopPip {
    NSLog(@"DYYY: 开始关闭小窗");
    
    // 移除监听器
    [self removePlayerObservers];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    // 停止播放器
    if (self.pipPlayer) {
        [self.pipPlayer pause];
        self.pipPlayer = nil;
    }
    
    // 清理播放器层
    if (self.pipPlayerLayer) {
        [self.pipPlayerLayer removeFromSuperlayer];
        self.pipPlayerLayer = nil;
    }
    
    self.isPlayingInPip = NO;
    
    // 清除全局引用
    Class longPressClass = NSClassFromString(@"AWEModernLongPressPanelTableViewController");
    if (longPressClass && [longPressClass respondsToSelector:@selector(setSharedPipContainer:)]) {
        [longPressClass performSelector:@selector(setSharedPipContainer:) withObject:nil];
    }
    
    [self removeFromSuperview];
    NSLog(@"DYYY: 小窗已完全关闭并清理资源");
}

// 拖动手势处理：允许拖动小窗
- (void)dyyy_handlePipPan:(UIPanGestureRecognizer *)pan {
    UIView *pipContainer = pan.view;
    CGPoint translation = [pan translationInView:self.superview];
    static CGPoint originCenter;
    
    if (pan.state == UIGestureRecognizerStateBegan) {
        originCenter = pipContainer.center;
        NSLog(@"DYYY: 开始拖动小窗");
        // 开始拖动时稍微放大
        [UIView animateWithDuration:0.1 animations:^{
            pipContainer.transform = CGAffineTransformMakeScale(1.05, 1.05);
        }];
    }
    
    CGPoint newCenter = CGPointMake(originCenter.x + translation.x, originCenter.y + translation.y);
    
    // 限制边界
    CGFloat halfW = pipContainer.bounds.size.width / 2.0;
    CGFloat halfH = pipContainer.bounds.size.height / 2.0;
    CGFloat minX = halfW, maxX = self.superview.bounds.size.width - halfW;
    CGFloat minY = halfH + 50, maxY = self.superview.bounds.size.height - halfH - 50; // 留出状态栏和底部安全区域
    
    newCenter.x = MAX(minX, MIN(maxX, newCenter.x));
    newCenter.y = MAX(minY, MIN(maxY, newCenter.y));
    pipContainer.center = newCenter;
    
    if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
        [pan setTranslation:CGPointZero inView:self.superview];
        NSLog(@"DYYY: 结束拖动小窗");
        
        // 结束拖动时恢复大小
        [UIView animateWithDuration:0.2 animations:^{
            pipContainer.transform = CGAffineTransformIdentity;
        }];
        
        // 自动吸附到边缘
        CGFloat screenWidth = self.superview.bounds.size.width;
        CGFloat currentX = pipContainer.center.x;
        CGFloat targetX = (currentX < screenWidth / 2) ? halfW + 10 : screenWidth - halfW - 10;
        
        [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            pipContainer.center = CGPointMake(targetX, pipContainer.center.y);
        } completion:nil];
    }
}

// 析构方法 - 确保资源清理
- (void)dealloc {
    [self removePlayerObservers];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    if (self.pipPlayer) {
        [self.pipPlayer pause];
    }
}

@end

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

@interface AWEModernLongPressPanelTableViewController (DYYY_PIP)
- (void)dyyy_handlePipButton;
- (UIView *)dyyy_clonePlayerView:(UIView *)originalView;
- (void)cloneVideoPlaybackControls:(UIView *)source toDestination:(UIView *)destination;
- (void)setupVideoSourceForClone:(UIView *)original clone:(UIView *)clone;
- (void)updateDYYYPipContainerRestoreMethod;
- (void)dyyy_handleRestorePipVideo:(NSNotification *)notification;
- (void)dyyy_handleVideoChange:(NSNotification *)notification;
- (void)dyyy_forceVideoSwitch:(AWEAwemeModel *)targetAwemeModel;
- (void)dyyy_findAndSwitchInView:(UIView *)view targetModel:(AWEAwemeModel *)targetModel;
+ (DYYYPipContainerView *)sharedPipContainer;
+ (void)setSharedPipContainer:(DYYYPipContainerView *)container;
+ (void)dyyy_forceSwitchToModel:(AWEAwemeModel *)awemeModel;
+ (id)dyyy_findPlayInteractionControllerInVC:(UIViewController *)vc;
+ (id)dyyy_findPlayInteractionControllerInView:(UIView *)view;
@end

@interface UIView (DYYYSnapshot)
- (UIImage *)dyyy_snapshotImage;
@end

@implementation UIView (DYYYSnapshot)
- (UIImage *)dyyy_snapshotImage {
    UIGraphicsBeginImageContextWithOptions(self.bounds.size, NO, [UIScreen mainScreen].scale);
    [self.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}
@end

// 属性声明
%hook AWELongPressPanelViewGroupModel
%property(nonatomic, assign) BOOL isDYYYCustomGroup;
%end

%group LongPressExtension
// 通过遍历 AWEPlayInteractionViewController 的 view 层级，找到 TTPlayerView
%hook AWEPlayInteractionViewController

// 获取视频ID的辅助方法
%new
- (NSString *)dyyy_getAwemeId:(AWEAwemeModel *)model {
    if (!model) return nil;
    
    if ([model respondsToSelector:@selector(awemeId)]) {
        return [model performSelector:@selector(awemeId)];
    } else if ([model respondsToSelector:@selector(awemeID)]) {
        return [model performSelector:@selector(awemeID)];
    }
    return nil;
}

// 强制刷新播放器
%new
- (void)dyyy_forceRefreshPlayer:(AWEAwemeModel *)awemeModel {
    NSLog(@"DYYY: 强制刷新播放器，目标视频ID: %@", [self dyyy_getAwemeId:awemeModel]);
    
    if (!awemeModel) {
        NSLog(@"DYYY: 刷新失败，awemeModel 为空");
        return;
    }
    
    // 直接设置模型
    if ([self respondsToSelector:@selector(setAwemeModel:)]) {
        [self setAwemeModel:awemeModel];
        NSLog(@"DYYY: 已调用 setAwemeModel");
    }
    
    // 尝试调用重新加载方法
    if ([self respondsToSelector:@selector(reloadWithAwemeModel:)]) {
        [self performSelector:@selector(reloadWithAwemeModel:) withObject:awemeModel];
        NSLog(@"DYYY: 已调用 reloadWithAwemeModel");
    }
    
    // 查找并操作播放器视图
    UIView *playerView = [self dyyy_findPlayerView:self.view];
    if (playerView) {
        NSLog(@"DYYY: 找到播放器视图: %@", NSStringFromClass([playerView class]));
        
        if ([playerView respondsToSelector:@selector(setAwemeModel:)]) {
            [playerView performSelector:@selector(setAwemeModel:) withObject:awemeModel];
        }
        
        if ([playerView respondsToSelector:@selector(refreshWithAwemeModel:)]) {
            [playerView performSelector:@selector(refreshWithAwemeModel:) withObject:awemeModel];
        }
        
        if ([playerView respondsToSelector:@selector(play)]) {
            [playerView performSelector:@selector(play)];
        }
    }
    
    // 强制重新布局
    [self.view setNeedsLayout];
    [self.view layoutIfNeeded];
    
    // 发送视频更新通知
    [[NSNotificationCenter defaultCenter] postNotificationName:@"AWEPlayInteractionVideoDidChange" 
                                                        object:nil 
                                                      userInfo:@{@"awemeModel": awemeModel}];
    
    NSLog(@"DYYY: 播放器刷新完成");
}

// 查找播放器视图
%new
- (UIView *)dyyy_findPlayerView:(UIView *)view {
    NSString *className = NSStringFromClass([view class]);
    if ([className containsString:@"TTPlayerView"] || [className containsString:@"Player"]) {
        return view;
    }
    
    for (UIView *subview in view.subviews) {
        UIView *found = [self dyyy_findPlayerView:subview];
        if (found) return found;
    }
    
    return nil;
}

// 递归查找 TTPlayerView
UIView* findTTPlayerView(UIView *root) {
    if ([NSStringFromClass([root class]) containsString:@"TTPlayerView"]) {
        return root;
    }
    for (UIView *sub in root.subviews) {
        UIView *found = findTTPlayerView(sub);
        if (found) return found;
    }
    return nil;
}

- (void)setAwemeModel:(AWEAwemeModel *)awemeModel {
    %orig;
    
    // 发送视频切换通知
    if (awemeModel) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"AWEPlayInteractionVideoDidChange" 
                                                            object:nil 
                                                          userInfo:@{@"awemeModel": awemeModel}];
    }
}

// 监听切换到指定视频的请求
- (void)viewDidLoad {
    %orig;
    
    // 移除旧的监听器避免重复
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"DYYYSwitchToAwemeModel" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"DYYYForceRefreshPlayer" object:nil];
    
    // 重新添加监听器
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(dyyy_switchToAwemeModel:) 
                                                 name:@"DYYYSwitchToAwemeModel" 
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(dyyy_handleForceRefreshPlayer:) 
                                                 name:@"DYYYForceRefreshPlayer" 
                                               object:nil];
}

// 新方法
%new
- (void)dyyy_handleForceRefreshPlayer:(NSNotification *)notification {
    AWEAwemeModel *targetAwemeModel = notification.userInfo[@"awemeModel"];
    NSString *action = notification.userInfo[@"action"];
    
    if (targetAwemeModel && [action isEqualToString:@"restore"]) {
        NSLog(@"DYYY: 收到强制刷新播放器请求");
        [self dyyy_forceRefreshPlayer:targetAwemeModel];
    }
}

%new
- (void)dyyy_switchToAwemeModel:(NSNotification *)notification {
    AWEAwemeModel *targetAwemeModel = notification.userInfo[@"awemeModel"];
    NSString *source = notification.userInfo[@"source"];
    BOOL forceSwitch = [notification.userInfo[@"force"] boolValue]; // 获取强制刷新标记
    
    if (!targetAwemeModel) {
        NSLog(@"DYYY: 切换失败，目标视频模型为空");
        return;
    }
    
    // 获取目标视频ID
    NSString *targetAwemeId = [self dyyy_getAwemeId:targetAwemeModel];
    
    NSLog(@"DYYY: 请求切换到视频: %@，来源: %@, 强制刷新: %@", targetAwemeId, source, forceSwitch ? @"是" : @"否");
    
    // 获取当前的 awemeModel 进行比较
    AWEAwemeModel *currentModel = [self valueForKey:@"awemeModel"];
    
    // 获取当前视频ID
    NSString *currentAwemeId = [self dyyy_getAwemeId:currentModel];
    
    // 如果不是强制切换，并且是同一个视频，则无需切换
    if (!forceSwitch && currentAwemeId && targetAwemeId && [currentAwemeId isEqualToString:targetAwemeId]) {
        NSLog(@"DYYY: 当前就是目标视频，无需切换");
        if ([source isEqualToString:@"pipRestore"]) {
            [DYYYManager showToast:@"已是当前视频"];
        }
        return;
    }
    
    // 执行切换
    NSLog(@"DYYY: 开始切换视频：从 %@ 到 %@", currentAwemeId ?: @"unknown", targetAwemeId ?: @"unknown");
    
    // 使用更可靠的方式强制刷新播放器
    [self dyyy_forceRefreshPlayer:targetAwemeModel];
    
    NSLog(@"DYYY: 视频切换完成");
    
    if ([source isEqualToString:@"pipRestore"]) {
        [DYYYManager showToast:@"正在恢复小窗视频..."];
    }
}

// 判断两个 AWEAwemeModel 是否是同一个视频
%new
- (BOOL)dyyy_isSameAwemeModel:(AWEAwemeModel *)model1 target:(AWEAwemeModel *)model2 {
    if (!model1 || !model2) return NO;
    
    // 比较 awemeId
    NSString *id1 = nil, *id2 = nil;
    if ([model1 respondsToSelector:@selector(awemeId)]) {
        id1 = [model1 performSelector:@selector(awemeId)];
    } else if ([model1 respondsToSelector:@selector(awemeID)]) {
        id1 = [model1 performSelector:@selector(awemeID)];
    }
    
    if ([model2 respondsToSelector:@selector(awemeId)]) {
        id2 = [model2 performSelector:@selector(awemeId)];
    } else if ([model2 respondsToSelector:@selector(awemeID)]) {
        id2 = [model2 performSelector:@selector(awemeID)];
    }
    
    return id1 && id2 && [id1 isEqualToString:id2];
}

// 刷新播放器以显示新视频
%new
- (void)dyyy_refreshPlayerWithAwemeModel:(AWEAwemeModel *)awemeModel {
    NSLog(@"DYYY: 刷新播放器以显示新视频");
    
    // 尝试调用重新加载方法
    if ([self respondsToSelector:@selector(reloadWithAwemeModel:)]) {
        [self performSelector:@selector(reloadWithAwemeModel:) withObject:awemeModel];
        return;
    }
    
    // 尝试调用刷新方法
    if ([self respondsToSelector:@selector(refreshWithAwemeModel:)]) {
        [self performSelector:@selector(refreshWithAwemeModel:) withObject:awemeModel];
        return;
    }
    
    // 尝试调用配置方法
    if ([self respondsToSelector:@selector(configWithAwemeModel:)]) {
        [self performSelector:@selector(configWithAwemeModel:) withObject:awemeModel];
        return;
    }
    
    // 查找并调用播放器相关方法
    [self dyyy_tryRefreshPlayerView:awemeModel];
}

// 尝试刷新播放器视图
%new
- (void)dyyy_tryRefreshPlayerView:(AWEAwemeModel *)awemeModel {
    // 查找播放器视图
    UIView *playerView = findTTPlayerView(self.view);
    if (playerView) {
        NSLog(@"DYYY: 找到播放器视图，尝试刷新");
        
        // 尝试调用播放器的重新加载方法
        if ([playerView respondsToSelector:@selector(setAwemeModel:)]) {
            [playerView performSelector:@selector(setAwemeModel:) withObject:awemeModel];
        }
        
        // 尝试调用播放器的播放方法
        if ([playerView respondsToSelector:@selector(play)]) {
            [playerView performSelector:@selector(play)];
        }
        
        // 尝试调用控制器的重新布局
        [self.view setNeedsLayout];
        [self.view layoutIfNeeded];
    }
    
    // 尝试通过通知刷新
    [[NSNotificationCenter defaultCenter] postNotificationName:@"DYYYForceRefreshPlayer" 
                                                        object:nil 
                                                      userInfo:@{@"awemeModel": awemeModel}];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"DYYYSwitchToAwemeModel" object:nil];
    %orig;
}

%end
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

// 添加属性声明
%property(nonatomic, strong) UIView *dyyy_backgroundColorView;

// 使用关联对象存储全局 PIP 容器
%new
+ (DYYYPipContainerView *)sharedPipContainer {
    return objc_getAssociatedObject(self, @selector(sharedPipContainer));
}

// dyyy_restoreFullScreen 方法中的逻辑
%new
- (void)updateDYYYPipContainerRestoreMethod {
    // 通过运行时替换 DYYYPipContainerView 的 dyyy_restoreFullScreen 方法
    Class pipClass = [DYYYPipContainerView class];
    Method originalMethod = class_getInstanceMethod(pipClass, @selector(dyyy_restoreFullScreen));
    
    if (originalMethod) {
        IMP newImplementation = imp_implementationWithBlock(^(DYYYPipContainerView *pipContainer) {
            NSLog(@"DYYY: 开始恢复小窗视频为全屏播放");
            
            if (!pipContainer.awemeModel) {
                NSLog(@"DYYY: 恢复失败，awemeModel 为空");
                [DYYYManager showToast:@"恢复播放器失败"];
                [pipContainer dyyy_closeAndStopPip];
                return;
            }
            
            // 暂停小窗播放
            [pipContainer.pipPlayer pause];
            
            // 通过通知告知主界面切换到小窗中的视频
            [[NSNotificationCenter defaultCenter] postNotificationName:@"DYYYRestorePipVideo" 
                                                                object:nil 
                                                              userInfo:@{@"awemeModel": pipContainer.awemeModel}];
            
            // 延迟关闭小窗，确保主界面有时间处理
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [pipContainer dyyy_closeAndStopPip];
            });
            
            NSLog(@"DYYY: 已发送恢复请求，正在切换到全屏播放");
        });
        
        method_setImplementation(originalMethod, newImplementation);
        NSLog(@"DYYY: 已替换 PIP 容器的恢复方法");
    } else {
        NSLog(@"DYYY: 无法找到 dyyy_restoreFullScreen 方法");
    }
}

%new
+ (void)setSharedPipContainer:(DYYYPipContainerView *)container {
    objc_setAssociatedObject(self, @selector(sharedPipContainer), container, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

// 新增：“全局方法”实现
%new
+ (void)dyyy_forceSwitchToModel:(AWEAwemeModel *)awemeModel {
    if (!awemeModel) {
        NSLog(@"DYYY: 切换失败，目标视频模型为空");
        return;
    }
    
    NSLog(@"DYYY: 开始强制切换视频，ID: %@", [awemeModel respondsToSelector:@selector(awemeId)] ? [awemeModel performSelector:@selector(awemeId)] : @"unknown");

    dispatch_async(dispatch_get_main_queue(), ^{
        // 通过顶层控制器查找
        UIViewController *topVC = [DYYYManager getActiveTopController];
        id playController = [self dyyy_findPlayInteractionControllerInVC:topVC]; // 使用 id
        
        // 通过主窗口查找
        if (!playController) {
            UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
            if (!keyWindow) {
                keyWindow = [UIApplication sharedApplication].windows.firstObject;
            }
            playController = [self dyyy_findPlayInteractionControllerInView:keyWindow];
        }
        
        // 遍历所有窗口查找
        if (!playController) {
            for (UIWindow *window in [UIApplication sharedApplication].windows) {
                playController = [self dyyy_findPlayInteractionControllerInView:window];
                if (playController) break;
            }
        }
        
        if (playController) {
            NSLog(@"DYYY: 找到播放控制器，强制刷新视频");
            [playController dyyy_forceRefreshPlayer:awemeModel];
            
            // 额外的刷新操作
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if ([playController respondsToSelector:@selector(setAwemeModel:)]) {
                    [playController setAwemeModel:awemeModel];
                }
            });
        } else {
            NSLog(@"DYYY: 未找到播放控制器，使用备用方法");
            // 备用方法：通过通知系统
            [[NSNotificationCenter defaultCenter] postNotificationName:@"DYYYForceRefreshPlayer"
                                                                object:nil
                                                              userInfo:@{
                                                                  @"awemeModel": awemeModel,
                                                                  @"action": @"restore"
                                                              }];
        }
    });
}

// 触发小窗播放
%new
- (void)dyyy_handlePipButton {
    NSLog(@"DYYY: [1] dyyy_handlePipButton 方法被调用。");
    
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
        [existingPip updatePipPlayerWithAwemeModel:self.awemeModel];
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
    [pipContainer setupPipPlayerWithAwemeModel:self.awemeModel];
    
    // 保存全局引用 - 修正类方法调用
    [[self class] setSharedPipContainer:pipContainer];
    
    // 添加到主窗口
    [keyWindow addSubview:pipContainer];
    
    // 添加阴影效果
    pipContainer.layer.shadowColor = [UIColor blackColor].CGColor;
    pipContainer.layer.shadowOffset = CGSizeMake(0, 2);
    pipContainer.layer.shadowOpacity = 0.3;
    pipContainer.layer.shadowRadius = 8;
    
}

// 克隆播放器视图
%new
- (UIView *)dyyy_clonePlayerView:(UIView *)originalView {
    NSLog(@"DYYY: 正在克隆播放器视图用于画中画功能");
    
    // 创建一个快照，捕获当前播放画面
    UIImage *snapshot = [originalView dyyy_snapshotImage];
    UIImageView *snapshotView = [[UIImageView alloc] initWithImage:snapshot];
    snapshotView.frame = originalView.bounds;
    snapshotView.contentMode = UIViewContentModeScaleAspectFill;
    
    // 通过深度拷贝原始视图层次结构来创建克隆
    UIView *cloneView = [originalView snapshotViewAfterScreenUpdates:NO];
    cloneView.frame = originalView.bounds;
    
    // 将快照作为背景添加到克隆视图
    [cloneView insertSubview:snapshotView atIndex:0];
    
    // 尝试查找并克隆视频播放控件
    [self cloneVideoPlaybackControls:originalView toDestination:cloneView];
    
    // 处理视频内容源
    [self setupVideoSourceForClone:originalView clone:cloneView];
    
    NSLog(@"DYYY: 播放器视图克隆完成");
    return cloneView;
}

// 查找并克隆视频播放控件
%new
- (void)cloneVideoPlaybackControls:(UIView *)source toDestination:(UIView *)destination {
    // 查找源视图中的视频播放器组件
    for (UIView *subview in source.subviews) {
        if ([NSStringFromClass([subview class]) containsString:@"Player"] || 
            [NSStringFromClass([subview class]) containsString:@"Video"]) {
            // 找到播放器组件，克隆其关键属性
            UIView *clonedControl = [[subview class] new];
            clonedControl.frame = subview.frame;
            // 复制关键属性和状态
            if ([subview respondsToSelector:@selector(videoURL)]) {
                NSURL *videoURL = [subview valueForKey:@"videoURL"];
                [clonedControl setValue:videoURL forKey:@"videoURL"];
            }
            [destination addSubview:clonedControl];
        }
    }
}

// 克隆视图的视频源
%new
- (void)setupVideoSourceForClone:(UIView *)original clone:(UIView *)clone {
    // 获取当前视频模型
    AWEAwemeModel *awemeModel = self.awemeModel;
    if (!awemeModel) return;
    
    AWEVideoModel *videoModel = awemeModel.video;
    if (!videoModel) return;
    
    // 获取视频URL
    NSURL *videoURL = nil;
    if (videoModel.playURL && videoModel.playURL.originURLList.count > 0) {
        videoURL = [NSURL URLWithString:videoModel.playURL.originURLList.firstObject];
    } else if (videoModel.h264URL && videoModel.h264URL.originURLList.count > 0) {
        videoURL = [NSURL URLWithString:videoModel.h264URL.originURLList.firstObject];
    }
    
    if (!videoURL) return;
    
    // 尝试创建AVPlayer来播放相同视频
    AVPlayer *player = [AVPlayer playerWithURL:videoURL];
    AVPlayerLayer *playerLayer = [AVPlayerLayer playerLayerWithPlayer:player];
    playerLayer.frame = clone.bounds;
    playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [clone.layer insertSublayer:playerLayer atIndex:0];
    
    // 开始播放
    [player play];
    
    // 保存播放器引用以便稍后清理
    objc_setAssociatedObject(clone, "dyyy_avplayer", player, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

// 拖动小窗的手势处理
%new
- (void)dyyy_handlePipPan:(UIPanGestureRecognizer *)pan {
    UIView *pipContainer = pan.view;
    if (!pipContainer) return;
    CGPoint translation = [pan translationInView:self.view];
    if (pan.state == UIGestureRecognizerStateBegan) {
        // 记录初始中心点
        objc_setAssociatedObject(pipContainer, @selector(dyyy_handlePipPan:), [NSValue valueWithCGPoint:pipContainer.center], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    NSValue *originValue = objc_getAssociatedObject(pipContainer, @selector(dyyy_handlePipPan:));
    CGPoint originCenter = originValue ? [originValue CGPointValue] : pipContainer.center;
    CGPoint newCenter = CGPointMake(originCenter.x + translation.x, originCenter.y + translation.y);
    // 限制小窗不超出父视图边界
    CGFloat halfW = pipContainer.bounds.size.width / 2.0;
    CGFloat halfH = pipContainer.bounds.size.height / 2.0;
    CGFloat minX = halfW, maxX = self.view.bounds.size.width - halfW;
    CGFloat minY = halfH, maxY = self.view.bounds.size.height - halfH;
    newCenter.x = MAX(minX, MIN(maxX, newCenter.x));
    newCenter.y = MAX(minY, MIN(maxY, newCenter.y));
    pipContainer.center = newCenter;
    if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
        // 结束时重置 translation
        [pan setTranslation:CGPointZero inView:self.view];
    }
}

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
    
    // 更新 PIP 容器的恢复方法
    [self updateDYYYPipContainerRestoreMethod];
    
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
    
    // 移除 dispatch_once，确保每个实例都能添加监听器
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(dyyy_handleVideoChange:)
                                                 name:@"AWEPlayInteractionVideoDidChange"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(dyyy_handleRestorePipVideo:)
                                                 name:@"DYYYRestorePipVideo"
                                               object:nil];
}

// 移除通知监听
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"DYYYRestorePipVideo" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"AWEPlayInteractionVideoDidChange" object:nil];
    %orig;
}

// PIP 恢复处理方法
%new
- (void)dyyy_handleRestorePipVideo:(NSNotification *)notification {
    AWEAwemeModel *awemeModel = notification.userInfo[@"awemeModel"];
    NSString *awemeId = notification.userInfo[@"awemeId"];
    NSString *source = notification.userInfo[@"source"];
    NSString *action = notification.userInfo[@"action"];
    
    NSLog(@"DYYY: 收到 PIP 恢复通知，视频ID: %@, 来源: %@, 动作: %@", awemeId, source, action);
    
    if (!awemeModel) {
        NSLog(@"DYYY: PIP 恢复失败，awemeModel 为空");
        return;
    }
    
    // 确保在主线程执行
    dispatch_async(dispatch_get_main_queue(), ^{
        // 查找当前的播放控制器 - 使用 id 类型
        id playController = [[self class] dyyy_findPlayInteractionControllerInVC:[DYYYManager getActiveTopController]];
        
        if (!playController) {
            // 备用方法：通过主窗口查找
            UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
            if (!keyWindow) {
                keyWindow = [UIApplication sharedApplication].windows.firstObject;
            }
            
            if (keyWindow) {
                playController = [[self class] dyyy_findPlayInteractionControllerInView:keyWindow];
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
                
                // 强制切换视频
                [playController dyyy_forceRefreshPlayer:awemeModel];
                
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

// 视频切换处理方法
%new
- (void)dyyy_handleVideoChange:(NSNotification *)notification {
    AWEAwemeModel *awemeModel = notification.userInfo[@"awemeModel"];
    
    if (!awemeModel) return;
    
    // 如果有活跃的小窗，更新小窗内容
    DYYYPipContainerView *existingPip = [[self class] sharedPipContainer];
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
    // 颜色选择器开关检查
    BOOL enableColorPicker = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYEnableColorPicker"];
    // PIP 功能开关检查
    BOOL enablePip = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYEnablePip"];

    // 检查是否有任何功能启用
    hasAnyFeatureEnabled = enableSaveVideo || enableSaveCover || enableSaveAudio || enableSaveCurrentImage || enableSaveAllImages || 
                           enableCopyText || enableCopyLink || enableApiDownload || enableFilterUser || enableFilterKeyword || 
                           enableTimerClose || enableCreateVideo || enableFLEX || enableColorPicker || enablePip;

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
    
    // 面板颜色选择器
    if (enableColorPicker) {
        AWELongPressPanelBaseViewModel *colorPickerViewModel = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        colorPickerViewModel.awemeModel = self.awemeModel;
        colorPickerViewModel.actionType = 699; // 自定义操作
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

    // 小窗PIP播放功能
    if (enablePip) {
        NSLog(@"DYYY: 正在创建 PIP 按钮");
        AWELongPressPanelBaseViewModel *pipViewModel = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        pipViewModel.awemeModel = self.awemeModel;
        pipViewModel.actionType = 700;
        pipViewModel.duxIconName = @"ic_xiaoxihuazhonghua_outlined";
        pipViewModel.describeString = @"小窗播放";
        pipViewModel.action = ^{
            NSLog(@"DYYY: PIP 按钮被点击");
            AWELongPressPanelManager *panelManager = [%c(AWELongPressPanelManager) shareInstance];
            __weak __typeof__(self) weakSelf = self;
            [panelManager dismissWithAnimation:YES completion:^{
                __strong __typeof__(weakSelf) strongSelf = weakSelf;
                if (strongSelf) {
                    [strongSelf dyyy_handlePipButton];
                }
            }];
        };
        [viewModels addObject:pipViewModel];
        NSLog(@"DYYY: PIP 按钮已添加，当前按钮总数: %lu", (unsigned long)viewModels.count);
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
    
    // 添加 PIP 功能默认值
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYEnablePip"] == nil) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"DYYYEnablePip"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    // 初始化默认的钩子组
    %init(_ungrouped);
    
    // 初始化颜色选择器钩子组
    %init(ColorPickerGroup);
    
    // 初始化长按扩展钩子组
    %init(LongPressExtension);
    
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
