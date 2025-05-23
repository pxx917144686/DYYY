//
//  FLEXShortcutsFactory+Defaults.m
//  FLEX
//
//  由 Tanner Bennett 创建于 8/29/19.
//  版权所有 © 2020 FLEX Team. 保留所有权利。
//

#import "FLEXShortcutsFactory+Defaults.h"
#import "FLEXShortcut.h"
#import "FLEXMacros.h"
#import "FLEXRuntimeUtility.h"
#import "NSArray+FLEX.h"
#import "NSObject+FLEX_Reflection.h"
#import "FLEXObjcInternal.h"
#import "Cocoa+FLEXShortcuts.h"

#pragma mark - UIApplication

@implementation FLEXShortcutsFactory (UIApplication)

+ (void)load { FLEX_EXIT_IF_NO_CTORS()
    // sharedApplication 类属性可能直到 iOS 10 才作为
    // 字面类属性添加
    FLEXRuntimeUtilityTryAddObjectProperty(
        2, sharedApplication, UIApplication.flex_metaclass, UIApplication, PropertyKey(ReadOnly)
    );
    
    self.append.classProperties(@[@"sharedApplication"]).forClass(UIApplication.flex_metaclass);
    self.append.properties(@[
        @"delegate", @"keyWindow", @"windows"
    ]).forClass(UIApplication.class);

    if (@available(iOS 13, *)) {
        self.append.properties(@[
            @"connectedScenes", @"openSessions", @"supportsMultipleScenes"
        ]).forClass(UIApplication.class);
    }
}

@end

#pragma mark - Views

@implementation FLEXShortcutsFactory (Views)

