// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXRuntime+UIKitHelpers.m
//  FLEX
//
//  由 Tanner Bennett 创建于 12/16/19.
//  版权所有 © 2020 FLEX Team。保留所有权利。

#import "FLEXRuntime+UIKitHelpers.h"
#import "FLEXRuntimeUtility.h"
#import "FLEXPropertyAttributes.h"
#import "FLEXArgumentInputViewFactory.h"
#import "FLEXObjectExplorerFactory.h"
#import "FLEXFieldEditorViewController.h"
#import "FLEXMethodCallingViewController.h"
#import "FLEXObjectListViewController.h"
#import "FLEXTableView.h"
#import "FLEXUtility.h"
#import "NSArray+FLEX.h"
#import "NSString+FLEX.h"

#define FLEXObjectExplorerDefaultsImpl \
- (FLEXObjectExplorerDefaults *)defaults { \
    return self.tag; \
} \
 \
- (void)setDefaults:(FLEXObjectExplorerDefaults *)defaults { \
    self.tag = defaults; \
}

#pragma mark - FLEXProperty
@implementation FLEXProperty (UIKitHelpers)
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
            // 带有类对象的实例属性
            return nil;
        }
    }
}

- (BOOL)isEditable {
    if (self.attributes.isReadOnly) {
        return self.likelySetterExists;
    }
    
    const FLEXTypeEncoding *typeEncoding = self.attributes.typeEncoding.UTF8String;
    return [FLEXArgumentInputViewFactory canEditFieldWithTypeEncoding:typeEncoding currentValue:nil];
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
        return [FLEXRuntimeUtility
            summaryForObject:[self currentValueWithTarget:object]
        ];
    }
    
    return nil;
}

- (UIViewController *)viewerWithTarget:(id)object {
    id value = [self currentValueWithTarget:object];
    return [FLEXObjectExplorerFactory explorerViewControllerForObject:value];
}

- (UIViewController *)editorWithTarget:(id)object section:(FLEXTableViewSection *)section {
    id target = [self appropriateTargetForPropertyType:object];
    return [FLEXFieldEditorViewController target:target property:self commitHandler:^{
        [section reloadData:YES];
    }];
}

- (UITableViewCellAccessoryType)suggestedAccessoryTypeWithTarget:(id)object {
    id targetForValueCheck = [self appropriateTargetForPropertyType:object];
    if (!targetForValueCheck) {
        // 具有类对象的实例属性
        return UITableViewCellAccessoryNone;
    }

    // 我们使用 .tag 来存储 .isEditable 的缓存值
    // 该值由 FLEXObjectExplorer 在 -reloadMetada 中初始化
    if ([self getPotentiallyUnboxedValue:targetForValueCheck]) {
        if (self.defaults.isEditable) {
            // 可编辑的非 nil 值，两者都有
            return UITableViewCellAccessoryDetailDisclosureButton;
        } else {
            // 不可编辑的非 nil 值，仅雪佛龙箭头
            return UITableViewCellAccessoryDisclosureIndicator;
        }
    } else {
        if (self.defaults.isEditable) {
            // 可编辑的 nil 值，仅 (i)
            return UITableViewCellAccessoryDetailButton;
        } else {
            // 不可编辑的 nil 值，两者都没有
            return UITableViewCellAccessoryNone;
        }
    }
}

- (NSString *)reuseIdentifierWithTarget:(id)object { return nil; }

