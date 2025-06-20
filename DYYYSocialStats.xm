/***
* 202505281200
* pxx917144686
**/

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "AwemeHeaders.h"
#import "DYYYManager.h"


#define DYYY_VIDEO_SPECIFIC_STATS_KEY @"DYYYVideoSpecificStats"
static NSMutableDictionary *videoSpecificStats = nil;

static void refreshAwemeStatisticsModels(void);
static void refreshVideoStatsForKeyPath(NSString *keyPath);
static void loadCustomSocialStats(void);
static void updateModelData(id model);
static void showVideoStatsListController(UIViewController *parentVC);
static id getCustomStatForVideo(NSString *videoId, NSString *statKey);
static void enumerateViewsRecursively(UIView *view, void(^block)(UIView *));

@interface NSObject (DYYYBlockTableDelegate)
- (instancetype)initWithDictionary:(NSDictionary *)dictionary;
@end

@implementation NSObject (DYYYBlockTableDelegate)
static char BlockDictionaryKey;

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    self = [self init];
    if (self && dictionary) {
        objc_setAssociatedObject(self, &BlockDictionaryKey, dictionary, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return self;
}

static id getCustomStatForVideo(NSString *videoId, NSString *statKey) {
    if (!videoId || !statKey || !videoSpecificStats) return nil;
    
    NSDictionary *videoStats = videoSpecificStats[videoId];
    if (!videoStats) return nil;
    
    return videoStats[statKey];
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    NSDictionary *dict = objc_getAssociatedObject(self, &BlockDictionaryKey);
    if (!dict) return;
    
    NSString *selectorName = NSStringFromSelector(invocation.selector);
    id block = dict[selectorName];
    if (!block) return;
    
    @try {
        if ([selectorName isEqualToString:@"tableView:numberOfRowsInSection:"]) {
            __unsafe_unretained id tableView;
            NSInteger section;
            [invocation getArgument:&tableView atIndex:2];
            [invocation getArgument:&section atIndex:3];
            
            NSInteger result = ((NSInteger (^)(id, NSInteger))block)(tableView, section);
            [invocation setReturnValue:&result];
        } 
        else if ([selectorName isEqualToString:@"tableView:cellForRowAtIndexPath:"]) {
            __unsafe_unretained id tableView;
            __unsafe_unretained id indexPath;
            [invocation getArgument:&tableView atIndex:2];
            [invocation getArgument:&indexPath atIndex:3];
            
            id result = ((id (^)(id, id))block)(tableView, indexPath);
            [invocation setReturnValue:&result];
        }
        else if ([selectorName isEqualToString:@"tableView:didSelectRowAtIndexPath:"]) {
            __unsafe_unretained id tableView;
            __unsafe_unretained id indexPath;
            [invocation getArgument:&tableView atIndex:2];
            [invocation getArgument:&indexPath atIndex:3];
            
            ((void (^)(id, id))block)(tableView, indexPath);
        }
    } @catch (NSException *e) {
        NSLog(@"[DYYY] 消息转发异常: %@", e);
    }
}
@end

@interface AWEProfileSocialStatisticView : UIView
- (void)setFansCount:(NSNumber *)count;
- (void)setPraiseCount:(NSNumber *)count;
- (void)setFollowingCount:(NSNumber *)count;
- (void)setFriendCount:(NSNumber *)count;
- (void)p_updateSocialStatisticContent:(BOOL)animated;
@end

@interface AWEProfileHeaderMyProfileViewController : UIViewController
- (void)reloadSettings;
@end

// 控制开关 & 自定义数据持久化
#define DYYY_SOCIAL_STATS_ENABLED_KEY @"DYYYEnableSocialStatsCustom"
#define DYYY_SOCIAL_FOLLOWERS_KEY @"DYYYCustomFollowers"
#define DYYY_SOCIAL_LIKES_KEY @"DYYYCustomLikes"
#define DYYY_SOCIAL_FOLLOWING_KEY @"DYYYCustomFollowing"
#define DYYY_SOCIAL_MUTUAL_KEY @"DYYYCustomMutual"

// 视频统计数据修改开关和自定义数据持久化键
#define DYYY_VIDEO_STATS_ENABLED_KEY @"DYYYEnableVideoStatsCustom"
#define DYYY_VIDEO_LIKES_KEY @"DYYYVideoCustomLikes" 
#define DYYY_VIDEO_COMMENTS_KEY @"DYYYVideoCustomComments"
#define DYYY_VIDEO_COLLECTS_KEY @"DYYYVideoCustomCollects"
#define DYYY_VIDEO_SHARES_KEY @"DYYYVideoCustomShares"
#define DYYY_VIDEO_RECOMMENDS_KEY @"DYYYVideoCustomRecommends"

// 在静态缓存区域添加
static NSString *customVideoRecommends = nil;
static NSNumber *cachedVideoRecommendsNumber = nil;

// 静态缓存
static NSString *customFollowersCount = nil;
static NSString *customLikesCount = nil;
static NSString *customFollowingCount = nil;
static NSString *customMutualCount = nil;
static BOOL socialStatsEnabled = NO;

static BOOL videoStatsEnabled = NO;
static NSString *customVideoLikes = nil;
static NSString *customVideoComments = nil;
static NSString *customVideoCollects = nil;
static NSString *customVideoShares = nil;

// 静态缓存的NSNumber值
static NSNumber *cachedFollowersNumber = nil;
static NSNumber *cachedLikesNumber = nil;
static NSNumber *cachedFollowingNumber = nil;
static NSNumber *cachedMutualNumber = nil;

static NSNumber *cachedVideoLikesNumber = nil;
static NSNumber *cachedVideoCommentsNumber = nil;
static NSNumber *cachedVideoCollectsNumber = nil;
static NSNumber *cachedVideoSharesNumber = nil;

// 防止重复更新
static BOOL isUpdatingViews = NO;
static NSTimeInterval lastUpdateTimestamp = 0;

// 函数声明
static void loadCustomSocialStats(void);
static void updateModelData(id model);

// 加载设置数据
static void loadCustomSocialStats() {
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
    videoSpecificStats = nil;
}

static void findAndRefreshSocialStatsViews(UIView *rootView) {
    if (!rootView) return;
    
    // 使用非递归方式遍历视图
    enumerateViewsRecursively(rootView, ^(UIView *view) {
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

// 视图遍历函数 - 使用非递归方式
static void enumerateViewsRecursively(UIView *view, void(^block)(UIView *)) {
    if (!view || !block) return;
    
    NSMutableArray *viewsToProcess = [NSMutableArray arrayWithObject:view];
    NSInteger processedCount = 0;
    const NSInteger MAX_VIEWS = 500; // 限制最大处理数量，防止死循环
    
    while (viewsToProcess.count > 0 && processedCount < MAX_VIEWS) {
        @autoreleasepool {
            UIView *currentView = viewsToProcess.firstObject;
            [viewsToProcess removeObjectAtIndex:0];
            
            block(currentView);
            
            for (UIView *subview in currentView.subviews) {
                if (subview) {
                    [viewsToProcess addObject:subview];
                }
            }
            
            processedCount++;
        }
    }
}

// 通知处理方法，确保统计模型实例被刷新
static void refreshAwemeStatisticsModels() {
    if (!videoStatsEnabled) return;
    
    // 延迟执行以确保UI已经完全加载
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        @try {
            UIViewController *topVC = [DYYYManager getActiveTopController];
            if (!topVC) return;
            
            // 查找视频单元格并刷新
            enumerateViewsRecursively(topVC.view, ^(UIView *view) {
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
            enumerateViewsRecursively(topVC.view, ^(UIView *view) {
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


// 创建"编辑当前视频"的上下文菜单
void showVideoStatsContextMenu(UIViewController *viewController) {
    UIAlertController *menu = [UIAlertController alertControllerWithTitle:@"视频数据修改"
                                                                 message:nil
                                                          preferredStyle:UIAlertControllerStyleActionSheet];
    
    [menu addAction:[UIAlertAction actionWithTitle:@"修改全局视频数据" 
                                          style:UIAlertActionStyleDefault 
                                        handler:^(UIAlertAction *action) {
        showVideoStatsEditAlert(viewController);
    }]];
    
    [menu addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    
    // 在iPad上需要设置弹出位置
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        menu.popoverPresentationController.sourceView = viewController.view;
        menu.popoverPresentationController.sourceRect = CGRectMake(viewController.view.bounds.size.width / 2, 
                                                                  viewController.view.bounds.size.height / 2, 
                                                                  0, 0);
        menu.popoverPresentationController.permittedArrowDirections = 0;
    }
    
    [viewController presentViewController:menu animated:YES completion:nil];
}

// 显示已修改视频列表的控制器
void showVideoStatsListController(UIViewController *parentVC) {
    if (!videoSpecificStats || [videoSpecificStats count] == 0) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"没有数据" 
                                                                      message:@"尚未对任何特定视频进行数据修改" 
                                                               preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        [parentVC presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    UITableViewController *listVC = [[UITableViewController alloc] initWithStyle:UITableViewStylePlain];
    listVC.title = @"已修改视频列表";
    
    // 获取所有已修改视频的ID
    NSArray *videoIds = [videoSpecificStats allKeys];
    
    // 自定义显示数据
    listVC.tableView.dataSource = [[NSObject alloc] initWithDictionary:@{
        @"tableView:numberOfRowsInSection:": ^NSInteger(UITableView *tableView, NSInteger section) {
            return [videoIds count];
        },
        @"tableView:cellForRowAtIndexPath:": ^UITableViewCell *(UITableView *tableView, NSIndexPath *indexPath) {
            static NSString *cellId = @"VideoStatsCellId";
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
            if (!cell) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellId];
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            }
            
            NSString *videoId = videoIds[indexPath.row];
            NSDictionary *stats = videoSpecificStats[videoId];
            
            cell.textLabel.text = [NSString stringWithFormat:@"视频ID: %@", videoId];
            
            NSMutableArray *statsStrings = [NSMutableArray array];
            if (stats[@"diggCount"]) [statsStrings addObject:[NSString stringWithFormat:@"点赞: %@", stats[@"diggCount"]]];
            if (stats[@"commentCount"]) [statsStrings addObject:[NSString stringWithFormat:@"评论: %@", stats[@"commentCount"]]];
            if (stats[@"collectCount"]) [statsStrings addObject:[NSString stringWithFormat:@"收藏: %@", stats[@"collectCount"]]];
            if (stats[@"shareCount"]) [statsStrings addObject:[NSString stringWithFormat:@"分享: %@", stats[@"shareCount"]]];
            if (stats[@"forwardCount"]) [statsStrings addObject:[NSString stringWithFormat:@"推荐: %@", stats[@"forwardCount"]]];
            if (stats[@"playCount"]) [statsStrings addObject:[NSString stringWithFormat:@"播放: %@", stats[@"playCount"]]];
            
            cell.detailTextLabel.text = [statsStrings componentsJoinedByString:@"  "];
            
            return cell;
        }
    }];
    
    // 添加删除功能
    listVC.tableView.delegate = [[NSObject alloc] initWithDictionary:@{
        @"tableView:didSelectRowAtIndexPath:": ^(UITableView *tableView, NSIndexPath *indexPath) {
            [tableView deselectRowAtIndexPath:indexPath animated:YES];
            
            NSString *videoId = videoIds[indexPath.row];
            
            UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"视频: %@", videoId]
                                                                                message:@"请选择操作"
                                                                         preferredStyle:UIAlertControllerStyleActionSheet];
            
            [actionSheet addAction:[UIAlertAction actionWithTitle:@"编辑数据" 
                                                          style:UIAlertActionStyleDefault 
                                                        handler:^(UIAlertAction *action) {
                NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                [defaults setObject:videoId forKey:@"DYYYTempEditingVideoId"];
                [defaults synchronize];
                
                [listVC dismissViewControllerAnimated:YES completion:^{
                    showVideoStatsEditAlert(parentVC);
                }];
            }]];
            
            [actionSheet addAction:[UIAlertAction actionWithTitle:@"删除数据" 
                                                          style:UIAlertActionStyleDestructive 
                                                        handler:^(UIAlertAction *action) {
                UIAlertController *confirmAlert = [UIAlertController alertControllerWithTitle:@"确认删除"
                                                                                     message:[NSString stringWithFormat:@"确定要删除视频 %@ 的自定义数据吗？", videoId]
                                                                              preferredStyle:UIAlertControllerStyleAlert];
                
                [confirmAlert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
                [confirmAlert addAction:[UIAlertAction actionWithTitle:@"确定删除" 
                                                                style:UIAlertActionStyleDestructive 
                                                              handler:^(UIAlertAction *action) {
                    // 删除该视频的自定义数据
                    [videoSpecificStats removeObjectForKey:videoId];
                    
                    // 保存更新后的数据
                    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                    [defaults setObject:videoSpecificStats forKey:DYYY_VIDEO_SPECIFIC_STATS_KEY];
                    [defaults synchronize];
                    
                    // 刷新列表
                    [listVC dismissViewControllerAnimated:YES completion:^{
                        // 如果列表为空，直接返回
                        if ([videoSpecificStats count] == 0) {
                            return;
                        }
                        // 否则重新显示列表
                        showVideoStatsListController(parentVC);
                    }];
                    
                    // 发送通知更新UI
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"DYYYVideoStatsChanged" 
                                                                      object:nil 
                                                                    userInfo:@{
                        @"videoId": videoId,
                        @"action": @"delete",
                        @"timestamp": @([[NSDate date] timeIntervalSince1970])
                    }];
                }]];
                
                [listVC presentViewController:confirmAlert animated:YES completion:nil];
            }]];
            
            [actionSheet addAction:[UIAlertAction actionWithTitle:@"复制视频ID" 
                                                          style:UIAlertActionStyleDefault 
                                                        handler:^(UIAlertAction *action) {
                // 复制视频ID到剪贴板
                UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
                pasteboard.string = videoId;
                
                // 显示复制成功提示
                UIAlertController *successAlert = [UIAlertController alertControllerWithTitle:@"复制成功"
                                                                                     message:[NSString stringWithFormat:@"视频ID: %@ 已复制到剪贴板", videoId]
                                                                              preferredStyle:UIAlertControllerStyleAlert];
                [successAlert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
                [listVC presentViewController:successAlert animated:YES completion:nil];
            }]];
            
            [actionSheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
            
            // 在iPad上需要设置弹出位置
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
                actionSheet.popoverPresentationController.sourceView = tableView;
                actionSheet.popoverPresentationController.sourceRect = [tableView rectForRowAtIndexPath:indexPath];
            }
            
            [listVC presentViewController:actionSheet animated:YES completion:nil];
        }
    }];
    
    // 添加导航栏按钮
    UIBarButtonItem *closeButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone 
                                                                                target:listVC 
                                                                                action:@selector(dismissViewControllerAnimated:completion:)];
    listVC.navigationItem.leftBarButtonItem = closeButton;
    
    UINavigationController *navVC = [[UINavigationController alloc] initWithRootViewController:listVC];
    [parentVC presentViewController:navVC animated:YES completion:nil];
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


// 字典数据源
%hook NSDictionary
- (id)objectForKey:(id)aKey {
    id originalValue = %orig;
    if (!socialStatsEnabled || !aKey || !originalValue || ![aKey isKindOfClass:[NSString class]]) {
        return originalValue;
    }
    
    NSString *keyString = (NSString *)aKey;
    
    // 粉丝
    if (cachedFollowersNumber && 
        ([keyString isEqualToString:@"follower_count"] ||
         [keyString isEqualToString:@"fans_count"] ||
         [keyString isEqualToString:@"follower"] ||
         [keyString isEqualToString:@"fans"])) {
        if ([originalValue isKindOfClass:[NSNumber class]]) {
            return cachedFollowersNumber;
        }
    }
    
    // 获赞
    if (cachedLikesNumber && 
        ([keyString isEqualToString:@"total_favorited"] ||
         [keyString isEqualToString:@"favorite_count"] ||
         [keyString isEqualToString:@"digg_count"] ||
         [keyString isEqualToString:@"like_count"] ||
         [keyString isEqualToString:@"praise_count"])) {
        if ([originalValue isKindOfClass:[NSNumber class]]) {
            return cachedLikesNumber;
        }
    }
    
    // 关注
    if (cachedFollowingNumber && 
        ([keyString isEqualToString:@"following_count"] ||
         [keyString isEqualToString:@"follow_count"] ||
         [keyString isEqualToString:@"following"] ||
         [keyString isEqualToString:@"follow"])) {
        if ([originalValue isKindOfClass:[NSNumber class]]) {
            return cachedFollowingNumber;
        }
    }
    
    // 互关
    if (cachedMutualNumber && 
        ([keyString isEqualToString:@"friend_count"] ||
         [keyString isEqualToString:@"mutual_friend_count"] ||
         [keyString isEqualToString:@"mutual_count"] ||
         [keyString isEqualToString:@"friendship_count"])) {
        if ([originalValue isKindOfClass:[NSNumber class]]) {
            return cachedMutualNumber;
        }
    }
    
    return originalValue;
}
%end

@interface AWEFeedTableCell : UIView
- (void)setNeedsLayout;
- (void)layoutIfNeeded;
@end

@interface AWEAwemeDetailController : UIViewController
@end

@interface DYYYVideoEditViewController : UIViewController <UITextFieldDelegate, UIGestureRecognizerDelegate>
@property (nonatomic, strong) NSString *videoId;
@property (nonatomic, strong) NSDictionary *existingStats;
@property (nonatomic, strong) NSMutableDictionary *currentValues;
@end

@implementation DYYYVideoEditViewController

- (instancetype)init {
    self = [super init];
    if (self) {
        _currentValues = [NSMutableDictionary dictionary];
        self.modalPresentationStyle = UIModalPresentationOverFullScreen;
        self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 设置半透明背景
    self.view.backgroundColor = [UIColor colorWithWhite:0 alpha:0.6];
    
    // 创建卡片容器
    UIView *cardView = [[UIView alloc] init];
    cardView.backgroundColor = [UIColor systemBackgroundColor];
    cardView.layer.cornerRadius = 20;
    cardView.clipsToBounds = YES;
    cardView.translatesAutoresizingMaskIntoConstraints = NO;
    cardView.alpha = 0; // 初始透明，用于动画
    cardView.transform = CGAffineTransformScale(CGAffineTransformIdentity, 0.8, 0.8); // 初始缩小，用于动画
    cardView.tag = 100;
    [self.view addSubview:cardView];
    
    // 卡片尺寸和位置约束
    [NSLayoutConstraint activateConstraints:@[
        [cardView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [cardView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [cardView.widthAnchor constraintEqualToAnchor:self.view.widthAnchor multiplier:0.85],
        [cardView.heightAnchor constraintEqualToConstant:500]
    ]];
    
    // 添加标题
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = @"自定义视频数据";
    titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [cardView addSubview:titleLabel];
    
    // 添加分割线
    UIView *divider = [[UIView alloc] init];
    divider.backgroundColor = [UIColor systemGray3Color];
    divider.translatesAutoresizingMaskIntoConstraints = NO;
    [cardView addSubview:divider];
    
    // 创建表单容器
    UIStackView *formContainer = [[UIStackView alloc] init];
    formContainer.axis = UILayoutConstraintAxisVertical;
    formContainer.spacing = 18;
    formContainer.distribution = UIStackViewDistributionFill;
    formContainer.alignment = UIStackViewAlignmentFill;
    formContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [cardView addSubview:formContainer];
    
    // 添加各项输入控件
    NSArray *itemTitles = @[@"点赞数", @"评论数", @"收藏数", @"分享数"];
    NSArray *itemIcons = @[@"heart.fill", @"bubble.left.fill", @"bookmark.fill", @"arrowshape.turn.up.right.fill"];
    NSArray *itemColors = @[
        [UIColor systemRedColor],
        [UIColor systemBlueColor], 
        [UIColor systemGreenColor], 
        [UIColor systemOrangeColor]
    ];
    NSArray *itemKeys = @[
        DYYY_VIDEO_LIKES_KEY,
        DYYY_VIDEO_COMMENTS_KEY,
        DYYY_VIDEO_COLLECTS_KEY,
        DYYY_VIDEO_SHARES_KEY
    ];
    
    for (int i = 0; i < itemTitles.count; i++) {
        [self addInputRow:formContainer 
                    title:itemTitles[i] 
                     icon:itemIcons[i] 
                    color:itemColors[i] 
                      tag:200 + i 
                      key:itemKeys[i]];
    }
    
    // 添加按钮容器
    UIStackView *buttonContainer = [[UIStackView alloc] init];
    buttonContainer.axis = UILayoutConstraintAxisHorizontal;
    buttonContainer.spacing = 12;
    buttonContainer.distribution = UIStackViewDistributionFillEqually;
    buttonContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [cardView addSubview:buttonContainer];
    
    // 创建取消按钮
    UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [cancelButton setTitle:@"取消" forState:UIControlStateNormal];
    cancelButton.backgroundColor = [UIColor systemGray5Color];
    cancelButton.layer.cornerRadius = 12;
    [cancelButton setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
    [cancelButton addTarget:self action:@selector(cancelAction) forControlEvents:UIControlEventTouchUpInside];
    [buttonContainer addArrangedSubview:cancelButton];
    
    // 创建确认按钮
    UIButton *saveButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [saveButton setTitle:@"确定" forState:UIControlStateNormal];
    saveButton.backgroundColor = [UIColor systemBlueColor];
    saveButton.layer.cornerRadius = 12;
    [saveButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [saveButton addTarget:self action:@selector(saveAction) forControlEvents:UIControlEventTouchUpInside];
    [buttonContainer addArrangedSubview:saveButton];
    
    // 为所有按钮设置高度
    for (UIButton *button in buttonContainer.arrangedSubviews) {
        button.translatesAutoresizingMaskIntoConstraints = NO;
        [button.heightAnchor constraintEqualToConstant:50].active = YES;
    }
    
    // 布局约束
    [NSLayoutConstraint activateConstraints:@[
        // 标题约束
        [titleLabel.topAnchor constraintEqualToAnchor:cardView.topAnchor constant:20],
        [titleLabel.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:20],
        [titleLabel.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-20],
        
        // 分割线约束
        [divider.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:15],
        [divider.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:0],
        [divider.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:0],
        [divider.heightAnchor constraintEqualToConstant:0.5],
        
        // 表单约束
        [formContainer.topAnchor constraintEqualToAnchor:divider.bottomAnchor constant:20],
        [formContainer.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:20],
        [formContainer.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-20],
        
        // 按钮容器约束
        [buttonContainer.topAnchor constraintEqualToAnchor:formContainer.bottomAnchor constant:25],
        [buttonContainer.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:20],
        [buttonContainer.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-20],
        [buttonContainer.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor constant:-25],
    ]];
    
    // 加载现有数据
    [self loadExistingData];
    
    // 添加轻点背景关闭弹窗的手势
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] 
                                          initWithTarget:self 
                                          action:@selector(handleBackgroundTap:)];
    tapGesture.delegate = self;
    [self.view addGestureRecognizer:tapGesture];
    
    // 注册键盘通知
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
}

- (void)addInputRow:(UIStackView *)container title:(NSString *)title icon:(NSString *)iconName color:(UIColor *)color tag:(NSInteger)tag key:(NSString *)key {
    // 创建容器
    UIView *rowView = [[UIView alloc] init];
    rowView.translatesAutoresizingMaskIntoConstraints = NO;
    [rowView.heightAnchor constraintEqualToConstant:65].active = YES;
    [container addArrangedSubview:rowView];
    
    // 创建图标 (在左侧)
    UIImageView *iconView = [[UIImageView alloc] init];
    if (@available(iOS 13.0, *)) {
        iconView.image = [UIImage systemImageNamed:iconName];
    } else {
        // 兼容iOS 13以下版本的替代图标
        iconView.image = [UIImage imageNamed:iconName];
    }
    iconView.tintColor = color;
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    [rowView addSubview:iconView];
    
    // 创建标题标签
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = title;
    titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [rowView addSubview:titleLabel];
    
    // 创建数值预览标签
    UILabel *valueLabel = [[UILabel alloc] init];
    valueLabel.font = [UIFont monospacedDigitSystemFontOfSize:16 weight:UIFontWeightMedium];
    valueLabel.textAlignment = NSTextAlignmentRight;
    valueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    valueLabel.tag = tag + 100; // 预览标签tag = 输入框tag + 100
    valueLabel.textColor = color;
    [rowView addSubview:valueLabel];
    
    // 创建输入框
    UITextField *textField = [[UITextField alloc] init];
    textField.placeholder = @"输入数值";
    textField.keyboardType = UIKeyboardTypeNumberPad;
    textField.textAlignment = NSTextAlignmentCenter;
    textField.borderStyle = UITextBorderStyleRoundedRect;
    textField.tag = tag;
    textField.delegate = self;
    textField.translatesAutoresizingMaskIntoConstraints = NO;
    [textField addTarget:self action:@selector(textFieldValueChanged:) forControlEvents:UIControlEventEditingChanged];
    [rowView addSubview:textField];
    
    // 创建滑块
    UISlider *slider = [[UISlider alloc] init];
    slider.minimumValue = 0;
    slider.maximumValue = 10000000; // 千万级上限
    slider.minimumTrackTintColor = color;
    slider.tag = tag + 200; // 滑块tag = 输入框tag + 200
    slider.translatesAutoresizingMaskIntoConstraints = NO;
    [slider addTarget:self action:@selector(sliderValueChanged:) forControlEvents:UIControlEventValueChanged];
    [rowView addSubview:slider];
    
    // 保存关联的键
    objc_setAssociatedObject(textField, "keyName", key, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(slider, "keyName", key, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // 布局约束
    [NSLayoutConstraint activateConstraints:@[
        // 图标约束
        [iconView.leadingAnchor constraintEqualToAnchor:rowView.leadingAnchor constant:2],
        [iconView.topAnchor constraintEqualToAnchor:rowView.topAnchor constant:8],
        [iconView.widthAnchor constraintEqualToConstant:22],
        [iconView.heightAnchor constraintEqualToConstant:22],
        
        // 标题约束
        [titleLabel.leadingAnchor constraintEqualToAnchor:iconView.trailingAnchor constant:8],
        [titleLabel.centerYAnchor constraintEqualToAnchor:iconView.centerYAnchor],
        
        // 数值预览标签约束
        [valueLabel.trailingAnchor constraintEqualToAnchor:rowView.trailingAnchor],
        [valueLabel.centerYAnchor constraintEqualToAnchor:iconView.centerYAnchor],
        [valueLabel.leadingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor constant:10],
        
        // 输入框约束
        [textField.topAnchor constraintEqualToAnchor:iconView.bottomAnchor constant:8],
        [textField.leadingAnchor constraintEqualToAnchor:rowView.leadingAnchor],
        [textField.widthAnchor constraintEqualToConstant:100],
        [textField.heightAnchor constraintEqualToConstant:35],
        
        // 滑块约束
        [slider.leadingAnchor constraintEqualToAnchor:textField.trailingAnchor constant:10],
        [slider.trailingAnchor constraintEqualToAnchor:rowView.trailingAnchor],
        [slider.centerYAnchor constraintEqualToAnchor:textField.centerYAnchor],
    ]];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    UIView *cardView = [self.view viewWithTag:100];
    
    // 设置卡片的初始状态为缩小并透明
    cardView.transform = CGAffineTransformScale(CGAffineTransformIdentity, 0.8, 0.8);
    cardView.alpha = 0;
    self.view.backgroundColor = [UIColor colorWithWhite:0 alpha:0];
    
    // 执行弹出动画
    [UIView animateWithDuration:0.3 
                          delay:0 
                        options:UIViewAnimationOptionCurveEaseOut 
                     animations:^{
        cardView.transform = CGAffineTransformIdentity;
        cardView.alpha = 1;
        self.view.backgroundColor = [UIColor colorWithWhite:0 alpha:0.6];
    } completion:nil];
}

// 加载现有数据
- (void)loadExistingData {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSArray *keys = @[
        DYYY_VIDEO_LIKES_KEY,
        DYYY_VIDEO_COMMENTS_KEY,
        DYYY_VIDEO_COLLECTS_KEY,
        DYYY_VIDEO_SHARES_KEY
    ];
    
    for (int i = 0; i < keys.count; i++) {
        NSString *key = keys[i];
        NSString *value = [defaults objectForKey:key];
        
        if (value) {
            [_currentValues setObject:value forKey:key];
            
            // 更新UI
            UITextField *textField = [self.view viewWithTag:200 + i];
            UILabel *valueLabel = [self.view viewWithTag:300 + i];
            UISlider *slider = [self.view viewWithTag:400 + i];
            
            textField.text = value;
            valueLabel.text = [self formatNumberString:value];
            
            // 设置滑块值，但不超过滑块最大值
            float sliderValue = [value floatValue];
            if (sliderValue > slider.maximumValue) {
                sliderValue = slider.maximumValue;
            }
            slider.value = sliderValue;
        }
    }
}

// 处理滑块值变化
- (void)sliderValueChanged:(UISlider *)slider {
    NSInteger correspondingTextFieldTag = slider.tag - 200;
    NSInteger correspondingValueLabelTag = slider.tag - 100;
    
    UITextField *textField = [self.view viewWithTag:correspondingTextFieldTag];
    UILabel *valueLabel = [self.view viewWithTag:correspondingValueLabelTag];
    
    // 四舍五入滑块值
    NSInteger intValue = roundf(slider.value);
    NSString *stringValue = [NSString stringWithFormat:@"%ld", (long)intValue];
    
    // 更新输入框和预览标签
    textField.text = stringValue;
    valueLabel.text = [self formatNumberString:stringValue];
    
    // 保存当前值到临时字典
    NSString *key = objc_getAssociatedObject(slider, "keyName");
    if (key) {
        [_currentValues setObject:stringValue forKey:key];
    }
    
    // 添加轻微振动反馈
    if (@available(iOS 10.0, *)) {
        UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [generator prepare];
        [generator impactOccurred];
    }
}

// 处理输入框值变化
- (void)textFieldValueChanged:(UITextField *)textField {
    NSInteger correspondingSliderTag = textField.tag + 200;
    NSInteger correspondingValueLabelTag = textField.tag + 100;
    
    UISlider *slider = [self.view viewWithTag:correspondingSliderTag];
    UILabel *valueLabel = [self.view viewWithTag:correspondingValueLabelTag];
    
    // 获取输入文本并转换为数字
    NSString *text = textField.text;
    float floatValue = [text floatValue];
    
    // 限制在滑块范围内
    if (floatValue > slider.maximumValue) {
        floatValue = slider.maximumValue;
    }
    
    // 更新滑块和预览标签
    slider.value = floatValue;
    valueLabel.text = [self formatNumberString:text];
    
    // 保存当前值到临时字典
    NSString *key = objc_getAssociatedObject(textField, "keyName");
    if (key) {
        [_currentValues setObject:text forKey:key];
    }
}

// 格式化数字字符串（添加千位分隔符）
- (NSString *)formatNumberString:(NSString *)numberString {
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterDecimalStyle;
    formatter.groupingSeparator = @",";
    formatter.groupingSize = 3;
    
    NSNumber *number = @([numberString longLongValue]);
    return [formatter stringFromNumber:number];
}

// 取消按钮动作
- (void)cancelAction {
    [self dismissWithAnimation:YES completion:nil];
}

// 保存按钮动作
- (void)saveAction {
    // 保存数据到UserDefaults
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    for (NSString *key in _currentValues) {
        NSString *value = _currentValues[key];
        if (value.length > 0) {
            [defaults setObject:value forKey:key];
        } else {
            [defaults removeObjectForKey:key];
        }
    }
    
    // 启用视频数据自定义
    [defaults setBool:YES forKey:DYYY_VIDEO_STATS_ENABLED_KEY];
    [defaults synchronize];
    
    // 重新加载数据并更新界面
    loadCustomSocialStats();
    syncVideoStatsFromSettings();
    
    // 发送通知
    [[NSNotificationCenter defaultCenter] postNotificationName:@"DYYYVideoStatsChanged" 
                                                      object:nil 
                                                    userInfo:@{
        @"action": @"update",
        @"timestamp": @([[NSDate date] timeIntervalSince1970])
    }];
    
    // 添加成功振动反馈
    if (@available(iOS 10.0, *)) {
        UINotificationFeedbackGenerator *generator = [[UINotificationFeedbackGenerator alloc] init];
        [generator prepare];
        [generator notificationOccurred:UINotificationFeedbackTypeSuccess];
    }
    
    // 关闭弹窗
    [self dismissWithAnimation:YES completion:^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIViewController *topVC = [DYYYManager getActiveTopController];
            if (topVC) {
                // 强制刷新当前视图
                enumerateViewsRecursively(topVC.view, ^(UIView *view) {
                    if ([view isKindOfClass:%c(AWEFeedVideoButton)] ||
                        [view isKindOfClass:%c(AWEFeedTableCell)] || 
                        [view isKindOfClass:%c(AWEFeedViewCell)]) {
                        [view setNeedsLayout];
                        [view layoutIfNeeded];
                        
                        // 用动画强制刷新
                        [UIView animateWithDuration:0.1 animations:^{
                            [view setNeedsDisplay];
                        }];
                    }
                });
                
                // 尝试调用刷新方法
                if ([topVC respondsToSelector:@selector(reloadData)]) {
                    [topVC performSelector:@selector(reloadData)];
                }
            }
        });
    }];
}

// 带动画消失
- (void)dismissWithAnimation:(BOOL)animated completion:(void(^)(void))completion {
    if (animated) {
        UIView *cardView = [self.view viewWithTag:100];
        
        [UIView animateWithDuration:0.2 animations:^{
            cardView.transform = CGAffineTransformScale(CGAffineTransformIdentity, 0.8, 0.8);
            cardView.alpha = 0;
            self.view.backgroundColor = [UIColor colorWithWhite:0 alpha:0];
        } completion:^(BOOL finished) {
            [self dismissViewControllerAnimated:NO completion:^{
                if (completion) completion();
            }];
        }];
    } else {
        [self dismissViewControllerAnimated:NO completion:completion];
    }
}

#pragma mark - UITextFieldDelegate

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    // 只允许输入数字
    NSCharacterSet *nonDigitSet = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    if ([string rangeOfCharacterFromSet:nonDigitSet].location != NSNotFound) {
        return NO;
    }
    
    // 限制最大长度为10位数
    NSString *newText = [textField.text stringByReplacingCharactersInRange:range withString:string];
    if (newText.length > 10) {
        return NO;
    }
    
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

#pragma mark - 键盘处理

- (void)keyboardWillShow:(NSNotification *)notification {
    NSDictionary *info = [notification userInfo];
    CGSize keyboardSize = [[info objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue].size;
    
    UIView *cardView = [self.view viewWithTag:100];
    CGRect cardFrame = [cardView convertRect:cardView.bounds toView:self.view];
    
    CGFloat bottomOfCard = cardFrame.origin.y + cardFrame.size.height;
    CGFloat topOfKeyboard = self.view.frame.size.height - keyboardSize.height;
    
    // 如果卡片底部被键盘遮挡
    if (bottomOfCard > topOfKeyboard) {
        CGFloat offsetY = bottomOfCard - topOfKeyboard + 20; // 额外20pt的空间
        
        [UIView animateWithDuration:0.3 animations:^{
            cardView.transform = CGAffineTransformMakeTranslation(0, -offsetY);
        }];
    }
}

- (void)keyboardWillHide:(NSNotification *)notification {
    UIView *cardView = [self.view viewWithTag:100];
    
    [UIView animateWithDuration:0.3 animations:^{
        cardView.transform = CGAffineTransformIdentity;
    }];
}

#pragma mark - 背景点击处理

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    UIView *cardView = [self.view viewWithTag:100];
    CGPoint touchPoint = [touch locationInView:self.view];
    return ![cardView pointInside:[self.view convertPoint:touchPoint toView:cardView] withEvent:nil];
}

- (void)handleBackgroundTap:(UITapGestureRecognizer *)gesture {
    [self.view endEditing:YES];
    [self cancelAction];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end

void showVideoStatsEditAlert(UIViewController *viewController) {    
    // 创建并显示编辑视图控制器
    DYYYVideoEditViewController *editVC = [[DYYYVideoEditViewController alloc] init];
    // 不再设置videoId属性
    editVC.videoId = nil;
    editVC.existingStats = nil;
    editVC.modalPresentationStyle = UIModalPresentationOverFullScreen;
    editVC.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    
    [viewController presentViewController:editVC animated:YES completion:nil];
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

%ctor {
    loadCustomSocialStats();
    
    // 对设置变更的监听
    [[NSNotificationCenter defaultCenter] addObserverForName:@"DYYYSettingChanged" 
                                                      object:nil 
                                                       queue:[NSOperationQueue mainQueue] 
                                                  usingBlock:^(NSNotification *note) {
        NSLog(@"[DYYY] 收到设置变更通知: %@", note.userInfo);
    
        NSString *key = note.userInfo[@"key"];
        id value = note.userInfo[@"value"];
        
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