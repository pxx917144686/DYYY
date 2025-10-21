//
//  FLEXShortcut.m
//  FLEX
//
//  由 Tanner Bennett 创建于 12/10/19.
//  版权所有 © 2020 FLEX Team. 保留所有权利。
//

#import "FLEXShortcut.h"
#import "FLEXProperty.h"
#import "FLEXPropertyAttributes.h"
#import "FLEXIvar.h"
#import "FLEXMethod.h"
#import "FLEXRuntime+UIKitHelpers.h"
#import "FLEXObjectExplorerFactory.h"
#import "FLEXFieldEditorViewController.h"
#import "FLEXMethodCallingViewController.h"
#import "FLEXMetadataSection.h"
#import "FLEXTableView.h"


#pragma mark - FLEXShortcut

@interface FLEXShortcut () {
    id _item;
}

@property (nonatomic, readonly) FLEXMetadataKind metadataKind;
@property (nonatomic, readonly) FLEXProperty *property;
@property (nonatomic, readonly) FLEXMethod *method;
@property (nonatomic, readonly) FLEXIvar *ivar;
@property (nonatomic, readonly) id<FLEXRuntimeMetadata> metadata;
@end

@implementation FLEXShortcut
@synthesize defaults = _defaults;

+ (id<FLEXShortcut>)shortcutFor:(id)item {
    if ([item conformsToProtocol:@protocol(FLEXShortcut)]) {
        return item;
    }
    
    FLEXShortcut *shortcut = [self new];
    shortcut->_item = item;

    if ([item isKindOfClass:[FLEXProperty class]]) {
        if (shortcut.property.isClassProperty) {
            shortcut->_metadataKind =  FLEXMetadataKindClassProperties;
        } else {
            shortcut->_metadataKind =  FLEXMetadataKindProperties;
        }
    }
    if ([item isKindOfClass:[FLEXIvar class]]) {
        shortcut->_metadataKind = FLEXMetadataKindIvars;
    }
    if ([item isKindOfClass:[FLEXMethod class]]) {
        // 我们不关心它是否是类方法
        shortcut->_metadataKind = FLEXMetadataKindMethods;
    }

    return shortcut;
}

- (id)propertyOrIvarValue:(id)object {
    return [self.metadata currentValueWithTarget:object];
}

- (NSString *)titleWith:(id)object {
    switch (self.metadataKind) {
        case FLEXMetadataKindClassProperties:
        case FLEXMetadataKindProperties:
            // 由于我们在"属性"部分之外，为了清晰起见，添加 @property 前缀
            return [@"@property " stringByAppendingString:[_item description]];

        default:
            return [_item description];
    }

    NSAssert(
        [_item isKindOfClass:[NSString class]],
        @"意外类型: %@", [_item class]
    );

    return _item;
}

- (NSString *)subtitleWith:(id)object {
    if (self.metadataKind) {
        return [self.metadata previewWithTarget:object];
    }

    // 项目可能是字符串；必须返回空字符串，因为
    // 这些将被收集到一个数组中。如果对象仅
    // 是一个字符串，它不会有副标题。
    return @"";
}

- (void (^)(UIViewController *))didSelectActionWith:(id)object { 
    return nil;
}

- (UIViewController *)viewerWith:(id)object {
    NSAssert(self.metadataKind, @"静态标题无法查看");
    return [self.metadata viewerWithTarget:object];
}

- (UIViewController *)editorWith:(id)object forSection:(FLEXTableViewSection *)section {
    NSAssert(self.metadataKind, @"静态标题无法编辑");
    return [self.metadata editorWithTarget:object section:section];
}

- (UITableViewCellAccessoryType)accessoryTypeWith:(id)object {
    if (self.metadataKind) {
        return [self.metadata suggestedAccessoryTypeWithTarget:object];
    }

    return UITableViewCellAccessoryNone;
}

