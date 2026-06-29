//
//  FLEXWindowManagerController.m
//  FLEX
//
//  由 Tanner 创建于 2/6/20.
//  版权所有 © 2020 FLEX Team. 保留所有权利。
//

#import "FLEXWindowManagerController.h"
#import "FLEXManager+Private.h"
#import "FLEXUtility.h"
#import "FLEXObjectExplorerFactory.h"

@interface FLEXWindowManagerController ()
@property (nonatomic) UIWindow *keyWindow;
@property (nonatomic, copy) NSString *keyWindowSubtitle;
@property (nonatomic, copy) NSArray<UIWindow *> *windows;
@property (nonatomic, copy) NSArray<NSString *> *windowSubtitles;
@property (nonatomic, copy) NSArray<UIScene *> *scenes API_AVAILABLE(ios(13));
@property (nonatomic, copy) NSArray<NSString *> *sceneSubtitles;
@property (nonatomic, copy) NSArray<NSArray *> *sections;
@end

@implementation FLEXWindowManagerController

#pragma mark - 初始化

- (id)init {
    return [self initWithStyle:UITableViewStylePlain];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"窗口";
    if (@available(iOS 13, *)) {
        self.title = @"窗口和场景";
    }
    
    [self disableToolbar];
    [self reloadData];
}


#pragma mark - 私有方法

- (void)reloadData {
    self.keyWindow = UIApplication.sharedApplication.keyWindow;
    self.windows = UIApplication.sharedApplication.windows;
    self.keyWindowSubtitle = self.windowSubtitles[[self.windows indexOfObject:self.keyWindow]];
    self.windowSubtitles = [self.windows flex_mapped:^id(UIWindow *window, NSUInteger idx) {
        return [NSString stringWithFormat:@"层级: %@ — 根控制器: %@",
            @(window.windowLevel), window.rootViewController
        ];
    }];
    
    if (@available(iOS 13, *)) {
        self.scenes = UIApplication.sharedApplication.connectedScenes.allObjects;
        self.sceneSubtitles = [self.scenes flex_mapped:^id(UIScene *scene, NSUInteger idx) {
            return [self sceneDescription:scene];
        }];
        
        self.sections = @[@[self.keyWindow], self.windows, self.scenes];
    } else {
        self.sections = @[@[self.keyWindow], self.windows];
    }
    
    [self.tableView reloadData];
}

- (void)dismissAnimated {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)showRevertOrDismissAlert:(void(^)(void))revertBlock {
    [self.tableView deselectRowAtIndexPath:self.tableView.indexPathForSelectedRow animated:YES];
    [self reloadData];
    [self.tableView reloadData];
    
    UIWindow *highestWindow = UIApplication.sharedApplication.keyWindow;
    UIWindowLevel maxLevel = 0;
    for (UIWindow *window in UIApplication.sharedApplication.windows) {
        if (window.windowLevel > maxLevel) {
            maxLevel = window.windowLevel;
            highestWindow = window;
        }
    }
    
    [FLEXAlert makeAlert:^(FLEXAlert *make) {
        make.title(@"保留更改？");
        make.message(@"如果您不希望保留这些设置，请选择下面的'还原更改'。");
        
        make.button(@"保留更改").destructiveStyle();
        make.button(@"保留更改并关闭").destructiveStyle().handler(^(NSArray<NSString *> *strings) {
            [self dismissAnimated];
        });
        make.button(@"还原更改").cancelStyle().handler(^(NSArray<NSString *> *strings) {
            revertBlock();
            [self reloadData];
            [self.tableView reloadData];
        });
    } showFrom:[FLEXUtility topViewControllerInWindow:highestWindow]];
}

- (NSString *)sceneDescription:(UIScene *)scene API_AVAILABLE(ios(13)) {
    NSString *state = [self stringFromSceneState:scene.activationState];
    NSString *title = scene.title.length ? scene.title : nil;
    NSString *suffix = nil;
    
    if ([scene isKindOfClass:[UIWindowScene class]]) {
        UIWindowScene *windowScene = (id)scene;
        suffix = FLEXPluralString(windowScene.windows.count, @"窗口", @"窗口");
    }
    
    NSMutableString *description = state.mutableCopy;
    if (title) {
        [description appendFormat:@" — %@", title];
    }
    if (suffix) {
        [description appendFormat:@" — %@", suffix];
    }
    
    return description.copy;
}

- (NSString *)stringFromSceneState:(UISceneActivationState)state API_AVAILABLE(ios(13)) {
    switch (state) {
        case UISceneActivationStateUnattached:
            return @"未连接";
        case UISceneActivationStateForegroundActive:
            return @"活跃";
        case UISceneActivationStateForegroundInactive:
            return @"不活跃";
        case UISceneActivationStateBackground:
            return @"后台";
    }
    
    return [NSString stringWithFormat:@"未知状态: %@", @(state)];
}


