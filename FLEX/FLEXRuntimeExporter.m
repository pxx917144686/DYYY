//
//  FLEXRuntimeExporter.m
//  FLEX
//
//  由 Tanner Bennett 创建于 3/26/20.
//  版权所有 (c) 2020 FLEX Team. 保留所有权利。
//

#import "FLEXRuntimeExporter.h"
#import "FLEXSQLiteDatabaseManager.h"
#import "NSObject+FLEX_Reflection.h"
#import "FLEXRuntimeController.h"
#import "FLEXRuntimeClient.h"
#import "NSArray+FLEX.h"
#import "FLEXTypeEncodingParser.h"
#import <sqlite3.h>

#import "FLEXProtocol.h"
#import "FLEXProperty.h"
#import "FLEXIvar.h"
#import "FLEXMethodBase.h"
#import "FLEXMethod.h"
#import "FLEXPropertyAttributes.h"

NSString * const kFREEnableForeignKeys = @"PRAGMA foreign_keys = ON;";

/// 已加载的镜像
NSString * const kFRECreateTableMachOCommand = @"CREATE TABLE MachO( "
    "id INTEGER PRIMARY KEY AUTOINCREMENT, "
    "shortName TEXT, "
    "imagePath TEXT, "
    "bundleID TEXT "
");";

NSString * const kFREInsertImage = @"INSERT INTO MachO ( "
    "shortName, imagePath, bundleID "
") VALUES ( "
    "$shortName, $imagePath, $bundleID "
");";

/// Objc 类
NSString * const kFRECreateTableClassCommand = @"CREATE TABLE Class( "
    "id INTEGER PRIMARY KEY AUTOINCREMENT, "
    "className TEXT, "
    "superclass INTEGER, "
    "instanceSize INTEGER, "
    "version INTEGER, "
    "image INTEGER, "

    "FOREIGN KEY(superclass) REFERENCES Class(id), "
    "FOREIGN KEY(image) REFERENCES MachO(id) "
");";

NSString * const kFREInsertClass = @"INSERT INTO Class ( "
    "className, instanceSize, version, image "
") VALUES ( "
    "$className, $instanceSize, $version, $image "
");";

NSString * const kFREUpdateClassSetSuper = @"UPDATE Class SET superclass = $super WHERE id = $id;";

/// 唯一的 objc 选择器
NSString * const kFRECreateTableSelectorCommand = @"CREATE TABLE Selector( "
    "id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "
    "name text NOT NULL UNIQUE "
");";

NSString * const kFREInsertSelector = @"INSERT OR IGNORE INTO Selector (name) VALUES ($name);";

/// 唯一的 objc 类型编码
NSString * const kFRECreateTableTypeEncodingCommand = @"CREATE TABLE TypeEncoding( "
    "id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "
    "string text NOT NULL UNIQUE, "
    "size integer "
");";

NSString * const kFREInsertTypeEncoding = @"INSERT OR IGNORE INTO TypeEncoding "
    "(string, size) VALUES ($type, $size);";

/// 唯一的 objc 类型签名
NSString * const kFRECreateTableTypeSignatureCommand = @"CREATE TABLE TypeSignature( "
    "id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "
    "string text NOT NULL UNIQUE "
");";

NSString * const kFREInsertTypeSignature = @"INSERT OR IGNORE INTO TypeSignature "
    "(string) VALUES ($type);";

NSString * const kFRECreateTableMethodSignatureCommand = @"CREATE TABLE MethodSignature( "
    "id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "
    "typeEncoding TEXT, "
    "argc INTEGER, "
    "returnType INTEGER, "
    "frameLength INTEGER, "

    "FOREIGN KEY(returnType) REFERENCES TypeEncoding(id) "
");";

NSString * const kFREInsertMethodSignature = @"INSERT INTO MethodSignature ( "
    "typeEncoding, argc, returnType, frameLength "
") VALUES ( "
    "$typeEncoding, $argc, $returnType, $frameLength "
");";

