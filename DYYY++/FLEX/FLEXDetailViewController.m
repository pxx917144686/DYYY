#import "FLEXDetailViewController.h"
#import "FLEXTableView.h"

@interface FLEXDetailViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *keys;
@end

@implementation FLEXDetailViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"Cell"];
    [self.view addSubview:self.tableView];
    
    // 解析数据
    if ([self.data isKindOfClass:[NSDictionary class]]) {
        self.keys = [[(NSDictionary *)self.data allKeys] sortedArrayUsingSelector:@selector(compare:)];
    } else if ([self.data isKindOfClass:[NSArray class]]) {
        NSMutableArray *indices = [NSMutableArray array];
        for (NSUInteger i = 0; i < [(NSArray *)self.data count]; i++) {
            [indices addObject:@(i)];
        }
        self.keys = indices;
    } else {
        self.keys = @[];
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.keys.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    
    id key = self.keys[indexPath.row];
    id value = nil;
    
    if ([self.data isKindOfClass:[NSDictionary class]]) {
        value = [(NSDictionary *)self.data objectForKey:key];
        cell.textLabel.text = [NSString stringWithFormat:@"%@: %@", key, [value description]];
    } else if ([self.data isKindOfClass:[NSArray class]]) {
        value = [(NSArray *)self.data objectAtIndex:[key integerValue]];
        cell.textLabel.text = [NSString stringWithFormat:@"[%@]: %@", key, [value description]];
    }
    
    return cell;
}

@end