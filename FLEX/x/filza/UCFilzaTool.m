#import "UCFilzaTool.h"
#import "../Shared/UCAppGroupHelper.h"
#import "../../FLEXTableListViewController.h"
#import <CoreFoundation/CoreFoundation.h>
#import <ImageIO/ImageIO.h>
#import <Photos/Photos.h>
#import <QuickLook/QuickLook.h>
#import <dlfcn.h>
#import <limits.h>
#import <mach-o/loader.h>
#import <mach-o/dyld.h>
#import <mach/vm_statistics.h>
#import <sys/sysctl.h>
#import <Security/Security.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <string.h>
#import <zlib.h>

typedef NS_ENUM(NSUInteger, UCFilzaEditorMode) {
    UCFilzaEditorModeText = 0,
    UCFilzaEditorModeHex = 1,
};

typedef NS_ENUM(NSUInteger, UCFilzaContentKind) {
    UCFilzaContentKindPlainText = 0,
    UCFilzaContentKindJSON,
    UCFilzaContentKindPropertyList,
    UCFilzaContentKindBinary,
};

static NSString *UCFilzaByteCountString(unsigned long long size) {
    return [NSByteCountFormatter stringFromByteCount:(long long)size countStyle:NSByteCountFormatterCountStyleFile];
}

static NSDateFormatter *UCFilzaDateFormatter(void) {
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [NSDateFormatter new];
        formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    });
    return formatter;
}

static NSDateFormatter *UCFilzaFileNameDateFormatter(void) {
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [NSDateFormatter new];
        formatter.dateFormat = @"yyyyMMdd-HHmmss";
    });
    return formatter;
}

static BOOL UCFilzaPathIsDirectory(NSString *path) {
    BOOL isDirectory = NO;
    return [NSFileManager.defaultManager fileExistsAtPath:path isDirectory:&isDirectory] && isDirectory;
}

static NSSet<NSString *> *UCFilzaImageExtensions(void) {
    static NSSet<NSString *> *extensions = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        extensions = [NSSet setWithArray:@[@"png", @"jpg", @"jpeg", @"gif", @"bmp", @"tif", @"tiff", @"webp", @"heic", @"heif"]];
    });
    return extensions;
}

static NSSet<NSString *> *UCFilzaAudioExtensions(void) {
    static NSSet<NSString *> *extensions = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        extensions = [NSSet setWithArray:@[@"mp3", @"m4a", @"aac", @"wav", @"caf", @"aiff", @"aif", @"amr", @"flac", @"ogg"]];
    });
    return extensions;
}

static NSSet<NSString *> *UCFilzaVideoExtensions(void) {
    static NSSet<NSString *> *extensions = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        extensions = [NSSet setWithArray:@[@"mp4", @"mov", @"m4v", @"avi", @"mkv", @"3gp", @"mpeg", @"mpg", @"webm"]];
    });
    return extensions;
}

static NSSet<NSString *> *UCFilzaPDFExtensions(void) {
    static NSSet<NSString *> *extensions = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        extensions = [NSSet setWithArray:@[@"pdf"]];
    });
    return extensions;
}

static NSSet<NSString *> *UCFilzaSQLiteExtensions(void) {
    static NSSet<NSString *> *extensions = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        extensions = [NSSet setWithArray:@[@"db", @"sqlite", @"sqlite3", @"db3", @"sqlitedb"]];
    });
    return extensions;
}

static NSSet<NSString *> *UCFilzaZIPExtensions(void) {
    static NSSet<NSString *> *extensions = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        extensions = [NSSet setWithArray:@[@"zip"]];
    });
    return extensions;
}

static BOOL UCFilzaPathHasExtensionInSet(NSString *path, NSSet<NSString *> *extensions) {
    if (path.length == 0) return NO;
    return [extensions containsObject:path.pathExtension.lowercaseString ?: @""];
}

static BOOL UCFilzaIsImagePath(NSString *path) {
    return UCFilzaPathHasExtensionInSet(path, UCFilzaImageExtensions());
}

static BOOL UCFilzaIsAudioPath(NSString *path) {
    return UCFilzaPathHasExtensionInSet(path, UCFilzaAudioExtensions());
}

static BOOL UCFilzaIsVideoPath(NSString *path) {
    return UCFilzaPathHasExtensionInSet(path, UCFilzaVideoExtensions());
}

static BOOL UCFilzaIsPDFPath(NSString *path) {
    return UCFilzaPathHasExtensionInSet(path, UCFilzaPDFExtensions());
}

static BOOL UCFilzaIsSQLitePath(NSString *path) {
    return UCFilzaPathHasExtensionInSet(path, UCFilzaSQLiteExtensions());
}

static BOOL UCFilzaIsZIPPath(NSString *path) {
    return UCFilzaPathHasExtensionInSet(path, UCFilzaZIPExtensions());
}

static BOOL UCFilzaIsAssetsCarPath(NSString *path) {
    NSString *extension = path.pathExtension.lowercaseString ?: @"";
    NSString *lastName = path.lastPathComponent.lowercaseString ?: @"";
    return [extension isEqualToString:@"car"] || [lastName isEqualToString:@"assets.car"];
}

static UIImage *UCFilzaAspectFitThumbnailImage(UIImage *image, CGSize targetSize);

static UIImage *UCFilzaThumbnailForImageFile(NSString *filePath, CGSize targetSize) {
    if (filePath.length == 0) return nil;

    NSURL *fileURL = [NSURL fileURLWithPath:filePath];
    CGImageSourceRef source = CGImageSourceCreateWithURL((CFURLRef)fileURL, nil);
    if (source) {
        NSDictionary<NSString *, id> *thumbOptions = @{
            (NSString *)kCGImageSourceCreateThumbnailFromImageAlways: @YES,
            (NSString *)kCGImageSourceCreateThumbnailFromImageIfAbsent: @YES,
            (NSString *)kCGImageSourceThumbnailMaxPixelSize: @(MAX(targetSize.width * 2, targetSize.height * 2)),
            (NSString *)kCGImageSourceShouldCache: @NO,
        };
        CGImageRef thumbnailRef = CGImageSourceCreateThumbnailAtIndex(source, 0, (CFDictionaryRef)thumbOptions);
        CFRelease(source);
        if (thumbnailRef) {
            UIImage *image = [UIImage imageWithCGImage:thumbnailRef scale:UIScreen.mainScreen.scale orientation:UIImageOrientationUp];
            CGImageRelease(thumbnailRef);
            if (image) {
                return UCFilzaAspectFitThumbnailImage(image, targetSize);
            }
        }
    }

    @try {
        NSData *data = [NSData dataWithContentsOfFile:filePath];
        if (!data || data.length == 0) return nil;

        UIImage *fullImage = [UIImage imageWithData:data];
        if (!fullImage) return nil;

        if (data.length < 51200) {
            return UCFilzaAspectFitThumbnailImage(fullImage, targetSize);
        }

        CGSize originalSize = fullImage.size;
        CGFloat scale = MIN(targetSize.width / originalSize.width, targetSize.height / originalSize.height);
        if (scale >= 1.0) {
            return UCFilzaAspectFitThumbnailImage(fullImage, targetSize);
        }

        CGSize drawSize = CGSizeMake(originalSize.width * scale * 2, originalSize.height * scale * 2);
        UIGraphicsBeginImageContextWithOptions(drawSize, NO, UIScreen.mainScreen.scale);
        [fullImage drawInRect:CGRectMake(0, 0, drawSize.width, drawSize.height)];
        UIImage *resized = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();

        if (resized) {
            return UCFilzaAspectFitThumbnailImage(resized, targetSize);
        }
        return UCFilzaAspectFitThumbnailImage(fullImage, targetSize);
    } @catch (NSException *exception) {
        return nil;
    }
}

static BOOL UCFilzaShouldUseQuickLookPreview(NSString *path) {
    return UCFilzaIsImagePath(path) || UCFilzaIsAudioPath(path) || UCFilzaIsVideoPath(path) || UCFilzaIsPDFPath(path);
}

static UIImage *UCFilzaAspectFitThumbnailImage(UIImage *image, CGSize targetSize);

static NSString *UCFilzaSymbolNameForFilePath(NSString *path, BOOL isDirectory) {
    if (isDirectory) return @"folder.fill";
    if (UCFilzaIsAssetsCarPath(path)) return @"shippingbox.fill";
    if (UCFilzaIsSQLitePath(path)) return @"cylinder.fill";
    if (UCFilzaIsZIPPath(path)) return @"archivebox.fill";
    if (UCFilzaIsImagePath(path)) return @"photo.fill";
    if (UCFilzaIsAudioPath(path)) return @"music.note";
    if (UCFilzaIsVideoPath(path)) return @"film.fill";
    if (UCFilzaIsPDFPath(path)) return @"doc.richtext.fill";
    return @"doc.fill";
}

static UIColor *UCFilzaTintColorForFilePath(NSString *path, BOOL isDirectory) {
    if (isDirectory) return UIColor.systemYellowColor;
    if (UCFilzaIsAssetsCarPath(path)) return UIColor.systemBrownColor;
    if (UCFilzaIsSQLitePath(path)) return UIColor.systemIndigoColor;
    if (UCFilzaIsZIPPath(path)) return UIColor.systemMintColor;
    if (UCFilzaIsImagePath(path)) return UIColor.systemPinkColor;
    if (UCFilzaIsAudioPath(path)) return UIColor.systemPurpleColor;
    if (UCFilzaIsVideoPath(path)) return UIColor.systemRedColor;
    if (UCFilzaIsPDFPath(path)) return UIColor.systemOrangeColor;
    return UIColor.systemBlueColor;
}

static NSString *UCFilzaBackupPathForOriginalPath(NSString *path) {
    NSString *directory = path.stringByDeletingLastPathComponent ?: @"";
    NSString *baseName = path.lastPathComponent.stringByDeletingPathExtension ?: path.lastPathComponent;
    NSString *extension = path.pathExtension ?: @"";
    NSString *timestamp = [UCFilzaFileNameDateFormatter() stringFromDate:[NSDate date]];
    NSString *backupName = extension.length
        ? [NSString stringWithFormat:@"%@_backup_%@.%@", baseName, timestamp, extension]
        : [NSString stringWithFormat:@"%@_backup_%@", baseName, timestamp];
    return [directory stringByAppendingPathComponent:backupName];
}

static NSString *UCFilzaJoinedPathSummary(NSArray<NSDictionary<NSString *, NSString *> *> *groups) {
    if (groups.count == 0) return @"无可访问应用组目录";
    if (groups.count == 1) return groups.firstObject[@"path"] ?: @"";
    return [NSString stringWithFormat:@"共 %lu 个应用组目录", (unsigned long)groups.count];
}

static void UCFilzaPresentMessage(UIViewController *host, NSString *title, NSString *message) {
    if (!host) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleCancel handler:nil]];
    [host presentViewController:alert animated:YES completion:nil];
}

static void UCFilzaPresentTransientMessage(UIViewController *host, NSString *title, NSString *message) {
    if (!host) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [host presentViewController:alert animated:YES completion:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (alert.presentingViewController) {
            [alert dismissViewControllerAnimated:YES completion:nil];
        }
    });
}

static NSArray<NSNumber *> *UCFilzaCandidateEncodings(void) {
    static NSArray<NSNumber *> *encodings = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSStringEncoding gb18030 = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
        encodings = @[
            @(NSUTF8StringEncoding),
            @(NSUnicodeStringEncoding),
            @(NSUTF16LittleEndianStringEncoding),
            @(NSUTF16BigEndianStringEncoding),
            @(NSUTF32LittleEndianStringEncoding),
            @(NSUTF32BigEndianStringEncoding),
            @(NSASCIIStringEncoding),
            @(NSISOLatin1StringEncoding),
            @(gb18030),
        ];
    });
    return encodings;
}

static BOOL UCFilzaStringLooksReadable(NSString *string) {
    if (string.length == 0) return YES;
    NSUInteger suspiciousCount = 0;
    for (NSUInteger idx = 0; idx < string.length; idx++) {
        unichar ch = [string characterAtIndex:idx];
        if ((ch < 0x20 && ch != '\n' && ch != '\r' && ch != '\t') || ch == 0xFFFD) {
            suspiciousCount += 1;
        }
    }
    return suspiciousCount <= MAX(2, string.length / 40);
}

static NSString *UCFilzaDecodedStringFromData(NSData *data, NSStringEncoding *encodingOut) {
    if (data.length == 0) {
        if (encodingOut) *encodingOut = NSUTF8StringEncoding;
        return @"";
    }

    for (NSNumber *encodingValue in UCFilzaCandidateEncodings()) {
        NSStringEncoding encoding = encodingValue.unsignedIntegerValue;
        NSString *string = [[NSString alloc] initWithData:data encoding:encoding];
        if (string.length || data.length == 0) {
            if (UCFilzaStringLooksReadable(string ?: @"")) {
                if (encodingOut) *encodingOut = encoding;
                return string ?: @"";
            }
        }
    }

    return nil;
}

static NSString *UCFilzaPrettyJSONStringFromData(NSData *data) {
    if (data.length == 0) return @"";
    id object = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
    if (!object || ![NSJSONSerialization isValidJSONObject:object]) return nil;

    NSJSONWritingOptions options = NSJSONWritingPrettyPrinted;
    if (@available(iOS 11.0, *)) {
        options |= NSJSONWritingSortedKeys;
    }
    NSData *prettyData = [NSJSONSerialization dataWithJSONObject:object options:options error:nil];
    if (!prettyData.length) return nil;
    return [[NSString alloc] initWithData:prettyData encoding:NSUTF8StringEncoding];
}

static NSString *UCFilzaPrettyPropertyListStringFromData(NSData *data, NSPropertyListFormat *formatOut) {
    if (data.length == 0) {
        if (formatOut) *formatOut = NSPropertyListXMLFormat_v1_0;
        return @"";
    }

    NSPropertyListFormat sourceFormat = NSPropertyListXMLFormat_v1_0;
    id plist = [NSPropertyListSerialization propertyListWithData:data
                                                         options:NSPropertyListMutableContainersAndLeaves
                                                          format:&sourceFormat
                                                           error:nil];
    if (!plist) return nil;

    NSData *xmlData = [NSPropertyListSerialization dataWithPropertyList:plist
                                                                 format:NSPropertyListXMLFormat_v1_0
                                                                options:0
                                                                  error:nil];
    if (!xmlData.length) return nil;

    if (formatOut) *formatOut = sourceFormat;
    return [[NSString alloc] initWithData:xmlData encoding:NSUTF8StringEncoding];
}

static uint16_t UCFilzaReadUInt16LE(const uint8_t *bytes) {
    return (uint16_t)(bytes[0] | (bytes[1] << 8));
}

static uint32_t UCFilzaReadUInt32LE(const uint8_t *bytes) {
    return (uint32_t)(bytes[0] | (bytes[1] << 8) | (bytes[2] << 16) | ((uint32_t)bytes[3] << 24));
}

static NSString *UCFilzaStableHexDigestForString(NSString *string) {
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding] ?: NSData.data;
    const uint8_t *bytes = data.bytes;
    uint64_t hash = 1469598103934665603ULL;
    for (NSUInteger idx = 0; idx < data.length; idx++) {
        hash ^= bytes[idx];
        hash *= 1099511628211ULL;
    }
    return [NSString stringWithFormat:@"%016llx", (unsigned long long)hash];
}

static NSString *UCFilzaDecodedZipNameFromData(NSData *data, BOOL isUTF8) {
    if (!data.length) return @"";
    if (isUTF8) {
        NSString *utf8 = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (utf8.length) return utf8;
    }

    NSStringEncoding gb18030 = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
    NSArray<NSNumber *> *encodings = @[@(gb18030), @(NSUTF8StringEncoding), @(NSISOLatin1StringEncoding)];
    for (NSNumber *value in encodings) {
        NSString *string = [[NSString alloc] initWithData:data encoding:value.unsignedIntegerValue];
        if (string.length) return string;
    }
    return nil;
}

static NSString *UCFilzaSanitizedArchivePath(NSString *archivePath) {
    if (archivePath.length == 0) return nil;
    NSString *normalized = [archivePath stringByReplacingOccurrencesOfString:@"\\" withString:@"/"];
    while ([normalized hasPrefix:@"/"]) {
        normalized = [normalized substringFromIndex:1];
    }

    NSArray<NSString *> *components = [normalized componentsSeparatedByString:@"/"];
    NSMutableArray<NSString *> *safeComponents = [NSMutableArray arrayWithCapacity:components.count];
    for (NSString *component in components) {
        if (component.length == 0 || [component isEqualToString:@"."]) continue;
        if ([component isEqualToString:@".."]) return nil;
        [safeComponents addObject:component];
    }
    return [safeComponents componentsJoinedByString:@"/"];
}

static NSString *UCFilzaAssetOverrideRootDirectory(void) {
    NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/ToolsEricAssetOverrides"];
    [NSFileManager.defaultManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    return path;
}

static NSString *UCFilzaAssetOverrideDirectoryForCarPath(NSString *carPath) {
    NSString *name = [NSString stringWithFormat:@"%@_%@", carPath.lastPathComponent.stringByDeletingPathExtension ?: @"assets", UCFilzaStableHexDigestForString(carPath ?: @"")];
    NSString *path = [UCFilzaAssetOverrideRootDirectory() stringByAppendingPathComponent:name];
    [NSFileManager.defaultManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    return path;
}

static NSString *UCFilzaAssetOverrideIndexPathForCarPath(NSString *carPath) {
    return [UCFilzaAssetOverrideDirectoryForCarPath(carPath) stringByAppendingPathComponent:@"index.plist"];
}

static NSMutableDictionary<NSString *, NSString *> *UCFilzaLoadAssetOverrideIndex(NSString *carPath) {
    NSDictionary *dictionary = [NSDictionary dictionaryWithContentsOfFile:UCFilzaAssetOverrideIndexPathForCarPath(carPath)];
    if (![dictionary isKindOfClass:NSDictionary.class]) return [NSMutableDictionary dictionary];
    return [dictionary mutableCopy];
}

static NSString *UCFilzaAssetOverrideImagePath(NSString *carPath, NSString *assetName) {
    if (carPath.length == 0 || assetName.length == 0) return nil;
    NSDictionary<NSString *, NSString *> *index = [NSDictionary dictionaryWithContentsOfFile:UCFilzaAssetOverrideIndexPathForCarPath(carPath)];
    NSString *fileName = index[assetName];
    if (fileName.length == 0) return nil;
    NSString *path = [UCFilzaAssetOverrideDirectoryForCarPath(carPath) stringByAppendingPathComponent:fileName];
    if (![NSFileManager.defaultManager fileExistsAtPath:path]) return nil;
    return path;
}

static BOOL UCFilzaAssetHasOverride(NSString *carPath, NSString *assetName) {
    return UCFilzaAssetOverrideImagePath(carPath, assetName).length > 0;
}

static BOOL UCFilzaSaveAssetOverrideFromURL(NSString *carPath, NSString *assetName, NSURL *sourceURL, NSError **error) {
    if (carPath.length == 0 || assetName.length == 0 || sourceURL == nil) return NO;

    BOOL accessing = [sourceURL respondsToSelector:@selector(startAccessingSecurityScopedResource)] ? [sourceURL startAccessingSecurityScopedResource] : NO;
    NSData *data = [NSData dataWithContentsOfURL:sourceURL options:0 error:error];
    if (accessing) {
        [sourceURL stopAccessingSecurityScopedResource];
    }
    if (!data.length) return NO;

    NSString *extension = sourceURL.path.pathExtension.lowercaseString ?: @"";
    if (extension.length == 0) extension = @"png";

    NSMutableDictionary<NSString *, NSString *> *index = UCFilzaLoadAssetOverrideIndex(carPath);
    NSString *oldFileName = index[assetName];
    NSString *newFileName = [NSString stringWithFormat:@"%@.%@", UCFilzaStableHexDigestForString([NSString stringWithFormat:@"%@|%@", carPath ?: @"", assetName ?: @""]), extension];
    NSString *targetPath = [UCFilzaAssetOverrideDirectoryForCarPath(carPath) stringByAppendingPathComponent:newFileName];

    BOOL written = [data writeToFile:targetPath options:NSDataWritingAtomic error:error];
    if (!written) return NO;

    index[assetName] = newFileName;
    BOOL saved = [index writeToFile:UCFilzaAssetOverrideIndexPathForCarPath(carPath) atomically:YES];
    if (!saved) {
        if (error && *error == nil) {
            *error = [NSError errorWithDomain:@"UCFilzaTool"
                                         code:2001
                                     userInfo:@{NSLocalizedDescriptionKey: @"保存 assets.car 单图替换索引失败。"}];
        }
        return NO;
    }

    if (oldFileName.length && ![oldFileName isEqualToString:newFileName]) {
        NSString *oldPath = [UCFilzaAssetOverrideDirectoryForCarPath(carPath) stringByAppendingPathComponent:oldFileName];
        [NSFileManager.defaultManager removeItemAtPath:oldPath error:nil];
    }
    return YES;
}

static BOOL UCFilzaRemoveAssetOverride(NSString *carPath, NSString *assetName, NSError **error) {
    if (carPath.length == 0 || assetName.length == 0) return NO;

    NSMutableDictionary<NSString *, NSString *> *index = UCFilzaLoadAssetOverrideIndex(carPath);
    NSString *fileName = index[assetName];
    if (fileName.length == 0) return YES;

    NSString *path = [UCFilzaAssetOverrideDirectoryForCarPath(carPath) stringByAppendingPathComponent:fileName];
    [NSFileManager.defaultManager removeItemAtPath:path error:nil];
    [index removeObjectForKey:assetName];
    BOOL saved = [index writeToFile:UCFilzaAssetOverrideIndexPathForCarPath(carPath) atomically:YES];
    if (!saved && error && *error == nil) {
        *error = [NSError errorWithDomain:@"UCFilzaTool"
                                     code:2002
                                 userInfo:@{NSLocalizedDescriptionKey: @"移除 assets.car 单图替换索引失败。"}];
    }
    return saved;
}

static NSString *UCFilzaAssetsCarPathForNameAndBundle(NSString *name, NSBundle *bundle) {
    if (!bundle) return nil;
    NSString *cleanName = name.length ? name : @"Assets";
    NSString *nameWithoutExtension = cleanName.stringByDeletingPathExtension.length ? cleanName.stringByDeletingPathExtension : cleanName;
    NSArray<NSString *> *candidates = @[
        [bundle pathForResource:cleanName ofType:@"car"] ?: @"",
        [bundle pathForResource:nameWithoutExtension ofType:@"car"] ?: @"",
        [bundle pathForResource:@"Assets" ofType:@"car"] ?: @"",
        [bundle.bundlePath stringByAppendingPathComponent:[cleanName hasSuffix:@".car"] ? cleanName : [cleanName stringByAppendingString:@".car"]],
        [bundle.bundlePath stringByAppendingPathComponent:@"Assets.car"],
    ];
    for (NSString *candidate in candidates) {
        if (candidate.length && [NSFileManager.defaultManager fileExistsAtPath:candidate]) {
            return candidate.stringByStandardizingPath ?: candidate;
        }
    }
    return nil;
}

static NSString *UCFilzaHexStringFromData(NSData *data) {
    if (data.length == 0) return @"";

    const unsigned char *bytes = data.bytes;
    NSMutableString *result = [NSMutableString stringWithCapacity:data.length * 3];
    for (NSUInteger idx = 0; idx < data.length; idx++) {
        [result appendFormat:@"%02X", bytes[idx]];
        if (idx + 1 < data.length) {
            if ((idx + 1) % 16 == 0) {
                [result appendString:@"\n"];
            } else {
                [result appendString:@" "];
            }
        }
    }
    return result;
}

static NSData *UCFilzaDataFromHexString(NSString *hexString, NSError **error) {
    NSMutableString *filtered = [NSMutableString stringWithCapacity:hexString.length];
    NSCharacterSet *hexCharacters = [NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdefABCDEF"];
    for (NSUInteger idx = 0; idx < hexString.length; idx++) {
        unichar ch = [hexString characterAtIndex:idx];
        if ([hexCharacters characterIsMember:ch]) {
            [filtered appendFormat:@"%C", ch];
        }
    }

    if (filtered.length % 2 != 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"UCFilzaTool"
                                         code:1001
                                     userInfo:@{NSLocalizedDescriptionKey: @"十六进制内容长度不正确，请检查是否缺少半个字节。"}];
        }
        return nil;
    }

    NSMutableData *data = [NSMutableData dataWithCapacity:filtered.length / 2];
    unsigned value = 0;
    for (NSUInteger idx = 0; idx < filtered.length; idx += 2) {
        NSString *byteString = [filtered substringWithRange:NSMakeRange(idx, 2)];
        NSScanner *scanner = [NSScanner scannerWithString:byteString];
        if (![scanner scanHexInt:&value]) {
            if (error) {
                *error = [NSError errorWithDomain:@"UCFilzaTool"
                                             code:1002
                                         userInfo:@{NSLocalizedDescriptionKey: @"十六进制内容包含无法识别的字符。"}];
            }
            return nil;
        }
        unsigned char byte = (unsigned char)value;
        [data appendBytes:&byte length:1];
    }

    return data;
}

@interface UCFilzaEditorViewController : UIViewController

- (instancetype)initWithFilePath:(NSString *)filePath;

@end

@interface UCFilzaQuickLookPreviewController : QLPreviewController <QLPreviewControllerDataSource>

- (instancetype)initWithFilePath:(NSString *)filePath;

@end

@interface UCFilzaCarManagerViewController : UIViewController <UIDocumentPickerDelegate>

- (instancetype)initWithFilePath:(NSString *)filePath;

@end

@interface UCFilzaCarAssetListViewController : UITableViewController <UISearchResultsUpdating>

- (instancetype)initWithFilePath:(NSString *)filePath;

@end

@interface UCFilzaCarAssetGridCell : UICollectionViewCell

- (void)configureWithTitle:(NSString *)title subtitle:(NSString *)subtitle image:(UIImage *)image highlighted:(BOOL)highlighted;

@end

@interface UCFilzaCarAssetGridViewController : UIViewController <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UISearchResultsUpdating>

- (instancetype)initWithFilePath:(NSString *)filePath;

@end

@interface UCFilzaCarAssetDetailViewController : UIViewController <UIDocumentPickerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>

- (instancetype)initWithFilePath:(NSString *)filePath assetName:(NSString *)assetName;

@end

@interface UCFilzaZipEntry : NSObject

@property (nonatomic, copy) NSString *archivePath;
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, assign) BOOL isDirectory;
@property (nonatomic, assign) BOOL isEncrypted;
@property (nonatomic, assign) uint16_t compressionMethod;
@property (nonatomic, assign) uint32_t compressedSize;
@property (nonatomic, assign) uint32_t uncompressedSize;
@property (nonatomic, assign) uint32_t localHeaderOffset;

