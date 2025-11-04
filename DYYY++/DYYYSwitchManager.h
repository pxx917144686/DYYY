#import <Foundation/Foundation.h>

// 使用前向声明替代 UIKit 头文件以降低编译依赖
@class UISwitch;
@class UITableView;

NS_ASSUME_NONNULL_BEGIN

@class DYYYSettingItem;

@interface DYYYSwitchManager : NSObject

+ (instancetype)sharedManager;

// 处理开关切换
- (void)handleSwitchToggled:(UISwitch *)sender 
                  withItem:(DYYYSettingItem *)item 
                   section:(NSInteger)section 
                       row:(NSInteger)row
                 tableView:(UITableView *)tableView
          settingSections:(NSArray<NSArray<DYYYSettingItem *> *> *)settingSections;

// 更新互斥开关（按钮大小）
- (void)updateMutuallyExclusiveSwitches:(NSInteger)section 
                        excludingItemKey:(NSString *)excludedKey
                               tableView:(UITableView *)tableView
                        settingSections:(NSArray<NSArray<DYYYSettingItem *> *> *)settingSections;

// 更新子开关状态
- (void)updateSubSwitchesInSection:(NSInteger)section 
                          withKeys:(NSArray<NSString *> *)keys 
                           enabled:(BOOL)enabled
                         tableView:(UITableView *)tableView
                  settingSections:(NSArray<NSArray<DYYYSettingItem *> *> *)settingSections;

// 更新开关依赖关系
- (void)updateSwitchDependencies:(NSString *)key 
                       isEnabled:(BOOL)enabled 
                         section:(NSInteger)section
                       tableView:(UITableView *)tableView
                settingSections:(NSArray<NSArray<DYYYSettingItem *> *> *)settingSections;

// 处理特殊开关逻辑
- (void)updateAreaSubSwitchesUI:(NSInteger)section 
                        enabled:(BOOL)enabled
                      tableView:(UITableView *)tableView
               settingSections:(NSArray<NSArray<DYYYSettingItem *> *> *)settingSections;

- (void)updateAreaMainSwitchUI:(NSInteger)section
                     tableView:(UITableView *)tableView
              settingSections:(NSArray<NSArray<DYYYSettingItem *> *> *)settingSections;

- (void)updateDateTimeFormatSubSwitchesUI:(NSInteger)section 
                                  enabled:(BOOL)enabled
                                tableView:(UITableView *)tableView
                         settingSections:(NSArray<NSArray<DYYYSettingItem *> *> *)settingSections;

- (void)updateDateTimeFormatMainSwitchUI:(NSInteger)section
                               tableView:(UITableView *)tableView
                        settingSections:(NSArray<NSArray<DYYYSettingItem *> *> *)settingSections;

- (void)updateDateTimeFormatExclusiveSwitch:(NSInteger)section 
                                 currentKey:(NSString *)currentKey
                                  tableView:(UITableView *)tableView
                           settingSections:(NSArray<NSArray<DYYYSettingItem *> *> *)settingSections;

// 处理特殊开关类型
- (void)handleSpecialSwitchTypes:(DYYYSettingItem *)item 
                          sender:(UISwitch *)sender
                         section:(NSInteger)section
                       tableView:(UITableView *)tableView
                settingSections:(NSArray<NSArray<DYYYSettingItem *> *> *)settingSections;

@end

NS_ASSUME_NONNULL_END