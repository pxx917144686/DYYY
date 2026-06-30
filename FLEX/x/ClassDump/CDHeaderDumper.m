#import "CDHeaderDumper.h"
#import "CDZipWriter.h"
#import "CDSwiftDumper.h"
#import <objc/runtime.h>
#import <mach-o/dyld.h>

static NSString *CDSafeFileName(NSString *name) {
    NSMutableString *s = [name mutableCopy];
    NSArray *bad = @[@"/", @":", @"*", @"?", @"\"", @"<", @">", @"|", @"\\"];
    for (NSString *b in bad) {
        [s replaceOccurrencesOfString:b withString:@"_" options:0 range:NSMakeRange(0, s.length)];
    }
    return s;
}

static BOOL CDIsLikelySwiftName(NSString *name) {
    if (name.length == 0) return YES;

    if ([name hasPrefix:@"_Tt"]) return YES;
    if ([name hasPrefix:@"Swift."]) return YES;
    if ([name hasPrefix:@"SwiftUI."]) return YES;
    if ([name containsString:@"<"]) return YES;
    if ([name containsString:@"`"]) return YES;

    if ([name containsString:@"."]) return YES;

    return NO;
}

static BOOL CDShouldSkipImage(NSString *imagePath) {
    if (imagePath.length == 0) return YES;

    if ([imagePath hasPrefix:@"/System/"]) return YES;
    if ([imagePath hasPrefix:@"/usr/lib/"]) return YES;

    NSString *bundlePath = NSBundle.mainBundle.bundlePath ?: @"";
    NSString *container = [bundlePath stringByDeletingLastPathComponent];

    if ([imagePath hasPrefix:bundlePath]) return NO;
    if ([imagePath hasPrefix:container] && ([imagePath containsString:@"/Frameworks/"] ||
                                            [imagePath containsString:@"/PlugIns/"] ||
                                            [imagePath containsString:@"/Extensions/"])) {
        return NO;
    }

    return YES;
}

static NSString *CDTypeFromEncoding(const char *encoding) {
    if (!encoding) return @"id";

    NSString *e = [NSString stringWithUTF8String:encoding];
    if (e.length == 0) return @"id";

    if ([e hasPrefix:@"@\""]) {
        NSRange r1 = [e rangeOfString:@"\""];
        NSRange r2 = [e rangeOfString:@"\"" options:NSBackwardsSearch];
        if (r1.location != NSNotFound && r2.location != NSNotFound && r2.location > r1.location) {
            NSString *cls = [e substringWithRange:NSMakeRange(r1.location + 1, r2.location - r1.location - 1)];
            if (cls.length) return [NSString stringWithFormat:@"%@ *", cls];
        }
    }

    unichar c = [e characterAtIndex:0];
    switch (c) {
        case 'v': return @"void";
        case '@': return @"id";
        case '#': return @"Class";
        case ':': return @"SEL";
        case 'c': return @"char";
        case 'C': return @"unsigned char";
        case 's': return @"short";
        case 'S': return @"unsigned short";
        case 'i': return @"int";
        case 'I': return @"unsigned int";
        case 'l': return @"long";
        case 'L': return @"unsigned long";
        case 'q': return @"long long";
        case 'Q': return @"unsigned long long";
        case 'f': return @"float";
        case 'd': return @"double";
        case 'B': return @"BOOL";
        case '*': return @"char *";
        case '^': return @"void *";
        case '{': return @"struct";
        case '[': return @"void *";
        default: return @"id";
    }
}

static NSString *CDPropertyLine(objc_property_t property) {
    const char *n = property_getName(property);
    if (!n) return nil;

    NSString *name = [NSString stringWithUTF8String:n];
    NSString *attrs = @"";
    const char *a = property_getAttributes(property);
    if (a) attrs = [NSString stringWithUTF8String:a];

    NSString *type = @"id";
    BOOL readonly = [attrs containsString:@",R"];
    BOOL copy = [attrs containsString:@",C"];
    BOOL weak = [attrs containsString:@",W"];
    BOOL nonatomic = [attrs containsString:@",N"];

    if ([attrs hasPrefix:@"T"]) {
        NSString *typePart = [[attrs substringFromIndex:1] componentsSeparatedByString:@","].firstObject ?: @"@";
        type = CDTypeFromEncoding(typePart.UTF8String);
    }

    NSMutableArray *parts = [NSMutableArray array];
    [parts addObject:(nonatomic ? @"nonatomic" : @"atomic")];
    if (readonly) [parts addObject:@"readonly"];
    if (copy) [parts addObject:@"copy"];
    else if (weak) [parts addObject:@"weak"];
    else if ([type containsString:@"*"] || [type isEqualToString:@"id"]) [parts addObject:@"strong"];
    else [parts addObject:@"assign"];

    return [NSString stringWithFormat:@"@property (%@) %@ %@;", [parts componentsJoinedByString:@", "], type, name];
}

