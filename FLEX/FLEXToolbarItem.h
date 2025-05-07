// 遇到问题联系中文翻译作者：pxx917144686
#import <UIKit/UIKit.h>

@interface FLEXToolbarItem : UIBarButtonItem

+ (instancetype)itemWithTitle:(NSString *)title image:(UIImage *)image;
- (NSArray *)toolbarItems;

@end