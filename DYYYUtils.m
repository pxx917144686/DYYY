#import "DYYYUtils.h"
#import <AVFoundation/AVFoundation.h>
#import <ImageIO/ImageIO.h>
#import <MobileCoreServices/UTCoreTypes.h>
#import <Photos/Photos.h>
#import <UIKit/UIKit.h>
#import <math.h>
#import <stdatomic.h>
#import <os/lock.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import "AwemeHeaders.h"
#import "DYYYToast.h"

@class YYImageDecoder;
@class YYImageFrame;

@interface YYImageFrame : NSObject
@property(nonatomic, strong) UIImage *image;
@property(nonatomic) CGFloat duration;
@end

@interface YYImageDecoder : NSObject
@property(nonatomic, readonly) NSUInteger frameCount;
+ (instancetype)decoderWithData:(NSData *)data scale:(CGFloat)scale;
- (YYImageFrame *)frameAtIndex:(NSUInteger)index decodeForDisplay:(BOOL)decodeForDisplay;
@end

static const NSTimeInterval kDYYYUtilsDefaultFrameDelay = 0.1f;

static inline CGFloat DYYYUtilsNormalizedDelay(CGFloat delay) {
    if (!isfinite(delay) || delay < 0.01f) {
        return kDYYYUtilsDefaultFrameDelay;
    }
    return delay;
}

static YYImageDecoder *DYYYUtilsCreateYYDecoderWithData(NSData *data, CGFloat scale) {
    if (!data || data.length == 0) {
        return nil;
    }

    Class decoderClass = NSClassFromString(@"YYImageDecoder");
    if (!decoderClass || ![decoderClass respondsToSelector:@selector(decoderWithData:scale:)]) {
        return nil;
    }

    CGFloat resolvedScale = scale > 0 ? scale : 1.0f;
    id decoderInstance = [(id)decoderClass decoderWithData:data scale:resolvedScale];
    if (![decoderInstance isKindOfClass:decoderClass]) {
        return nil;
    }

    return (YYImageDecoder *)decoderInstance;
}

static CGFloat DYYYUtilsTotalDurationFromYYDecoder(YYImageDecoder *decoder) {
    if (!decoder || decoder.frameCount == 0) {
        return 0;
    }

    CGFloat totalDuration = 0;
    NSUInteger frameCount = decoder.frameCount;
    for (NSUInteger i = 0; i < frameCount; i++) {
        YYImageFrame *frame = [decoder frameAtIndex:i decodeForDisplay:NO];
        if (!frame) {
            continue;
        }
        CGFloat frameDuration = frame.duration > 0 ? frame.duration : kDYYYUtilsDefaultFrameDelay;
        totalDuration += frameDuration;
    }

    return totalDuration;
}

static uint32_t DYYYUtilsReadUInt32BigEndian(const uint8_t *bytes) {
    return ((uint32_t)bytes[0] << 24) | ((uint32_t)bytes[1] << 16) | ((uint32_t)bytes[2] << 8) | (uint32_t)bytes[3];
}

static uint64_t DYYYUtilsReadUInt64BigEndian(const uint8_t *bytes) {
    uint64_t value = 0;
    for (NSUInteger i = 0; i < 8; i++) {
        value = (value << 8) | (uint64_t)bytes[i];
    }
    return value;
}

static NSTimeInterval DYYYUtilsParseMVHDDuration(const uint8_t *bytes, NSUInteger length) {
    NSUInteger position = 0;
    while (position + 8 <= length) {
        uint64_t rawSize = DYYYUtilsReadUInt32BigEndian(bytes + position);
        NSUInteger header = 8;

        if (rawSize == 1) {
            if (position + 16 > length) {
                break;
            }
            rawSize = DYYYUtilsReadUInt64BigEndian(bytes + position + 8);
            header = 16;
        } else if (rawSize == 0) {
            rawSize = length - position;
        }

        if (rawSize < header || position + rawSize > length) {
            break;
        }

        const uint8_t *typePtr = bytes + position + 4;
        if (typePtr[0] == 'm' && typePtr[1] == 'v' && typePtr[2] == 'h' && typePtr[3] == 'd') {
            const uint8_t *payload = bytes + position + header;
            NSUInteger payloadLength = (NSUInteger)rawSize - header;
            if (payloadLength < 20) {
                break;
            }

            uint8_t version = payload[0];
            if (version == 0) {
                uint32_t timescale = DYYYUtilsReadUInt32BigEndian(payload + 12);
                uint32_t duration = DYYYUtilsReadUInt32BigEndian(payload + 16);
                if (timescale > 0) {
                    return (NSTimeInterval)duration / (NSTimeInterval)timescale;
                }
            } else if (version == 1) {
                if (payloadLength < 32) {
                    break;
                }
                uint32_t timescale = DYYYUtilsReadUInt32BigEndian(payload + 20);
                uint64_t duration = DYYYUtilsReadUInt64BigEndian(payload + 24);
                if (timescale > 0) {
                    return (NSTimeInterval)duration / (NSTimeInterval)timescale;
                }
            }
        }

        position += (NSUInteger)rawSize;
    }

    return 0;
}

