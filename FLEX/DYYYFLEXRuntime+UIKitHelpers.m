//
//  FLEXRuntime+UIKitHelpers.m
//  FLEX
//
//  由 Tanner Bennett 创建于 12/16/19.
//  版权所有 © 2020 FLEX Team. 保留所有权利。
//

#import "DYYYFLEXRuntime+UIKitHelpers.h"
#import "DYYYFLEXRuntimeUtility.h"
#import "DYYYFLEXPropertyAttributes.h"
#import "DYYYFLEXArgumentInputViewFactory.h"
#import "DYYYFLEXObjectExplorerFactory.h"
#import "DYYYFLEXFieldEditorViewController.h"
#import "DYYYFLEXMethodCallingViewController.h"
#import "DYYYFLEXObjectListViewController.h"
#import "DYYYFLEXTableView.h"
#import "DYYYFLEXUtility.h"
#import "NSArray+FLEX.h"
#import "NSString+FLEX.h"

#define FLEXObjectExplorerDefaultsImpl \
- (DYYYFLEXObjectExplorerDefaults *)defaults { \
    return self.tag; \
} \
 \
- (void)setDefaults:(DYYYFLEXObjectExplorerDefaults *)defaults { \
    self.tag = defaults; \
}

#pragma mark DYYYFLEXProperty
@implementation DYYYFLEXProperty (UIKitHelpers)
FLEXObjectExplorerDefaultsImpl

/// 决定是使用 potentialTarget 还是 [potentialTarget class] 来获取或设置属性
- (id)appropriateTargetForPropertyType:(id)potentialTarget {
    if (!object_isClass(potentialTarget)) {
        if (self.isClassProperty) {
            return [potentialTarget class];
        } else {
            return potentialTarget;
        }
    } else {
        if (self.isClassProperty) {
            return potentialTarget;
        } else {
            // 使用类对象的实例属性
            return nil;
        }
    }
}

- (BOOL)isEditable {
    if (self.attributes.isReadOnly) {
        return self.likelySetterExists;
    }
    
    const FLEXTypeEncoding *typeEncoding = self.attributes.typeEncoding.UTF8String;
    return [DYYYFLEXArgumentInputViewFactory canEditFieldWithTypeEncoding:typeEncoding currentValue:nil];
}

- (BOOL)isCallable {
    return YES;
}

- (id)currentValueWithTarget:(id)object {
    return [self getPotentiallyUnboxedValue:
        [self appropriateTargetForPropertyType:object]
    ];
}

- (id)currentValueBeforeUnboxingWithTarget:(id)object {
    return [self getValue:
        [self appropriateTargetForPropertyType:object]
    ];
}

- (NSString *)previewWithTarget:(id)object {
    if (object_isClass(object) && !self.isClassProperty) {
        return self.attributes.fullDeclaration;
    } else if (self.defaults.wantsDynamicPreviews) {
        return [DYYYFLEXRuntimeUtility
            summaryForObject:[self currentValueWithTarget:object]
        ];
    }
    
    return nil;
}

- (UIViewController *)viewerWithTarget:(id)object {
    id value = [self currentValueWithTarget:object];
    return [DYYYFLEXObjectExplorerFactory explorerViewControllerForObject:value];
}

- (UIViewController *)editorWithTarget:(id)object section:(DYYYFLEXTableViewSection *)section {
    id target = [self appropriateTargetForPropertyType:object];
    return [DYYYFLEXFieldEditorViewController target:target property:self commitHandler:^{
        [section reloadData:YES];
    }];
}

- (UITableViewCellAccessoryType)suggestedAccessoryTypeWithTarget:(id)object {
    id targetForValueCheck = [self appropriateTargetForPropertyType:object];
    if (!targetForValueCheck) {
        // 使用类对象的实例属性
        return UITableViewCellAccessoryNone;
    }

    // 我们使用 .tag 来存储 .isEditable 的缓存值
    // 由 DYYYFLEXObjectExplorer 在 -reloadMetada 中初始化
    if ([self getPotentiallyUnboxedValue:targetForValueCheck]) {
        if (self.defaults.isEditable) {
            // 可编辑的非空值，两者都有
            return UITableViewCellAccessoryDetailDisclosureButton;
        } else {
            // 不可编辑的非空值，只有箭头
            return UITableViewCellAccessoryDisclosureIndicator;
        }
    } else {
        if (self.defaults.isEditable) {
            // 可编辑的空值，只有 (i)
            return UITableViewCellAccessoryDetailButton;
        } else {
            // 不可编辑的空值，两者都没有
            return UITableViewCellAccessoryNone;
        }
    }
}