NSString * const kFRECreateTableMethodCommand = @"CREATE TABLE Method( "
    "id INTEGER PRIMARY KEY AUTOINCREMENT, "
    "sel INTEGER, "
    "class INTEGER, "
    "instance INTEGER, " // 如果是类方法为0，如果是实例方法为1
    "signature INTEGER, "
    "image INTEGER, "

    "FOREIGN KEY(sel) REFERENCES Selector(id), "
    "FOREIGN KEY(class) REFERENCES Class(id), "
    "FOREIGN KEY(signature) REFERENCES MethodSignature(id), "
    "FOREIGN KEY(image) REFERENCES MachO(id) "
");";

NSString * const kFREInsertMethod = @"INSERT INTO Method ( "
    "sel, class, instance, signature, image "
") VALUES ( "
    "$sel, $class, $instance, $signature, $image "
");";

NSString * const kFRECreateTablePropertyCommand = @"CREATE TABLE Property( "
    "id INTEGER PRIMARY KEY AUTOINCREMENT, "
    "name TEXT, "
    "class INTEGER, "
    "instance INTEGER, " // 如果是类属性为0，如果是实例属性为1
    "image INTEGER, "
    "attributes TEXT, "

    "customGetter INTEGER, "
    "customSetter INTEGER, "

    "type INTEGER, "
    "ivar TEXT, "
    "readonly INTEGER, "
    "copy INTEGER, "
    "retained INTEGER, "
    "nonatomic INTEGER, "
    "dynamic INTEGER, "
    "weak INTEGER, "
    "canGC INTEGER, "

    "FOREIGN KEY(class) REFERENCES Class(id), "
    "FOREIGN KEY(customGetter) REFERENCES Selector(id), "
    "FOREIGN KEY(customSetter) REFERENCES Selector(id), "
    "FOREIGN KEY(image) REFERENCES MachO(id) "
");";

NSString * const kFREInsertProperty = @"INSERT INTO Property ( "
    "name, class, instance, attributes, image, "
    "customGetter, customSetter, type, ivar, readonly, "
    "copy, retained, nonatomic, dynamic, weak, canGC "
") VALUES ( "
    "$name, $class, $instance, $attributes, $image, "
    "$customGetter, $customSetter, $type, $ivar, $readonly, "
    "$copy, $retained, $nonatomic, $dynamic, $weak, $canGC "
");";

NSString * const kFRECreateTableIvarCommand = @"CREATE TABLE Ivar( "
    "id INTEGER PRIMARY KEY AUTOINCREMENT, "
    "name TEXT, "
    "offset INTEGER, "
    "type INTEGER, "
    "class INTEGER, "
    "image INTEGER, "

    "FOREIGN KEY(type) REFERENCES TypeEncoding(id), "
    "FOREIGN KEY(class) REFERENCES Class(id), "
    "FOREIGN KEY(image) REFERENCES MachO(id) "
");";

NSString * const kFREInsertIvar = @"INSERT INTO Ivar ( "
    "name, offset, type, class, image "
") VALUES ( "
    "$name, $offset, $type, $class, $image "
");";

NSString * const kFRECreateTableProtocolCommand = @"CREATE TABLE Protocol( "
    "id INTEGER PRIMARY KEY AUTOINCREMENT, "
    "name TEXT, "
    "image INTEGER, "

    "FOREIGN KEY(image) REFERENCES MachO(id) "
");";

NSString * const kFREInsertProtocol = @"INSERT INTO Protocol "
    "(name, image) VALUES ($name, $image);";

NSString * const kFRECreateTableProtocolPropertyCommand = @"CREATE TABLE ProtocolMember( "
    "id INTEGER PRIMARY KEY AUTOINCREMENT, "
    "protocol INTEGER, "
    "required INTEGER, "
    "instance INTEGER, " // 如果是类成员为0，如果是实例成员为1

    // 只使用下面两个之一
    "property TEXT, "
    "method TEXT, "

    "image INTEGER, "

    "FOREIGN KEY(protocol) REFERENCES Protocol(id), "
    "FOREIGN KEY(image) REFERENCES MachO(id) "
