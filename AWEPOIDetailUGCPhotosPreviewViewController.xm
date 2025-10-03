#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "AwemeHeaders.h"
#import <Photos/Photos.h>
#import "DYYYManager.h"
#import "DYYYToast.h"

// 带进度动画
static void dyyy_addLongPressToPOIPreview(id self);
static void dyyy_handlePOIPreviewLongPress(id self, UILongPressGestureRecognizer *gr);
static void dyyy_doSaveAtPoint(id self, CGPoint p);
static UIImageView *dyyy_findFirstImageView(UIView *view);
static UIImageView *dyyy_findBestImageView(UIView *root, CGPoint location);
static UIImage *dyyy_extractImageFromImageView(UIImageView *iv);
static UIImage *dyyy_extractImageAtPoint(UIView *root, CGPoint location);
static UICollectionView *dyyy_findAnyCollection(UIView *root);
static BOOL dyyy_tryDownloadFromPhotoAtPoint(UIView *root, CGPoint location);
static BOOL dyyy_ensurePhotoAuthThen(void (^grantedBlock)(void));

static const void *kDYYY_POI_LongPressAddedKey = &kDYYY_POI_LongPressAddedKey;
static const void *kDYYY_POI_LongPressAddedToViewKey = &kDYYY_POI_LongPressAddedToViewKey;
static const void *kDYYY_POI_SavingKey = &kDYYY_POI_SavingKey;

%hook AWEPOIDetailUGCPhotosPreviewViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig(animated);
    dyyy_addLongPressToPOIPreview(self);
}

%new
- (void)dyyy_onPOILongPress:(UILongPressGestureRecognizer *)gr {
    dyyy_handlePOIPreviewLongPress(self, gr);
}

// 放宽手势识别以避免退出
%new
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

%end

