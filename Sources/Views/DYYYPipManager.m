#import "DYYYPipPlayer.h"
#import "DYYYUtils.h"
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
    
    // 创建小窗播放器
    DYYYPipManager *pipManager = [DYYYPipManager sharedManager];
    [pipManager createPipWithAwemeModel:awemeModel];
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