static NSString *CDMethodLine(Method m, BOOL isClassMethod) {
    SEL sel = method_getName(m);
    if (!sel) return nil;

    const char *ret = method_copyReturnType(m);
    NSString *retType = CDTypeFromEncoding(ret);
    if (ret) free((void *)ret);

    NSString *name = NSStringFromSelector(sel);
    if (name.length == 0) return nil;

    unsigned int argCount = method_getNumberOfArguments(m);

    if (![name containsString:@":"] || argCount <= 2) {
        return [NSString stringWithFormat:@"%c (%@)%@;", isClassMethod ? '+' : '-', retType, name];
    }

    NSArray<NSString *> *parts = [name componentsSeparatedByString:@":"];
    NSMutableString *line = [NSMutableString stringWithFormat:@"%c (%@)", isClassMethod ? '+' : '-', retType];

    for (NSUInteger i = 0; i < parts.count - 1; i++) {
        NSString *label = parts[i];
        char *argTypeRaw = method_copyArgumentType(m, (unsigned int)i + 2);
        NSString *argType = CDTypeFromEncoding(argTypeRaw);
        if (argTypeRaw) free(argTypeRaw);

        if (i == 0) {
            [line appendFormat:@"%@:(%@)arg%lu", label.length ? label : @"method", argType, (unsigned long)i];
        } else {
            [line appendFormat:@" %@:(%@)arg%lu", label.length ? label : @"param", argType, (unsigned long)i];
        }
    }

    [line appendString:@";"];
    return line;
}

static NSString *CDHeaderForClass(Class cls, NSString *imageName) {
    @try {
        NSString *className = NSStringFromClass(cls);
        if (className.length == 0) return nil;
        if (CDIsLikelySwiftName(className)) return nil;

        Class superCls = class_getSuperclass(cls);
        NSString *superName = superCls ? NSStringFromClass(superCls) : @"NSObject";

        NSMutableString *h = [NSMutableString string];
        [h appendString:@"//\n"];
        [h appendString:@"// Dumped by ClassDumpExportPro 1.1.4\n"];
        [h appendFormat:@"// Bundle: %@\n", NSBundle.mainBundle.bundleIdentifier ?: @"Unknown"];
        [h appendFormat:@"// Image: %@\n", imageName ?: @"Unknown"];
        [h appendString:@"//\n\n"];
        [h appendString:@"#import <Foundation/Foundation.h>\n"];
        [h appendString:@"#import <UIKit/UIKit.h>\n\n"];

        unsigned int protocolCount = 0;
        Protocol *__unsafe_unretained *protocols = class_copyProtocolList(cls, &protocolCount);
        NSMutableArray *protocolNames = [NSMutableArray array];
        for (unsigned int i = 0; i < protocolCount; i++) {
            const char *pn = protocol_getName(protocols[i]);
            if (pn) [protocolNames addObject:[NSString stringWithUTF8String:pn]];
        }
        if (protocols) free(protocols);

        if (protocolNames.count) {
            [h appendFormat:@"@interface %@ : %@ <%@>\n\n", className, superName, [protocolNames componentsJoinedByString:@", "]];
        } else {
            [h appendFormat:@"@interface %@ : %@\n\n", className, superName];
        }

        unsigned int ivarCount = 0;
        Ivar *ivars = class_copyIvarList(cls, &ivarCount);
        if (ivarCount > 0) [h appendString:@"{\n"];
        for (unsigned int i = 0; i < ivarCount; i++) {
            const char *in = ivar_getName(ivars[i]);
            const char *it = ivar_getTypeEncoding(ivars[i]);
            if (in) {
                [h appendFormat:@"    %@ %s;\n", CDTypeFromEncoding(it), in];
            }
        }
        if (ivarCount > 0) [h appendString:@"}\n\n"];
        if (ivars) free(ivars);

        unsigned int propertyCount = 0;
        objc_property_t *props = class_copyPropertyList(cls, &propertyCount);
        if (propertyCount > 0) [h appendString:@"#pragma mark - Properties\n\n"];
        for (unsigned int i = 0; i < propertyCount; i++) {
            NSString *line = CDPropertyLine(props[i]);
            if (line.length) [h appendFormat:@"%@\n", line];
        }
        if (props) free(props);

        unsigned int methodCount = 0;
        Method *methods = class_copyMethodList(cls, &methodCount);
        if (methodCount > 0) [h appendString:@"\n#pragma mark - Instance Methods\n\n"];
        for (unsigned int i = 0; i < methodCount; i++) {
            NSString *line = CDMethodLine(methods[i], NO);
            if (line.length) [h appendFormat:@"%@\n", line];
        }
        if (methods) free(methods);

        Class meta = object_getClass(cls);
        unsigned int classMethodCount = 0;
        Method *classMethods = class_copyMethodList(meta, &classMethodCount);
        if (classMethodCount > 0) [h appendString:@"\n#pragma mark - Class Methods\n\n"];
        for (unsigned int i = 0; i < classMethodCount; i++) {
            NSString *line = CDMethodLine(classMethods[i], YES);
            if (line.length) [h appendFormat:@"%@\n", line];
        }
        if (classMethods) free(classMethods);

        [h appendString:@"\n@end\n"];
        return h;
    } @catch (__unused NSException *e) {
        NSLog(@"[CDHeaderDumper] Exception: %@", e);
        return nil;
    }
}

