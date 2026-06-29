#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <arpa/inet.h>
#import <netdb.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <sys/types.h>
#import <CoreFoundation/CoreFoundation.h>
#import <zlib.h>
#import <dlfcn.h>
#import "DatabaseManager.h"
#include "fishhook.h"

extern NSString *CurrentBundleID(void);

static BOOL URLInterceptEnabled(void) {
    return [[DatabaseManager sharedManager] getSwitch:@"zongkaiguan"
                                             bundleID:CurrentBundleID()
                                         defaultValue:NO];
}

static dispatch_queue_t gInterceptQueue;
static const NSUInteger kMaxBodyBytes = 1024 * 1024;

static void SaveInterceptRecord(NSString *title, NSString *detail) {
    if (!URLInterceptEnabled() || !title.length) return;
    NSString *info = [NSString stringWithFormat:@"%@\n%@", title, detail ?: @""];
    NSString *bundleID = CurrentBundleID();
    DatabaseManager *db = [DatabaseManager sharedManager];
    dispatch_async(gInterceptQueue, ^{
        [db insertDataIntoTable:@"url_responses" bundleID:bundleID text:info];
        [db insertLogText:[NSString stringWithFormat:@"[拦截] %@", title]];
    });
    NSLog(@"[URLIntercept] %@", title);
}

static SEL IZXSwizzledSelector(SEL selector) {
    static NSMutableDictionary<NSString *, NSString *> *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [NSMutableDictionary dictionary];
    });

    NSString *original = NSStringFromSelector(selector);
    @synchronized(cache) {
        NSString *swizzled = cache[original];
        if (!swizzled) {
            swizzled = [NSString stringWithFormat:@"izx_swizzled_%@", original];
            cache[original] = swizzled;
        }
        return NSSelectorFromString(swizzled);
    }
}

static void IZXReplaceImplementation(SEL selector, Class cls, id block) {
    SEL swizzledSelector = IZXSwizzledSelector(selector);

    if (class_getInstanceMethod(cls, swizzledSelector)) return;

    Method originalMethod = class_getInstanceMethod(cls, selector);
    if (!originalMethod) return;

    IMP implementation = imp_implementationWithBlock(block);
    const char *typeEncoding = method_getTypeEncoding(originalMethod);

    class_addMethod(cls, swizzledSelector, implementation, typeEncoding);
    Method swizzledMethod = class_getInstanceMethod(cls, swizzledSelector);
    method_exchangeImplementations(originalMethod, swizzledMethod);
}

static void IZXReplaceClassMethodImplementation(SEL selector, Class cls, id block) {
    Class metaClass = object_getClass(cls);
    SEL swizzledSelector = IZXSwizzledSelector(selector);

    if (class_getInstanceMethod(metaClass, swizzledSelector)) return;

    Method originalMethod = class_getClassMethod(cls, selector);
    if (!originalMethod) return;

    IMP implementation = imp_implementationWithBlock(block);
    const char *typeEncoding = method_getTypeEncoding(originalMethod);

    class_addMethod(metaClass, swizzledSelector, implementation, typeEncoding);
    Method swizzledMethod = class_getInstanceMethod(metaClass, swizzledSelector);
    method_exchangeImplementations(originalMethod, swizzledMethod);
}

static BOOL IZXInstanceRespondsButDoesNotImplement(SEL selector, Class cls) {
    if (![cls instancesRespondToSelector:selector]) return NO;
    Method method = class_getInstanceMethod(cls, selector);
    if (!method) return YES;

    Class superCls = class_getSuperclass(cls);
    while (superCls) {
        Method superMethod = class_getInstanceMethod(superCls, selector);
        if (superMethod && method_getImplementation(superMethod) == method_getImplementation(method)) {
            return YES;
        }
        superCls = class_getSuperclass(superCls);
    }
    return NO;
}

static BOOL IsIPAddress(const char *str) {
    if (!str) return NO;
    struct in_addr addr4;
    struct in6_addr addr6;
    return inet_pton(AF_INET, str, &addr4) == 1 ||
           inet_pton(AF_INET6, str, &addr6) == 1;
}

static NSString *SockAddrToString(const struct sockaddr *sa) {
    if (!sa) return nil;
    char buf[INET6_ADDRSTRLEN] = {0};
    uint16_t port = 0;

    switch (sa->sa_family) {
        case AF_INET: {
            const struct sockaddr_in *sin = (const struct sockaddr_in *)sa;
            inet_ntop(AF_INET, &sin->sin_addr, buf, sizeof(buf));
            port = ntohs(sin->sin_port);
            break;
        }
        case AF_INET6: {
            const struct sockaddr_in6 *sin6 = (const struct sockaddr_in6 *)sa;
            inet_ntop(AF_INET6, &sin6->sin6_addr, buf, sizeof(buf));
            port = ntohs(sin6->sin6_port);
            break;
        }
        default:
            return [NSString stringWithFormat:@"(sa_family=%d)", sa->sa_family];
    }
    if (port > 0) {
        return [NSString stringWithFormat:@"%s:%d", buf, port];
    }
    return [NSString stringWithUTF8String:buf];
}

static NSData *IZXInflateData(NSData *data, int windowBits) {
    if (!data || data.length == 0) return nil;

    z_stream stream;
    memset(&stream, 0, sizeof(stream));
    stream.next_in  = (Bytef *)(void *)data.bytes;
    stream.avail_in = (uInt)data.length;

    if (inflateInit2(&stream, windowBits) != Z_OK) return nil;

    NSMutableData *result = [NSMutableData dataWithCapacity:data.length * 4];
    uint8_t buffer[16384];

    while (YES) {
        stream.next_out  = buffer;
        stream.avail_out = sizeof(buffer);

        int status = inflate(&stream, Z_NO_FLUSH);

        NSUInteger produced = sizeof(buffer) - stream.avail_out;
        if (produced > 0) [result appendBytes:buffer length:produced];

        if (status == Z_STREAM_END) break;
        if (status != Z_OK) { inflateEnd(&stream); return nil; }
        if (produced == 0)  break;
    }

    inflateEnd(&stream);
    return result.length > 0 ? result : nil;
}

