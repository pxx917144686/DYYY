//
//  DYYYVideoStatsHooks.xm
//  DYYY
//
//  视频模型 / 统计模型 / 视频按钮 hook，及特定视频统计与刷新逻辑。
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "AwemeHeaders.h"
#import "DYYYManager.h"
#import "DYYYUtils.h"
#import "DYYYSocialStatsShared.h"

// 在静态缓存区域添加
NSString *customVideoRecommends = nil;
NSNumber *cachedVideoRecommendsNumber = nil;

BOOL videoStatsEnabled = NO;
NSString *customVideoLikes = nil;
NSString *customVideoComments = nil;
NSString *customVideoCollects = nil;
NSString *customVideoShares = nil;

NSNumber *cachedVideoLikesNumber = nil;
NSNumber *cachedVideoCommentsNumber = nil;
NSNumber *cachedVideoCollectsNumber = nil;
NSNumber *cachedVideoSharesNumber = nil;

NSMutableDictionary *videoSpecificStats = nil;
dispatch_once_t videoSpecificStatsOnceToken;

void ensureVideoSpecificStatsInitialized(void) {
    dispatch_once(&videoSpecificStatsOnceToken, ^{
        if (!videoSpecificStats) {
            videoSpecificStats = [NSMutableDictionary dictionary];
        }
    });
}

id getCustomStatForVideo(NSString *videoId, NSString *statKey) {
    if (!videoId || !statKey) return nil;
    
    ensureVideoSpecificStatsInitialized();
        @synchronized(videoSpecificStats) {
        NSDictionary *videoStats = videoSpecificStats[videoId];
        if (!videoStats) return nil;
        
        return videoStats[statKey];
    }
}

// 通知处理方法，确保统计模型实例被刷新
void refreshAwemeStatisticsModels() {
    if (!videoStatsEnabled) return;
    
    // 延迟执行以确保UI已经完全加载
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        @try {
            UIViewController *topVC = [DYYYManager getActiveTopController];
            if (!topVC) return;
            
            // 查找视频单元格并刷新
            DYYYEnumerateSubviews(topVC.view, ^(UIView *view) {
                if ([view isKindOfClass:%c(AWEFeedTableCell)] ||
                    [view isKindOfClass:%c(AWEFeedViewCell)]) {
                    // 尝试触发刷新
                    [view setNeedsLayout];
                    [view layoutIfNeeded];
                    
                    if ([view respondsToSelector:@selector(dyyy_refreshVideoStats)]) {
                        [view performSelector:@selector(dyyy_refreshVideoStats)];
                    }
                }
            });
        } @catch (NSException *e) {
            NSLog(@"[DYYY] 刷新统计模型异常: %@", e);
        }
    });
}

// 一个用于直接修改视频数据的辅助函数
static void refreshVideoStatsForKeyPath(NSString *keyPath) {
    id value = nil;
    
    if ([keyPath isEqualToString:DYYY_VIDEO_LIKES_KEY]) {
        value = cachedVideoLikesNumber;
        keyPath = @"diggCount";
    } else if ([keyPath isEqualToString:DYYY_VIDEO_COMMENTS_KEY]) {
        value = cachedVideoCommentsNumber;
        keyPath = @"commentCount";
    } else if ([keyPath isEqualToString:DYYY_VIDEO_COLLECTS_KEY]) {
        value = cachedVideoCollectsNumber;
        keyPath = @"collectCount";
    } else if ([keyPath isEqualToString:DYYY_VIDEO_SHARES_KEY]) {
        value = cachedVideoSharesNumber;
        keyPath = @"shareCount";
    }
    
    if (!value) return;
    
    // 尝试查找和更新所有相关统计模型
    UIViewController *topVC = [DYYYManager getActiveTopController];
    if (topVC) {
        int count = objc_getClassList(NULL, 0);
        Class *classes = (__unsafe_unretained Class *)malloc(sizeof(Class) * count);
        objc_getClassList(classes, count);
        
        // 查找相关模型类
        Class statsModelClass = nil;
        for (int i = 0; i < count; i++) {
            Class cls = classes[i];
            if (class_getSuperclass(cls) != nil && class_conformsToProtocol(cls, @protocol(NSObject))) {
                const char *className = class_getName(cls);
                if (strstr(className, "AWEAwemeStatisticsModel") != NULL) {
                    statsModelClass = cls;
                    break;
                }
            }
        }
        
        free(classes);
        
        if (statsModelClass) {
            // 遍历所有对象
            unsigned int objectCount = 0;
            __unsafe_unretained Class *objects = (__unsafe_unretained Class *)objc_copyClassList(&objectCount);
            for (unsigned int i = 0; i < objectCount; i++) {
                if ([objects[i] isKindOfClass:statsModelClass]) {
                    @try {
                        [objects[i] setValue:value forKey:keyPath];
                    } @catch (NSException *e) {
                        NSLog(@"[DYYY] Exception in updating stats: %@", e);
                    }
                }
            }
            free(objects);
        }
    }
}

