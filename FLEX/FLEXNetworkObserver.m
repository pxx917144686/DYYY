//
//  FLEXNetworkObserver.m
//  源自:
//
//  PDAFNetworkDomainController.m
//  PonyDebugger
//
//  Created by Mike Lewis on 2/27/12.
//
//  根据一个或多个贡献者许可协议许可给Square, Inc.
//  有关此文件适用的许可条款，请参阅分发此作品的许可证文件。
//
//  由Tanner Bennett和其他各种贡献者进行了大量修改和添加。
//  git blame详细说明了这些修改。
//

#import "FLEXNetworkObserver.h"
#import "FLEXNetworkRecorder.h"
#import "FLEXUtility.h"
#import "NSUserDefaults+FLEX.h"
#import "NSObject+FLEX_Reflection.h"
#import "FLEXMethod.h"
#import "Firestore.h"

#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dispatch/queue.h>
#include <dlfcn.h>

NSString *const kFLEXNetworkObserverEnabledStateChangedNotification = @"kFLEXNetworkObserverEnabledStateChangedNotification";

typedef void (^NSURLSessionAsyncCompletion)(id fileURLOrData, NSURLResponse *response, NSError *error);
typedef NSURLSessionTask * (^NSURLSessionNewTaskMethod)(NSURLSession *, id, NSURLSessionAsyncCompletion);

@interface FLEXInternalRequestState : NSObject

@property (nonatomic, copy) NSURLRequest *request;
@property (nonatomic) NSMutableData *dataAccumulator;

@end

@implementation FLEXInternalRequestState

@end

@interface FLEXNetworkObserver (NSURLConnectionHelpers)

- (void)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)response delegate:(id<NSURLConnectionDelegate>)delegate;
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response delegate:(id<NSURLConnectionDelegate>)delegate;

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data delegate:(id<NSURLConnectionDelegate>)delegate;

- (void)connectionDidFinishLoading:(NSURLConnection *)connection delegate:(id<NSURLConnectionDelegate>)delegate;
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error delegate:(id<NSURLConnectionDelegate>)delegate;

- (void)connectionWillCancel:(NSURLConnection *)connection;

@end


@interface FLEXNetworkObserver (NSURLSessionTaskHelpers)

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest *))completionHandler delegate:(id<NSURLSessionDelegate>)delegate;
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler delegate:(id<NSURLSessionDelegate>)delegate;
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data delegate:(id<NSURLSessionDelegate>)delegate;
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
didBecomeDownloadTask:(NSURLSessionDownloadTask *)downloadTask delegate:(id<NSURLSessionDelegate>)delegate;
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error delegate:(id<NSURLSessionDelegate>)delegate;
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite delegate:(id<NSURLSessionDelegate>)delegate;
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location data:(NSData *)data delegate:(id<NSURLSessionDelegate>)delegate;

- (void)URLSessionTaskWillResume:(NSURLSessionTask *)task;

- (void)websocketTask:(NSURLSessionWebSocketTask *)task
        sendMessagage:(NSURLSessionWebSocketMessage *)message API_AVAILABLE(ios(13.0));
- (void)websocketTaskMessageSendCompletion:(NSURLSessionWebSocketMessage *)message
                                     error:(NSError *)error API_AVAILABLE(ios(13.0));

- (void)websocketTask:(NSURLSessionWebSocketTask *)task
     receiveMessagage:(NSURLSessionWebSocketMessage *)message
                error:(NSError *)error API_AVAILABLE(ios(13.0));

@end

@interface FLEXNetworkObserver ()

@property (nonatomic) NSMutableDictionary<NSString *, FLEXInternalRequestState *> *requestStatesForRequestIDs;
@property (nonatomic) dispatch_queue_t queue;

@end

@implementation FLEXNetworkObserver

#pragma mark - Public Methods

+ (void)setEnabled:(BOOL)enabled {
    BOOL previouslyEnabled = [self isEnabled];
    
    NSUserDefaults.standardUserDefaults.flex_networkObserverEnabled = enabled;
    
    if (enabled) {
        // 如果需要，进行注入。此注入受dispatch_once保护，因此我们可以安全地多次调用它。
        // 通过延迟注入，当此功能未启用时，我们可以降低工具的影响。
        [self setNetworkMonitorHooks];
    }
    
    if (previouslyEnabled != enabled) {
        [NSNotificationCenter.defaultCenter postNotificationName:kFLEXNetworkObserverEnabledStateChangedNotification object:self];
    }
}

+ (BOOL)isEnabled {
    return NSUserDefaults.standardUserDefaults.flex_networkObserverEnabled;
}

+ (void)load {
    // 我们不希望从+load进行方法交换，因为我们想要钩住的所有
    // 代理类可能尚未加载。
    // 然而，Firebase类现在肯定已经加载了，
    // 因此我们可以更早地钩住这些类。
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self isEnabled]) {
            [self setNetworkMonitorHooks];
        }
    });
}

#pragma mark - Statics

+ (instancetype)sharedObserver {
    static FLEXNetworkObserver *sharedObserver = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedObserver = [self new];
    });
    return sharedObserver;
}

+ (NSString *)nextRequestID {
    return NSUUID.UUID.UUIDString;
}

#pragma mark 代理注入便捷方法