static NSTimeInterval DYYYUtilsParseHEIFDuration(const uint8_t *bytes, NSUInteger length) {
    NSUInteger position = 0;
    while (position + 8 <= length) {
        uint64_t rawSize = DYYYUtilsReadUInt32BigEndian(bytes + position);
        NSUInteger header = 8;

        if (rawSize == 1) {
            if (position + 16 > length) {
                break;
            }
            rawSize = DYYYUtilsReadUInt64BigEndian(bytes + position + 8);
            header = 16;
        } else if (rawSize == 0) {
            rawSize = length - position;
        }

        if (rawSize < header || position + rawSize > length) {
            break;
        }

        const uint8_t *typePtr = bytes + position + 4;
        if (typePtr[0] == 'm' && typePtr[1] == 'o' && typePtr[2] == 'o' && typePtr[3] == 'v') {
            NSTimeInterval duration = DYYYUtilsParseMVHDDuration(bytes + position + header, (NSUInteger)rawSize - header);
            if (duration > 0) {
                return duration;
            }
        }

        position += (NSUInteger)rawSize;
    }

    return 0;
}

static NSTimeInterval DYYYUtilsHEIFDurationFromData(NSData *data) {
    if (!data || data.length < 16) {
        return 0;
    }
    const uint8_t *bytes = (const uint8_t *)data.bytes;
    return DYYYUtilsParseHEIFDuration(bytes, data.length);
}

static NSURL *DYYYUtilsTemporaryGIFURLForSourceURL(NSURL *sourceURL) {
    NSString *baseName = sourceURL.lastPathComponent.stringByDeletingPathExtension;
    if (baseName.length == 0) {
        baseName = @"image";
    }
    NSString *fileName = [NSString stringWithFormat:@"%@_%@.gif", baseName, [[NSUUID UUID] UUIDString]];
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
    return [NSURL fileURLWithPath:path];
}

static BOOL DYYYUtilsWriteGIFUsingYYDecoder(YYImageDecoder *decoder, NSURL *gifURL, NSTimeInterval fallbackTotalDuration) {
    if (!decoder || decoder.frameCount == 0) {
        return NO;
    }

    NSUInteger frameCount = (NSUInteger)decoder.frameCount;
    CGFloat fallbackFrameDuration = 0;
    if (fallbackTotalDuration > 0 && frameCount > 0) {
        fallbackFrameDuration = fallbackTotalDuration / frameCount;
    }
    CGImageDestinationRef dest = CGImageDestinationCreateWithURL((__bridge CFURLRef)gifURL, kUTTypeGIF, frameCount, NULL);
    if (!dest) {
        return NO;
    }

    NSDictionary *gifProperties = @{(__bridge NSString *)kCGImagePropertyGIFDictionary : @{(__bridge NSString *)kCGImagePropertyGIFLoopCount : @0}};
    CGImageDestinationSetProperties(dest, (__bridge CFDictionaryRef)gifProperties);

    BOOL hasFrame = NO;
    for (NSUInteger i = 0; i < frameCount; i++) {
        YYImageFrame *frame = [decoder frameAtIndex:i decodeForDisplay:YES];
        UIImage *image = frame.image;
        CGImageRef imageRef = image.CGImage;
        if (!imageRef) {
            continue;
        }

        CGFloat frameDuration = frame.duration;
        if ((!isfinite(frameDuration) || frameDuration <= 0) && fallbackFrameDuration > 0) {
            frameDuration = fallbackFrameDuration;
        }
        CGFloat delay = DYYYUtilsNormalizedDelay(frameDuration);
        NSDictionary *frameProps = @{(__bridge NSString *)kCGImagePropertyGIFDictionary : @{(__bridge NSString *)kCGImagePropertyGIFDelayTime : @(delay)}};
        CGImageDestinationAddImage(dest, imageRef, (__bridge CFDictionaryRef)frameProps);
        hasFrame = YES;
    }

    BOOL success = hasFrame ? CGImageDestinationFinalize(dest) : NO;
    CFRelease(dest);
    return success;
}

