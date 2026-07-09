
#import "DYYYUCPseudocodeViewController.h"
#import "DYYYFLEXColor.h"

@interface DYYYUCPseudocodeViewController ()

@property (nonatomic, strong) UITextView *textView;
@property (nonatomic, copy) NSString *pseudocode;
@property (nonatomic, copy) NSString *navTitle;

@end

@implementation DYYYUCPseudocodeViewController

- (instancetype)initWithPseudocode:(NSString *)pseudocode title:(NSString *)title {
    self = [super init];
    if (self) {
        _pseudocode = pseudocode ?: @"";
        _navTitle = title ?: @"伪代码";
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = DYYYFLEXColor.primaryBackgroundColor;
    self.title = self.navTitle;
    
    [self setupNavigationBar];
    [self setupTextView];
}

- (void)setupNavigationBar {
    UIBarButtonItem *done = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemDone
        target:self
        action:@selector(doneAction)];
    
    UIBarButtonItem *copy = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemAction
        target:self
        action:@selector(copyAction)];
    
    self.navigationItem.rightBarButtonItems = @[done, copy];
}

- (void)setupTextView {
    self.textView = [[UITextView alloc] initWithFrame:self.view.bounds];
    self.textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.textView.font = [UIFont fontWithName:@"Menlo-Regular" size:12];
    self.textView.editable = NO;
    self.textView.selectable = YES;
    self.textView.backgroundColor = [UIColor colorWithRed:0.96 green:0.96 blue:0.98 alpha:1.0];
    self.textView.textColor = [UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:1.0];
    self.textView.textContainerInset = UIEdgeInsetsMake(10, 10, 10, 10);
    self.textView.text = self.pseudocode;
    
    [self.view addSubview:self.textView];
}

- (void)doneAction {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)copyAction {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"选项"
                                                                    message:nil
                                                             preferredStyle:UIAlertControllerStyleActionSheet];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"复制全部"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction * _Nonnull action) {
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        pasteboard.string = self.pseudocode;
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    
    alert.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItems.lastObject;
    [self presentViewController:alert animated:YES completion:nil];
}

@end
