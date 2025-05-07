// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXArgumentInputStructView.m
//  Flipboard
//
//  Created by Ryan Olson on 6/16/14.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

#import "FLEXArgumentInputStructView.h"
#import "FLEXArgumentInputViewFactory.h"
#import "FLEXRuntimeUtility.h"
#import "FLEXTypeEncodingParser.h"

@interface FLEXArgumentInputStructView ()

@property (nonatomic) NSArray<FLEXArgumentInputView *> *argumentInputViews;

@end

@implementation FLEXArgumentInputStructView

static NSMutableDictionary<NSString *, NSArray<NSString *> *> *structFieldNameRegistrar = nil;
+ (void)initialize {
    if (self == [FLEXArgumentInputStructView class]) {
        structFieldNameRegistrar = [NSMutableDictionary new];
        [self registerDefaultFieldNames];
    }
}

+ (void)registerDefaultFieldNames {
    NSDictionary *defaults = @{
        @(@encode(CGRect)):             @[@"CGPoint 原点", @"CGSize 大小"],
        @(@encode(CGPoint)):            @[@"CGFloat x坐标", @"CGFloat y坐标"],
        @(@encode(CGSize)):             @[@"CGFloat 宽度", @"CGFloat 高度"],
        @(@encode(CGVector)):           @[@"CGFloat dx", @"CGFloat dy"],
        @(@encode(UIEdgeInsets)):       @[@"CGFloat 顶部", @"CGFloat 左侧", @"CGFloat 底部", @"CGFloat 右侧"],
        @(@encode(UIOffset)):           @[@"CGFloat 水平", @"CGFloat 垂直"],
        @(@encode(NSRange)):            @[@"NSUInteger 位置", @"NSUInteger 长度"],
        @(@encode(CATransform3D)):      @[@"CGFloat m11", @"CGFloat m12", @"CGFloat m13", @"CGFloat m14",
                                          @"CGFloat m21", @"CGFloat m22", @"CGFloat m23", @"CGFloat m24",
                                          @"CGFloat m31", @"CGFloat m32", @"CGFloat m33", @"CGFloat m34",
                                          @"CGFloat m41", @"CGFloat m42", @"CGFloat m43", @"CGFloat m44"],
        @(@encode(CGAffineTransform)):  @[@"CGFloat a", @"CGFloat b",
                                          @"CGFloat c", @"CGFloat d",
                                          @"CGFloat tx", @"CGFloat ty"],
    };
    
    [structFieldNameRegistrar addEntriesFromDictionary:defaults];
    
    if (@available(iOS 11.0, *)) {
        structFieldNameRegistrar[@(@encode(NSDirectionalEdgeInsets))] = @[
            @"CGFloat 顶部", @"CGFloat 前缘", @"CGFloat 底部", @"CGFloat 后缘"
        ];
    }
}

- (instancetype)initWithArgumentTypeEncoding:(const char *)typeEncoding {
    self = [super initWithArgumentTypeEncoding:typeEncoding];
    if (self) {
        NSMutableArray<FLEXArgumentInputView *> *inputViews = [NSMutableArray new];
        NSArray<NSString *> *customTitles = [[self class] customFieldTitlesForTypeEncoding:typeEncoding];
        [FLEXRuntimeUtility enumerateTypesInStructEncoding:typeEncoding usingBlock:^(NSString *structName,
                                                                                     const char *fieldTypeEncoding,
                                                                                     NSString *prettyTypeEncoding,
                                                                                     NSUInteger fieldIndex,
                                                                                     NSUInteger fieldOffset) {
            
            FLEXArgumentInputView *inputView = [FLEXArgumentInputViewFactory argumentInputViewForTypeEncoding:fieldTypeEncoding];
            inputView.targetSize = FLEXArgumentInputViewSizeSmall; // 设置目标尺寸为小
            
            if (fieldIndex < customTitles.count) {
                inputView.title = customTitles[fieldIndex]; // 使用自定义标题
            } else {
                // 使用默认标题格式
                inputView.title = [NSString stringWithFormat:@"%@ field %lu (%@)",
                    structName, (unsigned long)fieldIndex, prettyTypeEncoding
                ];
            }

            [inputViews addObject:inputView];
            [self addSubview:inputView];
        }];
        self.argumentInputViews = inputViews;
    }
    return self;
}


#pragma mark - 父类重写

- (void)setBackgroundColor:(UIColor *)backgroundColor {
    [super setBackgroundColor:backgroundColor];
    for (FLEXArgumentInputView *inputView in self.argumentInputViews) {
        inputView.backgroundColor = backgroundColor;
    }
}

