/***
* 202505281200
* pxx917144686
**/

//
//  DYYYSocialStatsHooks.xm
//  DYYY
//
//  用户资料与个人主页统计视图 hook：粉丝/点赞/关注/互关。
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "AwemeHeaders.h"
#import "DYYYManager.h"
#import "DYYYUtils.h"
#import "DYYYSocialStatsShared.h"

// 静态缓存
static NSString *customFollowersCount = nil;
static NSString *customLikesCount = nil;
static NSString *customFollowingCount = nil;
static NSString *customMutualCount = nil;
static BOOL socialStatsEnabled = NO;

// 静态缓存的NSNumber值
static NSNumber *cachedFollowersNumber = nil;
static NSNumber *cachedLikesNumber = nil;
static NSNumber *cachedFollowingNumber = nil;
static NSNumber *cachedMutualNumber = nil;

// 防止重复更新
static BOOL isUpdatingViews = NO;
static NSTimeInterval lastUpdateTimestamp = 0;

// 加载设置数据
void loadCustomSocialStats() {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    socialStatsEnabled = [defaults boolForKey:DYYY_SOCIAL_STATS_ENABLED_KEY];
    videoStatsEnabled = [defaults boolForKey:DYYY_VIDEO_STATS_ENABLED_KEY];
    
    // 原有个人资料数据加载
    if (socialStatsEnabled) {
        customFollowersCount = [defaults objectForKey:DYYY_SOCIAL_FOLLOWERS_KEY];
        customLikesCount = [defaults objectForKey:DYYY_SOCIAL_LIKES_KEY];
        customFollowingCount = [defaults objectForKey:DYYY_SOCIAL_FOLLOWING_KEY];
        customMutualCount = [defaults objectForKey:DYYY_SOCIAL_MUTUAL_KEY];
        
        cachedFollowersNumber = customFollowersCount ? @([customFollowersCount longLongValue]) : nil;
        cachedLikesNumber = customLikesCount ? @([customLikesCount longLongValue]) : nil;
        cachedFollowingNumber = customFollowingCount ? @([customFollowingCount longLongValue]) : nil;
        cachedMutualNumber = customMutualCount ? @([customMutualCount longLongValue]) : nil;
    }
    
    // 视频数据加载
    if (videoStatsEnabled) {
        customVideoLikes = [defaults objectForKey:DYYY_VIDEO_LIKES_KEY];
        customVideoComments = [defaults objectForKey:DYYY_VIDEO_COMMENTS_KEY];
        customVideoCollects = [defaults objectForKey:DYYY_VIDEO_COLLECTS_KEY];
        customVideoShares = [defaults objectForKey:DYYY_VIDEO_SHARES_KEY];
        customVideoRecommends = [defaults objectForKey:DYYY_VIDEO_RECOMMENDS_KEY];
        
        cachedVideoLikesNumber = customVideoLikes ? @([customVideoLikes longLongValue]) : nil;
        cachedVideoCommentsNumber = customVideoComments ? @([customVideoComments longLongValue]) : nil;
        cachedVideoCollectsNumber = customVideoCollects ? @([customVideoCollects longLongValue]) : nil;
        cachedVideoSharesNumber = customVideoShares ? @([customVideoShares longLongValue]) : nil;
        cachedVideoRecommendsNumber = customVideoRecommends ? @([customVideoRecommends longLongValue]) : nil;
    }
    
    // 移除特定视频数据加载
    ensureVideoSpecificStatsInitialized();
    @synchronized(videoSpecificStats) {
        [videoSpecificStats removeAllObjects];
    }
}

static void findAndRefreshSocialStatsViews(UIView *rootView) {
    if (!rootView) return;
    
    // 使用非递归方式遍历视图
    DYYYEnumerateSubviews(rootView, ^(UIView *view) {
        if ([view isKindOfClass:%c(AWEProfileSocialStatisticView)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                AWEProfileSocialStatisticView *statsView = (AWEProfileSocialStatisticView *)view;
                [statsView p_updateSocialStatisticContent:YES];
                
                // 尝试强制更新
                if (cachedFollowersNumber) [statsView setFansCount:cachedFollowersNumber];
                if (cachedLikesNumber) [statsView setPraiseCount:cachedLikesNumber];
                if (cachedFollowingNumber) [statsView setFollowingCount:cachedFollowingNumber];
                if (cachedMutualNumber) [statsView setFriendCount:cachedMutualNumber];
            });
        }
    });
}

