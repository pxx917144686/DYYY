// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXAlert.m
//  FLEX
//
//  Created by Tanner Bennett on 8/20/19.
//  Copyright © 2020 FLEX Team. All rights reserved.
//

#import "FLEXAlert.h"
#import "FLEXMacros.h"

@interface FLEXAlert ()
@property (nonatomic, readonly) UIAlertController *_controller; // 底层 UIAlertController
@property (nonatomic, readonly) NSMutableArray<FLEXAlertAction *> *_actions; // 存储操作构建器的数组
@end

// 断言宏，用于确保在获取底层 UIAlertAction 后不再修改操作
#define FLEXAlertActionMutationAssertion() \
NSAssert(!self._action, @"在获取底层的 UIAlertAction 后无法修改操作");

@interface FLEXAlertAction ()
@property (nonatomic) UIAlertController *_controller; // 关联的 UIAlertController
@property (nonatomic) NSString *_title; // 标题
@property (nonatomic) UIAlertActionStyle _style; // 样式
@property (nonatomic) BOOL _disable; // 是否禁用
@property (nonatomic) BOOL _isPreferred; // 是否为首选操作
@property (nonatomic) void(^_handler)(UIAlertAction *action); // 处理程序块
@property (nonatomic) UIAlertAction *_action; // 底层 UIAlertAction
@end

@implementation FLEXAlert

+ (void)showAlert:(NSString *)title message:(NSString *)message from:(UIViewController *)viewController {
    // 显示一个简单的带“确定”按钮的警报
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:title
        message:message
        preferredStyle:UIAlertControllerStyleAlert
    ];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [viewController presentViewController:alert animated:YES completion:nil];
}

+ (void)showInputAlertWithTitle:(NSString *)title
                        message:(NSString *)message
                 placeholder:(NSString *)placeholder
                    completion:(void(^)(NSString *))completion
                          from:(UIViewController *)viewController {
    // 显示一个带输入框的警报
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:title
        message:message
        preferredStyle:UIAlertControllerStyleAlert
    ];
    
    // 添加文本输入框
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = placeholder;
    }];
    
    // 添加取消按钮
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    // 添加确定按钮，并在点击时调用完成回调
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *text = alert.textFields.firstObject.text;
        completion(text);
    }]];
    
    [viewController presentViewController:alert animated:YES completion:nil];
}

+ (void)showQuickAlert:(NSString *)title from:(UIViewController *)viewController {
    // 显示一个仅包含标题、无按钮、持续半秒的快速警报
    UIAlertController *alert = [self makeAlert:^(FLEXAlert *make) {
        make.title(title);
    }];
    
    [viewController presentViewController:alert animated:YES completion:^{
        // 半秒后自动消失
        flex_dispatch_after(0.5, dispatch_get_main_queue(), ^{
            [alert dismissViewControllerAnimated:YES completion:nil];
        });
    }];
}

#pragma mark - 初始化

- (instancetype)initWithController:(UIAlertController *)controller {
    self = [super init];
    if (self) {
        __controller = controller; // 初始化底层控制器
        __actions = [NSMutableArray new]; // 初始化操作数组
    }

    return self;
}

+ (UIAlertController *)make:(FLEXAlertBuilder)block withStyle:(UIAlertControllerStyle)style {
    // 创建警报构建器
    FLEXAlert *alert = [[self alloc] initWithController:
        [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:style]
    ];

    // 配置警报
    block(alert);

    // 添加操作
    for (FLEXAlertAction *builder in alert._actions) {
        [alert._controller addAction:builder.action]; // 获取并添加底层 UIAlertAction
    }

    UIAlertController *controller = alert._controller;
    
    // 在警报控制器上设置首选操作
    for (FLEXAlertAction *builder in alert._actions) {
        UIAlertAction *action = builder.action;
        if (builder._isPreferred) {
            controller.preferredAction = action; // 设置首选操作
            break; // 只设置第一个标记为首选的操作
        }
    }
    
    return controller; // 返回配置好的 UIAlertController
}

+ (void)make:(FLEXAlertBuilder)block
   withStyle:(UIAlertControllerStyle)style
    showFrom:(UIViewController *)viewController
      source:(id)viewOrBarItem {
    // 构建警报控制器
    UIAlertController *alert = [self make:block withStyle:style];
    // 配置 popoverPresentationController (用于 iPad)
    if ([viewOrBarItem isKindOfClass:[UIBarButtonItem class]]) {
        alert.popoverPresentationController.barButtonItem = viewOrBarItem;
    } else if ([viewOrBarItem isKindOfClass:[UIView class]]) {
        alert.popoverPresentationController.sourceView = viewOrBarItem;
        alert.popoverPresentationController.sourceRect = [viewOrBarItem bounds];
    } else if (viewOrBarItem) {
        // 确保 source 是 UIView 或 UIBarButtonItem 或 nil
        NSParameterAssert(
            [viewOrBarItem isKindOfClass:[UIBarButtonItem class]] ||
            [viewOrBarItem isKindOfClass:[UIView class]] ||
            !viewOrBarItem
        );
    }
    // 显示警报
    [viewController presentViewController:alert animated:YES completion:nil];
}

+ (void)makeAlert:(FLEXAlertBuilder)block showFrom:(UIViewController *)controller {
    // 构建并显示一个警报样式的弹窗
    [self make:block withStyle:UIAlertControllerStyleAlert showFrom:controller source:nil];
}

