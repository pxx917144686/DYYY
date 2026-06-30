#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <zlib.h>
#import <dlfcn.h>
#import "DatabaseManager.h"
#import "ScriptDecode.h"

extern NSString *CurrentBundleID(void);
extern NSString *HexStringFromBytes(const void *bytes, size_t length);
extern NSString *IZXTryAutoDecryptData(NSData *encryptedData, NSString *source);

static const NSUInteger kMaxResponseBytes = 1024 * 1024;
static const NSUInteger kMaxBinaryPreviewBytes = 64 * 1024;

static NSData *CaptureInflateData(NSData *data, int windowBits) {
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

static NSData *CaptureDecompressBody(NSData *data, NSString *contentEncoding) {
    if (!data || data.length < 2) return data;
    NSString *enc = contentEncoding ? contentEncoding.lowercaseString : @"";
    NSData *decompressed = nil;

    if ([enc containsString:@"gzip"]) {
        decompressed = CaptureInflateData(data, 15 + 32);
    } else if ([enc containsString:@"br"]) {

        typedef size_t (*compression_decode_buffer_t)(uint8_t *, size_t,
                                                       const uint8_t *, size_t,
                                                       void *, int32_t);
        static compression_decode_buffer_t p_fn = NULL;
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            void *h = dlopen("/System/Library/Frameworks/Compression.framework/Compression", RTLD_LAZY);
            if (h) {
                p_fn = (compression_decode_buffer_t)dlsym(h, "compression_decode_buffer");
                if (!p_fn) {
                    NSLog(@"[URLCapture] dlsym加载compression_decode_buffer失败: %s", dlerror());
                }
            } else {
                NSLog(@"[URLCapture] dlopen加载Compression.framework失败: %s", dlerror());
            }
        });
        if (p_fn) {
            size_t outCap = data.length * 20;
            if (outCap < 65536) outCap = 65536;
            uint8_t *outBuf = malloc(outCap);
            if (outBuf) {
                size_t actual = p_fn(outBuf, outCap,
                    (const uint8_t *)data.bytes, data.length, NULL, 2);
                decompressed = (actual > 0) ? [NSData dataWithBytes:outBuf length:actual] : nil;
                free(outBuf);
            }
        }
        if (!decompressed) decompressed = CaptureInflateData(data, 15 + 32);
    } else if ([enc containsString:@"deflate"]) {
        decompressed = CaptureInflateData(data, -15);
        if (!decompressed) decompressed = CaptureInflateData(data, 15 + 32);
    } else {

        const uint8_t *bytes = data.bytes;
        if (bytes[0] == 0x1f && bytes[1] == 0x8b) {
            decompressed = CaptureInflateData(data, 15 + 32);
        } else if (bytes[0] == 0x78 && (bytes[1] == 0x01 ||
                                          bytes[1] == 0x9c ||
                                          bytes[1] == 0xda)) {
            decompressed = CaptureInflateData(data, 15 + 32);
        }
    }
    return decompressed ?: data;
}

static char kRequestTaskOriginalKey;
static char kURLTaskOriginalKey;
static char kSessionInitOriginalKey;
static char kDelegateDataOriginalKey;
static char kDelegateCompleteOriginalKey;
static char kCompletionTaskKey;
static char kDefaultConfigOriginalKey;
static char kEphemeralConfigOriginalKey;

static NSString * const kIZXURLProtocolHandledKey = @"IZXURLProtocolHandled";

static dispatch_queue_t gResponseQueue;
static NSMutableDictionary<NSValue *, NSMutableDictionary *> *gTaskStates;

NSString * const IZXURLResponseCapturedNotification = @"IZXURLResponseCapturedNotification";
NSString * const IZXURLResponseCapturedTextKey = @"text";

static BOOL URLCaptureEnabled(void) {
    return [[DatabaseManager sharedManager] getSwitch:@"zongkaiguan"
                                              bundleID:CurrentBundleID()
                                          defaultValue:NO];
}

