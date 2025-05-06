// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXManager+Extensibility.h
//  FLEX
//
//  由 Tanner 创建于 2/2/20.
//  版权所有 © 2020 FLEX Team。保留所有权利。
//

#import "FLEXManager.h"
#import "FLEXGlobalsEntry.h"

NS_ASSUME_NONNULL_BEGIN

@interface FLEXManager (Extensibility)

#pragma mark - 全局屏幕条目

/// 在全局状态项列表的顶部添加一个条目。
/// 在显示此视图控制器之前调用此方法。
/// @param entryName 要在单元格中显示的字符串。
/// @param objectFutureBlock 当您点击该行时，将显示有关此块返回的对象的信息。
/// 传递一个返回对象的块允许您显示有关其实际指针可能在运行时更改的对象的信息（例如 +currentUser）
/// @注意 此方法必须从主线程调用。
/// objectFutureBlock 将从主线程调用，并且可能返回 nil。
/// @注意 传递的块将被复制并在应用程序的整个生命周期内保留，您可能需要使用 __weak 引用。
- (void)registerGlobalEntryWithName:(NSString *)entryName objectFutureBlock:(id (^)(void))objectFutureBlock;

/// 在全局状态项列表的顶部添加一个条目。
/// 在显示此视图控制器之前调用此方法。
/// @param entryName 要在单元格中显示的字符串。
/// @param viewControllerFutureBlock 当您点击该行时，此块返回的视图控制器将被推送到导航控制器堆栈上。
/// @注意 此方法必须从主线程调用。
/// viewControllerFutureBlock 将从主线程调用，并且不得返回 nil。
/// @注意 传递的块将被复制并在应用程序的整个生命周期内保留，您可能需要根据需要使用 __weak 引用。
- (void)registerGlobalEntryWithName:(NSString *)entryName
          viewControllerFutureBlock:(UIViewController * (^)(void))viewControllerFutureBlock;

/// 在全局状态项列表的顶部添加一个条目。
/// @param entryName 要在单元格中显示的字符串。
/// @param rowSelectedAction 当您点击该行时，将使用宿主表视图控制器调用此块。
/// 用它来取消选择该行或显示警报。
/// @注意 此方法必须从主线程调用。
/// rowSelectedAction 将从主线程调用。
/// @注意 传递的块将被复制并在应用程序的整个生命周期内保留，您可能需要根据需要使用 __weak 引用。
- (void)registerGlobalEntryWithName:(NSString *)entryName action:(FLEXGlobalsEntryRowAction)rowSelectedAction;

/// 删除所有已注册的全局条目。
- (void)clearGlobalEntries;

#pragma mark - 编辑

/// 为自定义结构类型启用显示 ivar 名称
+ (void)registerFieldNames:(NSArray<NSString *> *)names forTypeEncoding:(NSString *)typeEncoding;

#pragma mark - 模拟器快捷键

/// 模拟器键盘快捷键默认启用。
/// 当存在活动文本字段、文本视图或其他接受按键输入的响应程序时，快捷键将不会触发。
/// 如果您现有的键盘快捷键与 FLEX 冲突，或者您喜欢以困难的方式做事，则可以禁用键盘快捷键 ;)
/// 键盘快捷键在非模拟器版本中始终被禁用（并且支持被 #if'd 掉）
@property (nonatomic) BOOL simulatorShortcutsEnabled;

/// 添加一个在按下指定的键和修饰符组合时运行的操作
/// @param key 与键盘上的键匹配的单个字符字符串
/// @param modifiers 修饰键，例如 shift、command 或 alt/option
/// @param action 当识别到键和修饰符组合时在主线程上运行的块。
/// @param description 显示在键盘快捷键帮助菜单中，可通过“?”键访问。
/// @注意 操作块将在应用程序的整个生命周期内保留。您可能需要使用弱引用。
/// @注意 FLEX 注册了几个默认的键盘快捷键。使用“?”键查看快捷键列表。
- (void)registerSimulatorShortcutWithKey:(NSString *)key
                               modifiers:(UIKeyModifierFlags)modifiers
                                  action:(dispatch_block_t)action
                             description:(NSString *)description;

@end

NS_ASSUME_NONNULL_END