static NSData *IZXDecompressGzip(NSData *data) {
    return IZXInflateData(data, 15 + 32);
}

static NSData *IZXDecompressDeflate(NSData *data) {
    return IZXInflateData(data, -15);
}

typedef size_t (*compression_decode_buffer_t)(uint8_t *, size_t,
                                               const uint8_t *, size_t,
                                               void *, int32_t);
static NSData *IZXDecompressBrotli(NSData *data) {
    if (!data || data.length == 0) return nil;

    static compression_decode_buffer_t p_compression_decode_buffer = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        void *handle = dlopen("/System/Library/Frameworks/Compression.framework/Compression", RTLD_LAZY);
        if (handle) {
            p_compression_decode_buffer = (compression_decode_buffer_t)dlsym(handle, "compression_decode_buffer");
        }
    });

    if (!p_compression_decode_buffer) return nil;

    size_t outCap = data.length * 20;
    if (outCap < 65536) outCap = 65536;

    uint8_t *outBuf = malloc(outCap);
    if (!outBuf) return nil;

    size_t actual = p_compression_decode_buffer(outBuf, outCap,
                                                 (const uint8_t *)data.bytes, data.length,
                                                 NULL, 2);

    NSData *result = (actual > 0) ? [NSData dataWithBytes:outBuf length:actual] : nil;
    free(outBuf);
    return result;
}

static NSData *IZXDecompressResponseBody(NSData *data, NSString *contentEncoding) {
    if (!data || data.length < 2) return data;

    NSString *enc = contentEncoding ? contentEncoding.lowercaseString : @"";
    NSData *decompressed = nil;

    if ([enc containsString:@"gzip"]) {
        decompressed = IZXDecompressGzip(data);
    } else if ([enc containsString:@"br"]) {
        decompressed = IZXDecompressBrotli(data);

        if (!decompressed) decompressed = IZXDecompressGzip(data);
    } else if ([enc containsString:@"deflate"]) {

        decompressed = IZXDecompressDeflate(data);
        if (!decompressed) decompressed = IZXDecompressGzip(data);
    } else {

        const uint8_t *bytes = data.bytes;
        if (bytes[0] == 0x1f && bytes[1] == 0x8b) {

            decompressed = IZXDecompressGzip(data);
        } else if (bytes[0] == 0x78 && (bytes[1] == 0x01 ||
                                           bytes[1] == 0x9c ||
                                           bytes[1] == 0xda)) {

            decompressed = IZXDecompressGzip(data);
        }
    }

    return decompressed ?: data;
}

static NSString *IZXExtractReadableStrings(NSData *data) {
    if (!data || data.length == 0) return nil;

    const uint8_t *bytes = data.bytes;
    NSUInteger length = MIN(data.length, (NSUInteger)65536);
    NSMutableString *result = [NSMutableString string];

    NSUInteger i = 0;
    while (i < length) {

        if (bytes[i] >= 0x20 && bytes[i] < 0x7f) {
            NSUInteger start = i;
            while (i < length && bytes[i] >= 0x20 && bytes[i] < 0x7f) i++;
            NSUInteger runLen = i - start;
            if (runLen >= 4) {
                NSString *str = [[NSString alloc] initWithBytes:bytes + start
                                                          length:runLen
                                                        encoding:NSUTF8StringEncoding];
                if (str) [result appendFormat:@"%@\n", str];
            }
        } else {
            i++;
        }
    }

    return result.length > 0 ? result : nil;
}

static NSString *FormatBody(NSData *data) {
    if (!data || data.length == 0) return @"(空)";

    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (json && [NSJSONSerialization isValidJSONObject:json]) {
        NSData *pretty = [NSJSONSerialization dataWithJSONObject:json
                                                         options:NSJSONWritingPrettyPrinted
                                                           error:nil];
        NSString *text = [[NSString alloc] initWithData:pretty encoding:NSUTF8StringEncoding];
        if (text) return text;
    }

    NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (text) {
        if (text.length > 4096) {
            return [NSString stringWithFormat:@"%@\n\n…(已截断, 共 %lu 字节)",
                    [text substringToIndex:4096], (unsigned long)data.length];
        }
        return text;
    }

    NSString *latin1 = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
    if (latin1) {

        NSUInteger printable = 0;
        for (NSUInteger i = 0; i < MIN(latin1.length, (NSUInteger)256); i++) {
            unichar c = [latin1 characterAtIndex:i];
            if ((c >= 0x20 && c < 0x7f) || c == 0x0a || c == 0x0d) printable++;
        }
        if (printable > MIN(latin1.length, (NSUInteger)256) / 2) {
            if (latin1.length > 4096) {
                return [NSString stringWithFormat:@"%@\n\n…(已截断, 共 %lu 字节)",
                        [latin1 substringToIndex:4096], (unsigned long)data.length];
            }
            return latin1;
        }
    }

    NSUInteger previewLen = MIN(data.length, 256);
    const uint8_t *bytes = data.bytes;
    NSMutableString *hex = [NSMutableString string];
    for (NSUInteger i = 0; i < previewLen; i++) {
        [hex appendFormat:@"%02x", bytes[i]];
        if ((i + 1) % 32 == 0) [hex appendString:@"\n"];
        else if ((i + 1) % 4 == 0) [hex appendString:@" "];
    }

    NSMutableString *result = [NSMutableString stringWithFormat:
        @"(二进制数据, %lu 字节, 显示前 %lu)\n%@",
        (unsigned long)data.length, (unsigned long)previewLen, hex];

    NSString *readable = IZXExtractReadableStrings(data);
    if (readable) {
        NSUInteger maxStrings = MIN(readable.length, (NSUInteger)4096);
        [result appendFormat:@"\n\n可读字符串提取:\n%@",
         [readable substringToIndex:maxStrings]];
        if (readable.length > maxStrings) {
            [result appendString:@"\n…(更多字符串已截断)"];
        }
    }

    return result;
}