/// 所有交换（swizzled）的代理方法都应使用此保护措施。
/// 这将防止在原始实现调用父类实现时重复嗅探
/// 我们也交换了这个父类实现。如果从原始实现调用，父类实现
/// （以及上层类中的实现）将在不受干扰的情况下执行。
+ (void)sniffWithoutDuplicationForObject:(NSObject *)object selector:(SEL)selector
                           sniffingBlock:(void (^)(void))sniffingBlock originalImplementationBlock:(void (^)(void))originalImplementationBlock {
    // 如果我们没有一个对象来检测嵌套调用，只需运行原始实现并返回即可。
    // 如果URL加载系统以外的人直接调用代理方法，可能会发生这种情况。
    // 例子请参见 https://github.com/Flipboard/FLEX/issues/61
    if (!object) {
        originalImplementationBlock();
        return;
    }

    const void *key = selector;

    // 如果我们在嵌套调用中，不要运行嗅探块
    if (!objc_getAssociatedObject(object, key)) {
        sniffingBlock();
    }

    // 标记我们正在调用原始方法，这样我们就可以检测嵌套调用
    objc_setAssociatedObject(object, key, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    originalImplementationBlock();
    objc_setAssociatedObject(object, key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - Hooking

static void (*_logos_orig$_ungrouped$FIRDocumentReference$getDocumentWithCompletion$)(
    _LOGOS_SELF_TYPE_NORMAL FIRDocumentReference * _LOGOS_SELF_CONST, SEL, FIRDocumentSnapshotBlock);
static void _logos_method$_ungrouped$FIRDocumentReference$getDocumentWithCompletion$(
    _LOGOS_SELF_TYPE_NORMAL FIRDocumentReference * _LOGOS_SELF_CONST, SEL, FIRDocumentSnapshotBlock);
static void (*_logos_orig$_ungrouped$FIRQuery$getDocumentsWithCompletion$)(
    _LOGOS_SELF_TYPE_NORMAL FIRQuery * _LOGOS_SELF_CONST, SEL, FIRQuerySnapshotBlock);
static void _logos_method$_ungrouped$FIRQuery$getDocumentsWithCompletion$(
    _LOGOS_SELF_TYPE_NORMAL FIRQuery * _LOGOS_SELF_CONST, SEL, FIRQuerySnapshotBlock);

static void (*_logos_orig$_ungrouped$FIRDocumentReference$setData$merge$completion$)(
 _LOGOS_SELF_TYPE_NORMAL FIRDocumentReference * _LOGOS_SELF_CONST, SEL, NSDictionary *, BOOL, void (^)(NSError *));
static void (*_logos_orig$_ungrouped$FIRDocumentReference$setData$mergeFields$completion$)(
 _LOGOS_SELF_TYPE_NORMAL FIRDocumentReference * _LOGOS_SELF_CONST, SEL, NSDictionary *, NSArray *, void (^)(NSError *));
static void (*_logos_orig$_ungrouped$FIRDocumentReference$updateData$completion$)(
 _LOGOS_SELF_TYPE_NORMAL FIRDocumentReference * _LOGOS_SELF_CONST, SEL, NSDictionary *, void (^)(NSError *));
static void (*_logos_orig$_ungrouped$FIRDocumentReference$deleteDocumentWithCompletion$)(
 _LOGOS_SELF_TYPE_NORMAL FIRDocumentReference * _LOGOS_SELF_CONST, SEL, void (^)(NSError *));

static void _logos_register_hook(Class _class, SEL _cmd, IMP _new, IMP *_old) {
    unsigned int _count, _i;
    Class _searchedClass = _class;
    Method *_methods;
    while (_searchedClass) {
        _methods = class_copyMethodList(_searchedClass, &_count);
        for (_i = 0; _i < _count; _i++) {
            if (method_getName(_methods[_i]) == _cmd) {
                if (_class == _searchedClass) {
                    *_old = method_getImplementation(_methods[_i]);
                    *_old = class_replaceMethod(_class, _cmd, _new, method_getTypeEncoding(_methods[_i]));
                } else {
                    class_addMethod(_class, _cmd, _new, method_getTypeEncoding(_methods[_i]));
                }
                free(_methods);
                return;
            }
        }
        free(_methods);
        _searchedClass = class_getSuperclass(_searchedClass);
    }
}

static Class _logos_superclass$_ungrouped$FIRDocumentReference;
static void (*_logos_orig$_ungrouped$FIRDocumentReference$getDocumentWithCompletion$)(
    _LOGOS_SELF_TYPE_NORMAL FIRDocumentReference * _LOGOS_SELF_CONST, SEL, FIRDocumentSnapshotBlock);
static Class _logos_superclass$_ungrouped$FIRQuery;
static void (*_logos_orig$_ungrouped$FIRQuery$getDocumentsWithCompletion$)(
    _LOGOS_SELF_TYPE_NORMAL FIRQuery * _LOGOS_SELF_CONST, SEL, FIRQuerySnapshotBlock);
static Class _logos_superclass$_ungrouped$FIRCollectionReference;
static FIRDocumentReference * (*_logos_orig$_ungrouped$FIRCollectionReference$addDocumentWithData$completion$)(
    _LOGOS_SELF_TYPE_NORMAL FIRCollectionReference * _LOGOS_SELF_CONST, SEL, NSDictionary *, void (^)(NSError *error));

#pragma mark Firebase, 读取数据

static void _logos_method$_ungrouped$FIRDocumentReference$getDocumentWithCompletion$(
    _LOGOS_SELF_TYPE_NORMAL FIRDocumentReference * _LOGOS_SELF_CONST self, SEL _cmd, FIRDocumentSnapshotBlock completion) {
    
    // 生成事务ID
    NSString *requestID = [FLEXNetworkObserver nextRequestID];
    
    // 记录事务开始
    [FLEXNetworkRecorder.defaultRecorder recordFIRDocumentWillFetch:self withTransactionID:requestID];
    // 钩住回调
    FIRDocumentSnapshotBlock orig = completion;
    completion = ^(FIRDocumentSnapshot *document, NSError *error) {
        [FLEXNetworkRecorder.defaultRecorder recordFIRDocumentDidFetch:document error:error transactionID:requestID];
        if (orig != nil) {
            orig(document, error);
        }
    };
    
    // 转发调用
    (_logos_orig$_ungrouped$FIRDocumentReference$getDocumentWithCompletion$ ? _logos_orig$_ungrouped$FIRDocumentReference$getDocumentWithCompletion$ : (__typeof__(_logos_orig$_ungrouped$FIRDocumentReference$getDocumentWithCompletion$))class_getMethodImplementation(_logos_superclass$_ungrouped$FIRDocumentReference, @selector(getDocumentWithCompletion:)))(self, _cmd, completion);
}

static void _logos_method$_ungrouped$FIRQuery$getDocumentsWithCompletion$(
    _LOGOS_SELF_TYPE_NORMAL FIRQuery * _LOGOS_SELF_CONST self, SEL _cmd, FIRQuerySnapshotBlock completion) {
    
    // 生成事务ID
    NSString *requestID = [FLEXNetworkObserver nextRequestID];
    
    // 记录事务开始
    [FLEXNetworkRecorder.defaultRecorder recordFIRQueryWillFetch:self withTransactionID:requestID];
    // 钩住回调
    FIRQuerySnapshotBlock orig = completion;
    completion = ^(FIRQuerySnapshot *query, NSError *error) {
        [FLEXNetworkRecorder.defaultRecorder recordFIRQueryDidFetch:query error:error transactionID:requestID];
        if (orig != nil) {
            orig(query, error);
        }
    };
    
    // 转发调用
    (_logos_orig$_ungrouped$FIRQuery$getDocumentsWithCompletion$ ? _logos_orig$_ungrouped$FIRQuery$getDocumentsWithCompletion$ : (__typeof__(_logos_orig$_ungrouped$FIRQuery$getDocumentsWithCompletion$))class_getMethodImplementation(_logos_superclass$_ungrouped$FIRQuery, @selector(getDocumentsWithCompletion:)))(self, _cmd, completion);
}

#pragma mark Firebase, 写入数据

static void _logos_method$_ungrouped$FIRDocumentReference$setData$merge$completion$(
    _LOGOS_SELF_TYPE_NORMAL FIRDocumentReference * _LOGOS_SELF_CONST __unused self,
    SEL __unused _cmd, NSDictionary<NSString *, id> * documentData, BOOL merge, void (^completion)(NSError *)) {

    // 生成事务ID
    NSString *requestID = [FLEXNetworkObserver nextRequestID];
    
    // 记录事务开始
    [FLEXNetworkRecorder.defaultRecorder
        recordFIRWillSetData:self
        data:documentData
        merge:@(merge)
        mergeFields:nil
        transactionID:requestID
    ];
    
    // 钩住回调
    void (^orig)(NSError *) = completion;
    completion = ^(NSError *error) {
        [FLEXNetworkRecorder.defaultRecorder recordFIRDidSetData:error transactionID:requestID];
        if (orig != nil) {
            orig(error);
        }
    };
    
    // 转发调用
    (_logos_orig$_ungrouped$FIRDocumentReference$setData$merge$completion$ ? _logos_orig$_ungrouped$FIRDocumentReference$setData$merge$completion$ : (__typeof__(_logos_orig$_ungrouped$FIRDocumentReference$setData$merge$completion$))class_getMethodImplementation(_logos_superclass$_ungrouped$FIRDocumentReference, @selector(setData:merge:completion:)))(self, _cmd, documentData, merge, completion);
}

static void _logos_method$_ungrouped$FIRDocumentReference$setData$mergeFields$completion$(
    _LOGOS_SELF_TYPE_NORMAL FIRDocumentReference * _LOGOS_SELF_CONST __unused self,
    SEL __unused _cmd, NSDictionary<NSString *, id> * documentData,
    NSArray * mergeFields, void (^completion)(NSError *)) {

    // 生成事务ID
    NSString *requestID = [FLEXNetworkObserver nextRequestID];
    
    // 记录事务开始
    [FLEXNetworkRecorder.defaultRecorder
        recordFIRWillSetData:self
        data:documentData
        merge:nil
        mergeFields:mergeFields
        transactionID:requestID
    ];

    // 钩住回调
    void (^orig)(NSError *) = completion;
    completion = ^(NSError *error) {
        [FLEXNetworkRecorder.defaultRecorder recordFIRDidSetData:error transactionID:requestID];
        if (orig != nil) {
            orig(error);
        }
    };
    
    // 转发调用
    (_logos_orig$_ungrouped$FIRDocumentReference$setData$mergeFields$completion$ ? _logos_orig$_ungrouped$FIRDocumentReference$setData$mergeFields$completion$ : (__typeof__(_logos_orig$_ungrouped$FIRDocumentReference$setData$mergeFields$completion$))class_getMethodImplementation(_logos_superclass$_ungrouped$FIRDocumentReference, @selector(setData:mergeFields:completion:)))(self, _cmd, documentData, mergeFields, completion);
}

static void _logos_method$_ungrouped$FIRDocumentReference$updateData$completion$(
    _LOGOS_SELF_TYPE_NORMAL FIRDocumentReference * _LOGOS_SELF_CONST __unused self,
    SEL __unused _cmd, NSDictionary<id, id> * fields, void (^completion)(NSError *)) {

    // 生成事务ID
    NSString *requestID = [FLEXNetworkObserver nextRequestID];
    
    // 记录事务开始
    [FLEXNetworkRecorder.defaultRecorder recordFIRWillUpdateData:self fields:fields transactionID:requestID];
    // 钩住回调
    void (^orig)(NSError *) = completion;
    completion = ^(NSError *error) {
        [FLEXNetworkRecorder.defaultRecorder recordFIRDidUpdateData:error transactionID:requestID];
        if (orig != nil) {
            orig(error);
        }
    };
    
    // 转发调用
    (_logos_orig$_ungrouped$FIRDocumentReference$updateData$completion$ ? _logos_orig$_ungrouped$FIRDocumentReference$updateData$completion$ : (__typeof__(_logos_orig$_ungrouped$FIRDocumentReference$updateData$completion$))class_getMethodImplementation(_logos_superclass$_ungrouped$FIRDocumentReference, @selector(updateData:completion:)))(self, _cmd, fields, completion);
}

static void _logos_method$_ungrouped$FIRDocumentReference$deleteDocumentWithCompletion$(
    _LOGOS_SELF_TYPE_NORMAL FIRDocumentReference * _LOGOS_SELF_CONST __unused self,
    SEL __unused _cmd, void (^completion)(NSError *)) {

    // 生成事务ID
    NSString *requestID = [FLEXNetworkObserver nextRequestID];
    
    // 记录事务开始
    [FLEXNetworkRecorder.defaultRecorder recordFIRWillDeleteDocument:self transactionID:requestID];
    // 钩住回调
    void (^orig)(NSError *) = completion;
    completion = ^(NSError *error) {
        [FLEXNetworkRecorder.defaultRecorder recordFIRDidDeleteDocument:error transactionID:requestID];
        if (orig != nil) {
            orig(error);
        }
    };
    
    // 转发调用
    (_logos_orig$_ungrouped$FIRDocumentReference$deleteDocumentWithCompletion$ ? _logos_orig$_ungrouped$FIRDocumentReference$deleteDocumentWithCompletion$ : (__typeof__(_logos_orig$_ungrouped$FIRDocumentReference$deleteDocumentWithCompletion$))class_getMethodImplementation(_logos_superclass$_ungrouped$FIRDocumentReference, @selector(deleteDocumentWithCompletion:)))(self, _cmd, completion);
}

static FIRDocumentReference * _logos_method$_ungrouped$FIRCollectionReference$addDocumentWithData$completion$(
    _LOGOS_SELF_TYPE_NORMAL FIRCollectionReference * _LOGOS_SELF_CONST __unused self,
    SEL __unused _cmd, NSDictionary<NSString *, id> * data, void (^completion)(NSError *error)) {

    // 生成事务ID
    NSString *requestID = [FLEXNetworkObserver nextRequestID];

    // 钩住回调
    void (^orig)(NSError *) = completion;
    completion = ^(NSError *error) {
        [FLEXNetworkRecorder.defaultRecorder recordFIRDidAddDocument:error transactionID:requestID];
        if (orig != nil) {
            orig(error);
        }
    };

    // 转发调用
    FIRDocumentReference *ret = (_logos_orig$_ungrouped$FIRCollectionReference$addDocumentWithData$completion$ ? _logos_orig$_ungrouped$FIRCollectionReference$addDocumentWithData$completion$ : (__typeof__(_logos_orig$_ungrouped$FIRCollectionReference$addDocumentWithData$completion$))class_getMethodImplementation(_logos_superclass$_ungrouped$FIRCollectionReference, @selector(addDocumentWithData:completion:)))(self, _cmd, data, completion);

    // 记录事务开始
    [FLEXNetworkRecorder.defaultRecorder recordFIRWillAddDocument:self document:ret transactionID:requestID];

    // 返回
    return ret;
}

+ (void)setNetworkMonitorHooks {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self hookFirebaseThings];
        [self injectIntoAllNSURLThings];
    });
}