+ (void)load { FLEX_EXIT_IF_NO_CTORS()
    // UIView 和其他一些类的一个特点：很多 `@property` 
    // 从运行时的角度来看实际上不是属性。
    //
    // 如果还没有添加这些属性，我们会在运行时将它们添加到类中。
    // 这样，我们就可以使用我们的属性编辑器来访问和更改它们。
    // 属性特性与其头文件中声明的特性匹配。

    // UIView, 公共
    Class UIView_ = UIView.class;
    FLEXRuntimeUtilityTryAddNonatomicProperty(2, frame, UIView_, CGRect);
    FLEXRuntimeUtilityTryAddNonatomicProperty(2, alpha, UIView_, CGFloat);
    FLEXRuntimeUtilityTryAddNonatomicProperty(2, clipsToBounds, UIView_, BOOL);
    FLEXRuntimeUtilityTryAddNonatomicProperty(2, opaque, UIView_, BOOL, PropertyKeyGetter(isOpaque));
    FLEXRuntimeUtilityTryAddNonatomicProperty(2, hidden, UIView_, BOOL, PropertyKeyGetter(isHidden));
    FLEXRuntimeUtilityTryAddObjectProperty(2, backgroundColor, UIView_, UIColor, PropertyKey(Copy));
    FLEXRuntimeUtilityTryAddObjectProperty(6, constraints, UIView_, NSArray, PropertyKey(ReadOnly));
    FLEXRuntimeUtilityTryAddObjectProperty(2, subviews, UIView_, NSArray, PropertyKey(ReadOnly));
    FLEXRuntimeUtilityTryAddObjectProperty(2, superview, UIView_, UIView, PropertyKey(ReadOnly));
    FLEXRuntimeUtilityTryAddObjectProperty(7, tintColor, UIView_, UIView);

    // UIButton, 私有
    FLEXRuntimeUtilityTryAddObjectProperty(2, font, UIButton.class, UIFont, PropertyKey(ReadOnly));
    
    // 仅从 iOS 3.2 开始可用，但我们从未支持 iOS 3，所以无所谓
    NSArray *ivars = @[@"_gestureRecognizers"];
    NSArray *methods = @[@"sizeToFit", @"setNeedsLayout", @"removeFromSuperview"];

    // UIView
    self.append.ivars(ivars).methods(methods).properties(@[
        @"frame", @"bounds", @"center", @"transform",
        @"backgroundColor", @"alpha", @"opaque", @"hidden",
        @"clipsToBounds", @"userInteractionEnabled", @"layer",
        @"superview", @"subviews",
        @"accessibilityIdentifier", @"accessibilityLabel"
    ]).forClass(UIView.class);

    // UILabel
    self.append.ivars(ivars).methods(methods).properties(@[
        @"text", @"attributedText", @"font", @"frame",
        @"textColor", @"textAlignment", @"numberOfLines",
        @"lineBreakMode", @"enabled", @"backgroundColor",
        @"alpha", @"hidden", @"preferredMaxLayoutWidth",
        @"superview", @"subviews",
        @"accessibilityIdentifier", @"accessibilityLabel"
    ]).forClass(UILabel.class);

    // UIWindow
    self.append.ivars(ivars).properties(@[
        @"rootViewController", @"windowLevel", @"keyWindow",
        @"frame", @"bounds", @"center", @"transform",
        @"backgroundColor", @"alpha", @"opaque", @"hidden",
        @"clipsToBounds", @"userInteractionEnabled", @"layer",
        @"subviews"
    ]).forClass(UIWindow.class);

    if (@available(iOS 13, *)) {
        self.append.properties(@[@"windowScene"]).forClass(UIWindow.class);
    }

    ivars = @[@"_targetActions", @"_gestureRecognizers"];
    
    // 属性在 iOS 10 中添加，但我们希望在 iOS 9 上也有
    FLEXRuntimeUtilityTryAddObjectProperty(9, allTargets, UIControl.class, NSArray, PropertyKey(ReadOnly));

    // UIControl
    self.append.ivars(ivars).methods(methods).properties(@[
        @"enabled", @"allTargets", @"frame",
        @"backgroundColor", @"hidden", @"clipsToBounds",
        @"userInteractionEnabled", @"superview", @"subviews",
        @"accessibilityIdentifier", @"accessibilityLabel"
    ]).forClass(UIControl.class);

    // UIButton
    self.append.ivars(ivars).properties(@[
        @"titleLabel", @"font", @"imageView", @"tintColor",
        @"currentTitle", @"currentImage", @"enabled", @"frame",
        @"superview", @"subviews",
        @"accessibilityIdentifier", @"accessibilityLabel"
    ]).forClass(UIButton.class);
    
    // UIImageView
    self.append.properties(@[
        @"image", @"animationImages", @"frame", @"bounds", @"center",
        @"transform", @"alpha", @"hidden", @"clipsToBounds",
        @"userInteractionEnabled", @"layer", @"superview", @"subviews",
        @"accessibilityIdentifier", @"accessibilityLabel"
    ]).forClass(UIImageView.class);
}

@end


#pragma mark - View Controllers

@implementation FLEXShortcutsFactory (ViewControllers)

+ (void)load { FLEX_EXIT_IF_NO_CTORS()
    // toolbarItems 实际上不是一个属性，使其成为一个属性
    FLEXRuntimeUtilityTryAddObjectProperty(3, toolbarItems, UIViewController.class, NSArray);
    
    // UIViewController
    self.append
        .properties(@[
            @"viewIfLoaded", @"title", @"navigationItem", @"toolbarItems", @"tabBarItem",
            @"childViewControllers", @"navigationController", @"tabBarController", @"splitViewController",
            @"parentViewController", @"presentedViewController", @"presentingViewController",
        ])
        .methods(@[@"view"])
        .forClass(UIViewController.class);
    
    // UIAlertController
    NSMutableArray *alertControllerProps = @[
        @"title", @"message", @"actions", @"textFields",
        @"preferredAction", @"presentingViewController", @"viewIfLoaded",
    ].mutableCopy;
    if (@available(iOS 14.0, *)) {
        [alertControllerProps insertObject:@"image" atIndex:4];
    }
    self.append
        .properties(alertControllerProps)
        .methods(@[@"addAction:"])
        .forClass(UIAlertController.class);
    self.append.properties(@[
        @"title", @"style", @"enabled", @"flex_styleName",
        @"image", @"keyCommandInput", @"_isPreferred", @"_alertController",
    ]).forClass(UIAlertAction.class);
}

