//
//  FLEXObjectExplorer.m
//  FLEX
//
//  Created by Tanner Bennett on 8/28/19.
//  Copyright © 2020 FLEX Team. All rights reserved.
//

#import "FLEXObjectExplorer.h"
#import "FLEXUtility.h"
#import "FLEXRuntimeUtility.h"
#import "NSObject+FLEX_Reflection.h"
#import "FLEXRuntime+Compare.h"
#import "FLEXRuntime+UIKitHelpers.h"
#import "FLEXPropertyAttributes.h"
#import "FLEXMetadataSection.h"
#import "NSUserDefaults+FLEX.h"
#import "FLEXMirror.h"
#import "FLEXSwiftInternal.h"

@implementation FLEXObjectExplorerDefaults

+ (instancetype)canEdit:(BOOL)editable wantsPreviews:(BOOL)showPreviews {
    FLEXObjectExplorerDefaults *defaults = [self new];
    defaults->_isEditable = editable;
    defaults->_wantsDynamicPreviews = showPreviews;
    return defaults;
}

@end

@interface FLEXObjectExplorer () {
    NSMutableArray<NSArray<FLEXProperty *> *> *_allProperties;
    NSMutableArray<NSArray<FLEXProperty *> *> *_allClassProperties;
    NSMutableArray<NSArray<FLEXIvar *> *> *_allIvars;
    NSMutableArray<NSArray<FLEXMethod *> *> *_allMethods;
    NSMutableArray<NSArray<FLEXMethod *> *> *_allClassMethods;
    NSMutableArray<NSArray<FLEXProtocol *> *> *_allConformedProtocols;
    NSMutableArray<FLEXStaticMetadata *> *_allInstanceSizes;
    NSMutableArray<FLEXStaticMetadata *> *_allImageNames;
    NSString *_objectDescription;
}

@property (nonatomic, readonly) id<FLEXMirror> initialMirror;
@end

@implementation FLEXObjectExplorer

+ (void)initialize {
    if (self == FLEXObjectExplorer.class) {
        FLEXObjectExplorer.reflexAvailable = NSClassFromString(@"FLEXSwiftMirror") != nil;
    }
}

#pragma mark - 初始化

+ (id)forObject:(id)objectOrClass {
    return [[self alloc] initWithObject:objectOrClass];
}

- (id)initWithObject:(id)objectOrClass {
    NSParameterAssert(objectOrClass);
    
    self = [super init];
    if (self) {
        _object = objectOrClass;
        _objectIsInstance = !object_isClass(objectOrClass);
        
        [self reloadMetadata];
    }

    return self;
}

- (id<FLEXMirror>)mirrorForClass:(Class)cls {
    static Class FLEXSwiftMirror = nil;
    
    // 我们应该使用Reflex吗？
    if (FLEXIsSwiftObjectOrClass(cls) && FLEXObjectExplorer.reflexAvailable) {
        // 如有需要初始化FLEXSwiftMirror类
        if (!FLEXSwiftMirror) {
            FLEXSwiftMirror = NSClassFromString(@"FLEXSwiftMirror");            
        }
        
        return [(id<FLEXMirror>)[FLEXSwiftMirror alloc] initWithSubject:cls];
    }
    
    // 否则；不是swift对象，或者Reflex不可用
    return [FLEXMirror reflect:cls];
}


#pragma mark - 公共方法

+ (void)configureDefaultsForItems:(NSArray<id<FLEXObjectExplorerItem>> *)items {
    BOOL hidePreviews = NSUserDefaults.standardUserDefaults.flex_explorerHidesVariablePreviews;
    FLEXObjectExplorerDefaults *mutable = [FLEXObjectExplorerDefaults
        canEdit:YES wantsPreviews:!hidePreviews
    ];
    FLEXObjectExplorerDefaults *immutable = [FLEXObjectExplorerDefaults
        canEdit:NO wantsPreviews:!hidePreviews
    ];

    // .tag用于缓存.isEditable的值；
    // 这可能在运行时更改，所以重要的是
    // 每次请求快捷方式时都要缓存它，而不是
    // 只在最初注册快捷方式时缓存一次
    for (id<FLEXObjectExplorerItem> metadata in items) {
        metadata.defaults = metadata.isEditable ? mutable : immutable;
    }
}

