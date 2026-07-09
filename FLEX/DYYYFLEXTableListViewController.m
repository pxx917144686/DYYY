//
//  PTTableListViewController.m
//  PTDatabaseReader
//
//  由 Peng Tao 创建于 15/11/23.
//  版权所有 © 2015年 Peng Tao. 保留所有权利。
//

#import "DYYYFLEXTableListViewController.h"
#import "FLEXDatabaseManager.h"
#import "DYYYFLEXSQLiteDatabaseManager.h"
#import "DYYYFLEXRealmDatabaseManager.h"
#import "DYYYFLEXTableContentViewController.h"
#import "DYYYFLEXMutableListSection.h"
#import "NSArray+FLEX.h"
#import "DYYYFLEXAlert.h"
#import "FLEXMacros.h"

@interface DYYYFLEXTableListViewController ()
@property (nonatomic, readonly) id<FLEXDatabaseManager> dbm;
@property (nonatomic, readonly) NSString *path;

@property (nonatomic, readonly) DYYYFLEXMutableListSection<NSString *> *tables;

+ (NSArray<NSString *> *)supportedSQLiteExtensions;
+ (NSArray<NSString *> *)supportedRealmExtensions;

@end

@implementation DYYYFLEXTableListViewController

- (instancetype)initWithPath:(NSString *)path {
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        _path = path.copy;
        _dbm = [self databaseManagerForFileAtPath:path];
    }
    
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.showsSearchBar = YES;
    
    // 撰写查询按钮 //

    UIBarButtonItem *composeQuery = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemCompose
        target:self
        action:@selector(queryButtonPressed)
    ];
    // 无法在 realm 数据库上运行自定义查询
    composeQuery.enabled = [self.dbm
        respondsToSelector:@selector(executeStatement:)
    ];
    
    [self addToolbarItems:@[composeQuery]];
}

- (NSArray<DYYYFLEXTableViewSection *> *)makeSections {
    _tables = [DYYYFLEXMutableListSection list:[self.dbm queryAllTables]
        cellConfiguration:^(__kindof UITableViewCell *cell, NSString *tableName, NSInteger row) {
            cell.textLabel.text = tableName;
        } filterMatcher:^BOOL(NSString *filterText, NSString *tableName) {
            return [tableName localizedCaseInsensitiveContainsString:filterText];
        }
    ];
    
    self.tables.selectionHandler = ^(DYYYFLEXTableListViewController *host, NSString *tableName) {
        NSArray *rows = [host.dbm queryAllDataInTable:tableName];
        NSArray *columns = [host.dbm queryAllColumnsOfTable:tableName];
        NSArray *rowIDs = nil;
        if ([host.dbm respondsToSelector:@selector(queryRowIDsInTable:)]) {        
            rowIDs = [host.dbm queryRowIDsInTable:tableName];
        }
        UIViewController *resultsScreen = [DYYYFLEXTableContentViewController
            columns:columns rows:rows rowIDs:rowIDs tableName:tableName database:host.dbm
        ];
        [host.navigationController pushViewController:resultsScreen animated:YES];
    };
    
    return @[self.tables];
}

- (void)reloadData {
    self.tables.customTitle = [NSString
        stringWithFormat:@"表 (%@)", @(self.tables.filteredList.count)
    ];
    
    [super reloadData];
}
    
- (void)queryButtonPressed {
    [self showQueryInput:nil];
}

- (void)showQueryInput:(NSString *)prefillQuery {
    DYYYFLEXSQLiteDatabaseManager *database = self.dbm;
    
    [DYYYFLEXAlert makeAlert:^(DYYYFLEXAlert *make) {
        make.title(@"执行 SQL 查询");
        make.configuredTextField(^(UITextField *textField) {
            textField.text = prefillQuery;
        });
        
        make.button(@"运行").handler(^(NSArray<NSString *> *strings) {
            NSString *query = strings[0];
            DYYYFLEXSQLResult *result = [database executeStatement:query];
            
            if (result.message) {
                // 如果查询有错误，允许用户编辑他们的最后一个查询
                if ([result.message containsString:@"error"]) {
                    [DYYYFLEXAlert makeAlert:^(DYYYFLEXAlert *make) {
                        make.title(@"错误").message(result.message);
                        make.button(@"编辑查询").preferred().handler(^(NSArray<NSString *> *_) {
                            // 再次显示查询编辑器，包含我们上次的输入
                            [self showQueryInput:query];
                        });
                        
                        make.button(@"取消").cancelStyle();
                    } showFrom:self];
                } else {
                    [DYYYFLEXAlert showAlert:@"消息" message:result.message from:self];
                }
            } else {
                UIViewController *resultsScreen = [DYYYFLEXTableContentViewController
                    columns:result.columns rows:result.rows
                ];
                
                [self.navigationController pushViewController:resultsScreen animated:YES];
            }
        });
        make.button(@"取消").cancelStyle();
    } showFrom:self];
}
    
- (id<FLEXDatabaseManager>)databaseManagerForFileAtPath:(NSString *)path {
    NSString *pathExtension = path.pathExtension.lowercaseString;
    
    NSArray<NSString *> *sqliteExtensions = DYYYFLEXTableListViewController.supportedSQLiteExtensions;
    if ([sqliteExtensions indexOfObject:pathExtension] != NSNotFound) {
        return [DYYYFLEXSQLiteDatabaseManager managerForDatabase:path];
    }
    
    NSArray<NSString *> *realmExtensions = DYYYFLEXTableListViewController.supportedRealmExtensions;
    if (realmExtensions != nil && [realmExtensions indexOfObject:pathExtension] != NSNotFound) {
        return [DYYYFLEXRealmDatabaseManager managerForDatabase:path];
    }
    
    return nil;
}


#pragma mark - DYYYFLEXTableListViewController

+ (BOOL)supportsExtension:(NSString *)extension {
    extension = extension.lowercaseString;
    
    NSArray<NSString *> *sqliteExtensions = DYYYFLEXTableListViewController.supportedSQLiteExtensions;
    if (sqliteExtensions.count > 0 && [sqliteExtensions indexOfObject:extension] != NSNotFound) {
        return YES;
    }
    
    NSArray<NSString *> *realmExtensions = DYYYFLEXTableListViewController.supportedRealmExtensions;
    if (realmExtensions.count > 0 && [realmExtensions indexOfObject:extension] != NSNotFound) {
        return YES;
    }
    
    return NO;
}

+ (NSArray<NSString *> *)supportedSQLiteExtensions {
    return @[@"db", @"sqlite", @"sqlite3"];
}

+ (NSArray<NSString *> *)supportedRealmExtensions {
    if (NSClassFromString(@"RLMRealm") == nil) {
        return nil;
    }
    
    return @[@"realm"];
}

@end