");";

NSString * const kFREInsertProtocolMember = @"INSERT INTO ProtocolMember ( "
    "protocol, required, instance, property, method, image "
") VALUES ( "
    "$protocol, $required, $instance, $property, $method, $image "
");";

/// 用于协议符合其他协议
NSString * const kFRECreateTableProtocolConformanceCommand = @"CREATE TABLE ProtocolConformance( "
    "protocol INTEGER, "
    "conformance INTEGER, "

    "FOREIGN KEY(protocol) REFERENCES Protocol(id), "
    "FOREIGN KEY(conformance) REFERENCES Protocol(id) "
");";

NSString * const kFREInsertProtocolConformance = @"INSERT INTO ProtocolConformance "
"(protocol, conformance) VALUES ($protocol, $conformance);";

/// 用于类符合协议
NSString * const kFRECreateTableClassConformanceCommand = @"CREATE TABLE ClassConformance( "
    "class INTEGER, "
    "conformance INTEGER, "

    "FOREIGN KEY(class) REFERENCES Class(id), "
    "FOREIGN KEY(conformance) REFERENCES Protocol(id) "
");";

NSString * const kFREInsertClassConformance = @"INSERT INTO ClassConformance "
"(class, conformance) VALUES ($class, $conformance);";

@interface FLEXRuntimeExporter ()
@property (nonatomic, readonly) FLEXSQLiteDatabaseManager *db;
@property (nonatomic, copy) NSArray<NSString *> *loadedShortBundleNames;
@property (nonatomic, copy) NSArray<NSString *> *loadedBundlePaths;
@property (nonatomic, copy) NSArray<FLEXProtocol *> *protocols;
@property (nonatomic, copy) NSArray<Class> *classes;

@property (nonatomic) NSMutableDictionary<NSString *, NSNumber *> *bundlePathsToIDs;
@property (nonatomic) NSMutableDictionary<NSString *, NSNumber *> *protocolsToIDs;
@property (nonatomic) NSMutableDictionary<Class, NSNumber *> *classesToIDs;
@property (nonatomic) NSMutableDictionary<NSString *, NSNumber *> *typeEncodingsToIDs;
@property (nonatomic) NSMutableDictionary<NSString *, NSNumber *> *methodSignaturesToIDs;
@property (nonatomic) NSMutableDictionary<NSString *, NSNumber *> *selectorsToIDs;
@end

@implementation FLEXRuntimeExporter

+ (NSString *)tempFilename {
    NSString *temp = NSTemporaryDirectory();
    NSString *uuid = [NSUUID.UUID.UUIDString substringToIndex:8];
    NSString *filename = [NSString stringWithFormat:@"FLEXRuntimeDatabase-%@.db", uuid];
    return [temp stringByAppendingPathComponent:filename];
}

+ (void)createRuntimeDatabaseAtPath:(NSString *)path
                    progressHandler:(void(^)(NSString *status))progress
                         completion:(void (^)(NSString *))completion {
    [self createRuntimeDatabaseAtPath:path forImages:nil progressHandler:progress completion:completion];
}