static NSString *CDProtocolHeader(Protocol *protocol) {
    @try {
        const char *pn = protocol_getName(protocol);
        if (!pn) return nil;

        NSString *name = [NSString stringWithUTF8String:pn];
        if (name.length == 0) return nil;

        NSMutableString *h = [NSMutableString string];
        [h appendString:@"// Dumped Protocol by ClassDumpExportPro\n\n"];
        [h appendString:@"#import <Foundation/Foundation.h>\n"];
        [h appendString:@"#import <UIKit/UIKit.h>\n\n"];
        [h appendFormat:@"@protocol %@\n\n", name];

        struct objc_method_description *methods = NULL;
        unsigned int count = 0;

        methods = protocol_copyMethodDescriptionList(protocol, YES, YES, &count);
        if (count > 0) [h appendString:@"@required\n\n"];
        for (unsigned int i = 0; i < count; i++) {
            if (methods[i].name) {
                [h appendFormat:@"- (id)%@;\n", NSStringFromSelector(methods[i].name)];
            }
        }
        if (methods) free(methods);

        count = 0;
        methods = protocol_copyMethodDescriptionList(protocol, NO, YES, &count);
        if (count > 0) [h appendString:@"\n@optional\n\n"];
        for (unsigned int i = 0; i < count; i++) {
            if (methods[i].name) {
                [h appendFormat:@"- (id)%@;\n", NSStringFromSelector(methods[i].name)];
            }
        }
        if (methods) free(methods);

        [h appendString:@"\n@end\n"];
        return h;
    } @catch (__unused NSException *e) {
        NSLog(@"[CDHeaderDumper] Exception: %@", e);
        return nil;
    }
}

@implementation CDHeaderDumper

/// 缓存：按镜像分组的类名列表
static NSArray<NSDictionary *> *_cachedClassNamesByImage = nil;
/// 缓存：所有类名的扁平数组
static NSArray<NSString *> *_cachedAllClassNames = nil;
/// 缓存时的镜像数量（用于检测是否需要刷新）
static uint32_t _cachedImageCount = 0;