@end

@interface UCFilzaZipArchive : NSObject

@property (nonatomic, copy, readonly) NSString *filePath;
@property (nonatomic, copy, readonly) NSArray<UCFilzaZipEntry *> *entries;

- (instancetype)initWithFilePath:(NSString *)filePath error:(NSError **)error;
- (NSArray<UCFilzaZipEntry *> *)entriesForPrefix:(NSString *)prefix;
- (NSData *)dataForEntry:(UCFilzaZipEntry *)entry error:(NSError **)error;
- (NSString *)temporaryPathForEntry:(UCFilzaZipEntry *)entry error:(NSError **)error;
- (NSString *)extractEntriesWithPrefix:(NSString *)prefix error:(NSError **)error;

@end

@interface UCFilzaZipBrowserViewController : UITableViewController <UISearchResultsUpdating>

- (instancetype)initWithZipPath:(NSString *)zipPath title:(NSString *)title prefix:(NSString *)prefix archive:(UCFilzaZipArchive *)archive;

@end

@interface UCFilzaBrowserViewController : UITableViewController <UISearchResultsUpdating>

- (instancetype)initWithDirectoryPath:(NSString *)directoryPath title:(NSString *)title;

@end

@interface UCFilzaAppInfoViewController : UITableViewController
@end

@interface UCFilzaRootViewController : UITableViewController
@end

@interface UCFilzaRootViewController ()

@property (nonatomic, copy) NSArray<NSDictionary<NSString *, NSString *> *> *rootEntries;
@property (nonatomic, copy) NSArray<NSDictionary<NSString *, NSString *> *> *quickPathEntries;
@property (nonatomic, copy) NSArray<NSDictionary<NSString *, NSString *> *> *appGroupEntries;
@property (nonatomic, copy) NSArray<NSDictionary<NSString *, NSString *> *> *toolEntries;

@end

static uint64_t UCFilzaDirectorySize(NSString *path) {
    NSFileManager *fm = NSFileManager.defaultManager;
    BOOL isDir = NO;
    if (![fm fileExistsAtPath:path isDirectory:&isDir] || !isDir) return 0;
    
    uint64_t totalSize = 0;
    NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath:path];
    for (NSString *file in enumerator) {
        NSString *fullPath = [path stringByAppendingPathComponent:file];
        NSError *error = nil;
        NSDictionary *attrs = [fm attributesOfItemAtPath:fullPath error:&error];
        if (!error && attrs) {
            totalSize += attrs.fileSize;
        }
    }
    return totalSize;
}

static UIViewController *UCFilzaViewControllerForPath(NSString *path, NSString *titleOverride) {
    NSString *normalizedPath = path.stringByStandardizingPath ?: path;
    if (normalizedPath.length == 0) return nil;

    if (UCFilzaPathIsDirectory(normalizedPath)) {
        return [[UCFilzaBrowserViewController alloc] initWithDirectoryPath:normalizedPath title:titleOverride ?: normalizedPath.lastPathComponent];
    }
    if (UCFilzaIsAssetsCarPath(normalizedPath)) {
        return [[UCFilzaCarManagerViewController alloc] initWithFilePath:normalizedPath];
    }
    if (UCFilzaIsSQLitePath(normalizedPath)) {
        return [[FLEXTableListViewController alloc] initWithPath:normalizedPath];
    }
    if (UCFilzaIsZIPPath(normalizedPath)) {
        return [[UCFilzaZipBrowserViewController alloc] initWithZipPath:normalizedPath title:titleOverride ?: normalizedPath.lastPathComponent prefix:@"" archive:nil];
    }
    if (UCFilzaShouldUseQuickLookPreview(normalizedPath)) {
        return [[UCFilzaQuickLookPreviewController alloc] initWithFilePath:normalizedPath];
    }
    return [[UCFilzaEditorViewController alloc] initWithFilePath:normalizedPath];
}

static const void *UCFilzaCatalogPathAssociationKey = &UCFilzaCatalogPathAssociationKey;
static const void *UCFilzaNamedImageAssetNameAssociationKey = &UCFilzaNamedImageAssetNameAssociationKey;
static const void *UCFilzaNamedImageCatalogPathAssociationKey = &UCFilzaNamedImageCatalogPathAssociationKey;
static const void *UCFilzaNamedImageOverrideImageAssociationKey = &UCFilzaNamedImageOverrideImageAssociationKey;
static id (*UCFilzaOriginalCatalogInitWithURLErrorIMP)(id, SEL, NSURL *, NSError **);
static id (*UCFilzaOriginalCatalogInitWithNameFromBundleErrorIMP)(id, SEL, NSString *, NSBundle *, NSError **);
static id (*UCFilzaOriginalCatalogInitWithNameFromBundleIMP)(id, SEL, NSString *, NSBundle *);
static id (*UCFilzaOriginalCatalogImageWithNameScaleIMP)(id, SEL, NSString *, CGFloat);
static id (*UCFilzaOriginalCatalogImageWithNameScaleAppearanceIMP)(id, SEL, NSString *, CGFloat, NSString *);
static CGImageRef (*UCFilzaOriginalNamedImageImageIMP)(id, SEL);
static CGImageRef (*UCFilzaOriginalNamedImageCroppedImageIMP)(id, SEL);
static CGImageRef (*UCFilzaOriginalNamedImageUnslicedImageIMP)(id, SEL);

static NSString *UCFilzaAssociatedCatalogPath(id catalog) {
    return objc_getAssociatedObject(catalog, UCFilzaCatalogPathAssociationKey);
}

static void UCFilzaAssociateCatalogPath(id catalog, NSString *path) {
    if (catalog && path.length) {
        objc_setAssociatedObject(catalog, UCFilzaCatalogPathAssociationKey, path.stringByStandardizingPath ?: path, OBJC_ASSOCIATION_COPY_NONATOMIC);
    }
}

static Class UCFilzaCUINamedImageClass(void) {
    static Class namedImageClass = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dlopen("/System/Library/PrivateFrameworks/CoreUI.framework/CoreUI", RTLD_LAZY);
        namedImageClass = NSClassFromString(@"CUINamedImage");
    });
    return namedImageClass;
}

static NSString *UCFilzaAssociatedNamedImageAssetName(id object) {
    return objc_getAssociatedObject(object, UCFilzaNamedImageAssetNameAssociationKey);
}

static NSString *UCFilzaAssociatedNamedImageCatalogPath(id object) {
    return objc_getAssociatedObject(object, UCFilzaNamedImageCatalogPathAssociationKey);
}

static void UCFilzaAssociateNamedImageInfo(id object, NSString *assetName, NSString *carPath) {
    if (!object) return;
    if (assetName.length) {
        objc_setAssociatedObject(object, UCFilzaNamedImageAssetNameAssociationKey, assetName, OBJC_ASSOCIATION_COPY_NONATOMIC);
    }
    if (carPath.length) {
        objc_setAssociatedObject(object, UCFilzaNamedImageCatalogPathAssociationKey, carPath.stringByStandardizingPath ?: carPath, OBJC_ASSOCIATION_COPY_NONATOMIC);
    }
}

static Class UCFilzaCUICatalogClass(void) {
    static Class catalogClass = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dlopen("/System/Library/PrivateFrameworks/CoreUI.framework/CoreUI", RTLD_LAZY);
        catalogClass = NSClassFromString(@"CUICatalog");
    });
    return catalogClass;
}

static id UCFilzaCreateCatalogForFilePath(NSString *filePath, NSError **error) {
    Class catalogClass = UCFilzaCUICatalogClass();
    if (!catalogClass || filePath.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"UCFilzaTool"
                                         code:2003
                                     userInfo:@{NSLocalizedDescriptionKey: @"当前系统无法打开 assets.car 目录内容。"}];
        }
        return nil;
    }

    SEL selector = @selector(initWithURL:error:);
    if (![catalogClass instancesRespondToSelector:selector]) {
        if (error) {
            *error = [NSError errorWithDomain:@"UCFilzaTool"
                                         code:2004
                                     userInfo:@{NSLocalizedDescriptionKey: @"当前系统未暴露 assets.car 浏览接口。"}];
        }
        return nil;
    }

    id instance = ((id (*)(id, SEL))objc_msgSend)(catalogClass, @selector(alloc));
    NSURL *url = [NSURL fileURLWithPath:filePath];
    return ((id (*)(id, SEL, NSURL *, NSError **))objc_msgSend)(instance, selector, url, error);
}

static NSArray<NSString *> *UCFilzaCatalogAllImageNames(id catalog) {
    if (!catalog || ![catalog respondsToSelector:@selector(allImageNames)]) return @[];
    id names = ((id (*)(id, SEL))objc_msgSend)(catalog, @selector(allImageNames));
    if (![names isKindOfClass:NSArray.class]) return @[];
    NSMutableArray<NSString *> *result = [NSMutableArray array];
    for (id object in (NSArray *)names) {
        if ([object isKindOfClass:NSString.class] && ((NSString *)object).length > 0) {
            [result addObject:object];
        }
    }
    return [result sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

static id UCFilzaRawCatalogImageObject(id catalog, NSString *assetName, CGFloat scale, NSString *appearanceName) {
    if (!catalog || assetName.length == 0) return nil;
    NSString *carPath = UCFilzaAssociatedCatalogPath(catalog);
    id object = nil;
    if (appearanceName.length && UCFilzaOriginalCatalogImageWithNameScaleAppearanceIMP) {
        object = UCFilzaOriginalCatalogImageWithNameScaleAppearanceIMP(catalog, @selector(imageWithName:scaleFactor:appearanceName:), assetName, scale, appearanceName);
    } else if (UCFilzaOriginalCatalogImageWithNameScaleIMP) {
        object = UCFilzaOriginalCatalogImageWithNameScaleIMP(catalog, @selector(imageWithName:scaleFactor:), assetName, scale);
    } else if ([catalog respondsToSelector:@selector(imageWithName:scaleFactor:)]) {
        object = ((id (*)(id, SEL, NSString *, CGFloat))objc_msgSend)(catalog, @selector(imageWithName:scaleFactor:), assetName, scale);
    }
    if (object) {
        UCFilzaAssociateNamedImageInfo(object, assetName, carPath);
    }
    return object;
}

static CGFloat UCFilzaCatalogImageObjectScale(id object, CGFloat fallbackScale) {
    if (object && [object respondsToSelector:@selector(scale)]) {
        CGFloat value = ((CGFloat (*)(id, SEL))objc_msgSend)(object, @selector(scale));
        if (value > 0.0) return value;
    }
    return fallbackScale > 0.0 ? fallbackScale : 1.0;
}

static BOOL UCFilzaCatalogImageObjectIsTemplate(id object) {
    if (!object || ![object respondsToSelector:@selector(isTemplate)]) return NO;
    return ((BOOL (*)(id, SEL))objc_msgSend)(object, @selector(isTemplate));
}

static CGImageRef UCFilzaCatalogImageObjectCGImage(id object, CGFloat scale, BOOL preferOriginalMethods) {
    if (!object) return nil;
    if ([object isKindOfClass:UIImage.class]) {
        return ((UIImage *)object).CGImage;
    }

    CGImageRef imageRef = nil;
    if (preferOriginalMethods) {
        if (!imageRef && UCFilzaOriginalNamedImageImageIMP && [object respondsToSelector:@selector(image)]) {
            imageRef = UCFilzaOriginalNamedImageImageIMP(object, @selector(image));
        }
        if (!imageRef && UCFilzaOriginalNamedImageCroppedImageIMP && [object respondsToSelector:@selector(croppedImage)]) {
            imageRef = UCFilzaOriginalNamedImageCroppedImageIMP(object, @selector(croppedImage));
        }
        if (!imageRef && UCFilzaOriginalNamedImageUnslicedImageIMP && [object respondsToSelector:@selector(unslicedImage)]) {
            imageRef = UCFilzaOriginalNamedImageUnslicedImageIMP(object, @selector(unslicedImage));
        }
    } else {
        if (!imageRef && [object respondsToSelector:@selector(image)]) {
            imageRef = ((CGImageRef (*)(id, SEL))objc_msgSend)(object, @selector(image));
        }
        if (!imageRef && [object respondsToSelector:@selector(croppedImage)]) {
            imageRef = ((CGImageRef (*)(id, SEL))objc_msgSend)(object, @selector(croppedImage));
        }
        if (!imageRef && [object respondsToSelector:@selector(unslicedImage)]) {
            imageRef = ((CGImageRef (*)(id, SEL))objc_msgSend)(object, @selector(unslicedImage));
        }
    }

    if (!imageRef && [object respondsToSelector:@selector(createImageFromPDFRenditionWithScale:)]) {
        imageRef = ((CGImageRef (*)(id, SEL, CGFloat))objc_msgSend)(object, @selector(createImageFromPDFRenditionWithScale:), scale > 0.0 ? scale : 1.0);
    }
    return imageRef;
}

static UIImage *UCFilzaRenderableImageFromCatalogImageObject(id object, CGFloat preferredScale, BOOL preferOriginalMethods) {
    if (!object) return nil;
    if ([object isKindOfClass:UIImage.class]) {
        return (UIImage *)object;
    }

    CGFloat scale = UCFilzaCatalogImageObjectScale(object, preferredScale);
    CGImageRef imageRef = UCFilzaCatalogImageObjectCGImage(object, scale, preferOriginalMethods);
    if (!imageRef) return nil;

    UIImage *image = [UIImage imageWithCGImage:imageRef scale:scale orientation:UIImageOrientationUp];
    if (image && UCFilzaCatalogImageObjectIsTemplate(object)) {
        image = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    return image;
}

static UIImage *UCFilzaOriginalCatalogImage(id catalog, NSString *assetName, CGFloat scale, NSString *appearanceName) {
    id object = UCFilzaRawCatalogImageObject(catalog, assetName, scale, appearanceName);
    return UCFilzaRenderableImageFromCatalogImageObject(object, scale, YES);
}

static UIImage *UCFilzaOverrideImageForCatalogPathAndAssetName(NSString *carPath, NSString *assetName) {
    NSString *overridePath = UCFilzaAssetOverrideImagePath(carPath, assetName);
    if (overridePath.length == 0) return nil;
    return [UIImage imageWithContentsOfFile:overridePath];
}

static UIImage *UCFilzaEffectiveCatalogImage(id catalog, NSString *carPath, NSString *assetName, CGFloat scale, NSString *appearanceName) {
    UIImage *overrideImage = UCFilzaOverrideImageForCatalogPathAndAssetName(carPath, assetName);
    if (overrideImage) return overrideImage;
    id object = UCFilzaRawCatalogImageObject(catalog, assetName, scale, appearanceName);
    return UCFilzaRenderableImageFromCatalogImageObject(object, scale, NO);
}

static UIImage *UCFilzaAssociatedOrLoadOverrideImageForNamedImage(id object) {
    if (!object) return nil;
    UIImage *cached = objc_getAssociatedObject(object, UCFilzaNamedImageOverrideImageAssociationKey);
    if (cached) return cached;

    NSString *carPath = UCFilzaAssociatedNamedImageCatalogPath(object);
    NSString *assetName = UCFilzaAssociatedNamedImageAssetName(object);
    UIImage *loaded = UCFilzaOverrideImageForCatalogPathAndAssetName(carPath, assetName);
    if (loaded) {
        objc_setAssociatedObject(object, UCFilzaNamedImageOverrideImageAssociationKey, loaded, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return loaded;
}

static void UCFilzaSwizzleInstanceMethodIfNeeded(Class cls, SEL selector, IMP replacement, IMP *originalStorage) {
    Method method = class_getInstanceMethod(cls, selector);
    if (!method) return;
    IMP original = method_getImplementation(method);
    if (originalStorage) *originalStorage = original;
    method_setImplementation(method, replacement);
}

static id UCFilzaHook_CUICatalog_initWithURL_error(id self, SEL _cmd, NSURL *url, NSError **error) {
    id catalog = UCFilzaOriginalCatalogInitWithURLErrorIMP ? UCFilzaOriginalCatalogInitWithURLErrorIMP(self, _cmd, url, error) : self;
    if (catalog && url.path.length) {
        UCFilzaAssociateCatalogPath(catalog, url.path);
    }
    return catalog;
}

static id UCFilzaHook_CUICatalog_initWithName_fromBundle_error(id self, SEL _cmd, NSString *name, NSBundle *bundle, NSError **error) {
    id catalog = UCFilzaOriginalCatalogInitWithNameFromBundleErrorIMP ? UCFilzaOriginalCatalogInitWithNameFromBundleErrorIMP(self, _cmd, name, bundle, error) : self;
    NSString *carPath = UCFilzaAssetsCarPathForNameAndBundle(name, bundle);
    if (catalog && carPath.length) {
        UCFilzaAssociateCatalogPath(catalog, carPath);
    }
    return catalog;
}

static id UCFilzaHook_CUICatalog_initWithName_fromBundle(id self, SEL _cmd, NSString *name, NSBundle *bundle) {
    id catalog = UCFilzaOriginalCatalogInitWithNameFromBundleIMP ? UCFilzaOriginalCatalogInitWithNameFromBundleIMP(self, _cmd, name, bundle) : self;
    NSString *carPath = UCFilzaAssetsCarPathForNameAndBundle(name, bundle);
    if (catalog && carPath.length) {
        UCFilzaAssociateCatalogPath(catalog, carPath);
    }
    return catalog;
}

static id UCFilzaHook_CUICatalog_imageWithName_scaleFactor(id self, SEL _cmd, NSString *name, CGFloat scale) {
    id object = UCFilzaOriginalCatalogImageWithNameScaleIMP ? UCFilzaOriginalCatalogImageWithNameScaleIMP(self, _cmd, name, scale) : nil;
    NSString *carPath = UCFilzaAssociatedCatalogPath(self);
    UCFilzaAssociateNamedImageInfo(object, name, carPath);
    return object;
}

static id UCFilzaHook_CUICatalog_imageWithName_scaleFactor_appearanceName(id self, SEL _cmd, NSString *name, CGFloat scale, NSString *appearanceName) {
    id object = UCFilzaOriginalCatalogImageWithNameScaleAppearanceIMP ? UCFilzaOriginalCatalogImageWithNameScaleAppearanceIMP(self, _cmd, name, scale, appearanceName) : nil;
    NSString *carPath = UCFilzaAssociatedCatalogPath(self);
    UCFilzaAssociateNamedImageInfo(object, name, carPath);
    return object;
}

static CGImageRef UCFilzaHook_CUINamedImage_image(id self, SEL _cmd) {
    UIImage *overrideImage = UCFilzaAssociatedOrLoadOverrideImageForNamedImage(self);
    if (overrideImage.CGImage) return overrideImage.CGImage;
    return UCFilzaOriginalNamedImageImageIMP ? UCFilzaOriginalNamedImageImageIMP(self, _cmd) : nil;
}

static CGImageRef UCFilzaHook_CUINamedImage_croppedImage(id self, SEL _cmd) {
    UIImage *overrideImage = UCFilzaAssociatedOrLoadOverrideImageForNamedImage(self);
    if (overrideImage.CGImage) return overrideImage.CGImage;
    return UCFilzaOriginalNamedImageCroppedImageIMP ? UCFilzaOriginalNamedImageCroppedImageIMP(self, _cmd) : nil;
}

static CGImageRef UCFilzaHook_CUINamedImage_unslicedImage(id self, SEL _cmd) {
    UIImage *overrideImage = UCFilzaAssociatedOrLoadOverrideImageForNamedImage(self);
    if (overrideImage.CGImage) return overrideImage.CGImage;
    return UCFilzaOriginalNamedImageUnslicedImageIMP ? UCFilzaOriginalNamedImageUnslicedImageIMP(self, _cmd) : nil;
}

static void UCFilzaInstallCoreUIHooks(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class catalogClass = UCFilzaCUICatalogClass();
        if (!catalogClass) return;
        Class namedImageClass = UCFilzaCUINamedImageClass();

        UCFilzaSwizzleInstanceMethodIfNeeded(catalogClass, @selector(initWithURL:error:), (IMP)UCFilzaHook_CUICatalog_initWithURL_error, (IMP *)&UCFilzaOriginalCatalogInitWithURLErrorIMP);
        UCFilzaSwizzleInstanceMethodIfNeeded(catalogClass, @selector(initWithName:fromBundle:error:), (IMP)UCFilzaHook_CUICatalog_initWithName_fromBundle_error, (IMP *)&UCFilzaOriginalCatalogInitWithNameFromBundleErrorIMP);
        UCFilzaSwizzleInstanceMethodIfNeeded(catalogClass, @selector(initWithName:fromBundle:), (IMP)UCFilzaHook_CUICatalog_initWithName_fromBundle, (IMP *)&UCFilzaOriginalCatalogInitWithNameFromBundleIMP);
        UCFilzaSwizzleInstanceMethodIfNeeded(catalogClass, @selector(imageWithName:scaleFactor:), (IMP)UCFilzaHook_CUICatalog_imageWithName_scaleFactor, (IMP *)&UCFilzaOriginalCatalogImageWithNameScaleIMP);
        UCFilzaSwizzleInstanceMethodIfNeeded(catalogClass, @selector(imageWithName:scaleFactor:appearanceName:), (IMP)UCFilzaHook_CUICatalog_imageWithName_scaleFactor_appearanceName, (IMP *)&UCFilzaOriginalCatalogImageWithNameScaleAppearanceIMP);
        if (namedImageClass) {
            UCFilzaSwizzleInstanceMethodIfNeeded(namedImageClass, @selector(image), (IMP)UCFilzaHook_CUINamedImage_image, (IMP *)&UCFilzaOriginalNamedImageImageIMP);
            UCFilzaSwizzleInstanceMethodIfNeeded(namedImageClass, @selector(croppedImage), (IMP)UCFilzaHook_CUINamedImage_croppedImage, (IMP *)&UCFilzaOriginalNamedImageCroppedImageIMP);
            UCFilzaSwizzleInstanceMethodIfNeeded(namedImageClass, @selector(unslicedImage), (IMP)UCFilzaHook_CUINamedImage_unslicedImage, (IMP *)&UCFilzaOriginalNamedImageUnslicedImageIMP);
        }
    });
}

@implementation UCFilzaRootViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Filza文件";
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.tableView.sectionHeaderTopPadding = 0;
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemClose
                             target:self
                             action:@selector(closeTapped)];

    NSString *bundlePath = NSBundle.mainBundle.bundlePath.stringByStandardizingPath ?: @"";
    NSString *homePath = NSHomeDirectory().stringByStandardizingPath ?: @"";
    NSString *docsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject.stringByStandardizingPath ?: @"";
    NSString *libPath = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).firstObject.stringByStandardizingPath ?: @"";
    NSString *cachePath = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject.stringByStandardizingPath ?: @"";
    NSString *tmpPath = NSTemporaryDirectory().stringByStandardizingPath ?: @"";

    self.rootEntries = @[
        @{@"title": @"App 目录", @"subtitle": bundlePath, @"path": bundlePath, @"icon": @"app.badge"},
        @{@"title": @"数据目录", @"subtitle": homePath, @"path": homePath, @"icon": @"folder"},
    ];

    self.quickPathEntries = @[
        @{@"title": @"Documents", @"subtitle": docsPath, @"path": docsPath, @"icon": @"doc.text"},
        @{@"title": @"Library", @"subtitle": libPath, @"path": libPath, @"icon": @"books.vertical"},
        @{@"title": @"Caches", @"subtitle": cachePath, @"path": cachePath, @"icon": @"tray"},
        @{@"title": @"tmp", @"subtitle": tmpPath, @"path": tmpPath, @"icon": @"clock"},
    ];

    self.appGroupEntries = [UCAppGroupHelper accessibleAppGroups] ?: @[];

    self.toolEntries = @[
        @{@"title": @"应用信息", @"subtitle": @"查看应用详情、存储信息", @"action": @"appInfo", @"icon": @"info.circle"},
        @{@"title": @"清除缓存", @"subtitle": @"清除 Caches 和 tmp 目录", @"action": @"clearCache", @"icon": @"trash"},
    ];

    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"rootCell"];
}