+ (void)hookFirebaseThings {
    Class _logos_class$_ungrouped$FIRDocumentReference = objc_getClass("FIRDocumentReference");
    _logos_superclass$_ungrouped$FIRDocumentReference = class_getSuperclass(_logos_class$_ungrouped$FIRDocumentReference);
    Class _logos_class$_ungrouped$FIRQuery = objc_getClass("FIRQuery");
    _logos_superclass$_ungrouped$FIRQuery = class_getSuperclass(_logos_class$_ungrouped$FIRQuery);
    Class _logos_class$_ungrouped$FIRCollectionReference = objc_getClass("FIRCollectionReference");
    _logos_superclass$_ungrouped$FIRCollectionReference = class_getSuperclass(_logos_class$_ungrouped$FIRCollectionReference);

    // 读取 //

    _logos_register_hook(
        _logos_class$_ungrouped$FIRDocumentReference,
        @selector(getDocumentWithCompletion:),
        (IMP)&_logos_method$_ungrouped$FIRDocumentReference$getDocumentWithCompletion$,
        (IMP *)&_logos_orig$_ungrouped$FIRDocumentReference$getDocumentWithCompletion$
    );

    _logos_register_hook(
        _logos_class$_ungrouped$FIRQuery,
        @selector(getDocumentsWithCompletion:),
        (IMP)&_logos_method$_ungrouped$FIRQuery$getDocumentsWithCompletion$,
        (IMP *)&_logos_orig$_ungrouped$FIRQuery$getDocumentsWithCompletion$
    );

    // 写入 //

    _logos_register_hook(
        _logos_class$_ungrouped$FIRDocumentReference,
        @selector(setData:merge:completion:),
        (IMP)&_logos_method$_ungrouped$FIRDocumentReference$setData$merge$completion$,
        (IMP *)&_logos_orig$_ungrouped$FIRDocumentReference$setData$merge$completion$
    );
    _logos_register_hook(
        _logos_class$_ungrouped$FIRDocumentReference,
        @selector(setData:mergeFields:completion:),
        (IMP)&_logos_method$_ungrouped$FIRDocumentReference$setData$mergeFields$completion$,
        (IMP *)&_logos_orig$_ungrouped$FIRDocumentReference$setData$mergeFields$completion$
    );
    _logos_register_hook(
        _logos_class$_ungrouped$FIRDocumentReference,
        @selector(updateData:completion:),
        (IMP)&_logos_method$_ungrouped$FIRDocumentReference$updateData$completion$,
        (IMP *)&_logos_orig$_ungrouped$FIRDocumentReference$updateData$completion$
    );
    _logos_register_hook(
        _logos_class$_ungrouped$FIRDocumentReference,
        @selector(deleteDocumentWithCompletion:),
        (IMP)&_logos_method$_ungrouped$FIRDocumentReference$deleteDocumentWithCompletion$,
        (IMP *)&_logos_orig$_ungrouped$FIRDocumentReference$deleteDocumentWithCompletion$
    );
    _logos_register_hook(
        _logos_class$_ungrouped$FIRCollectionReference,
        @selector(addDocumentWithData:completion:),
        (IMP)&_logos_method$_ungrouped$FIRCollectionReference$addDocumentWithData$completion$,
        (IMP *)&_logos_orig$_ungrouped$FIRCollectionReference$addDocumentWithData$completion$
    );
}

+ (void)injectIntoAllNSURLThings {
    // 只允许交换一次。
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // 交换任何实现了这些选择器之一的类。
        const SEL selectors[] = {
            @selector(connectionDidFinishLoading:),
            @selector(connection:willSendRequest:redirectResponse:),
            @selector(connection:didReceiveResponse:),
            @selector(connection:didReceiveData:),
            @selector(connection:didFailWithError:),
            @selector(URLSession:task:willPerformHTTPRedirection:newRequest:completionHandler:),
            @selector(URLSession:dataTask:didReceiveData:),
            @selector(URLSession:dataTask:didReceiveResponse:completionHandler:),
            @selector(URLSession:task:didCompleteWithError:),
            @selector(URLSession:dataTask:didBecomeDownloadTask:),
            @selector(URLSession:downloadTask:didWriteData:totalBytesWritten:totalBytesExpectedToWrite:),
            @selector(URLSession:downloadTask:didFinishDownloadingToURL:)
        };

        const int numSelectors = sizeof(selectors) / sizeof(SEL);

        Class *classes = NULL;
        int numClasses = objc_getClassList(NULL, 0);

        if (numClasses > 0) {
            classes = (__unsafe_unretained Class *)malloc(sizeof(Class) * numClasses);
            numClasses = objc_getClassList(classes, numClasses);
            for (NSInteger classIndex = 0; classIndex < numClasses; ++classIndex) {
                Class class = classes[classIndex];

                if (class == [FLEXNetworkObserver class]) {
                    continue;
                }

                // 使用C API而不是NSObject方法，以避免向我们不感兴趣的类发送消息
                // 这可能导致我们在潜在未初始化的类上调用+initialize。
                // 注意：调用class_getInstanceMethod()会向类发送+initialize
                // 这就是我们遍历方法列表的原因。
                unsigned int methodCount = 0;
                Method *methods = class_copyMethodList(class, &methodCount);
                BOOL matchingSelectorFound = NO;
                for (unsigned int methodIndex = 0; methodIndex < methodCount; methodIndex++) {
                    for (int selectorIndex = 0; selectorIndex < numSelectors; ++selectorIndex) {
                        if (method_getName(methods[methodIndex]) == selectors[selectorIndex]) {
                            [self injectIntoDelegateClass:class];
                            matchingSelectorFound = YES;
                            break;
                        }
                    }
                    if (matchingSelectorFound) {
                        break;
                    }
                }
                
                free(methods);
            }
            
            free(classes);
        }

        [self injectIntoNSURLConnectionCancel];
        [self injectIntoNSURLSessionTaskResume];

        [self injectIntoNSURLConnectionAsynchronousClassMethod];
        [self injectIntoNSURLConnectionSynchronousClassMethod];

        Class URLSession = [NSURLSession class];
        [self injectIntoNSURLSessionAsyncDataAndDownloadTaskMethods:URLSession];
        [self injectIntoNSURLSessionAsyncUploadTaskMethods:URLSession];
        
        // 在某些时候，NSURLSession.sharedSession变成了__NSURLSessionLocal，
        // 这不是[NSURLSession class]返回的类，当然
        Class URLSessionLocal = NSClassFromString(@"__NSURLSessionLocal");
        if (URLSessionLocal && (URLSession != URLSessionLocal)) {
            [self injectIntoNSURLSessionAsyncDataAndDownloadTaskMethods:URLSessionLocal];
            [self injectIntoNSURLSessionAsyncUploadTaskMethods:URLSessionLocal];
        }
        
        if (@available(iOS 13.0, *)) {
            Class websocketTask = NSClassFromString(@"__NSURLSessionWebSocketTask");
            [self injectWebsocketSendMessage:websocketTask];
            [self injectWebsocketReceiveMessage:websocketTask];
            websocketTask = [NSURLSessionWebSocketTask class];
            [self injectWebsocketSendMessage:websocketTask];
            [self injectWebsocketReceiveMessage:websocketTask];
        }
    });
}

+ (void)injectIntoDelegateClass:(Class)cls {
    // Connections
    [self injectWillSendRequestIntoDelegateClass:cls];
    [self injectDidReceiveDataIntoDelegateClass:cls];
    [self injectDidReceiveResponseIntoDelegateClass:cls];
    [self injectDidFinishLoadingIntoDelegateClass:cls];
    [self injectDidFailWithErrorIntoDelegateClass:cls];
    
    // Sessions
    [self injectTaskWillPerformHTTPRedirectionIntoDelegateClass:cls];
    [self injectTaskDidReceiveDataIntoDelegateClass:cls];
    [self injectTaskDidReceiveResponseIntoDelegateClass:cls];
    [self injectTaskDidCompleteWithErrorIntoDelegateClass:cls];
    [self injectRespondsToSelectorIntoDelegateClass:cls];

    // Data tasks
    [self injectDataTaskDidBecomeDownloadTaskIntoDelegateClass:cls];

    // Download tasks
    [self injectDownloadTaskDidWriteDataIntoDelegateClass:cls];
    [self injectDownloadTaskDidFinishDownloadingIntoDelegateClass:cls];
}

+ (void)injectIntoNSURLConnectionCancel {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = [NSURLConnection class];
        SEL selector = @selector(cancel);
        SEL swizzledSelector = [FLEXUtility swizzledSelectorForSelector:selector];
        Method originalCancel = class_getInstanceMethod(class, selector);

        void (^swizzleBlock)(NSURLConnection *) = ^(NSURLConnection *slf) {
            [FLEXNetworkObserver.sharedObserver connectionWillCancel:slf];
            ((void(*)(id, SEL))objc_msgSend)(
                slf, swizzledSelector
            );
        };

        IMP implementation = imp_implementationWithBlock(swizzleBlock);
        class_addMethod(class, swizzledSelector, implementation, method_getTypeEncoding(originalCancel));
        Method newCancel = class_getInstanceMethod(class, swizzledSelector);
        method_exchangeImplementations(originalCancel, newCancel);
    });
}

+ (void)injectIntoNSURLSessionTaskResume {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // 在iOS 7中，resume位于__NSCFLocalSessionTask中
        // 在iOS 8中，resume位于NSURLSessionTask中
        // 在iOS 9中，resume位于__NSCFURLSessionTask中
        // 在iOS 14中，resume位于NSURLSessionTask中
        Class baseResumeClass = Nil;
        if (![NSProcessInfo.processInfo respondsToSelector:@selector(operatingSystemVersion)]) {
            // iOS ... 7
            baseResumeClass = NSClassFromString(@"__NSCFLocalSessionTask");
        } else {
            NSInteger majorVersion = NSProcessInfo.processInfo.operatingSystemVersion.majorVersion;
            if (majorVersion < 9 || majorVersion >= 14) {
                // iOS 8 或 iOS 14+
                baseResumeClass = [NSURLSessionTask class];
            } else {
                // iOS 9 ... 13
                baseResumeClass = NSClassFromString(@"__NSCFURLSessionTask");
            }
        }
        
        // 钩住-resume的基本实现
        IMP originalResume = [baseResumeClass instanceMethodForSelector:@selector(resume)];
        [self swizzleResumeSelector:@selector(resume) forClass:baseResumeClass];
        
        // *叹气*
        //
        // 所以，AFNetworking 2.5.X的多个版本以各种短视的方式交换-resume。
        // 如果你查看2.5.0及以上版本的历史记录，
        // 你会看到尝试了各种技术，包括使用NSURLSessionTask的私有
        // 子类并使用下面的`originalResume`调用class_addMethod，
        // 这样在该类中就存在-resume的重复实现。
        //
        // 这种技术特别麻烦，因为`baseResumeClass`中的实现根本不会被调用，
        // 这意味着我们的交换从未被调用。
        //
        // 唯一的解决方案是一个蛮力解决方案：我们必须循环遍历类树
        // 低于`baseResumeClass`，并检查所有实现`af_resume`的类。
        // 如果与该方法对应的IMP等于`originalResume`，那么我们
        // 除了交换`baseResumeClass`上的`resume`外，还要交换它。
        //
        // 然而，我们只有在NSSelectorFromString
        // 能够首先找到`"af_resume"`选择器的情况下才费心。
        SEL sel_af_resume = NSSelectorFromString(@"af_resume");
        if (sel_af_resume) {
            NSMutableArray<Class> *classTree = FLEXGetAllSubclasses(baseResumeClass, NO).mutableCopy;
            for (NSInteger i = 0; i < classTree.count; i++) {
                [classTree addObjectsFromArray:FLEXGetAllSubclasses(classTree[i], NO)];
            }
            
            for (Class current in classTree) {
                IMP af_resume = [current instanceMethodForSelector:sel_af_resume];
                if (af_resume == originalResume) {
                    [self swizzleResumeSelector:sel_af_resume forClass:current];
                }
            }
        }
    });
}

