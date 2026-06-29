#import "UCDecryptTool.h"
#import "DatabaseManager.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Security/Security.h>
#import <objc/runtime.h>

#ifdef __cplusplus
extern "C" {
#endif

void RegisterCryptoHooks(void);
void RegisterStreamingHashHooks(void);
void RegisterOpenSSLHooks(void);
void RegisterSSLHooks(void);
void ssl2_kill(void);
void ssl3_kill(void);
void RegisterURLResponseHooks(void);
void RegisterURLInterceptHooks(void);
void IZXShowDecryptPanelNow(void);

NSString *CurrentBundleID(void) {
    return [[NSBundle mainBundle] bundleIdentifier] ?: @"unknown.bundle";
}

NSString *HexStringFromBytes(const void *bytes, size_t length) {
    if (!bytes || length == 0) return @"";
    const uint8_t *p = (const uint8_t *)bytes;
    NSMutableString *s = [NSMutableString stringWithCapacity:length * 2];
    for (size_t i = 0; i < length; i++) {
        [s appendFormat:@"%02x", p[i]];
    }
    return s;
}

#ifdef __cplusplus
}
#endif

@implementation UCDecryptTool

+ (void)load {
    [self scheduleDeferredDecryptHooksInstall];
}

+ (void)scheduleDeferredDecryptHooksInstall {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            __block BOOL didScheduleInstall = NO;
            __block id launchObserver = nil;
            NSNotificationCenter *center = [NSNotificationCenter defaultCenter];

            void (^scheduleInstall)(void) = ^{
                if (didScheduleInstall) return;
                didScheduleInstall = YES;
                if (launchObserver) {
                    [center removeObserver:launchObserver];
                    launchObserver = nil;
                }

                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self installDecryptHooksIfNeeded];
                });
            };

            launchObserver = [center addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                 object:nil
                                                  queue:NSOperationQueue.mainQueue
                                             usingBlock:^(__unused NSNotification *note) {
                scheduleInstall();
            }];

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                scheduleInstall();
            });
        });
    });
}

+ (void)installDecryptHooksIfNeeded {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        @autoreleasepool {
            [[DatabaseManager sharedManager] createTables];
            [[DatabaseManager sharedManager] insertLogText:[NSString stringWithFormat:@"Decrypt feature loaded for %@", CurrentBundleID()]];
            RegisterCryptoHooks();
            RegisterStreamingHashHooks();
            RegisterOpenSSLHooks();
            RegisterSSLHooks();
            RegisterURLResponseHooks();
            RegisterURLInterceptHooks();
            ssl2_kill();
            ssl3_kill();
        }
    });
}

+ (void)presentDecryptPanelFromViewController:(UIViewController *)viewController {
    [self installDecryptHooksIfNeeded];
    dispatch_async(dispatch_get_main_queue(), ^{
        IZXShowDecryptPanelNow();
    });
}

@end
