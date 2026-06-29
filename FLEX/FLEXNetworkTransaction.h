//
//  FLEXNetworkTransaction.h
//  Flipboard
//
//  Created by Ryan Olson on 2/8/15.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Firestore.h"

typedef NS_ENUM(NSInteger, FLEXNetworkTransactionState) {
    FLEXNetworkTransactionStateUnstarted = -1,
    /// 这是默认值；请求被标记为"未启动"通常是没有意义的
    FLEXNetworkTransactionStateAwaitingResponse = 0,
    FLEXNetworkTransactionStateReceivingData,
    FLEXNetworkTransactionStateFinished,
    FLEXNetworkTransactionStateFailed
};

typedef NS_ENUM(NSUInteger, FLEXWebsocketMessageDirection) {
    FLEXWebsocketIncoming = 1,
    FLEXWebsocketOutgoing,
};

/// 所有网络事务类型的共享基类。
/// 子类应实现描述和详细信息属性，并分配缩略图。
@interface FLEXNetworkTransaction : NSObject {
    @protected

    NSString *_primaryDescription;
    NSString *_secondaryDescription;
    NSString *_tertiaryDescription;
}

+ (instancetype)withStartTime:(NSDate *)startTime;

+ (NSString *)readableStringFromTransactionState:(FLEXNetworkTransactionState)state;

@property (nonatomic) NSError *error;
/// 子类可以重写以提供基于响应数据的错误状态
@property (nonatomic, readonly) BOOL displayAsError;
@property (nonatomic, readonly) NSDate *startTime;

@property (nonatomic) FLEXNetworkTransactionState state;
@property (nonatomic) int64_t receivedDataLength;
/// 预览响应类型的小缩略图
@property (nonatomic) UIImage *thumbnail;

/// 单元格中最突出的一行。通常是URL端点或其他区分属性。
/// 当交易指示错误时，这行变为红色。
@property (nonatomic, readonly) NSString *primaryDescription;
/// 次要信息，例如数据块或URL的域。
@property (nonatomic, readonly) NSString *secondaryDescription;
/// 显示在单元格底部的次要细节，如时间戳、HTTP方法或状态。
@property (nonatomic, readonly) NSString *tertiaryDescription;

/// 用户选择"复制"操作时要复制的字符串
@property (nonatomic, readonly) NSString *copyString;

/// 当用户搜索给定字符串时，此请求是否应该显示
- (BOOL)matchesQuery:(NSString *)filterString;

/// 供内部使用
- (NSString *)timestampStringFromRequestDate:(NSDate *)date;

@end

/// 所有NSURL-API相关事务的共享基类。
/// 此类使用子类提供的URL生成描述。
@interface FLEXURLTransaction : FLEXNetworkTransaction

+ (instancetype)withRequest:(NSURLRequest *)request startTime:(NSDate *)startTime;

@property (nonatomic, readonly) NSURLRequest *request;
/// 交易完成时子类应实现
@property (nonatomic, readonly) NSArray<NSString *> *details;

@end


@interface FLEXHTTPTransaction : FLEXURLTransaction

+ (instancetype)request:(NSURLRequest *)request identifier:(NSString *)requestID;

@property (nonatomic, readonly) NSString *requestID;
@property (nonatomic) NSURLResponse *response;
@property (nonatomic, copy) NSString *requestMechanism;

@property (nonatomic) NSTimeInterval latency;
@property (nonatomic) NSTimeInterval duration;

/// 延迟填充，可为空。处理正常的HTTPBody数据和HTTPBodyStreams。
@property (nonatomic, readonly) NSData *cachedRequestBody;

@end


@interface FLEXWebsocketTransaction : FLEXURLTransaction

+ (instancetype)withMessage:(NSURLSessionWebSocketMessage *)message
                       task:(NSURLSessionWebSocketTask *)task
                  direction:(FLEXWebsocketMessageDirection)direction API_AVAILABLE(ios(13.0));

+ (instancetype)withMessage:(NSURLSessionWebSocketMessage *)message
                       task:(NSURLSessionWebSocketTask *)task
                  direction:(FLEXWebsocketMessageDirection)direction
                  startTime:(NSDate *)started API_AVAILABLE(ios(13.0));

//@property (nonatomic, readonly) NSURLSessionWebSocketTask *task;
@property (nonatomic, readonly) NSURLSessionWebSocketMessage *message API_AVAILABLE(ios(13.0));
@property (nonatomic, readonly) FLEXWebsocketMessageDirection direction API_AVAILABLE(ios(13.0));

@property (nonatomic, readonly) int64_t dataLength API_AVAILABLE(ios(13.0));

@end


typedef NS_ENUM(NSUInteger, FLEXFIRTransactionDirection) {
    FLEXFIRTransactionDirectionNone,
    FLEXFIRTransactionDirectionPush,
    FLEXFIRTransactionDirectionPull,
};

typedef NS_ENUM(NSUInteger, FLEXFIRRequestType) {
    FLEXFIRRequestTypeNotFirebase,
    FLEXFIRRequestTypeFetchQuery,
    FLEXFIRRequestTypeFetchDocument,
    FLEXFIRRequestTypeSetData,
    FLEXFIRRequestTypeUpdateData,
    FLEXFIRRequestTypeAddDocument,
    FLEXFIRRequestTypeDeleteDocument,
};

@interface FLEXFirebaseSetDataInfo : NSObject
/// 设置的数据
@property (nonatomic, readonly) NSDictionary *documentData;
/// 如果 \c mergeFields 有值则为 \c nil
@property (nonatomic, readonly) NSNumber *merge;
/// 如果 \c merge 有值则为 \c nil
@property (nonatomic, readonly) NSArray *mergeFields;
@end

@interface FLEXFirebaseTransaction : FLEXNetworkTransaction

+ (instancetype)queryFetch:(FIRQuery *)initiator;
+ (instancetype)documentFetch:(FIRDocumentReference *)initiator;
+ (instancetype)setData:(FIRDocumentReference *)initiator
                   data:(NSDictionary *)data
                  merge:(NSNumber *)merge
            mergeFields:(NSArray *)mergeFields;
+ (instancetype)updateData:(FIRDocumentReference *)initiator data:(NSDictionary *)data;
+ (instancetype)addDocument:(FIRCollectionReference *)initiator document:(FIRDocumentReference *)doc;
+ (instancetype)deleteDocument:(FIRDocumentReference *)initiator;

@property (nonatomic, readonly) FLEXFIRTransactionDirection direction;
@property (nonatomic, readonly) FLEXFIRRequestType requestType;

@property (nonatomic, readonly) id initiator;
@property (nonatomic, readonly) FIRQuery *initiator_query;
@property (nonatomic, readonly) FIRDocumentReference *initiator_doc;
@property (nonatomic, readonly) FIRCollectionReference *initiator_collection;

/// 仅用于获取类型
@property (nonatomic, copy) NSArray<FIRDocumentSnapshot *> *documents;
/// 仅用于"设置数据"类型
@property (nonatomic, readonly) FLEXFirebaseSetDataInfo *setDataInfo;
/// 仅用于"更新数据"类型
@property (nonatomic, readonly) NSDictionary *updateData;
/// 仅用于"添加文档"类型
@property (nonatomic, readonly) FIRDocumentReference *addedDocument;

@property (nonatomic, readonly) NSString *path;

//@property (nonatomic, readonly) NSString *responseString;
//@property (nonatomic, readonly) NSDictionary *responseObject;

@end