+ (void)createRuntimeDatabaseAtPath:(NSString *)path
                          forImages:(NSArray<NSString *> *)images
                    progressHandler:(void(^)(NSString *status))progress
                         completion:(void(^)(NSString *_Nullable error))completion {
    __typeof(completion) callback = ^(NSString *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(error);
        });
    };
    
    // 这必须首先在主线程上调用
    if (NSThread.isMainThread) {
        [FLEXRuntimeClient initializeWebKitLegacy];
    } else {
        dispatch_sync(dispatch_get_main_queue(), ^{
            [FLEXRuntimeClient initializeWebKitLegacy];
        });
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        NSError *error = nil;
        NSString *errorMessage = nil;
        
        // 获取未使用的临时文件名，如果存在则删除现有数据库
        NSString *tempPath = [self tempFilename];
        if ([NSFileManager.defaultManager fileExistsAtPath:tempPath]) {
            [NSFileManager.defaultManager removeItemAtPath:tempPath error:&error];
            if (error) {
                callback(error.localizedDescription);
                return;
            }
        }
        
        // 尝试创建并填充数据库，如果失败则中止
        FLEXRuntimeExporter *exporter = [self new];
        exporter.loadedBundlePaths = images;
        if (![exporter createAndPopulateDatabaseAtPath:tempPath
                                       progressHandler:progress
                                                 error:&errorMessage]) {
            // 如果未移动，则删除临时数据库
            if ([NSFileManager.defaultManager fileExistsAtPath:tempPath]) {
                [NSFileManager.defaultManager removeItemAtPath:tempPath error:nil];
            }
            
            callback(errorMessage);
            return;
        }
        
        // 删除给定路径上的旧数据库
        if ([NSFileManager.defaultManager fileExistsAtPath:path]) {
            [NSFileManager.defaultManager removeItemAtPath:path error:&error];
            if (error) {
                callback(error.localizedDescription);
                return;
            }
        }
        
        // 将新数据库移动到所需路径
        [NSFileManager.defaultManager moveItemAtPath:tempPath toPath:path error:&error];
        if (error) {
            callback(error.localizedDescription);
        }
        
        // 如果未移动，则删除临时数据库
        if ([NSFileManager.defaultManager fileExistsAtPath:tempPath]) {
            [NSFileManager.defaultManager removeItemAtPath:tempPath error:nil];
        }
        
        callback(nil);
    });
}

- (id)init {
    self = [super init];
    if (self) {
        _bundlePathsToIDs = [NSMutableDictionary new];
        _protocolsToIDs = [NSMutableDictionary new];
        _classesToIDs = [NSMutableDictionary new];
        _typeEncodingsToIDs = [NSMutableDictionary new];
        _methodSignaturesToIDs = [NSMutableDictionary new];
        _selectorsToIDs = [NSMutableDictionary new];
        
        _bundlePathsToIDs[NSNull.null] = (id)NSNull.null;
    }
    
    return self;
}

- (BOOL)createAndPopulateDatabaseAtPath:(NSString *)path
                        progressHandler:(void(^)(NSString *status))step
                                  error:(NSString **)error {
    _db = [FLEXSQLiteDatabaseManager managerForDatabase:path];
    
    [self loadMetadata:step];
    
    if ([self createTables] && [self addImages:step] && [self addProtocols:step] &&
        [self addClasses:step] && [self setSuperclasses:step] && 
        [self addProtocolConformances:step] && [self addClassConformances:step] &&
        [self addIvars:step] && [self addMethods:step] && [self addProperties:step]) {
        _db = nil; // 关闭数据库
        return YES;
    }
    
    *error = self.db.lastResult.message;
    return NO;
}

- (void)loadMetadata:(void(^)(NSString *status))progress {
    progress(@"正在加载元数据…");
    
    FLEXRuntimeClient *runtime = FLEXRuntimeClient.runtime;
    
    // 如果有现有路径，则仅加载这些路径的元数据
    if (self.loadedBundlePaths) {
        // 镜像
        self.loadedShortBundleNames = [self.loadedBundlePaths flex_mapped:^id(NSString *path, NSUInteger idx) {
            return [runtime shortNameForImageName:path];
        }];
        
        // 类
        self.classes = [[runtime classesForToken:FLEXSearchToken.any
            inBundles:self.loadedBundlePaths.mutableCopy
        ] flex_mapped:^id(NSString *cls, NSUInteger idx) {
            return NSClassFromString(cls);
        }];
    } else {
        // 镜像
        self.loadedShortBundleNames = runtime.imageDisplayNames;
        self.loadedBundlePaths = [self.loadedShortBundleNames flex_mapped:^id(NSString *name, NSUInteger idx) {
            return [runtime imageNameForShortName:name];
        }];
        
        // 类
        self.classes = [runtime copySafeClassList];
    }
    
    // ...除了协议，因为它们不多
    // 而且没有办法加载给定镜像的协议
    self.protocols = [[runtime copyProtocolList] flex_mapped:^id(Protocol *proto, NSUInteger idx) {
        return [FLEXProtocol protocol:proto];
    }];
}

