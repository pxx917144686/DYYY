//
//  FLEXDefaultsContentSection.m
//  FLEX
//
//  Created by Tanner Bennett on 8/28/19.
//  Copyright © 2020 FLEX Team. All rights reserved.
//

#import "FLEXDefaultsContentSection.h"
#import "FLEXDefaultEditorViewController.h"
#import "FLEXUtility.h"

@interface FLEXDefaultsContentSection ()
@property (nonatomic) NSUserDefaults *defaults;
@property (nonatomic) NSArray *keys;
@property (nonatomic, readonly) NSDictionary *unexcludedDefaults;
@end

@implementation FLEXDefaultsContentSection
@synthesize keys = _keys;

#pragma mark 初始化

+ (instancetype)forObject:(id)object {
    return [self forDefaults:object];
}

+ (instancetype)standard {
    return [self forDefaults:NSUserDefaults.standardUserDefaults];
}

+ (instancetype)forDefaults:(NSUserDefaults *)userDefaults {
    FLEXDefaultsContentSection *section = [self forReusableFuture:^id(FLEXDefaultsContentSection *section) {
        section.defaults = userDefaults;
        section.onlyShowKeysForAppPrefs = YES;
        return section.unexcludedDefaults;
    }];
    return section;
}

#pragma mark - 重写

- (NSString *)title {
    return @"默认设置";
}

- (void (^)(__kindof UIViewController *))didPressInfoButtonAction:(NSInteger)row {
    return ^(UIViewController *host) {
        if ([FLEXDefaultEditorViewController canEditDefaultWithValue:[self objectForRow:row]]) {
            // 我们使用titleForRow:获取键，因为self.keys不一定与显示的键顺序相同
            FLEXVariableEditorViewController *controller = [FLEXDefaultEditorViewController
                target:self.defaults key:[self titleForRow:row] commitHandler:^{
                    [self reloadData:YES];
                }
            ];
            [host.navigationController pushViewController:controller animated:YES];
        } else {
            [FLEXAlert showAlert:@"NO..." message:@"我们无法编辑此条目 :(" from:host];
        }
    };
}

- (UITableViewCellAccessoryType)accessoryTypeForRow:(NSInteger)row {
    return UITableViewCellAccessoryDetailDisclosureButton;
}

#pragma mark - 私有方法

- (NSArray *)keys {
    if (!_keys) {
        if (self.onlyShowKeysForAppPrefs) {
            // 从偏好设置文件读取键
            NSString *bundle = NSBundle.mainBundle.bundleIdentifier;
            NSString *prefsPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Preferences"];
            NSString *filePath = [NSString stringWithFormat:@"%@/%@.plist", prefsPath, bundle];
            self.keys = [NSDictionary dictionaryWithContentsOfFile:filePath].allKeys;
        } else {
            self.keys = self.defaults.dictionaryRepresentation.allKeys;
        }
    }

    return _keys;
}

- (void)setKeys:(NSArray *)keys {
    _keys = [keys sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
}

- (NSDictionary *)unexcludedDefaults {
    // 情况：不排除任何内容
    if (!self.onlyShowKeysForAppPrefs) {
        return self.defaults.dictionaryRepresentation;
    }

    // 每次调用此方法时重新生成键的允许列表
    _keys = nil;

    // 从未排除的键生成新字典
    NSArray *values = [self.defaults.dictionaryRepresentation
        objectsForKeys:self.keys notFoundMarker:NSNull.null
    ];
    return [NSDictionary dictionaryWithObjects:values forKeys:self.keys];
}

#pragma mark - 公共方法

- (void)setOnlyShowKeysForAppPrefs:(BOOL)onlyShowKeysForAppPrefs {
    if (onlyShowKeysForAppPrefs) {
        // 此属性仅适用于我们使用standardUserDefaults时
        if (self.defaults != NSUserDefaults.standardUserDefaults) return;
    }

    _onlyShowKeysForAppPrefs = onlyShowKeysForAppPrefs;
}

@end