- (NSString *)customReuseIdentifierWith:(id)object {
    if (self.metadataKind) {
        return kFLEXCodeFontCell;
    }

    return kFLEXMultilineCell;
}

#pragma mark FLEXObjectExplorerDefaults

- (void)setDefaults:(FLEXObjectExplorerDefaults *)defaults {
    _defaults = defaults;
    
    if (_metadataKind) {
        self.metadata.defaults = defaults;
    }
}

- (BOOL)isEditable {
    if (_metadataKind) {
        return self.metadata.isEditable;
    }
    
    return NO;
}

- (BOOL)isCallable {
    if (_metadataKind) {
        return self.metadata.isCallable;
    }
    
    return NO;
}

#pragma mark - 辅助方法

- (FLEXProperty *)property { return _item; }
- (FLEXMethodBase *)method { return _item; }
- (FLEXIvar *)ivar { return _item; }
- (id<FLEXRuntimeMetadata>)metadata { return _item; }

@end


#pragma mark - FLEXActionShortcut

@interface FLEXActionShortcut ()
@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly) NSString *(^subtitleFuture)(id);
@property (nonatomic, readonly) UIViewController *(^viewerFuture)(id);
@property (nonatomic, readonly) void (^selectionHandler)(UIViewController *, id);
@property (nonatomic, readonly) UITableViewCellAccessoryType (^accessoryTypeFuture)(id);
@end

@implementation FLEXActionShortcut
@synthesize defaults = _defaults;

+ (instancetype)title:(NSString *)title
             subtitle:(NSString *(^)(id))subtitle
               viewer:(UIViewController *(^)(id))viewer
        accessoryType:(UITableViewCellAccessoryType (^)(id))type {
    return [[self alloc] initWithTitle:title subtitle:subtitle viewer:viewer selectionHandler:nil accessoryType:type];
}

+ (instancetype)title:(NSString *)title
             subtitle:(NSString * (^)(id))subtitle
     selectionHandler:(void (^)(UIViewController *, id))tapAction
        accessoryType:(UITableViewCellAccessoryType (^)(id))type {
    return [[self alloc] initWithTitle:title subtitle:subtitle viewer:nil selectionHandler:tapAction accessoryType:type];
}

- (id)initWithTitle:(NSString *)title
           subtitle:(id)subtitleFuture
             viewer:(id)viewerFuture
   selectionHandler:(id)tapAction
      accessoryType:(id)accessoryTypeFuture {
    NSParameterAssert(title.length);

    self = [super init];
    if (self) {
        id nilBlock = ^id (id obj) { return nil; };
        
        _title = title;
        _subtitleFuture = subtitleFuture ?: nilBlock;
        _viewerFuture = viewerFuture ?: nilBlock;
        _selectionHandler = tapAction;
        _accessoryTypeFuture = accessoryTypeFuture ?: nilBlock;
    }

    return self;
}

- (NSString *)titleWith:(id)object {
    return self.title;
}

- (NSString *)subtitleWith:(id)object {
    if (self.defaults.wantsDynamicPreviews) {
        return self.subtitleFuture(object);
    }
    
    return nil;
}

- (void (^)(UIViewController *))didSelectActionWith:(id)object {
    if (self.selectionHandler) {
        return ^(UIViewController *host) {
            self.selectionHandler(host, object);
        };
    }
    
    return nil;
}

- (UIViewController *)viewerWith:(id)object {
    return self.viewerFuture(object);
}

- (UITableViewCellAccessoryType)accessoryTypeWith:(id)object {
    return self.accessoryTypeFuture(object);
}

- (NSString *)customReuseIdentifierWith:(id)object {
    if (!self.subtitleFuture(object)) {
        // 如果没有副标题，这种样式的文本更居中
        return kFLEXDefaultCell;
    }

    return nil;
}

- (BOOL)isEditable { return NO; }
- (BOOL)isCallable { return NO; }

@end
