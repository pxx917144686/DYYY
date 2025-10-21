//
//  FLEXClassShortcuts.m
//  FLEX
//
//  Created by Tanner Bennett on 11/22/19.
//  Copyright © 2020 FLEX Team. All rights reserved.
//

#import "FLEXClassShortcuts.h"
#import "FLEXShortcut.h"
#import "FLEXObjectExplorerFactory.h"
#import "FLEXObjectListViewController.h"
#import "NSObject+FLEX_Reflection.h"

@interface FLEXClassShortcuts ()
@property (nonatomic, readonly) Class cls;
@end

@implementation FLEXClassShortcuts

+ (instancetype)forObject:(Class)cls {
    // 这些附加行将出现在快捷方式部分的开头。
    // 下面的方法编写方式使它们不会干扰
    // 与这些一起注册的属性/等
    return [self forObject:cls additionalRows:@[
        [FLEXActionShortcut title:@"查找活跃实例" subtitle:nil
            viewer:^UIViewController *(id obj) {
                return [FLEXObjectListViewController
                    instancesOfClassWithName:NSStringFromClass(obj)
                    retained:NO
                ];
            }
            accessoryType:^UITableViewCellAccessoryType(id obj) {
                return UITableViewCellAccessoryDisclosureIndicator;
            }
        ],
        [FLEXActionShortcut title:@"列出子类" subtitle:nil
            viewer:^UIViewController *(id obj) {
                NSString *name = NSStringFromClass(obj);
                return [FLEXObjectListViewController subclassesOfClassWithName:name];
            }
            accessoryType:^UITableViewCellAccessoryType(id view) {
                return UITableViewCellAccessoryDisclosureIndicator;
            }
        ],
        [FLEXActionShortcut title:@"浏览类的Bundle"
            subtitle:^NSString *(id obj) {
                return [self shortNameForBundlePath:[NSBundle bundleForClass:obj].executablePath];
            }
            viewer:^UIViewController *(id obj) {
                NSBundle *bundle = [NSBundle bundleForClass:obj];
                return [FLEXObjectExplorerFactory explorerViewControllerForObject:bundle];
            }
            accessoryType:^UITableViewCellAccessoryType(id view) {
                return UITableViewCellAccessoryDisclosureIndicator;
            }
        ],
    ]];
}

+ (NSString *)shortNameForBundlePath:(NSString *)imageName {
    NSArray<NSString *> *components = [imageName componentsSeparatedByString:@"/"];
    if (components.count >= 2) {
        return [NSString stringWithFormat:@"%@/%@",
            components[components.count - 2],
            components[components.count - 1]
        ];
    }

    return imageName.lastPathComponent;
}

@end
