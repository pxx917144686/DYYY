// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXShortcutsSection.m
//  FLEX
//
//  由 Tanner Bennett 创建于 8/29/19.
//  版权所有 © 2020 FLEX Team。保留所有权利。

#import "FLEXShortcutsSection.h"
#import "FLEXTableView.h"
#import "FLEXTableViewCell.h"
#import "FLEXUtility.h"
#import "FLEXShortcut.h"
#import "FLEXProperty.h"
#import "FLEXPropertyAttributes.h"
#import "FLEXIvar.h"
#import "FLEXMethod.h"
#import "FLEXRuntime+UIKitHelpers.h"
#import "FLEXObjectExplorer.h"

#pragma mark 私有

@interface FLEXShortcutsSection ()
@property (nonatomic, copy) NSArray<NSString *> *titles;
@property (nonatomic, copy) NSArray<NSString *> *subtitles;

@property (nonatomic, copy) NSArray<NSString *> *allTitles;
@property (nonatomic, copy) NSArray<NSString *> *allSubtitles;

// 如果使用静态标题和副标题初始化，则不使用快捷方式
@property (nonatomic, copy) NSArray<id<FLEXShortcut>> *shortcuts;
@property (nonatomic, readonly) NSArray<id<FLEXShortcut>> *allShortcuts;
@end

@implementation FLEXShortcutsSection
@synthesize isNewSection = _isNewSection;

#pragma mark 初始化

+ (instancetype)forObject:(id)objectOrClass rowTitles:(NSArray<NSString *> *)titles {
    return [self forObject:objectOrClass rowTitles:titles rowSubtitles:nil];
}

+ (instancetype)forObject:(id)objectOrClass
                rowTitles:(NSArray<NSString *> *)titles
             rowSubtitles:(NSArray<NSString *> *)subtitles {
    return [[self alloc] initWithObject:objectOrClass titles:titles subtitles:subtitles];
}

+ (instancetype)forObject:(id)objectOrClass rows:(NSArray *)rows {
    return [[self alloc] initWithObject:objectOrClass rows:rows isNewSection:YES];
}

+ (instancetype)forObject:(id)objectOrClass additionalRows:(NSArray *)toPrepend {
    NSArray *rows = [FLEXShortcutsFactory shortcutsForObjectOrClass:objectOrClass];
    NSArray *allRows = [toPrepend arrayByAddingObjectsFromArray:rows] ?: rows;
    return [[self alloc] initWithObject:objectOrClass rows:allRows isNewSection:NO];
}

+ (instancetype)forObject:(id)objectOrClass {
    return [self forObject:objectOrClass additionalRows:nil];
}

- (id)initWithObject:(id)object
              titles:(NSArray<NSString *> *)titles
           subtitles:(NSArray<NSString *> *)subtitles {

    NSParameterAssert(titles.count == subtitles.count || !subtitles);
    NSParameterAssert(titles.count);

    self = [super init];
    if (self) {
        _object = object;
        _allTitles = titles.copy;
        _allSubtitles = subtitles.copy;
        _isNewSection = YES;
        _numberOfLines = 1;
    }

    return self;
}

- (id)initWithObject:object rows:(NSArray *)rows isNewSection:(BOOL)newSection {
    self = [super init];
    if (self) {
        _object = object;
        _isNewSection = newSection;
        
        _allShortcuts = [rows flex_mapped:^id(id obj, NSUInteger idx) {
            return [FLEXShortcut shortcutFor:obj];
        }];
        _numberOfLines = 1;
        
        // 填充标题和副标题
        [self reloadData];
    }

    return self;
}


#pragma mark - 公开

- (void)setCacheSubtitles:(BOOL)cacheSubtitles {
    if (_cacheSubtitles == cacheSubtitles) return;

    // cacheSubtitles 仅在有快捷方式对象时适用
    if (self.allShortcuts) {
        _cacheSubtitles = cacheSubtitles;
        [self reloadData];
    } else {
        NSLog(@"警告：在具有静态副标题的快捷方式部分设置 'cacheSubtitles'");
    }
}


#pragma mark - 重写

- (UITableViewCellAccessoryType)accessoryTypeForRow:(NSInteger)row {
    if (_allShortcuts) {
        return [self.shortcuts[row] accessoryTypeWith:self.object];
    }
    
    return UITableViewCellAccessoryNone;
}