// 一个同步功能
void syncVideoStatsFromSettings() {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // 重新获取最新的设置值
    videoStatsEnabled = [defaults boolForKey:DYYY_VIDEO_STATS_ENABLED_KEY];
    customVideoLikes = [defaults objectForKey:DYYY_VIDEO_LIKES_KEY];
    customVideoComments = [defaults objectForKey:DYYY_VIDEO_COMMENTS_KEY];
    customVideoCollects = [defaults objectForKey:DYYY_VIDEO_COLLECTS_KEY];
    customVideoShares = [defaults objectForKey:DYYY_VIDEO_SHARES_KEY];
    
    // 重新转换为NSNumber
    cachedVideoLikesNumber = customVideoLikes ? @([customVideoLikes longLongValue]) : nil;
    cachedVideoCommentsNumber = customVideoComments ? @([customVideoComments longLongValue]) : nil;
    cachedVideoCollectsNumber = customVideoCollects ? @([customVideoCollects longLongValue]) : nil;
    cachedVideoSharesNumber = customVideoShares ? @([customVideoShares longLongValue]) : nil;
    
    // 刷新所有统计模型
    refreshAwemeStatisticsModels();
    
    // 分别刷新每个关键路径
    if (cachedVideoLikesNumber) refreshVideoStatsForKeyPath(DYYY_VIDEO_LIKES_KEY);
    if (cachedVideoCommentsNumber) refreshVideoStatsForKeyPath(DYYY_VIDEO_COMMENTS_KEY);
    if (cachedVideoCollectsNumber) refreshVideoStatsForKeyPath(DYYY_VIDEO_COLLECTS_KEY);
    if (cachedVideoSharesNumber) refreshVideoStatsForKeyPath(DYYY_VIDEO_SHARES_KEY);
    
    // 强制刷新所有 AWEAwemeStatisticsModel 实例
    dispatch_async(dispatch_get_main_queue(), ^{
        // 获取所有活跃视图控制器
        UIViewController *topVC = [DYYYManager getActiveTopController];
        if (topVC) {
            // 递归查找所有视图中的计数按钮并刷新
            DYYYEnumerateSubviews(topVC.view, ^(UIView *view) {
                // 更新收藏按钮
                if ([view isKindOfClass:%c(AWEFeedVideoButton)]) {
                    // 强制调用 setNeedsLayout 和 layoutIfNeeded 触发重绘
                    [view setNeedsLayout];
                    [view layoutIfNeeded];
                }
                
                // 寻找可能包含统计模型的视图
                if ([view respondsToSelector:@selector(awemeStatisticsModel)] ||
                    [view respondsToSelector:@selector(statisticsModel)]) {
                    // 触发统计数据更新
                    [view setNeedsLayout];
                    [view layoutIfNeeded];
                }
            });
        }
    });
}


%hook AWEAwemeModel

- (NSNumber *)diggCount {
    if (videoStatsEnabled && cachedVideoLikesNumber) {
        return cachedVideoLikesNumber;
    }
    return %orig;
}

- (void)setDiggCount:(NSNumber *)count {
    if (videoStatsEnabled && cachedVideoLikesNumber) {
        %orig(cachedVideoLikesNumber);
    } else {
        %orig;
    }
}

- (NSNumber *)commentCount {
    if (videoStatsEnabled && cachedVideoCommentsNumber) {
        return cachedVideoCommentsNumber;
    }
    return %orig;
}

- (void)setCommentCount:(NSNumber *)count {
    if (videoStatsEnabled && cachedVideoCommentsNumber) {
        %orig(cachedVideoCommentsNumber);
    } else {
        %orig;
    }
}

- (NSNumber *)collectCount {
    if (videoStatsEnabled && cachedVideoCollectsNumber) {
        return cachedVideoCollectsNumber;
    }
    return %orig;
}

