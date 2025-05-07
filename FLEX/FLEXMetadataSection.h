// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXMetadataSection.h
//  FLEX
//
//  由 Tanner Bennett 创建于 9/19/19.
//  版权所有 © 2020 FLEX Team。保留所有权利。
//

#import "FLEXTableViewSection.h"
#import "FLEXObjectExplorer.h"

typedef NS_ENUM(NSUInteger, FLEXMetadataKind) {
    FLEXMetadataKindProperties = 1,
    FLEXMetadataKindClassProperties,
    FLEXMetadataKindIvars,
    FLEXMetadataKindMethods,
    FLEXMetadataKindClassMethods,
    FLEXMetadataKindClassHierarchy,
    FLEXMetadataKindProtocols,
    FLEXMetadataKindOther
};

/// 此部分用于显示有关类或对象的 ObjC 运行时元数据，
/// 例如列出方法、属性等。
@interface FLEXMetadataSection : FLEXTableViewSection

+ (instancetype)explorer:(FLEXObjectExplorer *)explorer kind:(FLEXMetadataKind)metadataKind;

@property (nonatomic, readonly) FLEXMetadataKind metadataKind;

/// 要排除的元数据的名称。如果您希望将特定的
/// 属性或方法分组到它们自己的部分中（而不是此部分），则此选项很有用。
///
/// 设置此属性会在此部分上调用 \c reloadData。
@property (nonatomic) NSSet<NSString *> *excludedMetadata;

@end
