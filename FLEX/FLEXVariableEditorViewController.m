// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXVariableEditorViewController.m
//  Flipboard
//
//  由 Ryan Olson 创建于 5/16/14.
//  版权所有 (c) 2020 FLEX Team。保留所有权利。
//

#import "FLEXColor.h"
#import "FLEXVariableEditorViewController.h"
#import "FLEXFieldEditorView.h"
#import "FLEXRuntimeUtility.h"
#import "FLEXUtility.h"
#import "FLEXObjectExplorerFactory.h"
#import "FLEXArgumentInputView.h"
#import "FLEXArgumentInputViewFactory.h"
#import "FLEXObjectExplorerViewController.h"
#import "UIBarButtonItem+FLEX.h"

@interface FLEXVariableEditorViewController () <UIScrollViewDelegate>
@property (nonatomic) UIScrollView *scrollView;
@end

@implementation FLEXVariableEditorViewController

#pragma mark - 初始化

+ (instancetype)target:(id)target data:(nullable id)data commitHandler:(void(^_Nullable)(void))onCommit {
    return [[self alloc] initWithTarget:target data:data commitHandler:onCommit];
}

- (id)initWithTarget:(id)target data:(nullable id)data commitHandler:(void(^_Nullable)(void))onCommit {
    self = [super init];
    if (self) {
        _target = target;
        _data = data;
        _commitHandler = onCommit;
        [NSNotificationCenter.defaultCenter
            addObserver:self selector:@selector(keyboardDidShow:)
            name:UIKeyboardWillShowNotification object:nil
        ];
        [NSNotificationCenter.defaultCenter
            addObserver:self selector:@selector(keyboardWillHide:)
            name:UIKeyboardWillHideNotification object:nil
        ];
    }
    
    return self;
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

#pragma mark - UIViewController 方法

- (void)keyboardDidShow:(NSNotification *)notification {
    CGRect keyboardRectInWindow = [[[notification userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGSize keyboardSize = [self.view convertRect:keyboardRectInWindow fromView:nil].size;
    UIEdgeInsets scrollInsets = self.scrollView.contentInset;
    scrollInsets.bottom = keyboardSize.height;
    self.scrollView.contentInset = scrollInsets;
    self.scrollView.scrollIndicatorInsets = scrollInsets;
    
    // 找到活动的输入视图并滚动以确保其可见。
    for (FLEXArgumentInputView *argumentInputView in self.fieldEditorView.argumentInputViews) {
        if (argumentInputView.inputViewIsFirstResponder) {
            CGRect scrollToVisibleRect = [self.scrollView convertRect:argumentInputView.bounds fromView:argumentInputView];
            [self.scrollView scrollRectToVisible:scrollToVisibleRect animated:YES];
            break;
        }
    }
}

- (void)keyboardWillHide:(NSNotification *)notification {
    UIEdgeInsets scrollInsets = self.scrollView.contentInset;
    scrollInsets.bottom = 0.0;
    self.scrollView.contentInset = scrollInsets;
    self.scrollView.scrollIndicatorInsets = scrollInsets;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = FLEXColor.scrollViewBackgroundColor;
    
    self.scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    self.scrollView.backgroundColor = self.view.backgroundColor;
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.scrollView.delegate = self;
    [self.view addSubview:self.scrollView];
    
    _fieldEditorView = [FLEXFieldEditorView new];
    self.fieldEditorView.targetDescription = [NSString stringWithFormat:@"%@ %p", [self.target class], self.target];
    [self.scrollView addSubview:self.fieldEditorView];
    
    _actionButton = [[UIBarButtonItem alloc]
        initWithTitle:@"设置"
        style:UIBarButtonItemStyleDone
        target:self
        action:@selector(actionButtonPressed:)
    ];
    
    self.navigationController.toolbarHidden = NO;
    self.toolbarItems = @[UIBarButtonItem.flex_flexibleSpace, self.actionButton];
}

- (void)viewWillLayoutSubviews {
    CGSize constrainSize = CGSizeMake(self.scrollView.bounds.size.width, CGFLOAT_MAX);
    CGSize fieldEditorSize = [self.fieldEditorView sizeThatFits:constrainSize];
    self.fieldEditorView.frame = CGRectMake(0, 0, fieldEditorSize.width, fieldEditorSize.height);
    self.scrollView.contentSize = fieldEditorSize;
}

#pragma mark - 公开

- (FLEXArgumentInputView *)firstInputView {
    return [self.fieldEditorView argumentInputViews].firstObject;
}

- (void)actionButtonPressed:(id)sender {
    // 子类可以覆盖
    [self.fieldEditorView endEditing:YES];
    if (_commitHandler) {
        _commitHandler();
    }
}

- (void)exploreObjectOrPopViewController:(id)objectOrNil {
    if (objectOrNil) {
        // 对于非 nil (或 void) 返回类型，推送一个浏览器视图控制器以显示对象
        FLEXObjectExplorerViewController *explorerViewController = [FLEXObjectExplorerFactory explorerViewControllerForObject:objectOrNil];
        [self.navigationController pushViewController:explorerViewController animated:YES];
    } else {
        // 如果我们没有得到返回的对象，但方法调用成功了，
        // 则将此视图控制器从堆栈中弹出，以指示调用已通过。
        [self.navigationController popViewControllerAnimated:YES];
    }
}

@end
