// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXUtility.h
//  Flipboard
//
//  由 Ryan Olson 创建于 4/18/14.
//  版权所有 (c) 2020 FLEX Team。保留所有权利。
//

#import <Availability.h>
#import <AvailabilityInternal.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "FLEXTypeEncodingParser.h"
#import "FLEXAlert.h"
#import "NSArray+FLEX.h"
#import "UIFont+FLEX.h"
#import "FLEXMacros.h"

@interface FLEXUtility : NSObject

/// 应用程序的主窗口，如果它不是 \c FLEXWindow。
/// 如果是，则返回 \c FLEXWindow.previousKeyWindow。
@property (nonatomic, readonly, class) UIWindow *appKeyWindow;
/// @return +[UIWindow allWindowsIncludingInternalWindows:onlyVisibleWindows:] 的结果
@property (nonatomic, readonly, class) NSArray<UIWindow *> *allWindows;
/// 应用程序的第一个活动的 \c UIWindowScene。
@property (nonatomic, readonly, class) UIWindowScene *activeScene API_AVAILABLE(ios(13.0));
/// @return 给定窗口的最顶层视图控制器
+ (UIViewController *)topViewControllerInWindow:(UIWindow *)window;

+ (UIColor *)consistentRandomColorForObject:(id)object;
+ (NSString *)descriptionForView:(UIView *)view includingFrame:(BOOL)includeFrame;
+ (NSString *)stringForCGRect:(CGRect)rect;
+ (UIViewController *)viewControllerForView:(UIView *)view;
+ (UIViewController *)viewControllerForAncestralView:(UIView *)view;
+ (UIImage *)previewImageForView:(UIView *)view;
+ (UIImage *)previewImageForLayer:(CALayer *)layer;
+ (NSString *)detailDescriptionForView:(UIView *)view;
+ (UIImage *)circularImageWithColor:(UIColor *)color radius:(CGFloat)radius;
+ (UIColor *)hierarchyIndentPatternColor;
+ (NSString *)pointerToString:(void *)ptr;
+ (NSString *)addressOfObject:(id)object;
+ (NSString *)stringByEscapingHTMLEntitiesInString:(NSString *)originalString;
+ (UIInterfaceOrientationMask)infoPlistSupportedInterfaceOrientationsMask;
+ (UIImage *)thumbnailedImageWithMaxPixelDimension:(NSInteger)dimension fromImageData:(NSData *)data;
+ (NSString *)stringFromRequestDuration:(NSTimeInterval)duration;
+ (NSString *)statusCodeStringFromURLResponse:(NSURLResponse *)response;
+ (BOOL)isErrorStatusCodeFromURLResponse:(NSURLResponse *)response;
+ (NSArray<NSURLQueryItem *> *)itemsFromQueryString:(NSString *)query;
+ (NSString *)prettyJSONStringFromData:(NSData *)data;
+ (BOOL)isValidJSONData:(NSData *)data;
+ (NSData *)inflatedDataFromCompressedData:(NSData *)compressedData;
+ (BOOL)hasCompressedContentEncoding:(NSURLRequest *)request;

// Swizzling 工具类

+ (SEL)swizzledSelectorForSelector:(SEL)selector;
+ (BOOL)instanceRespondsButDoesNotImplementSelector:(SEL)selector class:(Class)cls;
+ (void)replaceImplementationOfKnownSelector:(SEL)originalSelector onClass:(Class)cls withBlock:(id)block swizzledSelector:(SEL)swizzledSelector;
+ (void)replaceImplementationOfSelector:(SEL)selector withSelector:(SEL)swizzledSelector forClass:(Class)cls withMethodDescription:(struct objc_method_description)methodDescription implementationBlock:(id)implementationBlock undefinedBlock:(id)undefinedBlock;

@end