@interface DYYYUtils ()
+ (id)dyyy_safeValueForKey:(NSString *)key fromObject:(id)object;
+ (BOOL)dyyy_objectContainsMeaningfulAdPayload:(id)object;
@end

@implementation DYYYUtils

#pragma mark - Advertisement Filtering Utilities (广告过滤工具)

+ (id)dyyy_safeValueForKey:(NSString *)key fromObject:(id)object {
    if (!object || key.length == 0) {
        return nil;
    }

    @try {
        return [object valueForKey:key];
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

+ (BOOL)dyyy_objectContainsMeaningfulAdPayload:(id)object {
    if (!object || object == [NSNull null]) {
        return NO;
    }
    if ([object isKindOfClass:[NSString class]]) {
        NSString *value = [(NSString *)object stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        return value.length > 0 &&
               ![value isEqualToString:@"{}"] &&
               ![value isEqualToString:@"[]"] &&
               ![value isEqualToString:@"null"];
    }
    if ([object isKindOfClass:[NSData class]]) {
        return [(NSData *)object length] > 0;
    }
    if ([object isKindOfClass:[NSDictionary class]] || [object isKindOfClass:[NSArray class]]) {
        return [object count] > 0;
    }
    if ([object isKindOfClass:[NSNumber class]]) {
        return [(NSNumber *)object boolValue];
    }
    return NO;
}

+ (BOOL)isAdvertisementAwemeModel:(id)model {
    Class awemeModelClass = NSClassFromString(@"AWEAwemeModel");
    if (!model || !awemeModelClass || ![model isKindOfClass:awemeModelClass]) {
        return NO;
    }

    // 仅信任抖音模型自身明确的广告布尔判定，避免把常驻的广告能力占位对象误当成广告。
    for (NSString *selectorName in @[ @"checkIsAd", @"isHardAdModel", @"isHardAd", @"isAds" ]) {
        SEL selector = NSSelectorFromString(selectorName);
        if ([model respondsToSelector:selector]) {
            BOOL (*sendBool)(id, SEL) = (BOOL (*)(id, SEL))objc_msgSend;
            if (sendBool(model, selector)) {
                return YES;
            }
        }
    }

    return NO;
}

+ (BOOL)isAdvertisementContainerModel:(id)model {
    if ([self isAdvertisementAwemeModel:model]) {
        return YES;
    }

    Class searchModelClass = NSClassFromString(@"AWEGeneralSearchModel");
    if (!searchModelClass || ![model isKindOfClass:searchModelClass]) {
        return NO;
    }

    // 搜索模型中的模块、卡片名和卡片类型在正常作品中也可能作为能力占位常驻，不能单独作为广告证据。
    id dynamicPatch = [self dyyy_safeValueForKey:@"commonDynamicPatchModel" fromObject:model];
    id isAdValue = [self dyyy_safeValueForKey:@"is_ad" fromObject:dynamicPatch];
    if ([isAdValue respondsToSelector:@selector(boolValue)] && [isAdValue boolValue]) {
        return YES;
    }

    for (NSString *selectorName in @[ @"aweme", @"awemeInVideoFeed" ]) {
        SEL selector = NSSelectorFromString(selectorName);
        if (![model respondsToSelector:selector]) {
            continue;
        }
        id (*sendObject)(id, SEL) = (id (*)(id, SEL))objc_msgSend;
        if ([self isAdvertisementAwemeModel:sendObject(model, selector)]) {
            return YES;
        }
    }

    return NO;
}

+ (NSArray *)arrayByRemovingAdvertisements:(id)array {
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYNoAds"] || ![array isKindOfClass:[NSArray class]]) {
        return array;
    }

    NSArray *source = (NSArray *)array;
    NSMutableArray *filtered = [NSMutableArray arrayWithCapacity:source.count];
    for (id model in source) {
        if (![self isAdvertisementContainerModel:model]) {
            [filtered addObject:model];
        }
    }

    if (filtered.count == source.count) {
        return array;
    }
    return [array isKindOfClass:[NSMutableArray class]] ? filtered : [filtered copy];
}

+ (BOOL)isAdvertisementRawData:(id)rawData {
    if (![rawData isKindOfClass:[NSDictionary class]]) {
        return NO;
    }

    NSDictionary *dictionary = (NSDictionary *)rawData;
    for (NSString *flagKey in @[ @"is_ads", @"is_ad" ]) {
        id value = dictionary[flagKey];
        if ([value respondsToSelector:@selector(boolValue)] && [value boolValue]) {
            return YES;
        }
    }

    // 仅检查名称本身就代表广告原始载荷的字段；普通作品也可能带有通用 ad_info 能力配置。
    for (NSString *payloadKey in @[ @"aweme_raw_ad", @"raw_ad_data" ]) {
        if ([self dyyy_objectContainsMeaningfulAdPayload:dictionary[payloadKey]]) {
            return YES;
        }
    }

    for (NSString *containerKey in @[ @"aweme", @"aweme_info", @"item", @"common_dynamic_patch_model" ]) {
        if ([self isAdvertisementRawData:dictionary[containerKey]]) {
            return YES;
        }
    }

    return NO;
}

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

+ (UIViewController *)findViewControllerFromView:(UIView *)view {
    if (!view) return nil;
    UIResponder *responder = view;
    while (responder) {
        if ([responder isKindOfClass:[UIViewController class]]) {
            return (UIViewController *)responder;
        }
        responder = responder.nextResponder;
    }
    return nil;
}

+ (UIViewController *)findViewControllerOfClass:(Class)targetClass inViewController:(UIViewController *)vc {
    if (!targetClass || !vc) {
        return nil;
    }
    if ([vc isKindOfClass:targetClass]) {
        return vc;
    }
    for (UIViewController *childVC in vc.childViewControllers) {
        UIViewController *found = [self findViewControllerOfClass:targetClass inViewController:childVC];
        if (found) {
            return found;
        }
    }
    return [self findViewControllerOfClass:targetClass inViewController:vc.presentedViewController];
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

#pragma mark - Animated Sticker / GIF Utilities (动图表情/GIF工具)

+ (BOOL)isBDImageWithHeifURL:(UIImage *)image {
    if (!image) {
        return NO;
    }

    if ([NSStringFromClass([image class]) containsString:@"BDImage"]) {
        if ([image respondsToSelector:@selector(bd_webURL)]) {
            NSURL *webURL = [image performSelector:@selector(bd_webURL)];
            if (webURL) {
                NSString *urlString = webURL.absoluteString;
                return [urlString containsString:@".heif"] || [urlString containsString:@".heic"];
            }
        }
    }

    return NO;
}

+ (NSArray *)getImagesFromYYAnimatedImageView:(YYAnimatedImageView *)imageView {
    if (!imageView || !imageView.image) {
        return nil;
    }
    if ([imageView.image respondsToSelector:@selector(images)]) {
        return [imageView.image performSelector:@selector(images)];
    }
    return nil;
}

+ (CGFloat)getDurationFromYYAnimatedImageView:(YYAnimatedImageView *)imageView {
    if (!imageView || !imageView.image) {
        return 0;
    }

    UIImage *image = imageView.image;

    if (image.images.count > 0) {
        NSTimeInterval builtInDuration = image.duration;
        if (builtInDuration <= 0) {
            builtInDuration = image.images.count * kDYYYUtilsDefaultFrameDelay;
        }
        return builtInDuration;
    }

    SEL frameCountSEL = NSSelectorFromString(@"animatedImageFrameCount");
    SEL frameDurationSEL = NSSelectorFromString(@"animatedImageDurationAtIndex:");
    if ([image respondsToSelector:frameCountSEL] && [image respondsToSelector:frameDurationSEL]) {
        NSUInteger frameCount = ((NSUInteger(*)(id, SEL))objc_msgSend)(image, frameCountSEL);
        if (frameCount > 0) {
            CGFloat totalDuration = 0;
            for (NSUInteger i = 0; i < frameCount; i++) {
                CGFloat frameDuration = ((CGFloat(*)(id, SEL, NSUInteger))objc_msgSend)(image, frameDurationSEL, i);
                totalDuration += frameDuration > 0 ? frameDuration : kDYYYUtilsDefaultFrameDelay;
            }
            if (totalDuration > 0) {
                return totalDuration;
            }
        }
    }

    SEL dataSEL = NSSelectorFromString(@"animatedImageData");
    NSData *animatedData = nil;
    if ([image respondsToSelector:dataSEL]) {
        animatedData = ((NSData *(*)(id, SEL))objc_msgSend)(image, dataSEL);
    }
    if (animatedData.length > 0) {
        CGFloat scale = image.scale > 0 ? image.scale : 1.0f;
        YYImageDecoder *decoder = DYYYUtilsCreateYYDecoderWithData(animatedData, scale);
        CGFloat decoderDuration = DYYYUtilsTotalDurationFromYYDecoder(decoder);
        if (decoderDuration > 0) {
            return decoderDuration;
        }
    }

    if ([image respondsToSelector:@selector(duration)]) {
        NSTimeInterval duration = image.duration;
        if (duration > 0) {
            return duration;
        }
    }

    id durationValue = [image valueForKey:@"duration"];
    return [durationValue respondsToSelector:@selector(floatValue)] ? [durationValue floatValue] : 0;
}

+ (BOOL)framesFromAnimatedData:(NSData *)data
                         scale:(CGFloat)scale
                        images:(NSArray<UIImage *> *_Nullable *)images
                 totalDuration:(CGFloat *_Nullable)totalDuration {
    if (images) {
        *images = nil;
    }
    if (totalDuration) {
        *totalDuration = 0;
    }
    if (!data.length) {
        return NO;
    }

    CGFloat resolvedScale = scale > 0 ? scale : 1.0f;
    YYImageDecoder *decoder = DYYYUtilsCreateYYDecoderWithData(data, resolvedScale);
    if (!decoder || decoder.frameCount == 0) {
        return NO;
    }

    NSMutableArray<UIImage *> *decodedFrames = [NSMutableArray arrayWithCapacity:decoder.frameCount];
    CGFloat durationAccumulator = 0;
    for (NSUInteger i = 0; i < decoder.frameCount; i++) {
        YYImageFrame *frame = [decoder frameAtIndex:i decodeForDisplay:YES];
        if (!frame || !frame.image) {
            continue;
        }
        [decodedFrames addObject:frame.image];
        durationAccumulator += DYYYUtilsNormalizedDelay(frame.duration);
    }

    if (decodedFrames.count == 0) {
        return NO;
    }

    if (images) {
        *images = [decodedFrames copy];
    }
    if (totalDuration) {
        *totalDuration = durationAccumulator > 0 ? durationAccumulator : decodedFrames.count * kDYYYUtilsDefaultFrameDelay;
    }

    return YES;
}

+ (BOOL)createGIFWithImages:(NSArray *)images duration:(CGFloat)duration path:(NSString *)path progress:(void (^)(float progress))progressBlock {
    if (images.count == 0 || path.length == 0) {
        return NO;
    }

    CGFloat safeDuration = duration > 0 ? duration : (0.1f * images.count);
    float frameDuration = safeDuration / images.count;
    CGImageDestinationRef destination = CGImageDestinationCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:path], kUTTypeGIF, images.count, NULL);
    if (!destination) {
        return NO;
    }

    NSDictionary *gifProperties = @{(__bridge NSString *)kCGImagePropertyGIFDictionary : @{(__bridge NSString *)kCGImagePropertyGIFLoopCount : @0}};
    CGImageDestinationSetProperties(destination, (__bridge CFDictionaryRef)gifProperties);

    for (NSUInteger i = 0; i < images.count; i++) {
        UIImage *image = images[i];
        NSDictionary *frameProperties = @{(__bridge NSString *)kCGImagePropertyGIFDictionary : @{(__bridge NSString *)kCGImagePropertyGIFDelayTime : @(frameDuration)}};
        CGImageDestinationAddImage(destination, image.CGImage, (__bridge CFDictionaryRef)frameProperties);
        if (progressBlock) {
            progressBlock((float)(i + 1) / images.count);
        }
    }

    BOOL success = CGImageDestinationFinalize(destination);
    CFRelease(destination);
    return success;
}

+ (void)saveGIFToPhotoLibrary:(NSString *)path completion:(void (^)(BOOL success, NSError *error))completion {
    NSURL *fileURL = [NSURL fileURLWithPath:path];
    [[PHPhotoLibrary sharedPhotoLibrary]
        performChanges:^{
          PHAssetCreationRequest *request = [PHAssetCreationRequest creationRequestForAsset];
          [request addResourceWithType:PHAssetResourceTypePhoto fileURL:fileURL options:nil];
        }
        completionHandler:^(BOOL success, NSError *_Nullable error) {
          dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(success, error);
            }
            NSError *removeError = nil;
            [[NSFileManager defaultManager] removeItemAtPath:path error:&removeError];
            if (removeError) {
                NSLog(@"删除临时GIF文件失败: %@", removeError);
            }
          });
        }];
}

