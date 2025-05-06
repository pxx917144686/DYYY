// 遇到问题联系中文翻译作者：pxx917144686
//
//  UIPasteboard+FLEX.m
//  FLEX
//
//  由 Tanner Bennett 创建于 12/9/19.
//  版权所有 © 2020 FLEX Team。保留所有权利。
//

#import "UIPasteboard+FLEX.h"

@implementation UIPasteboard (FLEX)

- (void)flex_copy:(id)object {
    if (!object) {
        return;
    }
    
    if ([object isKindOfClass:[NSString class]]) {
        UIPasteboard.generalPasteboard.string = object;
    } else if([object isKindOfClass:[NSData class]]) {
        [UIPasteboard.generalPasteboard setData:object forPasteboardType:@"public.data"];
    } else if ([object isKindOfClass:[NSNumber class]]) {
        UIPasteboard.generalPasteboard.string = [object stringValue];
    } else {
        // TODO：将其设为警告而非异常
        [NSException raise:NSInternalInconsistencyException
                    format:@"尝试复制不受支持的类型: %@", [object class]];
    }
}

@end
