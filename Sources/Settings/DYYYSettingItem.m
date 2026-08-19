#import "DYYYSettingItem.h"

@implementation DYYYSettingItem

+ (instancetype)itemWithTitle:(NSString *)title key:(NSString *)key type:(NSInteger)type {
    return [self itemWithTitle:title key:key type:type placeholder:nil];
}

+ (instancetype)itemWithTitle:(NSString *)title key:(NSString *)key type:(NSInteger)type placeholder:(NSString *)placeholder {
    DYYYSettingItem *item = [[DYYYSettingItem alloc] init];
    item.title = title;
    item.key = key;
    item.type = type;
    item.placeholder = placeholder;
    return item;
}

+ (instancetype)itemWithTitle:(NSString *)title key:(NSString *)key type:(NSInteger)type options:(NSArray<NSString *> *)options {
    DYYYSettingItem *item = [self itemWithTitle:title key:key type:type];
    item.options = options;
    return item;
}

+ (instancetype)itemWithTitle:(NSString *)title key:(NSString *)key type:(NSInteger)type defaultInteger:(NSInteger)defaultInteger {
    DYYYSettingItem *item = [self itemWithTitle:title key:key type:type];
    item.defaultInteger = defaultInteger;
    return item;
}

+ (instancetype)itemWithGroupTitle:(NSString *)title {
    DYYYSettingItem *item = [[DYYYSettingItem alloc] init];
    item.title = title;
    item.key = nil;
    item.type = DYYYSettingItemTypeGroupHeader;
    return item;
}

@end
