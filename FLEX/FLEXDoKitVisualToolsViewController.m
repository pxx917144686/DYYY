#import "FLEXDoKitVisualToolsViewController.h"
#import "FLEXDoKitVisualTools.h"
#import "FLEXLookinMeasureController.h"

@interface FLEXDoKitVisualToolsViewController ()
@property (nonatomic, strong) NSArray *visualTools;
@end

@implementation FLEXDoKitVisualToolsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"视觉工具";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    
    self.visualTools = @[
        @{@"title": @"颜色吸管", @"detail": @"屏幕取色工具", @"action": @"showColorPicker"},
        @{@"title": @"对齐标尺", @"detail": @"UI测量工具", @"action": @"showRuler"},
        @{@"title": @"视图边框", @"detail": @"显示视图边框", @"action": @"showViewBorders"},
        @{@"title": @"布局边界", @"detail": @"显示布局约束", @"action": @"showLayoutBounds"},
        @{@"title": @"Lookin测量", @"detail": @"精确距离测量", @"action": @"showLookinMeasure"}
    ];
    
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"VisualToolCell"];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.visualTools.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"VisualToolCell" forIndexPath:indexPath];
    
    NSDictionary *tool = self.visualTools[indexPath.row];
    cell.textLabel.text = tool[@"title"];
    cell.detailTextLabel.text = tool[@"detail"];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    // 设置cell样式
    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"VisualToolCell"];
    cell.textLabel.text = tool[@"title"];
    cell.detailTextLabel.text = tool[@"detail"];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSDictionary *tool = self.visualTools[indexPath.row];
    NSString *action = tool[@"action"];
    
    SEL actionSelector = NSSelectorFromString(action);
    if ([self respondsToSelector:actionSelector]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:actionSelector];
#pragma clang diagnostic pop
    }
}

#pragma mark - Actions

- (void)showColorPicker {
    [self dismissViewControllerAnimated:YES completion:^{
        [[FLEXDoKitVisualTools sharedInstance] startColorPicker];
    }];
}

- (void)showRuler {
    [self dismissViewControllerAnimated:YES completion:^{
        [[FLEXDoKitVisualTools sharedInstance] showRuler];
    }];
}

- (void)showViewBorders {
    [self dismissViewControllerAnimated:YES completion:^{
        [[FLEXDoKitVisualTools sharedInstance] showViewBorders];
    }];
}

- (void)showLayoutBounds {
    [self dismissViewControllerAnimated:YES completion:^{
        [[FLEXDoKitVisualTools sharedInstance] showLayoutBounds];
    }];
}

- (void)showLookinMeasure {
    [self dismissViewControllerAnimated:YES completion:^{
        [[FLEXLookinMeasureController sharedInstance] startMeasuring];
    }];
}

@end