+ (void)makeSheet:(FLEXAlertBuilder)block showFrom:(UIViewController *)controller {
    // 构建并显示一个动作表样式的弹窗
    [self make:block withStyle:UIAlertControllerStyleActionSheet showFrom:controller source:nil];
}

/// 构建并显示一个动作表样式的警报
+ (void)makeSheet:(FLEXAlertBuilder)block
         showFrom:(UIViewController *)controller
           source:(id)viewOrBarItem {
    // 构建并显示一个动作表样式的弹窗，并指定来源视图或按钮项
    [self make:block
     withStyle:UIAlertControllerStyleActionSheet
      showFrom:controller
        source:viewOrBarItem];
}

+ (UIAlertController *)makeAlert:(FLEXAlertBuilder)block {
    // 构建一个警报样式的弹窗
    return [self make:block withStyle:UIAlertControllerStyleAlert];
}

+ (UIAlertController *)makeSheet:(FLEXAlertBuilder)block {
    // 构建一个动作表样式的弹窗
    return [self make:block withStyle:UIAlertControllerStyleActionSheet];
}

#pragma mark - 配置

- (FLEXAlertStringProperty)title {
    // 设置或追加标题
    return ^FLEXAlert *(NSString *title) {
        if (self._controller.title) {
            self._controller.title = [self._controller.title stringByAppendingString:title ?: @""];
        } else {
            self._controller.title = title;
        }
        return self;
    };
}

- (FLEXAlertStringProperty)message {
    // 设置或追加消息
    return ^FLEXAlert *(NSString *message) {
        if (self._controller.message) {
            self._controller.message = [self._controller.message stringByAppendingString:message ?: @""];
        } else {
            self._controller.message = message;
        }
        return self;
    };
}

- (FLEXAlertAddAction)button {
    // 添加一个按钮
    return ^FLEXAlertAction *(NSString *title) {
        FLEXAlertAction *action = FLEXAlertAction.new.title(title); // 创建新的操作构建器
        action._controller = self._controller; // 关联控制器
        [self._actions addObject:action]; // 添加到操作数组
        return action;
    };
}

- (FLEXAlertStringArg)textField {
    // 添加一个带占位符的文本框
    return ^FLEXAlert *(NSString *placeholder) {
        [self._controller addTextFieldWithConfigurationHandler:^(UITextField *textField) {
            textField.placeholder = placeholder;
        }];

        return self;
    };
}

- (FLEXAlertTextField)configuredTextField {
    // 添加一个可配置的文本框
    return ^FLEXAlert *(void(^configurationHandler)(UITextField *)) {
        [self._controller addTextFieldWithConfigurationHandler:configurationHandler];
        return self;
    };
}

@end

@implementation FLEXAlertAction

- (FLEXAlertActionStringProperty)title {
    // 设置或追加操作标题
    return ^FLEXAlertAction *(NSString *title) {
        FLEXAlertActionMutationAssertion(); // 检查是否已获取底层 action
        if (self._title) {
            self._title = [self._title stringByAppendingString:title ?: @""];
        } else {
            self._title = title;
        }
        return self;
    };
}

- (FLEXAlertActionProperty)destructiveStyle {
    // 设置为破坏性样式
    return ^FLEXAlertAction *() {
        FLEXAlertActionMutationAssertion();
        self._style = UIAlertActionStyleDestructive;
        return self;
    };
}

- (FLEXAlertActionProperty)cancelStyle {
    // 设置为取消样式
    return ^FLEXAlertAction *() {
        FLEXAlertActionMutationAssertion();
        self._style = UIAlertActionStyleCancel;
        return self;
    };
}

- (FLEXAlertActionProperty)preferred {
    // 标记为首选操作
    return ^FLEXAlertAction *() {
        FLEXAlertActionMutationAssertion();
        self._isPreferred = YES;
        return self;
    };
}

- (FLEXAlertActionBOOLProperty)enabled {
    // 设置启用/禁用状态
    return ^FLEXAlertAction *(BOOL enabled) {
        FLEXAlertActionMutationAssertion();
        self._disable = !enabled;
        return self;
    };
}

- (FLEXAlertActionHandler)handler {
    // 设置处理程序块
    return ^FLEXAlertAction *(void(^handler)(NSArray<NSString *> *)) {
        FLEXAlertActionMutationAssertion();

        // 获取对警报的弱引用以避免块 <--> 警报保留循环
        __weak UIAlertController *controller = self._controller; // 使用 __weak
        self._handler = ^(UIAlertAction *action) {
            __strong UIAlertController *strongController = controller; // 使用 __strong
            if (!strongController) return; // 检查 controller 是否为 nil
            // 强化该引用并将文本字段字符串传递给处理程序
            NSArray *strings = [strongController.textFields valueForKeyPath:@"text"];
            handler(strings);
        };

        return self;
    };
}

- (UIAlertAction *)action {
    // 获取或创建底层 UIAlertAction
    if (self._action) {
        return self._action;
    }

    // 根据配置创建 UIAlertAction
    self._action = [UIAlertAction
        actionWithTitle:self._title
        style:self._style
        handler:self._handler
    ];
    self._action.enabled = !self._disable; // 设置启用状态

    return self._action;
}

@end
