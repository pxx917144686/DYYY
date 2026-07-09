//
//  DYYYFLEXNetworkRecorder.m
//  Flipboard
//
//  Created by Ryan Olson on 2/4/15.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

#import "DYYYFLEXNetworkRecorder.h"
#import "DYYYFLEXNetworkCurlLogger.h"
#import "DYYYFLEXNetworkTransaction.h"
#import "DYYYFLEXUtility.h"
#import "DYYYFLEXResources.h"
#import "NSUserDefaults+FLEX.h"
#import "DYYYOSCache.h"

#define Synchronized(queue, obj) ({ \
    __block id __synchronized_retval = nil; \
    dispatch_sync(queue, ^{ __synchronized_retval = obj; }); \
    __synchronized_retval; \
})
    

NSString *const kFLEXNetworkRecorderNewTransactionNotification = @"kFLEXNetworkRecorderNewTransactionNotification";
NSString *const kFLEXNetworkRecorderTransactionUpdatedNotification = @"kFLEXNetworkRecorderTransactionUpdatedNotification";
NSString *const kFLEXNetworkRecorderUserInfoTransactionKey = @"transaction";
NSString *const kFLEXNetworkRecorderTransactionsClearedNotification = @"kFLEXNetworkRecorderTransactionsClearedNotification";

NSString *const kFLEXNetworkRecorderResponseCacheLimitDefaultsKey = @"com.flex.responseCacheLimit";

@interface DYYYFLEXNetworkRecorder ()

@property (nonatomic) DYYYOSCache *restCache;
@property (atomic) NSMutableArray<DYYYFLEXHTTPTransaction *> *orderedHTTPTransactions;
@property (atomic) NSMutableArray<DYYYFLEXWebsocketTransaction *> *orderedWSTransactions;
@property (atomic) NSMutableArray<DYYYFLEXFirebaseTransaction *> *orderedFirebaseTransactions;
@property (atomic) NSMutableDictionary<NSString *, __kindof DYYYFLEXNetworkTransaction *> *requestIDsToTransactions;
@property (nonatomic) dispatch_queue_t queue;

@end

@implementation DYYYFLEXNetworkRecorder

- (instancetype)init {
    self = [super init];
    if (self) {
        self.restCache = [DYYYOSCache new];
        NSUInteger responseCacheLimit = [[NSUserDefaults.standardUserDefaults
            objectForKey:kFLEXNetworkRecorderResponseCacheLimitDefaultsKey] unsignedIntegerValue
        ];
        
        // Default to 25 MB max. The cache will purge earlier if there is memory pressure.
        self.restCache.totalCostLimit = responseCacheLimit ?: 25 * 1024 * 1024;
        [self.restCache setTotalCostLimit:responseCacheLimit];
        
        self.orderedWSTransactions = [NSMutableArray new];
        self.orderedHTTPTransactions = [NSMutableArray new];
        self.orderedFirebaseTransactions = [NSMutableArray new];
        self.requestIDsToTransactions = [NSMutableDictionary new];
        self.hostDenylist = NSUserDefaults.standardUserDefaults.flex_networkHostDenylist.mutableCopy;

        // Serial queue used because we use mutable objects that are not thread safe
        self.queue = dispatch_queue_create("com.flex.DYYYFLEXNetworkRecorder", DISPATCH_QUEUE_SERIAL);
    }
    
    return self;
}

+ (instancetype)defaultRecorder {
    static DYYYFLEXNetworkRecorder *defaultRecorder = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        defaultRecorder = [self new];
    });
    
    return defaultRecorder;
}

#pragma mark - Public Data Access

- (NSUInteger)responseCacheByteLimit {
    return self.restCache.totalCostLimit;
}

- (void)setResponseCacheByteLimit:(NSUInteger)responseCacheByteLimit {
    self.restCache.totalCostLimit = responseCacheByteLimit;
    [NSUserDefaults.standardUserDefaults
        setObject:@(responseCacheByteLimit)
        forKey:kFLEXNetworkRecorderResponseCacheLimitDefaultsKey
    ];
}

- (NSArray<DYYYFLEXHTTPTransaction *> *)HTTPTransactions {
    return Synchronized(self.queue, self.orderedHTTPTransactions.copy);
}

