//
//  FLEXObjectExplorerViewController.m
//  Flipboard
//
//  Created by Ryan Olson on 2014-05-03.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

#import "FLEXObjectExplorerViewController.h"
#import "FLEXUtility.h"
#import "FLEXRuntimeUtility.h"
#import "UIBarButtonItem+FLEX.h"
#import "FLEXMultilineTableViewCell.h"
#import "FLEXObjectExplorerFactory.h"
#import "FLEXFieldEditorViewController.h"
#import "FLEXMethodCallingViewController.h"
#import "FLEXObjectListViewController.h"
#import "FLEXTabsViewController.h"
#import "FLEXBookmarkManager.h"
#import "FLEXTableView.h"
#import "FLEXResources.h"
#import "FLEXTableViewCell.h"
#import "FLEXScopeCarousel.h"
#import "FLEXMetadataSection.h"
#import "FLEXSingleRowSection.h"
#import "FLEXShortcutsSection.h"
#import "NSUserDefaults+FLEX.h"
#import <objc/runtime.h>

#pragma mark - 私有属性
@interface FLEXObjectExplorerViewController () <UIGestureRecognizerDelegate>
@property (nonatomic, readonly) FLEXSingleRowSection *descriptionSection;
@property (nonatomic, readonly) NSArray<FLEXTableViewSection *> *customSections;
@property (nonatomic) NSIndexSet *customSectionVisibleIndexes;

@property (nonatomic, readonly) NSArray<NSString *> *observedNotifications;

@end

@implementation FLEXObjectExplorerViewController

#pragma mark - 初始化

+ (instancetype)exploringObject:(id)target {
    return [self exploringObject:target customSection:[FLEXShortcutsSection forObject:target]];
}

+ (instancetype)exploringObject:(id)target customSection:(FLEXTableViewSection *)section {
    return [self exploringObject:target customSections:@[section]];
}

+ (instancetype)exploringObject:(id)target customSections:(NSArray *)customSections {
    return [[self alloc]
        initWithObject:target
        explorer:[FLEXObjectExplorer forObject:target]
        customSections:customSections
    ];
}

- (id)initWithObject:(id)target
            explorer:(__kindof FLEXObjectExplorer *)explorer
       customSections:(NSArray<FLEXTableViewSection *> *)customSections {
    NSParameterAssert(target);
    
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        _object = target;
        _explorer = explorer;
        _customSections = customSections;
    }

    return self;
}

- (NSArray<NSString *> *)observedNotifications {
    return @[
        kFLEXDefaultsHidePropertyIvarsKey,
        kFLEXDefaultsHidePropertyMethodsKey,
        kFLEXDefaultsHidePrivateMethodsKey,
        kFLEXDefaultsShowMethodOverridesKey,
        kFLEXDefaultsHideVariablePreviewsKey,
    ];
}

#pragma mark - 视图控制器生命周期

- (void)viewDidLoad {
    [super viewDidLoad];

    self.showsShareToolbarItem = YES;
    self.wantsSectionIndexTitles = YES;

    // 在这里使用[object class]而不是object_getClass
    // 以避免被观察对象的KVO前缀
    self.title = [FLEXRuntimeUtility safeClassNameForObject:self.object];

    // 搜索
    self.showsSearchBar = YES;
    self.searchBarDebounceInterval = kFLEXDebounceInstant;
    self.showsCarousel = YES;

    // 轮播范围栏
    [self.explorer reloadClassHierarchy];
    self.carousel.items = [self.explorer.classHierarchyClasses flex_mapped:^id(Class cls, NSUInteger idx) {
        return NSStringFromClass(cls);
    }];
    
    // 用于额外选项的...按钮
    [self addToolbarItems:@[[UIBarButtonItem
        flex_itemWithImage:FLEXResources.moreIcon target:self action:@selector(moreButtonPressed:)
    ]]];

    // 在层次结构中的类之间滑动的手势
    UISwipeGestureRecognizer *leftSwipe = [[UISwipeGestureRecognizer alloc]
        initWithTarget:self action:@selector(handleSwipeGesture:)
    ];
    UISwipeGestureRecognizer *rightSwipe = [[UISwipeGestureRecognizer alloc]
        initWithTarget:self action:@selector(handleSwipeGesture:)
    ];
    leftSwipe.direction = UISwipeGestureRecognizerDirectionLeft;
    rightSwipe.direction = UISwipeGestureRecognizerDirectionRight;
    leftSwipe.delegate = self;
    rightSwipe.delegate = self;
    [self.tableView addGestureRecognizer:leftSwipe];
    [self.tableView addGestureRecognizer:rightSwipe];
    
    // 观察可能在其他屏幕上更改的首选项
    //
    // "如果您的应用程序针对iOS 9.0及更高版本或macOS 10.11及更高版本，
    // 则无需在其dealloc方法中注销观察者。"
    for (NSString *pref in self.observedNotifications) {
        [NSNotificationCenter.defaultCenter
            addObserver:self
            selector:@selector(fullyReloadData)
            name:pref
            object:nil
        ];
    }
}

