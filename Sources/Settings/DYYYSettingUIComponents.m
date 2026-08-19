#import "DYYYSettingUIComponents.h"

@implementation DYYYSliderRelay

- (void)changed:(UISlider *)sender {
    if (self.block) self.block(sender);
}

@end

@interface DYYYSliderViewController ()
@property (nonatomic, copy) NSString *sliderTitle;
@property (nonatomic, assign) NSInteger initialValue;
@property (nonatomic, copy) void (^completion)(NSInteger value);
@property (nonatomic, strong) UISlider *slider;
@end

@implementation DYYYSliderViewController

- (instancetype)initWithTitle:(NSString *)title
                        value:(NSInteger)value
                   completion:(void (^)(NSInteger value))completion {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _sliderTitle = [title copy];
        _initialValue = value;
        _completion = [completion copy];
        self.modalPresentationStyle = UIModalPresentationPageSheet;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = self.sliderTitle;
    titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.numberOfLines = 0;

    UISlider *slider = [[UISlider alloc] init];
    slider.minimumValue = 0.0;
    slider.maximumValue = 100.0;
    slider.value = (float)self.initialValue;
    slider.translatesAutoresizingMaskIntoConstraints = NO;
    self.slider = slider;

    UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [cancelButton setTitle:@"取消" forState:UIControlStateNormal];
    [cancelButton addTarget:self action:@selector(cancelTapped) forControlEvents:UIControlEventTouchUpInside];

    UIButton *doneButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [doneButton setTitle:@"完成" forState:UIControlStateNormal];
    [doneButton addTarget:self action:@selector(doneTapped) forControlEvents:UIControlEventTouchUpInside];

    UIStackView *buttons = [[UIStackView alloc] initWithArrangedSubviews:@[cancelButton, doneButton]];
    buttons.axis = UILayoutConstraintAxisHorizontal;
    buttons.distribution = UIStackViewDistributionFillEqually;
    buttons.spacing = 16.0;

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[titleLabel, slider, buttons]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 24.0;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [stack.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:32.0],
        [stack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-32.0],
        [slider.widthAnchor constraintEqualToAnchor:stack.widthAnchor],
    ]];

    if (@available(iOS 15.0, *)) {
        self.sheetPresentationController.detents = @[UISheetPresentationControllerDetent.mediumDetent];
        self.sheetPresentationController.prefersGrabberVisible = YES;
    }
}

- (void)cancelTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)doneTapped {
    NSInteger value = (NSInteger)lroundf(self.slider.value);
    if (value < 0) value = 0;
    if (value > 100) value = 100;
    if (self.completion) self.completion(value);
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
