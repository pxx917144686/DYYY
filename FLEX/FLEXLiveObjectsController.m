//
//  FLEXLiveObjectsController.m
//  Flipboard
//
//  Created by Ryan Olson on 5/28/14.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

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
@property (nonatomic) UIActivityIndicatorView *loadingIndicator;

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
    
    // 添加加载指示器
    self.loadingIndicator = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.loadingIndicator.hidesWhenStopped = YES;
    self.loadingIndicator.center = CGPointMake(
        self.view.bounds.size.width / 2,
        self.view.bounds.size.height / 2 - 100
    );
    self.loadingIndicator.autoresizingMask =
        UIViewAutoresizingFlexibleTopMargin |
        UIViewAutoresizingFlexibleBottomMargin |
        UIViewAutoresizingFlexibleLeftMargin |
        UIViewAutoresizingFlexibleRightMargin;
    [self.tableView addSubview:self.loadingIndicator];
    
    // 异步加载数据，避免阻塞主线程
    self.headerTitle = @"正在扫描内存...";
    [self loadDataInBackground];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    // 更新加载指示器位置
    self.loadingIndicator.center = CGPointMake(
        self.tableView.bounds.size.width / 2,
        self.tableView.bounds.size.height / 2 - 100
    );
}

- (NSArray<NSString *> *)allClassNames {
    return self.instanceCountsForClassNames.allKeys;
}

- (void)loadDataInBackground {
    [self.loadingIndicator startAnimating];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // 在后台线程执行全堆枚举
        unsigned int classCount = 0;
        Class *classes = objc_copyClassList(&classCount);
        CFMutableDictionaryRef mutableCountsForClasses = CFDictionaryCreateMutable(NULL, classCount, NULL, NULL);
        for (unsigned int i = 0; i < classCount; i++) {
            CFDictionarySetValue(mutableCountsForClasses, (__bridge const void *)classes[i], (const void *)0);
        }
        
        // 枚举所有堆上的对象
        [FLEXHeapEnumerator enumerateLiveObjectsUsingBlock:^(__unsafe_unretained id object, __unsafe_unretained Class actualClass) {
            NSUInteger instanceCount = (NSUInteger)CFDictionaryGetValue(mutableCountsForClasses, (__bridge const void *)actualClass);
            instanceCount++;
            CFDictionarySetValue(mutableCountsForClasses, (__bridge const void *)actualClass, (const void *)instanceCount);
        }];
        
        // 转换结果
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
        CFRelease(mutableCountsForClasses);
        
        // 回到主线程更新UI
        dispatch_async(dispatch_get_main_queue(), ^{
            self.instanceCountsForClassNames = mutableCountsForClassNames;
            self.instanceSizesForClassNames = mutableSizesForClassNames;
            
            [self updateSearchResults:nil];
            [self.loadingIndicator stopAnimating];
        });
    });
}

- (void)reloadTableData {
    [self loadDataInBackground];
}

- (void)refreshControlDidRefresh:(id)sender {
    [self loadDataInBackground];
    // 延迟结束刷新，等待后台任务完成
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.refreshControl endRefreshing];
    });
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
        // Unfiltered
        self.headerTitle = [NSString
            stringWithFormat:@"%@ objects, %@",
            @(totalCount), [NSByteCountFormatter
                stringFromByteCount:totalSize
                countStyle:NSByteCountFormatterCountStyleFile
            ]
        ];
    } else {
        self.headerTitle = [NSString
            stringWithFormat:@"%@ of %@ objects, %@",
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


#pragma mark - Search bar

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
            // Reversed for descending counts.
            return [count2 compare:count1];
        }];
    } else if (selectedScope == kFLEXLiveObjectsSortBySizeIndex) {
        self.filteredClassNames = [self.filteredClassNames sortedArrayUsingComparator:^NSComparisonResult(NSString *className1, NSString *className2) {
            NSNumber *count1 = self.instanceCountsForClassNames[className1];
            NSNumber *count2 = self.instanceCountsForClassNames[className2];
            NSNumber *size1 = self.instanceSizesForClassNames[className1];
            NSNumber *size2 = self.instanceSizesForClassNames[className2];
            // Reversed for descending sizes.
            return [@(count2.integerValue * size2.integerValue) compare:@(count1.integerValue * size1.integerValue)];
        }];
    }
    
    [self updateHeaderTitle];
    [self.tableView reloadData];
}


#pragma mark - Table view data source

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
    cell.textLabel.text = [NSString stringWithFormat:@"%@ (%ld, %@)",
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


#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *className = self.filteredClassNames[indexPath.row];
    UIViewController *instances = [FLEXObjectListViewController
        instancesOfClassWithName:className
        retained:YES
    ];
    [self.navigationController pushViewController:instances animated:YES];
}

@end