- (void)setCollectCount:(NSNumber *)count {
    if (videoStatsEnabled && cachedVideoCollectsNumber) {
        %orig(cachedVideoCollectsNumber);
    } else {
        %orig;
    }
}

- (NSNumber *)shareCount {
    if (videoStatsEnabled && cachedVideoSharesNumber) {
        return cachedVideoSharesNumber;
    }
    return %orig;
}

- (void)setShareCount:(NSNumber *)count {
    if (videoStatsEnabled && cachedVideoSharesNumber) {
        %orig(cachedVideoSharesNumber);
    } else {
        %orig;
    }
}

%end

%hook AWEAwemeStatisticsModel

- (NSNumber *)favoriteCount {
    if (videoStatsEnabled && cachedVideoCollectsNumber) {
        return cachedVideoCollectsNumber;
    }
    return %orig;
}

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key {
    if ([key isEqualToString:@"favoriteCount"] && videoStatsEnabled && cachedVideoCollectsNumber) {
        return NO;
    }
    return %orig;
}

- (void)setFavoriteCount:(NSNumber *)count {
    if (videoStatsEnabled && cachedVideoCollectsNumber) {
        %orig(cachedVideoCollectsNumber);
    } else {
        %orig;
    }
}

- (NSNumber *)diggCount {
    @try {
        if (!videoStatsEnabled) {
            return %orig;
        }
        
        // 安全地获取自定义值
        NSNumber *customValue = cachedVideoLikesNumber;
        if (customValue && [customValue isKindOfClass:[NSNumber class]]) {
            return customValue;
        }
        
        return %orig;
    } @catch (NSException *exception) {
        NSLog(@"获取点赞数失败: %@", exception);
        return %orig;
    }
}

- (void)setDiggCount:(NSNumber *)count {
    if (videoStatsEnabled && cachedVideoLikesNumber) {
        %orig(cachedVideoLikesNumber);
    } else {
        %orig;
    }
}

- (NSNumber *)commentCount {
    if (videoStatsEnabled && cachedVideoCommentsNumber) {
        return cachedVideoCommentsNumber;
    }
    return %orig;
}

- (void)setCommentCount:(NSNumber *)count {
    if (videoStatsEnabled && cachedVideoCommentsNumber) {
        %orig(cachedVideoCommentsNumber);
    } else {
        %orig;
    }
}

- (NSNumber *)collectCount {
    if (videoStatsEnabled && cachedVideoCollectsNumber) {
        return cachedVideoCollectsNumber;
    }
    return %orig;
}

- (void)setCollectCount:(NSNumber *)count {
    if (videoStatsEnabled && cachedVideoCollectsNumber) {
        %orig(cachedVideoCollectsNumber);
    } else {
        %orig;
    }
}

- (NSNumber *)shareCount {
    if (videoStatsEnabled && cachedVideoSharesNumber) {
        return cachedVideoSharesNumber;
    }
    return %orig;
}

- (void)setShareCount:(NSNumber *)count {
    if (videoStatsEnabled && cachedVideoSharesNumber) {
        %orig(cachedVideoSharesNumber);
    } else {
        %orig;
    }
}

- (NSNumber *)forwardCount {
    if (videoStatsEnabled && cachedVideoRecommendsNumber) {
        return cachedVideoRecommendsNumber;
    }
    return %orig;
}

- (void)setForwardCount:(NSNumber *)count {
    if (videoStatsEnabled && cachedVideoRecommendsNumber) {
        %orig(cachedVideoRecommendsNumber);
    } else {
        %orig;
    }
}

- (id)init {
    id instance = %orig;
    
    if (videoStatsEnabled && instance) {
        // 检查方法是否存在并应用自定义值
        if (cachedVideoLikesNumber && [instance respondsToSelector:@selector(setDiggCount:)])
            [instance setDiggCount:cachedVideoLikesNumber];
            
        if (cachedVideoCommentsNumber && [instance respondsToSelector:@selector(setCommentCount:)])
            [instance performSelector:@selector(setCommentCount:) withObject:cachedVideoCommentsNumber];
            
        // 同时设置 favoriteCount 和 collectCount
        if (cachedVideoCollectsNumber) {
            if ([instance respondsToSelector:@selector(setCollectCount:)])
                [instance performSelector:@selector(setCollectCount:) withObject:cachedVideoCollectsNumber];
            
            if ([instance respondsToSelector:@selector(setFavoriteCount:)])
                [instance performSelector:@selector(setFavoriteCount:) withObject:cachedVideoCollectsNumber];
        }
            
        if (cachedVideoSharesNumber && [instance respondsToSelector:@selector(setShareCount:)])
            [instance performSelector:@selector(setShareCount:) withObject:cachedVideoSharesNumber];
    }
    
    return instance;
}

