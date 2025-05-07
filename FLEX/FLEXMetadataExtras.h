// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXMetadataExtras.h
//  FLEX
//
//  由 Tanner Bennett 创建于 4/26/22.
//

#import <Foundation/Foundation.h>
#import "FLEXMethodBase.h"
#import "FLEXProperty.h"
#import "FLEXIvar.h"

NS_ASSUME_NONNULL_BEGIN

/// 一个将类型编码字符串映射到字段标题数组的字典
extern NSString * const FLEXAuxiliarynfoKeyFieldLabels;

@protocol FLEXMetadataAuxiliaryInfo <NSObject>

/// 用于提供不需要通过其自身属性公开的任意附加数据
- (nullable id)auxiliaryInfoForKey:(NSString *)key;

@end

@interface FLEXMethodBase (Auxiliary) <FLEXMetadataAuxiliaryInfo> @end
@interface FLEXProperty (Auxiliary) <FLEXMetadataAuxiliaryInfo> @end
@interface FLEXIvar (Auxiliary) <FLEXMetadataAuxiliaryInfo> @end


NS_ASSUME_NONNULL_END
