#import "DYYYManager.h"
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@class DYYYToast;

@interface DYYYManager () {
  AVAssetExportSession *session;
  AVURLAsset *asset;
  AVAssetReader *reader;
  AVAssetWriter *writer;
  dispatch_queue_t queue;
  dispatch_group_t group;
}

@property(nonatomic, strong)
    NSMutableDictionary<NSString *, NSURLSessionDownloadTask *> *downloadTasks;
@property(nonatomic, strong)
    NSMutableDictionary<NSString *, DYYYToast *> *progressViews;
@property(nonatomic, strong) NSOperationQueue *downloadQueue;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *>
    *taskProgressMap;
@property(nonatomic, strong)
    NSMutableDictionary<NSString *, void (^)(BOOL success, NSURL *fileURL)>
        *completionBlocks;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *>
    *mediaTypeMap;

@property(nonatomic, strong) NSMutableDictionary<NSString *, NSString *>
    *downloadToBatchMap;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *>
    *batchCompletedCountMap;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *>
    *batchSuccessCountMap;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *>
    *batchTotalCountMap;
@property(nonatomic, strong)
    NSMutableDictionary<NSString *, void (^)(NSInteger current, NSInteger total)
                        > *batchProgressBlocks;
@property(nonatomic, strong)
    NSMutableDictionary<NSString *,
                        void (^)(NSInteger successCount, NSInteger totalCount)>
        *batchCompletionBlocks;
@end

NS_ASSUME_NONNULL_END