static NSString *PrettyBodyDescription(NSData *data) {
    if (data.length == 0) return @"(空响应)";

    NSError *jsonError = nil;
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
    if (json && [NSJSONSerialization isValidJSONObject:json]) {
        NSData *prettyData = [NSJSONSerialization dataWithJSONObject:json
                                                              options:NSJSONWritingPrettyPrinted
                                                                error:nil];
        NSString *pretty = [[NSString alloc] initWithData:prettyData encoding:NSUTF8StringEncoding];
        if (pretty) return pretty;
    } else if (jsonError) {
        NSLog(@"[URLCapture] JSON解析失败: %@", jsonError);
    }

    NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (text) {
        NSString *compact = [[text componentsSeparatedByCharactersInSet:
                              [NSCharacterSet whitespaceAndNewlineCharacterSet]] componentsJoinedByString:@""];
        NSCharacterSet *base64Set = [NSCharacterSet characterSetWithCharactersInString:
                                     @"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/="];
        BOOL looksLikeBase64 = compact.length >= 16 && compact.length % 4 == 0 &&
            [compact rangeOfCharacterFromSet:base64Set.invertedSet].location == NSNotFound;
        if (looksLikeBase64) {
            NSData *decoded = [[NSData alloc] initWithBase64EncodedString:compact options:0];
            NSString *decodedText = [[NSString alloc] initWithData:decoded encoding:NSUTF8StringEncoding];
            if (decodedText.length) {
                return [NSString stringWithFormat:@"%@\n\n[Base64 解码]\n%@", text, decodedText];
            }
        }
        return text;
    }

    NSUInteger previewLength = MIN(data.length, kMaxBinaryPreviewBytes);
    NSString *hex = HexStringFromBytes(data.bytes, previewLength);
    return [NSString stringWithFormat:@"(二进制数据，显示前 %lu 字节)\n%@%@",
            (unsigned long)previewLength, hex,
            data.length > previewLength ? @"\n…二进制内容已截断" : @""];
}

static BOOL IZXRequestWasHandledByProtocol(NSURLRequest *request) {
    return request && [NSURLProtocol propertyForKey:kIZXURLProtocolHandledKey inRequest:request] != nil;
}

static NSURLSessionConfiguration *IZXConfigurationByAddingProtocol(NSURLSessionConfiguration *configuration) {
    if (!configuration) return configuration;
    Class protocolClass = NSClassFromString(@"IZXURLCaptureProtocol");
    if (!protocolClass) return configuration;
    NSArray *classes = configuration.protocolClasses ?: @[];
    for (Class cls in classes) {
        if (cls == protocolClass) return configuration;
    }
    configuration.protocolClasses = [@[protocolClass] arrayByAddingObjectsFromArray:classes];
    return configuration;
}

static void IZXCollectStringsFromJSON(id obj, NSMutableArray<NSString *> *out) {
    if (!obj || !out) return;
    if ([obj isKindOfClass:[NSString class]]) {
        NSString *str = (NSString *)obj;
        if (str.length >= 8) [out addObject:str];
    } else if ([obj isKindOfClass:[NSArray class]]) {
        for (id item in (NSArray *)obj) IZXCollectStringsFromJSON(item, out);
    } else if ([obj isKindOfClass:[NSDictionary class]]) {
        for (id key in [(NSDictionary *)obj allKeys]) {
            id value = [(NSDictionary *)obj objectForKey:key];
            IZXCollectStringsFromJSON(value, out);
        }
    }
}

