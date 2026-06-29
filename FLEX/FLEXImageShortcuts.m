//
//  FLEXImageShortcuts.m
//  FLEX
//
//  Created by Tanner Bennett on 8/29/19.
//  Copyright © 2020 FLEX Team. All rights reserved.
//

#import "FLEXImageShortcuts.h"
#import "FLEXImagePreviewViewController.h"
#import "FLEXShortcut.h"
#import "FLEXAlert.h"
#import "FLEXMacros.h"

@interface UIAlertController (FLEXImageShortcuts)
- (void)flex_image:(UIImage *)image disSaveWithError:(NSError *)error :(void *)context;
@end

@implementation FLEXImageShortcuts

#pragma mark - 重写

+ (instancetype)forObject:(UIImage *)image {
    // 这些附加行将出现在快捷方式部分的开头。
    // 下面的方法编写方式使它们不会干扰
    // 与这些一起注册的属性/等
    return [self forObject:image additionalRows:@[
        [FLEXActionShortcut title:@"查看图片" subtitle:nil
            viewer:^UIViewController *(id image) {
                return [FLEXImagePreviewViewController forImage:image];
            }
            accessoryType:^UITableViewCellAccessoryType(id image) {
                return UITableViewCellAccessoryDisclosureIndicator;
            }
        ],
        [FLEXActionShortcut title:@"保存图片" subtitle:nil
            selectionHandler:^(UIViewController *host, id image) {
                // 显示模态提醒用户关于保存的信息
                UIAlertController *alert = [FLEXAlert makeAlert:^(FLEXAlert *make) {
                    make.title(@"正在保存图片…");
                }];
                [host presentViewController:alert animated:YES completion:nil];
            
                // 保存图片
                UIImageWriteToSavedPhotosAlbum(
                    image, alert, @selector(flex_image:disSaveWithError::), nil
                );
            }
            accessoryType:^UITableViewCellAccessoryType(id image) {
                return UITableViewCellAccessoryDisclosureIndicator;
            }
        ]
    ]];
}

@end


@implementation UIAlertController (FLEXImageShortcuts)

- (void)flex_image:(UIImage *)image disSaveWithError:(NSError *)error :(void *)context {
    self.title = @"图片已保存";
    flex_dispatch_after(1, dispatch_get_main_queue(), ^{
        [self dismissViewControllerAnimated:YES completion:nil];
    });
}

@end
