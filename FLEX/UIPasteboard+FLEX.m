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
        NSLog(@"已复制文本到剪贴板");
    } else if([object isKindOfClass:[NSData class]]) {
        [UIPasteboard.generalPasteboard setData:object forPasteboardType:@"public.data"];
        NSLog(@"已复制数据到剪贴板");
    } else if ([object isKindOfClass:[NSNumber class]]) {
        UIPasteboard.generalPasteboard.string = [object stringValue];
        NSLog(@"已复制数值到剪贴板");
    } else if ([object isKindOfClass:[NSURL class]]) {
        // 添加URL支持
        UIPasteboard.generalPasteboard.URL = object;
        NSLog(@"已复制URL到剪贴板");
    } else if ([object isKindOfClass:[UIImage class]]) {
        // 添加图片支持
        UIPasteboard.generalPasteboard.image = object;
        NSLog(@"已复制图片到剪贴板");
    } else if ([object isKindOfClass:[NSDictionary class]] || 
               [object isKindOfClass:[NSArray class]]) {
        // 添加对字典和数组的支持，转为JSON字符串
        NSError *error = nil;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:object 
                                                           options:NSJSONWritingPrettyPrinted 
                                                             error:&error];
        if (jsonData && !error) {
            NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
            UIPasteboard.generalPasteboard.string = jsonString;
            NSLog(@"已复制JSON数据到剪贴板");
        } else {
            NSLog(@"转换JSON失败: %@", error.localizedDescription);
            // 使用描述作为后备方案
            UIPasteboard.generalPasteboard.string = [object description];
            NSLog(@"已复制对象描述到剪贴板");
        }
    } else {
        // TODO：将其设为警告而非异常
        NSLog(@"警告：尝试复制不受支持的类型: %@，将使用对象描述", [object class]);
        UIPasteboard.generalPasteboard.string = [object description];
    }
}

// 添加一个便捷方法，用于显示当前剪贴板内容类型
+ (NSString *)flex_pasteboardContentTypeDescription {
    UIPasteboard *pb = UIPasteboard.generalPasteboard;
    
    if (pb.hasStrings) {
        return @"文本";
    } else if (pb.hasImages) {
        return @"图片";
    } else if (pb.hasURLs) {
        return @"URL链接";
    } else if (pb.hasColors) {
        return @"颜色";
    } else if (pb.pasteboardTypes.count > 0) {
        return [NSString stringWithFormat:@"其他类型: %@", [pb.pasteboardTypes componentsJoinedByString:@", "]];
    }
    
    return @"剪贴板为空";
}

@end