- (NSString *)reuseIdentifierWithTarget:(id)object { return nil; }

- (NSArray<UIAction *> *)additionalActionsWithTarget:(id)object sender:(UIViewController *)sender __IOS_AVAILABLE(13.0) {
    BOOL returnsObject = self.attributes.typeEncoding.flex_typeIsObjectOrClass;
    BOOL targetNotNil = [self appropriateTargetForPropertyType:object] != nil;
    
    // 对于具有具体类名的属性，提供"浏览属性类"选项
    if (returnsObject) {
        NSMutableArray<UIAction *> *actions = [NSMutableArray new];
        
        // 用于浏览此属性类的操作
        Class propertyClass = self.attributes.typeEncoding.flex_typeClass;
        if (propertyClass) {
            NSString *title = [NSString stringWithFormat:@"浏览 %@", NSStringFromClass(propertyClass)];
            [actions addObject:[UIAction actionWithTitle:title image:nil identifier:nil handler:^(UIAction *action) {
                UIViewController *explorer = [DYYYFLEXObjectExplorerFactory explorerViewControllerForObject:propertyClass];
                [sender.navigationController pushViewController:explorer animated:YES];
            }]];
        }
        
        // 用于浏览对此对象引用的操作
        if (targetNotNil) {
            // 由于属性持有者不是 nil，检查属性值是否为 nil
            id value = [self currentValueBeforeUnboxingWithTarget:object];
            if (value) {
                NSString *title = @"列出所有引用";
                [actions addObject:[UIAction actionWithTitle:title image:nil identifier:nil handler:^(UIAction *action) {
                    UIViewController *list = [DYYYFLEXObjectListViewController
                        objectsWithReferencesToObject:value
                        retained:NO
                    ];
                    [sender.navigationController pushViewController:list animated:YES];
                }]];
            }
        }
        
        return actions;
    }
    
    return nil;
}

- (NSArray<NSString *> *)copiableMetadataWithTarget:(id)object {
    BOOL returnsObject = self.attributes.typeEncoding.flex_typeIsObjectOrClass;
    BOOL targetNotNil = [self appropriateTargetForPropertyType:object] != nil;
    
    NSMutableArray *items = [NSMutableArray arrayWithArray:@[
        @"名称",          self.name ?: @"",
        @"类型",          self.attributes.typeEncoding ?: @"",
        @"声明",          self.fullDescription ?: @"",
    ]];
    
    if (targetNotNil) {
        id value = [self currentValueBeforeUnboxingWithTarget:object];
        [items addObjectsFromArray:@[
            @"值预览",      [self previewWithTarget:object] ?: @"",
            @"值地址",      returnsObject ? [DYYYFLEXUtility addressOfObject:value] : @"",
        ]];
    }
    
    [items addObjectsFromArray:@[
        @"获取器",                    NSStringFromSelector(self.likelyGetter) ?: @"",
        @"设置器",                    self.likelySetterExists ? NSStringFromSelector(self.likelySetter) : @"",
        @"镜像名称",                 self.imageName ?: @"",
        @"属性",                     self.attributes.string ?: @"",
        @"objc_property",             [DYYYFLEXUtility pointerToString:self.objc_property],
        @"objc_property_attribute_t", [DYYYFLEXUtility pointerToString:self.attributes.list],
    ]];
    
    return items;
}

- (NSString *)contextualSubtitleWithTarget:(id)object {
    id target = [self appropriateTargetForPropertyType:object];
    if (target && self.attributes.typeEncoding.flex_typeIsObjectOrClass) {
        return [DYYYFLEXUtility addressOfObject:[self currentValueBeforeUnboxingWithTarget:target]];
    }
    
    return nil;
}

@end


#pragma mark DYYYFLEXIvar
@implementation DYYYFLEXIvar (UIKitHelpers)
FLEXObjectExplorerDefaultsImpl

- (BOOL)isEditable {
    const FLEXTypeEncoding *typeEncoding = self.typeEncoding.UTF8String;
    return [DYYYFLEXArgumentInputViewFactory canEditFieldWithTypeEncoding:typeEncoding currentValue:nil];
}

- (BOOL)isCallable {
    return NO;
}

- (id)currentValueWithTarget:(id)object {
    if (!object_isClass(object)) {
        return [self getPotentiallyUnboxedValue:object];
    }

    return nil;
}