- (NSArray<DYYYFLEXWebsocketTransaction *> *)websocketTransactions {
    return Synchronized(self.queue, self.orderedWSTransactions.copy);
}

- (NSArray<DYYYFLEXFirebaseTransaction *> *)firebaseTransactions {
    return Synchronized(self.queue, self.orderedFirebaseTransactions.copy);
}

- (NSData *)cachedResponseBodyForTransaction:(DYYYFLEXHTTPTransaction *)transaction {
    return [self.restCache objectForKey:transaction.requestID];
}

- (void)clearRecordedActivity {
    dispatch_async(self.queue, ^{
        [self.restCache removeAllObjects];
        [self.orderedWSTransactions removeAllObjects];
        [self.orderedHTTPTransactions removeAllObjects];
        [self.orderedFirebaseTransactions removeAllObjects];
        [self.requestIDsToTransactions removeAllObjects];
        
        [self notify:kFLEXNetworkRecorderTransactionsClearedNotification transaction:nil];
    });
}

- (void)clearRecordedActivity:(FLEXNetworkTransactionKind)kind matching:(NSString *)query {
    dispatch_async(self.queue, ^{
        switch (kind) {
            case FLEXNetworkTransactionKindFirebase: {
                [self.orderedFirebaseTransactions flex_filter:^BOOL(DYYYFLEXFirebaseTransaction *obj, NSUInteger idx) {
                    return ![obj matchesQuery:query];
                }];
                break;
            }
            case FLEXNetworkTransactionKindREST: {
                NSArray<DYYYFLEXHTTPTransaction *> *toRemove;
                toRemove = [self.orderedHTTPTransactions flex_filtered:^BOOL(DYYYFLEXHTTPTransaction *obj, NSUInteger idx) {
                    return [obj matchesQuery:query];
                }];
                
                // Remove from cache
                for (DYYYFLEXHTTPTransaction *t in toRemove) {
                    [self.restCache removeObjectForKey:t.requestID];
                }
                
                // Remove from list
                [self.orderedHTTPTransactions removeObjectsInArray:toRemove];
                
                break;
            }
            case FLEXNetworkTransactionKindWebsockets: {
                [self.orderedWSTransactions flex_filter:^BOOL(DYYYFLEXWebsocketTransaction *obj, NSUInteger idx) {
                    return ![obj matchesQuery:query];
                }];
                break;
            }
        }
        
        [self notify:kFLEXNetworkRecorderTransactionsClearedNotification transaction:nil];
    });
}

- (void)clearExcludedTransactions {
    dispatch_sync(self.queue, ^{
        self.orderedHTTPTransactions = ({
            [self.orderedHTTPTransactions flex_filtered:^BOOL(DYYYFLEXHTTPTransaction *ta, NSUInteger idx) {
                NSString *host = ta.request.URL.host;
                for (NSString *excluded in self.hostDenylist) {
                    if ([host hasSuffix:excluded]) {
                        return NO;
                    }
                }
                
                return YES;
            }];
        });
    });
}

- (void)synchronizeDenylist {
    NSUserDefaults.standardUserDefaults.flex_networkHostDenylist = self.hostDenylist;
}

#pragma mark - Network Events

- (void)recordRequestWillBeSentWithRequestID:(NSString *)requestID
                                     request:(NSURLRequest *)request
                            redirectResponse:(NSURLResponse *)redirectResponse {
    for (NSString *host in self.hostDenylist) {
        if ([request.URL.host hasSuffix:host]) {
            return;
        }
    }
    
    DYYYFLEXHTTPTransaction *transaction = [DYYYFLEXHTTPTransaction request:request identifier:requestID];

    // Before async block to keep times accurate
    if (redirectResponse) {
        [self recordResponseReceivedWithRequestID:requestID response:redirectResponse];
        [self recordLoadingFinishedWithRequestID:requestID responseBody:nil];
    }

    // A redirect is always a new request
    dispatch_async(self.queue, ^{
        [self.orderedHTTPTransactions insertObject:transaction atIndex:0];
        self.requestIDsToTransactions[requestID] = transaction;

        [self postNewTransactionNotificationWithTransaction:transaction];
    });
}

