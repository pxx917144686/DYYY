//
//  FLEXKeychainViewController.m
//  FLEX
//
//  Created by ray on 2019/8/17.
//  Copyright © 2020 FLEX Team. All rights reserved.
//

#import "FLEXKeychain.h"
#import "FLEXKeychainQuery.h"
#import "FLEXKeychainViewController.h"
#import "FLEXTableViewCell.h"
#import "FLEXMutableListSection.h"
#import "FLEXUtility.h"
#import "UIPasteboard+FLEX.h"
#import "UIBarButtonItem+FLEX.h"

@interface FLEXKeychainViewController ()
@property (nonatomic, readonly) FLEXMutableListSection<NSDictionary *> *section;
@end

@implementation FLEXKeychainViewController

- (id)init {
    return [self initWithStyle:UITableViewStyleGrouped];
}

#pragma mark - 重写

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self addToolbarItems:@[
        FLEXBarButtonItemSystem(Add, self, @selector(addPressed)),
        [FLEXBarButtonItemSystem(Trash, self, @selector(trashPressed:)) flex_withTintColor:UIColor.redColor],
    ]];

    [self reloadData];
}

- (NSArray<FLEXTableViewSection *> *)makeSections {
    _section = [FLEXMutableListSection list:FLEXKeychain.allAccounts.mutableCopy
        cellConfiguration:^(__kindof FLEXTableViewCell *cell, NSDictionary *item, NSInteger row) {
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        
            id service = item[kFLEXKeychainWhereKey];
            if ([service isKindOfClass:[NSString class]]) {
                cell.textLabel.text = service;
                cell.detailTextLabel.text = [item[kFLEXKeychainAccountKey] description];
            } else {
                cell.textLabel.text = [NSString stringWithFormat:
                    @"[%@]\n\n%@",
                    NSStringFromClass([service class]),
                    [service description]
                ];
            }
        } filterMatcher:^BOOL(NSString *filterText, NSDictionary *item) {
            // 遍历钥匙串项目的内容寻找匹配项
            for (NSString *field in item.allValues) {
                if ([field isKindOfClass:[NSString class]]) {
                    if ([field localizedCaseInsensitiveContainsString:filterText]) {
                        return YES;
                    }
                }
            }
            
            return NO;
        }
    ];
    
    return @[self.section];
}

/// 我们总是希望显示此部分
- (NSArray<FLEXTableViewSection *> *)nonemptySections {
    return @[self.section];
}

- (void)reloadSections {
    self.section.list = FLEXKeychain.allAccounts.mutableCopy;
}

- (void)refreshSectionTitle {
    self.section.customTitle = FLEXPluralString(
        self.section.filteredList.count, @"项目", @"项目"
    );
}

- (void)reloadData {
    [self reloadSections];
    [self refreshSectionTitle];
    [super reloadData];
}


#pragma mark - 私有方法

- (FLEXKeychainQuery *)queryForItemAtIndex:(NSInteger)idx {
    NSDictionary *item = self.section.filteredList[idx];

    FLEXKeychainQuery *query = [FLEXKeychainQuery new];
    query.service = [item[kFLEXKeychainWhereKey] description];
    query.account = [item[kFLEXKeychainAccountKey] description];
    query.accessGroup = [item[kFLEXKeychainGroupKey] description];
    [query fetch:nil];

    return query;
}

- (void)deleteItem:(NSDictionary *)item {
    NSError *error = nil;
    BOOL success = [FLEXKeychain
        deletePasswordForService:item[kFLEXKeychainWhereKey]
        account:item[kFLEXKeychainAccountKey]
        error:&error
    ];

    if (!success) {
        [FLEXAlert makeAlert:^(FLEXAlert *make) {
            make.title(@"删除项目时出错");
            make.message(error.localizedDescription);
        } showFrom:self];
    }
}


#pragma mark 按钮

- (void)trashPressed:(UIBarButtonItem *)sender {
    [FLEXAlert makeSheet:^(FLEXAlert *make) {
        make.title(@"透明钥匙扣");
        make.message(@"这将删除此应用程序的所有钥匙串项目。\n");
        make.message(@"这个动作是无法撤销的。你确定吗？");
        make.button(@"是的，清除钥匙扣").destructiveStyle().handler(^(NSArray *strings) {
            [self confirmClearKeychain];
        });
        make.button(@"取消").cancelStyle();
    } showFrom:self source:sender];
}