- (NSString *)objectDescription {
    if (!_objectDescription) {
        // 硬编码UIColor描述
        if ([FLEXRuntimeUtility safeObject:self.object isKindOfClass:[UIColor class]]) {
            CGFloat h, s, l, r, g, b, a;
            [self.object getRed:&r green:&g blue:&b alpha:&a];
            [self.object getHue:&h saturation:&s brightness:&l alpha:nil];

            return [NSString stringWithFormat:
                @"HSL: (%.3f, %.3f, %.3f)\nRGB: (%.3f, %.3f, %.3f)\n透明度: %.3f",
                h, s, l, r, g, b, a
            ];
        }

        NSString *description = [FLEXRuntimeUtility safeDescriptionForObject:self.object];

        if (!description.length) {
            NSString *address = [FLEXUtility addressOfObject:self.object];
            return [NSString stringWithFormat:@"%@ 处的对象返回了空描述", address];
        }
        
        if (description.length > 10000) {
            description = [description substringToIndex:10000];
        }

        _objectDescription = description;
    }

    return _objectDescription;
}

- (void)setClassScope:(NSInteger)classScope {
    _classScope = classScope;
    
    [self reloadScopedMetadata];
}

- (void)reloadMetadata {
    _allProperties = [NSMutableArray new];
    _allClassProperties = [NSMutableArray new];
    _allIvars = [NSMutableArray new];
    _allMethods = [NSMutableArray new];
    _allClassMethods = [NSMutableArray new];
    _allConformedProtocols = [NSMutableArray new];
    _allInstanceSizes = [NSMutableArray new];
    _allImageNames = [NSMutableArray new];
    _objectDescription = nil;

    [self reloadClassHierarchy];
    
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    BOOL hideBackingIvars = defaults.flex_explorerHidesPropertyIvars;
    BOOL hidePropertyMethods = defaults.flex_explorerHidesPropertyMethods;
    BOOL hidePrivateMethods = defaults.flex_explorerHidesPrivateMethods;
    BOOL showMethodOverrides = defaults.flex_explorerShowsMethodOverrides;
    
    NSMutableArray<NSArray<FLEXProperty *> *> *allProperties = [NSMutableArray new];
    NSMutableArray<NSArray<FLEXProperty *> *> *allClassProps = [NSMutableArray new];
    NSMutableArray<NSArray<FLEXMethod *> *> *allMethods = [NSMutableArray new];
    NSMutableArray<NSArray<FLEXMethod *> *> *allClassMethods = [NSMutableArray new];

    // 循环遍历每个类和每个超类，收集
    // 每个类别中的新的和唯一的元数据
    Class superclass = nil;
    NSInteger count = self.classHierarchyClasses.count;
    NSInteger rootIdx = count - 1;
    for (NSInteger i = 0; i < count; i++) {
        Class cls = self.classHierarchyClasses[i];
        id<FLEXMirror> mirror = [self mirrorForClass:cls];
        superclass = (i < rootIdx) ? self.classHierarchyClasses[i+1] : nil;

        [allProperties addObject:[self
            metadataUniquedByName:mirror.properties
            superclass:superclass
            kind:FLEXMetadataKindProperties
            skip:showMethodOverrides
        ]];
        [allClassProps addObject:[self
            metadataUniquedByName:mirror.classProperties
            superclass:superclass
            kind:FLEXMetadataKindClassProperties
            skip:showMethodOverrides
        ]];
        [_allIvars addObject:[self
            metadataUniquedByName:mirror.ivars
            superclass:nil
            kind:FLEXMetadataKindIvars
            skip:NO
        ]];
        [allMethods addObject:[self
            metadataUniquedByName:mirror.methods
            superclass:superclass
            kind:FLEXMetadataKindMethods
            skip:showMethodOverrides
        ]];
        [allClassMethods addObject:[self
            metadataUniquedByName:mirror.classMethods
            superclass:superclass
            kind:FLEXMetadataKindClassMethods
            skip:showMethodOverrides
        ]];
        [_allConformedProtocols addObject:[self
            metadataUniquedByName:mirror.protocols
            superclass:superclass
            kind:FLEXMetadataKindProtocols
            skip:NO
        ]];
        
        // TODO: 将实例大小、图像名称和类层次结构合并为单个模型对象
        // 这将大大减少已开始在这里表现出来的懒惰
        [_allInstanceSizes addObject:[FLEXStaticMetadata
            style:FLEXStaticMetadataRowStyleKeyValue
            title:@"实例大小" number:@(class_getInstanceSize(cls))
        ]];
        [_allImageNames addObject:[FLEXStaticMetadata
            style:FLEXStaticMetadataRowStyleDefault
            title:@"图像名称" string:@(class_getImageName(cls) ?: "运行时创建")
        ]];
    }
    
    _classHierarchy = [FLEXStaticMetadata classHierarchy:self.classHierarchyClasses];
    
    NSArray<NSArray<FLEXProperty *> *> *properties = allProperties;
    
    // 可能过滤属性支持的实例变量
    if (hideBackingIvars) {
        NSArray<NSArray<FLEXIvar *> *> *ivars = _allIvars.copy;
        _allIvars = [ivars flex_mapped:^id(NSArray<FLEXIvar *> *list, NSUInteger idx) {
            // 获取当前层次结构类中所有支持实例变量名称的集合
            NSSet *ivarNames = [NSSet setWithArray:({
                [properties[idx] flex_mapped:^id(FLEXProperty *p, NSUInteger idx) {
                    // 如果没有实例变量则为nil，数组被扁平化
                    return p.likelyIvarName;
                }];
            })];
            
            // 删除名称在实例变量名称列表中的实例变量
            return [list flex_filtered:^BOOL(FLEXIvar *ivar, NSUInteger idx) {
                return ![ivarNames containsObject:ivar.name];
            }];
        }];
    }
    
    // 可能过滤属性支持的方法
    if (hidePropertyMethods) {
        allMethods = [allMethods flex_mapped:^id(NSArray<FLEXMethod *> *list, NSUInteger idx) {
            // 获取当前层次结构类中所有属性方法名称的集合
            NSSet *methodNames = [NSSet setWithArray:({
                [properties[idx] flex_flatmapped:^NSArray *(FLEXProperty *p, NSUInteger idx) {
                    if (p.likelyGetterExists) {
                        if (p.likelySetterExists) {
                            return @[p.likelyGetterString, p.likelySetterString];
                        }
                        
                        return @[p.likelyGetterString];
                    } else if (p.likelySetterExists) {
                        return @[p.likelySetterString];
                    }
                    
                    return nil;
                }];
            })];
            
            // 删除名称在属性方法名称列表中的方法
            return [list flex_filtered:^BOOL(FLEXMethod *method, NSUInteger idx) {
                return ![methodNames containsObject:method.selectorString];
            }];
        }];
    }
    
    if (hidePrivateMethods) {
        id methodMapBlock = ^id(NSArray<FLEXMethod *> *list, NSUInteger idx) {
            // 删除包含下划线的方法
            return [list flex_filtered:^BOOL(FLEXMethod *method, NSUInteger idx) {
                return ![method.selectorString containsString:@"_"];
            }];
        };
        id propertyMapBlock = ^id(NSArray<FLEXProperty *> *list, NSUInteger idx) {
            // 删除包含下划线的方法
            return [list flex_filtered:^BOOL(FLEXProperty *prop, NSUInteger idx) {
                return ![prop.name containsString:@"_"];
            }];
        };
        
        allMethods = [allMethods flex_mapped:methodMapBlock];
        allClassMethods = [allClassMethods flex_mapped:methodMapBlock];
        allProperties = [allProperties flex_mapped:propertyMapBlock];
        allClassProps = [allClassProps flex_mapped:propertyMapBlock];
    }
    
    _allProperties = allProperties;
    _allClassProperties = allClassProps;
    _allMethods = allMethods;
    _allClassMethods = allClassMethods;

    // 设置UIKit助手数据
    // 实际上，我们只需要在属性和实例变量上调用此方法
    // 因为没有其他元数据类型支持编辑。
    NSArray<NSArray *>*metadatas = @[
        _allProperties, _allClassProperties, _allIvars,
       /* _allMethods, _allClassMethods, _allConformedProtocols */
    ];
    for (NSArray *matrix in metadatas) {
        for (NSArray *metadataByClass in matrix) {
            [FLEXObjectExplorer configureDefaultsForItems:metadataByClass];
        }
    }
    
    [self reloadScopedMetadata];
}