- (void)recordResponseReceivedWithRequestID:(NSString *)requestID response:(NSURLResponse *)response {
    // Before async block to stay accurate
    NSDate *responseDate = [NSDate date];

    dispatch_async(self.queue, ^{
        DYYYFLEXHTTPTransaction *transaction = self.requestIDsToTransactions[requestID];
        if (!transaction) {
            return;
        }
        
        transaction.response = response;
        transaction.state = FLEXNetworkTransactionStateReceivingData;
        transaction.latency = -[transaction.startTime timeIntervalSinceDate:responseDate];

        [self postUpdateNotificationForTransaction:transaction];
    });
}

- (void)recordDataReceivedWithRequestID:(NSString *)requestID dataLength:(int64_t)dataLength {
    dispatch_async(self.queue, ^{
        DYYYFLEXHTTPTransaction *transaction = self.requestIDsToTransactions[requestID];
        if (!transaction) {
            return;
        }
        
        transaction.receivedDataLength += dataLength;
        [self postUpdateNotificationForTransaction:transaction];
    });
}

- (void)recordLoadingFinishedWithRequestID:(NSString *)requestID responseBody:(NSData *)responseBody {
    NSDate *finishedDate = [NSDate date];

    dispatch_async(self.queue, ^{
        DYYYFLEXHTTPTransaction *transaction = self.requestIDsToTransactions[requestID];
        if (!transaction) {
            return;
        }
        
        transaction.state = FLEXNetworkTransactionStateFinished;
        transaction.duration = -[transaction.startTime timeIntervalSinceDate:finishedDate];

        BOOL shouldCache = responseBody.length > 0;
        if (!self.shouldCacheMediaResponses) {
            NSArray<NSString *> *ignoredMIMETypePrefixes = @[ @"audio", @"image", @"video" ];
            for (NSString *ignoredPrefix in ignoredMIMETypePrefixes) {
                shouldCache = shouldCache && ![transaction.response.MIMEType hasPrefix:ignoredPrefix];
            }
        }
        
        if (shouldCache) {
            [self.restCache setObject:responseBody forKey:requestID cost:responseBody.length];
        }

        NSString *mimeType = transaction.response.MIMEType;
        if ([mimeType hasPrefix:@"image/"] && responseBody.length > 0) {
            // Thumbnail image previews on a separate background queue
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                NSInteger maxPixelDimension = UIScreen.mainScreen.scale * 32.0;
                transaction.thumbnail = [DYYYFLEXUtility
                    thumbnailedImageWithMaxPixelDimension:maxPixelDimension
                    fromImageData:responseBody
                ];
                [self postUpdateNotificationForTransaction:transaction];
            });
        } else if ([mimeType isEqual:@"application/json"]) {
            transaction.thumbnail = DYYYFLEXResources.jsonIcon;
        } else if ([mimeType isEqual:@"text/plain"]){
            transaction.thumbnail = DYYYFLEXResources.textPlainIcon;
        } else if ([mimeType isEqual:@"text/html"]) {
            transaction.thumbnail = DYYYFLEXResources.htmlIcon;
        } else if ([mimeType isEqual:@"application/x-plist"]) {
            transaction.thumbnail = DYYYFLEXResources.plistIcon;
        } else if ([mimeType isEqual:@"application/octet-stream"] || [mimeType isEqual:@"application/binary"]) {
            transaction.thumbnail = DYYYFLEXResources.binaryIcon;
        } else if ([mimeType containsString:@"javascript"]) {
            transaction.thumbnail = DYYYFLEXResources.jsIcon;
        } else if ([mimeType containsString:@"xml"]) {
            transaction.thumbnail = DYYYFLEXResources.xmlIcon;
        } else if ([mimeType hasPrefix:@"audio"]) {
            transaction.thumbnail = DYYYFLEXResources.audioIcon;
        } else if ([mimeType hasPrefix:@"video"]) {
            transaction.thumbnail = DYYYFLEXResources.videoIcon;
        } else if ([mimeType hasPrefix:@"text"]) {
            transaction.thumbnail = DYYYFLEXResources.textIcon;
        }
        
        [self postUpdateNotificationForTransaction:transaction];
    });
}

- (void)recordLoadingFailedWithRequestID:(NSString *)requestID error:(NSError *)error {
    dispatch_async(self.queue, ^{
        DYYYFLEXHTTPTransaction *transaction = self.requestIDsToTransactions[requestID];
        if (!transaction) {
            return;
        }
        
        transaction.state = FLEXNetworkTransactionStateFailed;
        transaction.duration = -[transaction.startTime timeIntervalSinceNow];
        transaction.error = error;

        [self postUpdateNotificationForTransaction:transaction];
    });
}

