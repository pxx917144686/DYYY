#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// 设置条目类型
typedef NS_ENUM(NSInteger, DYYYSettingItemType) {
    DYYYSettingItemTypeSwitch,
    DYYYSettingItemTypeTextField,
    DYYYSettingItemTypeSpeedPicker,
    DYYYSettingItemTypeColorPicker,
    DYYYSettingItemTypeCustomPicker,
    DYYYSettingItemTypeChoice,
    DYYYSettingItemTypeSlider,
    DYYYSettingItemTypeButton,
    DYYYSettingItemTypeGroupHeader
};

@interface DYYYSettingItem : NSObject

@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong, nullable) NSString *key;
@property (nonatomic, assign) NSInteger type;
@property (nonatomic, strong, nullable) NSString *placeholder;
@property (nonatomic, strong, nullable) NSArray<NSString *> *options;
@property (nonatomic, assign) NSInteger defaultInteger;

+ (instancetype)itemWithTitle:(NSString *)title key:(NSString *)key type:(NSInteger)type;
+ (instancetype)itemWithTitle:(NSString *)title key:(NSString *)key type:(NSInteger)type placeholder:(nullable NSString *)placeholder;
+ (instancetype)itemWithTitle:(NSString *)title key:(NSString *)key type:(NSInteger)type options:(nullable NSArray<NSString *> *)options;
+ (instancetype)itemWithTitle:(NSString *)title key:(NSString *)key type:(NSInteger)type defaultInteger:(NSInteger)defaultInteger;
+ (instancetype)itemWithGroupTitle:(NSString *)title;

@end

NS_ASSUME_NONNULL_END
