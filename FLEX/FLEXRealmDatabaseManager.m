// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXRealmDatabaseManager.m
//  FLEX
//
//  由 Tim Oliver 创建于 28/01/2016.
//  版权所有 © 2016 Realm。保留所有权利。

#import "FLEXRealmDatabaseManager.h"
#import "NSArray+FLEX.h"
#import "FLEXSQLResult.h"

#if __has_include(<Realm/Realm.h>)
#import <Realm/Realm.h>
#import <Realm/RLMRealm_Dynamic.h>
#else
#import "FLEXRealmDefines.h"
#endif

@interface FLEXRealmDatabaseManager ()

@property (nonatomic, copy) NSString *path;
@property (nonatomic) RLMRealm *realm;

@end

@implementation FLEXRealmDatabaseManager
static Class RLMRealmClass = nil;

+ (void)load {
    RLMRealmClass = NSClassFromString(@"RLMRealm");
}

+ (instancetype)managerForDatabase:(NSString *)path {
    return [[self alloc] initWithPath:path];
}

- (instancetype)initWithPath:(NSString *)path {
    if (!RLMRealmClass) {
        return nil;
    }
    
    self = [super init];
    if (self) {
        _path = path;
        
        if (![self open]) {
            return nil;
        }
    }
    
    return self;
}

- (BOOL)open {
    Class configurationClass = NSClassFromString(@"RLMRealmConfiguration");
    if (!RLMRealmClass || !configurationClass) {
        return NO;
    }
    
    NSError *error = nil;
    id configuration = [configurationClass new];
    [(RLMRealmConfiguration *)configuration setFileURL:[NSURL fileURLWithPath:self.path]];
    self.realm = [RLMRealmClass realmWithConfiguration:configuration error:&error];
    
    return (error == nil);
}

- (NSArray<NSString *> *)queryAllTables {
    // 将每个 schema 映射到其名称
    NSArray<NSString *> *tableNames = [self.realm.schema.objectSchema flex_mapped:^id(RLMObjectSchema *schema, NSUInteger idx) {
        return schema.className ?: nil;
    }];

    return [tableNames sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

- (NSArray<NSString *> *)queryAllColumnsOfTable:(NSString *)tableName {
    RLMObjectSchema *objectSchema = [self.realm.schema schemaForClassName:tableName];
    // 将每一列映射到其名称
    return [objectSchema.properties flex_mapped:^id(RLMProperty *property, NSUInteger idx) {
        return property.name;
    }];
}

- (NSArray<NSArray *> *)queryAllDataInTable:(NSString *)tableName {
    RLMObjectSchema *objectSchema = [self.realm.schema schemaForClassName:tableName];
    RLMResults *results = [self.realm allObjects:tableName];
    if (results.count == 0 || !objectSchema) {
        return nil;
    }
    
    // 将结果映射到一个行数组
    return [NSArray flex_mapped:results block:^id(RLMObject *result, NSUInteger idx) {
        // 将每一行映射到其属性值的数组
        return [objectSchema.properties flex_mapped:^id(RLMProperty *property, NSUInteger idx) {
            return [result valueForKey:property.name] ?: NSNull.null;
        }];
    }];
}

@end
