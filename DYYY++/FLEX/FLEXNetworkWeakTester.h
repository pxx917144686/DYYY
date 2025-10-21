//
//  FLEXNetworkWeakTester.h
//  FLEX
//
//  Copyright © 2023 FLEX Team. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, FLEXNetworkWeakType) {
    FLEXNetworkWeakTypeNone,       // 正常网络
    FLEXNetworkWeakTypeSlow2G,     // 慢速2G
    FLEXNetworkWeakType2G,         // 2G
    FLEXNetworkWeakType3G,         // 3G
    FLEXNetworkWeakType4G,         // 4G
    FLEXNetworkWeakTypeWifi,       // WiFi
    FLEXNetworkWeakTypeDisconnect, // 断网
};

@interface FLEXNetworkWeakTester : NSObject

+ (instancetype)sharedInstance;

// 开始模拟弱网
- (void)startWeakNetworkWithType:(FLEXNetworkWeakType)type;

// 停止弱网模拟
- (void)stopWeakNetwork;

// 当前模拟状态
@property (nonatomic, readonly) FLEXNetworkWeakType currentWeakType;

@end