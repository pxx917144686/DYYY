#import "DYYYUtils.h"
#import "DYYYConstants.h"
#import "CityManager.h"
#import <stdatomic.h>
#import <os/lock.h>
#import <objc/runtime.h>

@implementation DYYYUtils

static const void *kCurrentIPRequestCityCodeKey = &kCurrentIPRequestCityCodeKey;

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
    if (@available(iOS 13.0, *)) {
        UITraitCollection *traitCollection = [UIScreen mainScreen].traitCollection;
        return traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }
    return NO;
}

+ (NSArray<UIView *> *)findAllSubviewsOfClass:(Class)targetClass inContainer:(UIView *)container {
    NSMutableArray<UIView *> *foundViews = [NSMutableArray array];
    [self findSubviewsOfClass:targetClass inView:container result:foundViews];
    return [foundViews copy];
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

+ (void)findSubviewsOfClass:(Class)targetClass inView:(UIView *)view result:(NSMutableArray<UIView *> *)result {
    if ([view isKindOfClass:targetClass]) {
        [result addObject:view];
    }
    
    for (UIView *subview in view.subviews) {
        [self findSubviewsOfClass:targetClass inView:subview result:result];
    }
}

+ (UIWindow *)getActiveWindow {
    if (@available(iOS 15.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]] &&
                scene.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *w in ((UIWindowScene *)scene).windows) {
                    if (w.isKeyWindow)
                        return w;
                }
            }
        }
        return nil;
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        return [UIApplication sharedApplication].windows.firstObject;
#pragma clang diagnostic pop
    }
}