- (void)closeTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 4;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return self.rootEntries.count;
    if (section == 1) return self.quickPathEntries.count;
    if (section == 2) return MAX(self.appGroupEntries.count, 1);
    if (section == 3) return self.toolEntries.count;
    return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return @"基础目录";
    if (section == 1) return @"快捷路径";
    if (section == 2) return @"应用组目录";
    if (section == 3) return @"工具";
    return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) {
        return @"支持读取 App 目录、数据目录、应用组目录下文件；图片 / 音频 / PDF / 视频专门预览；assets.car 内容浏览与单图替换；sqlite 直接查看编辑；zip 直接浏览与解压。";
    }
    if (section == 2) {
        return UCFilzaJoinedPathSummary(self.appGroupEntries);
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"rootCell"];
    if (!cell || cell.detailTextLabel == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"rootCell"];
    }
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.textLabel.numberOfLines = 1;
    cell.detailTextLabel.numberOfLines = 2;
    cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    cell.textLabel.textColor = UIColor.labelColor;
    cell.userInteractionEnabled = YES;

    NSDictionary<NSString *, NSString *> *entry = nil;

    if (indexPath.section == 0) {
        entry = self.rootEntries[indexPath.row];
        cell.textLabel.text = entry[@"title"];
        cell.detailTextLabel.text = entry[@"subtitle"];
    } else if (indexPath.section == 1) {
        entry = self.quickPathEntries[indexPath.row];
        cell.textLabel.text = entry[@"title"];
        cell.detailTextLabel.text = entry[@"subtitle"];
    } else if (indexPath.section == 2) {
        if (self.appGroupEntries.count > 0) {
            entry = self.appGroupEntries[indexPath.row];
            cell.textLabel.text = entry[@"identifier"] ?: @"应用组目录";
            cell.detailTextLabel.text = entry[@"path"];
        } else {
            cell.textLabel.text = @"未发现可访问的应用组目录";
            cell.detailTextLabel.text = @"当前 App 没有声明应用组，或当前进程无法访问。";
            cell.userInteractionEnabled = NO;
            cell.textLabel.textColor = UIColor.secondaryLabelColor;
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
    } else if (indexPath.section == 3) {
        entry = self.toolEntries[indexPath.row];
        cell.textLabel.text = entry[@"title"];
        cell.detailTextLabel.text = entry[@"subtitle"];
        if ([entry[@"action"] isEqualToString:@"clearCache"]) {
            cell.textLabel.textColor = UIColor.systemRedColor;
        }
    }

    if (@available(iOS 13.0, *)) {
        NSString *symbolName = entry[@"icon"];
        if (!symbolName) {
            if (indexPath.section == 2) {
                symbolName = @"person.2";
            } else {
                symbolName = @"folder";
            }
        }
        UIImage *image = [UIImage systemImageNamed:symbolName];
        if (image) {
            cell.imageView.image = image;
            if ([entry[@"action"] isEqualToString:@"clearCache"]) {
                cell.imageView.tintColor = UIColor.systemRedColor;
            } else if ([entry[@"action"] isEqualToString:@"appInfo"]) {
                cell.imageView.tintColor = UIColor.systemBlueColor;
            } else {
                cell.imageView.tintColor = UIColor.systemBlueColor;
            }
        }
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    NSDictionary<NSString *, NSString *> *entry = nil;
    NSString *title = nil;
    NSString *action = nil;

    if (indexPath.section == 0) {
        entry = self.rootEntries[indexPath.row];
        title = entry[@"title"];
    } else if (indexPath.section == 1) {
        entry = self.quickPathEntries[indexPath.row];
        title = entry[@"title"];
    } else if (indexPath.section == 2) {
        if (self.appGroupEntries.count > 0) {
            entry = self.appGroupEntries[indexPath.row];
            title = entry[@"identifier"] ?: @"应用组目录";
        }
    } else if (indexPath.section == 3) {
        entry = self.toolEntries[indexPath.row];
        action = entry[@"action"];
    }

    if (action.length > 0) {
        if ([action isEqualToString:@"appInfo"]) {
            [self showAppInfo];
        } else if ([action isEqualToString:@"clearCache"]) {
            [self confirmClearCache];
        }
        return;
    }

    NSString *path = entry[@"path"];
    if (!path.length) return;

    UIViewController *controller = UCFilzaViewControllerForPath(path, title ?: path.lastPathComponent);
    if (controller) {
        [self.navigationController pushViewController:controller animated:YES];
    }
}

- (void)showAppInfo {
    UCFilzaAppInfoViewController *appInfoVC = [[UCFilzaAppInfoViewController alloc] initWithStyle:UITableViewStyleInsetGrouped];
    [self.navigationController pushViewController:appInfoVC animated:YES];
}

- (void)confirmClearCache {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"清除缓存"
                                                                   message:@"确定要清除 Caches 和 tmp 目录下的所有文件吗？此操作不可撤销。"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"清除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [self clearCache];
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)clearCache {
    NSString *cachePath = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
    NSString *tmpPath = NSTemporaryDirectory();
    
    NSFileManager *fm = NSFileManager.defaultManager;
    NSError *error = nil;
    NSUInteger clearedCount = 0;
    
    for (NSString *dirPath in @[cachePath, tmpPath]) {
        if (dirPath.length == 0) continue;
        NSArray *contents = [fm contentsOfDirectoryAtPath:dirPath error:&error];
        if (!contents) continue;
        
        for (NSString *item in contents) {
            NSString *fullPath = [dirPath stringByAppendingPathComponent:item];
            [fm removeItemAtPath:fullPath error:nil];
            clearedCount++;
        }
    }
    
    UCFilzaPresentTransientMessage(self, @"已清除", [NSString stringWithFormat:@"已清除 %lu 个文件", (unsigned long)clearedCount]);
}

@end

@interface UCFilzaListViewController : UITableViewController
@property (nonatomic, copy) NSString *listTitle;
@property (nonatomic, copy) NSArray<NSDictionary<NSString *, NSString *> *> *items;
+ (instancetype)controllerWithTitle:(NSString *)title items:(NSArray<NSDictionary<NSString *, NSString *> *> *)items;
@end

@implementation UCFilzaListViewController

+ (instancetype)controllerWithTitle:(NSString *)title items:(NSArray<NSDictionary<NSString *, NSString *> *> *)items {
    UCFilzaListViewController *vc = [[UCFilzaListViewController alloc] initWithStyle:UITableViewStyleInsetGrouped];
    vc.listTitle = title;
    vc.items = items ?: @[];
    return vc;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.listTitle;
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 44;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"ListCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];
    }
    NSDictionary *item = self.items[indexPath.row];
    cell.textLabel.text = item[@"title"];
    cell.detailTextLabel.text = item[@"subtitle"];
    cell.detailTextLabel.numberOfLines = 0;
    cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

@end

static NSArray<NSDictionary<NSString *, NSString *> *> *UCFilzaLoadedDylibsList(void) {
    NSMutableArray *list = [NSMutableArray array];
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (name) {
            NSString *path = [NSString stringWithUTF8String:name];
            [list addObject:@{
                @"title": path.lastPathComponent,
                @"subtitle": path.stringByDeletingLastPathComponent
            }];
        }
    }
    NSSortDescriptor *sort = [NSSortDescriptor sortDescriptorWithKey:@"title" ascending:YES selector:@selector(caseInsensitiveCompare:)];
    return [list sortedArrayUsingDescriptors:@[sort]];
}

static NSArray<NSDictionary<NSString *, NSString *> *> *UCFilzaEnvironmentList(void) {
    NSMutableArray *list = [NSMutableArray array];
    NSDictionary *env = NSProcessInfo.processInfo.environment;
    NSArray *sortedKeys = [env.allKeys sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    for (NSString *key in sortedKeys) {
        [list addObject:@{
            @"title": key,
            @"subtitle": env[key] ?: @""
        }];
    }
    return list.copy;
}

static NSArray<NSDictionary<NSString *, NSString *> *> *UCFilzaArgumentsList(void) {
    NSMutableArray *list = [NSMutableArray array];
    NSArray *args = NSProcessInfo.processInfo.arguments;
    for (NSUInteger i = 0; i < args.count; i++) {
        [list addObject:@{
            @"title": [NSString stringWithFormat:@"argv[%lu]", (unsigned long)i],
            @"subtitle": args[i]
        }];
    }
    return list.copy;
}

static NSDictionary *UCFilzaObjCRuntimeStats(void) {
    unsigned int classCount = 0;
    Class *classes = objc_copyClassList(&classCount);
    
    unsigned int totalMethods = 0;
    unsigned int totalProtocols = 0;
    
    for (unsigned int i = 0; i < classCount; i++) {
        unsigned int methodCount = 0;
        Method *methods = class_copyMethodList(classes[i], &methodCount);
        totalMethods += methodCount;
        if (methods) free(methods);
        
        unsigned int metaclass = class_isMetaClass(classes[i]);
        if (!metaclass) {
            Class metaClass = objc_getMetaClass(class_getName(classes[i]));
            if (metaClass) {
                unsigned int metaMethodCount = 0;
                Method *metaMethods = class_copyMethodList(metaClass, &metaMethodCount);
                totalMethods += metaMethodCount;
                if (metaMethods) free(metaMethods);
            }
        }
    }
    
    if (classes) free(classes);
    
    unsigned int protoCount = 0;
    Protocol * const *protocols = objc_copyProtocolList(&protoCount);
    totalProtocols = protoCount;
    if (protocols) free((void *)protocols);
    
    return @{
        @"classes": @(classCount),
        @"methods": @(totalMethods),
        @"protocols": @(totalProtocols),
        @"dylibs": @(_dyld_image_count())
    };
}

static NSArray<NSDictionary<NSString *, NSString *> *> *UCFilzaURLSchemesList(void) {
    NSMutableArray *list = [NSMutableArray array];
    NSArray *urlTypes = NSBundle.mainBundle.infoDictionary[@"CFBundleURLTypes"];
    for (NSDictionary *type in urlTypes) {
        NSString *name = type[@"CFBundleURLName"] ?: @"";
        NSArray *schemes = type[@"CFBundleURLSchemes"] ?: @[];
        for (NSString *scheme in schemes) {
            [list addObject:@{
                @"title": scheme,
                @"subtitle": name.length > 0 ? name : @"无名称"
            }];
        }
    }
    return list.copy;
}

static NSArray<NSDictionary<NSString *, NSString *> *> *UCFilzaInfoPlistKeys(void) {
    NSMutableArray *list = [NSMutableArray array];
    NSDictionary *info = NSBundle.mainBundle.infoDictionary;
    NSArray *sortedKeys = [info.allKeys sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    for (NSString *key in sortedKeys) {
        id value = info[key];
        NSString *valueStr = [value description];
        if (valueStr.length > 200) {
            valueStr = [[valueStr substringToIndex:200] stringByAppendingString:@"..."];
        }
        [list addObject:@{
            @"title": key,
            @"subtitle": valueStr
        }];
    }
    return list.copy;
}

static NSArray<NSDictionary<NSString *, NSString *> *> *UCFilzaPrivacyPermissions(void) {
    NSMutableArray *list = [NSMutableArray array];
    NSDictionary *info = NSBundle.mainBundle.infoDictionary;
    
    NSArray *privacyKeys = @[
        @"NSPhotoLibraryUsageDescription",
        @"NSPhotoLibraryAddUsageDescription",
        @"NSCameraUsageDescription",
        @"NSMicrophoneUsageDescription",
        @"NSLocationWhenInUseUsageDescription",
        @"NSLocationAlwaysAndWhenInUseUsageDescription",
        @"NSLocationAlwaysUsageDescription",
        @"NSContactsUsageDescription",
        @"NSCalendarsUsageDescription",
        @"NSRemindersUsageDescription",
        @"NSBluetoothAlwaysUsageDescription",
        @"NSBluetoothPeripheralUsageDescription",
        @"NSMotionUsageDescription",
        @"NSHealthShareUsageDescription",
        @"NSHealthUpdateUsageDescription",
        @"NSFaceIDUsageDescription",
        @"NSAppleMusicUsageDescription",
        @"NSSpeechRecognitionUsageDescription",
        @"NSLocalNetworkUsageDescription",
        @"NSUserTrackingUsageDescription"
    ];
    
    for (NSString *key in privacyKeys) {
        NSString *value = info[key];
        if (value) {
            [list addObject:@{
                @"title": [key stringByReplacingOccurrencesOfString:@"NS" withString:@""],
                @"subtitle": value
            }];
        }
    }
    return list.copy;
}

static NSArray<NSDictionary<NSString *, NSString *> *> *UCFilzaBackgroundModes(void) {
    NSMutableArray *list = [NSMutableArray array];
    NSArray *modes = NSBundle.mainBundle.infoDictionary[@"UIBackgroundModes"];
    for (NSString *mode in modes) {
        [list addObject:@{
            @"title": mode,
            @"subtitle": @""
        }];
    }
    return list.copy;
}

static NSString *UCFilzaMachOArchitecture(void) {
    NSString *executable = NSBundle.mainBundle.executablePath;
    if (!executable) return @"未知";
    
    FILE *f = fopen(executable.UTF8String, "r");
    if (!f) return @"未知";
    
    uint32_t magic = 0;
    if (fread(&magic, sizeof(uint32_t), 1, f) != 1) {
        fclose(f);
        return @"未知";
    }
    fclose(f);
    
    if (magic == MH_MAGIC_64) return @"ARM64";
    if (magic == MH_CIGAM_64) return @"ARM64 (BE)";
    if (magic == MH_MAGIC) return @"ARMv7";
    if (magic == MH_CIGAM) return @"ARMv7 (BE)";
    if (magic == 0xbebafeca) return @"Fat Binary (BE)";
    if (magic == 0xcafebabe) return @"Fat Binary";
    
    return [NSString stringWithFormat:@"Unknown (0x%08x)", magic];
}

static NSString *UCFilzaMachOUUID(void) {
    NSBundle *bundle = NSBundle.mainBundle;
    NSString *executable = bundle.executablePath;
    if (!executable) return nil;
    
    NSData *data = [NSData dataWithContentsOfFile:executable options:NSDataReadingMappedIfSafe error:nil];
    if (!data || data.length < sizeof(struct mach_header_64)) return nil;
    const void *exec = data.bytes;
    
    const uint32_t *magicPtr = (const uint32_t *)exec;
    uint32_t magic = *magicPtr;
    
    BOOL is64 = (magic == MH_MAGIC_64);  // 拒绝 MH_CIGAM_64 大端序：后续直接读取字段未做字节交换
    uint32_t ncmds = 0;
    const uint8_t *cmds = NULL;
    
    if (is64) {
        const struct mach_header_64 *hdr = (const struct mach_header_64 *)exec;
        ncmds = hdr->ncmds;
        cmds = (const uint8_t *)(hdr + 1);
    } else {
        const struct mach_header *hdr = (const struct mach_header *)exec;
        ncmds = hdr->ncmds;
        cmds = (const uint8_t *)(hdr + 1);
    }
    
    uint32_t offset = 0;
    for (uint32_t i = 0; i < ncmds; i++) {
        // 边界检查：offset 相对于 cmds(hdr+1)，需减去 header 大小
        if ((uint64_t)offset + sizeof(struct load_command) > data.length - sizeof(struct mach_header_64)) break;
        const struct load_command *lc = (const struct load_command *)(cmds + offset);
        if (lc->cmdsize == 0) break;  // 防止 cmdsize==0 导致死循环
        if (lc->cmd == LC_UUID) {
            const struct uuid_command *uuidCmd = (const struct uuid_command *)lc;
            NSUUID *uuid = [[NSUUID alloc] initWithUUIDBytes:uuidCmd->uuid];
            return uuid.UUIDString;
        }
        offset += lc->cmdsize;
    }
    
    return nil;
}

static NSArray<NSDictionary<NSString *, NSString *> *> *UCFilzaCookieList(void) {
    NSMutableArray *list = [NSMutableArray array];
    NSArray *cookies = NSHTTPCookieStorage.sharedHTTPCookieStorage.cookies;
    for (NSHTTPCookie *cookie in cookies) {
        [list addObject:@{
            @"title": cookie.name ?: @"",
            @"subtitle": [NSString stringWithFormat:@"%@=%@", cookie.domain ?: @"", cookie.value ?: @""]
        }];
    }
    return list.copy;
}

#pragma mark - Mach-O 深度解析

static NSArray<NSDictionary<NSString *, NSString *> *> *UCFilzaMachOLoadCommands(void) {
    NSMutableArray *list = [NSMutableArray array];
    NSString *executable = NSBundle.mainBundle.executablePath;
    if (!executable) return list.copy;
    NSData *data = [NSData dataWithContentsOfFile:executable options:NSDataReadingMappedIfSafe error:nil];
    if (!data || data.length < sizeof(struct mach_header_64)) return list.copy;
    const struct mach_header_64 *hdr = (const struct mach_header_64 *)data.bytes;
    if (hdr->magic != MH_MAGIC_64) return list.copy;
    const uint8_t *cmds = (const uint8_t *)(hdr + 1);
    uint32_t offset = 0;
    for (uint32_t i = 0; i < hdr->ncmds; i++) {
        if ((uint64_t)offset + sizeof(struct load_command) > data.length - sizeof(struct mach_header_64)) break;  // 边界检查修正：offset 相对 cmds(hdr+1)
        const struct load_command *lc = (const struct load_command *)(cmds + offset);
        if (lc->cmdsize == 0) break;
        NSString *cmdName = [NSString stringWithFormat:@"0x%x", lc->cmd];
        switch (lc->cmd) {
            case LC_SEGMENT_64: cmdName = @"SEGMENT_64"; break;
            case LC_SYMTAB: cmdName = @"SYMTAB"; break;
            case LC_DYSYMTAB: cmdName = @"DYSYMTAB"; break;
            case LC_LOAD_DYLIB: cmdName = @"LOAD_DYLIB"; break;
            case LC_LOAD_WEAK_DYLIB: cmdName = @"LOAD_WEAK_DYLIB"; break;
            case LC_REEXPORT_DYLIB: cmdName = @"REEXPORT_DYLIB"; break;
            case LC_LOAD_DYLINKER: cmdName = @"LOAD_DYLINKER"; break;
            case LC_UUID: cmdName = @"UUID"; break;
            case LC_MAIN: cmdName = @"MAIN"; break;
            case LC_FUNCTION_STARTS: cmdName = @"FUNCTION_STARTS"; break;
            case LC_CODE_SIGNATURE: cmdName = @"CODE_SIGNATURE"; break;
            case LC_DATA_IN_CODE: cmdName = @"DATA_IN_CODE"; break;
            case LC_DYLIB_CODE_SIGN_DRS: cmdName = @"DYLIB_CODE_SIGN_DRS"; break;
            case LC_LINKER_OPTIMIZATION_HINT: cmdName = @"LINKER_OPT_HINT"; break;
            case LC_VERSION_MIN_IPHONEOS: cmdName = @"VERSION_MIN_IPHONEOS"; break;
            case LC_SOURCE_VERSION: cmdName = @"SOURCE_VERSION"; break;
            case LC_BUILD_VERSION: cmdName = @"BUILD_VERSION"; break;
            case LC_ENCRYPTION_INFO_64: cmdName = @"ENCRYPTION_INFO_64"; break;
            case LC_RPATH: cmdName = @"RPATH"; break;
            case LC_DYLD_CHAINED_FIXUPS: cmdName = @"DYLD_CHAINED_FIXUPS"; break;
            case LC_DYLD_EXPORTS_TRIE: cmdName = @"DYLD_EXPORTS_TRIE"; break;
            case LC_DYLD_INFO_ONLY: cmdName = @"DYLD_INFO_ONLY"; break;
            case LC_SYMSEG: cmdName = @"SYMSEG"; break;
            case LC_THREAD: cmdName = @"THREAD"; break;
            case LC_UNIXTHREAD: cmdName = @"UNIXTHREAD"; break;
            case LC_LOADFVMLIB: cmdName = @"LOADFVMLIB"; break;
            case LC_IDFVMLIB: cmdName = @"IDFVMLIB"; break;
            case LC_IDENT: cmdName = @"IDENT"; break;
            case LC_FVMFILE: cmdName = @"FVMFILE"; break;
            case LC_PREPAGE: cmdName = @"PREPAGE"; break;
            case LC_TWOLEVEL_HINTS: cmdName = @"TWOLEVEL_HINTS"; break;
            case LC_PREBIND_CKSUM: cmdName = @"PREBIND_CKSUM"; break;
            default: break;
        }
        NSString *subtitle = [NSString stringWithFormat:@"size: %u", lc->cmdsize];
        if (lc->cmd == LC_SEGMENT_64) {
            // 验证可完整读取 segment_command_64（72字节），避免越界
            if ((uint64_t)offset + sizeof(struct segment_command_64) > data.length - sizeof(struct mach_header_64)) break;
            const struct segment_command_64 *seg = (const struct segment_command_64 *)lc;
            char name[17] = {0};
            strncpy(name, seg->segname, 16);
            subtitle = [NSString stringWithFormat:@"%s | %llu bytes | %u sections", name, seg->vmsize, seg->nsects];
        } else if (lc->cmd == LC_LOAD_DYLIB || lc->cmd == LC_LOAD_WEAK_DYLIB || lc->cmd == LC_REEXPORT_DYLIB) {
            const struct dylib_command *dlc = (const struct dylib_command *)lc;
            const char *name = (const char *)lc + dlc->dylib.name.offset;
            subtitle = [NSString stringWithUTF8String:name] ?: subtitle;
        } else if (lc->cmd == LC_LOAD_DYLINKER) {
            const struct dylinker_command *dlc = (const struct dylinker_command *)lc;
            const char *name = (const char *)lc + dlc->name.offset;
            subtitle = [NSString stringWithUTF8String:name] ?: subtitle;
        } else if (lc->cmd == LC_RPATH) {
            const struct rpath_command *rpc = (const struct rpath_command *)lc;
            const char *path = (const char *)lc + rpc->path.offset;
            subtitle = [NSString stringWithUTF8String:path] ?: subtitle;
        } else if (lc->cmd == LC_ENCRYPTION_INFO_64) {
            const struct encryption_info_command_64 *enc = (const struct encryption_info_command_64 *)lc;
            subtitle = [NSString stringWithFormat:@"offset: %u, size: %u, cryptid: %u", enc->cryptoff, enc->cryptsize, enc->cryptid];
        } else if (lc->cmd == LC_VERSION_MIN_IPHONEOS) {
            const struct version_min_command *ver = (const struct version_min_command *)lc;
            uint8_t major = (ver->version >> 16) & 0xFFFF;
            uint8_t minor = (ver->version >> 8) & 0xFF;
            uint8_t patch = ver->version & 0xFF;
            subtitle = [NSString stringWithFormat:@"%d.%d.%d", major, minor, patch];
        } else if (lc->cmd == LC_UUID) {
            const struct uuid_command *uuidCmd = (const struct uuid_command *)lc;
            NSUUID *uuid = [[NSUUID alloc] initWithUUIDBytes:uuidCmd->uuid];
            subtitle = uuid.UUIDString;
        } else if (lc->cmd == LC_MAIN) {
            const struct entry_point_command *ep = (const struct entry_point_command *)lc;
            subtitle = [NSString stringWithFormat:@"entryoff: 0x%llx, stacksize: %llu", ep->entryoff, ep->stacksize];
        }
        [list addObject:@{@"title": cmdName, @"subtitle": subtitle}];
        offset += lc->cmdsize;
    }
    return list.copy;
}

static NSArray<NSDictionary<NSString *, NSString *> *> *UCFilzaMachOSegments(void) {
    NSMutableArray *list = [NSMutableArray array];
    NSString *executable = NSBundle.mainBundle.executablePath;
    if (!executable) return list.copy;
    NSData *data = [NSData dataWithContentsOfFile:executable options:NSDataReadingMappedIfSafe error:nil];
    if (!data || data.length < sizeof(struct mach_header_64)) return list.copy;
    const struct mach_header_64 *hdr = (const struct mach_header_64 *)data.bytes;
    if (hdr->magic != MH_MAGIC_64) return list.copy;
    const uint8_t *cmds = (const uint8_t *)(hdr + 1);
    uint32_t offset = 0;
    for (uint32_t i = 0; i < hdr->ncmds; i++) {
        if ((uint64_t)offset + sizeof(struct load_command) > data.length - sizeof(struct mach_header_64)) break;  // 边界检查修正：offset 相对 cmds(hdr+1)
        const struct load_command *lc = (const struct load_command *)(cmds + offset);
        if (lc->cmdsize == 0) break;
        if (lc->cmd == LC_SEGMENT_64) {
            // 验证可完整读取 segment_command_64（72字节），避免越界
            if ((uint64_t)offset + sizeof(struct segment_command_64) > data.length - sizeof(struct mach_header_64)) break;
            const struct segment_command_64 *seg = (const struct segment_command_64 *)lc;
            char name[17] = {0};
            strncpy(name, seg->segname, 16);
            NSMutableString *flags = [NSMutableString string];
            if (seg->flags & SG_HIGHVM) [flags appendString:@"HIGHVM "];
            if (seg->flags & SG_FVMLIB) [flags appendString:@"FVMLIB "];
            if (seg->flags & SG_NORELOC) [flags appendString:@"NORELOC "];
            if (seg->flags & SG_PROTECTED_VERSION_1) [flags appendString:@"PROTECTED "];
            if (seg->flags & SG_READ_ONLY) [flags appendString:@"READ_ONLY "];
            [list addObject:@{
                @"title": [NSString stringWithFormat:@"%s", name],
                @"subtitle": [NSString stringWithFormat:@"vm: 0x%016llx-%016llx | file: %llu bytes | %u sections | %@",
                               seg->vmaddr, seg->vmaddr + seg->vmsize, seg->filesize, seg->nsects,
                               flags.length > 0 ? flags : @"无特殊 flag"]
            }];
        }
        offset += lc->cmdsize;
    }
    return list.copy;
}

static NSArray<NSDictionary<NSString *, NSString *> *> *UCFilzaMachOSectionsForSegment(NSString *segName) {
    NSMutableArray *list = [NSMutableArray array];
    NSString *executable = NSBundle.mainBundle.executablePath;
    if (!executable) return list.copy;
    NSData *data = [NSData dataWithContentsOfFile:executable options:NSDataReadingMappedIfSafe error:nil];
    if (!data || data.length < sizeof(struct mach_header_64)) return list.copy;
    const struct mach_header_64 *hdr = (const struct mach_header_64 *)data.bytes;
    if (hdr->magic != MH_MAGIC_64) return list.copy;
    const uint8_t *cmds = (const uint8_t *)(hdr + 1);
    uint32_t offset = 0;
    for (uint32_t i = 0; i < hdr->ncmds; i++) {
        if ((uint64_t)offset + sizeof(struct load_command) > data.length - sizeof(struct mach_header_64)) break;  // 边界检查修正：offset 相对 cmds(hdr+1)
        const struct load_command *lc = (const struct load_command *)(cmds + offset);
        if (lc->cmdsize == 0) break;
        if (lc->cmd == LC_SEGMENT_64) {
            // 验证可完整读取 segment_command_64（72字节），避免越界
            if ((uint64_t)offset + sizeof(struct segment_command_64) > data.length - sizeof(struct mach_header_64)) break;
            const struct segment_command_64 *seg = (const struct segment_command_64 *)lc;
            char curSegName[17] = {0};
            strncpy(curSegName, seg->segname, 16);
            NSString *curSeg = [NSString stringWithUTF8String:curSegName];
            if ([curSeg isEqualToString:segName]) {
                // 验证 sections 数组完整可读，防止 nsects 越界
                if ((uint8_t *)(seg + 1) + (uint64_t)seg->nsects * sizeof(struct section_64) > (uint8_t *)data.bytes + data.length) break;
                const struct section_64 *sect = (const struct section_64 *)(seg + 1);
                for (uint32_t j = 0; j < seg->nsects; j++) {
                    char sectName[17] = {0};
                    strncpy(sectName, sect[j].sectname, 16);
                    [list addObject:@{
                        @"title": [NSString stringWithUTF8String:sectName],
                        @"subtitle": [NSString stringWithFormat:@"addr: 0x%016llx | size: %llu | offset: %u | align: %u",
                                       sect[j].addr, sect[j].size, sect[j].offset, 1 << sect[j].align]
                    }];
                }
                break;
            }
        }
        offset += lc->cmdsize;
    }
    return list.copy;
}

typedef NS_ENUM(NSInteger, UCFilzaAppInfoSection) {
    UCFilzaAppInfoSectionBasic = 0,
    UCFilzaAppInfoSectionPaths,
    UCFilzaAppInfoSectionStorage,
    UCFilzaAppInfoSectionBinary,
    UCFilzaAppInfoSectionRuntime,
    UCFilzaAppInfoSectionEnvironment,
    UCFilzaAppInfoSectionInfoPlist,
    UCFilzaAppInfoSectionPermissions,
    UCFilzaAppInfoSectionData,
    UCFilzaAppInfoSectionDevice,
    UCFilzaAppInfoSectionActions,
    UCFilzaAppInfoSectionAppGroups
};

static vm_size_t UCFilzaMemoryUsage(void) {
    struct task_basic_info info;
    mach_msg_type_number_t size = TASK_BASIC_INFO_COUNT;
    kern_return_t kerr = task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)&info, &size);
    if (kerr == KERN_SUCCESS) {
        return info.resident_size;
    }
    return 0;
}

