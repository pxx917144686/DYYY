// 遇到问题联系中文翻译作者：pxx917144686
//
//  Firestore.h
//  Pods
//
//  Created by Tanner Bennett on 10/13/21.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - 前向声明

@class FIRQuery;
@class FIRQuerySnapshot;
@class FIRDocumentReference;
@class FIRDocumentSnapshot;
@class FIRQueryDocumentSnapshot;
@class FIRCollectionReference;
@class FIRFirestore;
@protocol FIRListenerRegistration;

// 获取类的宏定义
#define cFIRQuery objc_getClass("FIRQuery")
#define cFIRCollectionReference objc_getClass("FIRCollectionReference")
#define cFIRDocumentReference objc_getClass("FIRDocumentReference")

// 文档快照回调块类型
typedef void (^FIRDocumentSnapshotBlock)(FIRDocumentSnapshot *_Nullable snapshot,
                                         NSError *_Nullable error);
// 查询快照回调块类型
typedef void (^FIRQuerySnapshotBlock)(FIRQuerySnapshot *_Nullable snapshot,
                                      NSError *_Nullable error);

// Firestore 数据源枚举
typedef NS_ENUM(NSUInteger, FIRFirestoreSource) {
    FIRFirestoreSourceDefault, // 默认源（缓存优先，然后服务器）
    FIRFirestoreSourceServer,  // 仅服务器
    FIRFirestoreSourceCache    // 仅缓存
} NS_SWIFT_NAME(FirestoreSource);

#pragma mark - 查询 (FIRQuery)
@interface FIRQuery : NSObject

- (id)init __attribute__((unavailable())); // 不可用初始化方法

@property(nonatomic, readonly) FIRFirestore *firestore; // 所属 Firestore 实例
@property(nonatomic, readonly) void *query; // 底层查询对象指针 (不透明)

// 获取文档（默认源）
- (void)getDocumentsWithCompletion:(FIRQuerySnapshotBlock)completion
    NS_SWIFT_NAME(getDocuments(completion:));
// 获取文档（指定源）
- (void)getDocumentsWithSource:(FIRFirestoreSource)source
                    completion:(FIRQuerySnapshotBlock)completion
    NS_SWIFT_NAME(getDocuments(source:completion:));

@end


#pragma mark - 文档引用 (FIRDocumentReference)
NS_SWIFT_NAME(DocumentReference)
@interface FIRDocumentReference : NSObject

- (instancetype)init __attribute__((unavailable())); // 不可用初始化方法

@property(nonatomic, readonly) NSString *documentID; // 文档 ID
@property(nonatomic, readonly) FIRCollectionReference *parent; // 父集合引用
@property(nonatomic, readonly) FIRFirestore *firestore; // 所属 Firestore 实例
@property(nonatomic, readonly) NSString *path; // 文档路径

// 获取子集合引用
- (FIRCollectionReference *)collectionWithPath:(NSString *)collectionPath
    NS_SWIFT_NAME(collection(_:));

#pragma mark 写入数据

// 设置文档数据（覆盖）
- (void)setData:(NSDictionary<NSString *, id> *)documentData;
// 设置文档数据（可选合并）
- (void)setData:(NSDictionary<NSString *, id> *)documentData merge:(BOOL)merge;
// 设置文档数据（合并指定字段）
- (void)setData:(NSDictionary<NSString *, id> *)documentData mergeFields:(NSArray<id> *)mergeFields;
// 设置文档数据（带完成回调）
- (void)setData:(NSDictionary<NSString *, id> *)documentData
     completion:(nullable void (^)(NSError *_Nullable error))completion;
// 设置文档数据（可选合并，带完成回调）
- (void)setData:(NSDictionary<NSString *, id> *)documentData
          merge:(BOOL)merge
     completion:(nullable void (^)(NSError *_Nullable error))completion;
// 设置文档数据（合并指定字段，带完成回调）
- (void)setData:(NSDictionary<NSString *, id> *)documentData
    mergeFields:(NSArray<id> *)mergeFields
     completion:(nullable void (^)(NSError *_Nullable error))completion;

// 更新文档数据（部分更新）
- (void)updateData:(NSDictionary<id, id> *)fields;
// 更新文档数据（带完成回调）
- (void)updateData:(NSDictionary<id, id> *)fields
        completion:(nullable void (^)(NSError *_Nullable error))completion;

// 删除文档
- (void)deleteDocument NS_SWIFT_NAME(delete());
// 删除文档（带完成回调）
- (void)deleteDocumentWithCompletion:(nullable void (^)(NSError *_Nullable error))completion
    NS_SWIFT_NAME(delete(completion:));

#pragma mark 检索数据

// 获取文档快照（默认源）
- (void)getDocumentWithCompletion:(FIRDocumentSnapshotBlock)completion
    NS_SWIFT_NAME(getDocument(completion:));