@end


#pragma mark - UIImage

@implementation FLEXShortcutsFactory (UIImage)

+ (void)load { FLEX_EXIT_IF_NO_CTORS()
    self.append.methods(@[
        @"CGImage", @"CIImage"
    ]).properties(@[
        @"scale", @"size", @"capInsets",
        @"alignmentRectInsets", @"duration", @"images"
    ]).forClass(UIImage.class);

    if (@available(iOS 13, *)) {
        self.append.properties(@[@"symbolImage"]).forClass(UIImage.class);
    }
}

@end


#pragma mark - NSBundle

@implementation FLEXShortcutsFactory (NSBundle)

+ (void)load { FLEX_EXIT_IF_NO_CTORS()
    self.append.properties(@[
        @"bundleIdentifier", @"principalClass",
        @"infoDictionary", @"bundlePath",
        @"executablePath", @"loaded"
    ]).forClass(NSBundle.class);
}

@end


#pragma mark - Classes

@implementation FLEXShortcutsFactory (Classes)

+ (void)load { FLEX_EXIT_IF_NO_CTORS()
    self.append.classMethods(@[@"new", @"alloc"]).forClass(NSObject.flex_metaclass);
}

@end


#pragma mark - Activities

@implementation FLEXShortcutsFactory (Activities)

+ (void)load { FLEX_EXIT_IF_NO_CTORS()
    // 属性在 iOS 10 中添加，但我们希望在 iOS 9 上也有
    FLEXRuntimeUtilityTryAddNonatomicProperty(9, item, UIActivityItemProvider.class, id, PropertyKey(ReadOnly));
    
    self.append.properties(@[
        @"item", @"placeholderItem", @"activityType"
    ]).forClass(UIActivityItemProvider.class);

    self.append.properties(@[
        @"activityItems", @"applicationActivities", @"excludedActivityTypes", @"completionHandler"
    ]).forClass(UIActivityViewController.class);
}

@end


#pragma mark - Blocks

@implementation FLEXShortcutsFactory (Blocks)

+ (void)load { FLEX_EXIT_IF_NO_CTORS()
    self.append.methods(@[@"invoke"]).forClass(NSClassFromString(@"NSBlock"));
}

@end

#pragma mark - Foundation

@implementation FLEXShortcutsFactory (Foundation)

