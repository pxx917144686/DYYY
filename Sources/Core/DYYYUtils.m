//
//  DYYYUtils.m
//  DYYY
//
//  公共工具主文件：配置内存缓存、遍历基础 C 函数、杂项工具方法。
//  广告过滤见 DYYYUtilsAdFilter.m，动图/媒体见 DYYYUtilsMedia.m，
//  视图/控制器遍历与玻璃 flex 见 DYYYUtilsTraversal.m，
//  缓存失效/特性迁移/玻璃门控见 DYYYUtilsConfig.m。
//

#import "DYYYUtils.h"
#import <UIKit/UIKit.h>
#import "DYYYTheme.h"

#pragma mark - 配置内存缓存

NSMutableDictionary *DYYYConfigCache(void) {
    static NSMutableDictionary *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [NSMutableDictionary dictionary];
    });
    return cache;
}

BOOL DYYYCachedBool(NSString *key) {
    if (!key) return NO;
    NSMutableDictionary *cache = DYYYConfigCache();
    NSString *cacheKey = [@"B:" stringByAppendingString:key];
    @synchronized (cache) {
        NSNumber *cached = cache[cacheKey];
        if (cached) return cached.boolValue;
    }
    BOOL value = [[NSUserDefaults standardUserDefaults] boolForKey:key];
    @synchronized (cache) {
        cache[cacheKey] = @(value);
    }
    return value;
}

NSString *DYYYCachedString(NSString *key) {
    if (!key) return nil;
    NSMutableDictionary *cache = DYYYConfigCache();
    NSString *cacheKey = [@"S:" stringByAppendingString:key];
    @synchronized (cache) {
        NSString *cached = cache[cacheKey];
        if (cached) return cached;
    }
    NSString *value = [[NSUserDefaults standardUserDefaults] stringForKey:key];
    if (!value) value = @"";
    @synchronized (cache) {
        cache[cacheKey] = value;
    }
    return value;
}

NSInteger DYYYCachedInteger(NSString *key) {
    if (!key) return 0;
    NSMutableDictionary *cache = DYYYConfigCache();
    NSString *cacheKey = [@"I:" stringByAppendingString:key];
    @synchronized (cache) {
        NSNumber *cached = cache[cacheKey];
        if (cached) return cached.integerValue;
    }
    NSInteger value = [[NSUserDefaults standardUserDefaults] integerForKey:key];
    @synchronized (cache) {
        cache[cacheKey] = @(value);
    }
    return value;
}

CGFloat DYYYCachedFloat(NSString *key) {
    if (!key) return 0.0;
    NSMutableDictionary *cache = DYYYConfigCache();
    NSString *cacheKey = [@"F:" stringByAppendingString:key];
    @synchronized (cache) {
        NSNumber *cached = cache[cacheKey];
        if (cached) return cached.doubleValue;
    }
    CGFloat value = [[NSUserDefaults standardUserDefaults] floatForKey:key];
    @synchronized (cache) {
        cache[cacheKey] = @(value);
    }
    return value;
}

// 关键词列表预编译缓存（逗号分隔配置 → trim 后的字符串数组）
NSMutableDictionary *DYYYKeywordListCache(void) {
    static NSMutableDictionary *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [NSMutableDictionary dictionary];
    });
    return cache;
}

