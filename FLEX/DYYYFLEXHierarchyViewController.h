//
//  DYYYFLEXHierarchyViewController.h
//  FLEX
//
//  Created by Tanner Bennett on 1/9/20.
//  Copyright © 2020 FLEX Team. All rights reserved.
//

#import "DYYYFLEXNavigationController.h"

@protocol FLEXHierarchyDelegate <NSObject>
- (void)viewHierarchyDidDismiss:(UIView *)selectedView;
@end

/// A navigation controller which manages two child view controllers:
/// a 3D Reveal-like hierarchy explorer, and a 2D tree-list hierarchy explorer.
@interface DYYYFLEXHierarchyViewController : DYYYFLEXNavigationController

+ (instancetype)delegate:(id<FLEXHierarchyDelegate>)delegate;
+ (instancetype)delegate:(id<FLEXHierarchyDelegate>)delegate
              viewsAtTap:(NSArray<UIView *> *)viewsAtTap
            selectedView:(UIView *)selectedView;

- (void)toggleHierarchyMode;

@end