@interface UCFilzaAppInfoViewController ()

@property (nonatomic, strong) NSArray<NSString *> *sectionTitles;
@property (nonatomic, strong) NSArray<NSArray<NSDictionary *> *> *sectionData;

@property (nonatomic, assign) uint64_t bundleSize;
@property (nonatomic, assign) uint64_t documentsSize;
@property (nonatomic, assign) uint64_t librarySize;
@property (nonatomic, assign) uint64_t cachesSize;
@property (nonatomic, assign) uint64_t tmpSize;
@property (nonatomic, assign) uint64_t totalDataSize;

@property (nonatomic, strong) NSArray<NSDictionary *> *appGroups;

@end

@implementation UCFilzaAppInfoViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"应用信息";
    self.view.backgroundColor = UIColor.systemBackgroundColor;

    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 44;
    self.tableView.sectionHeaderTopPadding = 0;

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemClose
                             target:self
                             action:@selector(closeTapped)];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithTitle:@"复制全部"
                style:UIBarButtonItemStylePlain
               target:self
               action:@selector(copyAllInfo)];

    [self loadAppInfo];
    [self calculateSizes];
    [self loadAppGroups];
}

- (void)closeTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)loadAppInfo {
    NSBundle *bundle = NSBundle.mainBundle;
    NSDictionary *info = bundle.infoDictionary;
    
    NSString *appName = info[@"CFBundleDisplayName"] ?: info[@"CFBundleName"] ?: @"未知";
    NSString *bundleId = info[@"CFBundleIdentifier"] ?: @"未知";
    NSString *executable = info[@"CFBundleExecutable"] ?: @"未知";
    NSString *version = info[@"CFBundleShortVersionString"] ?: @"未知";
    NSString *build = info[@"CFBundleVersion"] ?: @"未知";
    NSString *minOS = info[@"MinimumOSVersion"] ?: @"未知";
    
    NSDate *launchDate = [NSDate dateWithTimeIntervalSinceNow:-NSProcessInfo.processInfo.systemUptime];
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.dateStyle = NSDateFormatterMediumStyle;
    fmt.timeStyle = NSDateFormatterMediumStyle;
    NSString *launchTime = [fmt stringFromDate:launchDate];
    
    NSInteger badge = UIApplication.sharedApplication.applicationIconBadgeNumber;
    
    NSString *docsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSString *libPath = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).firstObject;
    NSString *cachePath = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
    NSString *tmpPath = NSTemporaryDirectory();
    
    UIDevice *device = UIDevice.currentDevice;
    NSUInteger cpuCount = [NSProcessInfo processInfo].activeProcessorCount;
    uint64_t totalMemory = [NSProcessInfo processInfo].physicalMemory;
    
    NSError *error = nil;
    NSDictionary *fsAttrs = [NSFileManager.defaultManager attributesOfFileSystemForPath:NSHomeDirectory() error:&error];
    uint64_t freeDisk = [fsAttrs[NSFileSystemFreeSize] unsignedLongLongValue];
    uint64_t totalDisk = [fsAttrs[NSFileSystemSize] unsignedLongLongValue];
    
    NSMutableArray<NSString *> *titles = [NSMutableArray array];
    NSMutableArray<NSArray<NSDictionary *> *> *data = [NSMutableArray array];
    
    [titles addObject:@"基本信息"];
    [data addObject:@[
        @{@"title": @"应用名称", @"value": appName, @"copyable": @YES},
        @{@"title": @"包标识符", @"value": bundleId, @"copyable": @YES},
        @{@"title": @"可执行文件", @"value": executable, @"copyable": @YES},
        @{@"title": @"版本号", @"value": [NSString stringWithFormat:@"%@ (%@)", version, build], @"copyable": @YES},
        @{@"title": @"最低系统版本", @"value": minOS, @"copyable": @NO},
        @{@"title": @"启动时间", @"value": launchTime, @"copyable": @NO},
        @{@"title": @"角标数字", @"value": @(badge).stringValue, @"copyable": @NO, @"action": @"editBadge"}
    ]];
    
    [titles addObject:@"常用路径"];
    [data addObject:@[
        @{@"title": @"Bundle 目录", @"value": bundle.bundlePath, @"action": @"browse"},
        @{@"title": @"沙盒根目录", @"value": NSHomeDirectory(), @"action": @"browse"},
        @{@"title": @"Documents", @"value": docsPath, @"action": @"browse"},
        @{@"title": @"Library", @"value": libPath, @"action": @"browse"},
        @{@"title": @"Caches", @"value": cachePath, @"action": @"browse"},
        @{@"title": @"tmp", @"value": tmpPath, @"action": @"browse"}
    ]];
    
    [titles addObject:@"存储空间"];
    [data addObject:@[
        @{@"title": @"应用大小", @"value": @"计算中...", @"loading": @YES},
        @{@"title": @"Documents", @"value": @"计算中...", @"loading": @YES},
        @{@"title": @"Library", @"value": @"计算中...", @"loading": @YES},
        @{@"title": @"Caches", @"value": @"计算中...", @"loading": @YES},
        @{@"title": @"tmp", @"value": @"计算中...", @"loading": @YES},
        @{@"title": @"数据总大小", @"value": @"计算中...", @"loading": @YES}
    ]];
    
    NSString *execPath = bundle.executablePath ?: @"";
    NSString *arch = UCFilzaMachOArchitecture();
    NSDictionary *rtStats = UCFilzaObjCRuntimeStats();
    
    [titles addObject:@"二进制信息"];
    [data addObject:@[
        @{@"title": @"可执行文件", @"value": execPath.lastPathComponent, @"copyable": @YES},
        @{@"title": @"架构", @"value": arch, @"copyable": @NO},
        @{@"title": @"Load Commands", @"value": [NSString stringWithFormat:@"%u 个", (unsigned int)[UCFilzaMachOLoadCommands() count]], @"action": @"loadCmds"},
        @{@"title": @"Segments", @"value": [NSString stringWithFormat:@"%lu 个", (unsigned long)[UCFilzaMachOSegments() count]], @"action": @"segments"},
        @{@"title": @"依赖动态库", @"value": [NSString stringWithFormat:@"%u 个", _dyld_image_count()], @"action": @"dylibs"},
        @{@"title": @"UUID", @"value": @"获取中...", @"loading": @YES}
    ]];
    
    [titles addObject:@"运行时"];
    [data addObject:@[
        @{@"title": @"ObjC 类数量", @"value": [rtStats[@"classes"] stringValue], @"copyable": @NO},
        @{@"title": @"ObjC 方法总数", @"value": [rtStats[@"methods"] stringValue], @"copyable": @NO},
        @{@"title": @"ObjC 协议数", @"value": [rtStats[@"protocols"] stringValue], @"copyable": @NO},
        @{@"title": @"加载 image 数", @"value": [NSString stringWithFormat:@"%u", _dyld_image_count()], @"copyable": @NO},
        @{@"title": @"运行时长", @"value": [self stringFromTimeInterval:NSProcessInfo.processInfo.systemUptime], @"copyable": @NO}
    ]];
    
    [titles addObject:@"环境变量 & 参数"];
    [data addObject:@[
        @{@"title": @"环境变量", @"value": [NSString stringWithFormat:@"%lu 个", (unsigned long)NSProcessInfo.processInfo.environment.count], @"action": @"environment"},
        @{@"title": @"启动参数", @"value": [NSString stringWithFormat:@"%lu 个", (unsigned long)NSProcessInfo.processInfo.arguments.count], @"action": @"arguments"}
    ]];
    
    NSArray *urlSchemes = UCFilzaURLSchemesList();
    NSArray *bgModes = UCFilzaBackgroundModes();
    
    [titles addObject:@"Info.plist"];
    [data addObject:@[
        @{@"title": @"URL Schemes", @"value": [NSString stringWithFormat:@"%lu 个", (unsigned long)urlSchemes.count], @"action": @"urlSchemes"},
        @{@"title": @"后台模式", @"value": [NSString stringWithFormat:@"%lu 个", (unsigned long)bgModes.count], @"action": @"bgModes"},
        @{@"title": @"全部键值", @"value": [NSString stringWithFormat:@"%lu 个", (unsigned long)info.count], @"action": @"infoPlist"}
    ]];
    
    NSArray *perms = UCFilzaPrivacyPermissions();
    [titles addObject:@"隐私权限声明"];
    if (perms.count > 0) {
        NSMutableArray *permItems = [NSMutableArray array];
        for (NSDictionary *p in perms) {
            [permItems addObject:@{
                @"title": p[@"title"] ?: @"",
                @"value": p[@"subtitle"] ?: @"",
                @"copyable": @YES
            }];
        }
        [data addObject:permItems.copy];
    } else {
        [data addObject:@[
            @{@"title": @"无隐私权限声明", @"value": @"", @"copyable": @NO}
        ]];
    }
    
    NSArray *cookies = UCFilzaCookieList();
    [titles addObject:@"应用数据"];
    [data addObject:@[
        @{@"title": @"UserDefaults", @"value": [NSString stringWithFormat:@"%lu 个", (unsigned long)[NSUserDefaults standardUserDefaults].dictionaryRepresentation.count], @"action": @"userDefaults"},
        @{@"title": @"Cookie 存储", @"value": [NSString stringWithFormat:@"%lu 个", (unsigned long)cookies.count], @"action": @"cookies"}
    ]];
    
    [titles addObject:@"设备信息"];
    [data addObject:@[
        @{@"title": @"设备名称", @"value": device.name, @"copyable": @YES},
        @{@"title": @"系统版本", @"value": [NSString stringWithFormat:@"%@ %@", device.systemName, device.systemVersion], @"copyable": @YES},
        @{@"title": @"设备型号", @"value": device.model, @"copyable": @YES},
        @{@"title": @"内存使用", @"value": UCFilzaByteCountString(UCFilzaMemoryUsage()), @"copyable": @NO},
        @{@"title": @"总内存", @"value": UCFilzaByteCountString(totalMemory), @"copyable": @NO},
        @{@"title": @"可用磁盘", @"value": UCFilzaByteCountString(freeDisk), @"copyable": @NO},
        @{@"title": @"总磁盘", @"value": UCFilzaByteCountString(totalDisk), @"copyable": @NO},
        @{@"title": @"CPU 核心数", @"value": @(cpuCount).stringValue, @"copyable": @NO}
    ]];
    
    [titles addObject:@"快捷操作"];
    [data addObject:@[
        @{@"title": @"清除缓存", @"value": @"Caches + tmp", @"action": @"clearCache", @"destructive": @YES}
    ]];
    
    [titles addObject:@"应用组目录"];
    [data addObject:@[
        @{@"title": @"加载中...", @"value": @"", @"loading": @YES}
    ]];
    
    self.sectionTitles = titles.copy;
    self.sectionData = data.copy;
    [self.tableView reloadData];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *uuid = UCFilzaMachOUUID();
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateBinaryUUID:uuid];
        });
    });
}

- (NSString *)stringFromTimeInterval:(NSTimeInterval)interval {
    NSInteger ti = (NSInteger)interval;
    NSInteger seconds = ti % 60;
    NSInteger minutes = (ti / 60) % 60;
    NSInteger hours = (ti / 3600);
    if (hours > 0) {
        return [NSString stringWithFormat:@"%02ld:%02ld:%02ld", (long)hours, (long)minutes, (long)seconds];
    }
    return [NSString stringWithFormat:@"%02ld:%02ld", (long)minutes, (long)seconds];
}

- (void)updateBinaryUUID:(NSString *)uuid {
    if (self.sectionData.count <= UCFilzaAppInfoSectionBinary) return;
    NSMutableArray *binary = [self.sectionData[UCFilzaAppInfoSectionBinary] mutableCopy];
    if (binary.count >= 4) {
        binary[3] = @{@"title": @"UUID", @"value": uuid ?: @"未知", @"copyable": @YES};
    }
    NSMutableArray *allData = [self.sectionData mutableCopy];
    allData[UCFilzaAppInfoSectionBinary] = binary.copy;
    self.sectionData = allData.copy;
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:UCFilzaAppInfoSectionBinary] withRowAnimation:UITableViewRowAnimationAutomatic];
}

- (void)calculateSizes {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *docsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
        NSString *libPath = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).firstObject;
        NSString *cachePath = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
        NSString *tmpPath = NSTemporaryDirectory();
        
        uint64_t bundleSize = UCFilzaDirectorySize(NSBundle.mainBundle.bundlePath);
        uint64_t docsSize = UCFilzaDirectorySize(docsPath);
        uint64_t libSize = UCFilzaDirectorySize(libPath);
        uint64_t cacheSize = UCFilzaDirectorySize(cachePath);
        uint64_t tmpSize = UCFilzaDirectorySize(tmpPath);
        uint64_t totalData = docsSize + libSize + tmpSize;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.bundleSize = bundleSize;
            self.documentsSize = docsSize;
            self.librarySize = libSize;
            self.cachesSize = cacheSize;
            self.tmpSize = tmpSize;
            self.totalDataSize = totalData;
            [self updateStorageSection];
        });
    });
}

- (void)updateStorageSection {
    if (self.sectionData.count <= UCFilzaAppInfoSectionStorage) return;
    
    NSMutableArray<NSDictionary *> *storage = [self.sectionData[UCFilzaAppInfoSectionStorage] mutableCopy];
    storage[0] = @{@"title": @"应用大小", @"value": UCFilzaByteCountString(self.bundleSize), @"copyable": @NO};
    storage[1] = @{@"title": @"Documents", @"value": UCFilzaByteCountString(self.documentsSize), @"copyable": @NO};
    storage[2] = @{@"title": @"Library", @"value": UCFilzaByteCountString(self.librarySize), @"copyable": @NO};
    storage[3] = @{@"title": @"Caches", @"value": UCFilzaByteCountString(self.cachesSize), @"copyable": @NO};
    storage[4] = @{@"title": @"tmp", @"value": UCFilzaByteCountString(self.tmpSize), @"copyable": @NO};
    storage[5] = @{@"title": @"数据总大小", @"value": UCFilzaByteCountString(self.totalDataSize), @"copyable": @NO};
    
    NSMutableArray *allData = [self.sectionData mutableCopy];
    allData[UCFilzaAppInfoSectionStorage] = storage.copy;
    self.sectionData = allData.copy;
    
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:UCFilzaAppInfoSectionStorage] withRowAnimation:UITableViewRowAnimationAutomatic];
}

- (void)loadAppGroups {
    NSArray<NSDictionary *> *groups = [UCAppGroupHelper accessibleAppGroups] ?: @[];
    self.appGroups = groups;
    
    if (self.sectionData.count <= UCFilzaAppInfoSectionAppGroups) return;
    
    NSMutableArray *allData = [self.sectionData mutableCopy];
    
    if (groups.count == 0) {
        allData[UCFilzaAppInfoSectionAppGroups] = @[
            @{@"title": @"无可用应用组", @"value": @"当前 App 未配置 App Group", @"copyable": @NO}
        ];
    } else {
        NSMutableArray *groupItems = [NSMutableArray array];
        for (NSDictionary *group in groups) {
            [groupItems addObject:@{
                @"title": group[@"identifier"] ?: @"",
                @"value": group[@"path"] ?: @"",
                @"action": @"browseAppGroup",
                @"groupPath": group[@"path"] ?: @""
            }];
        }
        allData[UCFilzaAppInfoSectionAppGroups] = groupItems.copy;
    }
    
    self.sectionData = allData.copy;
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:UCFilzaAppInfoSectionAppGroups] withRowAnimation:UITableViewRowAnimationAutomatic];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.sectionTitles.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section >= self.sectionData.count) return 0;
    return self.sectionData[section].count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section >= self.sectionTitles.count) return nil;
    return self.sectionTitles[section];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"AppInfoCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];
    }
    
    if (indexPath.section >= self.sectionData.count) return cell;
    NSArray *rows = self.sectionData[indexPath.section];
    if (indexPath.row >= rows.count) return cell;
    
    NSDictionary *item = rows[indexPath.row];
    cell.textLabel.text = item[@"title"];
    cell.detailTextLabel.text = item[@"value"];
    
    BOOL isLoading = [item[@"loading"] boolValue];
    BOOL hasAction = item[@"action"] != nil;
    BOOL destructive = [item[@"destructive"] boolValue];
    
    cell.detailTextLabel.numberOfLines = 0;
    cell.textLabel.numberOfLines = 1;
    cell.textLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:14];
    
    if (isLoading) {
        cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    } else if (destructive) {
        cell.textLabel.textColor = UIColor.systemRedColor;
        cell.detailTextLabel.textColor = UIColor.systemRedColor;
    } else {
        cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
        cell.textLabel.textColor = UIColor.labelColor;
    }
    
    if (hasAction) {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section >= self.sectionData.count) return;
    NSArray *rows = self.sectionData[indexPath.section];
    if (indexPath.row >= rows.count) return;
    
    NSDictionary *item = rows[indexPath.row];
    NSString *action = item[@"action"];
    NSString *value = item[@"value"] ?: @"";
    BOOL copyable = [item[@"copyable"] boolValue];
    
    if ([action isEqualToString:@"browse"]) {
        [self browsePath:value title:item[@"title"]];
    } else if ([action isEqualToString:@"browseAppGroup"]) {
        [self browsePath:item[@"groupPath"] title:item[@"title"]];
    } else if ([action isEqualToString:@"clearCache"]) {
        [self confirmClearCache];
    } else if ([action isEqualToString:@"editBadge"]) {
        [self editBadge];
    } else if ([action isEqualToString:@"dylibs"]) {
        [self showDylibsList];
    } else if ([action isEqualToString:@"loadCmds"]) {
        [self showLoadCommands];
    } else if ([action isEqualToString:@"segments"]) {
        [self showSegments];
    } else if ([action isEqualToString:@"environment"]) {
        [self showEnvironmentList];
    } else if ([action isEqualToString:@"arguments"]) {
        [self showArgumentsList];
    } else if ([action isEqualToString:@"urlSchemes"]) {
        [self showURLSchemesList];
    } else if ([action isEqualToString:@"bgModes"]) {
        [self showBackgroundModes];
    } else if ([action isEqualToString:@"infoPlist"]) {
        [self showInfoPlistKeys];
    } else if ([action isEqualToString:@"userDefaults"]) {
        [self showUserDefaults];
    } else if ([action isEqualToString:@"cookies"]) {
        [self showCookies];
    } else if (copyable && value.length > 0) {
        [UIPasteboard.generalPasteboard setString:value];
        UCFilzaPresentTransientMessage(self, @"已复制", nil);
    }
}