- (BOOL)createTables {
    NSArray<NSString *> *commands = @[
        kFREEnableForeignKeys,
        kFRECreateTableMachOCommand,
        kFRECreateTableClassCommand,
        kFRECreateTableSelectorCommand,
        kFRECreateTableTypeEncodingCommand,
        kFRECreateTableTypeSignatureCommand,
        kFRECreateTableMethodSignatureCommand,
        kFRECreateTableMethodCommand,
        kFRECreateTablePropertyCommand,
        kFRECreateTableIvarCommand,
        kFRECreateTableProtocolCommand,
        kFRECreateTableProtocolPropertyCommand,
        kFRECreateTableProtocolConformanceCommand,
        kFRECreateTableClassConformanceCommand
    ];
    
    for (NSString *command in commands) {
        if (![self.db executeStatement:command]) {
            return NO;
        }
    }
    
    return YES;
}

- (BOOL)addImages:(void(^)(NSString *status))progress {
    progress(@"正在添加已加载的镜像…");
    
    FLEXSQLiteDatabaseManager *database = self.db;
    NSArray *shortNames = self.loadedShortBundleNames;
    NSArray *fullPaths = self.loadedBundlePaths;
    NSParameterAssert(shortNames.count == fullPaths.count);
    
    NSInteger count = shortNames.count;
    for (NSInteger i = 0; i < count; i++) {
        // 获取 bundle ID
        NSString *bundleID = [NSBundle
            bundleWithPath:fullPaths[i]
        ].bundleIdentifier; 
        
        [database executeStatement:kFREInsertImage arguments:@{
            @"$shortName": shortNames[i],
            @"$imagePath": fullPaths[i],
            @"$bundleID":  bundleID ?: NSNull.null
        }];
        
        if (database.lastResult.isError) {
            return NO;
        } else {
            self.bundlePathsToIDs[fullPaths[i]] = @(database.lastRowID);
        }
    }
    
    return YES;
}

NS_INLINE BOOL FREInsertProtocolMember(FLEXSQLiteDatabaseManager *db,
                                       id proto, id required, id instance,
                                       id prop, id methSel, id image) {
    return ![db executeStatement:kFREInsertProtocolMember arguments:@{
        @"$protocol": proto,
        @"$required": required,
        @"$instance": instance ?: NSNull.null,
        @"$property": prop ?: NSNull.null,
        @"$method": methSel ?: NSNull.null,
        @"$image": image
    }].isError;
}

- (BOOL)addProtocols:(void(^)(NSString *status))progress {
    progress([NSString stringWithFormat:@"正在添加 %@ 个协议…", @(self.protocols.count)]);
    
    FLEXSQLiteDatabaseManager *database = self.db;
    NSDictionary *imageIDs = self.bundlePathsToIDs;
    
    for (FLEXProtocol *proto in self.protocols) {
        id imagePath = proto.imagePath ?: NSNull.null;
        NSNumber *image = imageIDs[imagePath] ?: NSNull.null;
        NSNumber *pid = nil;
        
        // 插入协议
        BOOL failed = [database executeStatement:kFREInsertProtocol arguments:@{
            @"$name": proto.name, @"$image": image
        }].isError;
        
        // 缓存 rowid
        if (failed) {
            return NO;
        } else {
            self.protocolsToIDs[proto.name] = pid = @(database.lastRowID);
        }
        
        // 插入其成员 //
        
        // 必需的方法
        for (FLEXMethodDescription *method in proto.requiredMethods) {
            NSString *selector = NSStringFromSelector(method.selector);
            if (!FREInsertProtocolMember(database, pid, @YES, method.instance, nil, selector, image)) {
                return NO;
            }
        }
        // 可选的方法
        for (FLEXMethodDescription *method in proto.optionalMethods) {
            NSString *selector = NSStringFromSelector(method.selector);
            if (!FREInsertProtocolMember(database, pid, @NO, method.instance, nil, selector, image)) {
                return NO;
            }
        }
        
        if (@available(iOS 10, *)) {
            // 必需的属性
            for (FLEXProperty *property in proto.requiredProperties) {
                BOOL success = FREInsertProtocolMember(
                   database, pid, @YES, @(property.isClassProperty), property.name, NSNull.null, image
                );
                
                if (!success) return NO;
            }
            // 可选的属性
            for (FLEXProperty *property in proto.optionalProperties) {
                BOOL success = FREInsertProtocolMember(
                    database, pid, @NO, @(property.isClassProperty), property.name, NSNull.null, image
                );
                
                if (!success) return NO;
            }
        } else {
            // 仅...属性
            for (FLEXProperty *property in proto.properties) {
                BOOL success = FREInsertProtocolMember(
                    database, pid, nil, @(property.isClassProperty), property.name, NSNull.null, image
                );
                
                if (!success) return NO;
            }
        }
    }
    
    return YES;
}