- (void)recordMechanism:(NSString *)mechanism forRequestID:(NSString *)requestID {
    dispatch_async(self.queue, ^{
        DYYYFLEXHTTPTransaction *transaction = self.requestIDsToTransactions[requestID];
        if (!transaction) {
            return;
        }
        
        transaction.requestMechanism = mechanism;
        [self postUpdateNotificationForTransaction:transaction];
    });
}

#pragma mark - Websocket Events

- (void)recordWebsocketMessageSend:(NSURLSessionWebSocketMessage *)message task:(NSURLSessionWebSocketTask *)task {
    dispatch_async(self.queue, ^{
        DYYYFLEXWebsocketTransaction *send = [DYYYFLEXWebsocketTransaction
            withMessage:message task:task direction:FLEXWebsocketOutgoing
        ];
        
        [self.orderedWSTransactions insertObject:send atIndex:0];
        [self postNewTransactionNotificationWithTransaction:send];
    });
}

- (void)recordWebsocketMessageSendCompletion:(NSURLSessionWebSocketMessage *)message error:(NSError *)error {
    dispatch_async(self.queue, ^{
        DYYYFLEXWebsocketTransaction *send = [self.orderedWSTransactions flex_firstWhere:^BOOL(DYYYFLEXWebsocketTransaction *t) {
            return t.message == message;
        }];
        send.error = error;
        send.state = error ? FLEXNetworkTransactionStateFailed : FLEXNetworkTransactionStateFinished;
        
        [self postUpdateNotificationForTransaction:send];
    });
}

- (void)recordWebsocketMessageReceived:(NSURLSessionWebSocketMessage *)message task:(NSURLSessionWebSocketTask *)task {
    dispatch_async(self.queue, ^{
        DYYYFLEXWebsocketTransaction *receive = [DYYYFLEXWebsocketTransaction
            withMessage:message task:task direction:FLEXWebsocketIncoming
        ];
        
        [self.orderedWSTransactions insertObject:receive atIndex:0];
        [self postNewTransactionNotificationWithTransaction:receive];
    });
}

#pragma mark - Firebase, Reading

- (void)recordFIRQueryWillFetch:(FIRQuery *)query withTransactionID:(NSString *)transactionID {
    dispatch_async(self.queue, ^{
        DYYYFLEXFirebaseTransaction *transaction = [DYYYFLEXFirebaseTransaction queryFetch:query];
        self.requestIDsToTransactions[transactionID] = transaction;
        [self postNewTransactionNotificationWithTransaction:transaction];
    });
}

- (void)recordFIRDocumentWillFetch:(FIRDocumentReference *)document withTransactionID:(NSString *)transactionID {
    dispatch_async(self.queue, ^{
        DYYYFLEXFirebaseTransaction *transaction = [DYYYFLEXFirebaseTransaction documentFetch:document];
        self.requestIDsToTransactions[transactionID] = transaction;
        [self postNewTransactionNotificationWithTransaction:transaction];
    });
}

- (void)recordFIRQueryDidFetch:(FIRQuerySnapshot *)response error:(NSError *)error transactionID:(NSString *)transactionID {
    dispatch_async(self.queue, ^{
        DYYYFLEXFirebaseTransaction *transaction = self.requestIDsToTransactions[transactionID];
        if (!transaction) {
            return;
        }
        
        transaction.error = error;
        transaction.documents = response.documents;
        transaction.state = FLEXNetworkTransactionStateFinished;
        [self.orderedFirebaseTransactions insertObject:transaction atIndex:0];
        
        [self postUpdateNotificationForTransaction:transaction];
    });
}

- (void)recordFIRDocumentDidFetch:(FIRDocumentSnapshot *)response error:(NSError *)error transactionID:(NSString *)transactionID {
    dispatch_async(self.queue, ^{
        DYYYFLEXFirebaseTransaction *transaction = self.requestIDsToTransactions[transactionID];
        if (!transaction) {
            return;
        }
        
        transaction.error = error;
        transaction.documents = response ? @[response] : @[];
        transaction.state = FLEXNetworkTransactionStateFinished;
        [self.orderedFirebaseTransactions insertObject:transaction atIndex:0];
        
        [self postUpdateNotificationForTransaction:transaction];
    });
}

