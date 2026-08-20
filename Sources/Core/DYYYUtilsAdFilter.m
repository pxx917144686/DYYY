//
//  DYYYUtilsAdFilter.m
//  DYYY
//
//  广告过滤工具：只信任抖音模型自身的明确广告判定与明确广告字段。
//

#import "DYYYUtils.h"
#import <objc/message.h>
#import <objc/runtime.h>

@interface DYYYUtils ()
+ (id)dyyy_safeValueForKey:(NSString *)key fromObject:(id)object;
+ (BOOL)dyyy_objectContainsMeaningfulAdPayload:(id)object;
@end

@implementation DYYYUtils (AdFilter)

#pragma mark - Advertisement Filtering Utilities (广告过滤工具)

+ (id)dyyy_safeValueForKey:(NSString *)key fromObject:(id)object {
    if (!object || key.length == 0) {
        return nil;
    }

    @try {
        return [object valueForKey:key];
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

+ (BOOL)dyyy_objectContainsMeaningfulAdPayload:(id)object {
    if (!object || object == [NSNull null]) {
        return NO;
    }
    if ([object isKindOfClass:[NSString class]]) {
        NSString *value = [(NSString *)object stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        return value.length > 0 &&
               ![value isEqualToString:@"{}"] &&
               ![value isEqualToString:@"[]"] &&
               ![value isEqualToString:@"null"];
    }
    if ([object isKindOfClass:[NSData class]]) {
        return [(NSData *)object length] > 0;
    }
    if ([object isKindOfClass:[NSDictionary class]] || [object isKindOfClass:[NSArray class]]) {
        return [object count] > 0;
    }
    if ([object isKindOfClass:[NSNumber class]]) {
        return [(NSNumber *)object boolValue];
    }
    return NO;
}

+ (BOOL)isAdvertisementAwemeModel:(id)model {
    Class awemeModelClass = NSClassFromString(@"AWEAwemeModel");
    if (!model || !awemeModelClass || ![model isKindOfClass:awemeModelClass]) {
        return NO;
    }

    // 仅信任抖音模型自身明确的广告布尔判定，避免把常驻的广告能力占位对象误当成广告。
    for (NSString *selectorName in @[ @"checkIsAd", @"isHardAdModel", @"isHardAd", @"isAds" ]) {
        SEL selector = NSSelectorFromString(selectorName);
        if ([model respondsToSelector:selector]) {
            BOOL (*sendBool)(id, SEL) = (BOOL (*)(id, SEL))objc_msgSend;
            if (sendBool(model, selector)) {
                return YES;
            }
        }
    }

    return NO;
}

+ (BOOL)isAdvertisementContainerModel:(id)model {
    if ([self isAdvertisementAwemeModel:model]) {
        return YES;
    }

    Class searchModelClass = NSClassFromString(@"AWEGeneralSearchModel");
    if (!searchModelClass || ![model isKindOfClass:searchModelClass]) {
        return NO;
    }

    // 搜索模型中的模块、卡片名和卡片类型在正常作品中也可能作为能力占位常驻，不能单独作为广告证据。
    id dynamicPatch = [self dyyy_safeValueForKey:@"commonDynamicPatchModel" fromObject:model];
    id isAdValue = [self dyyy_safeValueForKey:@"is_ad" fromObject:dynamicPatch];
    if ([isAdValue respondsToSelector:@selector(boolValue)] && [isAdValue boolValue]) {
        return YES;
    }

    for (NSString *selectorName in @[ @"aweme", @"awemeInVideoFeed" ]) {
        SEL selector = NSSelectorFromString(selectorName);
        if (![model respondsToSelector:selector]) {
            continue;
        }
        id (*sendObject)(id, SEL) = (id (*)(id, SEL))objc_msgSend;
        if ([self isAdvertisementAwemeModel:sendObject(model, selector)]) {
            return YES;
        }
    }

    return NO;
}

+ (NSArray *)arrayByRemovingAdvertisements:(id)array {
    if (!DYYYCachedBool(@"DYYYNoAds") || ![array isKindOfClass:[NSArray class]]) {
        return array;
    }

    NSArray *source = (NSArray *)array;
    NSMutableArray *filtered = [NSMutableArray arrayWithCapacity:source.count];
    for (id model in source) {
        if (![self isAdvertisementContainerModel:model]) {
            [filtered addObject:model];
        }
    }

    if (filtered.count == source.count) {
        return array;
    }
    return [array isKindOfClass:[NSMutableArray class]] ? filtered : [filtered copy];
}

+ (BOOL)isAdvertisementRawData:(id)rawData {
    if (![rawData isKindOfClass:[NSDictionary class]]) {
        return NO;
    }

    NSDictionary *dictionary = (NSDictionary *)rawData;
    for (NSString *flagKey in @[ @"is_ads", @"is_ad" ]) {
        id value = dictionary[flagKey];
        if ([value respondsToSelector:@selector(boolValue)] && [value boolValue]) {
            return YES;
        }
    }

    // 仅检查名称本身就代表广告原始载荷的字段；普通作品也可能带有通用 ad_info 能力配置。
    for (NSString *payloadKey in @[ @"aweme_raw_ad", @"raw_ad_data" ]) {
        if ([self dyyy_objectContainsMeaningfulAdPayload:dictionary[payloadKey]]) {
            return YES;
        }
    }

    for (NSString *containerKey in @[ @"aweme", @"aweme_info", @"item", @"common_dynamic_patch_model" ]) {
        if ([self isAdvertisementRawData:dictionary[containerKey]]) {
            return YES;
        }
    }

    return NO;
}

@end
