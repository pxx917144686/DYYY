//
//  DYYYFLEXMethodCallingViewController.m
//  Flipboard
//
//  Created by Ryan Olson on 5/23/14.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

#import "DYYYFLEXMethodCallingViewController.h"
#import "DYYYFLEXRuntimeUtility.h"
#import "DYYYFLEXFieldEditorView.h"
#import "DYYYFLEXObjectExplorerFactory.h"
#import "DYYYFLEXObjectExplorerViewController.h"
#import "DYYYFLEXArgumentInputView.h"
#import "DYYYFLEXArgumentInputViewFactory.h"
#import "DYYYFLEXUtility.h"

@interface DYYYFLEXMethodCallingViewController ()
@property (nonatomic, readonly) DYYYFLEXMethod *method;
@end

@implementation DYYYFLEXMethodCallingViewController

+ (instancetype)target:(id)target method:(DYYYFLEXMethod *)method {
    return [[self alloc] initWithTarget:target method:method];
}

- (id)initWithTarget:(id)target method:(DYYYFLEXMethod *)method {
    NSParameterAssert(method.isInstanceMethod == !object_isClass(target));

    self = [super initWithTarget:target data:method commitHandler:nil];
    if (self) {
        self.title = method.isInstanceMethod ? @"方法: " : @"类方法: ";
        self.title = [self.title stringByAppendingString:method.selectorString];
    }

    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.actionButton.title = @"调用";

    // 配置字段编辑器视图
    self.fieldEditorView.argumentInputViews = [self argumentInputViews];
    self.fieldEditorView.fieldDescription = [NSString stringWithFormat:
        @"签名:\n%@\n\n返回类型:\n%s",
        self.method.description, (char *)self.method.returnType
    ];
}

- (NSArray<DYYYFLEXArgumentInputView *> *)argumentInputViews {
    Method method = self.method.objc_method;
    NSArray *methodComponents = [DYYYFLEXRuntimeUtility prettyArgumentComponentsForMethod:method];
    NSMutableArray<DYYYFLEXArgumentInputView *> *argumentInputViews = [NSMutableArray new];
    unsigned int argumentIndex = kFLEXNumberOfImplicitArgs;

    for (NSString *methodComponent in methodComponents) {
        char *argumentTypeEncoding = method_copyArgumentType(method, argumentIndex);
        DYYYFLEXArgumentInputView *inputView = [DYYYFLEXArgumentInputViewFactory argumentInputViewForTypeEncoding:argumentTypeEncoding];
        free(argumentTypeEncoding);

        inputView.backgroundColor = self.view.backgroundColor;
        inputView.title = methodComponent;
        [argumentInputViews addObject:inputView];
        argumentIndex++;
    }

    return argumentInputViews;
}

- (void)actionButtonPressed:(id)sender {
    // 收集参数
    NSMutableArray *arguments = [NSMutableArray new];
    for (DYYYFLEXArgumentInputView *inputView in self.fieldEditorView.argumentInputViews) {
        // 使用NSNull作为nil占位符；它将被解释为nil
        [arguments addObject:inputView.inputValue ?: NSNull.null];
    }

    // 调用方法
    NSError *error = nil;
    id returnValue = [DYYYFLEXRuntimeUtility
        performSelector:self.method.selector
        onObject:self.target
        withArguments:arguments
        error:&error
    ];
    
    // 关闭键盘并处理提交的更改
    [super actionButtonPressed:sender];

    // 显示返回值或错误
    if (error) {
        [DYYYFLEXAlert showAlert:@"方法调用失败" message:error.localizedDescription from:self];
    } else if (returnValue) {
        // 对于非nil（或void）返回类型，推送一个资源管理器视图控制器来显示返回的对象
        returnValue = [DYYYFLEXRuntimeUtility potentiallyUnwrapBoxedPointer:returnValue type:self.method.returnType];
        DYYYFLEXObjectExplorerViewController *explorer = [DYYYFLEXObjectExplorerFactory explorerViewControllerForObject:returnValue];
        [self.navigationController pushViewController:explorer animated:YES];
    } else {
        [self exploreObjectOrPopViewController:returnValue];
    }
}

- (DYYYFLEXMethod *)method {
    return _data;
}

@end
