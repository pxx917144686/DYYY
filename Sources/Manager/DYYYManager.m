#import "DYYYManagerPrivate.h"

@implementation DYYYManager

+ (instancetype)shared {
  static DYYYManager *sharedInstance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedInstance = [[self alloc] init];
  });
  return sharedInstance;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _fileLinks = [NSMutableDictionary dictionary];
    _downloadTasks = [NSMutableDictionary dictionary];
    _progressViews = [NSMutableDictionary dictionary];
    _downloadQueue = [[NSOperationQueue alloc] init];
    _downloadQueue.maxConcurrentOperationCount =
        3; // A maximum of 3 concurrent downloads
    _taskProgressMap =
        [NSMutableDictionary dictionary];
    _completionBlocks =
        [NSMutableDictionary dictionary];
    _mediaTypeMap =
        [NSMutableDictionary dictionary];

    // 初始化批量下载相关字典
    _downloadToBatchMap = [NSMutableDictionary dictionary];
    _batchCompletedCountMap = [NSMutableDictionary dictionary];
    _batchSuccessCountMap = [NSMutableDictionary dictionary];
    _batchTotalCountMap = [NSMutableDictionary dictionary];
    _batchProgressBlocks = [NSMutableDictionary dictionary];
    _batchCompletionBlocks = [NSMutableDictionary dictionary];
  }
  return self;
}


@end