static void refreshProfileControllerIfNeeded(UIViewController *controller) {
    if (!controller) return;
    
    if ([controller isKindOfClass:%c(AWEProfileHeaderMyProfileViewController)]) {
        AWEProfileHeaderMyProfileViewController *profileVC = (AWEProfileHeaderMyProfileViewController *)controller;
        dispatch_async(dispatch_get_main_queue(), ^{
            [profileVC reloadSettings];
        });
    }
    
    // 还要检查导航控制器和标签控制器的子控制器
    if ([controller isKindOfClass:[UINavigationController class]]) {
        UINavigationController *navController = (UINavigationController *)controller;
        refreshProfileControllerIfNeeded(navController.topViewController);
    }
    
    if ([controller isKindOfClass:[UITabBarController class]]) {
        UITabBarController *tabController = (UITabBarController *)controller;
        refreshProfileControllerIfNeeded(tabController.selectedViewController);
    }
}

// 模型数据更新
static void updateModelData(id model) {
    if (!socialStatsEnabled || !model) return;
    
    // 粉丝
    if (cachedFollowersNumber) {
        NSArray *followerKeys = @[@"followerCount", @"fansCount", @"fans_count"];
        for (NSString *key in followerKeys) {
            if ([model respondsToSelector:NSSelectorFromString(key)]) {
                [model setValue:cachedFollowersNumber forKey:key];
            }
        }
    }
    
    // 获赞
    if (cachedLikesNumber) {
        NSArray *likeKeys = @[
            @"totalFavorited", @"favoriteCount", @"diggCount", 
            @"praiseCount", @"likeCount", @"like_count",
            @"total_favorited", @"favorite_count", @"digg_count"
        ];
        for (NSString *key in likeKeys) {
            if ([model respondsToSelector:NSSelectorFromString(key)]) {
                [model setValue:cachedLikesNumber forKey:key];
            }
        }
    }
    
    // 关注
    if (cachedFollowingNumber) {
        NSArray *followingKeys = @[@"followingCount", @"followCount", @"follow_count"];
        for (NSString *key in followingKeys) {
            if ([model respondsToSelector:NSSelectorFromString(key)]) {
                [model setValue:cachedFollowingNumber forKey:key];
            }
        }
    }
    
    // 互关
    if (cachedMutualNumber) {
        NSArray *mutualKeys = @[
            @"friendCount", @"mutualFriendCount", @"followFriendCount",
            @"mutualCount", @"friend_count", @"mutual_friend_count",
            @"follow_friend_count", @"mutual_count"
        ];
        for (NSString *key in mutualKeys) {
            if ([model respondsToSelector:NSSelectorFromString(key)]) {
                [model setValue:cachedMutualNumber forKey:key];
            }
        }
    }
}

%hook AWEUserModel
- (id)init {
    id instance = %orig;
    if (socialStatsEnabled && instance) {
        updateModelData(instance);
    }
    return instance;
}

- (NSNumber *)followerCount {
    return socialStatsEnabled && cachedFollowersNumber ? cachedFollowersNumber : %orig;
}

- (void)setFollowerCount:(NSNumber *)count {
    if (socialStatsEnabled && cachedFollowersNumber) {
        %orig(cachedFollowersNumber);
    } else {
        %orig;
    }
}

- (NSNumber *)followingCount {
    return socialStatsEnabled && cachedFollowingNumber ? cachedFollowingNumber : %orig;
}

- (void)setFollowingCount:(NSNumber *)count {
    if (socialStatsEnabled && cachedFollowingNumber) {
        %orig(cachedFollowingNumber);
    } else {
        %orig;
    }
}

- (NSNumber *)totalFavorited {
    return socialStatsEnabled && cachedLikesNumber ? cachedLikesNumber : %orig;
}

- (void)setTotalFavorited:(NSNumber *)count {
    if (socialStatsEnabled && cachedLikesNumber) {
        %orig(cachedLikesNumber);
    } else {
        %orig;
    }
}

- (NSNumber *)diggCount {
    return socialStatsEnabled && cachedLikesNumber ? cachedLikesNumber : %orig;
}

- (void)setDiggCount:(NSNumber *)count {
    if (socialStatsEnabled && cachedLikesNumber) {
        %orig(cachedLikesNumber);
    } else {
        %orig;
    }
}

- (NSNumber *)likeCount {
    return socialStatsEnabled && cachedLikesNumber ? cachedLikesNumber : %orig;
}