#pragma mark Firebase, Writing

- (void)recordFIRWillSetData:(FIRDocumentReference *)doc
                        data:(NSDictionary *)documentData
                       merge:(NSNumber *)yesorno
                 mergeFields:(NSArray *)fields
               transactionID:(NSString *)transactionID {
    dispatch_async(self.queue, ^{
        DYYYFLEXFirebaseTransaction *transaction = [DYYYFLEXFirebaseTransaction
            setData:doc data:documentData merge:yesorno mergeFields:fields
        ];
        self.requestIDsToTransactions[transactionID] = transaction;
        [self postNewTransactionNotificationWithTransaction:transaction];
    });
}

- (void)recordFIRWillUpdateData:(FIRDocumentReference *)doc fields:(NSDictionary *)fields
                  transactionID:(NSString *)transactionID {
    dispatch_async(self.queue, ^{
        DYYYFLEXFirebaseTransaction *transaction = [DYYYFLEXFirebaseTransaction updateData:doc data:fields];
        self.requestIDsToTransactions[transactionID] = transaction;
        [self postNewTransactionNotificationWithTransaction:transaction];
    });
}

- (void)recordFIRWillDeleteDocument:(FIRDocumentReference *)doc transactionID:(NSString *)transactionID {
    dispatch_async(self.queue, ^{
        DYYYFLEXFirebaseTransaction *transaction = [DYYYFLEXFirebaseTransaction deleteDocument:doc];
        self.requestIDsToTransactions[transactionID] = transaction;
        [self postNewTransactionNotificationWithTransaction:transaction];
    });
}

- (void)recordFIRWillAddDocument:(FIRCollectionReference *)initiator document:(FIRDocumentReference *)doc
                   transactionID:(NSString *)transactionID {
    dispatch_async(self.queue, ^{
        DYYYFLEXFirebaseTransaction *transaction = [DYYYFLEXFirebaseTransaction
            addDocument:initiator document:doc
        ];
        self.requestIDsToTransactions[transactionID] = transaction;
        [self postNewTransactionNotificationWithTransaction:transaction];
    });
}

- (void)recordFIRDidSetData:(NSError *)error transactionID:(NSString *)transactionID {
    [self firebaseTransaction:transactionID didUpdate:error];
}

- (void)recordFIRDidUpdateData:(NSError *)error transactionID:(NSString *)transactionID {
    [self firebaseTransaction:transactionID didUpdate:error];
}

- (void)recordFIRDidDeleteDocument:(NSError *)error transactionID:(NSString *)transactionID {
    [self firebaseTransaction:transactionID didUpdate:error];
}

- (void)recordFIRDidAddDocument:(NSError *)error transactionID:(NSString *)transactionID {
    [self firebaseTransaction:transactionID didUpdate:error];
}

- (void)firebaseTransaction:(NSString *)transactionID didUpdate:(NSError *)error {
    dispatch_async(self.queue, ^{
        DYYYFLEXFirebaseTransaction *transaction = self.requestIDsToTransactions[transactionID];
        if (!transaction) {
            return;
        }
        
        transaction.error = error;
        transaction.state = FLEXNetworkTransactionStateFinished;
        [self.orderedFirebaseTransactions insertObject:transaction atIndex:0];
        
        [self postUpdateNotificationForTransaction:transaction];
    });
}

#pragma mark - Notification Posting

- (void)postNewTransactionNotificationWithTransaction:(DYYYFLEXNetworkTransaction *)transaction {
    [self notify:kFLEXNetworkRecorderNewTransactionNotification transaction:transaction];
}

- (void)postUpdateNotificationForTransaction:(DYYYFLEXNetworkTransaction *)transaction {
    [self notify:kFLEXNetworkRecorderTransactionUpdatedNotification transaction:transaction];
}

- (void)notify:(NSString *)name transaction:(DYYYFLEXNetworkTransaction *)transaction {
    NSDictionary *userInfo = nil;
    if (transaction) {
        userInfo = @{ kFLEXNetworkRecorderUserInfoTransactionKey : transaction };
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:name object:self userInfo:userInfo];
    });
}

@end