// 获取文档快照（指定源）
- (void)getDocumentWithSource:(FIRFirestoreSource)source
                   completion:(FIRDocumentSnapshotBlock)completion
    NS_SWIFT_NAME(getDocument(source:completion:));

// 添加快照监听器
- (id<FIRListenerRegistration>)addSnapshotListener:(FIRDocumentSnapshotBlock)listener
    NS_SWIFT_NAME(addSnapshotListener(_:));
// 添加快照监听器（可选包含元数据更改）
- (id<FIRListenerRegistration>)addSnapshotListenerWithIncludeMetadataChanges:(BOOL)includeMetadataChanges
                                                                    listener:(FIRDocumentSnapshotBlock)listener
    NS_SWIFT_NAME(addSnapshotListener(includeMetadataChanges:listener:));

@end


#pragma mark - 集合引用 (FIRCollectionReference)
NS_SWIFT_NAME(CollectionReference)
@interface FIRCollectionReference : FIRQuery // 继承自 FIRQuery

- (id)init __attribute__((unavailable())); // 不可用初始化方法

@property(nonatomic, readonly) NSString *collectionID; // 集合 ID
@property(nonatomic, nullable, readonly) FIRDocumentReference *parent; // 父文档引用（如果是子集合）
@property(nonatomic, readonly) NSString *path; // 集合路径

// 获取自动生成 ID 的文档引用
- (FIRDocumentReference *)documentWithAutoID NS_SWIFT_NAME(document());
// 获取指定路径的文档引用
- (FIRDocumentReference *)documentWithPath:(NSString *)documentPath NS_SWIFT_NAME(document(_:));
// 添加新文档（自动生成 ID）
- (FIRDocumentReference *)addDocumentWithData:(NSDictionary<NSString *, id> *)data
    NS_SWIFT_NAME(addDocument(data:));
// 添加新文档（自动生成 ID，带完成回调）
- (FIRDocumentReference *)addDocumentWithData:(NSDictionary<NSString *, id> *)data
                                   completion:(nullable void (^)(NSError *_Nullable error))completion
    NS_SWIFT_NAME(addDocument(data:completion:));
@end

#pragma mark - 查询快照 (FIRQuerySnapshot)
NS_SWIFT_NAME(QuerySnapshot)
@interface FIRQuerySnapshot : NSObject

- (id)init __attribute__((unavailable())); // 不可用初始化方法

@property(nonatomic, readonly) FIRQuery *query; // 原始查询
@property(nonatomic, readonly, getter=isEmpty) BOOL empty; // 是否为空
@property(nonatomic, readonly) NSInteger count; // 文档数量
@property(nonatomic, readonly) NSArray<FIRQueryDocumentSnapshot *> *documents; // 文档快照数组

@end

#pragma mark - 文档快照 (FIRDocumentSnapshot)
NS_SWIFT_NAME(DocumentSnapshot)
@interface FIRDocumentSnapshot : NSObject

- (instancetype)init __attribute__((unavailable())); // 不可用初始化方法

@property(nonatomic, readonly) BOOL exists; // 文档是否存在
@property(nonatomic, readonly) FIRDocumentReference *reference; // 文档引用
@property(nonatomic, copy, readonly) NSString *documentID; // 文档 ID

@property(nonatomic, readonly, nullable) NSDictionary<NSString *, id> *data; // 文档数据（可能为 nil）

// 获取指定字段的值
- (nullable id)valueForField:(id)field NS_SWIFT_NAME(get(_:));
// 通过下标获取字段值
- (nullable id)objectForKeyedSubscript:(id)key;

@end

#pragma mark - 查询文档快照 (FIRQueryDocumentSnapshot)
NS_SWIFT_NAME(QueryDocumentSnapshot)
@interface FIRQueryDocumentSnapshot : FIRDocumentSnapshot // 继承自 FIRDocumentSnapshot

- (instancetype)init __attribute__((unavailable())); // 不可用初始化方法

@property(nonatomic, readonly) NSDictionary<NSString *, id> *data; // 文档数据（保证非 nil）

@end

NS_ASSUME_NONNULL_END


#if defined(__clang__)
#if __has_feature(objc_arc)
// ARC 环境下的宏定义
#define _LOGOS_SELF_TYPE_NORMAL __unsafe_unretained
#define _LOGOS_SELF_TYPE_INIT __attribute__((ns_consumed))
#define _LOGOS_SELF_CONST const
#define _LOGOS_RETURN_RETAINED __attribute__((ns_returns_retained))
#else
// 非 ARC 环境下的宏定义
#define _LOGOS_SELF_TYPE_NORMAL
#define _LOGOS_SELF_TYPE_INIT
#define _LOGOS_SELF_CONST
#define _LOGOS_RETURN_RETAINED
#endif
#else
// 非 Clang 环境下的宏定义
#define _LOGOS_SELF_TYPE_NORMAL
#define _LOGOS_SELF_TYPE_INIT
#define _LOGOS_SELF_CONST
#define _LOGOS_RETURN_RETAINED
#endif