+ (NSArray<NSDictionary *> *)collectSafeClassNamesByImage {
    // 检查缓存是否有效
    uint32_t currentImageCount = _dyld_image_count();
    if (_cachedClassNamesByImage && _cachedImageCount == currentImageCount) {
        return _cachedClassNamesByImage;
    }
    
    NSMutableArray<NSDictionary *> *result = [NSMutableArray array];

    uint32_t imageCount = currentImageCount;
    for (uint32_t i = 0; i < imageCount; i++) {
        const char *cpath = _dyld_get_image_name(i);
        if (!cpath) continue;

        NSString *imagePath = [NSString stringWithUTF8String:cpath];
        if (CDShouldSkipImage(imagePath)) continue;

        unsigned int classCount = 0;
        const char **names = objc_copyClassNamesForImage(cpath, &classCount);
        if (!names || classCount == 0) {
            if (names) free(names);
            continue;
        }

        NSMutableArray<NSString *> *safeNames = [NSMutableArray array];
        for (unsigned int j = 0; j < classCount; j++) {
            const char *cn = names[j];
            if (!cn) continue;

            NSString *name = [NSString stringWithUTF8String:cn];
            if (CDIsLikelySwiftName(name)) continue;

            [safeNames addObject:name];
        }

        free(names);

        if (safeNames.count > 0) {
            [result addObject:@{
                @"imagePath": imagePath,
                @"imageName": imagePath.lastPathComponent ?: @"Image",
                @"classes": safeNames
            }];
        }
    }
    
    // 更新缓存
    _cachedClassNamesByImage = result.copy;
    _cachedImageCount = currentImageCount;
    // 清空扁平数组缓存，下次需要时重新生成
    _cachedAllClassNames = nil;

    return result;
}