- (void)showDylibsList {
    NSArray *dylibs = UCFilzaLoadedDylibsList();
    UCFilzaListViewController *vc = [UCFilzaListViewController controllerWithTitle:@"加载动态库" items:dylibs];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)showLoadCommands {
    NSArray *cmds = UCFilzaMachOLoadCommands();
    UCFilzaListViewController *vc = [UCFilzaListViewController controllerWithTitle:@"Load Commands" items:cmds];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)showSegments {
    NSArray *segs = UCFilzaMachOSegments();
    UCFilzaListViewController *vc = [UCFilzaListViewController controllerWithTitle:@"Segments" items:segs];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)showEnvironmentList {
    NSArray *env = UCFilzaEnvironmentList();
    UCFilzaListViewController *vc = [UCFilzaListViewController controllerWithTitle:@"环境变量" items:env];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)showArgumentsList {
    NSArray *args = UCFilzaArgumentsList();
    UCFilzaListViewController *vc = [UCFilzaListViewController controllerWithTitle:@"启动参数" items:args];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)showURLSchemesList {
    NSArray *schemes = UCFilzaURLSchemesList();
    UCFilzaListViewController *vc = [UCFilzaListViewController controllerWithTitle:@"URL Schemes" items:schemes];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)showBackgroundModes {
    NSArray *modes = UCFilzaBackgroundModes();
    UCFilzaListViewController *vc = [UCFilzaListViewController controllerWithTitle:@"后台模式" items:modes];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)showInfoPlistKeys {
    NSArray *keys = UCFilzaInfoPlistKeys();
    UCFilzaListViewController *vc = [UCFilzaListViewController controllerWithTitle:@"Info.plist" items:keys];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)showUserDefaults {
    NSDictionary *defaults = [NSUserDefaults standardUserDefaults].dictionaryRepresentation;
    NSMutableArray *items = [NSMutableArray array];
    NSArray *sortedKeys = [defaults.allKeys sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    for (NSString *key in sortedKeys) {
        id value = defaults[key];
        NSString *valueStr = [value description];
        if (valueStr.length > 300) {
            valueStr = [[valueStr substringToIndex:300] stringByAppendingString:@"..."];
        }
        [items addObject:@{
            @"title": key,
            @"subtitle": valueStr
        }];
    }
    UCFilzaListViewController *vc = [UCFilzaListViewController controllerWithTitle:@"UserDefaults" items:items];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)showCookies {
    NSArray *cookies = UCFilzaCookieList();
    UCFilzaListViewController *vc = [UCFilzaListViewController controllerWithTitle:@"Cookies" items:cookies];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)browsePath:(NSString *)path title:(NSString *)title {
    if (path.length == 0) return;
    UIViewController *controller = UCFilzaViewControllerForPath(path, title ?: path.lastPathComponent);
    if (controller) {
        [self.navigationController pushViewController:controller animated:YES];
    }
}

- (void)confirmClearCache {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"清除缓存"
                                                                   message:@"确定要清除 Caches 和 tmp 目录下的所有文件吗？此操作不可撤销。"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"清除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [self clearCache];
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)clearCache {
    NSString *cachePath = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
    NSString *tmpPath = NSTemporaryDirectory();
    
    NSFileManager *fm = NSFileManager.defaultManager;
    NSError *error = nil;
    NSUInteger clearedCount = 0;
    
    for (NSString *dirPath in @[cachePath, tmpPath]) {
        if (dirPath.length == 0) continue;
        NSArray *contents = [fm contentsOfDirectoryAtPath:dirPath error:&error];
        if (!contents) continue;
        
        for (NSString *item in contents) {
            NSString *fullPath = [dirPath stringByAppendingPathComponent:item];
            [fm removeItemAtPath:fullPath error:nil];
            clearedCount++;
        }
    }
    
    UCFilzaPresentTransientMessage(self, @"已清除", [NSString stringWithFormat:@"已清除 %lu 个文件", (unsigned long)clearedCount]);
    [self calculateSizes];
}

- (void)editBadge {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"设置角标"
                                                                   message:@"输入新的角标数字（留空清除）"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"0 = 清除角标";
        textField.keyboardType = UIKeyboardTypeNumberPad;
        textField.text = @(UIApplication.sharedApplication.applicationIconBadgeNumber).stringValue;
    }];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *text = alert.textFields.firstObject.text ?: @"0";
        NSInteger badge = text.integerValue;
        [UIApplication.sharedApplication setApplicationIconBadgeNumber:badge];
        [self loadAppInfo];
        UCFilzaPresentTransientMessage(self, @"已更新", nil);
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)copyAllInfo {
    NSMutableString *info = [NSMutableString string];
    
    for (NSUInteger i = 0; i < self.sectionTitles.count; i++) {
        [info appendFormat:@"=== %@ ===\n", self.sectionTitles[i]];
        
        if (i >= self.sectionData.count) continue;
        NSArray *rows = self.sectionData[i];
        
        for (NSDictionary *item in rows) {
            NSString *title = item[@"title"] ?: @"";
            NSString *value = item[@"value"] ?: @"";
            [info appendFormat:@"%@: %@\n", title, value];
        }
        
        [info appendString:@"\n"];
    }
    
    [UIPasteboard.generalPasteboard setString:info];
    UCFilzaPresentTransientMessage(self, @"已复制", @"已复制全部信息");
}

@end

@interface UCFilzaBrowserViewController ()

@property (nonatomic, copy) NSString *directoryPath;
@property (nonatomic, copy) NSString *displayTitle;
@property (nonatomic, copy) NSArray<NSString *> *allEntries;
@property (nonatomic, copy) NSArray<NSString *> *visibleEntries;
@property (nonatomic, strong) UISearchController *searchController;
@property (nonatomic, strong) NSCache<NSString *, UIImage *> *thumbnailCache;
@property (nonatomic, strong) NSMutableSet<NSString *> *loadingThumbnailKeys;
@property (nonatomic, strong) dispatch_queue_t thumbnailQueue;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *failedRetryCount;

@end

@implementation UCFilzaBrowserViewController

- (instancetype)initWithDirectoryPath:(NSString *)directoryPath title:(NSString *)title {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) {
        _directoryPath = directoryPath.stringByStandardizingPath ?: directoryPath;
        _displayTitle = title.length ? title : _directoryPath.lastPathComponent;
        _thumbnailCache = [NSCache new];
        _thumbnailCache.countLimit = 100;
        _loadingThumbnailKeys = [NSMutableSet set];
        _failedRetryCount = [NSMutableDictionary dictionary];
        _thumbnailQueue = dispatch_queue_create("com.filza.thumbnail", DISPATCH_QUEUE_CONCURRENT);
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = self.displayTitle;
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"browserCell"];

    self.refreshControl = [UIRefreshControl new];
    [self.refreshControl addTarget:self action:@selector(reloadEntries) forControlEvents:UIControlEventValueChanged];

    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchResultsUpdater = self;
    self.searchController.obscuresBackgroundDuringPresentation = NO;
    self.searchController.searchBar.placeholder = @"搜索文件名";
    self.navigationItem.searchController = self.searchController;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;

    UIBarButtonItem *actionButton = [[UIBarButtonItem alloc] initWithTitle:@"操作"
                                                                      style:UIBarButtonItemStylePlain
                                                                     target:self
                                                                     action:@selector(showDirectoryActions:)];
    self.navigationItem.rightBarButtonItem = actionButton;

    [self reloadEntries];
}

- (void)reloadEntries {
    NSError *error = nil;
    NSArray<NSString *> *names = [NSFileManager.defaultManager contentsOfDirectoryAtPath:self.directoryPath error:&error];
    if (error) {
        [self.refreshControl endRefreshing];
        UCFilzaPresentMessage(self, @"读取目录失败", error.localizedDescription ?: @"无法读取当前目录。");
        return;
    }

    NSMutableArray<NSString *> *paths = [NSMutableArray arrayWithCapacity:names.count];
    for (NSString *name in names) {
        [paths addObject:[self.directoryPath stringByAppendingPathComponent:name]];
    }

    [paths sortUsingComparator:^NSComparisonResult(NSString *lhs, NSString *rhs) {
        BOOL lhsDir = UCFilzaPathIsDirectory(lhs);
        BOOL rhsDir = UCFilzaPathIsDirectory(rhs);
        if (lhsDir != rhsDir) {
            return lhsDir ? NSOrderedAscending : NSOrderedDescending;
        }
        return [lhs.lastPathComponent localizedCaseInsensitiveCompare:rhs.lastPathComponent];
    }];

    self.allEntries = paths.copy;
    [self.thumbnailCache removeAllObjects];
    @synchronized (self.loadingThumbnailKeys) {
        [self.loadingThumbnailKeys removeAllObjects];
    }
    @synchronized (self.failedRetryCount) {
        [self.failedRetryCount removeAllObjects];
    }
    [self applySearchText:self.searchController.searchBar.text];
    [self.refreshControl endRefreshing];
}

- (void)applySearchText:(NSString *)searchText {
    NSString *keyword = [searchText stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (keyword.length == 0) {
        self.visibleEntries = self.allEntries ?: @[];
    } else {
        NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(NSString *path, __unused NSDictionary *bindings) {
            return [path.lastPathComponent localizedCaseInsensitiveContainsString:keyword];
        }];
        self.visibleEntries = [self.allEntries filteredArrayUsingPredicate:predicate];
    }
    [self.tableView reloadData];
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    [self applySearchText:searchController.searchBar.text];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.visibleEntries.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.directoryPath;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return [NSString stringWithFormat:@"%lu 项", (unsigned long)self.visibleEntries.count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"browserCell"];
    if (!cell || cell.detailTextLabel == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"browserCell"];
    }

    NSString *path = self.visibleEntries[indexPath.row];
    BOOL isDirectory = UCFilzaPathIsDirectory(path);
    NSDictionary<NSFileAttributeKey, id> *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:path error:nil];

    cell.textLabel.text = path.lastPathComponent;
    cell.textLabel.numberOfLines = 1;
    cell.detailTextLabel.numberOfLines = 2;
    cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

    if (isDirectory) {
        NSUInteger count = [NSFileManager.defaultManager contentsOfDirectoryAtPath:path error:nil].count;
        cell.detailTextLabel.text = [NSString stringWithFormat:@"目录 · %lu 项", (unsigned long)count];
    } else {
        unsigned long long fileSize = [attributes fileSize];
        NSString *sizeText = UCFilzaByteCountString(fileSize);
        NSDate *date = attributes.fileModificationDate;
        NSString *dateText = date ? [UCFilzaDateFormatter() stringFromDate:date] : @"未知时间";
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %@", sizeText, dateText];
    }

    if (!isDirectory && UCFilzaIsImagePath(path)) {
        UIImage *cached = [self.thumbnailCache objectForKey:path];
        if (cached) {
            cell.imageView.image = cached;
            cell.imageView.tintColor = nil;
            cell.imageView.contentMode = UIViewContentModeScaleAspectFill;
            cell.imageView.clipsToBounds = YES;
        } else {
            if (@available(iOS 13.0, *)) {
                cell.imageView.image = [UIImage systemImageNamed:@"photo.fill"];
                cell.imageView.tintColor = UCFilzaTintColorForFilePath(path, isDirectory);
            } else {
                cell.imageView.image = nil;
            }
            [self requestThumbnailForImagePath:path];
        }
    } else if (@available(iOS 13.0, *)) {
        NSString *symbolName = UCFilzaSymbolNameForFilePath(path, isDirectory);
        cell.imageView.image = [UIImage systemImageNamed:symbolName];
        cell.imageView.tintColor = UCFilzaTintColorForFilePath(path, isDirectory);
        cell.imageView.contentMode = UIViewContentModeScaleToFill;
    } else {
        cell.imageView.image = nil;
    }

    return cell;
}

- (void)requestThumbnailForImagePath:(NSString *)path {
    if (path.length == 0) return;
    @synchronized (self.loadingThumbnailKeys) {
        if ([self.loadingThumbnailKeys containsObject:path]) return;
        [self.loadingThumbnailKeys addObject:path];
    }

    __weak typeof(self) weakSelf = self;
    dispatch_async(self.thumbnailQueue, ^{
        @autoreleasepool {
            UIImage *thumbnail = UCFilzaThumbnailForImageFile(path, CGSizeMake(44, 44));
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) self = weakSelf;
                if (!self) return;

                @synchronized (self.loadingThumbnailKeys) {
                    [self.loadingThumbnailKeys removeObject:path];
                }

                if (thumbnail) {
                    [self.thumbnailCache setObject:thumbnail forKey:path];
                    [self.failedRetryCount removeObjectForKey:path];
                    [self reloadThumbnailCellForPath:path];
                } else {

                    @synchronized (self.failedRetryCount) {
                        NSInteger retries = [[self.failedRetryCount objectForKey:path] integerValue];
                        if (retries < 1) {
                            [self.failedRetryCount setObject:@(retries + 1) forKey:path];

                            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                __strong typeof(self) strongSelf = weakSelf;
                                if (strongSelf) {
                                    @synchronized (strongSelf.loadingThumbnailKeys) {
                                        [strongSelf.loadingThumbnailKeys removeObject:path];
                                    }
                                    [strongSelf requestThumbnailForImagePath:path];
                                }
                            });
                        }

                    }
                }
            });
        }
    });
}

- (void)reloadThumbnailCellForPath:(NSString *)path {
    NSUInteger row = [self.visibleEntries indexOfObject:path];
    if (row != NSNotFound) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:0];
        if ([[self.tableView indexPathsForVisibleRows] containsObject:indexPath]) {
            [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
        }
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSString *path = self.visibleEntries[indexPath.row];
    UIViewController *controller = UCFilzaViewControllerForPath(path, path.lastPathComponent);
    if (controller) {
        [self.navigationController pushViewController:controller animated:YES];
    }
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *path = self.visibleEntries[indexPath.row];

    __weak typeof(self) weakSelf = self;
    UIContextualAction *rename = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                         title:@"重命名"
                                                                       handler:^(__unused UIContextualAction *action, __unused UIView *sourceView, void (^completionHandler)(BOOL)) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            completionHandler(NO);
            return;
        }

        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"重命名"
                                                                       message:path.lastPathComponent
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
            field.text = path.lastPathComponent;
            field.placeholder = @"输入新文件名";
        }];
        [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(__unused UIAlertAction *action) {
            completionHandler(NO);
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            NSString *newName = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            if (newName.length == 0 || [newName isEqualToString:path.lastPathComponent]) {
                completionHandler(NO);
                return;
            }
            NSString *newPath = [path.stringByDeletingLastPathComponent stringByAppendingPathComponent:newName];
            NSError *moveError = nil;
            [NSFileManager.defaultManager moveItemAtPath:path toPath:newPath error:&moveError];
            if (moveError) {
                UCFilzaPresentMessage(self, @"重命名失败", moveError.localizedDescription ?: @"无法完成重命名。");
            }
            [self reloadEntries];
            completionHandler(moveError == nil);
        }]];
        [self presentViewController:alert animated:YES completion:nil];
    }];
    rename.backgroundColor = UIColor.systemOrangeColor;

    UIContextualAction *deleteAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                                               title:@"删除"
                                                                             handler:^(__unused UIContextualAction *action, __unused UIView *sourceView, void (^completionHandler)(BOOL)) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            completionHandler(NO);
            return;
        }

        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"确认删除"
                                                                       message:path.lastPathComponent
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(__unused UIAlertAction *action) {
            completionHandler(NO);
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"删除" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
            NSError *removeError = nil;
            [NSFileManager.defaultManager removeItemAtPath:path error:&removeError];
            if (removeError) {
                UCFilzaPresentMessage(self, @"删除失败", removeError.localizedDescription ?: @"无法删除所选文件。");
            }
            [self reloadEntries];
            completionHandler(removeError == nil);
        }]];
        [self presentViewController:alert animated:YES completion:nil];
    }];

    UISwipeActionsConfiguration *configuration = [UISwipeActionsConfiguration configurationWithActions:@[deleteAction, rename]];
    configuration.performsFirstActionWithFullSwipe = NO;
    return configuration;
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView leadingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *path = self.visibleEntries[indexPath.row];

    __weak typeof(self) weakSelf = self;
    UIContextualAction *copyPath = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                           title:@"路径"
                                                                         handler:^(__unused UIContextualAction *action, __unused UIView *sourceView, void (^completionHandler)(BOOL)) {
        UIPasteboard.generalPasteboard.string = path;
        __strong typeof(weakSelf) self = weakSelf;
        if (self) {
            UCFilzaPresentTransientMessage(self, @"已复制", path);
        }
        completionHandler(YES);
    }];
    copyPath.backgroundColor = UIColor.systemTealColor;

    UIContextualAction *share = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                        title:@"分享"
                                                                      handler:^(__unused UIContextualAction *action, UIView *sourceView, void (^completionHandler)(BOOL)) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            completionHandler(NO);
            return;
        }
        NSURL *fileURL = [NSURL fileURLWithPath:path];
        UIActivityViewController *activity = [[UIActivityViewController alloc] initWithActivityItems:@[fileURL] applicationActivities:nil];
        UIPopoverPresentationController *popover = activity.popoverPresentationController;
        if (popover) {
            popover.sourceView = sourceView;
            popover.sourceRect = sourceView.bounds;
        }
        [self presentViewController:activity animated:YES completion:nil];
        completionHandler(YES);
    }];
    share.backgroundColor = UIColor.systemBlueColor;

    UISwipeActionsConfiguration *configuration = [UISwipeActionsConfiguration configurationWithActions:@[copyPath, share]];
    configuration.performsFirstActionWithFullSwipe = NO;
    return configuration;
}

- (void)showDirectoryActions:(UIBarButtonItem *)sender {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"目录操作"
                                                                   message:self.directoryPath
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    [sheet addAction:[UIAlertAction actionWithTitle:@"新建文本文件" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [self createFileOrDirectory:NO];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"新建文件夹" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [self createFileOrDirectory:YES];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"复制当前路径" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        UIPasteboard.generalPasteboard.string = self.directoryPath;
        UCFilzaPresentTransientMessage(self, @"已复制目录路径", self.directoryPath);
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"刷新" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [self reloadEntries];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];

    UIPopoverPresentationController *popover = sheet.popoverPresentationController;
    if (popover) {
        popover.barButtonItem = sender;
    }
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)createFileOrDirectory:(BOOL)isDirectory {
    NSString *title = isDirectory ? @"新建文件夹" : @"新建文本文件";
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:self.directoryPath
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = isDirectory ? @"例如 NewFolder" : @"例如 config.txt";
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"创建" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        NSString *name = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (name.length == 0) return;

        NSString *targetPath = [self.directoryPath stringByAppendingPathComponent:name];
        NSError *createError = nil;
        if (isDirectory) {
            [NSFileManager.defaultManager createDirectoryAtPath:targetPath withIntermediateDirectories:YES attributes:nil error:&createError];
        } else {
            NSData *emptyData = [@"" dataUsingEncoding:NSUTF8StringEncoding];
            [NSFileManager.defaultManager createFileAtPath:targetPath contents:emptyData attributes:nil];
            if (![NSFileManager.defaultManager fileExistsAtPath:targetPath]) {
                createError = [NSError errorWithDomain:@"UCFilzaTool"
                                                  code:1003
                                              userInfo:@{NSLocalizedDescriptionKey: @"创建文件失败。"}];
            }
        }

        if (createError) {
            UCFilzaPresentMessage(self, @"创建失败", createError.localizedDescription ?: @"无法完成创建。");
        } else {
            [self reloadEntries];
        }
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end

@interface UCFilzaQuickLookPreviewController ()

@property (nonatomic, copy) NSString *filePath;

@end

@implementation UCFilzaQuickLookPreviewController

- (instancetype)initWithFilePath:(NSString *)filePath {
    self = [super init];
    if (self) {
        _filePath = filePath.stringByStandardizingPath ?: filePath;
        self.title = _filePath.lastPathComponent;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.dataSource = self;
    self.currentPreviewItemIndex = 0;
    [self reloadData];

    self.navigationItem.rightBarButtonItems = @[
        [[UIBarButtonItem alloc] initWithTitle:@"编辑"
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(editTapped)],
        [[UIBarButtonItem alloc] initWithTitle:@"更多"
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(showMoreActions:)]
    ];
}

- (NSInteger)numberOfPreviewItemsInPreviewController:(QLPreviewController *)controller {
    return 1;
}

- (id<QLPreviewItem>)previewController:(QLPreviewController *)controller previewItemAtIndex:(NSInteger)index {
    return [NSURL fileURLWithPath:self.filePath];
}

- (void)editTapped {
    UCFilzaEditorViewController *editor = [[UCFilzaEditorViewController alloc] initWithFilePath:self.filePath];
    [self.navigationController pushViewController:editor animated:YES];
}

- (void)showMoreActions:(UIBarButtonItem *)sender {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:self.filePath.lastPathComponent
                                                                   message:self.filePath
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    [sheet addAction:[UIAlertAction actionWithTitle:@"复制文件路径" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        UIPasteboard.generalPasteboard.string = self.filePath;
        UCFilzaPresentTransientMessage(self, @"已复制路径", self.filePath);
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"分享文件" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        NSURL *fileURL = [NSURL fileURLWithPath:self.filePath];
        UIActivityViewController *activity = [[UIActivityViewController alloc] initWithActivityItems:@[fileURL] applicationActivities:nil];
        UIPopoverPresentationController *popover = activity.popoverPresentationController;
        if (popover) {
            popover.barButtonItem = sender;
        }
        [self presentViewController:activity animated:YES completion:nil];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"打开编辑器" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [self editTapped];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];

    UIPopoverPresentationController *popover = sheet.popoverPresentationController;
    if (popover) {
        popover.barButtonItem = sender;
    }
    [self presentViewController:sheet animated:YES completion:nil];
}

@end

@implementation UCFilzaZipEntry
@end

@interface UCFilzaZipArchive ()

@property (nonatomic, copy, readwrite) NSString *filePath;
@property (nonatomic, copy, readwrite) NSArray<UCFilzaZipEntry *> *entries;
@property (nonatomic, strong) NSData *mappedData;

@end

@implementation UCFilzaZipArchive

- (instancetype)initWithFilePath:(NSString *)filePath error:(NSError **)error {
    self = [super init];
    if (!self) return nil;

    _filePath = filePath.stringByStandardizingPath ?: filePath;
    _mappedData = [NSData dataWithContentsOfFile:_filePath options:NSDataReadingMappedIfSafe error:error];
    if (!_mappedData.length) return nil;

    const uint8_t *bytes = _mappedData.bytes;
    NSUInteger length = _mappedData.length;
    if (length < 22) {
        if (error) {
            *error = [NSError errorWithDomain:@"UCFilzaTool"
                                         code:2100
                                     userInfo:@{NSLocalizedDescriptionKey: @"ZIP 文件太小，无法读取目录信息。"}];
        }
        return nil;
    }

    NSUInteger searchStart = length > (NSUInteger)(22 + 0xFFFF) ? length - (NSUInteger)(22 + 0xFFFF) : 0;
    NSInteger eocdOffset = -1;
    for (NSInteger idx = (NSInteger)length - 22; idx >= (NSInteger)searchStart; idx--) {
        if (UCFilzaReadUInt32LE(bytes + idx) == 0x06054b50) {
            eocdOffset = idx;
            break;
        }
    }

    if (eocdOffset < 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"UCFilzaTool"
                                         code:2101
                                     userInfo:@{NSLocalizedDescriptionKey: @"没有找到 ZIP 中央目录，当前文件可能不是标准 ZIP。"}];
        }
        return nil;
    }

    uint16_t totalEntries = UCFilzaReadUInt16LE(bytes + eocdOffset + 10);
    uint32_t centralDirectorySize = UCFilzaReadUInt32LE(bytes + eocdOffset + 12);
    uint32_t centralDirectoryOffset = UCFilzaReadUInt32LE(bytes + eocdOffset + 16);
    if ((uint64_t)centralDirectoryOffset + (uint64_t)centralDirectorySize > (uint64_t)length) {
        if (error) {
            *error = [NSError errorWithDomain:@"UCFilzaTool"
                                         code:2102
                                     userInfo:@{NSLocalizedDescriptionKey: @"ZIP 中央目录范围非法，当前压缩包可能已损坏。"}];
        }
        return nil;
    }

    NSMutableArray<UCFilzaZipEntry *> *entries = [NSMutableArray arrayWithCapacity:totalEntries];
    NSUInteger cursor = centralDirectoryOffset;
    for (uint16_t idx = 0; idx < totalEntries; idx++) {
        if (cursor + 46 > length || UCFilzaReadUInt32LE(bytes + cursor) != 0x02014b50) {
            if (error) {
                *error = [NSError errorWithDomain:@"UCFilzaTool"
                                             code:2103
                                         userInfo:@{NSLocalizedDescriptionKey: @"读取 ZIP 条目失败，中央目录格式异常。"}];
            }
            return nil;
        }

        uint16_t generalPurposeFlag = UCFilzaReadUInt16LE(bytes + cursor + 8);
        uint16_t compressionMethod = UCFilzaReadUInt16LE(bytes + cursor + 10);
        uint32_t compressedSize = UCFilzaReadUInt32LE(bytes + cursor + 20);
        uint32_t uncompressedSize = UCFilzaReadUInt32LE(bytes + cursor + 24);
        uint16_t fileNameLength = UCFilzaReadUInt16LE(bytes + cursor + 28);
        uint16_t extraLength = UCFilzaReadUInt16LE(bytes + cursor + 30);
        uint16_t commentLength = UCFilzaReadUInt16LE(bytes + cursor + 32);
        uint32_t localHeaderOffset = UCFilzaReadUInt32LE(bytes + cursor + 42);

        NSUInteger nameOffset = cursor + 46;
        if (nameOffset + fileNameLength > length) {
            if (error) {
                *error = [NSError errorWithDomain:@"UCFilzaTool"
                                             code:2104
                                         userInfo:@{NSLocalizedDescriptionKey: @"ZIP 文件名区域超出范围，当前压缩包可能已损坏。"}];
            }
            return nil;
        }

        NSData *nameData = [_mappedData subdataWithRange:NSMakeRange(nameOffset, fileNameLength)];
        NSString *decodedName = UCFilzaDecodedZipNameFromData(nameData, (generalPurposeFlag & (1 << 11)) != 0);
        NSString *sanitizedPath = UCFilzaSanitizedArchivePath(decodedName);
        BOOL isDirectory = [decodedName hasSuffix:@"/"] || [decodedName hasSuffix:@"\\"];
        if (sanitizedPath.length) {
            if (isDirectory && [sanitizedPath hasSuffix:@"/"]) {
                sanitizedPath = [sanitizedPath substringToIndex:sanitizedPath.length - 1];
            }
            UCFilzaZipEntry *entry = [UCFilzaZipEntry new];
            entry.archivePath = sanitizedPath;
            entry.displayName = sanitizedPath.lastPathComponent ?: sanitizedPath;
            entry.isDirectory = isDirectory;
            entry.isEncrypted = (generalPurposeFlag & 0x0001) != 0;
            entry.compressionMethod = compressionMethod;
            entry.compressedSize = compressedSize;
            entry.uncompressedSize = uncompressedSize;
            entry.localHeaderOffset = localHeaderOffset;
            [entries addObject:entry];
        }

        cursor += 46 + fileNameLength + extraLength + commentLength;
    }

    [entries sortUsingComparator:^NSComparisonResult(UCFilzaZipEntry *lhs, UCFilzaZipEntry *rhs) {
        if (lhs.isDirectory != rhs.isDirectory) {
            return lhs.isDirectory ? NSOrderedAscending : NSOrderedDescending;
        }
        return [lhs.archivePath localizedCaseInsensitiveCompare:rhs.archivePath];
    }];
    _entries = entries.copy;
    return self;
}

- (NSArray<UCFilzaZipEntry *> *)entriesForPrefix:(NSString *)prefix {
    NSString *normalizedPrefix = prefix ?: @"";
    if (normalizedPrefix.length && ![normalizedPrefix hasSuffix:@"/"]) {
        normalizedPrefix = [normalizedPrefix stringByAppendingString:@"/"];
    }

    NSMutableArray<UCFilzaZipEntry *> *matches = [NSMutableArray array];
    for (UCFilzaZipEntry *entry in self.entries) {
        if (normalizedPrefix.length == 0) {
            [matches addObject:entry];
            continue;
        }

        NSString *directoryMarker = [normalizedPrefix substringToIndex:normalizedPrefix.length - 1];
        if ([entry.archivePath isEqualToString:directoryMarker] || [entry.archivePath hasPrefix:normalizedPrefix]) {
            [matches addObject:entry];
        }
    }
    return matches;
}

- (NSData *)compressedDataForEntry:(UCFilzaZipEntry *)entry error:(NSError **)error {
    if (!entry || entry.isDirectory) return NSData.data;

    const uint8_t *bytes = self.mappedData.bytes;
    NSUInteger length = self.mappedData.length;
    NSUInteger offset = entry.localHeaderOffset;
    if (offset + 30 > length || UCFilzaReadUInt32LE(bytes + offset) != 0x04034b50) {
        if (error) {
            *error = [NSError errorWithDomain:@"UCFilzaTool"
                                         code:2105
                                     userInfo:@{NSLocalizedDescriptionKey: @"ZIP 本地文件头损坏，无法读取压缩数据。"}];
        }
        return nil;
    }

    uint16_t fileNameLength = UCFilzaReadUInt16LE(bytes + offset + 26);
    uint16_t extraLength = UCFilzaReadUInt16LE(bytes + offset + 28);
    NSUInteger dataOffset = offset + 30 + fileNameLength + extraLength;
    if ((uint64_t)dataOffset + (uint64_t)entry.compressedSize > (uint64_t)length) {
        if (error) {
            *error = [NSError errorWithDomain:@"UCFilzaTool"
                                         code:2106
                                     userInfo:@{NSLocalizedDescriptionKey: @"ZIP 数据区超出范围，无法提取该文件。"}];
        }
        return nil;
    }

    return [self.mappedData subdataWithRange:NSMakeRange(dataOffset, entry.compressedSize)];
}

- (NSData *)dataForEntry:(UCFilzaZipEntry *)entry error:(NSError **)error {
    if (!entry || entry.isDirectory) return NSData.data;
    if (entry.isEncrypted) {
        if (error) {
            *error = [NSError errorWithDomain:@"UCFilzaTool"
                                         code:2107
                                     userInfo:@{NSLocalizedDescriptionKey: @"暂不支持解密受密码保护的 ZIP 条目。"}];
        }
        return nil;
    }

    NSData *compressedData = [self compressedDataForEntry:entry error:error];
    if (!compressedData) return nil;

    if (entry.compressionMethod == 0) {
        return compressedData;
    }
    if (entry.compressionMethod != 8) {
        if (error) {
            *error = [NSError errorWithDomain:@"UCFilzaTool"
                                         code:2108
                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"暂不支持 ZIP 压缩方式 %u。", entry.compressionMethod]}];
        }
        return nil;
    }

    z_stream stream;
    memset(&stream, 0, sizeof(stream));
    stream.next_in = (Bytef *)compressedData.bytes;
    stream.avail_in = (uInt)MIN((NSUInteger)UINT_MAX, compressedData.length);
    int status = inflateInit2(&stream, -MAX_WBITS);
    if (status != Z_OK) {
        if (error) {
            *error = [NSError errorWithDomain:@"UCFilzaTool"
                                         code:2109
                                     userInfo:@{NSLocalizedDescriptionKey: @"初始化 ZIP 解压器失败。"}];
        }
        return nil;
    }

    NSMutableData *result = [NSMutableData dataWithCapacity:MAX((NSUInteger)entry.uncompressedSize, (NSUInteger)16384)];
    uint8_t buffer[16384];
    do {
        stream.next_out = buffer;
        stream.avail_out = sizeof(buffer);
        status = inflate(&stream, Z_NO_FLUSH);
        if (status != Z_OK && status != Z_STREAM_END) {
            inflateEnd(&stream);
            if (error) {
                *error = [NSError errorWithDomain:@"UCFilzaTool"
                                             code:2110
                                         userInfo:@{NSLocalizedDescriptionKey: @"ZIP 解压过程中发生错误。"}];
            }
            return nil;
        }
        NSUInteger produced = sizeof(buffer) - stream.avail_out;
        if (produced > 0) {
            [result appendBytes:buffer length:produced];
        }
    } while (status != Z_STREAM_END);

    inflateEnd(&stream);
    return result;
}