- (BOOL)scrollViewShouldScrollToTop:(UIScrollView *)scrollView {
    [self.navigationController setToolbarHidden:NO animated:YES];
    return YES;
}


#pragma mark - 重写

/// 重写以在搜索时隐藏描述部分
- (NSArray<FLEXTableViewSection *> *)nonemptySections {
    if (self.shouldShowDescription) {
        return super.nonemptySections;
    }
    
    return [super.nonemptySections flex_filtered:^BOOL(FLEXTableViewSection *section, NSUInteger idx) {
        return section != self.descriptionSection;
    }];
}

- (NSArray<FLEXTableViewSection *> *)makeSections {
    FLEXObjectExplorer *explorer = self.explorer;
    
    // 描述部分仅适用于实例
    if (self.explorer.objectIsInstance) {
        _descriptionSection = [FLEXSingleRowSection
            title:@"描述" reuse:kFLEXMultilineCell cell:^(FLEXTableViewCell *cell) {
                cell.titleLabel.font = UIFont.flex_defaultTableCellFont;
                cell.titleLabel.text = explorer.objectDescription;
            }
        ];
        self.descriptionSection.filterMatcher = ^BOOL(NSString *filterText) {
            return [explorer.objectDescription localizedCaseInsensitiveContainsString:filterText];
        };
    }

    // 对象图部分
    FLEXSingleRowSection *referencesSection = [FLEXSingleRowSection
        title:@"对象图" reuse:kFLEXDefaultCell cell:^(FLEXTableViewCell *cell) {
            cell.titleLabel.text = @"查看引用此对象的对象";
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
    ];
    referencesSection.selectionAction = ^(UIViewController *host) {
        UIViewController *references = [FLEXObjectListViewController
            objectsWithReferencesToObject:explorer.object
            retained:NO
        ];
        [host.navigationController pushViewController:references animated:YES];
    };

    NSMutableArray *sections = [NSMutableArray arrayWithArray:@[
        [FLEXMetadataSection explorer:self.explorer kind:FLEXMetadataKindProperties],
        [FLEXMetadataSection explorer:self.explorer kind:FLEXMetadataKindClassProperties],
        [FLEXMetadataSection explorer:self.explorer kind:FLEXMetadataKindIvars],
        [FLEXMetadataSection explorer:self.explorer kind:FLEXMetadataKindMethods],
        [FLEXMetadataSection explorer:self.explorer kind:FLEXMetadataKindClassMethods],
        [FLEXMetadataSection explorer:self.explorer kind:FLEXMetadataKindClassHierarchy],
        [FLEXMetadataSection explorer:self.explorer kind:FLEXMetadataKindProtocols],
        [FLEXMetadataSection explorer:self.explorer kind:FLEXMetadataKindOther],
        referencesSection
    ]];

    if (self.customSections) {
        [sections insertObjects:self.customSections atIndexes:[NSIndexSet
            indexSetWithIndexesInRange:NSMakeRange(0, self.customSections.count)
        ]];
    }
    if (self.descriptionSection) {
        [sections insertObject:self.descriptionSection atIndex:0];
    }

    return sections.copy;
}

/// 在我们的情况下，这只是重新加载表视图，
/// 或者如果我们在类层次结构中更改了位置，则重新加载部分数据。
/// 不刷新 \c self.explorer
- (void)reloadData {
    // 检查类作用域是否已更改，相应更新
    if (self.explorer.classScope != self.selectedScope) {
        self.explorer.classScope = self.selectedScope;
        [self reloadSections];
    }
    
    [super reloadData];
}

- (void)shareButtonPressed:(UIBarButtonItem *)sender {
    [FLEXAlert makeSheet:^(FLEXAlert *make) {
        make.button(@"添加到书签").handler(^(NSArray<NSString *> *strings) {
            [FLEXBookmarkManager.bookmarks addObject:self.object];
        });
        make.button(@"复制描述").handler(^(NSArray<NSString *> *strings) {
            UIPasteboard.generalPasteboard.string = self.explorer.objectDescription;
        });
        make.button(@"复制地址").handler(^(NSArray<NSString *> *strings) {
            UIPasteboard.generalPasteboard.string = [FLEXUtility addressOfObject:self.object];
        });
        make.button(@"取消").cancelStyle();
    } showFrom:self source:sender];
}


#pragma mark - 私有方法

/// 与 \c -reloadData 不同，这会刷新所有内容，包括探索器。
- (void)fullyReloadData {
    [self.explorer reloadMetadata];
    [self reloadSections];
    [self reloadData];
}

- (void)handleSwipeGesture:(UISwipeGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateEnded) {
        switch (gesture.direction) {
            case UISwipeGestureRecognizerDirectionRight:
                if (self.selectedScope > 0) {
                    self.selectedScope -= 1;
                }
                break;
            case UISwipeGestureRecognizerDirectionLeft:
                if (self.selectedScope != self.explorer.classHierarchy.count - 1) {
                    self.selectedScope += 1;
                }
                break;

            default:
                break;
        }
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)g1 shouldBeRequiredToFailByGestureRecognizer:(UIGestureRecognizer *)g2 {
    // 优先考虑重要的平移手势而不是我们的滑动手势
    if ([g2 isKindOfClass:[UIPanGestureRecognizer class]]) {
        if (g2 == self.navigationController.interactivePopGestureRecognizer) {
            return NO;
        }
        
        if (g2 == self.tableView.panGestureRecognizer) {
            return NO;
        }
    }
    
    return YES;
}

- (BOOL)gestureRecognizerShouldBegin:(UISwipeGestureRecognizer *)gesture {
    // 不允许从轮播中滑动
    CGPoint location = [gesture locationInView:self.tableView];
    if ([self.carousel hitTest:location withEvent:nil]) {
        return NO;
    }
    
    return YES;
}
    
- (void)moreButtonPressed:(UIBarButtonItem *)sender {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    // 将首选项键映射到它们影响的内容描述
    NSDictionary<NSString *, NSString *> *explorerToggles = @{
        kFLEXDefaultsHidePropertyIvarsKey:    @"属性-支持实例变量",
        kFLEXDefaultsHidePropertyMethodsKey:  @"属性-支持方法",
        kFLEXDefaultsHidePrivateMethodsKey:   @"可能的私人方法",
        kFLEXDefaultsShowMethodOverridesKey:  @"方法覆盖",
        kFLEXDefaultsHideVariablePreviewsKey: @"变量预览"
    };
    
    // 将操作本身的键映射到操作描述的映射
    // 的操作（"隐藏X"）映射到当前状态。
    //
    // 所以默认隐藏的键有NO映射到"显示"
    NSDictionary<NSString *, NSDictionary *> *nextStateDescriptions = @{
        kFLEXDefaultsHidePropertyIvarsKey:    @{ @NO: @"隐藏 ", @YES: @"显示 " },
        kFLEXDefaultsHidePropertyMethodsKey:  @{ @NO: @"隐藏 ", @YES: @"显示 " },
        kFLEXDefaultsHidePrivateMethodsKey:   @{ @NO: @"隐藏 ", @YES: @"显示 " },
        kFLEXDefaultsShowMethodOverridesKey:  @{ @NO: @"隐藏 ", @YES: @"显示 " },
        kFLEXDefaultsHideVariablePreviewsKey: @{ @NO: @"隐藏 ", @YES: @"显示 " },
    };
    
    [FLEXAlert makeSheet:^(FLEXAlert *make) {
        make.title(@"选项");
        
        for (NSString *option in explorerToggles.allKeys) {
            BOOL current = [defaults boolForKey:option];
            NSString *title = [nextStateDescriptions[option][@(current)]
                stringByAppendingString:explorerToggles[option]
            ];
            make.button(title).handler(^(NSArray<NSString *> *strings) {
                [NSUserDefaults.standardUserDefaults flex_toggleBoolForKey:option];
                [self fullyReloadData];
            });
        }
        
        make.button(@"取消").cancelStyle();
    } showFrom:self source:sender];
}

#pragma mark - 描述

- (BOOL)shouldShowDescription {
    // 如果我们有过滤文本则隐藏；在搜索时
    // 看到描述很少有用，因为它已经在屏幕顶部
    if (self.filterText.length) {
        return NO;
    }

    return YES;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    // 对于描述部分，我们希望那个漂亮的纤细/贴合的行。
    // 其他行使用自动大小。
    FLEXTableViewSection *section = self.filterDelegate.sections[indexPath.section];
    
    if (section == self.descriptionSection) {
        NSAttributedString *attributedText = [[NSAttributedString alloc]
            initWithString:self.explorer.objectDescription
            attributes:@{ NSFontAttributeName : UIFont.flex_defaultTableCellFont }
        ];
        
        return [FLEXMultilineTableViewCell
            preferredHeightWithAttributedText:attributedText
            maxWidth:tableView.frame.size.width - tableView.separatorInset.right
            style:tableView.style
            showsAccessory:NO
        ];
    }

    return UITableViewAutomaticDimension;
}

- (BOOL)tableView:(UITableView *)tableView shouldShowMenuForRowAtIndexPath:(NSIndexPath *)indexPath {
    return self.filterDelegate.sections[indexPath.section] == self.descriptionSection;
}

- (BOOL)tableView:(UITableView *)tableView canPerformAction:(SEL)action forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender {
    // 只有描述部分有"操作"
    if (self.filterDelegate.sections[indexPath.section] == self.descriptionSection) {
        return action == @selector(copy:);
    }

    return NO;
}

- (void)tableView:(UITableView *)tableView performAction:(SEL)action forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender {
    if (action == @selector(copy:)) {
        UIPasteboard.generalPasteboard.string = self.explorer.objectDescription;
    }
}

@end
