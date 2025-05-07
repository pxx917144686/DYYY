//
//  FLEXKeyboardShortcutManager.h
//  FLEX
//
//  Created by Ryan Olson on 9/19/15.
//  Copyright © 2020 FLEX Team. All rights reserved.
//
// 遇到问题联系中文翻译作者：pxx917144686

#import <UIKit/UIKit.h>

@interface FLEXKeyboardShortcutManager : NSObject

@property (nonatomic, readonly, class) FLEXKeyboardShortcutManager *sharedManager;

/// @param key 与键盘上按键匹配的单个字符字符串
/// @param modifiers 修饰键，如shift、command或alt/option
/// @param action 当识别到按键和修饰键组合时在主线程上运行的代码块
/// @param description 显示在键盘快捷键帮助菜单中，可通过'?'键访问
/// @param allowOverride 即使该按键/修饰键组合已有关联操作，也允许注册
- (void)registerSimulatorShortcutWithKey:(NSString *)key
                               modifiers:(UIKeyModifierFlags)modifiers
                                  action:(dispatch_block_t)action
                             description:(NSString *)description
                           allowOverride:(BOOL)allowOverride;

@property (nonatomic, getter=isEnabled) BOOL enabled;
@property (nonatomic, readonly) NSString *keyboardShortcutsDescription;

@end