+ (void)swizzleResumeSelector:(SEL)selector forClass:(Class)class {
    SEL swizzledSelector = [FLEXUtility swizzledSelectorForSelector:selector];
    Method originalResume = class_getInstanceMethod(class, selector);
    IMP implementation = imp_implementationWithBlock(^(NSURLSessionTask *slf) {
        
        if (@available(iOS 11.0, *)) {
            // AVAggregateAssetDownloadTask非常不喜欢被查看。访问-currentRequest或
            // -originalRequest会崩溃。不要尝试观察这些。https://github.com/FLEXTool/FLEX/issues/276
            if (![slf isKindOfClass:[AVAggregateAssetDownloadTask class]]) {
                // iOS的内部HTTP解析器完成代码神秘地不是线程安全的，
                // 异步调用它有可能导致`double free`崩溃。
                // 下面这行将同步请求HTTPBody，使HTTPParser
                // 解析请求，并提前缓存它们。之后HTTPParser
                // 将被完成。确保其他线程检查请求
                // 不会触发竞争来完成解析器。
                [slf.currentRequest HTTPBody];

                [FLEXNetworkObserver.sharedObserver URLSessionTaskWillResume:slf];
            }
        }

        ((void(*)(id, SEL))objc_msgSend)(
            slf, swizzledSelector
        );
    });
    
    class_addMethod(class, swizzledSelector, implementation, method_getTypeEncoding(originalResume));
    Method newResume = class_getInstanceMethod(class, swizzledSelector);
    method_exchangeImplementations(originalResume, newResume);
}

+ (void)injectIntoNSURLConnectionAsynchronousClassMethod {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = objc_getMetaClass(class_getName([NSURLConnection class]));
        SEL selector = @selector(sendAsynchronousRequest:queue:completionHandler:);
        SEL swizzledSelector = [FLEXUtility swizzledSelectorForSelector:selector];

        typedef void (^AsyncCompletion)(
            NSURLResponse *response, NSData *data, NSError *error
        );
        typedef void (^SendAsyncRequestBlock)(
            Class, NSURLRequest *, NSOperationQueue *, AsyncCompletion
        );
        SendAsyncRequestBlock swizzleBlock = ^(Class slf,
                                               NSURLRequest *request,
                                               NSOperationQueue *queue,
                                               AsyncCompletion completion) {
            if (FLEXNetworkObserver.isEnabled) {
                NSString *requestID = [self nextRequestID];
                [FLEXNetworkRecorder.defaultRecorder
                     recordRequestWillBeSentWithRequestID:requestID
                     request:request
                     redirectResponse:nil
                ];
                
                NSString *mechanism = [self mechanismFromClassMethod:selector onClass:class];
                [FLEXNetworkRecorder.defaultRecorder recordMechanism:mechanism forRequestID:requestID];
                
                AsyncCompletion wrapper = ^(NSURLResponse *response, NSData *data, NSError *error) {
                    [FLEXNetworkRecorder.defaultRecorder
                        recordResponseReceivedWithRequestID:requestID
                        response:response
                    ];
                    [FLEXNetworkRecorder.defaultRecorder
                         recordDataReceivedWithRequestID:requestID
                         dataLength:data.length
                    ];
                    if (error) {
                        [FLEXNetworkRecorder.defaultRecorder
                            recordLoadingFailedWithRequestID:requestID
                            error:error
                        ];
                    } else {
                        [FLEXNetworkRecorder.defaultRecorder
                            recordLoadingFinishedWithRequestID:requestID
                            responseBody:data
                        ];
                    }

                    // 调用原始完成处理程序
                    if (completion) {
                        completion(response, data, error);
                    }
                };
                ((void(*)(id, SEL, id, id, id))objc_msgSend)(
                    slf, swizzledSelector, request, queue, wrapper
                );
            } else {
                ((void(*)(id, SEL, id, id, id))objc_msgSend)(
                    slf, swizzledSelector, request, queue, completion
                );
            }
        };
        
        [FLEXUtility replaceImplementationOfKnownSelector:selector
            onClass:class withBlock:swizzleBlock swizzledSelector:swizzledSelector
        ];
    });
}

+ (void)injectIntoNSURLConnectionSynchronousClassMethod {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = objc_getMetaClass(class_getName([NSURLConnection class]));
        SEL selector = @selector(sendSynchronousRequest:returningResponse:error:);
        SEL swizzledSelector = [FLEXUtility swizzledSelectorForSelector:selector];

        typedef NSData * (^AsyncCompletion)(Class, NSURLRequest *, NSURLResponse **, NSError **);
        AsyncCompletion swizzleBlock = ^NSData *(Class slf,
                                                 NSURLRequest *request,
                                                 NSURLResponse **response,
                                                 NSError **error) {
            NSData *data = nil;
            if (FLEXNetworkObserver.isEnabled) {
                NSString *requestID = [self nextRequestID];
                [FLEXNetworkRecorder.defaultRecorder
                    recordRequestWillBeSentWithRequestID:requestID
                    request:request
                    redirectResponse:nil
                ];
                
                NSString *mechanism = [self mechanismFromClassMethod:selector onClass:class];
                [FLEXNetworkRecorder.defaultRecorder recordMechanism:mechanism forRequestID:requestID];
                NSError *temporaryError = nil;
                NSURLResponse *temporaryResponse = nil;
                data = ((id(*)(id, SEL, id, NSURLResponse **, NSError **))objc_msgSend)(
                    slf, swizzledSelector, request, &temporaryResponse, &temporaryError
                );
                
                [FLEXNetworkRecorder.defaultRecorder
                    recordResponseReceivedWithRequestID:requestID
                    response:temporaryResponse
                ];
                [FLEXNetworkRecorder.defaultRecorder
                    recordDataReceivedWithRequestID:requestID
                    dataLength:data.length
                ];
                
                if (temporaryError) {
                    [FLEXNetworkRecorder.defaultRecorder
                        recordLoadingFailedWithRequestID:requestID
                        error:temporaryError
                    ];
                } else {
                    [FLEXNetworkRecorder.defaultRecorder
                        recordLoadingFinishedWithRequestID:requestID
                        responseBody:data
                    ];
                }
                
                if (error) {
                    *error = temporaryError;
                }
                if (response) {
                    *response = temporaryResponse;
                }
            } else {
                data = ((id(*)(id, SEL, id, NSURLResponse **, NSError **))objc_msgSend)(
                    slf, swizzledSelector, request, response, error
                );
            }

            return data;
        };
        
        [FLEXUtility replaceImplementationOfKnownSelector:selector
            onClass:class withBlock:swizzleBlock swizzledSelector:swizzledSelector
        ];
    });
}

+ (void)injectIntoNSURLSessionAsyncDataAndDownloadTaskMethods:(Class)sessionClass {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = sessionClass;
        
        // 方法签名在这里非常接近，我们可以使用相同的逻辑注入到所有方法中。
        const SEL selectors[] = {
            @selector(dataTaskWithRequest:completionHandler:),
            @selector(dataTaskWithURL:completionHandler:),
            @selector(downloadTaskWithRequest:completionHandler:),
            @selector(downloadTaskWithResumeData:completionHandler:),
            @selector(downloadTaskWithURL:completionHandler:)
        };

        const int numSelectors = sizeof(selectors) / sizeof(SEL);

        for (int selectorIndex = 0; selectorIndex < numSelectors; selectorIndex++) {
            SEL selector = selectors[selectorIndex];
            SEL swizzledSelector = [FLEXUtility swizzledSelectorForSelector:selector];

            if ([FLEXUtility instanceRespondsButDoesNotImplementSelector:selector class:class]) {
                // iOS 7在NSURLSession上未实现这些方法。我们实际上想要
                // 交换__NSCFURLSession，我们可以从共享会话的类中获取
                class = [NSURLSession.sharedSession class];
            }
            
            typedef NSURLSessionTask * (^NSURLSessionNewTaskMethod)(
                NSURLSession *, id, NSURLSessionAsyncCompletion
            );
            NSURLSessionNewTaskMethod swizzleBlock = ^NSURLSessionTask *(NSURLSession *slf,
                                                                         id argument,
                                                                         NSURLSessionAsyncCompletion completion) {
                NSURLSessionTask *task = nil;
                // 检查网络观察是否开启以及是否提供了回调
                if (FLEXNetworkObserver.isEnabled && completion) {
                    NSString *requestID = [self nextRequestID];
                    NSString *mechanism = [self mechanismFromClassMethod:selector onClass:class];
                    // "钩住"完成块
                    NSURLSessionAsyncCompletion completionWrapper = [self
                        asyncCompletionWrapperForRequestID:requestID
                        mechanism:mechanism
                        completion:completion
                    ];
                    
                    // 调用原始方法
                    task = ((id(*)(id, SEL, id, id))objc_msgSend)(
                        slf, swizzledSelector, argument, completionWrapper
                    );
                    [self setRequestID:requestID forConnectionOrTask:task];
                } else {
                    // 网络观察已禁用或未提供回调，
                    // 直接传递给原始方法
                    task = ((id(*)(id, SEL, id, id))objc_msgSend)(
                        slf, swizzledSelector, argument, completion
                    );
                }
                return task;
            };
            
            // 实际交换
            [FLEXUtility replaceImplementationOfKnownSelector:selector
                onClass:class withBlock:swizzleBlock swizzledSelector:swizzledSelector
            ];
        }
    });
}