static NSString *FormatResponseBody(NSData *data, NSURLResponse *response) {
    if (!data || data.length == 0) return @"(空)";

    NSString *contentEncoding = nil;
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)response;
        contentEncoding = httpResp.allHeaderFields[@"Content-Encoding"];
        if (!contentEncoding) {

            contentEncoding = httpResp.allHeaderFields[@"content-encoding"];
        }
    }

    NSData *decompressed = IZXDecompressResponseBody(data, contentEncoding);
    BOOL didDecompress = (decompressed != data && decompressed.length != data.length);

    NSString *prefix = @"";
    if (didDecompress) {
        prefix = [NSString stringWithFormat:@"[已解压: %@, %lu → %lu 字节]\n",
                  contentEncoding ?: @"auto",
                  (unsigned long)data.length, (unsigned long)decompressed.length];
    }

    return [prefix stringByAppendingString:FormatBody(decompressed)];
}

static char kResumeRecordedKey;
static char kKVOObserverKey;
static char kResponseDataKey;

@interface IZXKVOObserver : NSObject
@property (copy, nonatomic) void (^completionHandler)(NSURLSessionTask *task);
@end

@implementation IZXKVOObserver
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey, id> *)change
                       context:(void *)context {
    if (![keyPath isEqualToString:@"state"]) return;

    NSInteger newState = [change[NSKeyValueChangeNewKey] integerValue];
    if (newState != NSURLSessionTaskStateCompleted) return;

    NSURLSessionTask *task = (NSURLSessionTask *)object;
    @try {
        [task removeObserver:self forKeyPath:@"state"];
    } @catch (NSException *e) {}

    if (self.completionHandler) {
        self.completionHandler(task);
    }
}
@end

static NSMutableSet<NSString *> *gSwizzledDelegateClasses;

static void SwizzleSessionDelegate(id<NSURLSessionDelegate> delegate) {
    if (!delegate) return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        gSwizzledDelegateClasses = [NSMutableSet set];
    });

    Class cls = [delegate class];
    NSString *clsName = NSStringFromClass(cls);

    @synchronized(gSwizzledDelegateClasses) {
        if ([gSwizzledDelegateClasses containsObject:clsName]) return;
        [gSwizzledDelegateClasses addObject:clsName];
    }

    SEL didReceiveDataSel = @selector(URLSession:dataTask:didReceiveData:);
    if (class_getInstanceMethod(cls, didReceiveDataSel)) {
        IZXReplaceImplementation(didReceiveDataSel, cls,
            ^(id slf, NSURLSession *session, NSURLSessionDataTask *dataTask, NSData *data) {

                NSMutableData *buf = objc_getAssociatedObject(dataTask, &kResponseDataKey);
                if (!buf) {
                    buf = [NSMutableData data];
                    objc_setAssociatedObject(dataTask, &kResponseDataKey, buf,
                                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                }
                [buf appendData:data];

                SEL swizzled = IZXSwizzledSelector(didReceiveDataSel);
                ((void(*)(id, SEL, id, id, id))objc_msgSend)(slf, swizzled, session, dataTask, data);
            });
    }

    SEL didCompleteSel = @selector(URLSession:task:didCompleteWithError:);
    if (class_getInstanceMethod(cls, didCompleteSel)) {
        IZXReplaceImplementation(didCompleteSel, cls,
            ^(id slf, NSURLSession *session, NSURLSessionTask *task, NSError *error) {
                if (URLInterceptEnabled()) {
                    NSURLResponse *response = task.response;
                    if (response) {
                        NSInteger statusCode = 0;
                        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                            statusCode = ((NSHTTPURLResponse *)response).statusCode;
                        }
                        NSURLRequest *request = task.currentRequest ?: task.originalRequest;
                        NSURL *url = request.URL;
                        NSString *method = request.HTTPMethod ?: @"GET";

                        NSString *title = [NSString stringWithFormat:@"[Delegate 响应] %@ %ld %@",
                                           method, (long)statusCode, url.absoluteString ?: @""];

                        NSMutableString *detail = [NSMutableString stringWithFormat:
                            @"方法: %@\nURL: %@\n状态: %ld\nMIME: %@\n预期长度: %lld",
                            method, url.absoluteString ?: @"(null)", (long)statusCode,
                            response.MIMEType ?: @"(unknown)", response.expectedContentLength];

                        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                            NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)response;
                            if (httpResp.allHeaderFields.count > 0) {
                                [detail appendFormat:@"\n\n响应头:\n%@", httpResp.allHeaderFields];
                            }
                        }

                        NSData *bodyData = objc_getAssociatedObject(task, &kResponseDataKey);
                        if (bodyData && bodyData.length > 0) {
                            [detail appendFormat:@"\n\n响应 Body:\n%@", FormatResponseBody(bodyData, response)];
                        }

                        if (error) {
                            [detail appendFormat:@"\n\n错误: %@", error];
                        }

                        SaveInterceptRecord(title, detail);
                    }
                }

                SEL swizzled = IZXSwizzledSelector(didCompleteSel);
                ((void(*)(id, SEL, id, id, id))objc_msgSend)(slf, swizzled, session, task, error);
            });
    }

    SEL didDownloadSel = @selector(URLSession:downloadTask:didFinishDownloadingToURL:);
    if (class_getInstanceMethod(cls, didDownloadSel)) {
        IZXReplaceImplementation(didDownloadSel, cls,
            ^(id slf, NSURLSession *session, NSURLSessionDownloadTask *downloadTask, NSURL *location) {
                if (URLInterceptEnabled()) {
                    NSURLResponse *response = downloadTask.response;
                    NSInteger statusCode = 0;
                    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                        statusCode = ((NSHTTPURLResponse *)response).statusCode;
                    }
                    NSURLRequest *request = downloadTask.currentRequest ?: downloadTask.originalRequest;
                    NSURL *url = request.URL;

                    NSString *title = [NSString stringWithFormat:@"[Delegate 下载完成] %ld %@",
                                       (long)statusCode, url.absoluteString ?: @""];

                    NSMutableString *detail = [NSMutableString stringWithFormat:
                        @"URL: %@\n状态: %ld\n下载文件: %@",
                        url.absoluteString ?: @"(null)", (long)statusCode,
                        location.path ?: @"(null)"];

                    if (location && [[NSFileManager defaultManager] fileExistsAtPath:location.path]) {
                        NSData *fileData = [NSData dataWithContentsOfFile:location.path
                            options:NSDataReadingMappedIfSafe error:nil];
                        if (fileData && fileData.length > 0 && fileData.length < kMaxBodyBytes) {
                            [detail appendFormat:@"\n\n文件内容:\n%@", FormatResponseBody(fileData, response)];
                        } else if (fileData) {
                            [detail appendFormat:@"\n\n文件大小: %lu 字节", (unsigned long)fileData.length];
                        }
                    }

                    SaveInterceptRecord(title, detail);
                }

                SEL swizzled = IZXSwizzledSelector(didDownloadSel);
                ((void(*)(id, SEL, id, id, id))objc_msgSend)(slf, swizzled, session, downloadTask, location);
            });
    }

    NSLog(@"[URLIntercept] Delegate class swizzled: %@", clsName);
}