- (BOOL)addProtocolConformances:(void(^)(NSString *status))progress {
    progress(@"正在添加协议到协议的遵循关系…");
    
    FLEXSQLiteDatabaseManager *database = self.db;
    NSDictionary *protocolIDs = self.protocolsToIDs;
    
    for (FLEXProtocol *proto in self.protocols) {
        id protoID = protocolIDs[proto.name];
        
        for (FLEXProtocol *conform in proto.protocols) {
            BOOL failed = [database executeStatement:kFREInsertProtocolConformance arguments:@{
                @"$protocol": protoID,
                @"$conformance": protocolIDs[conform.name]
            }].isError;
            
            if (failed) {
                return NO;
            }
        }
    }
    
    return YES;
}

- (BOOL)addClasses:(void(^)(NSString *status))progress {
    progress([NSString stringWithFormat:@"正在添加 %@ 个类…", @(self.classes.count)]);
    
    FLEXSQLiteDatabaseManager *database = self.db;
    NSDictionary *imageIDs = self.bundlePathsToIDs;
    
    for (Class cls in self.classes) {
        const char *imageName = class_getImageName(cls);
        id image = imageName ? imageIDs[@(imageName)] : NSNull.null;
        image = image ?: NSNull.null;
        
        BOOL failed = [database executeStatement:kFREInsertClass arguments:@{
            @"$className":    NSStringFromClass(cls),
            @"$instanceSize": @(class_getInstanceSize(cls)),
            @"$version":      @(class_getVersion(cls)),
            @"$image":        image
        }].isError;
        
        if (failed) {
            return NO;
        } else {
            self.classesToIDs[(id)cls] = @(database.lastRowID);
        }
    }
    
    return YES;
}

- (BOOL)setSuperclasses:(void(^)(NSString *status))progress {
    progress(@"正在设置父类…");
    
    FLEXSQLiteDatabaseManager *database = self.db;
    
    for (Class cls in self.classes) {
        // 获取父类 ID
        Class superclass = class_getSuperclass(cls);
        NSNumber *superclassID = _classesToIDs[class_getSuperclass(cls)];
        
        // ... 或者添加父类并缓存其 ID，如果
        // 父类不存在于目标镜像中
        if (!superclassID) {
            NSDictionary *args = @{ @"$className": NSStringFromClass(superclass) };
            BOOL failed = [database executeStatement:kFREInsertClass arguments:args].isError;
            if (failed) { return NO; }
            
            _classesToIDs[(id)superclass] = superclassID = @(database.lastRowID);
        }
        
        if (superclass) {
            BOOL failed = [database executeStatement:kFREUpdateClassSetSuper arguments:@{
                @"$super": superclassID, @"$id": _classesToIDs[cls]
            }].isError;
            
            if (failed) {
                return NO;
            }
        }
    }
    
    return YES;
}

