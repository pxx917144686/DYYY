#import "FLEXFileBrowserController.h"

@interface FLEXFileBrowserController (RuntimeBrowser)

// ✅ 重命名方法以避免冲突
- (void)analyzeRuntimeMachOFile:(NSString *)path;  // 原：analyzeMachOFile:
- (void)analyzePlistFile:(NSString *)path;
- (void)previewTextFile:(NSString *)path;
- (void)analyzeFileAtPath:(NSString *)path;

@end