- (NSString *)previewCacheRootPath {
    NSDictionary<NSFileAttributeKey, id> *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:self.filePath error:nil];
    NSTimeInterval modTime = attributes.fileModificationDate.timeIntervalSince1970;
    NSString *cacheName = [NSString stringWithFormat:@"%@_%@", self.filePath.lastPathComponent ?: @"archive", UCFilzaStableHexDigestForString([NSString stringWithFormat:@"%@|%.0f", self.filePath ?: @"", modTime])];
    NSString *root = [NSTemporaryDirectory() stringByAppendingPathComponent:[@"ToolsEricZipPreview" stringByAppendingPathComponent:cacheName]];
    [NSFileManager.defaultManager createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:nil];
    return root;
}

- (NSString *)temporaryPathForEntry:(UCFilzaZipEntry *)entry error:(NSError **)error {
    if (!entry || entry.isDirectory) return nil;
    NSString *targetPath = [[self previewCacheRootPath] stringByAppendingPathComponent:entry.archivePath];
    if ([NSFileManager.defaultManager fileExistsAtPath:targetPath]) {
        return targetPath;
    }

    NSError *dataError = nil;
    NSData *data = [self dataForEntry:entry error:&dataError];
    if (!data) {
        if (error) *error = dataError;
        return nil;
    }

    [NSFileManager.defaultManager createDirectoryAtPath:targetPath.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
    BOOL written = [data writeToFile:targetPath options:NSDataWritingAtomic error:error];
    return written ? targetPath : nil;
}

- (NSString *)extractEntriesWithPrefix:(NSString *)prefix error:(NSError **)error {
    NSString *normalizedPrefix = prefix ?: @"";
    if (normalizedPrefix.length && ![normalizedPrefix hasSuffix:@"/"]) {
        normalizedPrefix = [normalizedPrefix stringByAppendingString:@"/"];
    }

    NSString *zipBaseName = self.filePath.stringByDeletingPathExtension.lastPathComponent ?: @"Archive";
    NSString *folderName = normalizedPrefix.length ? [normalizedPrefix substringToIndex:normalizedPrefix.length - 1].lastPathComponent : @"unzipped";
    NSString *targetName = [NSString stringWithFormat:@"%@_%@_%@", zipBaseName, folderName, [UCFilzaFileNameDateFormatter() stringFromDate:NSDate.date]];
    NSString *targetRoot = [self.filePath.stringByDeletingLastPathComponent stringByAppendingPathComponent:targetName];

    BOOL created = [NSFileManager.defaultManager createDirectoryAtPath:targetRoot withIntermediateDirectories:YES attributes:nil error:error];
    if (!created) return nil;

    NSArray<UCFilzaZipEntry *> *candidates = [self entriesForPrefix:normalizedPrefix];
    for (UCFilzaZipEntry *entry in candidates) {
        NSString *relativePath = entry.archivePath ?: @"";
        if (normalizedPrefix.length) {
            NSString *directoryMarker = [normalizedPrefix substringToIndex:normalizedPrefix.length - 1];
            if ([relativePath isEqualToString:directoryMarker]) {
                continue;
            }
            if ([relativePath hasPrefix:normalizedPrefix]) {
                relativePath = [relativePath substringFromIndex:normalizedPrefix.length];
            }
        }
        if (relativePath.length == 0) continue;

        NSString *targetPath = [targetRoot stringByAppendingPathComponent:relativePath];
        if (entry.isDirectory) {
            [NSFileManager.defaultManager createDirectoryAtPath:targetPath withIntermediateDirectories:YES attributes:nil error:nil];
            continue;
        }

        NSData *data = [self dataForEntry:entry error:error];
        if (!data) return nil;

        [NSFileManager.defaultManager createDirectoryAtPath:targetPath.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
        BOOL written = [data writeToFile:targetPath options:NSDataWritingAtomic error:error];
        if (!written) return nil;
    }

    return targetRoot;
}

@end

@interface UCFilzaZipBrowserViewController ()

@property (nonatomic, copy) NSString *zipPath;
@property (nonatomic, copy) NSString *displayTitle;
@property (nonatomic, copy) NSString *currentPrefix;
@property (nonatomic, strong) UCFilzaZipArchive *archive;
@property (nonatomic, copy) NSArray<NSDictionary<NSString *, id> *> *allItems;
@property (nonatomic, copy) NSArray<NSDictionary<NSString *, id> *> *visibleItems;
@property (nonatomic, strong) UISearchController *searchController;

@end

@implementation UCFilzaZipBrowserViewController

- (instancetype)initWithZipPath:(NSString *)zipPath title:(NSString *)title prefix:(NSString *)prefix archive:(UCFilzaZipArchive *)archive {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) {
        _zipPath = zipPath.stringByStandardizingPath ?: zipPath;
        _displayTitle = title.length ? title : _zipPath.lastPathComponent;
        _currentPrefix = prefix ?: @"";
        _archive = archive;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = self.displayTitle;
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"zipCell"];

    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchResultsUpdater = self;
    self.searchController.obscuresBackgroundDuringPresentation = NO;
    self.searchController.searchBar.placeholder = @"搜索 ZIP 内容";
    self.navigationItem.searchController = self.searchController;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;

    self.refreshControl = [UIRefreshControl new];
    [self.refreshControl addTarget:self action:@selector(loadArchiveOrRefresh) forControlEvents:UIControlEventValueChanged];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"操作"
                                                                               style:UIBarButtonItemStylePlain
                                                                              target:self
                                                                              action:@selector(showActions:)];
    [self loadArchiveOrRefresh];
}

- (void)loadArchiveOrRefresh {
    if (self.archive) {
        [self rebuildItems];
        [self.refreshControl endRefreshing];
        return;
    }

    [self.refreshControl beginRefreshing];
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSError *error = nil;
        UCFilzaZipArchive *archive = [[UCFilzaZipArchive alloc] initWithFilePath:self.zipPath error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            [self.refreshControl endRefreshing];
            if (!archive || error) {
                UCFilzaPresentMessage(self, @"ZIP 打开失败", error.localizedDescription ?: @"无法读取当前 ZIP 文件。");
                return;
            }
            self.archive = archive;
            [self rebuildItems];
        });
    });
}

- (void)rebuildItems {
    NSMutableDictionary<NSString *, NSMutableDictionary<NSString *, id> *> *directories = [NSMutableDictionary dictionary];
    NSMutableArray<NSDictionary<NSString *, id> *> *files = [NSMutableArray array];
    NSString *prefix = self.currentPrefix ?: @"";
    NSString *prefixWithSlash = prefix.length && ![prefix hasSuffix:@"/"] ? [prefix stringByAppendingString:@"/"] : prefix;

    for (UCFilzaZipEntry *entry in [self.archive entriesForPrefix:prefixWithSlash]) {
        NSString *path = entry.archivePath ?: @"";
        NSString *relativePath = path;
        if (prefixWithSlash.length) {
            NSString *directoryMarker = [prefixWithSlash substringToIndex:prefixWithSlash.length - 1];
            if ([path isEqualToString:directoryMarker]) continue;
            if ([path hasPrefix:prefixWithSlash]) {
                relativePath = [path substringFromIndex:prefixWithSlash.length];
            }
        }
        if (relativePath.length == 0) continue;

        NSArray<NSString *> *components = [relativePath componentsSeparatedByString:@"/"];
        if (components.count > 1 || entry.isDirectory) {
            NSString *directoryName = components.firstObject ?: relativePath;
            NSString *childPrefix = prefixWithSlash.length ? [prefixWithSlash stringByAppendingFormat:@"%@/", directoryName] : [directoryName stringByAppendingString:@"/"];
            NSMutableDictionary<NSString *, id> *item = directories[directoryName];
            if (!item) {
                item = [@{@"type": @"dir", @"name": directoryName, @"prefix": childPrefix, @"count": @(0)} mutableCopy];
                directories[directoryName] = item;
            }
            item[@"count"] = @([item[@"count"] unsignedIntegerValue] + 1);
        } else {
            [files addObject:@{@"type": @"file", @"name": entry.displayName ?: relativePath, @"entry": entry}];
        }
    }

    NSMutableArray<NSDictionary<NSString *, id> *> *items = [NSMutableArray array];
    NSArray *sortedDirectoryKeys = [directories.allKeys sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    for (NSString *key in sortedDirectoryKeys) {
        [items addObject:directories[key]];
    }
    [files sortUsingComparator:^NSComparisonResult(NSDictionary<NSString *, id> *lhs, NSDictionary<NSString *, id> *rhs) {
        return [lhs[@"name"] localizedCaseInsensitiveCompare:rhs[@"name"]];
    }];
    [items addObjectsFromArray:files];
    self.allItems = items.copy;
    [self applySearchText:self.searchController.searchBar.text];
}

- (void)applySearchText:(NSString *)searchText {
    NSString *keyword = [searchText stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (keyword.length == 0) {
        self.visibleItems = self.allItems ?: @[];
    } else {
        NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(NSDictionary<NSString *, id> *item, __unused NSDictionary *bindings) {
            return [item[@"name"] localizedCaseInsensitiveContainsString:keyword];
        }];
        self.visibleItems = [self.allItems filteredArrayUsingPredicate:predicate];
    }
    [self.tableView reloadData];
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    [self applySearchText:searchController.searchBar.text];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.visibleItems.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (self.currentPrefix.length == 0) {
        return self.zipPath;
    }
    return [NSString stringWithFormat:@"%@ · %@", self.zipPath.lastPathComponent, self.currentPrefix];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return [NSString stringWithFormat:@"共 %lu 项。点击 ZIP 里的文件会先解出临时副本再打开；需要落地修改时请使用解压功能。", (unsigned long)self.visibleItems.count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"zipCell"];
    if (!cell || cell.detailTextLabel == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"zipCell"];
    }

    NSDictionary<NSString *, id> *item = self.visibleItems[indexPath.row];
    BOOL isDirectory = [item[@"type"] isEqualToString:@"dir"];
    cell.textLabel.text = item[@"name"];
    cell.textLabel.numberOfLines = 1;
    cell.detailTextLabel.numberOfLines = 2;
    cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

    if (isDirectory) {
        NSUInteger count = [item[@"count"] unsignedIntegerValue];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"ZIP 目录 · %lu 项", (unsigned long)count];
    } else {
        UCFilzaZipEntry *entry = item[@"entry"];
        NSString *methodText = entry.compressionMethod == 0 ? @"store" : (entry.compressionMethod == 8 ? @"deflate" : [NSString stringWithFormat:@"method %u", entry.compressionMethod]);
        NSString *sizeText = [NSString stringWithFormat:@"%@ → %@", UCFilzaByteCountString(entry.compressedSize), UCFilzaByteCountString(entry.uncompressedSize)];
        NSString *encryptText = entry.isEncrypted ? @" · 已加密" : @"";
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %@%@", sizeText, methodText, encryptText];
    }

    if (@available(iOS 13.0, *)) {
        NSString *symbolName = isDirectory ? @"folder.fill" : UCFilzaSymbolNameForFilePath(item[@"name"], NO);
        UIColor *color = isDirectory ? UIColor.systemYellowColor : UCFilzaTintColorForFilePath(item[@"name"], NO);
        cell.imageView.image = [UIImage systemImageNamed:symbolName];
        cell.imageView.tintColor = color;
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary<NSString *, id> *item = self.visibleItems[indexPath.row];
    if ([item[@"type"] isEqualToString:@"dir"]) {
        NSString *prefix = item[@"prefix"] ?: @"";
        NSString *title = item[@"name"] ?: prefix.lastPathComponent;
        UCFilzaZipBrowserViewController *browser = [[UCFilzaZipBrowserViewController alloc] initWithZipPath:self.zipPath title:title prefix:prefix archive:self.archive];
        [self.navigationController pushViewController:browser animated:YES];
        return;
    }

    UCFilzaZipEntry *entry = item[@"entry"];
    NSError *error = nil;
    NSString *temporaryPath = [self.archive temporaryPathForEntry:entry error:&error];
    if (!temporaryPath.length || error) {
        UCFilzaPresentMessage(self, @"打开失败", error.localizedDescription ?: @"无法打开 ZIP 中的文件。");
        return;
    }

    UIViewController *controller = UCFilzaViewControllerForPath(temporaryPath, entry.displayName);
    if (controller) {
        [self.navigationController pushViewController:controller animated:YES];
    }
}

- (void)showActions:(UIBarButtonItem *)sender {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:self.zipPath.lastPathComponent
                                                                   message:self.currentPrefix.length ? self.currentPrefix : self.zipPath
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    NSString *extractTitle = self.currentPrefix.length ? @"解压当前目录" : @"解压整个 ZIP";
    [sheet addAction:[UIAlertAction actionWithTitle:extractTitle style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        NSError *error = nil;
        NSString *path = [self.archive extractEntriesWithPrefix:self.currentPrefix error:&error];
        if (!path.length || error) {
            UCFilzaPresentMessage(self, @"解压失败", error.localizedDescription ?: @"无法解压当前 ZIP 内容。");
            return;
        }
        UCFilzaPresentMessage(self, @"解压成功", path);
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"复制 ZIP 路径" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        UIPasteboard.generalPasteboard.string = self.zipPath;
        UCFilzaPresentTransientMessage(self, @"已复制 ZIP 路径", self.zipPath);
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];

    UIPopoverPresentationController *popover = sheet.popoverPresentationController;
    if (popover) {
        popover.barButtonItem = sender;
    }
    [self presentViewController:sheet animated:YES completion:nil];
}

@end

static UIImage *UCFilzaAspectFitThumbnailImage(UIImage *image, CGSize targetSize) {
    if (!image || targetSize.width <= 0.0 || targetSize.height <= 0.0) return image;
    CGSize sourceSize = image.size;
    if (sourceSize.width <= 0.0 || sourceSize.height <= 0.0) return image;

    CGFloat scale = MIN(targetSize.width / sourceSize.width, targetSize.height / sourceSize.height);
    CGSize drawSize = CGSizeMake(MAX(1.0, floor(sourceSize.width * scale)), MAX(1.0, floor(sourceSize.height * scale)));
    UIGraphicsBeginImageContextWithOptions(targetSize, NO, 0.0);
    CGRect drawRect = CGRectMake((targetSize.width - drawSize.width) * 0.5, (targetSize.height - drawSize.height) * 0.5, drawSize.width, drawSize.height);
    [image drawInRect:drawRect];
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result ?: image;
}

static UIImage *UCFilzaPreviewImageForCarAsset(NSString *filePath, NSString *assetName, CGFloat scale) {
    NSError *error = nil;
    id catalog = UCFilzaCreateCatalogForFilePath(filePath, &error);
    if (!catalog || error) return nil;
    UIImage *image = UCFilzaEffectiveCatalogImage(catalog, filePath, assetName, scale, nil);
    if (!image) {
        image = UCFilzaOriginalCatalogImage(catalog, assetName, scale, nil);
    }
    return image;
}

@implementation UCFilzaCarAssetGridCell {
    UIImageView *_imageView;
    UILabel *_titleLabel;
    UILabel *_subtitleLabel;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.contentView.backgroundColor = UIColor.secondarySystemBackgroundColor;
        self.contentView.layer.cornerRadius = 8.0;
        self.contentView.layer.masksToBounds = YES;

        _imageView = [[UIImageView alloc] initWithFrame:CGRectZero];
        _imageView.translatesAutoresizingMaskIntoConstraints = NO;
        _imageView.contentMode = UIViewContentModeScaleAspectFit;
        _imageView.backgroundColor = UIColor.tertiarySystemBackgroundColor;

        _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _titleLabel.font = [UIFont systemFontOfSize:9 weight:UIFontWeightSemibold];
        _titleLabel.textColor = UIColor.labelColor;
        _titleLabel.numberOfLines = 2;
        _titleLabel.adjustsFontSizeToFitWidth = YES;
        _titleLabel.minimumScaleFactor = 0.7;

        _subtitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _subtitleLabel.font = [UIFont systemFontOfSize:8];
        _subtitleLabel.textColor = UIColor.secondaryLabelColor;
        _subtitleLabel.numberOfLines = 1;
        _subtitleLabel.adjustsFontSizeToFitWidth = YES;
        _subtitleLabel.minimumScaleFactor = 0.7;

        [self.contentView addSubview:_imageView];
        [self.contentView addSubview:_titleLabel];
        [self.contentView addSubview:_subtitleLabel];

        [NSLayoutConstraint activateConstraints:@[
            [_imageView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
            [_imageView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
            [_imageView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
            [_imageView.heightAnchor constraintEqualToAnchor:self.contentView.widthAnchor],

            [_titleLabel.topAnchor constraintEqualToAnchor:_imageView.bottomAnchor constant:4],
            [_titleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:4],
            [_titleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-4],

            [_subtitleLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:2],
            [_subtitleLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
            [_subtitleLabel.trailingAnchor constraintEqualToAnchor:_titleLabel.trailingAnchor],
            [_subtitleLabel.bottomAnchor constraintLessThanOrEqualToAnchor:self.contentView.bottomAnchor constant:-4],
        ]];
    }
    return self;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    _imageView.image = nil;
    _titleLabel.text = nil;
    _subtitleLabel.text = nil;
}

- (void)configureWithTitle:(NSString *)title subtitle:(NSString *)subtitle image:(UIImage *)image highlighted:(BOOL)highlighted {
    _titleLabel.text = title;
    _subtitleLabel.text = subtitle;
    _imageView.image = image;
    self.contentView.layer.borderWidth = highlighted ? 1.5 : 0.0;
    self.contentView.layer.borderColor = highlighted ? UIColor.systemGreenColor.CGColor : UIColor.clearColor.CGColor;
    if (!image) {
        if (@available(iOS 13.0, *)) {
            _imageView.image = [UIImage systemImageNamed:@"photo"];
            _imageView.tintColor = UIColor.systemBrownColor;
        }
    }
}

@end

@interface UCFilzaCarAssetGridViewController () <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UISearchResultsUpdating, UICollectionViewDataSourcePrefetching>

@property (nonatomic, copy) NSString *filePath;
@property (nonatomic, copy) NSArray<NSString *> *allAssetNames;
@property (nonatomic, copy) NSArray<NSString *> *visibleAssetNames;
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) UISearchController *searchController;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, strong) NSCache<NSString *, UIImage *> *thumbnailCache;
@property (nonatomic, strong) NSMutableSet<NSString *> *loadingThumbnailKeys;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *overrideStatusCache;
@property (nonatomic, strong) id cachedCatalog;

@end

@implementation UCFilzaCarAssetGridViewController

- (instancetype)initWithFilePath:(NSString *)filePath {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _filePath = filePath.stringByStandardizingPath ?: filePath;
        _thumbnailCache = [NSCache new];
        _loadingThumbnailKeys = [NSMutableSet set];
        _overrideStatusCache = [NSMutableDictionary dictionary];
        _cachedCatalog = nil;
        self.title = @"图片网格";
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = UIColor.systemBackgroundColor;

    UICollectionViewFlowLayout *layout = [UICollectionViewFlowLayout new];
    layout.minimumLineSpacing = 8.0;
    layout.minimumInteritemSpacing = 8.0;
    layout.sectionInset = UIEdgeInsetsMake(8, 8, 8, 8);

    self.collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    self.collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    self.collectionView.backgroundColor = UIColor.systemBackgroundColor;
    self.collectionView.dataSource = self;
    self.collectionView.delegate = self;
    self.collectionView.prefetchDataSource = self;
    [self.collectionView registerClass:UCFilzaCarAssetGridCell.class forCellWithReuseIdentifier:@"assetGridCell"];
    [self.view addSubview:self.collectionView];

    [NSLayoutConstraint activateConstraints:@[
        [self.collectionView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.collectionView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.collectionView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.collectionView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchResultsUpdater = self;
    self.searchController.obscuresBackgroundDuringPresentation = NO;
    self.searchController.searchBar.placeholder = @"搜索图片资源";
    self.navigationItem.searchController = self.searchController;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                                            target:self
                                                                                            action:@selector(loadAssets)];

    self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.loadingIndicator.hidesWhenStopped = YES;
    self.collectionView.backgroundView = self.loadingIndicator;
    [self loadAssets];
}

- (void)loadAssets {
    [self.loadingIndicator startAnimating];
    self.cachedCatalog = nil;
    [self.overrideStatusCache removeAllObjects];
    [self.thumbnailCache removeAllObjects];
    @synchronized (self.loadingThumbnailKeys) {
        [self.loadingThumbnailKeys removeAllObjects];
    }

    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSError *error = nil;
        id catalog = UCFilzaCreateCatalogForFilePath(self.filePath, &error);
        NSArray<NSString *> *names = catalog ? UCFilzaCatalogAllImageNames(catalog) : @[];

        NSMutableDictionary<NSString *, NSNumber *> *overrideCache = [NSMutableDictionary dictionaryWithCapacity:names.count];
        for (NSString *name in names) {
            overrideCache[name] = @(UCFilzaAssetHasOverride(self.filePath, name));
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            [self.loadingIndicator stopAnimating];
            if (!catalog || error) {
                UCFilzaPresentMessage(self, @"读取失败", error.localizedDescription ?: @"无法读取当前 assets.car 内容。");
                return;
            }
            self.cachedCatalog = catalog;
            self.overrideStatusCache = overrideCache;
            self.allAssetNames = names ?: @[];
            [self applySearchText:self.searchController.searchBar.text];
        });
    });
}

- (void)applySearchText:(NSString *)searchText {
    NSString *keyword = [searchText stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (keyword.length == 0) {
        self.visibleAssetNames = self.allAssetNames ?: @[];
    } else {
        NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(NSString *name, __unused NSDictionary *bindings) {
            return [name localizedCaseInsensitiveContainsString:keyword];
        }];
        self.visibleAssetNames = [self.allAssetNames filteredArrayUsingPredicate:predicate];
    }
    [self.collectionView reloadData];
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    [self applySearchText:searchController.searchBar.text];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.visibleAssetNames.count;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    UCFilzaCarAssetGridCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"assetGridCell" forIndexPath:indexPath];
    NSString *assetName = self.visibleAssetNames[indexPath.item];
    UIImage *thumbnail = [self.thumbnailCache objectForKey:assetName];
    BOOL overridden = [self.overrideStatusCache[assetName] boolValue];
    NSString *subtitle = overridden ? @"已替换" : @"原图";
    [cell configureWithTitle:assetName subtitle:subtitle image:thumbnail highlighted:overridden];
    if (!thumbnail) {
        [self requestThumbnailForAssetName:assetName];
    }
    return cell;
}