+ (void)injectIntoNSURLSessionAsyncUploadTaskMethods:(Class)sessionClass {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = sessionClass;
        
        // 方法签名在这里非常接近，我们可以使用相同的逻辑注入到所有方法中。
        // 注意它们有3个参数，因此我们不能轻易与上面的数据和下载方法合并。
        typedef NSURLSessionUploadTask *(^UploadTaskMethod)(
            NSURLSession *, NSURLRequest *, id, NSURLSessionAsyncCompletion
        );
        const SEL selectors[] = {
            @selector(uploadTaskWithRequest:fromData:completionHandler:),
            @selector(uploadTaskWithRequest:fromFile:completionHandler:)
        };

        const int numSelectors = sizeof(selectors) / sizeof(SEL);

        for (int selectorIndex = 0; selectorIndex < numSelectors; selectorIndex++) {
            SEL selector = selectors[selectorIndex];
            SEL swizzledSelector = [FLEXUtility swizzledSelectorForSelector:selector];

            if ([FLEXUtility instanceRespondsButDoesNotImplementSelector:selector class:class]) {
                // iOS 7在NSURLSession上未实现这些方法。我们实际上想要
                // 交换__NSCFURLSession，我们可以从共享会话的类中获取
                class = [NSURLSession.sharedSession class];
            }

            
            UploadTaskMethod swizzleBlock = ^NSURLSessionUploadTask *(NSURLSession * slf,
                                                                      NSURLRequest *request,
                                                                      id argument,
                                                                      NSURLSessionAsyncCompletion completion) {
                NSURLSessionUploadTask *task = nil;
                if (FLEXNetworkObserver.isEnabled && completion) {
                    NSString *requestID = [self nextRequestID];
                    NSString *mechanism = [self mechanismFromClassMethod:selector onClass:class];
                    NSURLSessionAsyncCompletion completionWrapper = [self
                        asyncCompletionWrapperForRequestID:requestID
                        mechanism:mechanism
                        completion:completion
                    ];
                    
                    task = ((id(*)(id, SEL, id, id, id))objc_msgSend)(
                        slf, swizzledSelector, request, argument, completionWrapper
                    );
                    [self setRequestID:requestID forConnectionOrTask:task];
                } else {
                    task = ((id(*)(id, SEL, id, id, id))objc_msgSend)(
                        slf, swizzledSelector, request, argument, completion
                    );
                }
                return task;
            };
            
            [FLEXUtility replaceImplementationOfKnownSelector:selector
                onClass:class withBlock:swizzleBlock swizzledSelector:swizzledSelector
            ];
        }
    });
}

+ (NSString *)mechanismFromClassMethod:(SEL)selector onClass:(Class)class {
    return [NSString stringWithFormat:@"+[%@ %@]", NSStringFromClass(class), NSStringFromSelector(selector)];
}

+ (NSURLSessionAsyncCompletion)asyncCompletionWrapperForRequestID:(NSString *)requestID
                                                        mechanism:(NSString *)mechanism
                                                       completion:(NSURLSessionAsyncCompletion)completion {
    NSURLSessionAsyncCompletion completionWrapper = ^(id fileURLOrData, NSURLResponse *response, NSError *error) {
        [FLEXNetworkRecorder.defaultRecorder recordMechanism:mechanism forRequestID:requestID];
        [FLEXNetworkRecorder.defaultRecorder
            recordResponseReceivedWithRequestID:requestID
            response:response
        ];
        
        NSData *data = nil;
        if ([fileURLOrData isKindOfClass:[NSURL class]]) {
            data = [NSData dataWithContentsOfURL:fileURLOrData];
        } else if ([fileURLOrData isKindOfClass:[NSData class]]) {
            data = fileURLOrData;
        }
        
        [FLEXNetworkRecorder.defaultRecorder
            recordDataReceivedWithRequestID:requestID
            dataLength:data.length
        ];
        
        if (error) {
            [FLEXNetworkRecorder.defaultRecorder
                recordLoadingFailedWithRequestID:requestID
                error:error
            ];
        } else {
            [FLEXNetworkRecorder.defaultRecorder
                 recordLoadingFinishedWithRequestID:requestID
                 responseBody:data
            ];
        }

        // 调用原始完成处理程序
        if (completion) {
            completion(fileURLOrData, response, error);
        }
    };
    return completionWrapper;
}

+ (void)injectWillSendRequestIntoDelegateClass:(Class)cls {
    SEL selector = @selector(connection:willSendRequest:redirectResponse:);
    SEL swizzledSelector = [FLEXUtility swizzledSelectorForSelector:selector];
    
    Protocol *protocol = @protocol(NSURLConnectionDataDelegate);
    protocol = protocol ?: @protocol(NSURLConnectionDelegate);
    struct objc_method_description methodDescription = protocol_getMethodDescription(
        protocol, selector, NO, YES
    );
    
    typedef NSURLRequest *(^WillSendRequestBlock)(
        id<NSURLConnectionDelegate> slf, NSURLConnection *connection,
        NSURLRequest *request, NSURLResponse *response
    );
    
    WillSendRequestBlock undefinedBlock = ^NSURLRequest *(id slf,
                                                          NSURLConnection *connection,
                                                          NSURLRequest *request,
                                                          NSURLResponse *response) {
        [FLEXNetworkObserver.sharedObserver
            connection:connection
            willSendRequest:request
            redirectResponse:response
            delegate:slf
        ];
        return request;
    };
    
    WillSendRequestBlock implementationBlock = ^NSURLRequest *(id slf,
                                                               NSURLConnection *connection,
                                                               NSURLRequest *request,
                                                               NSURLResponse *response) {
        __block NSURLRequest *returnValue = nil;
        [self sniffWithoutDuplicationForObject:connection selector:selector sniffingBlock:^{
            undefinedBlock(slf, connection, request, response);
        } originalImplementationBlock:^{
            returnValue = ((id(*)(id, SEL, id, id, id))objc_msgSend)(
                slf, swizzledSelector, connection, request, response
            );
        }];
        return returnValue;
    };
    
    [FLEXUtility replaceImplementationOfSelector:selector
        withSelector:swizzledSelector
        forClass:cls
        withMethodDescription:methodDescription
        implementationBlock:implementationBlock
        undefinedBlock:undefinedBlock
    ];
}

+ (void)injectDidReceiveResponseIntoDelegateClass:(Class)cls {
    SEL selector = @selector(connection:didReceiveResponse:);
    SEL swizzledSelector = [FLEXUtility swizzledSelectorForSelector:selector];
    
    Protocol *protocol = @protocol(NSURLConnectionDataDelegate);
    protocol = protocol ?: @protocol(NSURLConnectionDelegate);
    struct objc_method_description description = protocol_getMethodDescription(
        protocol, selector, NO, YES
    );
    
    typedef void (^DidReceiveResponseBlock)(
        id<NSURLConnectionDelegate> slf, NSURLConnection *connection, NSURLResponse *response
    );
    
    DidReceiveResponseBlock undefinedBlock = ^(id<NSURLConnectionDelegate> slf,
                                               NSURLConnection *connection,
                                               NSURLResponse *response) {
        [FLEXNetworkObserver.sharedObserver connection:connection
            didReceiveResponse:response delegate:slf
        ];
    };
    
    DidReceiveResponseBlock implementationBlock = ^(id<NSURLConnectionDelegate> slf,
                                                    NSURLConnection *connection,
                                                    NSURLResponse *response) {
        [self sniffWithoutDuplicationForObject:connection selector:selector sniffingBlock:^{
            undefinedBlock(slf, connection, response);
        } originalImplementationBlock:^{
            ((void(*)(id, SEL, id, id))objc_msgSend)(
                slf, swizzledSelector, connection, response
            );
        }];
    };
    
    [FLEXUtility replaceImplementationOfSelector:selector
        withSelector:swizzledSelector
        forClass:cls
        withMethodDescription:description
        implementationBlock:implementationBlock
        undefinedBlock:undefinedBlock
    ];
}

+ (void)injectDidReceiveDataIntoDelegateClass:(Class)cls {
    SEL selector = @selector(connection:didReceiveData:);
    SEL swizzledSelector = [FLEXUtility swizzledSelectorForSelector:selector];
    
    Protocol *protocol = @protocol(NSURLConnectionDataDelegate);
    protocol = protocol ?: @protocol(NSURLConnectionDelegate);
    struct objc_method_description description = protocol_getMethodDescription(
        protocol, selector, NO, YES
    );
    
    typedef void (^DidReceiveDataBlock)(
        id<NSURLConnectionDelegate> slf, NSURLConnection *connection, NSData *data
    );
    
    DidReceiveDataBlock undefinedBlock = ^(id<NSURLConnectionDelegate> slf,
                                           NSURLConnection *connection,
                                           NSData *data) {
        [FLEXNetworkObserver.sharedObserver connection:connection 
            didReceiveData:data delegate:slf
        ];
    };
    
    DidReceiveDataBlock implementationBlock = ^(id<NSURLConnectionDelegate> slf,
                                                NSURLConnection *connection,
                                                NSData *data) {
        [self sniffWithoutDuplicationForObject:connection selector:selector sniffingBlock:^{
            undefinedBlock(slf, connection, data);
        } originalImplementationBlock:^{
            ((void(*)(id, SEL, id, id))objc_msgSend)(
                slf, swizzledSelector, connection, data
            );
        }];
    };
    
    [FLEXUtility replaceImplementationOfSelector:selector
        withSelector:swizzledSelector
        forClass:cls
        withMethodDescription:description
        implementationBlock:implementationBlock
        undefinedBlock:undefinedBlock
    ];
}

+ (void)injectDidFinishLoadingIntoDelegateClass:(Class)cls {
    SEL selector = @selector(connectionDidFinishLoading:);
    SEL swizzledSelector = [FLEXUtility swizzledSelectorForSelector:selector];
    
    Protocol *protocol = @protocol(NSURLConnectionDataDelegate);
    protocol = protocol ?: @protocol(NSURLConnectionDelegate);
    struct objc_method_description description = protocol_getMethodDescription(
        protocol, selector, NO, YES
    );
    
    typedef void (^FinishLoadingBlock)(id<NSURLConnectionDelegate> slf, NSURLConnection *connection);
    
    FinishLoadingBlock undefinedBlock = ^(id<NSURLConnectionDelegate> slf, NSURLConnection *connection) {
        [FLEXNetworkObserver.sharedObserver connectionDidFinishLoading:connection delegate:slf];
    };
    
    FinishLoadingBlock implementationBlock = ^(id<NSURLConnectionDelegate> slf, NSURLConnection *connection) {
        [self sniffWithoutDuplicationForObject:connection selector:selector sniffingBlock:^{
            undefinedBlock(slf, connection);
        } originalImplementationBlock:^{
            ((void(*)(id, SEL, id))objc_msgSend)(
                slf, swizzledSelector, connection
            );
        }];
    };
    
    [FLEXUtility replaceImplementationOfSelector:selector
        withSelector:swizzledSelector forClass:cls
        withMethodDescription:description
        implementationBlock:implementationBlock
        undefinedBlock:undefinedBlock
    ];
}

