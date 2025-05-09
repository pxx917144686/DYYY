//
//  UIPasteboard+FLEX.h
//  FLEX
//
//  Created by Tanner Bennett on 12/9/19.
//  Copyright © 2020 FLEX Team. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIPasteboard (FLEX)

/// 用于复制一个对象，该对象可以是字符串、数据或数字
- (void)flex_copy:(id)unknownType;

@end