NSArray<NSString *> *DYYYCachedKeywordList(NSString *configKey) {
    if (!configKey) return @[];
    NSMutableDictionary *cache = DYYYKeywordListCache();
    @synchronized (cache) {
        NSArray *cached = cache[configKey];
        if (cached) return cached;
    }
    NSString *raw = [[NSUserDefaults standardUserDefaults] objectForKey:configKey];
    NSMutableArray<NSString *> *result = [NSMutableArray array];
    if (raw.length > 0) {
        for (NSString *part in [raw componentsSeparatedByString:@","]) {
            NSString *trimmed = [part stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (trimmed.length > 0) {
                [result addObject:trimmed];
            }
        }
    }
    NSArray *immutable = [result copy];
    @synchronized (cache) {
        cache[configKey] = immutable;
    }
    return immutable;
}

#pragma mark - 遍历基础 C 函数

void DYYYEnumerateSubviews(UIView *view, void (^block)(UIView *)) {
    if (!view || !block) return;
    NSMutableArray<UIView *> *views = [NSMutableArray arrayWithObject:view];
    NSUInteger index = 0;
    while (index < views.count) {
        @autoreleasepool {
            UIView *current = views[index++];
            block(current);
            [views addObjectsFromArray:current.subviews];
        }
    }
}

static void DYYYCollectViewControllers(UIViewController *controller,
                                      NSMutableArray<UIViewController *> *result) {
    if (!controller) return;
    [result addObject:controller];
    for (UIViewController *child in controller.childViewControllers) {
        DYYYCollectViewControllers(child, result);
    }
}

NSArray<UIViewController *> *DYYYAllViewControllersInHierarchy(UIViewController *rootViewController) {
    if (!rootViewController) return @[];

    static NSArray<UIViewController *> *cachedResult = nil;
    static UIViewController *cachedRoot = nil;
    static NSTimeInterval lastCallTime = 0.0;
    NSTimeInterval now = [NSDate date].timeIntervalSinceReferenceDate;
    if (cachedResult && cachedRoot == rootViewController && now - lastCallTime < 0.5) {
        return cachedResult;
    }

    NSMutableArray<UIViewController *> *result = [NSMutableArray array];
    DYYYCollectViewControllers(rootViewController, result);
    cachedResult = result;
    cachedRoot = rootViewController;
    lastCallTime = now;
    return cachedResult;
}

static UIViewController *DYYYSearchChildController(UIViewController *controller, NSString *className, NSUInteger depth) {
    if (!controller || depth > 12) return nil;
    for (UIViewController *child in controller.childViewControllers) {
        if ([NSStringFromClass(child.class) isEqualToString:className]) return child;
        UIViewController *match = DYYYSearchChildController(child, className, depth + 1);
        if (match) return match;
    }
    return nil;
}

UIViewController *DYYYChildControllerNamed(UIViewController *controller, NSString *className) {
    return DYYYSearchChildController(controller, className, 0);
}

BOOL DYYYColorIsOpaqueBlack(UIColor *color) {
    if (!color) return NO;

    CGFloat red = 0.0;
    CGFloat green = 0.0;
    CGFloat blue = 0.0;
    CGFloat alpha = 0.0;
    if ([color getRed:&red green:&green blue:&blue alpha:&alpha]) {
        return red <= 0.02 && green <= 0.02 && blue <= 0.02 && alpha >= 0.98;
    }

    CGFloat white = 0.0;
    if ([color getWhite:&white alpha:&alpha]) {
        return white <= 0.02 && alpha >= 0.98;
    }
    return NO;
}

UIView *DYYYCellContentView(UIView *view) {
    static Class contentCls;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ contentCls = NSClassFromString(@"UITableViewCellContentView"); });
    if (!contentCls) return nil;

    for (NSUInteger i = 0; view && i < 12; i++) {
        if ([view isKindOfClass:contentCls]) return view;
        view = view.superview;
    }
    return nil;
}

CGFloat DYYYFullCellHeight(UIView *view) {
    UIView *contentView = DYYYCellContentView(view.superview);
    return contentView ? CGRectGetHeight(contentView.bounds) : 0.0;
}

BOOL DYYYViewControllerChainLooksLikeChat(UIViewController *vc) {
    static NSSet<NSString *> *markers;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        markers = [NSSet setWithObjects:@"Chat", @"Conversation", @"IMDetail", nil];
    });
    for (int i = 0; vc && i < 12; i++) {
        NSString *name = NSStringFromClass(vc.class);
        for (NSString *marker in markers) {
            if ([name containsString:marker]) return YES;
        }
        vc = vc.parentViewController;
    }
    return NO;
}

@implementation DYYYUtils

+ (void)showToast:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *topVC = [self topView];
        if (!topVC || !topVC.view) return;
        
        // 创建 Toast 标签
        UILabel *toastLabel = [[UILabel alloc] init];
        toastLabel.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.8];
        toastLabel.textColor = [UIColor whiteColor];
        toastLabel.textAlignment = NSTextAlignmentCenter;
        toastLabel.font = [UIFont systemFontOfSize:16];
        toastLabel.text = message;
        toastLabel.alpha = 0.0;
        toastLabel.layer.cornerRadius = 8;
        toastLabel.clipsToBounds = YES;
        
        // 计算大小和位置
        CGSize textSize = [message sizeWithAttributes:@{NSFontAttributeName: toastLabel.font}];
        CGFloat width = textSize.width + 32;
        CGFloat height = textSize.height + 16;
        CGFloat x = (topVC.view.bounds.size.width - width) / 2;
        CGFloat y = topVC.view.bounds.size.height - height - 100;
        
        toastLabel.frame = CGRectMake(x, y, width, height);
        [topVC.view addSubview:toastLabel];
        
        // 显示动画
        [UIView animateWithDuration:0.3 animations:^{
            toastLabel.alpha = 1.0;
        } completion:^(BOOL finished) {
            // 延迟隐藏
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [UIView animateWithDuration:0.3 animations:^{
                    toastLabel.alpha = 0.0;
                } completion:^(BOOL finished) {
                    [toastLabel removeFromSuperview];
                }];
            });
        }];
    });
}

+ (UIViewController *)topView {
    UIViewController *topViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
    
    while (topViewController.presentedViewController) {
        topViewController = topViewController.presentedViewController;
    }
    
    return topViewController;
}

