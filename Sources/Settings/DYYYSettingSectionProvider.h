#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class DYYYSettingItem;

@interface DYYYSettingSectionProvider : NSObject

+ (NSArray<NSArray<DYYYSettingItem *> *> *)defaultSections;

@end

NS_ASSUME_NONNULL_END
