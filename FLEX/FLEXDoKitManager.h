#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface FLEXDoKitManager : NSObject

@property (nonatomic, strong, readonly) NSMutableArray *registeredTools;
@property (nonatomic, assign) BOOL isFloatingWindowEnabled;

+ (instancetype)sharedInstance;

// 工具注册
- (void)registerTool:(Class)toolClass withName:(NSString *)name category:(NSString *)category;
- (void)unregisterToolWithName:(NSString *)name;

// 悬浮窗管理
- (void)showFloatingWindow;
- (void)hideFloatingWindow;

// 工具启动
- (void)startTool:(NSString *)toolName;
- (void)stopTool:(NSString *)toolName;

@end

NS_ASSUME_NONNULL_END