- (NSString *)previewWithTarget:(id)object {
    if (object_isClass(object)) {
        return self.details;
    } else if (self.defaults.wantsDynamicPreviews) {
        return [DYYYFLEXRuntimeUtility
            summaryForObject:[self currentValueWithTarget:object]
        ];
    }
    
    return nil;
}

- (UIViewController *)viewerWithTarget:(id)object {
    NSAssert(!object_isClass(object), @"无法到达的状态：在类对象上查看实例变量");
    id value = [self currentValueWithTarget:object];
    return [DYYYFLEXObjectExplorerFactory explorerViewControllerForObject:value];
}

- (UIViewController *)editorWithTarget:(id)object section:(DYYYFLEXTableViewSection *)section {
    NSAssert(!object_isClass(object), @"无法到达的状态：在类对象上编辑实例变量");
    return [DYYYFLEXFieldEditorViewController target:object ivar:self commitHandler:^{
        [section reloadData:YES];
    }];
}

- (UITableViewCellAccessoryType)suggestedAccessoryTypeWithTarget:(id)object {
    if (object_isClass(object)) {
        return UITableViewCellAccessoryNone;
    }

    // 可以使用 .isEditable，但我们使用 .tag 提高速度，因为它已缓存
    if ([self getPotentiallyUnboxedValue:object]) {
        if (self.defaults.isEditable) {
            // 可编辑的非空值，两者都有
            return UITableViewCellAccessoryDetailDisclosureButton;
        } else {
            // 不可编辑的非空值，只有箭头
            return UITableViewCellAccessoryDisclosureIndicator;
        }
    } else {
        if (self.defaults.isEditable) {
            // 可编辑的空值，只有 (i)
            return UITableViewCellAccessoryDetailButton;
        } else {
            // 不可编辑的空值，两者都没有
            return UITableViewCellAccessoryNone;
        }
    }
}

- (NSString *)reuseIdentifierWithTarget:(id)object { return nil; }

- (NSArray<UIAction *> *)additionalActionsWithTarget:(id)object sender:(UIViewController *)sender __IOS_AVAILABLE(13.0) {
    Class ivarClass = self.typeEncoding.flex_typeClass;
    
    // 对于具有具体类名的属性，提供"浏览属性类"选项
    if (ivarClass) {
        NSString *title = [NSString stringWithFormat:@"浏览 %@", NSStringFromClass(ivarClass)];
        return @[[UIAction actionWithTitle:title image:nil identifier:nil handler:^(UIAction *action) {
            UIViewController *explorer = [DYYYFLEXObjectExplorerFactory explorerViewControllerForObject:ivarClass];
            [sender.navigationController pushViewController:explorer animated:YES];
        }]];
    }
    
    return nil;
}

- (NSArray<NSString *> *)copiableMetadataWithTarget:(id)object {
    BOOL isInstance = !object_isClass(object);
    BOOL returnsObject = self.typeEncoding.flex_typeIsObjectOrClass;
    id value = isInstance ? [self getValue:object] : nil;
    
    NSMutableArray *items = [NSMutableArray arrayWithArray:@[
        @"名称",          self.name ?: @"",
        @"类型",          self.typeEncoding ?: @"",
        @"声明",          self.description ?: @"",
    ]];
    
    if (isInstance) {
        [items addObjectsFromArray:@[
            @"值预览", isInstance ? [self previewWithTarget:object] : @"",
            @"值地址", returnsObject ? [DYYYFLEXUtility addressOfObject:value] : @"",
        ]];
    }
    
    [items addObjectsFromArray:@[
        @"大小",          @(self.size).stringValue,
        @"偏移量",        @(self.offset).stringValue,
        @"objc_ivar",     [DYYYFLEXUtility pointerToString:self.objc_ivar],
    ]];
    
    return items;
}

- (NSString *)contextualSubtitleWithTarget:(id)object {
    if (!object_isClass(object) && self.typeEncoding.flex_typeIsObjectOrClass) {
        return [DYYYFLEXUtility addressOfObject:[self getValue:object]];
    }
    
    return nil;
}

@end


#pragma mark DYYYFLEXMethod
@implementation DYYYFLEXMethodBase (UIKitHelpers)
FLEXObjectExplorerDefaultsImpl

- (BOOL)isEditable {
    return NO;
}

- (BOOL)isCallable {
    return NO;
}

- (id)currentValueWithTarget:(id)object {
    // 方法不能被"编辑"，也没有"值"
    return nil;
}

