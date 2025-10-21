#import <Foundation/Foundation.h>
#import "AwemeHeaders.h"

@interface DYYYSettingsHelper : NSObject

/**
 * 获取用户默认设置（布尔值）
 * @param key 设置键名
 * @return 布尔值设置
 */
+ (bool)getUserDefaults:(NSString *)key;

/**
 * 设置用户默认值
 * @param object 要保存的对象
 * @param key 设置键名
 */
+ (void)setUserDefaults:(id)object forKey:(NSString *)key;

/**
 * 显示自定义关于弹窗
 * @param title 标题
 * @param message 消息内容
 * @param onConfirm 确认回调
 */
+ (void)showAboutDialog:(NSString *)title message:(NSString *)message onConfirm:(void (^)(void))onConfirm;

/**
 * 显示文本输入弹窗（完整版）
 * @param title 标题
 * @param defaultText 默认文本
 * @param placeholder 占位文本
 * @param onConfirm 确认回调
 * @param onCancel 取消回调
 */
+ (void)showTextInputAlert:(NSString *)title defaultText:(NSString *)defaultText placeholder:(NSString *)placeholder onConfirm:(void (^)(NSString *text))onConfirm onCancel:(void (^)(void))onCancel;

/**
 * 显示文本输入弹窗（无占位符）
 * @param title 标题
 * @param defaultText 默认文本
 * @param onConfirm 确认回调
 * @param onCancel 取消回调
 */
+ (void)showTextInputAlert:(NSString *)title defaultText:(NSString *)defaultText onConfirm:(void (^)(NSString *text))onConfirm onCancel:(void (^)(void))onCancel;

/**
 * 显示文本输入弹窗（简化版）
 * @param title 标题
 * @param onConfirm 确认回调
 * @param onCancel 取消回调
 */
+ (void)showTextInputAlert:(NSString *)title onConfirm:(void (^)(NSString *text))onConfirm onCancel:(void (^)(void))onCancel;

/**
 * 获取设置项依赖关系配置
 */
+ (NSDictionary *)settingsDependencyConfig;

/**
 * 创建设置项模型
 * @param dict 包含设置项配置的字典
 * @return 创建的设置项模型
 */
+ (AWESettingItemModel *)createSettingItem:(NSDictionary *)dict;

/**
 * 创建设置项模型(含交互处理)
 * @param dict 包含设置项配置的字典
 * @param cellTapHandlers 单元格点击处理器字典
 * @return 创建的设置项模型
 */
+ (AWESettingItemModel *)createSettingItem:(NSDictionary *)dict cellTapHandlers:(NSMutableDictionary *)cellTapHandlers;

/**
 * 创建自定义图标设置项
 */
+ (AWESettingItemModel *)createIconCustomizationItemWithIdentifier:(NSString *)identifier title:(NSString *)title svgIcon:(NSString *)svgIconName saveFile:(NSString *)saveFilename;

/**
 * 创建设置分区
 */
+ (AWESettingSectionModel *)createSectionWithTitle:(NSString *)title items:(NSArray *)items;

/**
 * 创建设置分区，带 footer
 */
+ (AWESettingSectionModel *)createSectionWithTitle:(NSString *)title footerTitle:(NSString *)footerTitle items:(NSArray *)items;

/**
 * 创建子设置页面控制器
 */
+ (AWESettingBaseViewController *)createSubSettingsViewController:(NSString *)title sections:(NSArray *)sectionsArray;

/**
 * 查找视图所在控制器
 */
+ (UIViewController *)findViewController:(UIResponder *)responder;

/**
 * 打开设置页
 */
+ (void)openSettingsWithViewController:(UIViewController *)vc;

/**
 * 从视图打开设置页
 */
+ (void)openSettingsFromView:(UIView *)view;

/**
 * 为视图添加打开设置页的点击手势
 */
+ (void)addTapGestureToView:(UIView *)view target:(id)target;

/**
 * 显示搜索设置页面
 * @param rootVC 根视图控制器
 */
+ (void)showSearchSettingsPage:(UIViewController *)rootVC;

/**
 * 获取所有设置项的扁平化列表（用于搜索）
 * @return 包含所有设置项的数组
 */
+ (NSArray *)getAllSettingsItems;

@end
