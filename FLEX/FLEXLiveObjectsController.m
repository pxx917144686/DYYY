//
//  FLEXLiveObjectsController.m
//  Flipboard
//
//  创建者: Ryan Olson on 5/28/14.
//  版权所有 (c) 2020 FLEX Team. 保留所有权利。
//

// 遇到问题联系中文翻译作者：pxx917144686

#import "FLEXLiveObjectsController.h"
#import "FLEXHeapEnumerator.h"
#import "FLEXObjectListViewController.h"
#import "FLEXUtility.h"
#import "FLEXScopeCarousel.h"
#import "FLEXTableView.h"
#import <objc/runtime.h>

static const NSInteger kFLEXLiveObjectsSortAlphabeticallyIndex = 0;
static const NSInteger kFLEXLiveObjectsSortByCountIndex = 1;
static const NSInteger kFLEXLiveObjectsSortBySizeIndex = 2;

@interface FLEXLiveObjectsController ()

@property (nonatomic) NSDictionary<NSString *, NSNumber *> *instanceCountsForClassNames;
@property (nonatomic) NSDictionary<NSString *, NSNumber *> *instanceSizesForClassNames;
@property (nonatomic, readonly) NSArray<NSString *> *allClassNames;
@property (nonatomic) NSArray<NSString *> *filteredClassNames;
@property (nonatomic) NSString *headerTitle;

@end

@implementation FLEXLiveObjectsController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.showsSearchBar = YES;
    self.showSearchBarInitially = YES;
    self.activatesSearchBarAutomatically = YES;
    self.searchBarDebounceInterval = kFLEXDebounceInstant;
    self.showsCarousel = YES;
    self.carousel.items = @[@"A→Z", @"总数", @"大小"];
    
    self.refreshControl = [UIRefreshControl new];
    [self.refreshControl addTarget:self action:@selector(refreshControlDidRefresh:) forControlEvents:UIControlEventValueChanged];
    
    [self reloadTableData];
}

- (NSArray<NSString *> *)allClassNames {
    return self.instanceCountsForClassNames.allKeys;
}

- (void)reloadTableData {
    // 设置一个带有类指针键和NSUInteger值的CFMutableDictionary。
    // 我们通过审慎的类型转换滥用CFMutableDictionary来拥有原始键，但它能完成工作。
    // 该字典初始化时为每个类设置0计数，这样在枚举期间它就不必扩展。
    // 虽然使用类名字符串键到NSNumber计数的NSMutableDictionary填充可能更清晰，
    // 但我们选择CF/原始类型方法，因为它让我们可以在不在枚举期间分配任何内存的情况下枚举堆中的对象。
    // 创建堆上每个对象的一个NSString/NSNumber的替代方案最终会相当严重地污染活动对象的计数。
    unsigned int classCount = 0;
    Class *classes = objc_copyClassList(&classCount);
    CFMutableDictionaryRef mutableCountsForClasses = CFDictionaryCreateMutable(NULL, classCount, NULL, NULL);
    for (unsigned int i = 0; i < classCount; i++) {
        CFDictionarySetValue(mutableCountsForClasses, (__bridge const void *)classes[i], (const void *)0);
    }
    
    // 枚举堆上的所有对象以构建每个类的实例计数。
    [FLEXHeapEnumerator enumerateLiveObjectsUsingBlock:^(__unsafe_unretained id object, __unsafe_unretained Class actualClass) {
        NSUInteger instanceCount = (NSUInteger)CFDictionaryGetValue(mutableCountsForClasses, (__bridge const void *)actualClass);
        instanceCount++;
        CFDictionarySetValue(mutableCountsForClasses, (__bridge const void *)actualClass, (const void *)instanceCount);
    }];
    
    // 将我们的CF原始字典转换为更好的类名字符串到计数的映射，我们将用作表的模型。
    NSMutableDictionary<NSString *, NSNumber *> *mutableCountsForClassNames = [NSMutableDictionary new];
    NSMutableDictionary<NSString *, NSNumber *> *mutableSizesForClassNames = [NSMutableDictionary new];
    for (unsigned int i = 0; i < classCount; i++) {
        Class class = classes[i];
        NSUInteger instanceCount = (NSUInteger)CFDictionaryGetValue(mutableCountsForClasses, (__bridge const void *)(class));
        NSString *className = @(class_getName(class));
        if (instanceCount > 0) {
            [mutableCountsForClassNames setObject:@(instanceCount) forKey:className];
        }
        [mutableSizesForClassNames setObject:@(class_getInstanceSize(class)) forKey:className];
    }
    free(classes);
    
    self.instanceCountsForClassNames = mutableCountsForClassNames;
    self.instanceSizesForClassNames = mutableSizesForClassNames;
    
    [self updateSearchResults:nil];
}

- (void)refreshControlDidRefresh:(id)sender {
    [self reloadTableData];
    [self.refreshControl endRefreshing];
}

