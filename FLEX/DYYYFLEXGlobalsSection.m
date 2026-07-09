//
//  DYYYFLEXGlobalsSection.m
//  FLEX
//
//  Created by Tanner Bennett on 7/11/19.
//  Copyright © 2020 FLEX Team. All rights reserved.
//

#import "DYYYFLEXGlobalsSection.h"
#import "NSArray+FLEX.h"
#import "UIFont+FLEX.h"

@interface DYYYFLEXGlobalsSection ()
/// Filtered rows
@property (nonatomic) NSArray<DYYYFLEXGlobalsEntry *> *rows;
/// Unfiltered rows
@property (nonatomic) NSArray<DYYYFLEXGlobalsEntry *> *allRows;
@end
@implementation DYYYFLEXGlobalsSection

#pragma mark - Initialization

+ (instancetype)title:(NSString *)title rows:(NSArray<DYYYFLEXGlobalsEntry *> *)rows {
    DYYYFLEXGlobalsSection *s = [self new];
    s->_title = title;
    s.allRows = rows;

    return s;
}

- (void)setAllRows:(NSArray<DYYYFLEXGlobalsEntry *> *)allRows {
    _allRows = allRows.copy;
    [self reloadData];
}

#pragma mark - Overrides

- (NSInteger)numberOfRows {
    return self.rows.count;
}

- (void)setFilterText:(NSString *)filterText {
    super.filterText = filterText;
    [self reloadData];
}

- (void)reloadData {
    NSString *filterText = self.filterText;
    
    if (filterText.length) {
        self.rows = [self.allRows flex_filtered:^BOOL(DYYYFLEXGlobalsEntry *entry, NSUInteger idx) {
            return [entry.entryNameFuture() localizedCaseInsensitiveContainsString:filterText];
        }];
    } else {
        self.rows = self.allRows;
    }
}

- (BOOL)canSelectRow:(NSInteger)row {
    return YES;
}

- (void (^)(__kindof UIViewController *))didSelectRowAction:(NSInteger)row {
    return (id)self.rows[row].rowAction;
}

- (UIViewController *)viewControllerToPushForRow:(NSInteger)row {
    return self.rows[row].viewControllerFuture ? self.rows[row].viewControllerFuture() : nil;
}

- (void)configureCell:(__kindof UITableViewCell *)cell forRow:(NSInteger)row {
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.textLabel.font = UIFont.flex_defaultTableCellFont;
    cell.textLabel.text = self.rows[row].entryNameFuture();
}

@end


@implementation DYYYFLEXGlobalsSection (Subscripting)

- (id)objectAtIndexedSubscript:(NSUInteger)idx {
    return self.rows[idx];
}

@end