- (void)confirmClearKeychain {
    [FLEXAlert makeAlert:^(FLEXAlert *make) {
        make.title(@"你确定吗？");
        make.message(@"此操作无法撤销。\n你确定要继续吗？\n");
        make.message(@"如果您确定，请滚动确认。");
        make.button(@"是的，清除钥匙扣").destructiveStyle().handler(^(NSArray *strings) {
            for (id account in self.section.list) {
                [self deleteItem:account];
            }

            [self reloadData];
        });
        make.button(@"取消"); make.button(@"取消"); make.button(@"取消"); make.button(@"取消");
        make.button(@"取消"); make.button(@"取消"); make.button(@"取消"); make.button(@"取消");
        make.button(@"取消"); make.button(@"取消"); make.button(@"取消"); make.button(@"取消");
        make.button(@"取消"); make.button(@"取消"); make.button(@"取消"); make.button(@"取消");
        make.button(@"取消").cancelStyle();
    } showFrom:self];
}

- (void)addPressed {
    [FLEXAlert makeAlert:^(FLEXAlert *make) {
        make.title(@"添加钥匙扣项目");
        make.textField(@"服务名称(Service)");
        make.textField(@"账户(Account)");
        make.textField(@"密码(Password)");
        make.button(@"取消").cancelStyle();
        make.button(@"添加").handler(^(NSArray<NSString *> *strings) {
            // 显示错误
            NSError *error = nil;
            if (![FLEXKeychain setPassword:strings[2] forService:strings[0] account:strings[1] error:&error]) {
                [FLEXAlert showAlert:@"错误" message:error.localizedDescription from:self];
            }

            [self reloadData];
        });
    } showFrom:self];
}


#pragma mark - FLEXGlobalsEntry

+ (NSString *)globalsEntryTitle:(FLEXGlobalsRow)row {
    return @"🔑  钥匙串";
}

+ (UIViewController *)globalsEntryViewController:(FLEXGlobalsRow)row {
    FLEXKeychainViewController *viewController = [self new];
    viewController.title = [self globalsEntryTitle:row];

    return viewController;
}


#pragma mark - 表视图数据源

- (void)tableView:(UITableView *)tv commitEditingStyle:(UITableViewCellEditingStyle)style forRowAtIndexPath:(NSIndexPath *)ip {
    if (style == UITableViewCellEditingStyleDelete) {
        // 更新模型
        NSDictionary *toRemove = self.section.filteredList[ip.row];
        [self deleteItem:toRemove];
        [self.section mutate:^(NSMutableArray *list) {
            [list removeObject:toRemove];
        }];
    
        // 删除行
        [tv deleteRowsAtIndexPaths:@[ip] withRowAnimation:UITableViewRowAnimationAutomatic];
        
        // 通过刷新部分而不干扰删除动画来更新标题
        //
        // 这是一个丑陋的黑客手段，但实际上没有其他方法可行，除了手动获取
        // 标题并设置其标题，但我个人认为这更糟，因为它
        // 需要对标题的默认样式（全大写）做出假设
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self refreshSectionTitle];
            [tv reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationNone];
        });
    }
}


#pragma mark - 表视图代理

- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    FLEXKeychainQuery *query = [self queryForItemAtIndex:indexPath.row];
    
    [FLEXAlert makeAlert:^(FLEXAlert *make) {
        make.title(query.service);
        make.message(@"服务: ").message(query.service);
        make.message(@"\n账户: ").message(query.account);
        make.message(@"\n密码: ").message(query.password);
        make.message(@"\n组: ").message(query.accessGroup);

        make.button(@"复制服务").handler(^(NSArray<NSString *> *strings) {
            [UIPasteboard.generalPasteboard flex_copy:query.service];
        });
        make.button(@"复制账户").handler(^(NSArray<NSString *> *strings) {
            [UIPasteboard.generalPasteboard flex_copy:query.account];
        });
        make.button(@"复制密码").handler(^(NSArray<NSString *> *strings) {
            [UIPasteboard.generalPasteboard flex_copy:query.password];
        });
        make.button(@"取消").cancelStyle();
        
    } showFrom:self];

    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