// KVC 赋值拦截
- (void)setValue:(id)value forKey:(NSString *)key {
    if (videoStatsEnabled) {
        if ([key isEqualToString:@"diggCount"] && cachedVideoLikesNumber) {
            %orig(cachedVideoLikesNumber, key);
        } 
        else if ([key isEqualToString:@"commentCount"] && cachedVideoCommentsNumber) {
            %orig(cachedVideoCommentsNumber, key);
        }
        else if ([key isEqualToString:@"collectCount"] && cachedVideoCollectsNumber) {
            %orig(cachedVideoCollectsNumber, key);
        }
        else if ([key isEqualToString:@"favoriteCount"] && cachedVideoCollectsNumber) {
            // 添加对 favoriteCount 的处理
            %orig(cachedVideoCollectsNumber, key);
        }
        else if ([key isEqualToString:@"shareCount"] && cachedVideoSharesNumber) {
            %orig(cachedVideoSharesNumber, key);
        }
        else {
            %orig;
        }
    } else {
        %orig;
    }
}

- (void)updateFavoriteCount:(NSNumber *)count {
    if (videoStatsEnabled && cachedVideoCollectsNumber) {
        %orig(cachedVideoCollectsNumber);
    } else {
        %orig;
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (videoStatsEnabled && [keyPath isEqualToString:@"favoriteCount"] && cachedVideoCollectsNumber) {
        NSMutableDictionary *mutableChange = [change mutableCopy];
        [mutableChange setObject:cachedVideoCollectsNumber forKey:NSKeyValueChangeNewKey];
        %orig(keyPath, object, [mutableChange copy], context);
    } else {
        %orig;
    }
}

%end


// 对视频按钮的钩子
%hook AWEFeedVideoButton

- (void)setCount:(NSNumber *)count {
    // 自定义数
    if (videoStatsEnabled) {
        NSString *type = nil;
        @try {
            if ([self respondsToSelector:@selector(type)]) {
                type = [self valueForKey:@"type"];
                
                if ([type isEqualToString:@"like"] && cachedVideoLikesNumber) {
                    %orig(cachedVideoLikesNumber);
                    return;
                }
                else if ([type isEqualToString:@"comment"] && cachedVideoCommentsNumber) {
                    %orig(cachedVideoCommentsNumber);
                    return;
                }
                else if ([type isEqualToString:@"collect"] && cachedVideoCollectsNumber) {
                    %orig(cachedVideoCollectsNumber);
                    return;
                }
                else if ([type isEqualToString:@"share"] && cachedVideoSharesNumber) {
                    %orig(cachedVideoSharesNumber);
                    return;
                }
            }
        } @catch (NSException *e) {
            NSLog(@"[DYYY] Exception in AWEFeedVideoButton: %@", e);
        }
    }
    %orig;
}

// 强制刷新按钮
- (void)layoutSubviews {
    %orig;
    
    if (videoStatsEnabled) {
        // 尝试获取按钮类型并设置对应值
        NSString *type = nil;
        @try {
            if ([self respondsToSelector:@selector(type)]) {
                type = [self valueForKey:@"type"];
                
                if ([type isEqualToString:@"like"] && cachedVideoLikesNumber) {
                    [self performSelector:@selector(setCount:) withObject:cachedVideoLikesNumber];
                }
                else if ([type isEqualToString:@"comment"] && cachedVideoCommentsNumber) {
                    [self performSelector:@selector(setCount:) withObject:cachedVideoCommentsNumber];
                }
                else if ([type isEqualToString:@"collect"] && cachedVideoCollectsNumber) {
                    [self performSelector:@selector(setCount:) withObject:cachedVideoCollectsNumber];
                }
                else if ([type isEqualToString:@"share"] && cachedVideoSharesNumber) {
                    [self performSelector:@selector(setCount:) withObject:cachedVideoSharesNumber];
                }
            }
        } @catch (NSException *e) {
            NSLog(@"[DYYY] Exception in AWEFeedVideoButton layoutSubviews: %@", e);
        }
    }
}
%end