- (NSString *)previewWithTarget:(id)object {
    return [self.selectorString stringByAppendingFormat:@"  —  %@", self.typeEncoding];
}

- (UIViewController *)viewerWithTarget:(id)object {
    // 我们不允许调用 DYYYFLEXMethodBase 方法
    @throw NSInternalInconsistencyException;
    return nil;
}

- (UIViewController *)editorWithTarget:(id)object section:(DYYYFLEXTableViewSection *)section {
    // 方法不能被编辑
    @throw NSInternalInconsistencyException;
    return nil;
}

- (UITableViewCellAccessoryType)suggestedAccessoryTypeWithTarget:(id)object {
    // 我们不应该使用任何 DYYYFLEXMethodBase 对象来做这个
    @throw NSInternalInconsistencyException;
    return UITableViewCellAccessoryNone;
}

- (NSString *)reuseIdentifierWithTarget:(id)object { return nil; }

- (NSArray<UIAction *> *)additionalActionsWithTarget:(id)object sender:(UIViewController *)sender __IOS_AVAILABLE(13.0) {
    return nil;
}

- (NSArray<NSString *> *)copiableMetadataWithTarget:(id)object {
    return @[
        @"选择器",      self.name ?: @"",
        @"类型编码", self.typeEncoding ?: @"",
        @"声明",   self.description ?: @"",
    ];
}

- (NSString *)contextualSubtitleWithTarget:(id)object {
    return nil;
}

@end

@implementation DYYYFLEXMethod (UIKitHelpers)

- (BOOL)isCallable {
    return self.signature != nil;
}

- (UIViewController *)viewerWithTarget:(id)object {
    object = self.isInstanceMethod ? object : (object_isClass(object) ? object : [object class]);
    return [DYYYFLEXMethodCallingViewController target:object method:self];
}

- (UITableViewCellAccessoryType)suggestedAccessoryTypeWithTarget:(id)object {
    if (self.isInstanceMethod) {
        if (object_isClass(object)) {
            // 从类获取实例方法，不能调用
            return UITableViewCellAccessoryNone;
        } else {
            // 从实例获取实例方法，可以调用
            return UITableViewCellAccessoryDisclosureIndicator;
        }
    } else {
        return UITableViewCellAccessoryDisclosureIndicator;
    }
}

- (NSArray<NSString *> *)copiableMetadataWithTarget:(id)object {
    return [[super copiableMetadataWithTarget:object] arrayByAddingObjectsFromArray:@[
        @"NSMethodSignature *", [DYYYFLEXUtility addressOfObject:self.signature],
        @"签名字符串",    self.signatureString ?: @"",
        @"参数数量", @(self.numberOfArguments).stringValue,
        @"返回类型",         @(self.returnType ?: ""),
        @"返回大小",         @(self.returnSize).stringValue,
        @"objc_method",       [DYYYFLEXUtility pointerToString:self.objc_method],
    ]];
}

@end


#pragma mark DYYYFLEXProtocol
@implementation DYYYFLEXProtocol (UIKitHelpers)
FLEXObjectExplorerDefaultsImpl

- (BOOL)isEditable {
    return NO;
}

- (BOOL)isCallable {
    return NO;
}

- (id)currentValueWithTarget:(id)object {
    return nil;
}

- (NSString *)previewWithTarget:(id)object {
    return nil;
}

- (UIViewController *)viewerWithTarget:(id)object {
    return [DYYYFLEXObjectExplorerFactory explorerViewControllerForObject:self];
}

- (UIViewController *)editorWithTarget:(id)object section:(DYYYFLEXTableViewSection *)section {
    // 协议不能被编辑
    @throw NSInternalInconsistencyException;
    return nil;
}

- (UITableViewCellAccessoryType)suggestedAccessoryTypeWithTarget:(id)object {
    return UITableViewCellAccessoryDisclosureIndicator;
}

- (NSString *)reuseIdentifierWithTarget:(id)object { return nil; }

- (NSArray<UIAction *> *)additionalActionsWithTarget:(id)object sender:(UIViewController *)sender __IOS_AVAILABLE(13.0) {
    return nil;
}

- (NSArray<NSString *> *)copiableMetadataWithTarget:(id)object {
    NSArray<NSString *> *conformanceNames = [self.protocols valueForKeyPath:@"name"];
    NSString *conformances = [conformanceNames componentsJoinedByString:@"\n"];
    return @[
        @"名称",         self.name ?: @"",
        @"遵循协议", conformances ?: @"",
    ];
}

