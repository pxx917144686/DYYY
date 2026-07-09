//
//  DYYYFLEXRuntimeBrowserToolbar.m
//  FLEX
//
//  Created by Tanner on 6/11/17.
//  Copyright © 2017 Tanner Bennett. All rights reserved.
//

#import "DYYYFLEXRuntimeBrowserToolbar.h"
#import "DYYYFLEXRuntimeKeyPathTokenizer.h"

@interface DYYYFLEXRuntimeBrowserToolbar ()
@property (nonatomic, copy) FLEXKBToolbarAction tapHandler;
@end

@implementation DYYYFLEXRuntimeBrowserToolbar

+ (instancetype)toolbarWithHandler:(FLEXKBToolbarAction)tapHandler suggestions:(NSArray<NSString *> *)suggestions {
    NSArray *buttons = [self
        buttonsForKeyPath:DYYYFLEXRuntimeKeyPath.empty suggestions:suggestions handler:tapHandler
    ];

    DYYYFLEXRuntimeBrowserToolbar *me = [self toolbarWithButtons:buttons];
    me.tapHandler = tapHandler;
    return me;
}

+ (NSArray<DYYYFLEXKBToolbarButton*> *)buttonsForKeyPath:(DYYYFLEXRuntimeKeyPath *)keyPath
                                     suggestions:(NSArray<NSString *> *)suggestions
                                         handler:(FLEXKBToolbarAction)handler {
    NSMutableArray *buttons = [NSMutableArray new];
    DYYYFLEXSearchToken *lastKey = nil;
    BOOL lastKeyIsMethod = NO;

    if (keyPath.methodKey) {
        lastKey = keyPath.methodKey;
        lastKeyIsMethod = YES;
    } else {
        lastKey = keyPath.classKey ?: keyPath.bundleKey;
    }

    switch (lastKey.options) {
        case TBWildcardOptionsNone:
        case TBWildcardOptionsAny:
            if (lastKeyIsMethod) {
                if (!keyPath.instanceMethods) {
                    [buttons addObject:[DYYYFLEXKBToolbarButton buttonWithTitle:@"-" action:handler]];
                    [buttons addObject:[DYYYFLEXKBToolbarButton buttonWithTitle:@"+" action:handler]];
                }
                [buttons addObject:[DYYYFLEXKBToolbarButton buttonWithTitle:@"*" action:handler]];
            } else {
                [buttons addObject:[DYYYFLEXKBToolbarButton buttonWithTitle:@"*" action:handler]];
                [buttons addObject:[DYYYFLEXKBToolbarButton buttonWithTitle:@"*." action:handler]];
            }
            break;

        default: {
            if (lastKey.options & TBWildcardOptionsPrefix) {
                if (lastKeyIsMethod) {
                    if (lastKey.string.length) {
                        [buttons addObject:[DYYYFLEXKBToolbarButton buttonWithTitle:@"*" action:handler]];
                    }
                } else {
                    if (lastKey.string.length) {
                        [buttons addObject:[DYYYFLEXKBToolbarButton buttonWithTitle:@"*." action:handler]];
                    }
                }
            }

            else if (lastKey.options & TBWildcardOptionsSuffix) {
                if (!lastKeyIsMethod) {
                    [buttons addObject:[DYYYFLEXKBToolbarButton buttonWithTitle:@"*" action:handler]];
                    [buttons addObject:[DYYYFLEXKBToolbarButton buttonWithTitle:@"*." action:handler]];
                }
            }
        }
    }
    
    for (NSString *suggestion in suggestions) {
        [buttons addObject:[DYYYFLEXKBToolbarSuggestedButton buttonWithTitle:suggestion action:handler]];
    }

    return buttons;
}

- (void)setKeyPath:(DYYYFLEXRuntimeKeyPath *)keyPath suggestions:(NSArray<NSString *> *)suggestions {
    self.buttons = [self.class
        buttonsForKeyPath:keyPath suggestions:suggestions handler:self.tapHandler
    ];
}

@end