- (void)setLikeCount:(NSNumber *)count {
    if (socialStatsEnabled && cachedLikesNumber) {
        %orig(cachedLikesNumber);
    } else {
        %orig;
    }
}

- (NSNumber *)friendCount {
    return socialStatsEnabled && cachedMutualNumber ? cachedMutualNumber : %orig;
}

- (void)setFriendCount:(NSNumber *)count {
    if (socialStatsEnabled && cachedMutualNumber) {
        %orig(cachedMutualNumber);
    } else {
        %orig;
    }
}

- (NSNumber *)mutualFriendCount {
    return socialStatsEnabled && cachedMutualNumber ? cachedMutualNumber : %orig;
}

- (void)setMutualFriendCount:(NSNumber *)count {
    if (socialStatsEnabled && cachedMutualNumber) {
        %orig(cachedMutualNumber);
    } else {
        %orig;
    }
}

- (NSNumber *)followFriendCount {
    return socialStatsEnabled && cachedMutualNumber ? cachedMutualNumber : %orig;
}

- (void)setFollowFriendCount:(NSNumber *)count {
    if (socialStatsEnabled && cachedMutualNumber) {
        %orig(cachedMutualNumber);
    } else {
        %orig;
    }
}
%end


// 统计视图
%hook AWEProfileSocialStatisticView
- (void)setFansCount:(NSNumber *)count {
    if (socialStatsEnabled && cachedFollowersNumber) {
        %orig(cachedFollowersNumber);
    } else {
        %orig;
    }
}

- (void)setPraiseCount:(NSNumber *)count {
    if (socialStatsEnabled && cachedLikesNumber) {
        %orig(cachedLikesNumber);
    } else {
        %orig;
    }
}
- (void)setFollowingCount:(NSNumber *)count {
    if (socialStatsEnabled && cachedFollowingNumber) {
        %orig(cachedFollowingNumber);
    } else {
        %orig;
    }
}
- (void)setFriendCount:(NSNumber *)count {
    if (socialStatsEnabled && cachedMutualNumber) {
        %orig(cachedMutualNumber);
    } else {
        %orig;
    }
}
- (void)p_updateSocialStatisticContent:(BOOL)animated {
    %orig;
    if (socialStatsEnabled && !isUpdatingViews) {
        isUpdatingViews = YES;
        NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
        if (now - lastUpdateTimestamp < 0.5) {
            isUpdatingViews = NO;
            return;
        }
        lastUpdateTimestamp = now;
        
        __weak __typeof__(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            __strong __typeof__(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                isUpdatingViews = NO;
                return;
            }
            
            @try {
                if (cachedFollowersNumber) [strongSelf setFansCount:cachedFollowersNumber];
                if (cachedLikesNumber) [strongSelf setPraiseCount:cachedLikesNumber];
                if (cachedFollowingNumber) [strongSelf setFollowingCount:cachedFollowingNumber];
                if (cachedMutualNumber) [strongSelf setFriendCount:cachedMutualNumber];
            } @catch (NSException *e) {
                NSLog(@"[DYYY] Exception in updating stats: %@", e);
            } @finally {
                isUpdatingViews = NO;
            }
        });
    }
}
- (void)layoutSubviews {
    %orig;
    
    if (socialStatsEnabled && !isUpdatingViews) {
        NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
        if (now - lastUpdateTimestamp < 0.5) return;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self p_updateSocialStatisticContent:YES];
        });
    }
}
%end

%ctor {
    loadCustomSocialStats();
    
    // 对设置变更的监听
    [[NSNotificationCenter defaultCenter] addObserverForName:@"DYYYSettingChanged" 
                                                      object:nil 
                                                       queue:[NSOperationQueue mainQueue] 
                                                  usingBlock:^(NSNotification *note) {
        NSLog(@"[DYYY] 收到设置变更通知: %@", note.userInfo);
    
        NSString *key = note.userInfo[@"key"];
        
        // 重新加载所有数据
        loadCustomSocialStats();
        if ([key hasPrefix:@"DYYYCustom"] || [key isEqualToString:DYYY_SOCIAL_STATS_ENABLED_KEY]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
                findAndRefreshSocialStatsViews(keyWindow);
                UIViewController *topVC = [DYYYManager getActiveTopController];
                refreshProfileControllerIfNeeded(topVC);
            });
        }
        if ([key hasPrefix:@"DYYYVideo"] || [key isEqualToString:DYYY_VIDEO_STATS_ENABLED_KEY]) {
            if (videoStatsEnabled) {
                refreshAwemeStatisticsModels();
            }
        }
    }];
}