static void dyyy_addLongPressToPOIPreview(id self) {
    UIView *root = [self valueForKey:@"view"];
    if (!root) return;

    NSNumber *added = objc_getAssociatedObject(self, kDYYY_POI_LongPressAddedKey);
    if ([added boolValue]) return;

    // 将手势加在根视图，确保覆盖所有子视图
    UIView *targetRoot = root;
    NSNumber *addedRoot = objc_getAssociatedObject(targetRoot, kDYYY_POI_LongPressAddedToViewKey);
    if (![addedRoot boolValue]) {
        UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(dyyy_onPOILongPress:)];
        lp.minimumPressDuration = 0.5;
        lp.cancelsTouchesInView = NO;
        lp.numberOfTouchesRequired = 1;
        lp.delegate = (id<UIGestureRecognizerDelegate>)self;
        [targetRoot addGestureRecognizer:lp];
        objc_setAssociatedObject(targetRoot, kDYYY_POI_LongPressAddedToViewKey, @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    UICollectionView *cv = dyyy_findAnyCollection(root);
    if (cv) {
        NSNumber *addedCV = objc_getAssociatedObject(cv, kDYYY_POI_LongPressAddedToViewKey);
        if (![addedCV boolValue]) {
            UILongPressGestureRecognizer *lp2 = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(dyyy_onPOILongPress:)];
            lp2.minimumPressDuration = 0.5;
            lp2.cancelsTouchesInView = NO;
            lp2.numberOfTouchesRequired = 1;
            lp2.delegate = (id<UIGestureRecognizerDelegate>)self;
            [cv addGestureRecognizer:lp2];
            objc_setAssociatedObject(cv, kDYYY_POI_LongPressAddedToViewKey, @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }

    objc_setAssociatedObject(self, kDYYY_POI_LongPressAddedKey, @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void dyyy_handlePOIPreviewLongPress(id self, UILongPressGestureRecognizer *gr) {
    if (gr.state != UIGestureRecognizerStateBegan) return;

    UIView *root = [self valueForKey:@"view"];
    if (!root) return;

    CGPoint p = [gr locationInView:root];
    // 首次使用可能触发相册权限弹窗，先确保授权后再执行保存，避免崩溃
    if (!dyyy_ensurePhotoAuthThen(^{ dyyy_doSaveAtPoint(self, p); })) {
        return; // 正在申请权限，授权后会自动继续
    }

    dyyy_doSaveAtPoint(self, p);
}

static void dyyy_doSaveAtPoint(id self, CGPoint p) {
    UIView *root = [self valueForKey:@"view"];
    if (!root) return;
    
    // 防重复保存：检查是否正在保存
    NSNumber *saving = objc_getAssociatedObject(self, kDYYY_POI_SavingKey);
    if ([saving boolValue]) {
        return; // 正在保存，直接返回
    }
    
    // 设置保存状态
    objc_setAssociatedObject(self, kDYYY_POI_SavingKey, @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // 优先：直接从业务 photo URL 下载（自带进度动画）
    if (dyyy_tryDownloadFromPhotoAtPoint(root, p)) {
        // 下载完成后重置保存状态（延迟3秒，因为下载是异步的）
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            objc_setAssociatedObject(self, kDYYY_POI_SavingKey, @(NO), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        });
        return;
    }
    
    // 回退：从 UIImageView 保存
    UIImageView *iv = dyyy_findBestImageView(root, p);
    UIImage *image = dyyy_extractImageFromImageView(iv);
    if (!image) {
        objc_setAssociatedObject(self, kDYYY_POI_SavingKey, @(NO), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }

    DYYYToast *toast = [[DYYYToast alloc] initWithFrame:[UIScreen mainScreen].bounds];
    dispatch_async(dispatch_get_main_queue(), ^{ [toast show]; [toast setProgress:0.15f]; });

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        CGImageAlphaInfo alphaInfo = image.CGImage ? CGImageGetAlphaInfo(image.CGImage) : kCGImageAlphaNone;
        BOOL hasAlpha = (alphaInfo == kCGImageAlphaPremultipliedLast ||
                         alphaInfo == kCGImageAlphaPremultipliedFirst ||
                         alphaInfo == kCGImageAlphaLast ||
                         alphaInfo == kCGImageAlphaFirst);
        NSData *data = hasAlpha ? UIImagePNGRepresentation(image) : UIImageJPEGRepresentation(image, 0.95);
        if (!data || data.length == 0) {
            dispatch_async(dispatch_get_main_queue(), ^{ 
                [toast dismiss]; 
                objc_setAssociatedObject(self, kDYYY_POI_SavingKey, @(NO), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            });
            return;
        }
        NSString *ext = hasAlpha ? @"png" : @"jpg";
        NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"poi_image_%@.%@", [NSUUID UUID].UUIDString, ext]];
        BOOL ok = [data writeToFile:path atomically:YES];
        dispatch_async(dispatch_get_main_queue(), ^{ [toast setProgress:0.7f]; });
        if (!ok) {
            dispatch_async(dispatch_get_main_queue(), ^{ 
                [toast dismiss]; 
                objc_setAssociatedObject(self, kDYYY_POI_SavingKey, @(NO), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            });
            return;
        }
        NSURL *fileURL = [NSURL fileURLWithPath:path];
        [DYYYManager saveMedia:fileURL mediaType:MediaTypeImage completion:^{
            dispatch_async(dispatch_get_main_queue(), ^{ 
                [toast showSuccessAnimation:nil];
                objc_setAssociatedObject(self, kDYYY_POI_SavingKey, @(NO), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            });
        }];
    });
}

static UIImageView *dyyy_findFirstImageView(UIView *view) {
    if ([view isKindOfClass:[UIImageView class]]) {
        UIImageView *iv = (UIImageView *)view;
        if (iv.image && !iv.hidden && iv.alpha > 0.01) return iv;
    }
    for (UIView *sub in view.subviews) {
        UIImageView *found = dyyy_findFirstImageView(sub);
        if (found) return found;
    }
    return nil;
}

// 筛选最合适的 UIImageView
static UIImageView *dyyy_findBestImageView(UIView *root, CGPoint location) {
    // 触点命中在某个 UICollectionView 的 cell 内，精确定位该 cell 的图片（从命中向上找最近的集合视图）
    UIView *hitForCV = [root hitTest:location withEvent:nil];
    UIView *curCV = hitForCV;
    while (curCV && ![curCV isKindOfClass:[UICollectionView class]]) curCV = curCV.superview;
    if (curCV && [curCV isKindOfClass:[UICollectionView class]]) {
        UICollectionView *cv = (UICollectionView *)curCV;
        CGPoint pInCV = [root convertPoint:location toView:cv];
        NSIndexPath *ip = [cv indexPathForItemAtPoint:pInCV];
        if (ip) {
            UICollectionViewCell *cell = [cv cellForItemAtIndexPath:ip];
            if (cell) {
                UIImageView *ivInCell = dyyy_findFirstImageView(cell.contentView ?: (UIView *)cell);
                if (ivInCell && ivInCell.image && !ivInCell.hidden && ivInCell.alpha > 0.01) {
                    return ivInCell;
                }
            }
        }
    }

    // 触点命中的图片视图
    UIView *hit = [root hitTest:location withEvent:nil];
    UIView *cursor = hit;
    while (cursor) {
        if ([cursor isKindOfClass:[UIImageView class]]) {
            UIImageView *iv = (UIImageView *)cursor;
            if (iv.image && !iv.hidden && iv.alpha > 0.01 && iv.bounds.size.width > 40 && iv.bounds.size.height > 40) {
                return iv;
            }
        }
        cursor = cursor.superview;
    }
    // 回退：全树中第一个可用图片
    return dyyy_findFirstImageView(root);
}

// 返回 image
static UIImage *dyyy_extractImageFromImageView(UIImageView *iv) {
    if (!iv) return nil;
    if (iv.image) return iv.image;
    // 尝试从 layer 的 contents 取图
    id contents = iv.layer.contents;
    if ([contents isKindOfClass:[NSNumber class]] || contents == nil) return nil;
    // 避免崩溃
    return nil;
}

// 通过业务视图 AWEPOIDetailUGCPhotosPreviewScrollView 定位图片模型并下载为 UIImage
static UIImage *dyyy_extractImageAtPoint(UIView *root, CGPoint location) {
    if (!root) return nil;
    UIView *hit = [root hitTest:location withEvent:nil];
    UIView *cursor = hit;
    while (cursor) {
        // 根据你提供的层级：AWEPOIDetailUGCPhotosPreviewScrollView -> imageView / photo
        if ([NSStringFromClass([cursor class]) containsString:@"AWEPOIDetailUGCPhotosPreviewScrollView"]) {
            @try {
                id photo = [cursor valueForKey:@"photo"]; // AWEPOIDetailPhotoBaseInfo *
                NSString *best = nil;
                @try {
                    NSArray *origin = [photo valueForKey:@"originURLList"]; if ([origin isKindOfClass:[NSArray class]] && origin.count>0) best = origin.firstObject;
                } @catch (__unused NSException *e) {}
                if (!best) {
                    @try {
                        NSArray *list = [photo valueForKey:@"urlList"]; if ([list isKindOfClass:[NSArray class]] && list.count>0) {
                            for (id u in list) { if ([u isKindOfClass:[NSString class]] && ![(NSString*)u hasSuffix:@".image"]) { best = (NSString*)u; break; } }
                            if (!best) best = list.firstObject;
                        }
                    } @catch (__unused NSException *e) {}
                }
                if (best && best.length > 0) {
                    NSURL *u = [NSURL URLWithString:best];
                    if (!u) return nil;
                    NSData *d = [NSData dataWithContentsOfURL:u];
                    if (d.length > 0) return [UIImage imageWithData:d];
                }
            } @catch (__unused NSException *e) {}
            break;
        }
        cursor = cursor.superview;
    }
    return nil;
}

// 查找任意 UICollectionView
static UICollectionView *dyyy_findAnyCollection(UIView *root) {
    if (!root) return nil;
    if ([root isKindOfClass:[UICollectionView class]]) return (UICollectionView *)root;
    for (UIView *sub in root.subviews) {
        UICollectionView *c = dyyy_findAnyCollection(sub);
        if (c) return c;
    }
    return nil;
}

// 直接通过业务 photo URL 触发下载保存
static BOOL dyyy_tryDownloadFromPhotoAtPoint(UIView *root, CGPoint location) {
    if (!root) return NO;
    UIView *hit = [root hitTest:location withEvent:nil];
    UIView *cursor = hit;
    while (cursor) {
        if ([NSStringFromClass([cursor class]) containsString:@"AWEPOIDetailUGCPhotosPreviewScrollView"]) {
            @try {
                id photo = [cursor valueForKey:@"photo"]; // AWEPOIDetailPhotoBaseInfo *
                NSString *best = nil;
                @try {
                    NSArray *origin = [photo valueForKey:@"originURLList"]; if ([origin isKindOfClass:[NSArray class]] && origin.count>0) best = origin.firstObject;
                } @catch (__unused NSException *e) {}
                if (!best) {
                    @try {
                        NSArray *list = [photo valueForKey:@"urlList"]; if ([list isKindOfClass:[NSArray class]] && list.count>0) {
                            for (id u in list) { if ([u isKindOfClass:[NSString class]] && ![(NSString*)u hasSuffix:@".image"]) { best = (NSString*)u; break; } }
                            if (!best) best = list.firstObject;
                        }
                    } @catch (__unused NSException *e) {}
                }
                if (best && best.length > 0) {
                    NSURL *url = [NSURL URLWithString:best];
                    if (url) {
                        [DYYYManager downloadMediaWithProgress:url
                                                     mediaType:MediaTypeImage
                                                      progress:^(float progress) {}
                                                    completion:^(BOOL success, NSURL *fileURL) {
                                                        if (success && fileURL) {
                                                            [DYYYManager saveMedia:fileURL mediaType:MediaTypeImage completion:^{}];
                                                        }
                                                    }];
                        return YES;
                    }
                }
            } @catch (__unused NSException *e) {}
            break;
        }
        cursor = cursor.superview;
    }
    return NO;
}

// 确保相册权限，避免首次使用时崩溃
static BOOL dyyy_ensurePhotoAuthThen(void (^grantedBlock)(void)) {
    if (@available(iOS 14.0, *)) {
        PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatusForAccessLevel:PHAccessLevelAddOnly];
        if (status == PHAuthorizationStatusAuthorized || status == PHAuthorizationStatusLimited) {
            return YES;
        }
        if (status == PHAuthorizationStatusNotDetermined) {
            [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelAddOnly handler:^(PHAuthorizationStatus s) {
                if (s == PHAuthorizationStatusAuthorized || s == PHAuthorizationStatusLimited) {
                    dispatch_async(dispatch_get_main_queue(), ^{ if (grantedBlock) grantedBlock(); });
                }
            }];
            return NO;
        }
        return YES; // 其他状态交由 DYYYManager 内部再处理
    } else {
        PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
        if (status == PHAuthorizationStatusAuthorized) return YES;
        if (status == PHAuthorizationStatusNotDetermined) {
            [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus s) {
                if (s == PHAuthorizationStatusAuthorized) {
                    dispatch_async(dispatch_get_main_queue(), ^{ if (grantedBlock) grantedBlock(); });
                }
            }];
            return NO;
        }
        return YES;
    }
}