- (void)updateHeaderTitle {
    NSUInteger totalCount = 0;
    NSUInteger totalSize = 0;
    for (NSString *className in self.allClassNames) {
        NSUInteger count = self.instanceCountsForClassNames[className].unsignedIntegerValue;
        totalCount += count;
        totalSize += count * self.instanceSizesForClassNames[className].unsignedIntegerValue;
    }

    NSUInteger filteredCount = 0;
    NSUInteger filteredSize = 0;
    for (NSString *className in self.filteredClassNames) {
        NSUInteger count = self.instanceCountsForClassNames[className].unsignedIntegerValue;
        filteredCount += count;
        filteredSize += count * self.instanceSizesForClassNames[className].unsignedIntegerValue;
    }
    
    if (filteredCount == totalCount) {
        // 未过滤
        self.headerTitle = [NSString
            stringWithFormat:@"%@ 个对象, %@",
            @(totalCount), [NSByteCountFormatter
                stringFromByteCount:totalSize
                countStyle:NSByteCountFormatterCountStyleFile
            ]
        ];
    } else {
        self.headerTitle = [NSString
            stringWithFormat:@"%@ / %@ 个对象, %@",
            @(filteredCount), @(totalCount), [NSByteCountFormatter
                stringFromByteCount:filteredSize
                countStyle:NSByteCountFormatterCountStyleFile
            ]
        ];
    }
}


#pragma mark - FLEXGlobalsEntry

+ (NSString *)globalsEntryTitle:(FLEXGlobalsRow)row {
    return @"💩  内存对象";
}

+ (UIViewController *)globalsEntryViewController:(FLEXGlobalsRow)row {
    FLEXLiveObjectsController *liveObjectsViewController = [self new];
    liveObjectsViewController.title = [self globalsEntryTitle:row];

    return liveObjectsViewController;
}


#pragma mark - 搜索栏

- (void)updateSearchResults:(NSString *)filter {
    NSInteger selectedScope = self.selectedScope;
    
    if (filter.length) {
        NSPredicate *searchPredicate = [NSPredicate predicateWithFormat:@"SELF CONTAINS[cd] %@", filter];
        self.filteredClassNames = [self.allClassNames filteredArrayUsingPredicate:searchPredicate];
    } else {
        self.filteredClassNames = self.allClassNames;
    }
    
    if (selectedScope == kFLEXLiveObjectsSortAlphabeticallyIndex) {
        self.filteredClassNames = [self.filteredClassNames sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    } else if (selectedScope == kFLEXLiveObjectsSortByCountIndex) {
        self.filteredClassNames = [self.filteredClassNames sortedArrayUsingComparator:^NSComparisonResult(NSString *className1, NSString *className2) {
            NSNumber *count1 = self.instanceCountsForClassNames[className1];
            NSNumber *count2 = self.instanceCountsForClassNames[className2];
            // 为了降序计数而反转
            return [count2 compare:count1];
        }];
    } else if (selectedScope == kFLEXLiveObjectsSortBySizeIndex) {
        self.filteredClassNames = [self.filteredClassNames sortedArrayUsingComparator:^NSComparisonResult(NSString *className1, NSString *className2) {
            NSNumber *count1 = self.instanceCountsForClassNames[className1];
            NSNumber *count2 = self.instanceCountsForClassNames[className2];
            NSNumber *size1 = self.instanceSizesForClassNames[className1];
            NSNumber *size2 = self.instanceSizesForClassNames[className2];
            // 为了降序大小而反转
            return [@(count2.integerValue * size2.integerValue) compare:@(count1.integerValue * size1.integerValue)];
        }];
    }
    
    [self updateHeaderTitle];
    [self.tableView reloadData];
}


#pragma mark - 表视图数据源

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.filteredClassNames.count;
}

- (UITableViewCell *)tableView:(__kindof UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView
        dequeueReusableCellWithIdentifier:kFLEXDefaultCell
        forIndexPath:indexPath
    ];

    NSString *className = self.filteredClassNames[indexPath.row];
    NSNumber *count = self.instanceCountsForClassNames[className];
    NSNumber *size = self.instanceSizesForClassNames[className];
    unsigned long totalSize = count.unsignedIntegerValue * size.unsignedIntegerValue;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.textLabel.text = [NSString stringWithFormat:@"%@ (数量:%ld, 大小:%@)",
        className, (long)[count integerValue],
        [NSByteCountFormatter
            stringFromByteCount:totalSize
            countStyle:NSByteCountFormatterCountStyleFile
        ]
    ];
    
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.headerTitle;
}


#pragma mark - 表视图代理

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *className = self.filteredClassNames[indexPath.row];
    UIViewController *instances = [FLEXObjectListViewController
        instancesOfClassWithName:className
        retained:YES
    ];
    [self.navigationController pushViewController:instances animated:YES];
}

@end
