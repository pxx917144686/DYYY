// 遇到问题联系中文翻译作者：pxx917144686
#import "FLEXManager.h"

@implementation FLEXManager (Defaults)

- (void)setupDefaultSettings {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    [defaults registerDefaults:@{
        @"显示网络请求": @YES,
        @"启用日志记录": @YES,
        @"显示类层级": @YES,
        @"过滤私有API": @NO,
        @"显示ivar预览": @YES
    }];
}

@end