- (void)setFilterText:(NSString *)filterText {
    super.filterText = filterText;

    NSAssert(
        self.allTitles.count == self.allSubtitles.count,
        @"每个标题都需要一个（可能为空的）副标题"
    );

    if (filterText.length) {
        // 统计匹配筛选条件的标题和副标题的索引
        NSMutableIndexSet *filterMatches = [NSMutableIndexSet new];
        id filterBlock = ^BOOL(NSString *obj, NSUInteger idx) {
            if ([obj localizedCaseInsensitiveContainsString:filterText]) {
                [filterMatches addIndex:idx];
                return YES;
            }

            return NO;
        };

        // 获取所有匹配的索引，包括副标题
        [self.allTitles flex_forEach:filterBlock];
        [self.allSubtitles flex_forEach:filterBlock];
        // 筛选到仅匹配的索引
        self.titles    = [self.allTitles objectsAtIndexes:filterMatches];
        self.subtitles = [self.allSubtitles objectsAtIndexes:filterMatches];
        self.shortcuts = [self.allShortcuts objectsAtIndexes:filterMatches];
    } else {
        self.shortcuts = self.allShortcuts;
        self.titles    = self.allTitles;
        self.subtitles = [self.allSubtitles flex_filtered:^BOOL(NSString *sub, NSUInteger idx) {
            return sub.length > 0;
        }];
    }
}

- (void)reloadData {
    [FLEXObjectExplorer configureDefaultsForItems:self.allShortcuts];
    
    // 从快捷方式生成所有（副）标题
    if (self.allShortcuts) {
        self.allTitles = [self.allShortcuts flex_mapped:^id(id<FLEXShortcut> s, NSUInteger idx) {
            return [s titleWith:self.object];
        }];
        self.allSubtitles = [self.allShortcuts flex_mapped:^id(id<FLEXShortcut> s, NSUInteger idx) {
            return [s subtitleWith:self.object] ?: @"";
        }];
    }

    // 重新生成已筛选的（副）标题和快捷方式
    self.filterText = self.filterText;
}

- (NSString *)title {
    return @"快捷方式";
}

- (NSInteger)numberOfRows {
    return self.titles.count;
}

- (BOOL)canSelectRow:(NSInteger)row {
    UITableViewCellAccessoryType type = [self.shortcuts[row] accessoryTypeWith:self.object];
    BOOL hasDisclosure = NO;
    hasDisclosure |= type == UITableViewCellAccessoryDisclosureIndicator;
    hasDisclosure |= type == UITableViewCellAccessoryDetailDisclosureButton;
    return hasDisclosure;
}

- (void (^)(__kindof UIViewController *))didSelectRowAction:(NSInteger)row {
    return [self.shortcuts[row] didSelectActionWith:self.object];
}

- (UIViewController *)viewControllerToPushForRow:(NSInteger)row {
    /// 如果 shortcuts 为 nil，则为 Nil，即如果使用 forObject:rowTitles:rowSubtitles: 初始化
    return [self.shortcuts[row] viewerWith:self.object];
}

- (void (^)(__kindof UIViewController *))didPressInfoButtonAction:(NSInteger)row {
    id<FLEXShortcut> shortcut = self.shortcuts[row];
    if ([shortcut respondsToSelector:@selector(editorWith:forSection:)]) {
        id object = self.object;
        return ^(UIViewController *host) {
            UIViewController *editor = [shortcut editorWith:object forSection:self];
            [host.navigationController pushViewController:editor animated:YES];
        };
    }

    return nil;
}

- (NSString *)reuseIdentifierForRow:(NSInteger)row {
    FLEXTableViewCellReuseIdentifier defaultReuse = kFLEXDetailCell;
    if (@available(iOS 11, *)) {
        defaultReuse = kFLEXMultilineDetailCell;
    }
    
    return [self.shortcuts[row] customReuseIdentifierWith:self.object] ?: defaultReuse;
}

- (void)configureCell:(__kindof FLEXTableViewCell *)cell forRow:(NSInteger)row {
    cell.titleLabel.text = [self titleForRow:row];
    cell.titleLabel.numberOfLines = self.numberOfLines;
    cell.subtitleLabel.text = [self subtitleForRow:row];
    cell.subtitleLabel.numberOfLines = self.numberOfLines;
    cell.accessoryType = [self accessoryTypeForRow:row];
}