#pragma mark - 表格视图数据源

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.sections[section].count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case 0: return @"主窗口";
        case 1: return @"窗口";
        case 2: return @"已连接场景";
    }
    
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kFLEXDetailCell forIndexPath:indexPath];
    cell.accessoryType = UITableViewCellAccessoryDetailButton;
    cell.textLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    
    UIWindow *window = nil;
    NSString *subtitle = nil;
    
    switch (indexPath.section) {
        case 0:
            window = self.keyWindow;
            subtitle = self.keyWindowSubtitle;
            break;
        case 1:
            window = self.windows[indexPath.row];
            subtitle = self.windowSubtitles[indexPath.row];
            break;
        case 2:
            if (@available(iOS 13, *)) {
                UIScene *scene = self.scenes[indexPath.row];
                cell.textLabel.text = scene.description;
                cell.detailTextLabel.text = self.sceneSubtitles[indexPath.row];
                return cell;
            }
    }
    
    cell.textLabel.text = window.description;
    cell.detailTextLabel.text = [NSString
        stringWithFormat:@"层级: %@ — 根控制器: %@",
        @((NSInteger)window.windowLevel), window.rootViewController.class
    ];
    
    return cell;
}


#pragma mark - 表格视图代理

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UIWindow *window = nil;
    NSString *subtitle = nil;
    FLEXWindow *flex = FLEXManager.sharedManager.explorerWindow;
    
    id cancelHandler = ^{
        [self.tableView deselectRowAtIndexPath:self.tableView.indexPathForSelectedRow animated:YES];
    };
    
    switch (indexPath.section) {
        case 0:
            window = self.keyWindow;
            subtitle = self.keyWindowSubtitle;
            break;
        case 1:
            window = self.windows[indexPath.row];
            subtitle = self.windowSubtitles[indexPath.row];
            break;
        case 2:
            if (@available(iOS 13, *)) {
                UIScene *scene = self.scenes[indexPath.row];
                UIWindowScene *oldScene = flex.windowScene;
                BOOL isWindowScene = [scene isKindOfClass:[UIWindowScene class]];
                BOOL isFLEXScene = isWindowScene ? flex.windowScene == scene : NO;
                
                [FLEXAlert makeAlert:^(FLEXAlert *make) {
                    make.title(NSStringFromClass(scene.class));
                    
                    if (isWindowScene) {
                        if (isFLEXScene) {
                            make.message(@"已经是 FLEX 窗口场景");
                        }
                        
                        make.button(@"设为 FLEX 窗口场景")
                        .handler(^(NSArray<NSString *> *strings) {
                            flex.windowScene = (id)scene;
                            [self showRevertOrDismissAlert:^{
                                flex.windowScene = oldScene;
                            }];
                        }).enabled(!isFLEXScene);
                        make.button(@"取消").cancelStyle();
                    } else {
                        make.message(@"不是 UIWindowScene");
                        make.button(@"关闭").cancelStyle().handler(cancelHandler);
                    }
                } showFrom:self];
            }
    }

    __block UIWindow *targetWindow = nil, *oldKeyWindow = nil;
    __block UIWindowLevel oldLevel;
    __block BOOL wasVisible;
    
    subtitle = [subtitle stringByAppendingString:
        @"\n\n1) 调整 FLEX 窗口层级相对于此窗口，\n"
        "2) 调整此窗口的层级相对于 FLEX 窗口，\n"
        "3) 将此窗口的层级设置为特定值，或\n"
        "4) 如果还不是主窗口，则将此窗口设为主窗口。"
    ];
    
    [FLEXAlert makeAlert:^(FLEXAlert *make) {
        make.title(NSStringFromClass(window.class)).message(subtitle);
        make.button(@"调整 FLEX 窗口层级").handler(^(NSArray<NSString *> *strings) {
            targetWindow = flex; oldLevel = flex.windowLevel;
            flex.windowLevel = window.windowLevel + strings.firstObject.integerValue;
            
            [self showRevertOrDismissAlert:^{ targetWindow.windowLevel = oldLevel; }];
        });
        make.button(@"调整此窗口层级").handler(^(NSArray<NSString *> *strings) {
            targetWindow = window; oldLevel = window.windowLevel;
            window.windowLevel = flex.windowLevel + strings.firstObject.integerValue;
            
            [self showRevertOrDismissAlert:^{ targetWindow.windowLevel = oldLevel; }];
        });
        make.button(@"设置此窗口层级").handler(^(NSArray<NSString *> *strings) {
            targetWindow = window; oldLevel = window.windowLevel;
            window.windowLevel = strings.firstObject.integerValue;
            
            [self showRevertOrDismissAlert:^{ targetWindow.windowLevel = oldLevel; }];
        });
        make.button(@"设为主窗口并可见").handler(^(NSArray<NSString *> *strings) {
            oldKeyWindow = UIApplication.sharedApplication.keyWindow;
            wasVisible = window.hidden;
            [window makeKeyAndVisible];
            
            [self showRevertOrDismissAlert:^{
                window.hidden = wasVisible;
                [oldKeyWindow makeKeyWindow];
            }];
        }).enabled(!window.isKeyWindow && !window.hidden);
        make.button(@"取消").cancelStyle().handler(cancelHandler);
        
        make.textField(@"+/- 窗口层级, 例如 5 或 -10");
    } showFrom:self];
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)ip {
    [self.navigationController pushViewController:
        [FLEXObjectExplorerFactory explorerViewControllerForObject:self.sections[ip.section][ip.row]]
    animated:YES];
}

@end