- (NSArray<UIAction *> *)additionalActionsWithTarget:(id)object sender:(UIViewController *)sender __IOS_AVAILABLE(13.0) {
    BOOL returnsObject = self.attributes.typeEncoding.flex_typeIsObjectOrClass;
    BOOL targetNotNil = [self appropriateTargetForPropertyType:object] != nil;
    
    // 针对具有具体类名的属性显示“浏览属性类”
    if (returnsObject) {
        NSMutableArray<UIAction *> *actions = [NSMutableArray new];
        
        // 浏览此属性的类的操作
        Class propertyClass = self.attributes.typeEncoding.flex_typeClass;
        if (propertyClass) {
            NSString *title = [NSString stringWithFormat:@"浏览 %@", NSStringFromClass(propertyClass)];
            [actions addObject:[UIAction actionWithTitle:title image:nil identifier:nil handler:^(UIAction *action) {
                UIViewController *explorer = [FLEXObjectExplorerFactory explorerViewControllerForObject:propertyClass];
                [sender.navigationController pushViewController:explorer animated:YES];
            }]];
        }
        
        // 浏览对此对象的引用的操作
        if (targetNotNil) {
            // 由于属性持有者不为 nil，检查属性值是否为 nil
            id value = [self currentValueBeforeUnboxingWithTarget:object];
            if (value) {
                NSString *title = @"列出所有引用";
                [actions addObject:[UIAction actionWithTitle:title image:nil identifier:nil handler:^(UIAction *action) {
                    UIViewController *list = [FLEXObjectListViewController
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
        @"Name",                      self.name ?: @"",
        @"Type",                      self.attributes.typeEncoding ?: @"",
        @"Declaration",               self.fullDescription ?: @"",
    ]];
    
    if (targetNotNil) {
        id value = [self currentValueBeforeUnboxingWithTarget:object];
        [items addObjectsFromArray:@[
            @"Value Preview",         [self previewWithTarget:object] ?: @"",
            @"Value Address",         returnsObject ? [FLEXUtility addressOfObject:value] : @"",
        ]];
    }
    
    [items addObjectsFromArray:@[
        @"Getter",                    NSStringFromSelector(self.likelyGetter) ?: @"",
        @"Setter",                    self.likelySetterExists ? NSStringFromSelector(self.likelySetter) : @"",
        @"Image Name",                self.imageName ?: @"",
        @"Attributes",                self.attributes.string ?: @"",
        @"objc_property",             [FLEXUtility pointerToString:self.objc_property],
        @"objc_property_attribute_t", [FLEXUtility pointerToString:self.attributes.list],
    ]];
    
    return items;
}

- (NSString *)contextualSubtitleWithTarget:(id)object {
    id target = [self appropriateTargetForPropertyType:object];
    if (target && self.attributes.typeEncoding.flex_typeIsObjectOrClass) {
        return [FLEXUtility addressOfObject:[self currentValueBeforeUnboxingWithTarget:target]];
    }
    
    return nil;
}

@end


#pragma mark - FLEXIvar
@implementation FLEXIvar (UIKitHelpers)
FLEXObjectExplorerDefaultsImpl

- (BOOL)isEditable {
    const FLEXTypeEncoding *typeEncoding = self.typeEncoding.UTF8String;
    return [FLEXArgumentInputViewFactory canEditFieldWithTypeEncoding:typeEncoding currentValue:nil];
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
        return [FLEXRuntimeUtility
            summaryForObject:[self currentValueWithTarget:object]
        ];
    }
    
    return nil;
}

- (UIViewController *)viewerWithTarget:(id)object {
    NSAssert(!object_isClass(object), @"无法到达的状态：在类对象上查看 ivar");
    id value = [self currentValueWithTarget:object];
    return [FLEXObjectExplorerFactory explorerViewControllerForObject:value];
}

- (UIViewController *)editorWithTarget:(id)object section:(FLEXTableViewSection *)section {
    NSAssert(!object_isClass(object), @"无法到达的状态：在类对象上编辑 ivar");
    return [FLEXFieldEditorViewController target:object ivar:self commitHandler:^{
        [section reloadData:YES];
    }];
}

- (UITableViewCellAccessoryType)suggestedAccessoryTypeWithTarget:(id)object {
    if (object_isClass(object)) {
        return UITableViewCellAccessoryNone;
    }

    // 这里可以使用 .isEditable，但为了速度我们使用 .tag，因为它被缓存了
    if ([self getPotentiallyUnboxedValue:object]) {
        if (self.defaults.isEditable) {
            // 可编辑的非 nil 值，两者都有
            return UITableViewCellAccessoryDetailDisclosureButton;
        } else {
            // 不可编辑的非 nil 值，仅雪佛龙箭头
            return UITableViewCellAccessoryDisclosureIndicator;
        }
    } else {
        if (self.defaults.isEditable) {
            // 可编辑的 nil 值，仅 (i)
            return UITableViewCellAccessoryDetailButton;
        } else {
            // 不可编辑的 nil 值，两者都没有
            return UITableViewCellAccessoryNone;
        }
    }
}

- (NSString *)reuseIdentifierWithTarget:(id)object { return nil; }

- (NSArray<UIAction *> *)additionalActionsWithTarget:(id)object sender:(UIViewController *)sender __IOS_AVAILABLE(13.0) {
    Class ivarClass = self.typeEncoding.flex_typeClass;
    
    // 针对具有具体类名的属性显示“浏览属性类”
    if (ivarClass) {
        NSString *title = [NSString stringWithFormat:@"浏览 %@", NSStringFromClass(ivarClass)];
        return @[[UIAction actionWithTitle:title image:nil identifier:nil handler:^(UIAction *action) {
            UIViewController *explorer = [FLEXObjectExplorerFactory explorerViewControllerForObject:ivarClass];
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
        @"Name",          self.name ?: @"",
        @"Type",          self.typeEncoding ?: @"",
        @"Declaration",   self.description ?: @"",
    ]];
    
    if (isInstance) {
        [items addObjectsFromArray:@[
            @"Value Preview", isInstance ? [self previewWithTarget:object] : @"",
            @"Value Address", returnsObject ? [FLEXUtility addressOfObject:value] : @"",
        ]];
    }
    
    [items addObjectsFromArray:@[
        @"Size",          @(self.size).stringValue,
        @"Offset",        @(self.offset).stringValue,
        @"objc_ivar",     [FLEXUtility pointerToString:self.objc_ivar],
    ]];
    
    return items;
}

- (NSString *)contextualSubtitleWithTarget:(id)object {
    if (!object_isClass(object) && self.typeEncoding.flex_typeIsObjectOrClass) {
        return [FLEXUtility addressOfObject:[self getValue:object]];
    }
    
    return nil;
}

@end


#pragma mark - FLEXMethod
@implementation FLEXMethodBase (UIKitHelpers)
FLEXObjectExplorerDefaultsImpl

- (BOOL)isEditable {
    return NO;
}

- (BOOL)isCallable {
    return NO;
}

- (id)currentValueWithTarget:(id)object {
    // 方法不能被“编辑”，也没有“值”
    return nil;
}

- (NSString *)previewWithTarget:(id)object {
    return [self.selectorString stringByAppendingFormat:@"  —  %@", self.typeEncoding];
}

- (UIViewController *)viewerWithTarget:(id)object {
    // 我们不允许调用 FLEXMethodBase 方法
    @throw NSInternalInconsistencyException;
    return nil;
}

- (UIViewController *)editorWithTarget:(id)object section:(FLEXTableViewSection *)section {
    // 方法不能被编辑
    @throw NSInternalInconsistencyException;
    return nil;
}

- (UITableViewCellAccessoryType)suggestedAccessoryTypeWithTarget:(id)object {
    // 我们不应该为此使用任何 FLEXMethodBase 对象
    @throw NSInternalInconsistencyException;
    return UITableViewCellAccessoryNone;
}

- (NSString *)reuseIdentifierWithTarget:(id)object { return nil; }

- (NSArray<UIAction *> *)additionalActionsWithTarget:(id)object sender:(UIViewController *)sender __IOS_AVAILABLE(13.0) {
    return nil;
}

- (NSArray<NSString *> *)copiableMetadataWithTarget:(id)object {
    return @[
        @"Selector",      self.name ?: @"",
        @"Type Encoding", self.typeEncoding ?: @"",
        @"Declaration",   self.description ?: @"",
    ];
}

- (NSString *)contextualSubtitleWithTarget:(id)object {
    return nil;
}

@end

@implementation FLEXMethod (UIKitHelpers)

- (BOOL)isCallable {
    return self.signature != nil;
}

- (UIViewController *)viewerWithTarget:(id)object {
    object = self.isInstanceMethod ? object : (object_isClass(object) ? object : [object class]);
    return [FLEXMethodCallingViewController target:object method:self];
}

- (UITableViewCellAccessoryType)suggestedAccessoryTypeWithTarget:(id)object {
    if (self.isInstanceMethod) {
        if (object_isClass(object)) {
            // 来自类的实例方法，无法调用
            return UITableViewCellAccessoryNone;
        } else {
            // 来自实例的实例方法，可以调用
            return UITableViewCellAccessoryDisclosureIndicator;
        }
    } else {
        return UITableViewCellAccessoryDisclosureIndicator;
    }
}

- (NSArray<NSString *> *)copiableMetadataWithTarget:(id)object {
    return [[super copiableMetadataWithTarget:object] arrayByAddingObjectsFromArray:@[
        @"NSMethodSignature *", [FLEXUtility addressOfObject:self.signature],
        @"Signature String",    self.signatureString ?: @"",
        @"Number of Arguments", @(self.numberOfArguments).stringValue,
        @"Return Type",         @(self.returnType ?: ""),
        @"Return Size",         @(self.returnSize).stringValue,
        @"objc_method",       [FLEXUtility pointerToString:self.objc_method],
    ]];
}

@end


#pragma mark - FLEXProtocol
@implementation FLEXProtocol (UIKitHelpers)
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
    return [FLEXObjectExplorerFactory explorerViewControllerForObject:self];
}

- (UIViewController *)editorWithTarget:(id)object section:(FLEXTableViewSection *)section {
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
        @"Name",         self.name ?: @"",
        @"Conformances", conformances ?: @"",
    ];
}

- (NSString *)contextualSubtitleWithTarget:(id)object {
    return nil;
}

@end


#pragma mark - FLEXStaticMetadata
@interface FLEXStaticMetadata () {
    @protected
    NSString *_name;
}
@property (nonatomic) FLEXTableViewCellReuseIdentifier reuse;
@property (nonatomic) NSString *subtitle;
@property (nonatomic) id metadata;
@end

@interface FLEXStaticMetadata_Class : FLEXStaticMetadata
+ (instancetype)withClass:(Class)cls;
@end

@implementation FLEXStaticMetadata
@synthesize name = _name;
@synthesize tag = _tag;

FLEXObjectExplorerDefaultsImpl

+ (NSArray<FLEXStaticMetadata *> *)classHierarchy:(NSArray<Class> *)classes {
    return [classes flex_mapped:^id(Class cls, NSUInteger idx) {
        return [FLEXStaticMetadata_Class withClass:cls];
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

- (UIViewController *)editorWithTarget:(id)object section:(FLEXTableViewSection *)section {
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


#pragma mark - FLEXStaticMetadata_Class
@implementation FLEXStaticMetadata_Class

+ (instancetype)withClass:(Class)cls {
    NSParameterAssert(cls);
    
    FLEXStaticMetadata_Class *metadata = [self new];
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
    return [FLEXObjectExplorerFactory explorerViewControllerForObject:self.metadata];
}

- (UITableViewCellAccessoryType)suggestedAccessoryTypeWithTarget:(id)object {
    return UITableViewCellAccessoryDisclosureIndicator;
}

- (NSArray<NSString *> *)copiableMetadataWithTarget:(id)object {
    return @[
        @"Class Name", self.name,
        @"Class", [FLEXUtility addressOfObject:self.metadata]
    ];
}

- (NSString *)contextualSubtitleWithTarget:(id)object {
    return [FLEXUtility addressOfObject:self.metadata];
}

@end