- (NSString *)titleForRow:(NSInteger)row {
    return self.titles[row];
}

- (NSString *)subtitleForRow:(NSInteger)row {
    // 情况：动态、未缓存的副标题
    if (!self.cacheSubtitles) {
        NSString *subtitle = [self.shortcuts[row] subtitleWith:self.object];
        return subtitle.length ? subtitle : nil;
    }

    // 情况：静态副标题或缓存的副标题
    return self.subtitles[row];
}

@end


#pragma mark - 全局快捷方式注册

@interface FLEXShortcutsFactory () {
    BOOL _append, _prepend, _replace, _notInstance;
    NSArray<NSString *> *_properties, *_ivars, *_methods;
}
@end

#define NewAndSet(ivar) ({ FLEXShortcutsFactory *r = [self sharedFactory]; r->ivar = YES; r; })
#define SetIvar(ivar) ({ self->ivar = YES; self; })
#define SetParamBlock(ivar) ^(NSArray *p) { self->ivar = p; return self; }

typedef NSMutableDictionary<Class, NSMutableArray<id<FLEXRuntimeMetadata>> *> RegistrationBuckets;

@implementation FLEXShortcutsFactory {
    // 类存储桶
    RegistrationBuckets *cProperties;
    RegistrationBuckets *cIvars;
    RegistrationBuckets *cMethods;
    // 元类存储桶
    RegistrationBuckets *mProperties;
    RegistrationBuckets *mMethods;
}

+ (instancetype)sharedFactory {
    static FLEXShortcutsFactory *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [self new];
    });
    
    return shared;
}

- (id)init {
    self = [super init];
    if (self) {
        cProperties = [NSMutableDictionary new];
        cIvars = [NSMutableDictionary new];
        cMethods = [NSMutableDictionary new];

        mProperties = [NSMutableDictionary new];
        mMethods = [NSMutableDictionary new];
    }
    
    return self;
}

+ (NSArray<id<FLEXRuntimeMetadata>> *)shortcutsForObjectOrClass:(id)objectOrClass {
    return [[self sharedFactory] shortcutsForObjectOrClass:objectOrClass];
}

- (NSArray<id<FLEXRuntimeMetadata>> *)shortcutsForObjectOrClass:(id)objectOrClass {
    NSParameterAssert(objectOrClass);

    NSMutableArray<id<FLEXRuntimeMetadata>> *shortcuts = [NSMutableArray new];
    BOOL isClass = object_isClass(objectOrClass);
    // -class 不会给你一个元类，如果传入一个类，我们想要一个元类，
    // 或者如果传入一个对象，我们想要一个类
    Class classKey = object_getClass(objectOrClass);
    
    RegistrationBuckets *propertyBucket = isClass ? mProperties : cProperties;
    RegistrationBuckets *methodBucket = isClass ? mMethods : cMethods;
    RegistrationBuckets *ivarBucket = isClass ? nil : cIvars;

    BOOL stop = NO;
    while (!stop && classKey) {
        NSArray *properties = propertyBucket[classKey];
        NSArray *ivars = ivarBucket[classKey];
        NSArray *methods = methodBucket[classKey];

        // 如果找到任何东西就停止
        stop = properties || ivars || methods;
        if (stop) {
            // 将找到的内容添加到列表中
            [shortcuts addObjectsFromArray:properties];
            [shortcuts addObjectsFromArray:ivars];
            [shortcuts addObjectsFromArray:methods];
        } else {
            classKey = class_getSuperclass(classKey);
        }
    }
    
    [FLEXObjectExplorer configureDefaultsForItems:shortcuts];
    return shortcuts;
}

+ (FLEXShortcutsFactory *)append {
    return NewAndSet(_append);
}

+ (FLEXShortcutsFactory *)prepend {
    return NewAndSet(_prepend);
}

+ (FLEXShortcutsFactory *)replace {
    return NewAndSet(_replace);
}

