//
//  FLEXFieldEditorViewController.m
//  FLEX
//
//  Created by Tanner on 11/22/18.
//  Copyright © 2020 FLEX Team. All rights reserved.
//

#import "FLEXFieldEditorViewController.h"
#import "FLEXFieldEditorView.h"
#import "FLEXArgumentInputViewFactory.h"
#import "FLEXPropertyAttributes.h"
#import "FLEXRuntimeUtility.h"
#import "FLEXMetadataExtras.h"
#import "FLEXUtility.h"
#import "FLEXColor.h"
#import "UIBarButtonItem+FLEX.h"

@interface FLEXFieldEditorViewController () <FLEXArgumentInputViewDelegate>

@property (nonatomic, readonly) id<FLEXMetadataAuxiliaryInfo> auxiliaryInfoProvider;
@property (nonatomic) FLEXProperty *property;
@property (nonatomic) FLEXIvar *ivar;

@property (nonatomic, readonly) id currentValue;
@property (nonatomic, readonly) const FLEXTypeEncoding *typeEncoding;
@property (nonatomic, readonly) NSString *fieldDescription;

@end

@implementation FLEXFieldEditorViewController

#pragma mark - 初始化

+ (instancetype)target:(id)target property:(nonnull FLEXProperty *)property commitHandler:(void(^)(void))onCommit {
    FLEXFieldEditorViewController *editor = [self target:target data:property commitHandler:onCommit];
    editor.title = [@"属性: " stringByAppendingString:property.name];
    editor.property = property;
    return editor;
}

+ (instancetype)target:(id)target ivar:(nonnull FLEXIvar *)ivar commitHandler:(void(^)(void))onCommit {
    FLEXFieldEditorViewController *editor = [self target:target data:ivar commitHandler:onCommit];
    editor.title = [@"实例变量: " stringByAppendingString:ivar.name];
    editor.ivar = ivar;
    return editor;
}

#pragma mark - 重写

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = FLEXColor.groupedBackgroundColor;

    // 创建获取器按钮
    _getterButton = [[UIBarButtonItem alloc]
        initWithTitle:@"进入"
        style:UIBarButtonItemStyleDone
        target:self
        action:@selector(getterButtonPressed:)
    ];
    self.toolbarItems = @[
        UIBarButtonItem.flex_flexibleSpace, self.getterButton, self.actionButton
    ];
    
    [self registerAuxiliaryInfo];

    // 配置输入视图
    self.fieldEditorView.fieldDescription = self.fieldDescription;
    FLEXArgumentInputView *inputView = [FLEXArgumentInputViewFactory argumentInputViewForTypeEncoding:self.typeEncoding];
    inputView.inputValue = self.currentValue;
    inputView.delegate = self;
    self.fieldEditorView.argumentInputViews = @[inputView];

    // 不为开关显示"设置"按钮；当开关翻转时我们进行变更
    if ([inputView isKindOfClass:[FLEXArgumentInputSwitchView class]]) {
        self.actionButton.enabled = NO;
        self.actionButton.title = @"翻转开关以调用设置器";
        // 将获取器按钮放在设置器按钮之前
        self.toolbarItems = @[
            UIBarButtonItem.flex_flexibleSpace, self.actionButton, self.getterButton
        ];
    }
}

- (void)actionButtonPressed:(id)sender {
    if (self.property) {
        id userInputObject = self.firstInputView.inputValue;
        NSArray *arguments = userInputObject ? @[userInputObject] : nil;
        SEL setterSelector = self.property.likelySetter;
        NSError *error = nil;
        [FLEXRuntimeUtility performSelector:setterSelector onObject:self.target withArguments:arguments error:&error];
        if (error) {
            [FLEXAlert showAlert:@"属性设置失败" message:error.localizedDescription from:self];
            sender = nil; // 不要返回上一页
        }
    } else {
        // TODO: 检查可变性并在必要时使用mutableCopy；
        // 这当前可能会将NSArray分配给NSMutableArray
        [self.ivar setValue:self.firstInputView.inputValue onObject:self.target];
    }
    
    // 关闭键盘并处理已提交的更改
    [super actionButtonPressed:sender];

    // 设置后返回，但不适用于开关
    if (sender) {
        [self.navigationController popViewControllerAnimated:YES];
    } else {
        self.firstInputView.inputValue = self.currentValue;
    }
}

- (void)getterButtonPressed:(id)sender {
    [self.fieldEditorView endEditing:YES];

    [self exploreObjectOrPopViewController:self.currentValue];
}

- (void)argumentInputViewValueDidChange:(FLEXArgumentInputView *)argumentInputView {
    if ([argumentInputView isKindOfClass:[FLEXArgumentInputSwitchView class]]) {
        [self actionButtonPressed:nil];
    }
}

#pragma mark - 私有方法

- (void)registerAuxiliaryInfo {
    // 这是Reflex在运行时将Swift结构体字段名称引入编辑器的方式
    NSDictionary<NSString *, NSArray *> *labels = [self.auxiliaryInfoProvider
        auxiliaryInfoForKey:FLEXAuxiliarynfoKeyFieldLabels
    ];
    
    for (NSString *type in labels) {
        [FLEXArgumentInputViewFactory registerFieldNames:labels[type] forTypeEncoding:type];
    }
}

- (id)currentValue {
    if (self.property) {
        return [self.property getValue:self.target];
    } else {
        return [self.ivar getValue:self.target];
    }
}

- (id<FLEXMetadataAuxiliaryInfo>)auxiliaryInfoProvider {
    return self.ivar ?: self.property;
}

- (const FLEXTypeEncoding *)typeEncoding {
    if (self.property) {
        return self.property.attributes.typeEncoding.UTF8String;
    } else {
        return self.ivar.typeEncoding.UTF8String;
    }
}

- (NSString *)fieldDescription {
    if (self.property) {
        return self.property.fullDescription;
    } else {
        return self.ivar.description;
    }
}

@end