+ (void)injectDidFailWithErrorIntoDelegateClass:(Class)cls {
    SEL selector = @selector(connection:didFailWithError:);
    SEL swizzledSelector = [FLEXUtility swizzledSelectorForSelector:selector];
    
    struct objc_method_description description = protocol_getMethodDescription(
        @protocol(NSURLConnectionDelegate), selector, NO, YES
    );
    
    typedef void (^DidFailWithErrorBlock)(
        id<NSURLConnectionDelegate> slf, NSURLConnection *connection, NSError *error
    );
    
    DidFailWithErrorBlock undefinedBlock = ^(id<NSURLConnectionDelegate> slf,
                                             NSURLConnection *connection,
                                             NSError *error) {
        [FLEXNetworkObserver.sharedObserver connection:connection
            didFailWithError:error delegate:slf
        ];
    };
    
    DidFailWithErrorBlock implementationBlock = ^(id<NSURLConnectionDelegate> slf,
                                                  NSURLConnection *connection,
                                                  NSError *error) {
        [self sniffWithoutDuplicationForObject:connection selector:selector sniffingBlock:^{
            undefinedBlock(slf, connection, error);
        } originalImplementationBlock:^{
            ((void(*)(id, SEL, id, id))objc_msgSend)(
                slf, swizzledSelector, connection, error
            );
        }];
    };
    
    [FLEXUtility replaceImplementationOfSelector:selector
        withSelector:swizzledSelector forClass:cls
        withMethodDescription:description
        implementationBlock:implementationBlock
        undefinedBlock:undefinedBlock
    ];
}

+ (void)injectTaskWillPerformHTTPRedirectionIntoDelegateClass:(Class)cls {
    SEL selector = @selector(URLSession:task:willPerformHTTPRedirection:newRequest:completionHandler:);
    SEL swizzledSelector = [FLEXUtility swizzledSelectorForSelector:selector];

    struct objc_method_description description = protocol_getMethodDescription(
        @protocol(NSURLSessionTaskDelegate), selector, NO, YES
    );
    
    typedef void (^HTTPRedirectionBlock)(id<NSURLSessionTaskDelegate> slf,
                                         NSURLSession *session,
                                         NSURLSessionTask *task,
                                         NSHTTPURLResponse *response,
                                         NSURLRequest *newRequest,
                                         void(^completionHandler)(NSURLRequest *));
    
    HTTPRedirectionBlock undefinedBlock = ^(id<NSURLSessionTaskDelegate> slf,
                                            NSURLSession *session,
                                            NSURLSessionTask *task,
                                            NSHTTPURLResponse *response,
                                            NSURLRequest *newRequest,
                                            void(^completionHandler)(NSURLRequest *)) {
        [FLEXNetworkObserver.sharedObserver
            URLSession:session task:task
            willPerformHTTPRedirection:response
            newRequest:newRequest
            completionHandler:completionHandler
            delegate:slf
        ];
        completionHandler(newRequest);
    };

    HTTPRedirectionBlock implementationBlock = ^(id<NSURLSessionTaskDelegate> slf,
                                                 NSURLSession *session,
                                                 NSURLSessionTask *task,
                                                 NSHTTPURLResponse *response,
                                                 NSURLRequest *newRequest,
                                                 void(^completionHandler)(NSURLRequest *)) {
        [self sniffWithoutDuplicationForObject:session selector:selector sniffingBlock:^{
            [FLEXNetworkObserver.sharedObserver
                URLSession:session task:task
                willPerformHTTPRedirection:response
                newRequest:newRequest
                completionHandler:completionHandler
                delegate:slf
            ];
        } originalImplementationBlock:^{
            ((id(*)(id, SEL, id, id, id, id, void(^)(NSURLRequest *)))objc_msgSend)(
                slf, swizzledSelector, session, task, response, newRequest, completionHandler
            );
        }];
    };

    [FLEXUtility replaceImplementationOfSelector:selector
        withSelector:swizzledSelector
        forClass:cls
        withMethodDescription:description
        implementationBlock:implementationBlock
        undefinedBlock:undefinedBlock
    ];
}

+ (void)injectTaskDidReceiveDataIntoDelegateClass:(Class)cls {
    SEL selector = @selector(URLSession:dataTask:didReceiveData:);
    SEL swizzledSelector = [FLEXUtility swizzledSelectorForSelector:selector];
    
    struct objc_method_description description = protocol_getMethodDescription(
        @protocol(NSURLSessionDataDelegate), selector, NO, YES
    );
    
    typedef void (^DidReceiveDataBlock)(id<NSURLSessionDataDelegate> slf,
                                        NSURLSession *session,
                                        NSURLSessionDataTask *dataTask,
                                        NSData *data);
    DidReceiveDataBlock undefinedBlock = ^(id<NSURLSessionDataDelegate> slf,
                                           NSURLSession *session,
                                           NSURLSessionDataTask *dataTask,
                                           NSData *data) {
        [FLEXNetworkObserver.sharedObserver URLSession:session
            dataTask:dataTask didReceiveData:data delegate:slf
        ];
    };
    
    DidReceiveDataBlock implementationBlock = ^(id<NSURLSessionDataDelegate> slf,
                                                NSURLSession *session,
                                                NSURLSessionDataTask *dataTask,
                                                NSData *data) {
        [self sniffWithoutDuplicationForObject:session selector:selector sniffingBlock:^{
            undefinedBlock(slf, session, dataTask, data);
        } originalImplementationBlock:^{
            ((void(*)(id, SEL, id, id, id))objc_msgSend)(
                slf, swizzledSelector, session, dataTask, data
            );
        }];
    };
    
    [FLEXUtility replaceImplementationOfSelector:selector
        withSelector:swizzledSelector
        forClass:cls
        withMethodDescription:description
        implementationBlock:implementationBlock
        undefinedBlock:undefinedBlock
    ];
}

+ (void)injectDataTaskDidBecomeDownloadTaskIntoDelegateClass:(Class)cls {
    SEL selector = @selector(URLSession:dataTask:didBecomeDownloadTask:);
    SEL swizzledSelector = [FLEXUtility swizzledSelectorForSelector:selector];

    struct objc_method_description description = protocol_getMethodDescription(
        @protocol(NSURLSessionDataDelegate), selector, NO, YES
    );

    typedef void (^DidBecomeDownloadTaskBlock)(id<NSURLSessionDataDelegate> slf,
                                               NSURLSession *session,
                                               NSURLSessionDataTask *dataTask,
                                               NSURLSessionDownloadTask *downloadTask);

    DidBecomeDownloadTaskBlock undefinedBlock = ^(id<NSURLSessionDataDelegate> slf,
                                                  NSURLSession *session,
                                                  NSURLSessionDataTask *dataTask,
                                                  NSURLSessionDownloadTask *downloadTask) {
        [FLEXNetworkObserver.sharedObserver URLSession:session
            dataTask:dataTask didBecomeDownloadTask:downloadTask delegate:slf
        ];
    };

    DidBecomeDownloadTaskBlock implementationBlock = ^(id<NSURLSessionDataDelegate> slf,
                                                       NSURLSession *session,
                                                       NSURLSessionDataTask *dataTask,
                                                       NSURLSessionDownloadTask *downloadTask) {
        [self sniffWithoutDuplicationForObject:session selector:selector sniffingBlock:^{
            undefinedBlock(slf, session, dataTask, downloadTask);
        } originalImplementationBlock:^{
            ((void(*)(id, SEL, id, id, id))objc_msgSend)(
                slf, swizzledSelector, session, dataTask, downloadTask
            );
        }];
    };

    [FLEXUtility replaceImplementationOfSelector:selector
        withSelector:swizzledSelector
        forClass:cls
        withMethodDescription:description
        implementationBlock:implementationBlock
        undefinedBlock:undefinedBlock
    ];
}

+ (void)injectTaskDidReceiveResponseIntoDelegateClass:(Class)cls {
    SEL selector = @selector(URLSession:dataTask:didReceiveResponse:completionHandler:);
    SEL swizzledSelector = [FLEXUtility swizzledSelectorForSelector:selector];
    
    struct objc_method_description description = protocol_getMethodDescription(
        @protocol(NSURLSessionDataDelegate), selector, NO, YES
    );
    
    typedef void (^DidReceiveResponseBlock)(id<NSURLSessionDelegate> slf,
                                            NSURLSession *session,
                                            NSURLSessionDataTask *dataTask,
                                            NSURLResponse *response,
                                            void(^completion)(NSURLSessionResponseDisposition));
    
    DidReceiveResponseBlock undefinedBlock = ^(id<NSURLSessionDelegate> slf,
                                               NSURLSession *session,
                                               NSURLSessionDataTask *dataTask,
                                               NSURLResponse *response,
                                               void(^completion)(NSURLSessionResponseDisposition)) {
        [FLEXNetworkObserver.sharedObserver
            URLSession:session
            dataTask:dataTask
            didReceiveResponse:response
            completionHandler:completion
            delegate:slf
        ];
        completion(NSURLSessionResponseAllow);
    };
    
    DidReceiveResponseBlock implementationBlock = ^(id<NSURLSessionDelegate> slf,
                                                    NSURLSession *session,
                                                    NSURLSessionDataTask *dataTask,
                                                    NSURLResponse *response,
                                                    void(^completion)(NSURLSessionResponseDisposition )) {
        [self sniffWithoutDuplicationForObject:session selector:selector sniffingBlock:^{
            [FLEXNetworkObserver.sharedObserver
                URLSession:session
                dataTask:dataTask
                didReceiveResponse:response
                completionHandler:completion
                delegate:slf
            ];
        } originalImplementationBlock:^{
            ((void(*)(id, SEL, id, id, id, void(^)(NSURLSessionResponseDisposition)))objc_msgSend)(
                slf, swizzledSelector, session, dataTask, response, completion
            );
        }];
    };
    
    [FLEXUtility replaceImplementationOfSelector:selector
        withSelector:swizzledSelector
        forClass:cls
        withMethodDescription:description
        implementationBlock:implementationBlock
        undefinedBlock:undefinedBlock
    ];

}

+ (void)injectTaskDidCompleteWithErrorIntoDelegateClass:(Class)cls {
    SEL selector = @selector(URLSession:task:didCompleteWithError:);
    SEL swizzledSelector = [FLEXUtility swizzledSelectorForSelector:selector];
    
    struct objc_method_description description = protocol_getMethodDescription(
        @protocol(NSURLSessionDataDelegate), selector, NO, YES
    );
    
    typedef void (^DidCompleteWithErrorBlock)(id<NSURLSessionTaskDelegate> slf,
                                              NSURLSession *session,
                                              NSURLSessionTask *task,
                                              NSError *error);

    DidCompleteWithErrorBlock undefinedBlock = ^(id<NSURLSessionTaskDelegate> slf,
                                                 NSURLSession *session,
                                                 NSURLSessionTask *task,
                                                 NSError *error) {
        [FLEXNetworkObserver.sharedObserver URLSession:session
            task:task didCompleteWithError:error delegate:slf
        ];
    };
    
    DidCompleteWithErrorBlock implementationBlock = ^(id<NSURLSessionTaskDelegate> slf,
                                                      NSURLSession *session,
                                                      NSURLSessionTask *task,
                                                      NSError *error) {
        [self sniffWithoutDuplicationForObject:session selector:selector sniffingBlock:^{
            undefinedBlock(slf, session, task, error);
        } originalImplementationBlock:^{
            ((void(*)(id, SEL, id, id, id))objc_msgSend)(
                slf, swizzledSelector, session, task, error
            );
        }];
    };

    [FLEXUtility replaceImplementationOfSelector:selector
        withSelector:swizzledSelector
        forClass:cls
        withMethodDescription:description
        implementationBlock:implementationBlock
        undefinedBlock:undefinedBlock
    ];
}

