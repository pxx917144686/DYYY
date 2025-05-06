//
//  FLEXWindowManagerController.m
//  FLEX
//
//  Created by Tanner on 6/29/20.
//  Copyright © 2020 FLEX Team. All rights reserved.
//
//  遇到问题联系中文翻译作者：pxx917144686

#import "FLEXWindowManagerController.h"
#import "FLEXManager+Private.h"
#import "FLEXUtility.h"
#import "FLEXObjectExplorerFactory.h"

// 遇到问题联系中文翻译作者：pxx917144686

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

#pragma mark - Initialization

- (id)init {
    return [self initWithStyle:UITableViewStylePlain];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"Windows";
    if (@available(iOS 13, *)) {
        self.title = @"Windows and Scenes";
    }
    
    [self disableToolbar];
    [self reloadData];
}


#pragma mark - Private

- (void)reloadData {
    if (@available(iOS 13.0, *)) {
        // 获取当前活跃的场景
        UIWindowScene *scene = FLEXUtility.activeScene;
        self.keyWindow = scene.windows.firstObject;
        self.windows = [scene.windows copy];
    } else {
        // 降级处理
        self.keyWindow = [[UIApplication sharedApplication].delegate window];
        self.windows = @[self.keyWindow];
    }
    
    self.keyWindowSubtitle = self.windowSubtitles[[self.windows indexOfObject:self.keyWindow]];
    self.windowSubtitles = [self.windows flex_mapped:^id(UIWindow *window, NSUInteger idx) {
        return [NSString stringWithFormat:@"Level: %@ — Root: %@",
            @(window.windowLevel), window.rootViewController
        ];
    }];
    
    if (@available(iOS 13.0, *)) {
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
    
    UIWindow *highestWindow = nil;
    if (@available(iOS 13.0, *)) {
        // 获取当前活跃场景的窗口
        UIWindowScene *scene = FLEXUtility.activeScene;
        for (UIWindow *window in scene.windows) {
            if (!highestWindow || window.windowLevel > highestWindow.windowLevel) {
                highestWindow = window;
            }
        }
    } else {
        highestWindow = [[UIApplication sharedApplication].delegate window];
    }
    
    [FLEXAlert makeAlert:^(FLEXAlert *make) {
        make.title(@"Keep Changes?");
        make.message(@"If you do not wish to keep these settings, choose 'Revert Changes' below.");
        
        make.button(@"Keep Changes").destructiveStyle();
        make.button(@"Keep Changes and Dismiss").destructiveStyle().handler(^(NSArray<NSString *> *strings) {
            [self dismissAnimated];
        });
        make.button(@"Revert Changes").cancelStyle().handler(^(NSArray<NSString *> *strings) {
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
        suffix = FLEXPluralString(windowScene.windows.count, @"windows", @"window");
    }
    
    NSMutableString *description = state.mutableCopy;
    if (title) {
        [description appendFormat:@" — %@", title];
    }
    if (suffix) {
        [description appendFormat:@" — %@", suffix];
    }
    
    return description.copy;
}

- (NSString *)stringFromSceneState:(UISceneActivationState)state API_AVAILABLE(ios(13)) {
    switch (state) {
        case UISceneActivationStateUnattached:
            return @"Unattached";
        case UISceneActivationStateForegroundActive:
            return @"Active";
        case UISceneActivationStateForegroundInactive:
            return @"Inactive";
        case UISceneActivationStateBackground:
            return @"Backgrounded";
    }
    
    return [NSString stringWithFormat:@"Unknown state: %@", @(state)];
}


#pragma mark - Table View Data Source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.sections[section].count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case 0: return @"Key Window";
        case 1: return @"Windows";
        case 2: return @"Connected Scenes";
    }
    
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kFLEXDetailCell forIndexPath:indexPath];
    cell.accessoryType = UITableViewCellAccessoryDetailButton;
    cell.textLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    
    UIWindow *window = nil;
    
    switch (indexPath.section) {
        case 0:
            window = self.keyWindow;
            break;
        case 1:
            window = self.windows[indexPath.row];
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
        stringWithFormat:@"Level: %@ — Root: %@",
        @((NSInteger)window.windowLevel), window.rootViewController.class
    ];
    
    return cell;
}


#pragma mark - Table View Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    __block UIWindow *oldKeyWindow = nil;
    __block UIWindowLevel oldLevel;
    __block BOOL wasVisible;
    
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
                subtitle = self.sceneSubtitles[indexPath.row];
                
                [FLEXAlert makeAlert:^(FLEXAlert *make) {
                    make.title(NSStringFromClass(scene.class));
                    
                    if ([scene isKindOfClass:[UIWindowScene class]]) {
                        if (flex.windowScene == scene) {
                            make.message(@"Already the FLEX window scene");
                        }
                        
                        make.button(@"Set as FLEX Window Scene")
                        .handler(^(NSArray<NSString *> *strings) {
                            flex.windowScene = (id)scene;
                            [self showRevertOrDismissAlert:^{
                                flex.windowScene = oldScene;
                            }];
                        }).enabled(flex.windowScene != scene);
                        make.button(@"关闭").cancelStyle();
                    } else {
                        make.message(@"Not a UIWindowScene");
                        make.button(@"关闭").cancelStyle().handler(cancelHandler);
                    }
                } showFrom:self];
            }
            return;
    }

    __block UIWindow *targetWindow = nil;
    
    NSString *title = window ? NSStringFromClass(window.class) : @"窗口";
    subtitle = [subtitle stringByAppendingString:
        @"\n\n1) 调整FLEX窗口级别相对于此窗口，\n"
        "2) 调整此窗口的级别相对于FLEX窗口，\n"
        "3) 将此窗口的级别设置为特定值，或\n"
        "4) 如果此窗口尚未成为键窗口，则将其设为键窗口。"
    ];
    
    [FLEXAlert makeAlert:^(FLEXAlert *make) {
        make.title(title).message(subtitle);
        make.button(@"调整FLEX窗口级别").handler(^(NSArray<NSString *> *strings) {
            targetWindow = flex; oldLevel = flex.windowLevel;
            flex.windowLevel = window.windowLevel + strings.firstObject.integerValue;
            
            [self showRevertOrDismissAlert:^{ targetWindow.windowLevel = oldLevel; }];
        });
        make.button(@"调整此窗口的级别").handler(^(NSArray<NSString *> *strings) {
            targetWindow = window; oldLevel = window.windowLevel;
            window.windowLevel = flex.windowLevel + strings.firstObject.integerValue;
            
            [self showRevertOrDismissAlert:^{ targetWindow.windowLevel = oldLevel; }];
        });
        make.button(@"设置此窗口级别").handler(^(NSArray<NSString *> *strings) {
            targetWindow = window; oldLevel = window.windowLevel;
            window.windowLevel = strings.firstObject.integerValue;
            
            [self showRevertOrDismissAlert:^{ targetWindow.windowLevel = oldLevel; }];
        });
        make.button(@"设为键窗口并可见").handler(^(NSArray<NSString *> *strings) {
            // 使用当前活跃场景的第一个窗口作为旧的 key window
            if (@available(iOS 13.0, *)) {
                oldKeyWindow = FLEXUtility.activeScene.windows.firstObject;
            } else {
                oldKeyWindow = [[UIApplication sharedApplication].delegate window];
            }
            wasVisible = window.hidden;
            [window makeKeyAndVisible];
            
            [self showRevertOrDismissAlert:^{
                window.hidden = wasVisible;
                [oldKeyWindow makeKeyWindow];
            }];
        }).enabled(!window.isKeyWindow && !window.hidden);
        make.button(@"关闭").cancelStyle().handler(cancelHandler);
        
        make.textField(@"+/- 窗口级别，例如 5 或 -10");
    } showFrom:self];
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)ip {
    [self.navigationController pushViewController:
        [FLEXObjectExplorerFactory explorerViewControllerForObject:self.sections[ip.section][ip.row]]
    animated:YES];
}

@end
