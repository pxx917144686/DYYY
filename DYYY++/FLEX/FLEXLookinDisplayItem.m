#import "FLEXLookinDisplayItem.h"

@implementation FLEXLookinDisplayItem

- (NSString *)title {
    // 使用存储的title
    if (_title) {
        return _title;
    }
    
    // 存储的title，则动态生成
    if (self.view) {
        return NSStringFromClass([self.view class]);
    } else if (self.layer) {
        return NSStringFromClass([self.layer class]);
    }
    return @"Unknown";
}

- (NSString *)subtitle {
    // 使用存储的subtitle
    if (_subtitle) {
        return _subtitle;
    }
    
    // 存储的subtitle，则动态生成
    if (self.view) {
        return [NSString stringWithFormat:@"<%p>", self.view];
    } else if (self.layer) {
        return [NSString stringWithFormat:@"<%p>", self.layer];
    }
    return @"";
}

- (BOOL)representedForSystemClass {
    // 检查是否已经计算过
    static NSNumber *cachedResult = nil;
    if (cachedResult != nil && _representedForSystemClass == cachedResult.boolValue) {
        return _representedForSystemClass;
    }
    
    // 动态计算并缓存结果
    NSString *className = self.title;
    BOOL isSystemClass = [className hasPrefix:@"UI"] || 
                        [className hasPrefix:@"CA"] || 
                        [className hasPrefix:@"_"];
    
    // 更新实例变量
    _representedForSystemClass = isSystemClass;
    
    return _representedForSystemClass;
}

- (BOOL)isMatchedWithSearchString:(NSString *)string {
    if (string.length == 0) {
        return NO;
    }
    
    NSString *searchString = string.lowercaseString;
    
    // 搜索类名
    if ([self.title.lowercaseString containsString:searchString]) {
        return YES;
    }
    
    // 搜索子标题
    if ([self.subtitle.lowercaseString containsString:searchString]) {
        return YES;
    }
    
    // 搜索内存地址
    if (self.view && [[NSString stringWithFormat:@"%p", self.view] containsString:searchString]) {
        return YES;
    }
    
    if (self.layer && [[NSString stringWithFormat:@"%p", self.layer] containsString:searchString]) {
        return YES;
    }
    
    return NO;
}

- (void)enumerateSelfAndAncestors:(void (^)(FLEXLookinDisplayItem *, BOOL *))block {
    if (!block) return;
    
    BOOL stop = NO;
    FLEXLookinDisplayItem *currentItem = self;
    
    while (currentItem && !stop) {
        block(currentItem, &stop);
        // 这里需要实现获取父级item的逻辑
        currentItem = nil;
    }
}

- (void)enumerateSelfAndChildren:(void (^)(FLEXLookinDisplayItem *))block {
    if (!block) return;
    
    block(self);
    
    for (FLEXLookinDisplayItem *child in self.children) {
        [child enumerateSelfAndChildren:block];
    }
}

- (BOOL)hasValidFrameToRoot {
    if (self.view) {
        UIView *view = self.view;
        while (view.superview) {
            view = view.superview;
        }
        return view != nil;
    }
    return NO;
}

- (CGRect)calculateFrameToRoot {
    if (!self.view) {
        return CGRectZero;
    }
    
    return [self.view convertRect:self.view.bounds toView:nil];
}

- (BOOL)hasPreviewBoxAbility {
    return self.view != nil || self.layer != nil;
}

- (UIImage *)appropriateScreenshot {
    if (self.view) {
        UIGraphicsBeginImageContextWithOptions(self.view.bounds.size, NO, 0);
        [self.view.layer renderInContext:UIGraphicsGetCurrentContext()];
        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        return image;
    }
    return nil;
}

@end