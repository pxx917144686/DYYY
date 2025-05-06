// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXObjectExplorer.h
//  FLEX
//
//  由 Tanner Bennett 创建于 8/28/19.
//  版权所有 © 2020 FLEX Team。保留所有权利。
//

#import "FLEXRuntime+UIKitHelpers.h"

/// 保存当前用户默认设置的状态
@interface FLEXObjectExplorerDefaults : NSObject
+ (instancetype)canEdit:(BOOL)editable wantsPreviews:(BOOL)showPreviews;

/// 仅对属性和实例变量为 \c YES
@property (nonatomic, readonly) BOOL isEditable;
/// 仅影响属性和实例变量
@property (nonatomic, readonly) BOOL wantsDynamicPreviews;
@end

@interface FLEXObjectExplorer : NSObject

+ (instancetype)forObject:(id)objectOrClass;

+ (void)configureDefaultsForItems:(NSArray<id<FLEXObjectExplorerItem>> *)items;

@property (nonatomic, readonly) id object;
/// 子类可以重写以提供更有用的描述
@property (nonatomic, readonly) NSString *objectDescription;

/// @return 如果 \c object 是一个类的实例，则为 \c YES，
/// 或者如果 \c object 是一个类本身，则为 \c NO。
@property (nonatomic, readonly) BOOL objectIsInstance;

/// `classHierarchy` 数组的索引。
///
/// 此属性决定了从下面的元数据数组中获取哪组数据。
/// 例如，\c properties 包含所选类作用域的属性，
/// 而 \c allProperties 是一个数组的数组，其中每个数组都是
/// 当前对象的类层次结构中某个类的一组属性。
@property (nonatomic) NSInteger classScope;

@property (nonatomic, readonly) NSArray<NSArray<FLEXProperty *> *> *allProperties;
@property (nonatomic, readonly) NSArray<FLEXProperty *> *properties;

@property (nonatomic, readonly) NSArray<NSArray<FLEXProperty *> *> *allClassProperties;
@property (nonatomic, readonly) NSArray<FLEXProperty *> *classProperties;

@property (nonatomic, readonly) NSArray<NSArray<FLEXIvar *> *> *allIvars;
@property (nonatomic, readonly) NSArray<FLEXIvar *> *ivars;

@property (nonatomic, readonly) NSArray<NSArray<FLEXMethod *> *> *allMethods;
@property (nonatomic, readonly) NSArray<FLEXMethod *> *methods;

@property (nonatomic, readonly) NSArray<NSArray<FLEXMethod *> *> *allClassMethods;
@property (nonatomic, readonly) NSArray<FLEXMethod *> *classMethods;

@property (nonatomic, readonly) NSArray<Class> *classHierarchyClasses;
@property (nonatomic, readonly) NSArray<FLEXStaticMetadata *> *classHierarchy;

@property (nonatomic, readonly) NSArray<NSArray<FLEXProtocol *> *> *allConformedProtocols;
@property (nonatomic, readonly) NSArray<FLEXProtocol *> *conformedProtocols;

@property (nonatomic, readonly) NSArray<FLEXStaticMetadata *> *allInstanceSizes;
@property (nonatomic, readonly) FLEXStaticMetadata *instanceSize;

@property (nonatomic, readonly) NSArray<FLEXStaticMetadata *> *allImageNames;
@property (nonatomic, readonly) FLEXStaticMetadata *imageName;

- (void)reloadMetadata;
- (void)reloadClassHierarchy;

@end


@interface FLEXObjectExplorer (Reflex)

/// 不要手动启用此属性；Reflex 加载时会自动切换。
/// 如果您愿意，可以手动 \e 禁用它。
@property (nonatomic, class) BOOL reflexAvailable;

@end