- (void)requestThumbnailForAssetName:(NSString *)assetName {
    if (assetName.length == 0) return;
    @synchronized (self.loadingThumbnailKeys) {
        if ([self.loadingThumbnailKeys containsObject:assetName]) return;
        [self.loadingThumbnailKeys addObject:assetName];
    }

    NSString *filePath = self.filePath;
    id catalog = self.cachedCatalog;
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        @autoreleasepool {
            CGFloat screenScale = UIScreen.mainScreen.scale > 0.0 ? UIScreen.mainScreen.scale : 2.0;
            UIImage *image = nil;
            if (catalog) {
                image = UCFilzaEffectiveCatalogImage(catalog, filePath, assetName, screenScale, nil);
                if (!image) {
                    image = UCFilzaOriginalCatalogImage(catalog, assetName, screenScale, nil);
                }
            }
            if (!image) {
                image = UCFilzaPreviewImageForCarAsset(filePath, assetName, screenScale);
            }
            UIImage *thumbnail = UCFilzaAspectFitThumbnailImage(image, CGSizeMake(80, 80));
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) self = weakSelf;
                if (!self) return;
                if (thumbnail) {
                    [self.thumbnailCache setObject:thumbnail forKey:assetName];
                }
                @synchronized (self.loadingThumbnailKeys) {
                    [self.loadingThumbnailKeys removeObject:assetName];
                }
                NSUInteger row = [self.visibleAssetNames indexOfObject:assetName];
                if (row != NSNotFound) {
                    NSIndexPath *indexPath = [NSIndexPath indexPathForItem:row inSection:0];
                    if ([[self.collectionView indexPathsForVisibleItems] containsObject:indexPath]) {
                        [self.collectionView reloadItemsAtIndexPaths:@[indexPath]];
                    }
                }
            });
        }
    });
}

- (void)collectionView:(UICollectionView *)collectionView prefetchItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths {
    for (NSIndexPath *indexPath in indexPaths) {
        if (indexPath.item >= self.visibleAssetNames.count) continue;
        NSString *assetName = self.visibleAssetNames[indexPath.item];
        if (![self.thumbnailCache objectForKey:assetName]) {
            [self requestThumbnailForAssetName:assetName];
        }
    }
}

- (void)collectionView:(UICollectionView *)collectionView cancelPrefetchingForItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths {
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    for (NSIndexPath *indexPath in self.collectionView.indexPathsForVisibleItems) {
        if (indexPath.item >= self.visibleAssetNames.count) continue;
        NSString *assetName = self.visibleAssetNames[indexPath.item];
        BOOL overridden = UCFilzaAssetHasOverride(self.filePath, assetName);
        self.overrideStatusCache[assetName] = @(overridden);
        UCFilzaCarAssetGridCell *cell = (UCFilzaCarAssetGridCell *)[self.collectionView cellForItemAtIndexPath:indexPath];
        if (cell) {
            NSString *subtitle = overridden ? @"已替换" : @"原图";
            [cell configureWithTitle:assetName subtitle:subtitle image:[self.thumbnailCache objectForKey:assetName] highlighted:overridden];
        }
    }
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat width = collectionView.bounds.size.width - 16.0;
    NSInteger columns = 6;
    CGFloat itemWidth = floor((width - (columns - 1) * 8.0) / columns);
    return CGSizeMake(MAX(44.0, itemWidth), MAX(44.0, itemWidth + 52.0));
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    NSString *assetName = self.visibleAssetNames[indexPath.item];
    UCFilzaCarAssetDetailViewController *detail = [[UCFilzaCarAssetDetailViewController alloc] initWithFilePath:self.filePath assetName:assetName];
    [self.navigationController pushViewController:detail animated:YES];
}

@end

@interface UCFilzaCarAssetListViewController ()

@property (nonatomic, copy) NSString *filePath;
@property (nonatomic, copy) NSArray<NSString *> *allAssetNames;
@property (nonatomic, copy) NSArray<NSString *> *visibleAssetNames;
@property (nonatomic, strong) UISearchController *searchController;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;

@end

@implementation UCFilzaCarAssetListViewController

- (instancetype)initWithFilePath:(NSString *)filePath {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) {
        _filePath = filePath.stringByStandardizingPath ?: filePath;
        self.title = @"图片资源";
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = UIColor.systemBackgroundColor;
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"assetCell"];

    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchResultsUpdater = self;
    self.searchController.obscuresBackgroundDuringPresentation = NO;
    self.searchController.searchBar.placeholder = @"搜索 assets.car 图片名";
    self.navigationItem.searchController = self.searchController;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
    self.navigationItem.rightBarButtonItems = @[
        [[UIBarButtonItem alloc] initWithTitle:@"网格"
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(openGridTapped)],
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                      target:self
                                                      action:@selector(loadAssets)]
    ];

    self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.loadingIndicator.hidesWhenStopped = YES;
    self.tableView.backgroundView = self.loadingIndicator;
    [self loadAssets];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

- (void)openGridTapped {
    UCFilzaCarAssetGridViewController *controller = [[UCFilzaCarAssetGridViewController alloc] initWithFilePath:self.filePath];
    [self.navigationController pushViewController:controller animated:YES];
}

- (void)loadAssets {
    [self.loadingIndicator startAnimating];
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSError *error = nil;
        id catalog = UCFilzaCreateCatalogForFilePath(self.filePath, &error);
        NSArray<NSString *> *names = catalog ? UCFilzaCatalogAllImageNames(catalog) : @[];
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            [self.loadingIndicator stopAnimating];
            if (!catalog || error) {
                UCFilzaPresentMessage(self, @"读取失败", error.localizedDescription ?: @"无法读取当前 assets.car 内容。");
                return;
            }
            self.allAssetNames = names ?: @[];
            [self applySearchText:self.searchController.searchBar.text];
        });
    });
}

- (void)applySearchText:(NSString *)searchText {
    NSString *keyword = [searchText stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (keyword.length == 0) {
        self.visibleAssetNames = self.allAssetNames ?: @[];
    } else {
        NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(NSString *name, __unused NSDictionary *bindings) {
            return [name localizedCaseInsensitiveContainsString:keyword];
        }];
        self.visibleAssetNames = [self.allAssetNames filteredArrayUsingPredicate:predicate];
    }
    [self.tableView reloadData];
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    [self applySearchText:searchController.searchBar.text];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.visibleAssetNames.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.filePath;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return [NSString stringWithFormat:@"共 %lu 个图片资源。点进去可预览原图 / 当前生效图，并直接替换单张图片。", (unsigned long)self.visibleAssetNames.count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"assetCell"];
    if (!cell || cell.detailTextLabel == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"assetCell"];
    }

    NSString *assetName = self.visibleAssetNames[indexPath.row];
    cell.textLabel.text = assetName;
    cell.textLabel.numberOfLines = 2;
    cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    cell.detailTextLabel.text = UCFilzaAssetHasOverride(self.filePath, assetName) ? @"已存在单图替换" : @"原始资源图";
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

    if (@available(iOS 13.0, *)) {
        cell.imageView.image = [UIImage systemImageNamed:UCFilzaAssetHasOverride(self.filePath, assetName) ? @"photo.badge.checkmark" : @"photo"];
        cell.imageView.tintColor = UCFilzaAssetHasOverride(self.filePath, assetName) ? UIColor.systemGreenColor : UIColor.systemBrownColor;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSString *assetName = self.visibleAssetNames[indexPath.row];
    UCFilzaCarAssetDetailViewController *detail = [[UCFilzaCarAssetDetailViewController alloc] initWithFilePath:self.filePath assetName:assetName];
    [self.navigationController pushViewController:detail animated:YES];
}

@end

@interface UCFilzaCarAssetDetailViewController ()

@property (nonatomic, copy) NSString *filePath;
@property (nonatomic, copy) NSString *assetName;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIImageView *originalImageView;
@property (nonatomic, strong) UIImageView *effectiveImageView;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;

@end

@implementation UCFilzaCarAssetDetailViewController

- (instancetype)initWithFilePath:(NSString *)filePath assetName:(NSString *)assetName {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _filePath = filePath.stringByStandardizingPath ?: filePath;
        _assetName = assetName.copy;
        self.title = assetName;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = UIColor.systemBackgroundColor;
    UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:CGRectZero];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;

    UIView *contentView = [[UIView alloc] initWithFrame:CGRectZero];
    contentView.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *assetLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    assetLabel.translatesAutoresizingMaskIntoConstraints = NO;
    assetLabel.numberOfLines = 0;
    assetLabel.font = [UIFont systemFontOfSize:14];
    assetLabel.text = [NSString stringWithFormat:@"assets.car：%@\n资源名：%@", self.filePath.lastPathComponent ?: self.filePath, self.assetName ?: @""];

    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.font = [UIFont systemFontOfSize:13];
    self.statusLabel.textColor = UIColor.secondaryLabelColor;
    self.statusLabel.text = @"正在读取资源图…";

    UILabel *originalTitle = [[UILabel alloc] initWithFrame:CGRectZero];
    originalTitle.translatesAutoresizingMaskIntoConstraints = NO;
    originalTitle.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    originalTitle.text = @"原始资源图";

    self.originalImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
    self.originalImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.originalImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.originalImageView.backgroundColor = UIColor.secondarySystemBackgroundColor;
    self.originalImageView.layer.cornerRadius = 12.0;
    self.originalImageView.clipsToBounds = YES;

    UILabel *effectiveTitle = [[UILabel alloc] initWithFrame:CGRectZero];
    effectiveTitle.translatesAutoresizingMaskIntoConstraints = NO;
    effectiveTitle.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    effectiveTitle.text = @"当前生效图";

    self.effectiveImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
    self.effectiveImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.effectiveImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.effectiveImageView.backgroundColor = UIColor.secondarySystemBackgroundColor;
    self.effectiveImageView.layer.cornerRadius = 12.0;
    self.effectiveImageView.clipsToBounds = YES;

    UIButton *importButton = [UIButton buttonWithType:UIButtonTypeSystem];
    importButton.translatesAutoresizingMaskIntoConstraints = NO;
    [importButton setTitle:@"导入替换图" forState:UIControlStateNormal];
    [importButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    importButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    importButton.backgroundColor = UIColor.systemBlueColor;
    importButton.layer.cornerRadius = 12.0;
    [importButton addTarget:self action:@selector(importReplacementTapped) forControlEvents:UIControlEventTouchUpInside];

    UIButton *removeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    removeButton.translatesAutoresizingMaskIntoConstraints = NO;
    [removeButton setTitle:@"清除替换图" forState:UIControlStateNormal];
    [removeButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    removeButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    removeButton.backgroundColor = UIColor.systemOrangeColor;
    removeButton.layer.cornerRadius = 12.0;
    [removeButton addTarget:self action:@selector(removeReplacementTapped) forControlEvents:UIControlEventTouchUpInside];

    UIButton *shareButton = [UIButton buttonWithType:UIButtonTypeSystem];
    shareButton.translatesAutoresizingMaskIntoConstraints = NO;
    [shareButton setTitle:@"分享当前生效图" forState:UIControlStateNormal];
    [shareButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    shareButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    shareButton.backgroundColor = UIColor.systemGreenColor;
    shareButton.layer.cornerRadius = 12.0;
    [shareButton addTarget:self action:@selector(shareEffectiveImageTapped) forControlEvents:UIControlEventTouchUpInside];

    self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    [self.loadingIndicator startAnimating];

    [self.view addSubview:scrollView];
    [scrollView addSubview:contentView];
    [contentView addSubview:assetLabel];
    [contentView addSubview:self.statusLabel];
    [contentView addSubview:originalTitle];
    [contentView addSubview:self.originalImageView];
    [contentView addSubview:effectiveTitle];
    [contentView addSubview:self.effectiveImageView];
    [contentView addSubview:importButton];
    [contentView addSubview:removeButton];
    [contentView addSubview:shareButton];
    [contentView addSubview:self.loadingIndicator];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [scrollView.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [scrollView.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor],
        [scrollView.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor],

        [contentView.topAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.topAnchor],
        [contentView.leadingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.leadingAnchor],
        [contentView.trailingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.trailingAnchor],
        [contentView.bottomAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.bottomAnchor],
        [contentView.widthAnchor constraintEqualToAnchor:scrollView.frameLayoutGuide.widthAnchor],

        [assetLabel.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:16],
        [assetLabel.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:16],
        [assetLabel.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-16],

        [self.statusLabel.topAnchor constraintEqualToAnchor:assetLabel.bottomAnchor constant:8],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:assetLabel.leadingAnchor],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:assetLabel.trailingAnchor],

        [originalTitle.topAnchor constraintEqualToAnchor:self.statusLabel.bottomAnchor constant:18],
        [originalTitle.leadingAnchor constraintEqualToAnchor:assetLabel.leadingAnchor],
        [originalTitle.trailingAnchor constraintEqualToAnchor:assetLabel.trailingAnchor],

        [self.originalImageView.topAnchor constraintEqualToAnchor:originalTitle.bottomAnchor constant:8],
        [self.originalImageView.leadingAnchor constraintEqualToAnchor:assetLabel.leadingAnchor],
        [self.originalImageView.trailingAnchor constraintEqualToAnchor:assetLabel.trailingAnchor],
        [self.originalImageView.heightAnchor constraintEqualToConstant:180],

        [effectiveTitle.topAnchor constraintEqualToAnchor:self.originalImageView.bottomAnchor constant:18],
        [effectiveTitle.leadingAnchor constraintEqualToAnchor:assetLabel.leadingAnchor],
        [effectiveTitle.trailingAnchor constraintEqualToAnchor:assetLabel.trailingAnchor],

        [self.effectiveImageView.topAnchor constraintEqualToAnchor:effectiveTitle.bottomAnchor constant:8],
        [self.effectiveImageView.leadingAnchor constraintEqualToAnchor:assetLabel.leadingAnchor],
        [self.effectiveImageView.trailingAnchor constraintEqualToAnchor:assetLabel.trailingAnchor],
        [self.effectiveImageView.heightAnchor constraintEqualToConstant:180],

        [importButton.topAnchor constraintEqualToAnchor:self.effectiveImageView.bottomAnchor constant:22],
        [importButton.leadingAnchor constraintEqualToAnchor:assetLabel.leadingAnchor],
        [importButton.trailingAnchor constraintEqualToAnchor:assetLabel.trailingAnchor],
        [importButton.heightAnchor constraintEqualToConstant:46],

        [removeButton.topAnchor constraintEqualToAnchor:importButton.bottomAnchor constant:12],
        [removeButton.leadingAnchor constraintEqualToAnchor:assetLabel.leadingAnchor],
        [removeButton.trailingAnchor constraintEqualToAnchor:assetLabel.trailingAnchor],
        [removeButton.heightAnchor constraintEqualToConstant:46],

        [shareButton.topAnchor constraintEqualToAnchor:removeButton.bottomAnchor constant:12],
        [shareButton.leadingAnchor constraintEqualToAnchor:assetLabel.leadingAnchor],
        [shareButton.trailingAnchor constraintEqualToAnchor:assetLabel.trailingAnchor],
        [shareButton.heightAnchor constraintEqualToConstant:46],

        [shareButton.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-24],

        [self.loadingIndicator.centerXAnchor constraintEqualToAnchor:self.originalImageView.centerXAnchor],
        [self.loadingIndicator.centerYAnchor constraintEqualToAnchor:self.originalImageView.centerYAnchor],
    ]];

    [self refreshPreview];
}

- (void)refreshPreview {
    [self.loadingIndicator startAnimating];
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSError *error = nil;
        id catalog = UCFilzaCreateCatalogForFilePath(self.filePath, &error);
        UIImage *originalImage = catalog ? UCFilzaOriginalCatalogImage(catalog, self.assetName, UIScreen.mainScreen.scale ?: 2.0, nil) : nil;
        UIImage *effectiveImage = catalog ? UCFilzaEffectiveCatalogImage(catalog, self.filePath, self.assetName, UIScreen.mainScreen.scale ?: 2.0, nil) : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            [self.loadingIndicator stopAnimating];
            if (!catalog || error) {
                self.statusLabel.text = error.localizedDescription ?: @"无法读取当前图片资源。";
                self.originalImageView.image = nil;
                self.effectiveImageView.image = nil;
                return;
            }
            self.originalImageView.image = originalImage;
            self.effectiveImageView.image = effectiveImage ?: originalImage;

            NSMutableArray<NSString *> *parts = [NSMutableArray array];
            [parts addObject:UCFilzaAssetHasOverride(self.filePath, self.assetName) ? @"当前资源已存在单图替换，运行时优先生效。" : @"当前资源未设置单图替换。"];
            if (!originalImage) {
                [parts addObject:@"原始图预览失败，可能是当前条目不是普通位图资源。"];
            }
            self.statusLabel.text = [parts componentsJoinedByString:@"\n"];
        });
    });
}

- (void)importReplacementTapped {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"导入替换图"
                                                                 message:@"选择图片来源"
                                                          preferredStyle:UIAlertControllerStyleActionSheet];

    [sheet addAction:[UIAlertAction actionWithTitle:@"从照片选择" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [self presentPhotoLibraryPicker];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:@"从文件选择" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [self presentDocumentPicker];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];

    if (sheet.popoverPresentationController) {
        sheet.popoverPresentationController.sourceView = self.view;
        sheet.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMaxY(self.view.bounds) - 60, 1, 1);
        sheet.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionDown;
    }
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)presentPhotoLibraryPicker {

    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
    if (status == PHAuthorizationStatusNotDetermined) {
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus result) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (result == PHAuthorizationStatusAuthorized) {
                    [self presentImagePickerController];
                } else {
                    UCFilzaPresentMessage(self, @"无法访问照片", @"请在设置中允许访问照片库。");
                }
            });
        }];
        return;
    }
    if (status != PHAuthorizationStatusAuthorized) {
        UCFilzaPresentMessage(self, @"无法访问照片", @"请在设置中允许访问照片库。");
        return;
    }
    [self presentImagePickerController];
}

- (void)presentImagePickerController {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.delegate = self;
    picker.modalPresentationStyle = UIModalPresentationFormSheet;
    picker.allowsEditing = NO;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)presentDocumentPicker {
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.image"] inMode:UIDocumentPickerModeImport];
    picker.delegate = self;
    picker.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:picker animated:YES completion:nil];
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey, id> *)info {
    [picker dismissViewControllerAnimated:YES completion:^{
        UIImage *image = info[UIImagePickerControllerOriginalImage];
        if (!image) {
            UCFilzaPresentMessage(self, @"导入失败", @"无法获取所选照片。");
            return;
        }
        [self handleImportedImage:image];
    }];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - 图片保存处理

- (void)handleImportedImage:(UIImage *)image {

    NSData *imageData = UIImagePNGRepresentation(image);
    NSString *ext = @"png";

    if (!imageData || imageData.length == 0) {
        imageData = UIImageJPEGRepresentation(image, 0.9);
        ext = @"jpg";
    }
    if (!imageData || imageData.length == 0) {
        UCFilzaPresentMessage(self, @"导入失败", @"无法将所选图片转换为可用格式。");
        return;
    }

    NSString *tempFileName = [NSString stringWithFormat:@"filza_import_%@.%@", NSUUID.UUID.UUIDString, ext];
    NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:tempFileName];
    NSURL *tempURL = [NSURL fileURLWithPath:tempPath];

    NSError *writeError = nil;
    BOOL written = [imageData writeToURL:tempURL options:NSDataWritingAtomic error:&writeError];
    if (!written || writeError) {
        UCFilzaPresentMessage(self, @"导入失败", writeError.localizedDescription ?: @"无法写入临时文件。");
        return;
    }

    NSError *error = nil;
    BOOL saved = UCFilzaSaveAssetOverrideFromURL(self.filePath, self.assetName, tempURL, &error);

    [[NSFileManager defaultManager] removeItemAtPath:tempPath error:nil];

    if (!saved || error) {
        UCFilzaPresentMessage(self, @"替换失败", error.localizedDescription ?: @"无法保存当前替换图片。");
        return;
    }
    [self refreshPreview];
    UCFilzaPresentTransientMessage(self, @"替换成功", self.assetName);
}

- (void)removeReplacementTapped {
    NSError *error = nil;
    BOOL ok = UCFilzaRemoveAssetOverride(self.filePath, self.assetName, &error);
    if (!ok || error) {
        UCFilzaPresentMessage(self, @"清除失败", error.localizedDescription ?: @"无法清除当前图片替换。");
        return;
    }
    [self refreshPreview];
    UCFilzaPresentTransientMessage(self, @"已清除", self.assetName);
}

- (void)shareEffectiveImageTapped {
    UIImage *image = self.effectiveImageView.image ?: self.originalImageView.image;
    if (!image) {
        UCFilzaPresentMessage(self, @"无法分享", @"当前没有可分享的图片内容。");
        return;
    }

    NSData *pngData = UIImagePNGRepresentation(image);
    if (!pngData.length) {
        UCFilzaPresentMessage(self, @"无法分享", @"当前图片无法导出为 PNG。");
        return;
    }

    NSString *fileName = [NSString stringWithFormat:@"%@.png", self.assetName.length ? self.assetName : @"asset"];
    NSString *safeFileName = [fileName stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    NSString *outputPath = [NSTemporaryDirectory() stringByAppendingPathComponent:safeFileName];
    [pngData writeToFile:outputPath atomically:YES];

    NSURL *fileURL = [NSURL fileURLWithPath:outputPath];
    UIActivityViewController *activity = [[UIActivityViewController alloc] initWithActivityItems:@[fileURL] applicationActivities:nil];
    UIPopoverPresentationController *popover = activity.popoverPresentationController;
    if (popover) {
        popover.sourceView = self.view;
        popover.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1);
        popover.permittedArrowDirections = 0;
    }
    [self presentViewController:activity animated:YES completion:nil];
}

