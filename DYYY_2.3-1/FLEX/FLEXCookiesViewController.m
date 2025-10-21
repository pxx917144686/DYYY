//
//  FLEXCookiesViewController.m
//  FLEX
//
//  Created by Rich Robinson on 19/10/2015.
//  Copyright © 2020 FLEX Team. All rights reserved.
//

#import "FLEXCookiesViewController.h"
#import "FLEXObjectExplorerFactory.h"
#import "FLEXMutableListSection.h"
#import "FLEXUtility.h"

@interface FLEXCookiesViewController ()
@property (nonatomic, readonly) FLEXMutableListSection<NSHTTPCookie *> *cookies;
@property (nonatomic) NSString *headerTitle;
@end

@implementation FLEXCookiesViewController

#pragma mark - 重写

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Cookie缓存";
}

- (NSString *)headerTitle {
    return self.cookies.title;
}

- (void)setHeaderTitle:(NSString *)headerTitle {
    self.cookies.customTitle = headerTitle;
}

- (NSArray<FLEXTableViewSection *> *)makeSections {
    NSSortDescriptor *nameSortDescriptor = [[NSSortDescriptor alloc]
        initWithKey:@"name" ascending:YES selector:@selector(caseInsensitiveCompare:)
    ];
    NSArray *cookies = [NSHTTPCookieStorage.sharedHTTPCookieStorage.cookies
       sortedArrayUsingDescriptors:@[nameSortDescriptor]
    ];
    
    _cookies = [FLEXMutableListSection list:cookies
        cellConfiguration:^(UITableViewCell *cell, NSHTTPCookie *cookie, NSInteger row) {
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.textLabel.text = [cookie.name stringByAppendingFormat:@" (%@)", cookie.value];
            cell.detailTextLabel.text = [cookie.domain stringByAppendingFormat:@" — %@", cookie.path];
        } filterMatcher:^BOOL(NSString *filterText, NSHTTPCookie *cookie) {
            return [cookie.name localizedCaseInsensitiveContainsString:filterText] ||
                [cookie.value localizedCaseInsensitiveContainsString:filterText] ||
                [cookie.domain localizedCaseInsensitiveContainsString:filterText] ||
                [cookie.path localizedCaseInsensitiveContainsString:filterText];
        }
    ];
    
    self.cookies.selectionHandler = ^(UIViewController *host, NSHTTPCookie *cookie) {
        [host.navigationController pushViewController:[
            FLEXObjectExplorerFactory explorerViewControllerForObject:cookie
        ] animated:YES];
    };
    
    return @[self.cookies];
}

- (void)reloadData {
    self.headerTitle = [NSString stringWithFormat:
        @"%@个cookie", @(self.cookies.filteredList.count)
    ];
    [super reloadData];
}

#pragma mark - FLEXGlobals入口

+ (NSString *)globalsEntryTitle:(FLEXGlobalsRow)row {
    return @"🍪  Cookie缓存";
}

+ (UIViewController *)globalsEntryViewController:(FLEXGlobalsRow)row {
    return [self new];
}

@end