static void RecordTaskRequest(NSURLSessionTask *task) {
    if (!task || !URLInterceptEnabled()) return;

    if (@available(iOS 11.0, *)) {
        if ([task isKindOfClass:[AVAggregateAssetDownloadTask class]]) return;
    }

    if (objc_getAssociatedObject(task, &kResumeRecordedKey)) return;
    objc_setAssociatedObject(task, &kResumeRecordedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    NSURLRequest *request = task.currentRequest ?: task.originalRequest;
    if (!request) return;

    NSURL *url = request.URL;
    if (!url) return;

    NSString *scheme = url.scheme.lowercaseString;
    if (![scheme isEqualToString:@"http"] && ![scheme isEqualToString:@"https"]) return;

    NSString *method = request.HTTPMethod ?: @"GET";
    NSString *taskType;
    if ([task isKindOfClass:[NSURLSessionDownloadTask class]]) {
        taskType = @"Download";
    } else if ([task isKindOfClass:[NSURLSessionUploadTask class]]) {
        taskType = @"Upload";
    } else {
        taskType = @"Data";
    }

    NSString *title = [NSString stringWithFormat:@"[Resume 拦截] %@ %@ %@",
                       taskType, method, url.absoluteString ?: @""];

    NSMutableString *detail = [NSMutableString string];
    [detail appendFormat:@"方法: %@\nURL: %@\n任务类型: %@\n任务类: %@",
        method, url.absoluteString ?: @"(null)", taskType, NSStringFromClass([task class])];

    NSDictionary *headers = request.allHTTPHeaderFields;
    if (headers.count > 0) {
        [detail appendFormat:@"\n\n请求头:\n%@", headers];
    }

    NSData *body = [request HTTPBody];
    if (body && body.length > 0) {
        [detail appendFormat:@"\n\n请求 Body:\n%@", FormatBody(body)];
    }

    NSInputStream *bodyStream = request.HTTPBodyStream;
    if (bodyStream && !body) {
        [detail appendFormat:@"\n\n请求 Body Stream: (有流式 body, 无法直接读取)"];
    }

    SaveInterceptRecord(title, detail);

    @try {
        id session = [task valueForKey:@"session"];
        if ([session isKindOfClass:[NSURLSession class]]) {
            SwizzleSessionDelegate([(NSURLSession *)session delegate]);
        }
    } @catch (NSException *e) {

    }

    @try {
        IZXKVOObserver *observer = [[IZXKVOObserver alloc] init];
        observer.completionHandler = ^(NSURLSessionTask *completedTask) {
            NSURLResponse *response = completedTask.response;
            if (response) {
                NSInteger statusCode = 0;
                if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                    statusCode = ((NSHTTPURLResponse *)response).statusCode;
                }
                NSString *respTitle = [NSString stringWithFormat:@"[Resume 响应] %@ %ld %@",
                                       method, (long)statusCode,
                                       url.absoluteString ?: @""];

                NSMutableString *respDetail = [NSMutableString stringWithFormat:
                    @"URL: %@\n状态: %ld\nMIME: %@\n预期长度: %lld",
                    url.absoluteString ?: @"(null)",
                    (long)statusCode,
                    response.MIMEType ?: @"(unknown)",
                    response.expectedContentLength];

                if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                    NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)response;
                    if (httpResp.allHeaderFields.count > 0) {
                        [respDetail appendFormat:@"\n\n响应头:\n%@", httpResp.allHeaderFields];
                    }
                }

                NSData *bodyData = objc_getAssociatedObject(completedTask, &kResponseDataKey);
                if (bodyData && bodyData.length > 0) {
                    [respDetail appendFormat:@"\n\n响应 Body:\n%@", FormatResponseBody(bodyData, response)];
                }

                @try {
                    id body = [completedTask valueForKeyPath:@"response.body"];
                    if (body && [body isKindOfClass:[NSData class]] && bodyData.length == 0) {
                        [respDetail appendFormat:@"\n\n响应 Body (KVC):\n%@", FormatResponseBody(body, response)];
                    }
                } @catch (NSException *e) {}

                SaveInterceptRecord(respTitle, respDetail);
            }
        };
        [task addObserver:observer forKeyPath:@"state"
                  options:NSKeyValueObservingOptionNew context:nil];
        objc_setAssociatedObject(task, &kKVOObserverKey, observer,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } @catch (NSException *e) {

    }
}

static Class IZXGetResumeBaseClass(void) {
    if (![NSProcessInfo.processInfo respondsToSelector:@selector(operatingSystemVersion)]) {

        return NSClassFromString(@"__NSCFLocalSessionTask");
    }

    NSInteger majorVersion = NSProcessInfo.processInfo.operatingSystemVersion.majorVersion;
    if (majorVersion < 9 || majorVersion >= 14) {

        return [NSURLSessionTask class];
    } else {

        return NSClassFromString(@"__NSCFURLSessionTask");
    }
}