- (void)handleImportedImageURL:(NSURL *)url {
    if (!url) return;
    NSError *error = nil;
    BOOL saved = UCFilzaSaveAssetOverrideFromURL(self.filePath, self.assetName, url, &error);
    if (!saved || error) {
        UCFilzaPresentMessage(self, @"替换失败", error.localizedDescription ?: @"无法保存当前替换图片。");
        return;
    }
    [self refreshPreview];
    UCFilzaPresentTransientMessage(self, @"替换成功", self.assetName);
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls API_AVAILABLE(ios(11.0)) {
    [self handleImportedImageURL:urls.firstObject];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentAtURL:(NSURL *)url {
    [self handleImportedImageURL:url];
}

@end

@interface UCFilzaCarManagerViewController ()

@property (nonatomic, copy) NSString *filePath;
@property (nonatomic, strong) UILabel *infoLabel;
@property (nonatomic, strong) UILabel *noteLabel;

@end

@implementation UCFilzaCarManagerViewController

- (instancetype)initWithFilePath:(NSString *)filePath {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _filePath = filePath.stringByStandardizingPath ?: filePath;
        self.title = _filePath.lastPathComponent;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = UIColor.systemBackgroundColor;

    self.infoLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.infoLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.infoLabel.numberOfLines = 0;
    self.infoLabel.font = [UIFont systemFontOfSize:14];
    self.infoLabel.textColor = UIColor.labelColor;

    self.noteLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.noteLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.noteLabel.numberOfLines = 0;
    self.noteLabel.font = [UIFont systemFontOfSize:13];
    self.noteLabel.textColor = UIColor.secondaryLabelColor;
    self.noteLabel.text = @"这是 assets.car 专用管理页。整包替换会直接覆盖当前文件并自动备份；图片资源列表支持查看内容和单图替换，单图替换会保存为运行时覆盖图，不直接重写 car 二进制。";

    UIButton *importButton = [self actionButtonWithTitle:@"替换导入 assets.car" color:UIColor.systemBlueColor action:@selector(importReplacementTapped)];
    UIButton *browseButton = [self actionButtonWithTitle:@"查看图片资源 / 替换单图" color:UIColor.systemTealColor action:@selector(browseAssetsTapped)];
    UIButton *backupButton = [self actionButtonWithTitle:@"备份当前 assets.car" color:UIColor.systemOrangeColor action:@selector(backupTapped)];
    UIButton *editButton = [self actionButtonWithTitle:@"HEX 查看 / 编辑" color:UIColor.systemPurpleColor action:@selector(openHexEditorTapped)];
    UIButton *shareButton = [self actionButtonWithTitle:@"分享当前文件" color:UIColor.systemGreenColor action:@selector(shareTapped)];

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[importButton, browseButton, backupButton, editButton, shareButton]];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 14;
    for (UIButton *button in stack.arrangedSubviews) {
        [button.heightAnchor constraintEqualToConstant:46].active = YES;
    }

    [self.view addSubview:self.infoLabel];
    [self.view addSubview:self.noteLabel];
    [self.view addSubview:stack];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.infoLabel.topAnchor constraintEqualToAnchor:safe.topAnchor constant:18],
        [self.infoLabel.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:18],
        [self.infoLabel.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-18],

        [self.noteLabel.topAnchor constraintEqualToAnchor:self.infoLabel.bottomAnchor constant:12],
        [self.noteLabel.leadingAnchor constraintEqualToAnchor:self.infoLabel.leadingAnchor],
        [self.noteLabel.trailingAnchor constraintEqualToAnchor:self.infoLabel.trailingAnchor],

        [stack.topAnchor constraintEqualToAnchor:self.noteLabel.bottomAnchor constant:22],
        [stack.leadingAnchor constraintEqualToAnchor:self.infoLabel.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:self.infoLabel.trailingAnchor],
    ]];

    [self refreshInfo];
}

- (UIButton *)actionButtonWithTitle:(NSString *)title color:(UIColor *)color action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    button.backgroundColor = color;
    button.layer.cornerRadius = 12.0;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)refreshInfo {
    NSDictionary<NSFileAttributeKey, id> *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:self.filePath error:nil];
    NSString *sizeText = UCFilzaByteCountString([attributes fileSize]);
    NSString *timeText = attributes.fileModificationDate ? [UCFilzaDateFormatter() stringFromDate:attributes.fileModificationDate] : @"未知时间";
    self.infoLabel.text = [NSString stringWithFormat:@"路径：%@\n大小：%@\n修改时间：%@", self.filePath, sizeText, timeText];
}

- (void)importReplacementTapped {
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.data"] inMode:UIDocumentPickerModeImport];
    picker.delegate = self;
    picker.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)backupTapped {
    NSError *error = nil;
    NSString *backupPath = [self backupCurrentFileWithError:&error];
    if (!backupPath.length || error) {
        UCFilzaPresentMessage(self, @"备份失败", error.localizedDescription ?: @"无法备份当前 assets.car。");
        return;
    }
    UCFilzaPresentMessage(self, @"备份成功", backupPath);
}

- (void)browseAssetsTapped {
    UCFilzaCarAssetListViewController *controller = [[UCFilzaCarAssetListViewController alloc] initWithFilePath:self.filePath];
    [self.navigationController pushViewController:controller animated:YES];
}

- (void)openHexEditorTapped {
    UCFilzaEditorViewController *editor = [[UCFilzaEditorViewController alloc] initWithFilePath:self.filePath];
    [self.navigationController pushViewController:editor animated:YES];
}

- (void)shareTapped {
    NSURL *fileURL = [NSURL fileURLWithPath:self.filePath];
    UIActivityViewController *activity = [[UIActivityViewController alloc] initWithActivityItems:@[fileURL] applicationActivities:nil];
    UIPopoverPresentationController *popover = activity.popoverPresentationController;
    if (popover) {
        popover.sourceView = self.view;
        popover.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1);
        popover.permittedArrowDirections = 0;
    }
    [self presentViewController:activity animated:YES completion:nil];
}

- (NSString *)backupCurrentFileWithError:(NSError **)error {
    NSString *backupPath = UCFilzaBackupPathForOriginalPath(self.filePath);
    BOOL copied = [NSFileManager.defaultManager copyItemAtPath:self.filePath toPath:backupPath error:error];
    return copied ? backupPath : nil;
}

- (void)handleImportedURL:(NSURL *)url {
    if (!url) return;

    NSString *ext = url.path.pathExtension.lowercaseString ?: @"";
    if (![ext isEqualToString:@"car"]) {
        UCFilzaPresentMessage(self, @"导入失败", @"请选择 .car 文件进行替换导入。");
        return;
    }

    BOOL accessing = [url respondsToSelector:@selector(startAccessingSecurityScopedResource)] ? [url startAccessingSecurityScopedResource] : NO;
    NSError *readError = nil;
    NSData *data = [NSData dataWithContentsOfURL:url options:0 error:&readError];
    if (accessing) {
        [url stopAccessingSecurityScopedResource];
    }

    if (!data.length || readError) {
        UCFilzaPresentMessage(self, @"读取导入文件失败", readError.localizedDescription ?: @"无法读取所选 .car 文件。");
        return;
    }

    NSError *backupError = nil;
    NSString *backupPath = [self backupCurrentFileWithError:&backupError];
    if (!backupPath.length || backupError) {
        UCFilzaPresentMessage(self, @"导入失败", backupError.localizedDescription ?: @"备份原始 assets.car 失败。");
        return;
    }

    NSError *writeError = nil;
    BOOL written = [data writeToFile:self.filePath options:NSDataWritingAtomic error:&writeError];
    if (!written || writeError) {
        UCFilzaPresentMessage(self, @"导入失败", writeError.localizedDescription ?: @"覆盖写入 assets.car 失败。");
        return;
    }

    [self refreshInfo];
    UCFilzaPresentMessage(self, @"导入成功", [NSString stringWithFormat:@"已替换当前 assets.car\n备份文件：%@", backupPath.lastPathComponent ?: backupPath]);
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls API_AVAILABLE(ios(11.0)) {
    [self handleImportedURL:urls.firstObject];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentAtURL:(NSURL *)url {
    [self handleImportedURL:url];
}

@end

@interface UCFilzaEditorViewController ()

@property (nonatomic, copy) NSString *filePath;
@property (nonatomic, strong) UILabel *infoLabel;
@property (nonatomic, strong) UITextView *textView;
@property (nonatomic, strong) UISegmentedControl *modeControl;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, strong) NSData *originalData;
@property (nonatomic, assign) NSStringEncoding textEncoding;
@property (nonatomic, assign) UCFilzaContentKind contentKind;
@property (nonatomic, assign) NSPropertyListFormat plistFormat;
@property (nonatomic, assign) UCFilzaEditorMode currentMode;
@property (nonatomic, assign) BOOL hasTextMode;
@property (nonatomic, copy) NSString *cachedTextContent;
@property (nonatomic, copy) NSString *cachedHexContent;

@end

@implementation UCFilzaEditorViewController

- (instancetype)initWithFilePath:(NSString *)filePath {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _filePath = filePath.stringByStandardizingPath ?: filePath;
        self.title = _filePath.lastPathComponent;
        _textEncoding = NSUTF8StringEncoding;
        _plistFormat = NSPropertyListXMLFormat_v1_0;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = UIColor.systemBackgroundColor;

    self.navigationItem.rightBarButtonItems = @[
        [[UIBarButtonItem alloc] initWithTitle:@"保存"
                                         style:UIBarButtonItemStyleDone
                                        target:self
                                        action:@selector(saveTapped)],
        [[UIBarButtonItem alloc] initWithTitle:@"更多"
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(showMoreActions:)]
    ];

    self.infoLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.infoLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.infoLabel.numberOfLines = 0;
    self.infoLabel.font = [UIFont systemFontOfSize:12];
    self.infoLabel.textColor = UIColor.secondaryLabelColor;
    self.infoLabel.text = @"正在读取文件…";

    self.modeControl = [[UISegmentedControl alloc] initWithItems:@[@"文本", @"HEX"]];
    self.modeControl.translatesAutoresizingMaskIntoConstraints = NO;
    self.modeControl.selectedSegmentIndex = 0;
    [self.modeControl addTarget:self action:@selector(modeControlChanged:) forControlEvents:UIControlEventValueChanged];

    self.textView = [[UITextView alloc] initWithFrame:CGRectZero];
    self.textView.translatesAutoresizingMaskIntoConstraints = NO;
    self.textView.backgroundColor = UIColor.secondarySystemBackgroundColor;
    self.textView.textColor = UIColor.labelColor;
    self.textView.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightRegular];
    self.textView.autocorrectionType = UITextAutocorrectionTypeNo;
    self.textView.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.textView.smartDashesType = UITextSmartDashesTypeNo;
    self.textView.smartQuotesType = UITextSmartQuotesTypeNo;
    self.textView.smartInsertDeleteType = UITextSmartInsertDeleteTypeNo;
    self.textView.layer.cornerRadius = 12.0;
    self.textView.text = @"正在读取文件…";

    self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    [self.loadingIndicator startAnimating];

    [self.view addSubview:self.infoLabel];
    [self.view addSubview:self.modeControl];
    [self.view addSubview:self.textView];
    [self.view addSubview:self.loadingIndicator];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.infoLabel.topAnchor constraintEqualToAnchor:safe.topAnchor constant:12],
        [self.infoLabel.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:16],
        [self.infoLabel.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-16],

        [self.modeControl.topAnchor constraintEqualToAnchor:self.infoLabel.bottomAnchor constant:10],
        [self.modeControl.leadingAnchor constraintEqualToAnchor:self.infoLabel.leadingAnchor],
        [self.modeControl.trailingAnchor constraintEqualToAnchor:self.infoLabel.trailingAnchor],

        [self.textView.topAnchor constraintEqualToAnchor:self.modeControl.bottomAnchor constant:12],
        [self.textView.leadingAnchor constraintEqualToAnchor:self.infoLabel.leadingAnchor],
        [self.textView.trailingAnchor constraintEqualToAnchor:self.infoLabel.trailingAnchor],
        [self.textView.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-12],

        [self.loadingIndicator.centerXAnchor constraintEqualToAnchor:self.textView.centerXAnchor],
        [self.loadingIndicator.centerYAnchor constraintEqualToAnchor:self.textView.centerYAnchor],
    ]];

    [self loadFileContent];
}

- (void)loadFileContent {
    self.textView.editable = NO;
    self.navigationItem.rightBarButtonItems.firstObject.enabled = NO;
    [self.loadingIndicator startAnimating];

    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSError *readError = nil;
        NSData *data = [NSData dataWithContentsOfFile:self.filePath options:0 error:&readError];

        NSStringEncoding detectedEncoding = NSUTF8StringEncoding;
        UCFilzaContentKind contentKind = UCFilzaContentKindBinary;
        NSPropertyListFormat plistFormat = NSPropertyListXMLFormat_v1_0;
        NSString *textContent = nil;
        NSString *hexContent = nil;
        BOOL hasTextMode = NO;
        UCFilzaEditorMode mode = UCFilzaEditorModeHex;

        if (!readError) {
            NSString *extension = self.filePath.pathExtension.lowercaseString;
            if ([extension isEqualToString:@"json"]) {
                textContent = UCFilzaPrettyJSONStringFromData(data);
                if (textContent) {
                    contentKind = UCFilzaContentKindJSON;
                    hasTextMode = YES;
                    mode = UCFilzaEditorModeText;
                    detectedEncoding = NSUTF8StringEncoding;
                }
            }

            if (!textContent && [@[@"plist", @"strings"] containsObject:extension]) {
                textContent = UCFilzaPrettyPropertyListStringFromData(data, &plistFormat);
                if (textContent) {
                    contentKind = UCFilzaContentKindPropertyList;
                    hasTextMode = YES;
                    mode = UCFilzaEditorModeText;
                    detectedEncoding = NSUTF8StringEncoding;
                }
            }

            if (!textContent) {
                NSString *decoded = UCFilzaDecodedStringFromData(data, &detectedEncoding);
                if (decoded) {
                    textContent = decoded;
                    contentKind = UCFilzaContentKindPlainText;
                    hasTextMode = YES;
                    mode = UCFilzaEditorModeText;
                }
            }

            if (!hasTextMode) {
                hexContent = UCFilzaHexStringFromData(data ?: NSData.data);
                contentKind = UCFilzaContentKindBinary;
                mode = UCFilzaEditorModeHex;
            }
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;

            [self.loadingIndicator stopAnimating];

            if (readError) {
                self.infoLabel.text = [NSString stringWithFormat:@"读取失败：%@", readError.localizedDescription ?: @"未知错误"];
                self.textView.text = @"";
                self.modeControl.enabled = NO;
                return;
            }

            self.originalData = data ?: NSData.data;
            self.textEncoding = detectedEncoding;
            self.contentKind = contentKind;
            self.plistFormat = plistFormat;
            self.hasTextMode = hasTextMode;
            self.currentMode = mode;
            self.cachedTextContent = textContent;
            self.cachedHexContent = hexContent;

            NSDictionary<NSFileAttributeKey, id> *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:self.filePath error:nil];
            NSString *sizeText = UCFilzaByteCountString([attributes fileSize]);
            NSString *timeText = attributes.fileModificationDate ? [UCFilzaDateFormatter() stringFromDate:attributes.fileModificationDate] : @"未知时间";
            NSString *modeText = hasTextMode ? @"文本 / HEX 可切换" : @"仅 HEX 编辑";
            self.infoLabel.text = [NSString stringWithFormat:@"%@\n%@ · %@", self.filePath, sizeText, timeText];

            self.modeControl.enabled = YES;
            self.modeControl.selectedSegmentIndex = hasTextMode ? mode : UCFilzaEditorModeHex;
            self.modeControl.hidden = NO;
            [self.modeControl setEnabled:hasTextMode forSegmentAtIndex:0];
            [self.modeControl setEnabled:YES forSegmentAtIndex:1];
            self.modeControl.accessibilityLabel = modeText;

            [self refreshTextViewForCurrentMode];
            self.textView.editable = YES;
            self.navigationItem.rightBarButtonItems.firstObject.enabled = YES;
        });
    });
}

- (void)refreshTextViewForCurrentMode {
    if (self.currentMode == UCFilzaEditorModeText) {
        self.textView.text = self.cachedTextContent ?: @"";
    } else {
        if (!self.cachedHexContent) {
            NSData *sourceData = self.originalData ?: NSData.data;
            self.cachedHexContent = UCFilzaHexStringFromData(sourceData);
        }
        self.textView.text = self.cachedHexContent ?: @"";
    }
}

- (NSData *)dataFromTextContent:(NSString *)text error:(NSError **)error {
    NSString *safeText = text ?: @"";
    switch (self.contentKind) {
        case UCFilzaContentKindJSON: {
            NSData *textData = [safeText dataUsingEncoding:NSUTF8StringEncoding];
            id jsonObject = [NSJSONSerialization JSONObjectWithData:textData options:NSJSONReadingMutableContainers error:error];
            if (!jsonObject || ![NSJSONSerialization isValidJSONObject:jsonObject]) return nil;
            NSJSONWritingOptions options = NSJSONWritingPrettyPrinted;
            if (@available(iOS 11.0, *)) {
                options |= NSJSONWritingSortedKeys;
            }
            return [NSJSONSerialization dataWithJSONObject:jsonObject options:options error:error];
        }
        case UCFilzaContentKindPropertyList: {
            NSData *textData = [safeText dataUsingEncoding:NSUTF8StringEncoding];
            id plistObject = [NSPropertyListSerialization propertyListWithData:textData options:NSPropertyListMutableContainersAndLeaves format:nil error:error];
            if (!plistObject) return nil;
            NSPropertyListFormat outputFormat = self.plistFormat == NSPropertyListBinaryFormat_v1_0 ? NSPropertyListBinaryFormat_v1_0 : NSPropertyListXMLFormat_v1_0;
            return [NSPropertyListSerialization dataWithPropertyList:plistObject format:outputFormat options:0 error:error];
        }
        case UCFilzaContentKindPlainText: {
            NSData *textData = [safeText dataUsingEncoding:self.textEncoding allowLossyConversion:NO];
            if (!textData) {
                textData = [safeText dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
            }
            if (!textData && error) {
                *error = [NSError errorWithDomain:@"UCFilzaTool"
                                             code:1004
                                         userInfo:@{NSLocalizedDescriptionKey: @"当前文本无法按原编码保存。"}];
            }
            return textData;
        }
        case UCFilzaContentKindBinary:
        default:
            return [safeText dataUsingEncoding:NSUTF8StringEncoding];
    }
}

- (NSString *)textContentFromData:(NSData *)data error:(NSError **)error {
    switch (self.contentKind) {
        case UCFilzaContentKindJSON: {
            NSString *prettyJSON = UCFilzaPrettyJSONStringFromData(data);
            if (!prettyJSON && error) {
                *error = [NSError errorWithDomain:@"UCFilzaTool"
                                             code:1005
                                         userInfo:@{NSLocalizedDescriptionKey: @"HEX 内容转换后不是合法 JSON。"}];
            }
            return prettyJSON;
        }
        case UCFilzaContentKindPropertyList: {
            NSPropertyListFormat format = self.plistFormat;
            NSString *prettyPlist = UCFilzaPrettyPropertyListStringFromData(data, &format);
            if (!prettyPlist && error) {
                *error = [NSError errorWithDomain:@"UCFilzaTool"
                                             code:1006
                                         userInfo:@{NSLocalizedDescriptionKey: @"HEX 内容转换后不是合法 plist。"}];
            }
            return prettyPlist;
        }
        case UCFilzaContentKindPlainText: {
            NSStringEncoding encoding = self.textEncoding;
            NSString *decoded = UCFilzaDecodedStringFromData(data, &encoding);
            if (!decoded && error) {
                *error = [NSError errorWithDomain:@"UCFilzaTool"
                                             code:1007
                                         userInfo:@{NSLocalizedDescriptionKey: @"HEX 内容转换后无法按文本读取。"}];
            }
            if (decoded) self.textEncoding = encoding;
            return decoded;
        }
        case UCFilzaContentKindBinary:
        default:
            if (error) {
                *error = [NSError errorWithDomain:@"UCFilzaTool"
                                             code:1008
                                         userInfo:@{NSLocalizedDescriptionKey: @"该文件当前只有十六进制编辑模式。"}];
            }
            return nil;
    }
}

- (NSData *)currentEditorDataWithError:(NSError **)error {
    if (self.currentMode == UCFilzaEditorModeHex) {
        return UCFilzaDataFromHexString(self.textView.text ?: @"", error);
    }
    return [self dataFromTextContent:self.textView.text error:error];
}

- (void)modeControlChanged:(UISegmentedControl *)control {
    UCFilzaEditorMode targetMode = (UCFilzaEditorMode)control.selectedSegmentIndex;
    if (targetMode == self.currentMode) return;

    NSError *conversionError = nil;
    if (targetMode == UCFilzaEditorModeHex) {
        NSData *currentData = [self dataFromTextContent:self.textView.text error:&conversionError];
        if (!currentData) {
            control.selectedSegmentIndex = self.currentMode;
            UCFilzaPresentMessage(self, @"切换失败", conversionError.localizedDescription ?: @"无法转换为十六进制内容。");
            return;
        }
        self.cachedTextContent = self.textView.text ?: @"";
        self.cachedHexContent = UCFilzaHexStringFromData(currentData);
    } else {
        NSData *currentData = UCFilzaDataFromHexString(self.textView.text ?: @"", &conversionError);
        if (!currentData) {
            control.selectedSegmentIndex = self.currentMode;
            UCFilzaPresentMessage(self, @"切换失败", conversionError.localizedDescription ?: @"无法解析十六进制内容。");
            return;
        }
        NSString *textContent = [self textContentFromData:currentData error:&conversionError];
        if (!textContent) {
            control.selectedSegmentIndex = self.currentMode;
            UCFilzaPresentMessage(self, @"切换失败", conversionError.localizedDescription ?: @"无法转换为文本内容。");
            return;
        }
        self.cachedHexContent = self.textView.text ?: @"";
        self.cachedTextContent = textContent;
    }

    self.currentMode = targetMode;
    [self refreshTextViewForCurrentMode];
}

- (void)saveTapped {
    NSError *saveError = nil;
    NSData *data = [self currentEditorDataWithError:&saveError];
    if (!data) {
        UCFilzaPresentMessage(self, @"保存失败", saveError.localizedDescription ?: @"无法生成要保存的文件内容。");
        return;
    }

    BOOL ok = [data writeToFile:self.filePath options:NSDataWritingAtomic error:&saveError];
    if (!ok || saveError) {
        UCFilzaPresentMessage(self, @"保存失败", saveError.localizedDescription ?: @"写入文件失败。");
        return;
    }

    self.originalData = data;
    if (self.currentMode == UCFilzaEditorModeText) {
        self.cachedTextContent = self.textView.text ?: @"";
        self.cachedHexContent = nil;
    } else {
        self.cachedHexContent = self.textView.text ?: @"";
        if (self.hasTextMode) {
            NSString *textContent = [self textContentFromData:data error:nil];
            if (textContent) self.cachedTextContent = textContent;
        }
    }

    NSDictionary<NSFileAttributeKey, id> *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:self.filePath error:nil];
    NSString *sizeText = UCFilzaByteCountString([attributes fileSize]);
    NSString *timeText = attributes.fileModificationDate ? [UCFilzaDateFormatter() stringFromDate:attributes.fileModificationDate] : @"未知时间";
    self.infoLabel.text = [NSString stringWithFormat:@"%@\n%@ · %@", self.filePath, sizeText, timeText];

    UCFilzaPresentTransientMessage(self, @"保存成功", self.filePath.lastPathComponent);
}

- (void)showMoreActions:(UIBarButtonItem *)sender {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:self.filePath.lastPathComponent
                                                                   message:self.filePath
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    if (self.hasTextMode) {
        NSString *toggleTitle = self.currentMode == UCFilzaEditorModeText ? @"切换到 HEX 模式" : @"切换到文本模式";
        [sheet addAction:[UIAlertAction actionWithTitle:toggleTitle style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            self.modeControl.selectedSegmentIndex = self.currentMode == UCFilzaEditorModeText ? UCFilzaEditorModeHex : UCFilzaEditorModeText;
            [self modeControlChanged:self.modeControl];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"重新读取文件" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [self loadFileContent];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"复制文件路径" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        UIPasteboard.generalPasteboard.string = self.filePath;
        UCFilzaPresentTransientMessage(self, @"已复制路径", self.filePath);
    }]];
    if (UCFilzaIsAssetsCarPath(self.filePath)) {
        [sheet addAction:[UIAlertAction actionWithTitle:@"查看 assets.car 图片资源" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            UCFilzaCarAssetListViewController *controller = [[UCFilzaCarAssetListViewController alloc] initWithFilePath:self.filePath];
            [self.navigationController pushViewController:controller animated:YES];
        }]];
        [sheet addAction:[UIAlertAction actionWithTitle:@"打开 assets.car 导入页" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            UCFilzaCarManagerViewController *manager = [[UCFilzaCarManagerViewController alloc] initWithFilePath:self.filePath];
            [self.navigationController pushViewController:manager animated:YES];
        }]];
    }
    if (UCFilzaIsSQLitePath(self.filePath)) {
        [sheet addAction:[UIAlertAction actionWithTitle:@"打开 SQLite 查看器" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            FLEXTableListViewController *controller = [[FLEXTableListViewController alloc] initWithPath:self.filePath];
            [self.navigationController pushViewController:controller animated:YES];
        }]];
    }
    if (UCFilzaIsZIPPath(self.filePath)) {
        [sheet addAction:[UIAlertAction actionWithTitle:@"打开 ZIP 浏览器" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            UCFilzaZipBrowserViewController *controller = [[UCFilzaZipBrowserViewController alloc] initWithZipPath:self.filePath title:self.filePath.lastPathComponent prefix:@"" archive:nil];
            [self.navigationController pushViewController:controller animated:YES];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"分享文件" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        NSURL *fileURL = [NSURL fileURLWithPath:self.filePath];
        UIActivityViewController *activity = [[UIActivityViewController alloc] initWithActivityItems:@[fileURL] applicationActivities:nil];
        UIPopoverPresentationController *popover = activity.popoverPresentationController;
        if (popover) {
            popover.barButtonItem = sender;
        }
        [self presentViewController:activity animated:YES completion:nil];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];

    UIPopoverPresentationController *popover = sheet.popoverPresentationController;
    if (popover) {
        popover.barButtonItem = sender;
    }
    [self presentViewController:sheet animated:YES completion:nil];
}

@end

@implementation UCFilzaTool

+ (void)load {
    UCFilzaInstallCoreUIHooks();
}

+ (void)presentFilzaPanelFromViewController:(UIViewController *)viewController {
    if (!viewController) return;

    UCFilzaAppInfoViewController *root = [[UCFilzaAppInfoViewController alloc] initWithStyle:UITableViewStyleInsetGrouped];
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:root];
    navigationController.modalPresentationStyle = UIModalPresentationFormSheet;
    navigationController.preferredContentSize = CGSizeMake(430, 640);
    [viewController presentViewController:navigationController animated:YES completion:nil];
}

@end