+ (NSUInteger)clearDirectoryContents:(NSString *)directoryPath {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSUInteger totalSize = 0;
    
    if (![fileManager fileExistsAtPath:directoryPath]) {
        return 0;
    }
    
    NSError *error = nil;
    NSArray<NSString *> *contents = [fileManager contentsOfDirectoryAtPath:directoryPath error:&error];
    
    if (error) {
        NSLog(@"获取目录内容失败 %@: %@", directoryPath, error);
        return 0;
    }
    
    for (NSString *item in contents) {
        // 跳过隐藏文件
        if ([item hasPrefix:@"."]) {
            continue;
        }
        
        NSString *fullPath = [directoryPath stringByAppendingPathComponent:item];
        
        // 获取文件属性
        NSError *attrError = nil;
        NSDictionary<NSFileAttributeKey, id> *attrs = [fileManager attributesOfItemAtPath:fullPath error:&attrError];
        if (!attrs && attrError) {
            NSLog(@"[DYYYUtils] 获取文件属性失败: %@", attrError);
        }
        NSUInteger fileSize = attrs ? [attrs fileSize] : 0;
        
        // 判断是文件还是目录
        BOOL isDirectory;
        if ([fileManager fileExistsAtPath:fullPath isDirectory:&isDirectory]) {
            if (isDirectory) {
                // 如果是目录，先递归清理内容
                fileSize += [self clearDirectoryContents:fullPath];
            }
            
            // 然后删除文件或空目录
            NSError *delError = nil;
            [fileManager removeItemAtPath:fullPath error:&delError];
            if (delError) {
                NSLog(@"删除失败 %@: %@", fullPath, delError);
            } else {
                totalSize += fileSize;
            }
        }
    }
    
    return totalSize;
}

+ (void)applyBlurEffectToView:(UIView *)view transparency:(float)userTransparency blurViewTag:(NSInteger)tag {
    if (!view)
        return;

    view.backgroundColor = [UIColor clearColor];

    UIVisualEffectView *existingBlurView = nil;
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:[UIVisualEffectView class]] && subview.tag == tag) {
            existingBlurView = (UIVisualEffectView *)subview;
            break;
        }
    }

    BOOL isDarkMode = [DYYYUtils isDarkMode];
    UIBlurEffectStyle blurStyle = isDarkMode ? UIBlurEffectStyleDark : UIBlurEffectStyleLight;

    UIView *overlayView = nil;

    if (!existingBlurView) {
        UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:blurStyle];
        UIVisualEffectView *blurEffectView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
        blurEffectView.frame = view.bounds;
        blurEffectView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        blurEffectView.alpha = userTransparency;
        blurEffectView.tag = tag;

        overlayView = [[UIView alloc] initWithFrame:view.bounds];
        overlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [blurEffectView.contentView addSubview:overlayView];

        [view insertSubview:blurEffectView atIndex:0];
    } else {
        UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:blurStyle];
        [existingBlurView setEffect:blurEffect];
        existingBlurView.alpha = userTransparency;

        for (UIView *subview in existingBlurView.contentView.subviews) {
            if ([subview isKindOfClass:[UIView class]]) {
                overlayView = subview;
                break;
            }
        }
        if (!overlayView) {
            overlayView = [[UIView alloc] initWithFrame:existingBlurView.bounds];
            overlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [existingBlurView.contentView addSubview:overlayView];
        }
    }
    if (overlayView) {
        CGFloat alpha = isDarkMode ? 0.2 : 0.1;
        overlayView.backgroundColor = [UIColor colorWithWhite:(isDarkMode ? 0 : 1) alpha:alpha];
    }
}

+ (void)clearBackgroundRecursivelyInView:(UIView *)view {
    if (!view)
        return;

    BOOL shouldClear = YES;

    if ([view isKindOfClass:[UIVisualEffectView class]]) {
        shouldClear = NO;  // 不清除 UIVisualEffectView 本身的背景
    } else if (view.superview && [view.superview isKindOfClass:[UIVisualEffectView class]]) {
        shouldClear = NO;  // 不清除 UIVisualEffectView 的 contentView 的背景
    }

    if (shouldClear) {
        view.backgroundColor = [UIColor clearColor];
        view.opaque = NO;
    }

    for (UIView *subview in view.subviews) {
        [self clearBackgroundRecursivelyInView:subview];
    }
}

+ (BOOL)isDarkMode {
    return DYYYThemeIsDark();
}

// 在主线程安全延迟执行：weak-strong dance，避免 owner 释放后回调继续执行
+ (void)dispatchAfter:(NSTimeInterval)delaySeconds owner:(id)owner block:(dispatch_block_t)block {
    if (delaySeconds < 0) delaySeconds = 0;
    __weak id weakOwner = owner;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delaySeconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong id strongOwner = weakOwner;
        if (!strongOwner) return;
        if (block) block();
    });
}

@end

NSString *cleanShareURL(NSString *url) {
    if (!url || url.length == 0) {
        return url;
    }
    
    NSRange questionMarkRange = [url rangeOfString:@"?"];

    if (questionMarkRange.location != NSNotFound) {
        return [url substringToIndex:questionMarkRange.location];
    }

    return url;
}