- (NSString *)contextualSubtitleWithTarget:(id)object {
    return nil;
}

@end


#pragma mark DYYYFLEXStaticMetadata
@interface DYYYFLEXStaticMetadata () {
    @protected
    NSString *_name;
}
@property (nonatomic) FLEXTableViewCellReuseIdentifier reuse;
@property (nonatomic) NSString *subtitle;
@property (nonatomic) id metadata;
@end

@interface DYYYFLEXStaticMetadata_Class : DYYYFLEXStaticMetadata
+ (instancetype)withClass:(Class)cls;
@end

@implementation DYYYFLEXStaticMetadata
@synthesize name = _name;
@synthesize tag = _tag;

FLEXObjectExplorerDefaultsImpl

+ (NSArray<DYYYFLEXStaticMetadata *> *)classHierarchy:(NSArray<Class> *)classes {
    return [classes flex_mapped:^id(Class cls, NSUInteger idx) {
        return [DYYYFLEXStaticMetadata_Class withClass:cls];
    }];
}

+ (instancetype)style:(FLEXStaticMetadataRowStyle)style title:(NSString *)title string:(NSString *)string {
    return [[self alloc] initWithStyle:style title:title subtitle:string];
}

+ (instancetype)style:(FLEXStaticMetadataRowStyle)style title:(NSString *)title number:(NSNumber *)number {
    return [[self alloc] initWithStyle:style title:title subtitle:number.stringValue];
}

- (id)initWithStyle:(FLEXStaticMetadataRowStyle)style title:(NSString *)title subtitle:(NSString *)subtitle  {
    self = [super init];
    if (self) {
        if (style == FLEXStaticMetadataRowStyleKeyValue) {
            _reuse = kFLEXKeyValueCell;
        } else {
            _reuse = kFLEXMultilineDetailCell;
        }

        _name = title;
        _subtitle = subtitle;
    }

    return self;
}

- (NSString *)description {
    return self.name;
}

- (NSString *)reuseIdentifierWithTarget:(id)object {
    return self.reuse;
}

- (BOOL)isEditable {
    return NO;
}

- (BOOL)isCallable {
    return NO;
}

- (id)currentValueWithTarget:(id)object {
    return nil;
}

- (NSString *)previewWithTarget:(id)object {
    return self.subtitle;
}

- (UIViewController *)viewerWithTarget:(id)object {
    return nil;
}

- (UIViewController *)editorWithTarget:(id)object section:(DYYYFLEXTableViewSection *)section {
    // 静态元数据不能被编辑
    @throw NSInternalInconsistencyException;
    return nil;
}

- (UITableViewCellAccessoryType)suggestedAccessoryTypeWithTarget:(id)object {
    return UITableViewCellAccessoryNone;
}

- (NSArray<UIAction *> *)additionalActionsWithTarget:(id)object sender:(UIViewController *)sender __IOS_AVAILABLE(13.0) {
    return nil;
}

- (NSArray<NSString *> *)copiableMetadataWithTarget:(id)object {
    return @[self.name, self.subtitle];
}

- (NSString *)contextualSubtitleWithTarget:(id)object {
    return nil;
}

@end


#pragma mark DYYYFLEXStaticMetadata_Class
@implementation DYYYFLEXStaticMetadata_Class

+ (instancetype)withClass:(Class)cls {
    NSParameterAssert(cls);
    
    DYYYFLEXStaticMetadata_Class *metadata = [self new];
    metadata.metadata = cls;
    metadata->_name = NSStringFromClass(cls);
    metadata.reuse = kFLEXDefaultCell;
    return metadata;
}

- (id)initWithStyle:(FLEXStaticMetadataRowStyle)style title:(NSString *)title subtitle:(NSString *)subtitle {
    @throw NSInternalInconsistencyException;
    return nil;
}

- (UIViewController *)viewerWithTarget:(id)object {
    return [DYYYFLEXObjectExplorerFactory explorerViewControllerForObject:self.metadata];
}

- (UITableViewCellAccessoryType)suggestedAccessoryTypeWithTarget:(id)object {
    return UITableViewCellAccessoryDisclosureIndicator;
}

- (NSArray<NSString *> *)copiableMetadataWithTarget:(id)object {
    return @[
        @"类名", self.name,
        @"类", [DYYYFLEXUtility addressOfObject:self.metadata]
    ];
}

- (NSString *)contextualSubtitleWithTarget:(id)object {
    return [DYYYFLEXUtility addressOfObject:self.metadata];
}

@end