+ (void)load { FLEX_EXIT_IF_NO_CTORS()
    self.append.properties(@[
        @"configuration", @"delegate", @"delegateQueue", @"sessionDescription",
    ]).methods(@[
        @"dataTaskWithURL:", @"finishTasksAndInvalidate", @"invalidateAndCancel",
    ]).forClass(NSURLSession.class);
    
    self.append.methods(@[
        @"cachedResponseForRequest:", @"storeCachedResponse:forRequest:",
        @"storeCachedResponse:forDataTask:", @"removeCachedResponseForRequest:",
        @"removeCachedResponseForDataTask:", @"removeCachedResponsesSinceDate:",
        @"removeAllCachedResponses",
    ]).forClass(NSURLCache.class);
    
    
    self.append.methods(@[
        @"postNotification:", @"postNotificationName:object:userInfo:",
        @"addObserver:selector:name:object:", @"removeObserver:",
        @"removeObserver:name:object:",
    ]).forClass(NSNotificationCenter.class);
    
    // NSTimeZone 类属性不是实际属性
    FLEXRuntimeUtilityTryAddObjectProperty(2, localTimeZone, NSTimeZone.flex_metaclass, NSTimeZone);
    FLEXRuntimeUtilityTryAddObjectProperty(2, systemTimeZone, NSTimeZone.flex_metaclass, NSTimeZone);
    FLEXRuntimeUtilityTryAddObjectProperty(2, defaultTimeZone, NSTimeZone.flex_metaclass, NSTimeZone);
    FLEXRuntimeUtilityTryAddObjectProperty(2, knownTimeZoneNames, NSTimeZone.flex_metaclass, NSArray);
    FLEXRuntimeUtilityTryAddObjectProperty(2, abbreviationDictionary, NSTimeZone.flex_metaclass, NSDictionary);
    
    self.append.classMethods(@[
        @"timeZoneWithName:", @"timeZoneWithAbbreviation:", @"timeZoneForSecondsFromGMT:",
    ]).forClass(NSTimeZone.flex_metaclass);
    
    self.append.classProperties(@[
        @"defaultTimeZone", @"systemTimeZone", @"localTimeZone",
    ]).forClass(NSTimeZone.class);
    
    // UTF8String 不是底层的实际属性
    FLEXRuntimeUtilityTryAddNonatomicProperty(2, UTF8String, NSString.class, const char *, PropertyKey(ReadOnly));
    
    self.append.properties(@[@"length"]).methods(@[@"characterAtIndex:"]).forClass(NSString.class);
    self.append.methods(@[
        @"writeToFile:atomically:", @"subdataWithRange:", @"isEqualToData:",
    ]).properties(@[
        @"length", @"bytes",
    ]).forClass(NSData.class);
    
    self.append.classMethods(@[
        @"dataWithJSONObject:options:error:",
        @"JSONObjectWithData:options:error:",
        @"isValidJSONObject:",
    ]).forClass(NSJSONSerialization.class);
    
    // NSArray
    self.append.classMethods(@[
        @"arrayWithObject:", @"arrayWithContentsOfFile:"
    ]).forClass(NSArray.flex_metaclass);
    self.append.methods(@[
        @"valueForKeyPath:", @"subarrayWithRange:",
        @"arrayByAddingObject:", @"arrayByAddingObjectsFromArray:",
        @"filteredArrayUsingPredicate:", @"subarrayWithRange:",
        @"containsObject:", @"objectAtIndex:", @"indexOfObject:",
        @"makeObjectsPerformSelector:", @"makeObjectsPerformSelector:withObject:",
        @"sortedArrayUsingSelector:", @"reverseObjectEnumerator",
        @"isEqualToArray:", @"mutableCopy",
    ]).forClass(NSArray.class);
    // NSDictionary
    self.append.methods(@[
        @"objectForKey:", @"valueForKeyPath:",
        @"isEqualToDictionary:", @"mutableCopy",
    ]).forClass(NSDictionary.class);
    // NSSet
    self.append.classMethods(@[
        @"setWithObject:", @"setWithArray:"
    ]).forClass(NSSet.flex_metaclass);
    self.append.methods(@[
        @"allObjects", @"valueForKeyPath:", @"containsObject:",
        @"setByAddingObject:", @"setByAddingObjectsFromArray:",
        @"filteredSetUsingPredicate:", @"isSubsetOfSet:",
        @"makeObjectsPerformSelector:", @"makeObjectsPerformSelector:withObject:",
        @"reverseObjectEnumerator", @"isEqualToSet:", @"mutableCopy",
    ]).forClass(NSSet.class);
    
    // NSMutableArray
    self.prepend.methods(@[
        @"addObject:", @"insertObject:atIndex:", @"addObjectsFromArray:", 
        @"removeObject:", @"removeObjectAtIndex:",
        @"removeObjectsInArray:", @"removeAllObjects", 
        @"removeLastObject", @"filterUsingPredicate:",
        @"sortUsingSelector:", @"copy",
    ]).forClass(NSMutableArray.class);
    // NSMutableDictionary
    self.prepend.methods(@[
        @"setObject:forKey:", @"removeObjectForKey:",
        @"removeAllObjects", @"removeObjectsForKeys:", @"copy",
    ]).forClass(NSMutableDictionary.class);
    // NSMutableSet
    self.prepend.methods(@[
        @"addObject:", @"removeObject:", @"filterUsingPredicate:",
        @"removeAllObjects", @"addObjectsFromArray:",
        @"unionSet:", @"minusSet:", @"intersectSet:", @"copy"
    ]).forClass(NSMutableSet.class);
    
    self.append.methods(@[@"nextObject", @"allObjects"]).forClass(NSEnumerator.class);
    
    self.append.properties(@[@"flex_observers"]).forClass(NSNotificationCenter.class);
}

