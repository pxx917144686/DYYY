//
//  DYYYFLEXShortcut.m
//  FLEX
//
//  由 Tanner Bennett 创建于 12/10/19.
//  版权所有 © 2020 FLEX Team. 保留所有权利。
//

#import "DYYYFLEXShortcut.h"
#import "DYYYFLEXProperty.h"
#import "DYYYFLEXPropertyAttributes.h"
#import "DYYYFLEXIvar.h"
#import "DYYYFLEXMethod.h"
#import "DYYYFLEXRuntime+UIKitHelpers.h"
#import "DYYYFLEXObjectExplorerFactory.h"
#import "DYYYFLEXFieldEditorViewController.h"
#import "DYYYFLEXMethodCallingViewController.h"
#import "DYYYFLEXMetadataSection.h"
#import "DYYYFLEXTableView.h"


#pragma mark - DYYYFLEXShortcut

@interface DYYYFLEXShortcut () {
    id _item;
}

@property (nonatomic, readonly) FLEXMetadataKind metadataKind;
@property (nonatomic, readonly) DYYYFLEXProperty *property;
@property (nonatomic, readonly) DYYYFLEXMethod *method;
@property (nonatomic, readonly) DYYYFLEXIvar *ivar;
@property (nonatomic, readonly) id<FLEXRuntimeMetadata> metadata;
@end

@implementation DYYYFLEXShortcut
@synthesize defaults = _defaults;

+ (id<DYYYFLEXShortcut>)shortcutFor:(id)item {
    if ([item conformsToProtocol:@protocol(DYYYFLEXShortcut)]) {
        return item;
    }
    
    DYYYFLEXShortcut *shortcut = [self new];
    shortcut->_item = item;

    if ([item isKindOfClass:[DYYYFLEXProperty class]]) {
        if (shortcut.property.isClassProperty) {
            shortcut->_metadataKind =  FLEXMetadataKindClassProperties;
        } else {
            shortcut->_metadataKind =  FLEXMetadataKindProperties;
        }
    }
    if ([item isKindOfClass:[DYYYFLEXIvar class]]) {
        shortcut->_metadataKind = FLEXMetadataKindIvars;
    }
    if ([item isKindOfClass:[DYYYFLEXMethod class]]) {
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

- (UIViewController *)editorWith:(id)object forSection:(DYYYFLEXTableViewSection *)section {
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

#pragma mark DYYYFLEXObjectExplorerDefaults

- (void)setDefaults:(DYYYFLEXObjectExplorerDefaults *)defaults {
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

- (DYYYFLEXProperty *)property { return _item; }
- (DYYYFLEXMethodBase *)method { return _item; }
- (DYYYFLEXIvar *)ivar { return _item; }
- (id<FLEXRuntimeMetadata>)metadata { return _item; }

@end


#pragma mark - DYYYFLEXActionShortcut

@interface DYYYFLEXActionShortcut ()
@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly) NSString *(^subtitleFuture)(id);
@property (nonatomic, readonly) UIViewController *(^viewerFuture)(id);
@property (nonatomic, readonly) void (^selectionHandler)(UIViewController *, id);
@property (nonatomic, readonly) UITableViewCellAccessoryType (^accessoryTypeFuture)(id);
@end

@implementation DYYYFLEXActionShortcut
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