static void IZXSwizzleResumeSelector(SEL selector, Class cls) {
    SEL swizzledSelector = IZXSwizzledSelector(selector);

    if (class_getInstanceMethod(cls, swizzledSelector)) return;

    Method originalMethod = class_getInstanceMethod(cls, selector);
    if (!originalMethod) return;

    IMP implementation = imp_implementationWithBlock(^(NSURLSessionTask *slf) {
        if (@available(iOS 11.0, *)) {

            if (![slf isKindOfClass:[AVAggregateAssetDownloadTask class]]) {

                [slf.currentRequest HTTPBody];
                RecordTaskRequest(slf);
            }
        } else {
            RecordTaskRequest(slf);
        }

        ((void(*)(id, SEL))objc_msgSend)(slf, swizzledSelector);
    });

    class_addMethod(cls, swizzledSelector, implementation,
                    method_getTypeEncoding(originalMethod));
    Method newResume = class_getInstanceMethod(cls, swizzledSelector);
    method_exchangeImplementations(originalMethod, newResume);
}

static void HookTaskResume(void) {
    Class baseResumeClass = IZXGetResumeBaseClass();
    if (!baseResumeClass) {
        NSLog(@"[URLIntercept] 无法找到 resume 基类, 跳过 resume hook");
        return;
    }

    IZXSwizzleResumeSelector(@selector(resume), baseResumeClass);

    NSLog(@"[URLIntercept] resume swizzled on %@", NSStringFromClass(baseResumeClass));
}

typedef void (^DataCompletion)(NSData *, NSURLResponse *, NSError *);
typedef void (^DownloadCompletion)(NSURL *, NSURLResponse *, NSError *);

static void HookSessionAsyncMethods(Class sessionClass) {
    if (!sessionClass) return;

    Class sharedClass = [NSURLSession.sharedSession class];
    Class targetClass = IZXInstanceRespondsButDoesNotImplement(
        @selector(dataTaskWithRequest:completionHandler:), sessionClass) ? sharedClass : sessionClass;

    IZXReplaceImplementation(@selector(dataTaskWithRequest:completionHandler:), targetClass,
        ^NSURLSessionDataTask *(NSURLSession *slf, NSURLRequest *request, DataCompletion completion) {

            SwizzleSessionDelegate(slf.delegate);

            DataCompletion wrapped = completion ? ^(NSData *data, NSURLResponse *response, NSError *error) {
                if (URLInterceptEnabled()) {
                    NSURL *url = request.URL;
                    NSInteger status = [response isKindOfClass:[NSHTTPURLResponse class]] ?
                        ((NSHTTPURLResponse *)response).statusCode : 0;
                    NSString *title = [NSString stringWithFormat:@"[Session·Data] %@ %@ → %ld",
                                       request.HTTPMethod ?: @"GET", url.absoluteString ?: @"", (long)status];
                    NSString *detail = [NSString stringWithFormat:
                        @"方法: %@\nURL: %@\n状态: %ld\nMIME: %@\n长度: %lu%@",
                        request.HTTPMethod ?: @"GET", url.absoluteString ?: @"(null)",
                        (long)status, response.MIMEType ?: @"(unknown)",
                        (unsigned long)data.length,
                        error ? [NSString stringWithFormat:@"\n错误: %@", error] : @""];
                    detail = [NSString stringWithFormat:@"%@\n\nBody:\n%@", detail, FormatResponseBody(data, response)];
                    SaveInterceptRecord(title, detail);
                }
                if (completion) completion(data, response, error);
            } : nil;

            SEL swizzled = IZXSwizzledSelector(@selector(dataTaskWithRequest:completionHandler:));
            return ((id(*)(id, SEL, id, id))objc_msgSend)(slf, swizzled, request, wrapped);
        });

    IZXReplaceImplementation(@selector(dataTaskWithURL:completionHandler:), targetClass,
        ^NSURLSessionDataTask *(NSURLSession *slf, NSURL *URL, DataCompletion completion) {
            SwizzleSessionDelegate(slf.delegate);

            DataCompletion wrapped = completion ? ^(NSData *data, NSURLResponse *response, NSError *error) {
                if (URLInterceptEnabled()) {
                    NSInteger status = [response isKindOfClass:[NSHTTPURLResponse class]] ?
                        ((NSHTTPURLResponse *)response).statusCode : 0;
                    NSString *title = [NSString stringWithFormat:@"[Session·Data] GET %@ → %ld",
                                       URL.absoluteString ?: @"", (long)status];
                    NSString *detail = [NSString stringWithFormat:
                        @"URL: %@\n状态: %ld\nMIME: %@\n长度: %lu%@",
                        URL.absoluteString ?: @"(null)", (long)status,
                        response.MIMEType ?: @"(unknown)", (unsigned long)data.length,
                        error ? [NSString stringWithFormat:@"\n错误: %@", error] : @""];
                    detail = [NSString stringWithFormat:@"%@\n\nBody:\n%@", detail, FormatResponseBody(data, response)];
                    SaveInterceptRecord(title, detail);
                }
                if (completion) completion(data, response, error);
            } : nil;
            SEL swizzled = IZXSwizzledSelector(@selector(dataTaskWithURL:completionHandler:));
            return ((id(*)(id, SEL, id, id))objc_msgSend)(slf, swizzled, URL, wrapped);
        });

    IZXReplaceImplementation(@selector(downloadTaskWithRequest:completionHandler:), targetClass,
        ^NSURLSessionDownloadTask *(NSURLSession *slf, NSURLRequest *request, DownloadCompletion completion) {
            SwizzleSessionDelegate(slf.delegate);

            DownloadCompletion wrapped = completion ? ^(NSURL *location, NSURLResponse *response, NSError *error) {
                if (URLInterceptEnabled()) {
                    NSURL *url = request.URL;
                    NSInteger status = [response isKindOfClass:[NSHTTPURLResponse class]] ?
                        ((NSHTTPURLResponse *)response).statusCode : 0;
                    NSString *title = [NSString stringWithFormat:@"[Session·Download] %@ %@ → %ld",
                                       request.HTTPMethod ?: @"GET", url.absoluteString ?: @"", (long)status];
                    NSString *detail = [NSString stringWithFormat:
                        @"方法: %@\nURL: %@\n状态: %ld\n下载文件: %@%@",
                        request.HTTPMethod ?: @"GET", url.absoluteString ?: @"(null)",
                        (long)status, location.path ?: @"(null)",
                        error ? [NSString stringWithFormat:@"\n错误: %@", error] : @""];

                    if (location && [[NSFileManager defaultManager] fileExistsAtPath:location.path]) {
                        NSData *fileData = [NSData dataWithContentsOfFile:location.path
                            options:NSDataReadingMappedIfSafe error:nil];
                        if (fileData && fileData.length > 0 && fileData.length < kMaxBodyBytes) {
                            detail = [NSString stringWithFormat:@"%@\n\n文件内容:\n%@", detail, FormatResponseBody(fileData, response)];
                        } else if (fileData) {
                            detail = [NSString stringWithFormat:@"%@\n\n文件大小: %lu 字节", detail,
                                      (unsigned long)fileData.length];
                        }
                    }
                    SaveInterceptRecord(title, detail);
                }
                if (completion) completion(location, response, error);
            } : nil;
            SEL swizzled = IZXSwizzledSelector(@selector(downloadTaskWithRequest:completionHandler:));
            return ((id(*)(id, SEL, id, id))objc_msgSend)(slf, swizzled, request, wrapped);
        });

    IZXReplaceImplementation(@selector(downloadTaskWithURL:completionHandler:), targetClass,
        ^NSURLSessionDownloadTask *(NSURLSession *slf, NSURL *URL, DownloadCompletion completion) {
            SwizzleSessionDelegate(slf.delegate);

            DownloadCompletion wrapped = completion ? ^(NSURL *location, NSURLResponse *response, NSError *error) {
                if (URLInterceptEnabled()) {
                    NSInteger status = [response isKindOfClass:[NSHTTPURLResponse class]] ?
                        ((NSHTTPURLResponse *)response).statusCode : 0;
                    NSString *title = [NSString stringWithFormat:@"[Session·Download] GET %@ → %ld",
                                       URL.absoluteString ?: @"", (long)status];
                    NSString *detail = [NSString stringWithFormat:
                        @"URL: %@\n状态: %ld\n下载文件: %@%@",
                        URL.absoluteString ?: @"(null)", (long)status,
                        location.path ?: @"(null)",
                        error ? [NSString stringWithFormat:@"\n错误: %@", error] : @""];
                    if (location && [[NSFileManager defaultManager] fileExistsAtPath:location.path]) {
                        NSData *fileData = [NSData dataWithContentsOfFile:location.path
                            options:NSDataReadingMappedIfSafe error:nil];
                        if (fileData && fileData.length > 0 && fileData.length < kMaxBodyBytes) {
                            detail = [NSString stringWithFormat:@"%@\n\n文件内容:\n%@", detail, FormatResponseBody(fileData, response)];
                        }
                    }
                    SaveInterceptRecord(title, detail);
                }
                if (completion) completion(location, response, error);
            } : nil;
            SEL swizzled = IZXSwizzledSelector(@selector(downloadTaskWithURL:completionHandler:));
            return ((id(*)(id, SEL, id, id))objc_msgSend)(slf, swizzled, URL, wrapped);
        });

    IZXReplaceImplementation(@selector(downloadTaskWithResumeData:completionHandler:), targetClass,
        ^NSURLSessionDownloadTask *(NSURLSession *slf, NSData *resumeData, DownloadCompletion completion) {
            SwizzleSessionDelegate(slf.delegate);

            DownloadCompletion wrapped = completion ? ^(NSURL *location, NSURLResponse *response, NSError *error) {
                if (URLInterceptEnabled()) {
                    NSInteger status = [response isKindOfClass:[NSHTTPURLResponse class]] ?
                        ((NSHTTPURLResponse *)response).statusCode : 0;
                    NSString *title = [NSString stringWithFormat:@"[Session·Download·Resume] → %ld", (long)status];
                    NSString *detail = [NSString stringWithFormat:
                        @"状态: %ld\n恢复数据: %lu 字节\n下载文件: %@%@",
                        (long)status, (unsigned long)resumeData.length,
                        location.path ?: @"(null)",
                        error ? [NSString stringWithFormat:@"\n错误: %@", error] : @""];
                    SaveInterceptRecord(title, detail);
                }
                if (completion) completion(location, response, error);
            } : nil;
            SEL swizzled = IZXSwizzledSelector(@selector(downloadTaskWithResumeData:completionHandler:));
            return ((id(*)(id, SEL, id, id))objc_msgSend)(slf, swizzled, resumeData, wrapped);
        });

    NSLog(@"[URLIntercept] Session async methods hooked on %@", NSStringFromClass(targetClass));
}

