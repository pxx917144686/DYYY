//
//  FLEXVisualToolsViewController.m
//  FLEX
//
//  Copyright © 2023 FLEX Team. All rights reserved.
//

#import "FLEXVisualToolsViewController.h"
#import "FLEXColorPickerTool.h"
#import "FLEXRulerTool.h"

@interface FLEXVisualToolsViewController ()

@property (nonatomic, strong) NSArray *toolsList;

@end

@implementation FLEXVisualToolsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"视觉工具";
    self.toolsList = @[
        @{@"title": @"颜色拾取器", @"detail": @"拾取屏幕上的颜色"},
        @{@"title": @"对齐标尺", @"detail": @"测量UI元素的尺寸"}
    ];
    
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"ToolCell"];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.toolsList.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ToolCell" forIndexPath:indexPath];
    
    NSDictionary *tool = self.toolsList[indexPath.row];
    cell.textLabel.text = tool[@"title"];
    cell.detailTextLabel.text = tool[@"detail"];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    switch (indexPath.row) {
        case 0: // 颜色拾取器
            [self dismissViewControllerAnimated:YES completion:^{
                [[FLEXColorPickerTool sharedInstance] show];
            }];
            break;
            
        case 1: // 对齐标尺
            [self dismissViewControllerAnimated:YES completion:^{
                [[FLEXRulerTool sharedInstance] show];
            }];
            break;
            
        default:
            break;
    }
}

@end