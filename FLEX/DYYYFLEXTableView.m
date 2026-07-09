//
//  DYYYFLEXTableView.m
//  FLEX
//
//  Created by Tanner on 4/17/19.
//  Copyright © 2020 FLEX Team. All rights reserved.
//

#import "DYYYFLEXTableView.h"
#import "DYYYFLEXUtility.h"
#import "DYYYFLEXSubtitleTableViewCell.h"
#import "DYYYFLEXMultilineTableViewCell.h"
#import "DYYYFLEXKeyValueTableViewCell.h"
#import "DYYYFLEXCodeFontCell.h"

FLEXTableViewCellReuseIdentifier const kFLEXDefaultCell = @"kFLEXDefaultCell";
FLEXTableViewCellReuseIdentifier const kFLEXDetailCell = @"kFLEXDetailCell";
FLEXTableViewCellReuseIdentifier const kFLEXMultilineCell = @"kFLEXMultilineCell";
FLEXTableViewCellReuseIdentifier const kFLEXMultilineDetailCell = @"kFLEXMultilineDetailCell";
FLEXTableViewCellReuseIdentifier const kFLEXKeyValueCell = @"kFLEXKeyValueCell";
FLEXTableViewCellReuseIdentifier const kFLEXCodeFontCell = @"kFLEXCodeFontCell";

#pragma mark Private

@interface UITableView (Private)
- (CGFloat)_heightForHeaderInSection:(NSInteger)section;
- (NSString *)_titleForHeaderInSection:(NSInteger)section;
@end

@implementation DYYYFLEXTableView

+ (instancetype)flexDefaultTableView {
    if (@available(iOS 13.0, *)) {
        return [[self alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    } else {
        return [[self alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
    }
}

#pragma mark - Initialization

+ (id)groupedTableView {
    if (@available(iOS 13.0, *)) {
        return [[self alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    } else {
        return [[self alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
    }
}

+ (id)plainTableView {
    return [[self alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
}

+ (id)style:(UITableViewStyle)style {
    return [[self alloc] initWithFrame:CGRectZero style:style];
}

- (id)initWithFrame:(CGRect)frame style:(UITableViewStyle)style {
    self = [super initWithFrame:frame style:style];
    if (self) {
        [self registerCells:@{
            kFLEXDefaultCell : [DYYYFLEXTableViewCell class],
            kFLEXDetailCell : [DYYYFLEXSubtitleTableViewCell class],
            kFLEXMultilineCell : [DYYYFLEXMultilineTableViewCell class],
            kFLEXMultilineDetailCell : [DYYYFLEXMultilineDetailTableViewCell class],
            kFLEXKeyValueCell : [DYYYFLEXKeyValueTableViewCell class],
            kFLEXCodeFontCell : [DYYYFLEXCodeFontCell class],
        }];
    }

    return self;
}


#pragma mark - Public

- (void)registerCells:(NSDictionary<NSString*, Class> *)registrationMapping {
    [registrationMapping enumerateKeysAndObjectsUsingBlock:^(NSString *identifier, Class cellClass, BOOL *stop) {
        [self registerClass:cellClass forCellReuseIdentifier:identifier];
    }];
}

@end