static void HookUploadMethods(Class sessionClass) {
    if (!sessionClass) return;
    Class sharedClass = [NSURLSession.sharedSession class];
    Class targetClass = IZXInstanceRespondsButDoesNotImplement(
        @selector(uploadTaskWithRequest:fromData:completionHandler:), sessionClass) ? sharedClass : sessionClass;

    IZXReplaceImplementation(@selector(uploadTaskWithRequest:fromData:completionHandler:), targetClass,
        ^NSURLSessionUploadTask *(NSURLSession *slf, NSURLRequest *request, NSData *bodyData, DataCompletion completion) {
            SwizzleSessionDelegate(slf.delegate);

            DataCompletion wrapped = completion ? ^(NSData *data, NSURLResponse *response, NSError *error) {
                if (URLInterceptEnabled()) {
                    NSURL *url = request.URL;
                    NSInteger status = [response isKindOfClass:[NSHTTPURLResponse class]] ?
                        ((NSHTTPURLResponse *)response).statusCode : 0;
                    NSString *title = [NSString stringWithFormat:@"[Session·Upload·Data] %@ %@ → %ld",
                                       request.HTTPMethod ?: @"POST", url.absoluteString ?: @"", (long)status];
                    NSString *detail = [NSString stringWithFormat:
                        @"方法: %@\nURL: %@\n状态: %ld\n上传数据: %lu 字节\n响应长度: %lu%@",
                        request.HTTPMethod ?: @"POST", url.absoluteString ?: @"(null)",
                        (long)status, (unsigned long)bodyData.length, (unsigned long)data.length,
                        error ? [NSString stringWithFormat:@"\n错误: %@", error] : @""];
                    if (bodyData.length > 0 && bodyData.length < kMaxBodyBytes) {
                        detail = [NSString stringWithFormat:@"%@\n\n上传内容:\n%@", detail, FormatBody(bodyData)];
                    }
                    if (data.length > 0 && data.length < kMaxBodyBytes) {
                        detail = [NSString stringWithFormat:@"%@\n\n响应内容:\n%@", detail, FormatResponseBody(data, response)];
                    }
                    SaveInterceptRecord(title, detail);
                }
                if (completion) completion(data, response, error);
            } : nil;
            SEL swizzled = IZXSwizzledSelector(@selector(uploadTaskWithRequest:fromData:completionHandler:));
            return ((id(*)(id, SEL, id, id, id))objc_msgSend)(slf, swizzled, request, bodyData, wrapped);
        });

    IZXReplaceImplementation(@selector(uploadTaskWithRequest:fromFile:completionHandler:), targetClass,
        ^NSURLSessionUploadTask *(NSURLSession *slf, NSURLRequest *request, NSURL *fileURL, DataCompletion completion) {
            SwizzleSessionDelegate(slf.delegate);

            DataCompletion wrapped = completion ? ^(NSData *data, NSURLResponse *response, NSError *error) {
                if (URLInterceptEnabled()) {
                    NSURL *url = request.URL;
                    NSInteger status = [response isKindOfClass:[NSHTTPURLResponse class]] ?
                        ((NSHTTPURLResponse *)response).statusCode : 0;
                    NSString *title = [NSString stringWithFormat:@"[Session·Upload·File] %@ %@ → %ld",
                                       request.HTTPMethod ?: @"POST", url.absoluteString ?: @"", (long)status];
                    NSString *detail = [NSString stringWithFormat:
                        @"方法: %@\nURL: %@\n状态: %ld\n上传文件: %@\n响应长度: %lu%@",
                        request.HTTPMethod ?: @"POST", url.absoluteString ?: @"(null)",
                        (long)status, fileURL.path ?: @"(null)", (unsigned long)data.length,
                        error ? [NSString stringWithFormat:@"\n错误: %@", error] : @""];
                    if (data.length > 0 && data.length < kMaxBodyBytes) {
                        detail = [NSString stringWithFormat:@"%@\n\n响应内容:\n%@", detail, FormatResponseBody(data, response)];
                    }
                    SaveInterceptRecord(title, detail);
                }
                if (completion) completion(data, response, error);
            } : nil;
            SEL swizzled = IZXSwizzledSelector(@selector(uploadTaskWithRequest:fromFile:completionHandler:));
            return ((id(*)(id, SEL, id, id, id))objc_msgSend)(slf, swizzled, request, fileURL, wrapped);
        });

    NSLog(@"[URLIntercept] Upload methods hooked on %@", NSStringFromClass(targetClass));
}

