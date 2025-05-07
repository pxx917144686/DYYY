// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXMITMDataSource.h
//  FLEX
//
//  由 Tanner Bennett 创建于 8/22/21.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FLEXMITMDataSource<__covariant TransactionType> : NSObject

+ (instancetype)dataSourceWithProvider:(NSArray<TransactionType> *(^)(void))future;

/// \c transactions 和 \c bytesReceived 中的数据是否实际已过滤
@property (nonatomic, readonly) BOOL isFiltered;

/// 此数组的内容已过滤以匹配 \c filter:completion: 的输入
@property (nonatomic, readonly) NSArray<TransactionType> *transactions;
@property (nonatomic, readonly) NSArray<TransactionType> *allTransactions;

/// 此数组的内容已过滤以匹配 \c filter:completion: 的输入
@property (nonatomic) NSInteger bytesReceived;
@property (nonatomic) NSInteger totalBytesReceived;

- (void)reloadByteCounts;
- (void)reloadData:(void (^_Nullable)(FLEXMITMDataSource *dataSource))completion;
- (void)filter:(NSString *)searchString completion:(void(^_Nullable)(FLEXMITMDataSource *dataSource))completion;

@end

NS_ASSUME_NONNULL_END