+ (NSString *)cachePathForFilename:(NSString *)filename {
    if (!filename || filename.length == 0) {
        return nil;
    }
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cachesDirectory = [paths firstObject];
    
    // 创建DYYY专用缓存目录
    NSString *dyyyDirectory = [cachesDirectory stringByAppendingPathComponent:@"DYYY"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    if (![fileManager fileExistsAtPath:dyyyDirectory]) {
        NSError *error;
        [fileManager createDirectoryAtPath:dyyyDirectory withIntermediateDirectories:YES attributes:nil error:&error];
        if (error) {
            NSLog(@"Failed to create DYYY cache directory: %@", error.localizedDescription);
            return [cachesDirectory stringByAppendingPathComponent:filename];
        }
    }
    
    return [dyyyDirectory stringByAppendingPathComponent:filename];
}

+ (void)executeWithTabBarSwiftUICheckDisabled:(dispatch_block_t)block {
    if (!block) return;
    
    // 简单地执行代码块，这个方法主要是为了兼容性
    // 在实际的抖音应用中，这可能涉及到一些内部的SwiftUI检查逻辑
    // 但在这里我们只需要确保代码块能够正常执行
    block();
}

+ (UIView *)findSubviewOfClass:(Class)targetClass inContainer:(UIView *)container {
    if (!targetClass || !container) return nil;
    
    for (UIView *subview in container.subviews) {
        if ([subview isKindOfClass:targetClass]) {
            return subview;
        }
        UIView *found = [self findSubviewOfClass:targetClass inContainer:subview];
        if (found) return found;
    }
    return nil;
}

+ (void)applyColorSettingsToLabel:(UILabel *)label colorHexString:(NSString *)colorHexString {
    if (!label || !colorHexString) return;
    
    // 简单的十六进制颜色解析
    NSString *cleanString = [colorHexString stringByReplacingOccurrencesOfString:@"#" withString:@""];
    if (cleanString.length == 6) {
        unsigned int rgbValue = 0;
        NSScanner *scanner = [NSScanner scannerWithString:cleanString];
        [scanner scanHexInt:&rgbValue];
        
        UIColor *color = [UIColor colorWithRed:((rgbValue & 0xFF0000) >> 16)/255.0
                                         green:((rgbValue & 0x00FF00) >> 8)/255.0
                                          blue:(rgbValue & 0x0000FF)/255.0
                                         alpha:1.0];
        label.textColor = color;
    }
}

+ (void)processAndApplyIPLocationToLabel:(UILabel *)label forModel:(id)model withLabelColor:(NSString *)colorHexString {
    NSString *originalText = label.text ?: @"";
    NSString *cityCode = [model valueForKey:@"cityCode"];

    if (cityCode.length == 0) {
        return;
    }

    objc_setAssociatedObject(label, kCurrentIPRequestCityCodeKey, cityCode, OBJC_ASSOCIATION_COPY_NONATOMIC);

    NSString *cityName = [[NSClassFromString(@"CityManager") sharedInstance] getCityNameWithCode:cityCode];
    NSString *provinceName = [[NSClassFromString(@"CityManager") sharedInstance] getProvinceNameWithCode:cityCode];

    if (!cityName || cityName.length == 0) {
        NSString *cacheKey = cityCode;
        static NSCache *geoNamesCache = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
          geoNamesCache = [[NSCache alloc] init];
          geoNamesCache.name = @"com.dyyy.geonames.cache";
          geoNamesCache.countLimit = 1000;
        });

        // 1 & 2. 查内存和磁盘缓存
        NSDictionary *cachedData = [geoNamesCache objectForKey:cacheKey];
        if (!cachedData) {
            NSString *cachesDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
            NSString *geoNamesCacheDir = [cachesDir stringByAppendingPathComponent:@"DYYYGeoNamesCache"];
            NSFileManager *fileManager = [NSFileManager defaultManager];
            if (![fileManager fileExistsAtPath:geoNamesCacheDir]) {
                [fileManager createDirectoryAtPath:geoNamesCacheDir withIntermediateDirectories:YES attributes:nil error:nil];
            }
            NSString *cacheFilePath = [geoNamesCacheDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist", cacheKey]];
            if ([fileManager fileExistsAtPath:cacheFilePath]) {
                cachedData = [NSDictionary dictionaryWithContentsOfFile:cacheFilePath];
                if (cachedData) {
                    [geoNamesCache setObject:cachedData forKey:cacheKey];
                }
            }
        }

        // 3. 处理缓存数据或发起网络请求
        if (cachedData) {
            NSString *countryName = cachedData[@"countryName"];
            NSString *adminName1 = cachedData[@"adminName1"];
            NSString *localName = cachedData[@"name"];
            NSString *displayLocation = @"未知";

            if (countryName.length > 0) {
                if (adminName1.length > 0 && localName.length > 0 && ![countryName isEqualToString:@"中国"] && ![countryName isEqualToString:localName]) {
                    displayLocation = [NSString stringWithFormat:@"%@ %@ %@", countryName, adminName1, localName];
                } else if (localName.length > 0 && ![countryName isEqualToString:localName]) {
                    displayLocation = [NSString stringWithFormat:@"%@ %@", countryName, localName];
                } else {
                    displayLocation = countryName;
                }
            } else if (localName.length > 0) {
                displayLocation = localName;
            }

            dispatch_async(dispatch_get_main_queue(), ^{
              NSString *currentRequestCode = objc_getAssociatedObject(label, kCurrentIPRequestCityCodeKey);
              if (![currentRequestCode isEqualToString:cityCode]) {
                  return;
              }

              NSString *currentLabelText = label.text ?: @"";
              if ([currentLabelText containsString:@"IP属地："]) {
                  NSRange range = [currentLabelText rangeOfString:@"IP属地："];
                  if (range.location != NSNotFound) {
                      NSString *baseText = [currentLabelText substringToIndex:range.location];
                      if (![currentLabelText containsString:displayLocation]) {
                          label.text = [NSString stringWithFormat:@"%@IP属地：%@", baseText, displayLocation];
                      }
                  }
              } else {
                  if (currentLabelText.length > 0 && ![displayLocation isEqualToString:@"未知"]) {
                      label.text = [NSString stringWithFormat:@"%@  IP属地：%@", currentLabelText, displayLocation];
                  } else if (![displayLocation isEqualToString:@"未知"]) {
                      label.text = [NSString stringWithFormat:@"IP属地：%@", displayLocation];
                  }
              }
              [DYYYUtils applyColorSettingsToLabel:label colorHexString:colorHexString];
            });
        } else {
            [[NSClassFromString(@"CityManager") sharedInstance] fetchLocationWithGeonameId:cityCode
                                  completionHandler:^(NSDictionary *locationInfo, NSError *error) {
                                    __block NSString *displayLocation = @"未知";

                                    if (error) {
                                        if ([error.domain isEqualToString:DYYYGeonamesErrorDomain] && error.code == 11) {
                                            displayLocation = error.localizedDescription;
                                        } else {
                                            NSLog(@"[DYYY] GeoNames fetch failed: %@", error.localizedDescription);
                                            return;
                                        }
                                    } else if (locationInfo) {
                                        NSString *countryName = locationInfo[@"countryName"];
                                        NSString *adminName1 = locationInfo[@"adminName1"];
                                        NSString *localName = locationInfo[@"name"];

                                        if (countryName.length > 0) {
                                            if (adminName1.length > 0 && localName.length > 0 && ![countryName isEqualToString:@"中国"] && ![countryName isEqualToString:localName]) {
                                                displayLocation = [NSString stringWithFormat:@"%@ %@ %@", countryName, adminName1, localName];
                                            } else if (localName.length > 0 && ![countryName isEqualToString:localName]) {
                                                displayLocation = [NSString stringWithFormat:@"%@ %@", countryName, localName];
                                            } else {
                                                displayLocation = countryName;
                                            }
                                        } else if (localName.length > 0) {
                                            displayLocation = localName;
                                        }

                                        if (![displayLocation isEqualToString:@"未知"]) {
                                            [geoNamesCache setObject:locationInfo forKey:cacheKey];
                                            NSString *cachesDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
                                            NSString *geoNamesCacheDir = [cachesDir stringByAppendingPathComponent:@"DYYYGeoNamesCache"];
                                            NSString *cacheFilePath = [geoNamesCacheDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist", cacheKey]];
                                            [locationInfo writeToFile:cacheFilePath atomically:YES];
                                        }
                                    }

                                    dispatch_async(dispatch_get_main_queue(), ^{
                                      NSString *currentRequestCode = objc_getAssociatedObject(label, kCurrentIPRequestCityCodeKey);
                                      if (![currentRequestCode isEqualToString:cityCode]) {
                                          return;
                                      }

                                      NSString *currentLabelText = label.text ?: @"";
                                      if ([currentLabelText containsString:@"IP属地："]) {
                                          NSRange range = [currentLabelText rangeOfString:@"IP属地："];
                                          if (range.location != NSNotFound) {
                                              NSString *baseText = [currentLabelText substringToIndex:range.location];
                                              if (![currentLabelText containsString:displayLocation]) {
                                                  label.text = [NSString stringWithFormat:@"%@IP属地：%@", baseText, displayLocation];
                                              }
                                          }
                                      } else {
                                          if (currentLabelText.length > 0 && ![displayLocation isEqualToString:@"未知"]) {
                                              label.text = [NSString stringWithFormat:@"%@  IP属地：%@", currentLabelText, displayLocation];
                                          } else if (![displayLocation isEqualToString:@"未知"]) {
                                              label.text = [NSString stringWithFormat:@"IP属地：%@", displayLocation];
                                          }
                                      }
                                      [DYYYUtils applyColorSettingsToLabel:label colorHexString:colorHexString];
                                    });
                                  }];
        }
    }

    else if (![originalText containsString:cityName]) {
        BOOL isDirectCity = [provinceName isEqualToString:cityName] || ([cityCode hasPrefix:@"11"] || [cityCode hasPrefix:@"12"] || [cityCode hasPrefix:@"31"] || [cityCode hasPrefix:@"50"]);
        id ipAttribution = [model valueForKey:@"ipAttribution"];
        if (!ipAttribution) {
            if (isDirectCity) {
                label.text = [NSString stringWithFormat:@"%@  IP属地：%@", originalText, cityName];
            } else {
                label.text = [NSString stringWithFormat:@"%@  IP属地：%@ %@", originalText, provinceName, cityName];
            }
        } else {
            BOOL containsProvince = [originalText containsString:provinceName];
            BOOL containsCity = [originalText containsString:cityName];
            if (containsProvince && !isDirectCity && !containsCity) {
                label.text = [NSString stringWithFormat:@"%@ %@", originalText, cityName];
            } else if (isDirectCity && !containsCity) {
                label.text = [NSString stringWithFormat:@"%@  IP属地：%@", originalText, cityName];
            }
        }
        [DYYYUtils applyColorSettingsToLabel:label colorHexString:colorHexString];
    }
}

+ (void)applyTextColorRecursively:(UIColor *)color inView:(UIView *)view shouldExcludeViewBlock:(BOOL(^)(UIView *))shouldExcludeViewBlock {
    if (!color || !view) return;
    
    if (shouldExcludeViewBlock && shouldExcludeViewBlock(view)) {
        return;
    }
    
    if ([view isKindOfClass:[UILabel class]]) {
        ((UILabel *)view).textColor = color;
    } else if ([view isKindOfClass:[UIButton class]]) {
        [(UIButton *)view setTitleColor:color forState:UIControlStateNormal];
    }
    
    for (UIView *subview in view.subviews) {
        [self applyTextColorRecursively:color inView:subview shouldExcludeViewBlock:shouldExcludeViewBlock];
    }
}

+ (UIViewController *)firstAvailableViewControllerFromView:(UIView *)view {
    if (!view) return nil;
    
    UIResponder *responder = view.nextResponder;
    while (responder) {
        if ([responder isKindOfClass:[UIViewController class]]) {
            return (UIViewController *)responder;
        }
        responder = responder.nextResponder;
    }
    return nil;
}

+ (UIColor *)colorFromSchemeHexString:(NSString *)colorHex targetWidth:(CGFloat)targetWidth {
    // 简化实现，忽略targetWidth参数
    if (!colorHex) return nil;
    
    NSString *cleanString = [colorHex stringByReplacingOccurrencesOfString:@"#" withString:@""];
    if (cleanString.length == 6) {
        unsigned int rgbValue = 0;
        NSScanner *scanner = [NSScanner scannerWithString:cleanString];
        [scanner scanHexInt:&rgbValue];
        
        return [UIColor colorWithRed:((rgbValue & 0xFF0000) >> 16)/255.0
                               green:((rgbValue & 0x00FF00) >> 8)/255.0
                                blue:(rgbValue & 0x0000FF)/255.0
                               alpha:1.0];
    }
    return nil;
}

+ (BOOL)containsSubviewOfClass:(Class)targetClass inContainer:(UIView *)container {
    if (!targetClass || !container) return NO;
    
    for (UIView *subview in container.subviews) {
        if ([subview isKindOfClass:targetClass]) {
            return YES;
        }
        if ([self containsSubviewOfClass:targetClass inContainer:subview]) {
            return YES;
        }
    }
    return NO;
}

+ (UIViewController *)findViewControllerOfClass:(Class)targetClass inViewController:(UIViewController *)viewController {
    if (!targetClass || !viewController) return nil;
    
    if ([viewController isKindOfClass:targetClass]) {
        return viewController;
    }
    
    for (UIViewController *childVC in viewController.childViewControllers) {
        UIViewController *found = [self findViewControllerOfClass:targetClass inViewController:childVC];
        if (found) return found;
    }
    
    if (viewController.presentedViewController) {
        return [self findViewControllerOfClass:targetClass inViewController:viewController.presentedViewController];
    }
    
    return nil;
}

+ (NSString *)formattedSize:(long long)size {
    if (size < 1024) {
        return [NSString stringWithFormat:@"%lld B", size];
    } else if (size < 1024 * 1024) {
        return [NSString stringWithFormat:@"%.1f KB", size / 1024.0];
    } else if (size < 1024 * 1024 * 1024) {
        return [NSString stringWithFormat:@"%.1f MB", size / (1024.0 * 1024.0)];
    } else {
        return [NSString stringWithFormat:@"%.1f GB", size / (1024.0 * 1024.0 * 1024.0)];
    }
}

+ (long long)directorySizeAtPath:(NSString *)path {
    if (!path) return 0;
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSDirectoryEnumerator *enumerator = [fileManager enumeratorAtPath:path];
    long long totalSize = 0;
    
    for (NSString *fileName in enumerator) {
        NSString *filePath = [path stringByAppendingPathComponent:fileName];
        NSDictionary *attributes = [fileManager attributesOfItemAtPath:filePath error:nil];
        if (attributes) {
            totalSize += [attributes fileSize];
        }
    }
    
    return totalSize;
}

+ (void)removeAllContentsAtPath:(NSString *)path {
    if (!path) return;
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *contents = [fileManager contentsOfDirectoryAtPath:path error:nil];
    
    for (NSString *fileName in contents) {
        NSString *filePath = [path stringByAppendingPathComponent:fileName];
        [fileManager removeItemAtPath:filePath error:nil];
    }
}

+ (BOOL)isLiquidGlassEnabled {
    // 检查用户是否启用了LiquidGlass功能
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    return [defaults boolForKey:@"DYYYLiquidGlassEnabled"];
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

UIViewController * _Nullable topView(void) {
    return [DYYYUtils topView];
}