static void HookNSURLConnectionClassMethods(void) {

    IZXReplaceClassMethodImplementation(
        @selector(sendSynchronousRequest:returningResponse:error:), [NSURLConnection class],
        ^NSData *(Class slf, NSURLRequest *request, NSURLResponse **response, NSError **error) {

            SEL swizzled = IZXSwizzledSelector(@selector(sendSynchronousRequest:returningResponse:error:));
            NSError *tempError = nil;
            NSURLResponse *tempResponse = nil;
            NSData *data = ((id(*)(id, SEL, id, NSURLResponse **, NSError **))objc_msgSend)(
                slf, swizzled, request, &tempResponse, &tempError);

            if (URLInterceptEnabled()) {
                NSURL *url = request.URL;
                NSInteger status = [tempResponse isKindOfClass:[NSHTTPURLResponse class]] ?
                    ((NSHTTPURLResponse *)tempResponse).statusCode : 0;
                NSString *title = [NSString stringWithFormat:@"[NSURLConnection·同步] %@ %@ → %ld",
                                   request.HTTPMethod ?: @"GET", url.absoluteString ?: @"", (long)status];
                NSString *detail = [NSString stringWithFormat:
                    @"方法: %@\nURL: %@\n状态: %ld\n长度: %lu%@",
                    request.HTTPMethod ?: @"GET", url.absoluteString ?: @"(null)",
                    (long)status, (unsigned long)data.length,
                    tempError ? [NSString stringWithFormat:@"\n错误: %@", tempError] : @""];
                if (data.length > 0 && data.length < kMaxBodyBytes) {
                    detail = [NSString stringWithFormat:@"%@\n\nBody:\n%@", detail, FormatResponseBody(data, tempResponse)];
                }
                SaveInterceptRecord(title, detail);
            }

            if (error) *error = tempError;
            if (response) *response = tempResponse;
            return data;
        });

    IZXReplaceClassMethodImplementation(
        @selector(sendAsynchronousRequest:queue:completionHandler:), [NSURLConnection class],
        ^(Class slf, NSURLRequest *request, NSOperationQueue *queue,
          void (^completion)(NSURLResponse *, NSData *, NSError *)) {
            void (^wrapped)(NSURLResponse *, NSData *, NSError *) =
                completion ? ^(NSURLResponse *response, NSData *data, NSError *error) {
                    if (URLInterceptEnabled()) {
                        NSURL *url = request.URL;
                        NSInteger status = [response isKindOfClass:[NSHTTPURLResponse class]] ?
                            ((NSHTTPURLResponse *)response).statusCode : 0;
                        NSString *title = [NSString stringWithFormat:@"[NSURLConnection·异步] %@ %@ → %ld",
                                           request.HTTPMethod ?: @"GET", url.absoluteString ?: @"", (long)status];
                        NSString *detail = [NSString stringWithFormat:
                            @"方法: %@\nURL: %@\n状态: %ld\n长度: %lu%@",
                            request.HTTPMethod ?: @"GET", url.absoluteString ?: @"(null)",
                            (long)status, (unsigned long)data.length,
                            error ? [NSString stringWithFormat:@"\n错误: %@", error] : @""];
                        if (data.length > 0 && data.length < kMaxBodyBytes) {
                            detail = [NSString stringWithFormat:@"%@\n\nBody:\n%@", detail, FormatResponseBody(data, response)];
                        }
                        SaveInterceptRecord(title, detail);
                    }
                    if (completion) completion(response, data, error);
                } : nil;

            SEL swizzled = IZXSwizzledSelector(@selector(sendAsynchronousRequest:queue:completionHandler:));
            ((void(*)(id, SEL, id, id, id))objc_msgSend)(slf, swizzled, request, queue, wrapped);
        });

    NSLog(@"[URLIntercept] NSURLConnection class methods hooked");
}