@end

#pragma mark - WebKit / Safari

@implementation FLEXShortcutsFactory (WebKit_Safari)

+ (void)load { FLEX_EXIT_IF_NO_CTORS()
    Class WKWebView = NSClassFromString(@"WKWebView");
    Class SafariVC = NSClassFromString(@"SFSafariViewController");
    
    if (WKWebView) {
        self.append.properties(@[
            @"configuration", @"scrollView", @"title", @"URL",
            @"customUserAgent", @"navigationDelegate"
        ]).methods(@[@"reload", @"stopLoading"]).forClass(WKWebView);
    }
    
    if (SafariVC) {
        self.append.properties(@[
            @"delegate"
        ]).forClass(SafariVC);
        if (@available(iOS 10.0, *)) {
            self.append.properties(@[
                @"preferredBarTintColor", @"preferredControlTintColor"
            ]).forClass(SafariVC);
        }
        if (@available(iOS 11.0, *)) {
            self.append.properties(@[
                @"configuration", @"dismissButtonStyle"
            ]).forClass(SafariVC);
        }
    }
}

@end

#pragma mark - Pasteboard

@implementation FLEXShortcutsFactory (Pasteboard)

+ (void)load { FLEX_EXIT_IF_NO_CTORS()
    self.append.properties(@[
        @"name", @"numberOfItems", @"items",
        @"string", @"image", @"color", @"URL",
    ]).forClass(UIPasteboard.class);
}

@end

@interface NSNotificationCenter (Observers)
@property (readonly) NSArray<NSString *> *flex_observers;
@end

@implementation NSNotificationCenter (Observers)
- (id)flex_observers {
    NSString *debug = self.debugDescription;
    NSArray<NSString *> *observers = [debug componentsSeparatedByString:@"\n"];
    NSArray<NSArray<NSString *> *> *splitObservers = [observers flex_mapped:^id(NSString *entry, NSUInteger idx) {
        return [entry componentsSeparatedByString:@","];
    }];
    
    NSArray *names = [splitObservers flex_mapped:^id(NSArray<NSString *> *entry, NSUInteger idx) {
        return entry[0];
    }];
    NSArray *objects = [splitObservers flex_mapped:^id(NSArray<NSString *> *entry, NSUInteger idx) {
        if (entry.count < 2) return NSNull.null;
        NSScanner *scanner = [NSScanner scannerWithString:entry[1]];

        unsigned long long objectPointerValue;
        if ([scanner scanHexLongLong:&objectPointerValue]) {
            void *objectPointer = (void *)objectPointerValue;
            if (FLEXPointerIsValidObjcObject(objectPointer))
                return (__bridge id)(void *)objectPointer;
        }
        
        return NSNull.null;
    }];
    
    return [NSArray flex_forEachUpTo:names.count map:^id(NSUInteger i) {
        return @[names[i], objects[i]];
    }];
}
@end

#pragma mark - Firebase Firestore

@implementation FLEXShortcutsFactory (FirebaseFirestore)

+ (void)load { FLEX_EXIT_IF_NO_CTORS()
    Class FIRDocumentSnap = NSClassFromString(@"FIRDocumentSnapshot");
    if (FIRDocumentSnap) {
        FLEXRuntimeUtilityTryAddObjectProperty(2, data, FIRDocumentSnap, NSDictionary, PropertyKey(ReadOnly));        
    }
}

@end
