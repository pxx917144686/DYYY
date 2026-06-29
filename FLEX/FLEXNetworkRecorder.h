//
//  FLEXNetworkRecorder.h
//  Flipboard
//
//  Created by Ryan Olson on 2/4/15.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

#import <Foundation/Foundation.h>

// 记录更新时发布的通知
extern NSString *const kFLEXNetworkRecorderNewTransactionNotification;
extern NSString *const kFLEXNetworkRecorderTransactionUpdatedNotification;
extern NSString *const kFLEXNetworkRecorderUserInfoTransactionKey;
extern NSString *const kFLEXNetworkRecorderTransactionsClearedNotification;

@class FLEXNetworkTransaction, FLEXHTTPTransaction, FLEXWebsocketTransaction, FLEXFirebaseTransaction;
@class FIRQuery, FIRDocumentReference, FIRCollectionReference, FIRDocumentSnapshot, FIRQuerySnapshot;

typedef NS_ENUM(NSUInteger, FLEXNetworkTransactionKind) {
    FLEXNetworkTransactionKindFirebase = 0,
    FLEXNetworkTransactionKindREST,
    FLEXNetworkTransactionKindWebsockets,
};

@interface FLEXNetworkRecorder : NSObject

/// 通常情况下，整个应用程序只需要一个记录器。
@property (nonatomic, readonly, class) FLEXNetworkRecorder *defaultRecorder;

/// 如果从未设置，默认为25 MB。这里设置的值在应用程序启动之间保持不变。
@property (nonatomic) NSUInteger responseCacheByteLimit;

/// 如果为NO，记录器将不会缓存内容类型前缀为"image"、"video"或"audio"的响应。
@property (nonatomic) BOOL shouldCacheMediaResponses;

@property (nonatomic) NSMutableArray<NSString *> *hostDenylist;

/// 在添加到或设置 \c hostDenylist 后调用此方法以移除被排除的事务
- (void)clearExcludedTransactions;

/// 调用此方法将拒绝列表保存到磁盘以便下次加载
- (void)synchronizeDenylist;


#pragma mark 访问记录的网络活动

/// FLEXHTTPTransaction对象数组，按开始时间排序，最新的排在前面。
@property (nonatomic, readonly) NSArray<FLEXHTTPTransaction *> *HTTPTransactions;
/// FLEXWebsocketTransaction对象数组，按开始时间排序，最新的排在前面。
@property (nonatomic, readonly) NSArray<FLEXWebsocketTransaction *> *websocketTransactions API_AVAILABLE(ios(13.0));
/// FLEXFirebaseTransaction对象数组，按开始时间排序，最新的排在前面。
@property (nonatomic, readonly) NSArray<FLEXFirebaseTransaction *> *firebaseTransactions;

/// 完整的响应数据，如果由于内存压力尚未被清除的话。
- (NSData *)cachedResponseBodyForTransaction:(FLEXHTTPTransaction *)transaction;

/// 清除所有网络事务和缓存的响应体。
- (void)clearRecordedActivity;

/// 仅清除匹配给定查询的事务。
- (void)clearRecordedActivity:(FLEXNetworkTransactionKind)kind matching:(NSString *)query;


#pragma mark 记录网络活动

/// 当应用程序即将发送HTTP请求时调用。
- (void)recordRequestWillBeSentWithRequestID:(NSString *)requestID
                                     request:(NSURLRequest *)request
                            redirectResponse:(NSURLResponse *)redirectResponse;

/// 当HTTP响应可用时调用。
- (void)recordResponseReceivedWithRequestID:(NSString *)requestID response:(NSURLResponse *)response;

/// 当通过网络接收到数据块时调用。
- (void)recordDataReceivedWithRequestID:(NSString *)requestID dataLength:(int64_t)dataLength;

/// 当HTTP请求已完成加载时调用。
- (void)recordLoadingFinishedWithRequestID:(NSString *)requestID responseBody:(NSData *)responseBody;

/// 当HTTP请求加载失败时调用。
- (void)recordLoadingFailedWithRequestID:(NSString *)requestID error:(NSError *)error;

/// 在调用recordRequestWillBeSent...之后的任何时候调用，以设置请求机制。
/// 此字符串可以设置为有关用于发出请求的API的任何有用信息。
- (void)recordMechanism:(NSString *)mechanism forRequestID:(NSString *)requestID;

- (void)recordWebsocketMessageSend:(NSURLSessionWebSocketMessage *)message
                              task:(NSURLSessionWebSocketTask *)task API_AVAILABLE(ios(13.0));
- (void)recordWebsocketMessageSendCompletion:(NSURLSessionWebSocketMessage *)message
                                       error:(NSError *)error API_AVAILABLE(ios(13.0));

- (void)recordWebsocketMessageReceived:(NSURLSessionWebSocketMessage *)message
                                  task:(NSURLSessionWebSocketTask *)task API_AVAILABLE(ios(13.0));

- (void)recordFIRQueryWillFetch:(FIRQuery *)query withTransactionID:(NSString *)transactionID;
- (void)recordFIRDocumentWillFetch:(FIRDocumentReference *)document withTransactionID:(NSString *)transactionID;

- (void)recordFIRQueryDidFetch:(FIRQuerySnapshot *)response error:(NSError *)error
                 transactionID:(NSString *)transactionID;
- (void)recordFIRDocumentDidFetch:(FIRDocumentSnapshot *)response error:(NSError *)error
                    transactionID:(NSString *)transactionID;

- (void)recordFIRWillSetData:(FIRDocumentReference *)doc
                        data:(NSDictionary *)documentData
                       merge:(NSNumber *)yesorno
                 mergeFields:(NSArray *)fields
               transactionID:(NSString *)transactionID;
- (void)recordFIRWillUpdateData:(FIRDocumentReference *)doc fields:(NSDictionary *)fields
                  transactionID:(NSString *)transactionID;
- (void)recordFIRWillDeleteDocument:(FIRDocumentReference *)doc transactionID:(NSString *)transactionID;
- (void)recordFIRWillAddDocument:(FIRCollectionReference *)initiator
                            document:(FIRDocumentReference *)doc
                   transactionID:(NSString *)transactionID;

- (void)recordFIRDidSetData:(NSError *)error transactionID:(NSString *)transactionID;
- (void)recordFIRDidUpdateData:(NSError *)error transactionID:(NSString *)transactionID;
- (void)recordFIRDidDeleteDocument:(NSError *)error transactionID:(NSString *)transactionID;
- (void)recordFIRDidAddDocument:(NSError *)error transactionID:(NSString *)transactionID;

@end
