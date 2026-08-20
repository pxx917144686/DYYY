#if __has_include(<UIKit/UIKit.h>)
#import <UIKit/UIKit.h>
#else
#import <Foundation/Foundation.h>

#ifndef CGFLOAT_DEFINED
typedef double CGFloat;
#define CGFLOAT_DEFINED 1
#endif

@interface UIView : NSObject @end
@interface UIViewController : NSObject @end
@interface UIColor : NSObject @end
@interface UIFont : NSObject @end
@interface UIButton : UIView @end
@interface UILabel : UIView @end
@interface UITextView : UIView @end
#endif

#if __has_include(<Photos/Photos.h>)
#import <Photos/Photos.h>
#endif

#define DYYYGetBool(key) [[NSUserDefaults standardUserDefaults] boolForKey:key]
#define DYYYGetFloat(key) [[NSUserDefaults standardUserDefaults] floatForKey:key]
#define DYYYGetInteger(key) [[NSUserDefaults standardUserDefaults] integerForKey:key]
#define DYYYGetString(key) [[NSUserDefaults standardUserDefaults] stringForKey:key]
#define DYYY_IGNORE_GLOBAL_ALPHA_TAG 114514

// 配置内存缓存：供高频 hook 读取，NSUserDefaults 写入时失效
#ifdef __cplusplus
extern "C" {
#endif
BOOL DYYYCachedBool(NSString *key);
NSString *DYYYCachedString(NSString *key);
NSArray<NSString *> *DYYYCachedKeywordList(NSString *configKey);
void DYYYConfigCacheInvalidate(void);
#ifdef __cplusplus
}
#endif

typedef NS_ENUM(NSInteger, MediaType) {
  MediaTypeVideo,
  MediaTypeImage,
  MediaTypeAudio,
  MediaTypeHeic
};

// ===== 领域头文件（自 AwemeHeaders.h 拆分；声明内容原样保留）=====
#import "AwemeHeadersModel.h"
#import "AwemeHeadersUI.h"
#import "AwemeHeadersFeed.h"
#import "AwemeHeadersComment.h"
#import "AwemeHeadersLive.h"
#import "AwemeHeadersPlayback.h"
#import "AwemeHeadersService.h"
#import "AwemeHeadersPanel.h"

void showVideoStatsEditAlert(UIViewController *viewController);