+ (void)dumpHeadersZipWithProgress:(CDDumpProgressBlock)progress
                        completion:(CDDumpCompletionBlock)completion {

    dispatch_async(dispatch_get_main_queue(), ^{
        progress(0.02, @"扫描已加载 Mach-O 镜像...");

        NSArray<NSDictionary *> *images = [self collectSafeClassNamesByImage];

        NSUInteger total = 0;
        for (NSDictionary *info in images) {
            total += [info[@"classes"] count];
        }

        NSString *tmp = NSTemporaryDirectory();
        NSString *bundleID = NSBundle.mainBundle.bundleIdentifier ?: @"Unknown";
        NSString *rootName = [NSString stringWithFormat:@"ClassDump-%@-%lld", bundleID, (long long)[NSDate.date timeIntervalSince1970]];
        NSString *rootDir = [tmp stringByAppendingPathComponent:rootName];
        NSString *classesDir = [rootDir stringByAppendingPathComponent:@"Classes"];
        NSString *protocolsDir = [rootDir stringByAppendingPathComponent:@"Protocols"];

        NSFileManager *fm = NSFileManager.defaultManager;
        [fm removeItemAtPath:rootDir error:nil];
        [fm createDirectoryAtPath:classesDir withIntermediateDirectories:YES attributes:nil error:nil];
        [fm createDirectoryAtPath:protocolsDir withIntermediateDirectories:YES attributes:nil error:nil];

        NSMutableArray<NSString *> *writtenFiles = [NSMutableArray array];
        __block NSUInteger done = 0;

        progress(0.05, [NSString stringWithFormat:@"发现 %lu 个 Objective-C 类", (unsigned long)total]);

        __block NSUInteger imageIndex = 0;

        void (^__block processNextImage)(void);
        processNextImage = ^{
            if (imageIndex >= images.count) {
                progress(0.82, @"正在导出协议...");

                @try {
                    unsigned int protocolCount = 0;
                    Protocol *__unsafe_unretained *protocols = objc_copyProtocolList(&protocolCount);
                    for (unsigned int i = 0; i < protocolCount; i++) {
                        NSString *ph = CDProtocolHeader(protocols[i]);
                        if (!ph.length) continue;

                        const char *pn = protocol_getName(protocols[i]);
                        if (!pn) continue;

                        NSString *pname = CDSafeFileName([NSString stringWithUTF8String:pn]);
                        NSString *path = [protocolsDir stringByAppendingPathComponent:[pname stringByAppendingString:@".h"]];
                        NSError *writeError = nil;
                        BOOL writeOk = [ph writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&writeError];
                        if (!writeOk) {
                            NSLog(@"[CDHeaderDumper] 写入文件失败: %@, error: %@", path, writeError);
                        }
                        [writtenFiles addObject:path];
                    }
                    if (protocols) free(protocols);
                } @catch (__unused NSException *e) {
                    NSLog(@"[CDHeaderDumper] Exception: %@", e);
                }

                progress(0.82, @"正在导出 Swift 类...");

                NSArray<NSString *> *swiftFiles = [CDSwiftDumper dumpSwiftInterfacesAtRootDir:rootDir progress:^(CGFloat swiftProgress, NSString *text) {
                    progress(0.82 + swiftProgress * 0.06, text ?: @"正在导出 Swift 类...");
                }];
                if (swiftFiles.count > 0) {
                    [writtenFiles addObjectsFromArray:swiftFiles];
                }

                progress(0.88, @"正在生成索引文件...");

                NSString *index = [NSString stringWithFormat:
                                   @"Bundle: %@\nApp: %@\nObjC Classes: %lu\nFiles: %lu\nGenerated: %@\n\n说明：ObjC 使用安全 image 枚举；Swift 使用符号表 + swift_demangle 生成伪接口。\n",
                                   bundleID,
                                   NSBundle.mainBundle.infoDictionary[@"CFBundleName"] ?: @"Unknown",
                                   (unsigned long)total,
                                   (unsigned long)writtenFiles.count,
                                   NSDate.date];

                NSString *indexPath = [rootDir stringByAppendingPathComponent:@"README.txt"];
                NSError *writeError = nil;
                BOOL writeOk = [index writeToFile:indexPath atomically:YES encoding:NSUTF8StringEncoding error:&writeError];
                if (!writeOk) {
                    NSLog(@"[CDHeaderDumper] 写入文件失败: %@, error: %@", indexPath, writeError);
                }
                [writtenFiles addObject:indexPath];

                if (writtenFiles.count == 0) {
                    NSString *emptyPath = [rootDir stringByAppendingPathComponent:@"EMPTY.txt"];
                    NSError *writeError = nil;
                    BOOL writeOk = [@"没有发现可导出的 ObjC/Swift 符号，但插件运行正常。\n" writeToFile:emptyPath atomically:YES encoding:NSUTF8StringEncoding error:&writeError];
                    if (!writeOk) {
                        NSLog(@"[CDHeaderDumper] 写入文件失败: %@, error: %@", emptyPath, writeError);
                    }
                    [writtenFiles addObject:emptyPath];
                }

                progress(0.9, @"正在压缩 zip...");

                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    NSString *zipPath = [tmp stringByAppendingPathComponent:[rootName stringByAppendingString:@".zip"]];
                    [fm removeItemAtPath:zipPath error:nil];

                    NSError *zipError = nil;
                    BOOL ok = [CDZipWriter createZipAtPath:zipPath
                                                    rootDir:rootDir
                                                     files:writtenFiles
                                                  progress:^(CGFloat zipProgress) {
                        progress(0.9 + zipProgress * 0.09, @"正在压缩 zip...");
                    }
                                                      error:&zipError];

                    if (!ok || zipError) {
                        NSString *errorPath = [rootDir stringByAppendingPathComponent:@"ZIP_ERROR.txt"];
                        NSString *msg = zipError.localizedDescription ?: @"ZIP失败，未知错误";
                        NSError *writeError = nil;
                        BOOL writeOk = [msg writeToFile:errorPath atomically:YES encoding:NSUTF8StringEncoding error:&writeError];
                        if (!writeOk) {
                            NSLog(@"[CDHeaderDumper] 写入文件失败: %@, error: %@", errorPath, writeError);
                        }
                        if (![writtenFiles containsObject:errorPath]) [writtenFiles addObject:errorPath];

                        zipError = nil;
                        ok = [CDZipWriter createZipAtPath:zipPath
                                                   rootDir:rootDir
                                                     files:writtenFiles
                                                  progress:nil
                                                     error:&zipError];
                    }

                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (!ok || zipError) {
                            completion(nil, zipError ?: [NSError errorWithDomain:@"ClassDumpExportPro"
                                                                             code:-2
                                                                         userInfo:@{NSLocalizedDescriptionKey:@"ZIP最终打包失败"}]);
                        } else {
                            progress(1.0, @"完成");
                            completion([NSURL fileURLWithPath:zipPath], nil);
                        }
                    });
                });

                return;
            }

            NSDictionary *info = images[imageIndex++];
            NSString *imageName = info[@"imageName"] ?: @"Image";
            NSArray<NSString *> *classes = info[@"classes"] ?: @[];

            NSString *imageDirName = CDSafeFileName([imageName stringByDeletingPathExtension]);
            NSString *imageDir = [classesDir stringByAppendingPathComponent:imageDirName];
            [fm createDirectoryAtPath:imageDir withIntermediateDirectories:YES attributes:nil error:nil];

            NSUInteger batchSize = 20;
            __block NSUInteger idx = 0;

            void (^__block processBatch)(void);
            processBatch = ^{
                NSUInteger end = MIN(idx + batchSize, classes.count);

                for (; idx < end; idx++) {
                    NSString *className = classes[idx];
                    if (CDIsLikelySwiftName(className)) {
                        done++;
                        continue;
                    }

                    @autoreleasepool {
                        @try {
                            Class cls = objc_getClass(className.UTF8String);
                            if (!cls) {
                                done++;
                                continue;
                            }

                            NSString *header = CDHeaderForClass(cls, imageName);
                            if (header.length) {
                                NSString *fileName = [CDSafeFileName(className) stringByAppendingString:@".h"];
                                NSString *path = [imageDir stringByAppendingPathComponent:fileName];
                                NSError *writeError = nil;
                                BOOL writeOk = [header writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&writeError];
                                if (!writeOk) {
                                    NSLog(@"[CDHeaderDumper] 写入文件失败: %@, error: %@", path, writeError);
                                }
                                [writtenFiles addObject:path];
                            }
                        } @catch (__unused NSException *e) {
                            NSLog(@"[CDHeaderDumper] Exception: %@", e);
                        }
                    }

                    done++;
                }

                CGFloat p = 0.05 + ((CGFloat)done / (CGFloat)MAX(total, 1)) * 0.75;
                progress(p, [NSString stringWithFormat:@"%lu/%lu  %@", (unsigned long)done, (unsigned long)total, imageName]);

                if (idx < classes.count) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        processBatch();
                    });
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        processNextImage();
                    });
                }
            };

            processBatch();
        };

        processNextImage();
    });
}

