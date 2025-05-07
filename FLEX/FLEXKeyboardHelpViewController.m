//
//  FLEXKeyboardHelpViewController.m
//  FLEX
//
//  Created by Ryan Olson on 9/19/15.
//  Copyright © 2015 f. All rights reserved.
//
// 遇到问题联系中文翻译作者：pxx917144686

#import "FLEXKeyboardHelpViewController.h"
#import "FLEXKeyboardShortcutManager.h"

@interface FLEXKeyboardHelpViewController ()

@property (nonatomic) UITextView *textView;

@end

@implementation FLEXKeyboardHelpViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.textView = [[UITextView alloc] initWithFrame:self.view.bounds];
    self.textView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.textView];
#if TARGET_OS_SIMULATOR
    self.textView.text = FLEXKeyboardShortcutManager.sharedManager.keyboardShortcutsDescription;
#endif
    self.textView.backgroundColor = UIColor.blackColor;
    self.textView.textColor = UIColor.whiteColor;
    self.textView.font = [UIFont boldSystemFontOfSize:14.0];
    self.navigationController.navigationBar.barStyle = UIBarStyleBlack;
    
    self.title = @"模拟器快捷键";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(donePressed:)];
}

- (void)donePressed:(id)sender {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

@end
