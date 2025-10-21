//
//  FLEXMemoryAnalyzerViewController.m
//  FLEX
//
//  Created from RuntimeBrowser functionalities.
//

#import "FLEXMemoryAnalyzerViewController.h"
#import "FLEXMemoryAnalyzer.h"

@interface FLEXMemoryAnalyzerViewController ()
@property (nonatomic, strong) NSDictionary *memoryUsage;
@property (nonatomic, strong) NSArray *classes;
@end

@implementation FLEXMemoryAnalyzerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"内存分析器";
    
    [self refreshMemoryData];
    
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(refreshMemoryData) forControlEvents:UIControlEventValueChanged];
}

- (void)refreshMemoryData {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        FLEXMemoryAnalyzer *analyzer = [FLEXMemoryAnalyzer sharedAnalyzer];
        self.memoryUsage = [analyzer getAllClassesMemoryUsage];
        self.classes = [self.memoryUsage.allKeys sortedArrayUsingSelector:@selector(compare:)];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.tableView reloadData];
            [self.refreshControl endRefreshing];
        });
    });
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.classes.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier];
    }
    
    NSString *className = self.classes[indexPath.row];
    NSDictionary *classData = self.memoryUsage[className];
    
    cell.textLabel.text = className;
    
    NSUInteger instanceSize = [classData[@"instanceSize"] unsignedIntegerValue];
    NSUInteger instanceCount = [classData[@"instanceCount"] unsignedIntegerValue];
    
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%lu × %lu bytes", 
                                (unsigned long)instanceCount, 
                                (unsigned long)instanceSize];
    
    return cell;
}

@end