static NSArray<NSData *> *IZXPossibleEncryptedPayloadsFromBody(NSData *body) {
    if (body.length == 0) return @[];
    NSMutableArray<NSData *> *items = [NSMutableArray arrayWithObject:body];
    NSError *jsonError = nil;
    id json = [NSJSONSerialization JSONObjectWithData:body options:0 error:&jsonError];
    if (!json && jsonError) {
        NSLog(@"[URLCapture] JSON解析失败(候选载荷): %@", jsonError);
    }
    NSMutableArray<NSString *> *strings = [NSMutableArray array];
    IZXCollectStringsFromJSON(json, strings);
    NSString *plain = [[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding];
    if (plain.length) [strings addObject:plain];

    NSCharacterSet *b64Set = [NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=_-"];
    NSCharacterSet *hexSet = [NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdefABCDEF"];
    for (NSString *str in strings) {
        NSString *compact = [[str componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] componentsJoinedByString:@""];
        if (compact.length < 8) continue;
        NSString *urlDecoded = [compact stringByRemovingPercentEncoding] ?: compact;
        NSArray *cands = @[compact, urlDecoded];
        for (NSString *cand in cands) {
            if (cand.length < 8) continue;
            if ([cand rangeOfCharacterFromSet:b64Set.invertedSet].location == NSNotFound) {
                NSData *b64 = [[NSData alloc] initWithBase64EncodedString:cand options:NSDataBase64DecodingIgnoreUnknownCharacters];
                if (b64.length && ![items containsObject:b64]) [items addObject:b64];
            }
            if (cand.length % 2 == 0 && [cand rangeOfCharacterFromSet:hexSet.invertedSet].location == NSNotFound) {
                NSMutableData *hexData = [NSMutableData dataWithCapacity:cand.length / 2];
                BOOL ok = YES;
                for (NSUInteger i = 0; i < cand.length; i += 2) {
                    unsigned int v = 0;
                    NSString *bs = [cand substringWithRange:NSMakeRange(i, 2)];
                    NSScanner *sc = [NSScanner scannerWithString:bs];
                    if (![sc scanHexInt:&v]) { ok = NO; break; }
                    uint8_t b = (uint8_t)v;
                    [hexData appendBytes:&b length:1];
                }
                if (ok && hexData.length && ![items containsObject:hexData]) [items addObject:hexData];
            }
        }
    }
    return items;
}

static NSString *IZXAutoDecryptBodyAndFields(NSData *body, NSString *source) {
    NSMutableArray<NSString *> *hits = [NSMutableArray array];
    NSUInteger idx = 0;
    for (NSData *candidate in IZXPossibleEncryptedPayloadsFromBody(body)) {
        idx++;
        NSString *hit = IZXTryAutoDecryptData(candidate, [NSString stringWithFormat:@"%@ #候选%lu", source ?: @"URL", (unsigned long)idx]);
        if (hit.length && ![hits containsObject:hit]) [hits addObject:hit];
    }
    if (hits.count == 0) return nil;
    return [@"[URL Body/JSON字段自动解密结果]\n" stringByAppendingString:[hits componentsJoinedByString:@"\n\n---\n\n"]];
}

static void SaveURLResponse(NSURLRequest *request,
                            NSURLResponse *response,
                            NSData *body,
                            NSError *error,
                            BOOL alreadyTruncated,
                            NSString *source) {
    if (!URLCaptureEnabled()) return;
    if (IZXRequestWasHandledByProtocol(request) && ![source hasPrefix:@"protocol"]) return;

    NSURL *URL = response.URL ?: request.URL;
    if (!URL) return;

    NSData *capturedBody = body ?: [NSData data];
    BOOL truncated = alreadyTruncated || capturedBody.length > kMaxResponseBytes;
    NSUInteger originalLength = capturedBody.length;
    if (capturedBody.length > kMaxResponseBytes) {
        capturedBody = [capturedBody subdataWithRange:NSMakeRange(0, kMaxResponseBytes)];
    }

    NSInteger statusCode = 0;
    NSDictionary *headers = @{};
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
        statusCode = http.statusCode;
        headers = http.allHeaderFields ?: @{};
    }

    NSString *MIMEType = response.MIMEType;
    NSString *URLString = URL.absoluteString;
    NSString *HTTPMethod = request.HTTPMethod;

    dispatch_async(gResponseQueue, ^{
        @autoreleasepool {
            NSString *contentEncoding = headers[@"Content-Encoding"] ?: headers[@"content-encoding"];
            NSData *displayBody = CaptureDecompressBody(capturedBody, contentEncoding);
            NSString *decompressNote = @"";
            if (displayBody != capturedBody && displayBody.length != capturedBody.length) {
                decompressNote = [NSString stringWithFormat:@"[已解压: %@, %lu → %lu 字节]\n",
                                  contentEncoding ?: @"auto",
                                  (unsigned long)capturedBody.length,
                                  (unsigned long)displayBody.length];
            }

            NSString *bodyDescription = [decompressNote stringByAppendingString:PrettyBodyDescription(displayBody)];
            NSString *sourceLine = [NSString stringWithFormat:@"%@ %@", source ?: @"URL", URLString ?: @""];
            NSString *autoDecrypt = IZXAutoDecryptBodyAndFields(displayBody, sourceLine);
            if (autoDecrypt.length) {
                bodyDescription = [NSString stringWithFormat:@"%@\n\n%@", bodyDescription ?: @"", autoDecrypt];
            }
            NSString *scriptText = [[NSString alloc] initWithData:displayBody encoding:NSUTF8StringEncoding];
            BOOL mayBeScript = [MIMEType.lowercaseString containsString:@"javascript"] ||
                               [MIMEType.lowercaseString containsString:@"text"] ||
                               [URL.pathExtension.lowercaseString isEqualToString:@"js"] ||
                               [scriptText rangeOfString:@"eval(" options:NSCaseInsensitiveSearch].location != NSNotFound ||
                               [scriptText rangeOfString:@"_0x" options:NSCaseInsensitiveSearch].location != NSNotFound ||
                               [scriptText rangeOfString:@"jsjiami" options:NSCaseInsensitiveSearch].location != NSNotFound ||
                               [scriptText rangeOfString:@"awsc" options:NSCaseInsensitiveSearch].location != NSNotFound ||
                               [scriptText rangeOfString:@"jjencode" options:NSCaseInsensitiveSearch].location != NSNotFound;
            if (mayBeScript && scriptText.length > 0) {
                NSString *scriptDecoded = IZXDecodeScriptText(scriptText, sourceLine);
                if (scriptDecoded.length) {
                    [[DatabaseManager sharedManager] insertDataIntoTable:@"decrypt_data" bundleID:CurrentBundleID() text:scriptDecoded];
                    bodyDescription = [NSString stringWithFormat:@"%@\n\n%@", bodyDescription ?: @"", scriptDecoded];
                }
            }
            NSString *errorLine = error ? [NSString stringWithFormat:@"\nError: %@", error] : @"";
            NSString *info = [NSString stringWithFormat:
                              @"[URL Response · %@]\n%@ %@\nStatus: %ld\nMIME: %@\nHeaders: %@\n"
                               "Length: %lu%@%@\n\nBody:\n%@",
                              source ?: @"NSURLSession", HTTPMethod ?: @"GET", URLString,
                              (long)statusCode, MIMEType ?: @"(unknown)", headers,
                              (unsigned long)originalLength, truncated ? @"（仅保存前 1 MB）" : @"",
                              errorLine, bodyDescription];

            NSString *bundleID = CurrentBundleID();
            DatabaseManager *db = [DatabaseManager sharedManager];
            [db insertDataIntoTable:@"url_responses" bundleID:bundleID text:info];
            [db insertLogText:[NSString stringWithFormat:@"URL响应已抓取: %ld %@", (long)statusCode, URLString]];

            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:IZXURLResponseCapturedNotification
                                                                    object:nil
                                                                  userInfo:@{IZXURLResponseCapturedTextKey: info ?: @""}];
            });

            if ([URL.scheme.lowercaseString isEqualToString:@"https"]) {
                NSString *decrypted = [NSString stringWithFormat:@"[HTTPS TLS 解密后响应]\n%@", info];
                [db insertDataIntoTable:@"decrypt_data" bundleID:bundleID text:decrypted];
            }
            NSLog(@"[URLCapture] %@ %ld (%lu bytes)", URLString,
                  (long)statusCode, (unsigned long)originalLength);
        }
    });
}