// 用于重写AFNetworking行为
+ (void)injectRespondsToSelectorIntoDelegateClass:(Class)cls {
    SEL selector = @selector(respondsToSelector:);
    SEL swizzledSelector = [FLEXUtility swizzledSelectorForSelector:selector];

    //Protocol *protocol = @protocol(NSURLSessionTaskDelegate);
    Method method = class_getInstanceMethod(cls, selector);
    struct objc_method_description methodDescription = *method_getDescription(method);

    typedef BOOL (^RespondsToSelectorImpl)(id self, SEL sel);
    RespondsToSelectorImpl undefinedBlock = ^(id slf, SEL sel) {
        return YES;
    };

    RespondsToSelectorImpl implementationBlock = ^(id<NSURLSessionTaskDelegate> slf, SEL sel) {
        if (sel == @selector(URLSession:dataTask:didReceiveResponse:completionHandler:)) {
            return undefinedBlock(slf, sel);
        }
        return ((BOOL(*)(id, SEL, SEL))objc_msgSend)(slf, swizzledSelector, sel);
    };

    [FLEXUtility replaceImplementationOfSelector:selector
        withSelector:swizzledSelector
        forClass:cls
        withMethodDescription:methodDescription
        implementationBlock:implementationBlock
        undefinedBlock:undefinedBlock
    ];
}

+ (void)injectDownloadTaskDidFinishDownloadingIntoDelegateClass:(Class)cls {
    SEL selector = @selector(URLSession:downloadTask:didFinishDownloadingToURL:);
    SEL swizzledSelector = [FLEXUtility swizzledSelectorForSelector:selector];

    struct objc_method_description description = protocol_getMethodDescription(
        @protocol(NSURLSessionDownloadDelegate), selector, NO, YES
    );

    typedef void (^DidFinishDownloadingBlock)(id<NSURLSessionTaskDelegate> slf,
                                              NSURLSession *session,
                                              NSURLSessionDownloadTask *task,
                                              NSURL *location);

    DidFinishDownloadingBlock undefinedBlock = ^(id<NSURLSessionTaskDelegate> slf,
                                                 NSURLSession *session,
                                                 NSURLSessionDownloadTask *task,
                                                 NSURL *location) {
        NSData *data = [NSData dataWithContentsOfFile:location.relativePath];
        [FLEXNetworkObserver.sharedObserver URLSession:session
            task:task didFinishDownloadingToURL:location data:data delegate:slf
        ];
    };

    DidFinishDownloadingBlock implementationBlock = ^(id<NSURLSessionTaskDelegate> slf,
                                                      NSURLSession *session,
                                                      NSURLSessionDownloadTask *task,
                                                      NSURL *location) {
        [self sniffWithoutDuplicationForObject:session selector:selector sniffingBlock:^{
            undefinedBlock(slf, session, task, location);
        } originalImplementationBlock:^{
            ((void(*)(id, SEL, id, id, id))objc_msgSend)(
                slf, swizzledSelector, session, task, location
            );
        }];
    };

    [FLEXUtility replaceImplementationOfSelector:selector
        withSelector:swizzledSelector
        forClass:cls
        withMethodDescription:description
        implementationBlock:implementationBlock
        undefinedBlock:undefinedBlock
    ];
}

+ (void)injectDownloadTaskDidWriteDataIntoDelegateClass:(Class)cls {
    SEL selector = @selector(URLSession:downloadTask:didWriteData:totalBytesWritten:totalBytesExpectedToWrite:);
    SEL swizzledSelector = [FLEXUtility swizzledSelectorForSelector:selector];

    struct objc_method_description description = protocol_getMethodDescription(
        @protocol(NSURLSessionDownloadDelegate), selector, NO, YES
    );

    typedef void (^DidWriteDataBlock)(id<NSURLSessionTaskDelegate> slf,
                                      NSURLSession *session,
                                      NSURLSessionDownloadTask *task,
                                      int64_t bytesWritten,
                                      int64_t totalBytesWritten,
                                      int64_t totalBytesExpectedToWrite);

    DidWriteDataBlock undefinedBlock = ^(id<NSURLSessionTaskDelegate> slf,
                                         NSURLSession *session,
                                         NSURLSessionDownloadTask *task,
                                         int64_t bytesWritten,
                                         int64_t totalBytesWritten,
                                         int64_t totalBytesExpectedToWrite) {
        [FLEXNetworkObserver.sharedObserver URLSession:session
            downloadTask:task didWriteData:bytesWritten
            totalBytesWritten:totalBytesWritten
            totalBytesExpectedToWrite:totalBytesExpectedToWrite
            delegate:slf
        ];
    };

    DidWriteDataBlock implementationBlock = ^(id<NSURLSessionTaskDelegate> slf,
                                              NSURLSession *session,
                                              NSURLSessionDownloadTask *task,
                                              int64_t bytesWritten,
                                              int64_t totalBytesWritten,
                                              int64_t totalBytesExpectedToWrite) {
        [self sniffWithoutDuplicationForObject:session selector:selector sniffingBlock:^{
            undefinedBlock(
                slf, session, task, bytesWritten,
                totalBytesWritten, totalBytesExpectedToWrite
            );
        } originalImplementationBlock:^{
            ((void(*)(id, SEL, id, id, int64_t, int64_t, int64_t))objc_msgSend)(
                slf, swizzledSelector, session, task, bytesWritten,
                totalBytesWritten, totalBytesExpectedToWrite
            );
        }];
    };

    [FLEXUtility replaceImplementationOfSelector:selector
        withSelector:swizzledSelector
        forClass:cls
        withMethodDescription:description
        implementationBlock:implementationBlock
        undefinedBlock:undefinedBlock
    ];
}

+ (void)injectWebsocketSendMessage:(Class)cls API_AVAILABLE(ios(13.0)) {
    SEL selector = @selector(sendMessage:completionHandler:);
    SEL swizzledSelector = [FLEXUtility swizzledSelectorForSelector:selector];

    typedef void (^SendMessageBlock)(
        NSURLSessionWebSocketTask *slf,
        NSURLSessionWebSocketMessage *message,
        void (^completion)(NSError *error)
    );

    SendMessageBlock implementationBlock = ^(
        NSURLSessionWebSocketTask *slf,
        NSURLSessionWebSocketMessage *message,
        void (^completion)(NSError *error)
    ) {
        [FLEXNetworkObserver.sharedObserver
            websocketTask:slf sendMessagage:message
        ];
        
        id completionHook = ^(NSError *error) {
            [FLEXNetworkObserver.sharedObserver
                websocketTaskMessageSendCompletion:message
                error:error
            ];
            if (completion) {
                completion(error);
            }
        };
        
        ((void(*)(id, SEL, id, id))objc_msgSend)(
            slf, swizzledSelector, message, completionHook
        );
    };

    [FLEXUtility replaceImplementationOfKnownSelector:selector
        onClass:cls
        withBlock:implementationBlock
        swizzledSelector:swizzledSelector
    ];
}

+ (void)injectWebsocketReceiveMessage:(Class)cls API_AVAILABLE(ios(13.0)) {
    SEL selector = @selector(receiveMessageWithCompletionHandler:);
    SEL swizzledSelector = [FLEXUtility swizzledSelectorForSelector:selector];

    typedef void (^SendMessageBlock)(
        NSURLSessionWebSocketTask *slf,
        void (^completion)(NSURLSessionWebSocketMessage *message, NSError *error)
    );

    SendMessageBlock implementationBlock = ^(
        NSURLSessionWebSocketTask *slf,
        void (^completion)(NSURLSessionWebSocketMessage *message, NSError *error)
    ) {        
        id completionHook = ^(NSURLSessionWebSocketMessage *message, NSError *error) {
            [FLEXNetworkObserver.sharedObserver
                websocketTask:slf receiveMessagage:message error:error
            ];
            completion(message, error);
        };
        
        ((void(*)(id, SEL, id))objc_msgSend)(
            slf, swizzledSelector, completionHook
        );

    };

    [FLEXUtility replaceImplementationOfKnownSelector:selector
        onClass:cls
        withBlock:implementationBlock
        swizzledSelector:swizzledSelector
    ];
}

static char const * const kFLEXRequestIDKey = "kFLEXRequestIDKey";

+ (NSString *)requestIDForConnectionOrTask:(id)connectionOrTask {
    NSString *requestID = objc_getAssociatedObject(connectionOrTask, kFLEXRequestIDKey);
    if (!requestID) {
        requestID = [self nextRequestID];
        [self setRequestID:requestID forConnectionOrTask:connectionOrTask];
    }
    return requestID;
}

+ (void)setRequestID:(NSString *)requestID forConnectionOrTask:(id)connectionOrTask {
    objc_setAssociatedObject(
        connectionOrTask, kFLEXRequestIDKey, requestID, OBJC_ASSOCIATION_RETAIN_NONATOMIC
    );
}

#pragma mark - 初始化

- (id)init {
    self = [super init];
    if (self) {
        self.requestStatesForRequestIDs = [NSMutableDictionary new];
        self.queue = dispatch_queue_create(
            "com.flex.FLEXNetworkObserver", DISPATCH_QUEUE_SERIAL
        );
    }
    
    return self;
}

#pragma mark - 私有方法

- (void)performBlock:(dispatch_block_t)block {
    if ([[self class] isEnabled]) {
        dispatch_async(_queue, block);
    }
}

- (FLEXInternalRequestState *)requestStateForRequestID:(NSString *)requestID {
    FLEXInternalRequestState *requestState = self.requestStatesForRequestIDs[requestID];
    if (!requestState) {
        requestState = [FLEXInternalRequestState new];
        [self.requestStatesForRequestIDs setObject:requestState forKey:requestID];
    }
    
    return requestState;
}

- (void)removeRequestStateForRequestID:(NSString *)requestID {
    [self.requestStatesForRequestIDs removeObjectForKey:requestID];
}

@end


@implementation FLEXNetworkObserver (NSURLConnectionHelpers)

