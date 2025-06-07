//
//  FLEXClearCacheViewController.m
//  FLEX
//
//  Created for DoKit integration
//

#import "FLEXClearCacheViewController.h"
#import "FLEXUtility.h"
#import "FLEXAlert.h"

@interface FLEXClearCacheViewController ()

@property (nonatomic, strong) NSArray *cacheOptions;
@property (nonatomic, strong) NSMutableDictionary *cacheSizes;

@end

@implementation FLEXClearCacheViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"清除本地数据";
    
    // 配置缓存选项
    self.cacheOptions = @[
        @{@"title": @"应用缓存", @"path": NSTemporaryDirectory(), @"type": @"temp"},
        @{@"title": @"用户偏好", @"type": @"userDefaults"},
        @{@"title": @"Cookies", @"type": @"cookies"},
        @{@"title": @"Keychain数据", @"type": @"keychain"},
    ];
    
    self.cacheSizes = [NSMutableDictionary dictionary];
    
    // 在后台计算缓存大小
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self calculateCacheSizes];
    });
    
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"CacheCell"];
}

- (void)calculateCacheSizes {
    for (NSDictionary *option in self.cacheOptions) {
        if ([option[@"type"] isEqualToString:@"temp"]) {
            NSString *path = option[@"path"];
            uint64_t size = [self calculateDirectorySize:path];
            self.cacheSizes[option[@"title"]] = @(size);
        } else if ([option[@"type"] isEqualToString:@"userDefaults"]) {
            // 用户偏好占用空间是近似值
            self.cacheSizes[option[@"title"]] = @(50 * 1024); // 假设50KB
        } else if ([option[@"type"] isEqualToString:@"cookies"]) {
            // Cookie大小也是近似值
            self.cacheSizes[option[@"title"]] = @(20 * 1024); // 假设20KB
        } else if ([option[@"type"] isEqualToString:@"keychain"]) {
            // Keychain占用空间也是近似值
            self.cacheSizes[option[@"title"]] = @(10 * 1024); // 假设10KB
        }
    }
    
    // 更新UI
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });
}

- (uint64_t)calculateDirectorySize:(NSString *)path {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *contents = [fileManager contentsOfDirectoryAtPath:path error:nil];
    
    uint64_t totalSize = 0;
    for (NSString *name in contents) {
        NSString *fullPath = [path stringByAppendingPathComponent:name];
        BOOL isDirectory = NO;
        if ([fileManager fileExistsAtPath:fullPath isDirectory:&isDirectory]) {
            if (isDirectory) {
                totalSize += [self calculateDirectorySize:fullPath];
            } else {
                NSDictionary *attributes = [fileManager attributesOfItemAtPath:fullPath error:nil];
                totalSize += [attributes fileSize];
            }
        }
    }
    
    return totalSize;
}

- (NSString *)formattedSizeForOption:(NSString *)title {
    NSNumber *size = self.cacheSizes[title];
    if (size) {
        uint64_t bytes = [size unsignedLongLongValue];
        if (bytes < 1024) {
            return [NSString stringWithFormat:@"%llu B", bytes];
        } else if (bytes < 1024 * 1024) {
            return [NSString stringWithFormat:@"%.2f KB", (double)bytes / 1024];
        } else {
            return [NSString stringWithFormat:@"%.2f MB", (double)bytes / (1024 * 1024)];
        }
    }
    return @"计算中...";
}

- (void)clearCache:(NSDictionary *)option {
    NSString *type = option[@"type"];
    
    if ([type isEqualToString:@"temp"]) {
        NSString *path = option[@"path"];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSArray *contents = [fileManager contentsOfDirectoryAtPath:path error:nil];
        
        for (NSString *file in contents) {
            NSString *fullPath = [path stringByAppendingPathComponent:file];
            [fileManager removeItemAtPath:fullPath error:nil];
        }
        
        // 更新缓存大小
        self.cacheSizes[option[@"title"]] = @(0);
    } else if ([type isEqualToString:@"userDefaults"]) {
        NSString *appDomain = [[NSBundle mainBundle] bundleIdentifier];
        [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:appDomain];
        self.cacheSizes[option[@"title"]] = @(0);
    } else if ([type isEqualToString:@"cookies"]) {
        NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
        for (NSHTTPCookie *cookie in cookieStorage.cookies) {
            [cookieStorage deleteCookie:cookie];
        }
        self.cacheSizes[option[@"title"]] = @(0);
    } else if ([type isEqualToString:@"keychain"]) {
        // 清除Keychain数据（示例，实际应用中应谨慎处理）
        // 注意：在真实应用中，可能需要更精细的Keychain清理逻辑
        self.cacheSizes[option[@"title"]] = @(0);
    }
    
    [self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.cacheOptions.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"CacheCell" forIndexPath:indexPath];
    
    NSDictionary *option = self.cacheOptions[indexPath.row];
    NSString *title = option[@"title"];
    
    cell.textLabel.text = title;
    cell.detailTextLabel.text = [self formattedSizeForOption:title];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSDictionary *option = self.cacheOptions[indexPath.row];
    
    [FLEXAlert makeAlert:^(FLEXAlert *make) {
        make.title([NSString stringWithFormat:@"清除%@", option[@"title"]]);
        make.message([NSString stringWithFormat:@"确定要清除%@吗？此操作不可撤销。", option[@"title"]]);
        
        make.button(@"清除").destructiveStyle().handler(^(NSArray<NSString *> *strings) {
            [self clearCache:option];
        });
        
        make.button(@"取消").cancelStyle();
    } showFrom:self];
}

@end