- (void)setInputValue:(id)inputValue {
    if ([inputValue isKindOfClass:[NSValue class]]) {
        const char *structTypeEncoding = [inputValue objCType];
        if (strcmp(self.typeEncoding.UTF8String, structTypeEncoding) == 0) {
            NSUInteger valueSize = 0;
            
            if (FLEXGetSizeAndAlignment(structTypeEncoding, &valueSize, NULL)) {
                void *unboxedValue = malloc(valueSize); // 分配内存
                [inputValue getValue:unboxedValue]; // 获取值
                [FLEXRuntimeUtility enumerateTypesInStructEncoding:structTypeEncoding usingBlock:^(NSString *structName,
                                                                                                   const char *fieldTypeEncoding,
                                                                                                   NSString *prettyTypeEncoding,
                                                                                                   NSUInteger fieldIndex,
                                                                                                   NSUInteger fieldOffset) {
                    
                    void *fieldPointer = unboxedValue + fieldOffset; // 获取字段指针
                    FLEXArgumentInputView *inputView = self.argumentInputViews[fieldIndex];
                    
                    // 处理对象或类类型
                    if (fieldTypeEncoding[0] == FLEXTypeEncodingObjcObject || fieldTypeEncoding[0] == FLEXTypeEncodingObjcClass) {
                        inputView.inputValue = (__bridge id)fieldPointer;
                    } else {
                        // 处理基本类型
                        NSValue *boxedField = [FLEXRuntimeUtility valueForPrimitivePointer:fieldPointer objCType:fieldTypeEncoding];
                        inputView.inputValue = boxedField;
                    }
                }];
                free(unboxedValue); // 释放内存
            }
        }
    }
}

- (id)inputValue {
    NSValue *boxedStruct = nil;
    const char *structTypeEncoding = self.typeEncoding.UTF8String;
    NSUInteger structSize = 0;
    
    if (FLEXGetSizeAndAlignment(structTypeEncoding, &structSize, NULL)) {
        void *unboxedStruct = malloc(structSize); // 分配内存
        [FLEXRuntimeUtility enumerateTypesInStructEncoding:structTypeEncoding usingBlock:^(NSString *structName,
                                                                                           const char *fieldTypeEncoding,
                                                                                           NSString *prettyTypeEncoding,
                                                                                           NSUInteger fieldIndex,
                                                                                           NSUInteger fieldOffset) {
            
            void *fieldPointer = unboxedStruct + fieldOffset; // 获取字段指针
            FLEXArgumentInputView *inputView = self.argumentInputViews[fieldIndex];
            
            if (fieldTypeEncoding[0] == FLEXTypeEncodingObjcObject || fieldTypeEncoding[0] == FLEXTypeEncodingObjcClass) {
                // 对象字段
                memcpy(fieldPointer, (__bridge void *)inputView.inputValue, sizeof(id));
            } else {
                // 包装的基本类型/结构体字段
                id inputValue = inputView.inputValue;
                if ([inputValue isKindOfClass:[NSValue class]] && strcmp([inputValue objCType], fieldTypeEncoding) == 0) {
                    [inputValue getValue:fieldPointer]; // 获取值
                }
            }
        }];
        
        boxedStruct = [NSValue value:unboxedStruct withObjCType:structTypeEncoding]; // 包装结构体
        free(unboxedStruct); // 释放内存
    }
    
    return boxedStruct;
}

- (BOOL)inputViewIsFirstResponder {
    BOOL isFirstResponder = NO;
    for (FLEXArgumentInputView *inputView in self.argumentInputViews) {
        if ([inputView inputViewIsFirstResponder]) {
            isFirstResponder = YES; // 如果任何子视图是第一响应者，则返回 YES
            break;
        }
    }
    return isFirstResponder;
}


#pragma mark - 布局和尺寸

- (void)layoutSubviews {
    [super layoutSubviews];
    
    CGFloat runningOriginY = self.topInputFieldVerticalLayoutGuide; // 获取顶部布局参考线
    
    for (FLEXArgumentInputView *inputView in self.argumentInputViews) {
        CGSize inputFitSize = [inputView sizeThatFits:self.bounds.size]; // 计算适合的尺寸
        inputView.frame = CGRectMake(0, runningOriginY, inputFitSize.width, inputFitSize.height); // 设置 frame
        runningOriginY = CGRectGetMaxY(inputView.frame) + [[self class] verticalPaddingBetweenFields]; // 更新 Y 坐标
    }
}

+ (CGFloat)verticalPaddingBetweenFields {
    // 字段之间的垂直间距
    return 10.0;
}

- (CGSize)sizeThatFits:(CGSize)size {
    CGSize fitSize = [super sizeThatFits:size]; // 获取父类计算的尺寸
    
    CGSize constrainSize = CGSizeMake(size.width, CGFLOAT_MAX); // 约束尺寸
    CGFloat height = fitSize.height; // 初始高度
    
    // 累加所有子视图的高度和间距
    for (FLEXArgumentInputView *inputView in self.argumentInputViews) {
        height += [inputView sizeThatFits:constrainSize].height;
        height += [[self class] verticalPaddingBetweenFields];
    }
    
    return CGSizeMake(fitSize.width, height); // 返回最终计算的尺寸
}


#pragma mark - 类助手方法

+ (BOOL)supportsObjCType:(const char *)type withCurrentValue:(id)value {
    NSParameterAssert(type); // 确保类型不为空
    // 检查类型是否为结构体类型，并能获取其大小和对齐方式
    if (type[0] == FLEXTypeEncodingStructBegin) {
        return FLEXGetSizeAndAlignment(type, nil, nil);
    }

    return NO;
}

+ (void)registerFieldNames:(NSArray<NSString *> *)names forTypeEncoding:(NSString *)typeEncoding {
    NSParameterAssert(typeEncoding); NSParameterAssert(names); // 确保参数不为空
    structFieldNameRegistrar[typeEncoding] = names; // 注册字段名称
}

+ (NSArray<NSString *> *)customFieldTitlesForTypeEncoding:(const char *)typeEncoding {
    // 获取指定类型的自定义字段标题
    return structFieldNameRegistrar[@(typeEncoding)];
}

@end
