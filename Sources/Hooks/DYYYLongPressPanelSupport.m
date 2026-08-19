//
//  DYYYLongPressPanelSupport.m
//  DYYY
//
//  长按面板辅助 category 实现（UIView 快照）。
//

#import "DYYYLongPressPanelSupport.h"

@implementation UIView (DYYYSnapshot)
- (UIImage *)dyyy_snapshotImage {
    UIGraphicsBeginImageContextWithOptions(self.bounds.size, NO, [UIScreen mainScreen].scale);
    [self.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}
@end