#pragma mark - 单个类头文件导出

+ (Class)classForName:(NSString *)className {
    if (className.length == 0) return nil;
    if (CDIsLikelySwiftName(className)) return nil;
    
    Class cls = objc_getClass(className.UTF8String);
    return cls;
}

+ (NSString *)headerForClassName:(NSString *)className {
    if (className.length == 0) return nil;
    
    Class cls = [self classForName:className];
    if (!cls) return nil;
    
    // 尝试找到类所在的 image
    NSString *imageName = @"Unknown";
    const char *classNameC = className.UTF8String;
    
    uint32_t imageCount = _dyld_image_count();
    for (uint32_t i = 0; i < imageCount; i++) {
        const char *cpath = _dyld_get_image_name(i);
        if (!cpath) continue;
        
        NSString *imagePath = [NSString stringWithUTF8String:cpath];
        if (CDShouldSkipImage(imagePath)) continue;
        
        unsigned int classCount = 0;
        const char **names = objc_copyClassNamesForImage(cpath, &classCount);
        if (!names) continue;
        
        BOOL found = NO;
        for (unsigned int j = 0; j < classCount; j++) {
            if (names[j] && strcmp(names[j], classNameC) == 0) {
                imageName = imagePath.lastPathComponent ?: @"Image";
                found = YES;
                break;
            }
        }
        free(names);
        if (found) break;
    }
    
    return CDHeaderForClass(cls, imageName);
}

+ (NSArray<NSDictionary *> *)allClassNamesByImage {
    return [self collectSafeClassNamesByImage];
}

+ (NSArray<NSString *> *)allClassNames {
    // 检查缓存
    if (_cachedAllClassNames) {
        return _cachedAllClassNames;
    }
    
    NSArray<NSDictionary *> *images = [self collectSafeClassNamesByImage];
    NSMutableArray<NSString *> *allNames = [NSMutableArray array];
    
    for (NSDictionary *info in images) {
        NSArray<NSString *> *classes = info[@"classes"];
        if (classes) {
            [allNames addObjectsFromArray:classes];
        }
    }
    
    // 排序
    [allNames sortUsingSelector:@selector(caseInsensitiveCompare:)];
    
    // 缓存结果
    _cachedAllClassNames = allNames.copy;
    return _cachedAllClassNames;
}

+ (NSArray<NSString *> *)searchClassNames:(NSString *)keyword {
    if (keyword.length == 0) {
        return [self allClassNames];
    }
    
    NSString *lowerKeyword = keyword.lowercaseString;
    NSArray<NSString *> *allNames = [self allClassNames];
    NSMutableArray<NSString *> *results = [NSMutableArray array];
    
    for (NSString *name in allNames) {
        if ([name.lowercaseString containsString:lowerKeyword]) {
            [results addObject:name];
        }
    }
    
    return results;
}

@end
