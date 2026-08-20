//
//  DYYYUtilsMedia.m
//  DYYY
//
//  GIF/HEIF 动图：时长解析、帧提取、转码与保存相册。
//

#import "DYYYUtils.h"
#import "AwemeHeaders.h"
#import <AVFoundation/AVFoundation.h>
#import <ImageIO/ImageIO.h>
#import <MobileCoreServices/UTCoreTypes.h>
#import <Photos/Photos.h>
#import <UIKit/UIKit.h>
#import <math.h>
#import <objc/message.h>

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

@implementation DYYYUtils (Media)

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
                        images:(NSArray<UIImage *> * _Nullable * _Nullable)images
                 totalDuration:(CGFloat * _Nullable)totalDuration {
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