- (void)_register:(NSArray<id<FLEXRuntimeMetadata>> *)items to:(RegistrationBuckets *)global class:(Class)key {
    @synchronized (self) {
        // 获取（或初始化）此类的存储桶
        NSMutableArray *bucket = ({
            id bucket = global[key];
            if (!bucket) {
                bucket = [NSMutableArray new];
                global[(id)key] = bucket;
            }
            bucket;
        });

        if (self->_append)  { [bucket addObjectsFromArray:items]; }
        if (self->_replace) { [bucket setArray:items]; }
        if (self->_prepend) {
            if (bucket.count) {
                // 将新项目设置为数组，并将旧项目添加到它们后面
                id copy = bucket.copy;
                [bucket setArray:items];
                [bucket addObjectsFromArray:copy];
            } else {
                [bucket addObjectsFromArray:items];
            }
        }
    }
}

- (void)reset {
    _append = NO;
    _prepend = NO;
    _replace = NO;
    _notInstance = NO;
    
    _properties = nil;
    _ivars = nil;
    _methods = nil;
}

- (FLEXShortcutsFactory *)class {
    return SetIvar(_notInstance);
}

- (FLEXShortcutsFactoryNames)properties {
    NSAssert(!_notInstance, @"不要同时设置 properties 和 classProperties");
    return SetParamBlock(_properties);
}

- (FLEXShortcutsFactoryNames)classProperties {
    _notInstance = YES;
    return SetParamBlock(_properties);
}

- (FLEXShortcutsFactoryNames)ivars {
    return SetParamBlock(_ivars);
}

- (FLEXShortcutsFactoryNames)methods {
    NSAssert(!_notInstance, @"不要同时设置 methods 和 classMethods");
    return SetParamBlock(_methods);
}

- (FLEXShortcutsFactoryNames)classMethods {
    _notInstance = YES;
    return SetParamBlock(_methods);
}

- (FLEXShortcutsFactoryTarget)forClass {
    return ^(Class cls) {
        NSAssert(
            ( self->_append && !self->_prepend && !self->_replace) ||
            (!self->_append &&  self->_prepend && !self->_replace) ||
            (!self->_append && !self->_prepend &&  self->_replace),
            @"您只能执行 [append, prepend, replace] 中的一个操作"
        );

        
        /// 我们将要添加的元数据是实例元数据还是类元数据，
        /// 即类属性与实例属性
        BOOL instanceMetadata = !self->_notInstance;
        /// 给定的类是否是元类；如果给定的是普通类对象，
        /// 我们需要切换到元类来添加类元数据
        BOOL isMeta = class_isMetaClass(cls);
        /// 我们将要添加的快捷方式应该出现在类还是实例中
        BOOL instanceShortcut = !isMeta;
        
        if (instanceMetadata) {
            NSAssert(!isMeta,
                @"实例元数据只能作为实例快捷方式添加"
            );
        }
        
        Class metaclass = isMeta ? cls : object_getClass(cls);
        Class clsForMetadata = instanceMetadata ? cls : metaclass;
        
        // 工厂是单例，所以我们不需要担心“泄漏”它
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wimplicit-retain-self"
        
        RegistrationBuckets *propertyBucket = instanceShortcut ? cProperties : mProperties;
        RegistrationBuckets *methodBucket = instanceShortcut ? cMethods : mMethods;
        RegistrationBuckets *ivarBucket = instanceShortcut ? cIvars : nil;
        
        #pragma clang diagnostic pop

        if (self->_properties) {
            NSArray *items = [self->_properties flex_mapped:^id(NSString *name, NSUInteger idx) {
                return [FLEXProperty named:name onClass:clsForMetadata];
            }];
            [self _register:items to:propertyBucket class:cls];
        }

        if (self->_methods) {
            NSArray *items = [self->_methods flex_mapped:^id(NSString *name, NSUInteger idx) {
                return [FLEXMethod selector:NSSelectorFromString(name) class:clsForMetadata];
            }];
            [self _register:items to:methodBucket class:cls];
        }

        if (self->_ivars) {
            NSAssert(instanceMetadata, @"实例元数据只能作为实例快捷方式添加 (%@)", cls);
            NSArray *items = [self->_ivars flex_mapped:^id(NSString *name, NSUInteger idx) {
                return [FLEXIvar named:name onClass:clsForMetadata];
            }];
            [self _register:items to:ivarBucket class:cls];
        }
        
        [self reset];
    };
}

@end