- (BOOL)addClassConformances:(void(^)(NSString *status))progress {
    progress(@"正在添加类到协议的遵循关系…");
    
    FLEXSQLiteDatabaseManager *database = self.db;
    NSDictionary *protocolIDs = self.protocolsToIDs;
    NSDictionary *classIDs = self.classesToIDs;
    
    for (Class cls in self.classes) {
        id classID = classIDs[(id)cls];
        
        for (FLEXProtocol *conform in FLEXGetConformedProtocols(cls)) {
            BOOL failed = [database executeStatement:kFREInsertClassConformance arguments:@{
                @"$class": classID,
                @"$conformance": protocolIDs[conform.name]
            }].isError;
            
            if (failed) {
                return NO;
            }
        }
    }
    
    return YES;
}

- (BOOL)addIvars:(void(^)(NSString *status))progress {
    progress(@"正在添加实例变量…");
    
    FLEXSQLiteDatabaseManager *database = self.db;
    NSDictionary *imageIDs = self.bundlePathsToIDs;
    
    for (Class cls in self.classes) {
        for (FLEXIvar *ivar in FLEXGetAllIvars(cls)) {
            // 插入类型编码
            if (![self addTypeEncoding:ivar.typeEncoding size:ivar.size]) {
                return NO;
            }
            
            id imagePath = ivar.imagePath ?: NSNull.null;
            NSNumber *image = imageIDs[imagePath] ?: NSNull.null;
            
            BOOL failed = [database executeStatement:kFREInsertIvar arguments:@{
                @"$name":   ivar.name,
                @"$offset": @(ivar.offset),
                @"$type":   _typeEncodingsToIDs[ivar.typeEncoding],
                @"$class":  _classesToIDs[cls],
                @"$image":  image
            }].isError;
            
            if (failed) {
                return NO;
            }
        }
    }
    
    return YES;
}

- (BOOL)addMethods:(void(^)(NSString *status))progress {
    progress(@"正在添加方法…");
    
    FLEXSQLiteDatabaseManager *database = self.db;
    NSDictionary *imageIDs = self.bundlePathsToIDs;
    
    // 遍历所有类
    for (Class cls in self.classes) {
        NSNumber *classID = _classesToIDs[(id)cls];
        const char *imageName = class_getImageName(cls);
        id image = imageName ? imageIDs[@(imageName)] : NSNull.null;
        image = image ?: NSNull.null;
        
        // 用于处理每个消息的块
        BOOL (^insert)(FLEXMethod *, NSNumber *) = ^BOOL(FLEXMethod *method, NSNumber *instance) {
            // 首先插入选择器和签名
            if (![self addSelector:method.selectorString]) {
                return NO;
            }
            if (![self addMethodSignature:method]) {
                return NO;
            }
            
            return ![database executeStatement:kFREInsertMethod arguments:@{
                @"$sel":       self->_selectorsToIDs[method.selectorString],
                @"$class":     classID,
                @"$instance":  instance,
                @"$signature": self->_methodSignaturesToIDs[method.signatureString],
                @"$image":     image
            }].isError;
        };
        
        // 遍历该类的所有实例方法和类方法 //
        
        for (FLEXMethod *method in FLEXGetAllMethods(cls, YES)) {
            if (!insert(method, @YES)) {
                return NO;
            }
        }
        for (FLEXMethod *method in FLEXGetAllMethods(object_getClass(cls), NO)) {
            if (!insert(method, @NO)) {
                return NO;
            }
        }
    }
    
    return YES;
}