static int (*orig_connect)(int, const struct sockaddr *, socklen_t);

static int hooked_connect(int sockfd, const struct sockaddr *addr, socklen_t addrlen) {
    NSString *target = SockAddrToString(addr);
    if (target && URLInterceptEnabled()) {

        BOOL isDNSPort = NO;
        if (addr->sa_family == AF_INET) {
            uint16_t port = ntohs(((struct sockaddr_in *)addr)->sin_port);
            isDNSPort = (port == 53);
        } else if (addr->sa_family == AF_INET6) {
            uint16_t port = ntohs(((struct sockaddr_in6 *)addr)->sin6_port);
            isDNSPort = (port == 53);
        }

        if (!isDNSPort) {
            NSString *title = [NSString stringWithFormat:@"[Socket Connect] %@", target];
            NSString *detail = [NSString stringWithFormat:@"fd=%d\n地址=%@\n类型=TCP 直连", sockfd, target];
            SaveInterceptRecord(title, detail);
        }
    }
    return orig_connect ? orig_connect(sockfd, addr, addrlen) : connect(sockfd, addr, addrlen);
}

static int (*orig_getaddrinfo)(const char *, const char *,
                                const struct addrinfo *, struct addrinfo **);

static int hooked_getaddrinfo(const char *node, const char *service,
                               const struct addrinfo *hints, struct addrinfo **res) {
    int ret = orig_getaddrinfo ? orig_getaddrinfo(node, service, hints, res)
                               : getaddrinfo(node, service, hints, res);

    if (URLInterceptEnabled() && node && !IsIPAddress(node) && res && *res) {
        NSMutableArray<NSString *> *ips = [NSMutableArray array];
        for (struct addrinfo *ai = *res; ai != NULL; ai = ai->ai_next) {
            NSString *addrStr = SockAddrToString(ai->ai_addr);
            if (addrStr && ![ips containsObject:addrStr]) {
                [ips addObject:addrStr];
            }
        }
        if (ips.count > 0) {
            NSString *title = [NSString stringWithFormat:@"[DNS 解析] %s → %@", node, ips];
            NSString *detail = [NSString stringWithFormat:
                @"域名: %s\n端口: %s\n解析结果:\n%@",
                node ?: "(null)", service ?: "(null)",
                [ips componentsJoinedByString:@"\n"]];
            SaveInterceptRecord(title, detail);
        }
    }
    return ret;
}

static void (*orig_CFStreamCreatePairWithSocketToHost)(CFAllocatorRef, CFStringRef,
                                                        UInt32, CFReadStreamRef *, CFWriteStreamRef *);

static void hooked_CFStreamCreatePairWithSocketToHost(CFAllocatorRef alloc, CFStringRef host,
                                                       UInt32 port,
                                                       CFReadStreamRef *readStream,
                                                       CFWriteStreamRef *writeStream) {
    if (URLInterceptEnabled() && host) {
        NSString *hostStr = (__bridge NSString *)host;
        NSString *title = [NSString stringWithFormat:@"[CFStream] %@:%d", hostStr, port];
        NSString *detail = [NSString stringWithFormat:
            @"主机: %@\n端口: %d\n类型=CFStream 流式连接", hostStr, port];
        SaveInterceptRecord(title, detail);
    }
    if (orig_CFStreamCreatePairWithSocketToHost) {
        orig_CFStreamCreatePairWithSocketToHost(alloc, host, port, readStream, writeStream);
    } else {
        CFStreamCreatePairWithSocketToHost(alloc, host, port, readStream, writeStream);
    }
}

static void RegisterFishhookHooks(void) {
    struct rebinding connect_rebind = {
        .name = "connect",
        .replacement = (void *)hooked_connect,
        .replaced = (void **)&orig_connect
    };
    struct rebinding gai_rebind = {
        .name = "getaddrinfo",
        .replacement = (void *)hooked_getaddrinfo,
        .replaced = (void **)&orig_getaddrinfo
    };
    struct rebinding cfstream_rebind = {
        .name = "CFStreamCreatePairWithSocketToHost",
        .replacement = (void *)hooked_CFStreamCreatePairWithSocketToHost,
        .replaced = (void **)&orig_CFStreamCreatePairWithSocketToHost
    };

    struct rebinding rebindings[] = { connect_rebind, gai_rebind, cfstream_rebind };
    rebind_symbols(rebindings, sizeof(rebindings) / sizeof(rebindings[0]));

    NSLog(@"[URLIntercept] fishhook registered (connect, getaddrinfo, CFStream)");
}

void RegisterURLInterceptHooks(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        gInterceptQueue = dispatch_queue_create("com.iosnixiangzhushou.urlintercept",
                                                 DISPATCH_QUEUE_SERIAL);

        HookTaskResume();

        Class localSession = NSClassFromString(@"__NSURLSessionLocal");
        if (localSession) {
            HookSessionAsyncMethods(localSession);
            HookUploadMethods(localSession);
        }

        HookSessionAsyncMethods([NSURLSession class]);
        HookUploadMethods([NSURLSession class]);

        HookNSURLConnectionClassMethods();

        RegisterFishhookHooks();

        NSLog(@"[URLIntercept] 全部拦截 hooks 已注册:");
        NSLog(@"  - resume swizzle (所有 task URL)");
        NSLog(@"  - __NSURLSessionLocal + NSURLSession (data/download/upload)");
        NSLog(@"  - NSURLConnection (同步/异步)");
        NSLog(@"  - fishhook (connect/getaddrinfo/CFStream)");
        NSLog(@"  - KVO task.state (响应状态/头捕获)");
        NSLog(@"  - Delegate swizzle (委托模式响应 body 累积)");
    });
}
