//
// FLEXBlockShortcuts.m
//  FLEX
//
//  由 Tanner 于 1/30/20 创建.
//  版权所有 © 2020 FLEX Team. 保留所有权利.
//

#import "FLEXBlockShortcuts.h"
#import "FLEXShortcut.h"
#import "FLEXBlockDescription.h"
#import "FLEXObjectExplorerFactory.h"

#pragma mark - 
@implementation FLEXBlockShortcuts

#pragma mark 重写

+ (instancetype)forObject:(id)block {
    NSParameterAssert([block isKindOfClass:NSClassFromString(@"NSBlock")]);
    
    FLEXBlockDescription *blockInfo = [FLEXBlockDescription describing:block];
    NSMethodSignature *signature = blockInfo.signature;
    NSArray *blockShortcutRows = @[blockInfo.summary];
    
    if (signature) {
        blockShortcutRows = @[
            blockInfo.summary,
            blockInfo.sourceDeclaration,
            signature.debugDescription,
            [FLEXActionShortcut title:@"查看方法签名"
                subtitle:^NSString *(id block) {
                    return signature.description ?: @"不支持的签名";
                }
                viewer:^UIViewController *(id block) {
                    return [FLEXObjectExplorerFactory explorerViewControllerForObject:signature];
                }
                accessoryType:^UITableViewCellAccessoryType(id view) {
                    if (signature) {
                        return UITableViewCellAccessoryDisclosureIndicator;
                    }
                    return UITableViewCellAccessoryNone;
                }
            ]
        ];
    }
    
    return [self forObject:block additionalRows:blockShortcutRows];
}

- (NSString *)title {
    return @"元数据";
}

- (NSInteger)numberOfLines {
    return 0;
}

@end
