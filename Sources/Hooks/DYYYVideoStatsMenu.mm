//
//  DYYYVideoStatsMenu.m
//  DYYY
//
//  视频数据修改的上下文菜单、已修改视频列表与编辑弹窗入口。
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "DYYYSocialStatsShared.h"

@implementation NSObject (DYYYBlockTableDelegate)
static char BlockDictionaryKey;

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    self = [self init];
    if (self && dictionary) {
        objc_setAssociatedObject(self, &BlockDictionaryKey, dictionary, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return self;
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

// 显示已修改视频列表的控制器
void showVideoStatsListController(UIViewController *parentVC) {
    ensureVideoSpecificStatsInitialized();
    
    NSUInteger statsCount;
    @synchronized(videoSpecificStats) {
        statsCount = [videoSpecificStats count];
    }
    
    if (statsCount == 0) {
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
    NSArray *videoIds;
    @synchronized(videoSpecificStats) {
        videoIds = [videoSpecificStats allKeys];
    }
    
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
            NSDictionary *stats;
            @synchronized(videoSpecificStats) {
                stats = videoSpecificStats[videoId];
            }
            
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
                    @synchronized(videoSpecificStats) {
                        [videoSpecificStats removeObjectForKey:videoId];
                    }
                    
                    // 保存更新后的数据
                    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                    @synchronized(videoSpecificStats) {
                        [defaults setObject:videoSpecificStats forKey:DYYY_VIDEO_SPECIFIC_STATS_KEY];
                    }
                    [defaults synchronize];
                    
                    // 刷新列表
                    [listVC dismissViewControllerAnimated:YES completion:^{
                        // 如果列表为空，直接返回
                        NSUInteger count;
                        @synchronized(videoSpecificStats) {
                            count = [videoSpecificStats count];
                        }
                        if (count == 0) {
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