#pragma mark - 私有方法

- (void)reloadScopedMetadata {
    _properties = self.allProperties[self.classScope];
    _classProperties = self.allClassProperties[self.classScope];
    _ivars = self.allIvars[self.classScope];
    _methods = self.allMethods[self.classScope];
    _classMethods = self.allClassMethods[self.classScope];
    _conformedProtocols = self.allConformedProtocols[self.classScope];
    _instanceSize = self.allInstanceSizes[self.classScope];
    _imageName = self.allImageNames[self.classScope];
}

/// 接受一个flex元数据对象数组并丢弃具有
/// 重复名称的对象，以及不是"新的"的属性和方法
/// （即，超类响应的那些）
- (NSArray *)metadataUniquedByName:(NSArray *)list
                        superclass:(Class)superclass
                              kind:(FLEXMetadataKind)kind
                              skip:(BOOL)skipUniquing {
    if (skipUniquing) {
        return list;
    }
    
    // 删除具有相同名称的项目并返回过滤后的列表
    NSMutableSet *names = [NSMutableSet new];
    return [list flex_filtered:^BOOL(id obj, NSUInteger idx) {
        NSString *name = [obj name];
        if ([names containsObject:name]) {
            return NO;
        } else {
            if (!name) {
                return NO;
            }
            
            [names addObject:name];

            // 跳过仅是重写的方法和属性，
            // 可能跳过与属性相关的实例变量和方法
            switch (kind) {
                case FLEXMetadataKindProperties:
                    if ([superclass instancesRespondToSelector:[obj likelyGetter]]) {
                        return NO;
                    }
                    break;
                case FLEXMetadataKindClassProperties:
                    if ([superclass respondsToSelector:[obj likelyGetter]]) {
                        return NO;
                    }
                    break;
                case FLEXMetadataKindMethods:
                    if ([superclass instancesRespondToSelector:NSSelectorFromString(name)]) {
                        return NO;
                    }
                    break;
                case FLEXMetadataKindClassMethods:
                    if ([superclass respondsToSelector:NSSelectorFromString(name)]) {
                        return NO;
                    }
                    break;

                case FLEXMetadataKindProtocols:
                case FLEXMetadataKindClassHierarchy:
                case FLEXMetadataKindOther:
                    return YES; // 这些类型已经是唯一的
                    break;
                    
                // 实例变量不能被重写
                case FLEXMetadataKindIvars: break;
            }

            return YES;
        }
    }];
}


#pragma mark - 超类

- (void)reloadClassHierarchy {
    // 根据这个逻辑，类层次结构永远不会包含元类对象；
    // 对于给定的类和它的实例，它总是相同的
    _classHierarchyClasses = [[self.object class] flex_classHierarchy];
}

@end


#pragma mark - Reflex
@implementation FLEXObjectExplorer (Reflex)
static BOOL _reflexAvailable = NO;

+ (BOOL)reflexAvailable { return _reflexAvailable; }
+ (void)setReflexAvailable:(BOOL)enable { _reflexAvailable = enable; }

@end