static IMP OriginalIMP(id object, const void *key, IMP wrapper) {
    Class cls = object_getClass(object);
    while (cls) {
        NSValue *value = objc_getAssociatedObject(cls, key);
        if (value) {
            IMP original = [value pointerValue];
            return original == wrapper ? NULL : original;
        }
        cls = class_getSuperclass(cls);
    }
    return NULL;
}

static void HookMethod(Class cls, SEL selector, IMP replacement,
                       const void *key, const char *fallbackTypes,
                       BOOL addWhenMissing) {
    if (!cls || objc_getAssociatedObject(cls, key)) return;
    @synchronized (cls) {
        if (objc_getAssociatedObject(cls, key)) return;
        Method method = class_getInstanceMethod(cls, selector);
        if (!method && !addWhenMissing) return;

        IMP original = method ? method_getImplementation(method) : NULL;
        if (original == replacement) return;
        const char *types = method ? method_getTypeEncoding(method) : fallbackTypes;
        objc_setAssociatedObject(cls, key, [NSValue valueWithPointer:original],
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        if (!class_addMethod(cls, selector, replacement, types) && method) {
            method_setImplementation(method, replacement);
        }
    }
}

static void HookClassMethod(Class cls, SEL selector, IMP replacement,
                            const void *key, const char *fallbackTypes) {
    Class metaClass = object_getClass(cls);
    if (!metaClass || objc_getAssociatedObject(metaClass, key)) return;
    @synchronized (metaClass) {
        if (objc_getAssociatedObject(metaClass, key)) return;
        Method method = class_getClassMethod(cls, selector);
        if (!method) return;
        IMP original = method_getImplementation(method);
        if (original == replacement) return;
        objc_setAssociatedObject(metaClass, key, [NSValue valueWithPointer:original],
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        method_setImplementation(method, replacement);
    }
}

static IMP OriginalClassIMP(Class cls, const void *key, IMP wrapper) {
    Class metaClass = object_getClass(cls);
    NSValue *value = metaClass ? objc_getAssociatedObject(metaClass, key) : nil;
    IMP original = [value pointerValue];
    return original == wrapper ? NULL : original;
}

@interface IZXURLCaptureProtocol : NSURLProtocol <NSURLSessionDataDelegate>
@property (nonatomic, strong) NSURLSessionDataTask *task;
@property (nonatomic, strong) NSMutableData *body;
@property (nonatomic, strong) NSURLResponse *capturedResponse;
@end

@implementation IZXURLCaptureProtocol

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    if (!URLCaptureEnabled()) return NO;
    if (IZXRequestWasHandledByProtocol(request)) return NO;
    NSString *scheme = request.URL.scheme.lowercaseString;
    return [scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"];
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}

+ (BOOL)requestIsCacheEquivalent:(NSURLRequest *)a toRequest:(NSURLRequest *)b {
    return [super requestIsCacheEquivalent:a toRequest:b];
}

- (void)startLoading {
    NSMutableURLRequest *markedRequest = [self.request mutableCopy];
    [NSURLProtocol setProperty:@YES forKey:kIZXURLProtocolHandledKey inRequest:markedRequest];

    self.body = [NSMutableData data];
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    configuration.protocolClasses = @[];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];
    self.task = [session dataTaskWithRequest:markedRequest];
    [self.task resume];
}

- (void)stopLoading {
    [self.task cancel];
    self.task = nil;
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
    self.capturedResponse = response;
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    if (completionHandler) completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    if (data.length) {
        if (self.body.length < kMaxResponseBytes) {
            NSUInteger available = kMaxResponseBytes - self.body.length;
            [self.body appendData:[data subdataWithRange:NSMakeRange(0, MIN(available, data.length))]];
        }
        [self.client URLProtocol:self didLoadData:data];
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    BOOL truncated = NO;
    NSNumber *expected = @(task.countOfBytesExpectedToReceive);
    if (expected.longLongValue > 0 && (unsigned long long)expected.unsignedLongLongValue > (unsigned long long)self.body.length) {
        truncated = self.body.length >= kMaxResponseBytes;
    }
    SaveURLResponse(self.request, self.capturedResponse ?: task.response, self.body ?: [NSData data], error, truncated, @"protocol/all");
    if (error) {
        [self.client URLProtocol:self didFailWithError:error];
    } else {
        [self.client URLProtocolDidFinishLoading:self];
    }
    [session finishTasksAndInvalidate];
}

@end

static NSURLSessionConfiguration *HookedDefaultSessionConfiguration(id self, SEL command) {
    IMP imp = OriginalClassIMP([NSURLSessionConfiguration class], &kDefaultConfigOriginalKey, (IMP)HookedDefaultSessionConfiguration);
    NSURLSessionConfiguration *(*original)(id, SEL) = (void *)imp;
    NSURLSessionConfiguration *configuration = original ? original(self, command) : nil;
    return IZXConfigurationByAddingProtocol(configuration);
}

static NSURLSessionConfiguration *HookedEphemeralSessionConfiguration(id self, SEL command) {
    IMP imp = OriginalClassIMP([NSURLSessionConfiguration class], &kEphemeralConfigOriginalKey, (IMP)HookedEphemeralSessionConfiguration);
    NSURLSessionConfiguration *(*original)(id, SEL) = (void *)imp;
    NSURLSessionConfiguration *configuration = original ? original(self, command) : nil;
    return IZXConfigurationByAddingProtocol(configuration);
}

typedef void (^URLDataCompletion)(NSData *, NSURLResponse *, NSError *);

static NSURLSessionDataTask *HookedDataTaskWithRequest(id self, SEL command,
                                                       NSURLRequest *request,
                                                       URLDataCompletion completion) {
    IMP imp = OriginalIMP(self, &kRequestTaskOriginalKey, (IMP)HookedDataTaskWithRequest);
    if (!imp) return nil;
    URLDataCompletion wrapped = completion ? ^(NSData *data, NSURLResponse *response, NSError *error) {
        SaveURLResponse(request, response, data, error, NO, @"completion/request");
        completion(data, response, error);
    } : nil;
    NSURLSessionDataTask *(*original)(id, SEL, NSURLRequest *, URLDataCompletion) = (void *)imp;
    NSURLSessionDataTask *task = original(self, command, request, wrapped);
    if (wrapped && task) objc_setAssociatedObject(task, &kCompletionTaskKey, @YES,
                                                   OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return task;
}

static NSURLSessionDataTask *HookedDataTaskWithURL(id self, SEL command,
                                                   NSURL *URL,
                                                   URLDataCompletion completion) {
    IMP imp = OriginalIMP(self, &kURLTaskOriginalKey, (IMP)HookedDataTaskWithURL);
    if (!imp) return nil;
    NSURLRequest *request = URL ? [NSURLRequest requestWithURL:URL] : nil;
    URLDataCompletion wrapped = completion ? ^(NSData *data, NSURLResponse *response, NSError *error) {
        SaveURLResponse(request, response, data, error, NO, @"completion/URL");
        completion(data, response, error);
    } : nil;
    NSURLSessionDataTask *(*original)(id, SEL, NSURL *, URLDataCompletion) = (void *)imp;
    NSURLSessionDataTask *task = original(self, command, URL, wrapped);
    if (wrapped && task) objc_setAssociatedObject(task, &kCompletionTaskKey, @YES,
                                                   OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return task;
}

static void AppendDelegateData(NSURLSessionDataTask *task, NSData *data) {
    if (!task || data.length == 0) return;
    NSValue *key = [NSValue valueWithNonretainedObject:task];
    dispatch_async(gResponseQueue, ^{
        NSMutableDictionary *state = gTaskStates[key];
        if (!state) {
            if (!URLCaptureEnabled()) return;
            state = [@{@"data": [NSMutableData data], @"truncated": @NO} mutableCopy];
            gTaskStates[key] = state;
        }
        NSMutableData *buffer = state[@"data"];
        if (buffer.length >= kMaxResponseBytes) {
            state[@"truncated"] = @YES;
            return;
        }
        NSUInteger available = kMaxResponseBytes - buffer.length;
        NSUInteger length = MIN(available, data.length);
        [buffer appendData:[data subdataWithRange:NSMakeRange(0, length)]];
        if (length < data.length) state[@"truncated"] = @YES;
    });
}

static void CompleteDelegateTask(NSURLSessionTask *task, NSError *error) {
    if (!task || objc_getAssociatedObject(task, &kCompletionTaskKey)) return;
    NSValue *key = [NSValue valueWithNonretainedObject:task];
    NSURLRequest *request = task.currentRequest ?: task.originalRequest;
    NSURLResponse *response = task.response;
    dispatch_async(gResponseQueue, ^{
        NSMutableDictionary *state = gTaskStates[key];
        [gTaskStates removeObjectForKey:key];
        NSData *data = state[@"data"] ?: [NSData data];
        BOOL truncated = [state[@"truncated"] boolValue];
        SaveURLResponse(request, response, data, error, truncated, @"delegate");
    });
}

static void HookedDidReceiveData(id self, SEL command, NSURLSession *session,
                                 NSURLSessionDataTask *task, NSData *data) {
    AppendDelegateData(task, data);
    IMP imp = OriginalIMP(self, &kDelegateDataOriginalKey, (IMP)HookedDidReceiveData);
    if (imp) {
        void (*original)(id, SEL, NSURLSession *, NSURLSessionDataTask *, NSData *) = (void *)imp;
        original(self, command, session, task, data);
    }
}

static void HookedDidComplete(id self, SEL command, NSURLSession *session,
                              NSURLSessionTask *task, NSError *error) {
    CompleteDelegateTask(task, error);
    IMP imp = OriginalIMP(self, &kDelegateCompleteOriginalKey, (IMP)HookedDidComplete);
    if (imp) {
        void (*original)(id, SEL, NSURLSession *, NSURLSessionTask *, NSError *) = (void *)imp;
        original(self, command, session, task, error);
    }
}

static void HookDelegateClass(Class cls) {
    if (!cls) return;
    HookMethod(cls, @selector(URLSession:dataTask:didReceiveData:),
               (IMP)HookedDidReceiveData, &kDelegateDataOriginalKey, "v@:@@@", YES);
    HookMethod(cls, @selector(URLSession:task:didCompleteWithError:),
               (IMP)HookedDidComplete, &kDelegateCompleteOriginalKey, "v@:@@@", YES);
}

static id HookedSessionInit(id self, SEL command, NSURLSessionConfiguration *configuration,
                            id delegate, NSOperationQueue *queue) {
    configuration = IZXConfigurationByAddingProtocol(configuration);
    HookDelegateClass(object_getClass(delegate));
    IMP imp = OriginalIMP(self, &kSessionInitOriginalKey, (IMP)HookedSessionInit);
    if (!imp) return nil;
    id (*original)(id, SEL, NSURLSessionConfiguration *, id, NSOperationQueue *) = (void *)imp;
    return original(self, command, configuration, delegate, queue);
}

static void HookAllSessionSubclasses(void) {
    // 遍历所有类，寻找 NSURLSession 的子类
    int numClasses = objc_getClassList(NULL, 0);
    if (numClasses <= 0) return;
    
    Class *classes = (Class *)malloc(sizeof(Class) * numClasses);
    if (!classes) return;
    
    numClasses = objc_getClassList(classes, numClasses);
    Class baseClass = [NSURLSession class];
    
    for (int i = 0; i < numClasses; i++) {
        Class cls = classes[i];
        Class superCls = class_getSuperclass(cls);
        
        // 检查是否是 NSURLSession 的子类（但不是 NSURLSession 本身）
        while (superCls) {
            if (superCls == baseClass) {
                HookMethod(cls, @selector(dataTaskWithRequest:completionHandler:),
                           (IMP)HookedDataTaskWithRequest, &kRequestTaskOriginalKey, NULL, YES);
                HookMethod(cls, @selector(dataTaskWithURL:completionHandler:),
                           (IMP)HookedDataTaskWithURL, &kURLTaskOriginalKey, NULL, YES);
                break;
            }
            superCls = class_getSuperclass(superCls);
        }
    }
    
    free(classes);
}

static void HookNSURLSessionClass(Class cls) {
    HookMethod(cls, @selector(dataTaskWithRequest:completionHandler:),
               (IMP)HookedDataTaskWithRequest, &kRequestTaskOriginalKey, NULL, YES);
    HookMethod(cls, @selector(dataTaskWithURL:completionHandler:),
               (IMP)HookedDataTaskWithURL, &kURLTaskOriginalKey, NULL, YES);
    HookMethod(cls, @selector(initWithConfiguration:delegate:delegateQueue:),
               (IMP)HookedSessionInit, &kSessionInitOriginalKey, NULL, YES);
}

// Hook NSURLSessionTask 的 resume 方法，用于捕获所有任务（包括 upload/download）
static char kTaskResumeOriginalKey;

static void HookedTaskResume(id self, SEL command) {
    IMP imp = OriginalIMP(self, &kTaskResumeOriginalKey, (IMP)HookedTaskResume);
    
    // 如果是 data task 且没有 completion handler，确保 delegate 被 hook
    if ([self isKindOfClass:[NSURLSessionDataTask class]]) {
        NSURLSessionTask *task = (NSURLSessionTask *)self;
        if (task && !objc_getAssociatedObject(task, &kCompletionTaskKey)) {
            // 尝试获取 session 的 delegate 并 hook
            id session = [task valueForKey:@"session"];
            if (session && [session isKindOfClass:[NSURLSession class]]) {
                id delegate = [session delegate];
                if (delegate) {
                    HookDelegateClass(object_getClass(delegate));
                }
            }
        }
    }
    
    if (imp) {
        void (*original)(id, SEL) = (void *)imp;
        original(self, command);
    }
}

void RegisterURLResponseHooks(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        gResponseQueue = dispatch_queue_create("com.iosnixiangzhushou.urlcapture",
                                                DISPATCH_QUEUE_SERIAL);
        gTaskStates = [NSMutableDictionary dictionary];

        [NSURLProtocol registerClass:[IZXURLCaptureProtocol class]];
        HookClassMethod([NSURLSessionConfiguration class], @selector(defaultSessionConfiguration),
                        (IMP)HookedDefaultSessionConfiguration, &kDefaultConfigOriginalKey, NULL);
        HookClassMethod([NSURLSessionConfiguration class], @selector(ephemeralSessionConfiguration),
                        (IMP)HookedEphemeralSessionConfiguration, &kEphemeralConfigOriginalKey, NULL);

        Class baseClass = [NSURLSession class];
        HookNSURLSessionClass(baseClass);

        Class localSession = NSClassFromString(@"__NSURLSessionLocal");
        if (localSession && localSession != baseClass) {
            HookNSURLSessionClass(localSession);
        }

        Class taskClass = [NSURLSessionTask class];
        HookMethod(taskClass, @selector(resume),
                   (IMP)HookedTaskResume, &kTaskResumeOriginalKey, "v@:", YES);

        NSLog(@"[URLCapture] NSURLSession + NSURLProtocol response hooks registered successfully");
    });
}
