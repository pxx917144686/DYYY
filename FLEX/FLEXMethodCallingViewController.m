// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXMethodCallingViewController.m
//  Flipboard
//
//  由 Ryan Olson 创建于 5/23/14.
//  版权所有 (c) 2020 FLEX Team。保留所有权利。

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
        self.title = method.isInstanceMethod ? @"Method: " : @"Class Method: ";
        self.title = [self.title stringByAppendingString:method.selectorString];
    }

    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // 将 "Call" 改为 "调用"
    self.actionButton.title = @"调用";

    // 将签名和返回类型的描述文本翻译为中文
    self.fieldEditorView.fieldDescription = [NSString stringWithFormat:
        @"方法签名:\n%@\n\n返回类型:\n%s",
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
        // 使用 NSNull 作为 nil 占位符；它将被解释为 nil
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
    
    // 关闭键盘并处理已提交的更改
    [super actionButtonPressed:sender];

    // 显示返回值或错误
    if (error) {
        [FLEXAlert showAlert:@"Method Call Failed" message:error.localizedDescription from:self];
    } else if (returnValue) {
        // 对于非 nil（或 void）返回类型，推送一个浏览器视图控制器以显示返回的对象
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