- (void)connection:(NSURLConnection *)connection
   willSendRequest:(NSURLRequest *)request
  redirectResponse:(NSURLResponse *)response
          delegate:(id<NSURLConnectionDelegate>)delegate {
    [self performBlock:^{
        NSString *requestID = [[self class] requestIDForConnectionOrTask:connection];
        FLEXInternalRequestState *requestState = [self requestStateForRequestID:requestID];
        requestState.request = request;
        
        [FLEXNetworkRecorder.defaultRecorder
            recordRequestWillBeSentWithRequestID:requestID
            request:request
            redirectResponse:response
        ];
        
        NSString *mechanism = [NSString stringWithFormat:
            @"NSURLConnection (delegate: %@)", [delegate class]
        ];
        [FLEXNetworkRecorder.defaultRecorder recordMechanism:mechanism forRequestID:requestID];
    }];
}

- (void)connection:(NSURLConnection *)connection
didReceiveResponse:(NSURLResponse *)response
          delegate:(id<NSURLConnectionDelegate>)delegate {
    [self performBlock:^{
        NSString *requestID = [[self class] requestIDForConnectionOrTask:connection];
        FLEXInternalRequestState *requestState = [self requestStateForRequestID:requestID];
        requestState.dataAccumulator = [NSMutableData new];

        [FLEXNetworkRecorder.defaultRecorder
            recordResponseReceivedWithRequestID:requestID
            response:response
        ];
    }];
}

- (void)connection:(NSURLConnection *)connection
    didReceiveData:(NSData *)data
          delegate:(id<NSURLConnectionDelegate>)delegate {
    // 仅为了安全起见，因为我们是异步做这个
    data = [data copy];
    [self performBlock:^{
        NSString *requestID = [[self class] requestIDForConnectionOrTask:connection];
        FLEXInternalRequestState *requestState = [self requestStateForRequestID:requestID];
        [requestState.dataAccumulator appendData:data];
        
        [FLEXNetworkRecorder.defaultRecorder
            recordDataReceivedWithRequestID:requestID
            dataLength:data.length
        ];
    }];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
                          delegate:(id<NSURLConnectionDelegate>)delegate {
    [self performBlock:^{
        NSString *requestID = [[self class] requestIDForConnectionOrTask:connection];
        FLEXInternalRequestState *requestState = [self requestStateForRequestID:requestID];
        [FLEXNetworkRecorder.defaultRecorder
            recordLoadingFinishedWithRequestID:requestID
            responseBody:requestState.dataAccumulator
        ];
        [self removeRequestStateForRequestID:requestID];
    }];
}

- (void)connection:(NSURLConnection *)connection
  didFailWithError:(NSError *)error
          delegate:(id<NSURLConnectionDelegate>)delegate {
    [self performBlock:^{
        NSString *requestID = [[self class] requestIDForConnectionOrTask:connection];
        FLEXInternalRequestState *requestState = [self requestStateForRequestID:requestID];

        // 取消可能发生在willSendRequest:...
        // NSURLConnection代理调用之前。这些非常常见
        // 并且会使日志变得混乱。只有在
        // 记录器已经通过willSendRequest:...了解请求时才记录失败。
        if (requestState.request) {
            [FLEXNetworkRecorder.defaultRecorder 
                recordLoadingFailedWithRequestID:requestID error:error
            ];
        }
        
        [self removeRequestStateForRequestID:requestID];
    }];
}

- (void)connectionWillCancel:(NSURLConnection *)connection {
    [self performBlock:^{
        // 模拟NSURLSession的行为，即在取消时创建一个错误。
        NSDictionary<NSString *, id> *userInfo = @{ NSLocalizedDescriptionKey : @"已取消" };
        NSError *error = [NSError errorWithDomain:NSURLErrorDomain
            code:NSURLErrorCancelled userInfo:userInfo
        ];
        [self connection:connection didFailWithError:error delegate:nil];
    }];
}

@end


@implementation FLEXNetworkObserver (NSURLSessionTaskHelpers)

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
willPerformHTTPRedirection:(NSHTTPURLResponse *)response
        newRequest:(NSURLRequest *)request
 completionHandler:(void (^)(NSURLRequest *))completionHandler
          delegate:(id<NSURLSessionDelegate>)delegate {
    [self performBlock:^{
        NSString *requestID = [[self class] requestIDForConnectionOrTask:task];
        [FLEXNetworkRecorder.defaultRecorder
            recordRequestWillBeSentWithRequestID:requestID
            request:request
            redirectResponse:response
        ];
    }];
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
          delegate:(id<NSURLSessionDelegate>)delegate {
    [self performBlock:^{
        NSString *requestID = [[self class] requestIDForConnectionOrTask:dataTask];
        FLEXInternalRequestState *requestState = [self requestStateForRequestID:requestID];
        requestState.dataAccumulator = [NSMutableData new];

        NSString *requestMechanism = [NSString stringWithFormat:
            @"NSURLSessionDataTask (delegate: %@)", [delegate class]
        ];
        [FLEXNetworkRecorder.defaultRecorder
            recordMechanism:requestMechanism
            forRequestID:requestID
        ];

        [FLEXNetworkRecorder.defaultRecorder
            recordResponseReceivedWithRequestID:requestID
            response:response
        ];
    }];
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
didBecomeDownloadTask:(NSURLSessionDownloadTask *)downloadTask
          delegate:(id<NSURLSessionDelegate>)delegate {
    [self performBlock:^{
        // 通过将下载任务的请求ID设置为与数据任务匹配，
        // 它可以从数据任务停止的地方继续。
        NSString *requestID = [[self class] requestIDForConnectionOrTask:dataTask];
        [[self class] setRequestID:requestID forConnectionOrTask:downloadTask];
    }];
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data
          delegate:(id<NSURLSessionDelegate>)delegate {
    // 仅为了安全起见，因为我们是异步做这个
    data = [data copy];
    [self performBlock:^{
        NSString *requestID = [[self class] requestIDForConnectionOrTask:dataTask];
        FLEXInternalRequestState *requestState = [self requestStateForRequestID:requestID];

        // 修复开发者报告的"响应体不在缓存中"问题
        // 有关为什么发生这种情况的详细解释，请参阅此github评论
        // https://github.com/FLEXTool/FLEX/issues/568#issuecomment-1141015572
        if (requestState.dataAccumulator == nil) {
            requestState.dataAccumulator = [NSMutableData new];
        }
        [requestState.dataAccumulator appendData:data];

        [FLEXNetworkRecorder.defaultRecorder
            recordDataReceivedWithRequestID:requestID
            dataLength:data.length
        ];
    }];
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error
          delegate:(id<NSURLSessionDelegate>)delegate {
    [self performBlock:^{
        NSString *requestID = [[self class] requestIDForConnectionOrTask:task];
        FLEXInternalRequestState *requestState = [self requestStateForRequestID:requestID];

        if (error) {
            [FLEXNetworkRecorder.defaultRecorder
                recordLoadingFailedWithRequestID:requestID error:error
            ];
        } else {
            [FLEXNetworkRecorder.defaultRecorder
                recordLoadingFinishedWithRequestID:requestID 
                responseBody:requestState.dataAccumulator
            ];
        }

        [self removeRequestStateForRequestID:requestID];
    }];
}

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
      didWriteData:(int64_t)bytesWritten
 totalBytesWritten:(int64_t)totalBytesWritten
totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
          delegate:(id<NSURLSessionDelegate>)delegate {
    [self performBlock:^{
        NSString *requestID = [[self class] requestIDForConnectionOrTask:downloadTask];
        FLEXInternalRequestState *requestState = [self requestStateForRequestID:requestID];

        if (!requestState.dataAccumulator) {
            requestState.dataAccumulator = [NSMutableData new];
            [FLEXNetworkRecorder.defaultRecorder
                recordResponseReceivedWithRequestID:requestID
                response:downloadTask.response
            ];

            NSString *requestMechanism = [NSString stringWithFormat:
                @"NSURLSessionDownloadTask (delegate: %@)", [delegate class]
            ];
            [FLEXNetworkRecorder.defaultRecorder
                recordMechanism:requestMechanism
                forRequestID:requestID
             ];
        }

        [FLEXNetworkRecorder.defaultRecorder
            recordDataReceivedWithRequestID:requestID
            dataLength:bytesWritten
        ];
    }];
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionDownloadTask *)downloadTask
didFinishDownloadingToURL:(NSURL *)location data:(NSData *)data
          delegate:(id<NSURLSessionDelegate>)delegate {
    data = [data copy];
    [self performBlock:^{
        NSString *requestID = [[self class] requestIDForConnectionOrTask:downloadTask];
        FLEXInternalRequestState *requestState = [self requestStateForRequestID:requestID];
        [requestState.dataAccumulator appendData:data];
    }];
}

- (void)URLSessionTaskWillResume:(NSURLSessionTask *)task {
    if (@available(iOS 11.0, *)) {
        // AVAggregateAssetDownloadTask非常不喜欢被查看。访问-currentRequest或
        // -originalRequest会崩溃。不要尝试观察这些。https://github.com/FLEXTool/FLEX/issues/276
        if ([task isKindOfClass:[AVAggregateAssetDownloadTask class]]) {
            return;
        }
    }

    // 由于resume可以在同一个任务上多次调用，因此只有第一次resume被视为
    // 等效于connection:willSendRequest:...
    [self performBlock:^{
        NSString *requestID = [[self class] requestIDForConnectionOrTask:task];
        FLEXInternalRequestState *requestState = [self requestStateForRequestID:requestID];
        if (!requestState.request) {
            requestState.request = task.currentRequest;

            [FLEXNetworkRecorder.defaultRecorder
                recordRequestWillBeSentWithRequestID:requestID
                request:task.currentRequest
                redirectResponse:nil
            ];
        }
    }];
}

- (void)websocketTask:(NSURLSessionWebSocketTask *)task
        sendMessagage:(NSURLSessionWebSocketMessage *)message {
    [self performBlock:^{
//        NSString *requestID = [[self class] requestIDForConnectionOrTask:task];
        [FLEXNetworkRecorder.defaultRecorder recordWebsocketMessageSend:message task:task];
    }];
}

- (void)websocketTaskMessageSendCompletion:(NSURLSessionWebSocketMessage *)message
                                     error:(NSError *)error {
    [self performBlock:^{
        [FLEXNetworkRecorder.defaultRecorder
            recordWebsocketMessageSendCompletion:message
            error:error
        ];
    }];
}

- (void)websocketTask:(NSURLSessionWebSocketTask *)task
     receiveMessagage:(NSURLSessionWebSocketMessage *)message
                error:(NSError *)error {
    [self performBlock:^{
        if (!error && message) {
            [FLEXNetworkRecorder.defaultRecorder
                recordWebsocketMessageReceived:message
                task:task
            ];            
        }
    }];
}

@end
