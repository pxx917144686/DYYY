//
//  FLEXMethodCallingViewController.m
//  Flipboard
//
//  Created by Ryan Olson on 5/23/14.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

#import "FLEXMethodCallingViewController.h"
#import "FLEXRuntimeUtility.h"
#import "FLEXFieldEditorView.h"
#import "FLEXObjectExplorerFactory.h"
#import "FLEXObjectExplorerViewController.h"
#import "FLEXArgumentInputView.h"
#import "FLEXArgumentInputViewFactory.h"
#import "FLEXUtility.h"

@interface FLEXMethodCallingViewController ()
@property (nonatomic, readonly) FLEXMethod *method;
@end

@implementation FLEXMethodCallingViewController

+ (instancetype)target:(id)target method:(FLEXMethod *)method {
    return [[self alloc] initWithTarget:target method:method];
}

- (id)initWithTarget:(id)target method:(FLEXMethod *)method {
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

- (NSArray<FLEXArgumentInputView *> *)argumentInputViews {
    Method method = self.method.objc_method;
    NSArray *methodComponents = [FLEXRuntimeUtility prettyArgumentComponentsForMethod:method];
    NSMutableArray<FLEXArgumentInputView *> *argumentInputViews = [NSMutableArray new];
    unsigned int argumentIndex = kFLEXNumberOfImplicitArgs;

    for (NSString *methodComponent in methodComponents) {
        char *argumentTypeEncoding = method_copyArgumentType(method, argumentIndex);
        FLEXArgumentInputView *inputView = [FLEXArgumentInputViewFactory argumentInputViewForTypeEncoding:argumentTypeEncoding];
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
    for (FLEXArgumentInputView *inputView in self.fieldEditorView.argumentInputViews) {
        // 使用NSNull作为nil占位符；它将被解释为nil
        [arguments addObject:inputView.inputValue ?: NSNull.null];
    }

    // 调用方法
    NSError *error = nil;
    id returnValue = [FLEXRuntimeUtility
        performSelector:self.method.selector
        onObject:self.target
        withArguments:arguments
        error:&error
    ];
    
    // 关闭键盘并处理提交的更改
    [super actionButtonPressed:sender];

    // 显示返回值或错误
    if (error) {
        [FLEXAlert showAlert:@"方法调用失败" message:error.localizedDescription from:self];
    } else if (returnValue) {
        // 对于非nil（或void）返回类型，推送一个资源管理器视图控制器来显示返回的对象
        returnValue = [FLEXRuntimeUtility potentiallyUnwrapBoxedPointer:returnValue type:self.method.returnType];
        FLEXObjectExplorerViewController *explorer = [FLEXObjectExplorerFactory explorerViewControllerForObject:returnValue];
        [self.navigationController pushViewController:explorer animated:YES];
    } else {
        [self exploreObjectOrPopViewController:returnValue];
    }
}

- (FLEXMethod *)method {
    return _data;
}

@end