+ (void)saveGifToPhotoLibrary:(NSURL *)gifURL completion:(void (^)(BOOL success))completion {
    [[PHPhotoLibrary sharedPhotoLibrary]
        performChanges:^{
          NSData *gifData = [NSData dataWithContentsOfURL:gifURL];
          PHAssetCreationRequest *request = [PHAssetCreationRequest creationRequestForAsset];
          PHAssetResourceCreationOptions *options = [[PHAssetResourceCreationOptions alloc] init];
          options.uniformTypeIdentifier = @"com.compuserve.gif";
          [request addResourceWithType:PHAssetResourceTypePhoto data:gifData options:options];
        }
        completionHandler:^(BOOL success, NSError *_Nullable error) {
          dispatch_async(dispatch_get_main_queue(), ^{
            if (!success) {
              [DYYYUtils showToast:@"保存失败"];
            }
            [[NSFileManager defaultManager] removeItemAtPath:gifURL.path error:nil];
            if (completion) {
                completion(success);
            }
          });
        }];
}

+ (void)convertHeicToGif:(NSURL *)heicURL completion:(void (^)(NSURL *gifURL, BOOL success))completion {
    if (!heicURL) {
        dispatch_async(dispatch_get_main_queue(), ^{
          if (completion) {
              completion(nil, NO);
          }
        });
        return;
    }

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      NSData *heicData = [NSData dataWithContentsOfURL:heicURL options:NSDataReadingMappedIfSafe error:nil];
      NSTimeInterval heifDuration = DYYYUtilsHEIFDurationFromData(heicData);
      NSURL *gifURL = DYYYUtilsTemporaryGIFURLForSourceURL(heicURL);
      [[NSFileManager defaultManager] removeItemAtURL:gifURL error:nil];

      BOOL success = NO;
      NSString *failureReason = nil;

      if (!heicData || heicData.length == 0) {
          failureReason = @"读取HEIC数据失败或数据为空";
      } else {
          YYImageDecoder *decoder = DYYYUtilsCreateYYDecoderWithData(heicData, 1.0f);
          if (!decoder) {
              failureReason = @"无法通过YYImageDecoder解析HEIC数据，可能是资源不是动图或SDK不可用";
          } else if (decoder.frameCount == 0) {
              failureReason = @"YYImageDecoder未解析到任何帧，HEIC资源可能不是动图";
          } else {
              success = DYYYUtilsWriteGIFUsingYYDecoder(decoder, gifURL, heifDuration);
              if (!success) {
                  failureReason = @"YYImageDecoder写入GIF失败，可能是图像数据损坏或磁盘空间不足";
              }
          }
      }

      if (!success) {
          [[NSFileManager defaultManager] removeItemAtURL:gifURL error:nil];
          if (failureReason.length > 0) {
              NSLog(@"[DYYY] convertHeicToGif失败: %@", failureReason);
          }
      }

      dispatch_async(dispatch_get_main_queue(), ^{
        if (completion) {
            completion(success ? gifURL : nil, success);
        }
      });
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