- (BOOL)addProperties:(void(^)(NSString *status))progress {
    progress(@"正在添加属性…");
    
    FLEXSQLiteDatabaseManager *database = self.db;
    NSDictionary *imageIDs = self.bundlePathsToIDs;
    
    // 遍历所有类
    for (Class cls in self.classes) {
        NSNumber *classID = _classesToIDs[(id)cls];
        
        // 用于处理每个消息的块
        BOOL (^insert)(FLEXProperty *, NSNumber *) = ^BOOL(FLEXProperty *property, NSNumber *instance) {
            FLEXPropertyAttributes *attrs = property.attributes;
            NSString *customGetter = attrs.customGetterString;
            NSString *customSetter = attrs.customSetterString;
            
            // 首先插入选择器
            if (customGetter) {
                if (![self addSelector:customGetter]) {
                    return NO;
                }
            }
            if (customSetter) {
                if (![self addSelector:customSetter]) {
                    return NO;
                }
            }
            
            // 首先插入类型编码
            NSInteger size = [FLEXTypeEncodingParser
                sizeForTypeEncoding:attrs.typeEncoding alignment:nil
            ];
            if (![self addTypeEncoding:attrs.typeEncoding size:size]) {
                return NO;
            }
            
            id imagePath = property.imagePath ?: NSNull.null;
            id image = imageIDs[imagePath] ?: NSNull.null;
            return ![database executeStatement:kFREInsertProperty arguments:@{
                @"$name":       property.name,
                @"$class":      classID,
                @"$instance":   instance,
                @"$image":      image,
                @"$attributes": attrs.string,
                
                @"$customGetter": self->_selectorsToIDs[customGetter] ?: NSNull.null,
                @"$customSetter": self->_selectorsToIDs[customSetter] ?: NSNull.null,
                
                @"$type":      self->_typeEncodingsToIDs[attrs.typeEncoding] ?: NSNull.null,
                @"$ivar":      attrs.backingIvar ?: NSNull.null,
                @"$readonly":  @(attrs.isReadOnly),
                @"$copy":      @(attrs.isCopy),
                @"$retained":  @(attrs.isRetained),
                @"$nonatomic": @(attrs.isNonatomic),
                @"$dynamic":   @(attrs.isDynamic),
                @"$weak":      @(attrs.isWeak),
                @"$canGC":     @(attrs.isGarbageCollectable),
            }].isError;
        };
        
        // 遍历该类的所有实例方法和类方法 //
        
        for (FLEXProperty *property in FLEXGetAllProperties(cls)) {
            if (!insert(property, @YES)) {
                return NO;
            }
        }
        for (FLEXProperty *property in FLEXGetAllProperties(object_getClass(cls))) {
            if (!insert(property, @NO)) {
                return NO;
            }
        }
    }
    
    return YES;
}

- (BOOL)addSelector:(NSString *)sel {
    return [self executeInsert:kFREInsertSelector args:@{
        @"$name": sel
    } key:sel cacheResult:_selectorsToIDs];
}

- (BOOL)addTypeEncoding:(NSString *)type size:(NSInteger)size {
    return [self executeInsert:kFREInsertTypeEncoding args:@{
        @"$type": type, @"$size": @(size)
    } key:type cacheResult:_typeEncodingsToIDs];
}

- (BOOL)addMethodSignature:(FLEXMethod *)method {
    NSString *signature = method.signatureString;
    NSString *returnType = @((char *)method.returnType);
    
    // 首先插入返回类型
    if (![self addTypeEncoding:returnType size:method.returnSize]) {
        return NO;
    }
    
    return [self executeInsert:kFREInsertMethodSignature args:@{
        @"$typeEncoding": signature,
        @"$returnType":   _typeEncodingsToIDs[returnType],
        @"$argc":         @(method.numberOfArguments),
        @"$frameLength":  @(method.signature.frameLength)
    } key:signature cacheResult:_methodSignaturesToIDs];
}

- (BOOL)executeInsert:(NSString *)statement
                 args:(NSDictionary *)args
                  key:(NSString *)cacheKey
          cacheResult:(NSMutableDictionary<NSString *, NSNumber *> *)rowids {
    // 检查是否已插入
    if (rowids[cacheKey]) {
        return YES;
    }
    
    // 插入
    FLEXSQLiteDatabaseManager *database = _db;
    [database executeStatement:statement arguments:args];
    
    if (database.lastResult.isError) {
        return NO;
    }
    
    // 缓存 rowid
    rowids[cacheKey] = @(database.lastRowID);
    return YES;
}

@end
