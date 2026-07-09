//
//  DYYYFLEXTableRowDataViewController.m
//  FLEX
//
//  由 Chaoshuai Lu 创建于 7/8/20.
//

#import "DYYYFLEXTableRowDataViewController.h"
#import "DYYYFLEXMutableListSection.h"
#import "DYYYFLEXAlert.h"

@interface DYYYFLEXTableRowDataViewController ()
@property (nonatomic) NSDictionary<NSString *, NSString *> *rowsByColumn;
@end

@implementation DYYYFLEXTableRowDataViewController

#pragma mark - 初始化

+ (instancetype)rows:(NSDictionary<NSString *, id> *)rowData {
    DYYYFLEXTableRowDataViewController *controller = [self new];
    controller.rowsByColumn = rowData;
    return controller;
}

#pragma mark - 重写

- (NSArray<DYYYFLEXTableViewSection *> *)makeSections {
    NSDictionary<NSString *, NSString *> *rowsByColumn = self.rowsByColumn;
    
    DYYYFLEXMutableListSection<NSString *> *section = [DYYYFLEXMutableListSection list:self.rowsByColumn.allKeys
        cellConfiguration:^(UITableViewCell *cell, NSString *column, NSInteger row) {
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.textLabel.text = column;
            cell.detailTextLabel.text = rowsByColumn[column].description;
        } filterMatcher:^BOOL(NSString *filterText, NSString *column) {
            return [column localizedCaseInsensitiveContainsString:filterText] ||
                [rowsByColumn[column] localizedCaseInsensitiveContainsString:filterText];
        }
    ];
    
    section.selectionHandler = ^(UIViewController *host, NSString *column) {
        UIPasteboard.generalPasteboard.string = rowsByColumn[column].description;
        [DYYYFLEXAlert makeAlert:^(DYYYFLEXAlert *make) {
            make.title(@"列已复制到剪贴板");
            make.message(rowsByColumn[column].description);
            make.button(@"关闭").cancelStyle();
        } showFrom:host];
    };

    return @[section];
}

@end
