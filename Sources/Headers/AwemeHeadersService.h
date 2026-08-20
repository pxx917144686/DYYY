//
//  AwemeHeadersService.h
//  DYYY
//
//  Service 领域头文件声明（自 AwemeHeaders.h 拆分，内容原样保留）。
//

#import <UIKit/UIKit.h>

#ifndef AwemeHeaders_Service_h
#define AwemeHeaders_Service_h


@interface AWEListDataController : NSObject
@property(nonatomic, strong) NSMutableArray *dataSource;
@property(nonatomic, strong) NSMutableArray *filteredDataSource;
@end


@interface AWEHotListDataController : NSObject
- (id)transferAwemeListIfNeededWithArray:(id)arg1 isInitFetch:(BOOL)arg2;
@end


// AWEVersionUpdateManager相关接口声明
@interface AWEVersionUpdateManager : NSObject
@property(nonatomic, strong) id networkModule;
@property(nonatomic, strong) id badgeModule;
@property(nonatomic, strong) id workflow;
- (NSString *)currentVersion;
- (void)startVersionUpdateWorkflow:(id)arg1 completion:(id)arg2;
- (void)workflowDidFinish:(id)arg1;
+ (id)sharedInstance;
@end


@interface AWEVersionUpdateNetworkModule : NSObject
@end


@interface AWEVersionUpdateBadgeModule : NSObject
@end


@interface AWEVersionUpdateWorkflow : NSObject
@end


@interface AWEABTestManager : NSObject
@property(retain, nonatomic) id abTestData;
@property(retain, nonatomic) NSMutableDictionary *consistentABTestDic;
@property(copy, nonatomic) NSDictionary *performanceReversalDic;
- (void)setAbTestData:(id)arg1;
- (void)_saveABTestData:(id)arg1;
- (id)abTestData;
+ (id)sharedManager;
@end
#endif /* AwemeHeaders_Service_h */
