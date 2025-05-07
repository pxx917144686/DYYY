// 遇到问题联系中文翻译作者：pxx917144686
#import "FLEXToolbarItem.h"

@implementation FLEXToolbarItem

+ (instancetype)itemWithTitle:(NSString *)title image:(UIImage *)image {
    FLEXToolbarItem *item = [[self alloc] init];
    item.title = title;
    item.image = image;
    return item;
}

- (NSArray *)toolbarItems {
    UIImage *browserImage = [UIImage systemImageNamed:@"safari"];
    return @[
        [self.class itemWithTitle:@"浏览器" image:browserImage],
    ];
}

@end