#import "DYYYUtils.h"

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
        NSDictionary<NSFileAttributeKey, id> *attrs = [fileManager attributesOfItemAtPath:fullPath error:nil];
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