//
//  DYYYFHSViewSnapshot.h
//  FLEX
//
//  Created by Tanner Bennett on 1/9/20.
//  Copyright © 2020 FLEX Team. All rights reserved.
//

#import "DYYYFHSView.h"

NS_ASSUME_NONNULL_BEGIN

@interface DYYYFHSViewSnapshot : NSObject

+ (instancetype)snapshotWithView:(DYYYFHSView *)view;

@property (nonatomic, readonly) DYYYFHSView *view;

@property (nonatomic, readonly) NSString *title;
/// Whether or not this view item should be visually distinguished
@property (nonatomic, readwrite) BOOL important;

@property (nonatomic, readonly) CGRect frame;
@property (nonatomic, readonly) BOOL hidden;
@property (nonatomic, readonly) UIImage *snapshotImage;

@property (nonatomic, readonly) NSArray<DYYYFHSViewSnapshot *> *children;
@property (nonatomic, readonly) NSString *summary;

/// Returns a different color based on whether or not the view is important
@property (nonatomic, readonly) UIColor *headerColor;

- (DYYYFHSViewSnapshot *)snapshotForView:(UIView *)view;

@end

NS_ASSUME_NONNULL_END
