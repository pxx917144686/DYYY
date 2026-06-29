#import "UCSimulatorTool.h"
#import <objc/runtime.h>

static NSString * const kUCSystemVersionKey = @"UCToolsSimulator.systemVersion";
static NSString * const kUCAppVersionKey = @"UCToolsSimulator.appVersion";
static NSString * const kUCDeviceModeKey = @"UCToolsSimulator.deviceMode";
static NSString * const kUCFreshIdentifierForVendorKey = @"UCToolsClean.freshIdentifierForVendor";

static IMP UCOriginalSystemVersion;
static IMP UCOriginalDeviceModel;
static IMP UCOriginalLocalizedModel;
static IMP UCOriginalDeviceName;
static IMP UCOriginalUserInterfaceIdiom;
static IMP UCOriginalIdentifierForVendor;
static IMP UCOriginalOperatingSystemVersion;
static IMP UCOriginalOperatingSystemVersionString;
static IMP UCOriginalIsOperatingSystemAtLeastVersion;
static IMP UCOriginalBundleInfoDictionary;
static IMP UCOriginalBundleLocalizedInfoDictionary;
static IMP UCOriginalBundleObjectForInfoKey;
static NSMutableDictionary<NSString *, NSValue *> *UCOriginalDeviceBooleanMethods;

static NSString *UCStringSetting(NSString *key) {
    id value = [NSUserDefaults.standardUserDefaults objectForKey:key];
    return [value isKindOfClass:NSString.class] && [value length] ? value : nil;
}

static NSInteger UCDeviceMode(void) {
    id value = [NSUserDefaults.standardUserDefaults objectForKey:kUCDeviceModeKey];
    return [value respondsToSelector:@selector(integerValue)] ? [value integerValue] : -1;
}

static NSUUID *UCHookedIdentifierForVendor(id self, SEL _cmd) {
    NSString *uuidString = UCStringSetting(kUCFreshIdentifierForVendorKey);
    if (uuidString.length) {
        NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:uuidString];
        if (uuid) return uuid;
    }
    return ((id (*)(id, SEL))UCOriginalIdentifierForVendor)(self, _cmd);
}

static NSString *UCHookedSystemVersion(id self, SEL _cmd) {
    return UCStringSetting(kUCSystemVersionKey) ?: ((id (*)(id, SEL))UCOriginalSystemVersion)(self, _cmd);
}

static NSString *UCHookedDeviceModel(id self, SEL _cmd) {
    NSInteger mode = UCDeviceMode();
    if (mode == 1) return @"iPad";
    if (mode == 0) return @"iPhone";
    return ((id (*)(id, SEL))UCOriginalDeviceModel)(self, _cmd);
}

static NSString *UCHookedLocalizedModel(id self, SEL _cmd) {
    NSInteger mode = UCDeviceMode();
    if (mode == 1) return @"iPad";
    if (mode == 0) return @"iPhone";
    return ((id (*)(id, SEL))UCOriginalLocalizedModel)(self, _cmd);
}

static NSString *UCHookedDeviceName(id self, SEL _cmd) {
    NSInteger mode = UCDeviceMode();
    if (mode == 1) return @"iPad";
    if (mode == 0) return @"iPhone";
    return ((id (*)(id, SEL))UCOriginalDeviceName)(self, _cmd);
}

static UIUserInterfaceIdiom UCHookedUserInterfaceIdiom(id self, SEL _cmd) {
    NSInteger mode = UCDeviceMode();
    if (mode == 1) return UIUserInterfaceIdiomPad;
    if (mode == 0) return UIUserInterfaceIdiomPhone;
    return ((UIUserInterfaceIdiom (*)(id, SEL))UCOriginalUserInterfaceIdiom)(self, _cmd);
}

static NSOperatingSystemVersion UCParsedOperatingSystemVersion(NSString *version) {
    NSArray<NSString *> *parts = [version componentsSeparatedByString:@"."];
    NSOperatingSystemVersion result = {0, 0, 0};
    if (parts.count > 0) result.majorVersion = parts[0].integerValue;
    if (parts.count > 1) result.minorVersion = parts[1].integerValue;
    if (parts.count > 2) result.patchVersion = parts[2].integerValue;
    return result;
}

static NSOperatingSystemVersion UCHookedOperatingSystemVersion(id self, SEL _cmd) {
    NSString *version = UCStringSetting(kUCSystemVersionKey);
    return version.length ? UCParsedOperatingSystemVersion(version) : ((NSOperatingSystemVersion (*)(id, SEL))UCOriginalOperatingSystemVersion)(self, _cmd);
}

static NSString *UCHookedOperatingSystemVersionString(id self, SEL _cmd) {
    NSString *version = UCStringSetting(kUCSystemVersionKey);
    return version.length ? [NSString stringWithFormat:@"Version %@ (Build simulated)", version] : ((id (*)(id, SEL))UCOriginalOperatingSystemVersionString)(self, _cmd);
}

static BOOL UCHookedIsOperatingSystemAtLeastVersion(id self, SEL _cmd, NSOperatingSystemVersion required) {
    NSString *version = UCStringSetting(kUCSystemVersionKey);
    if (!version.length) {
        return ((BOOL (*)(id, SEL, NSOperatingSystemVersion))UCOriginalIsOperatingSystemAtLeastVersion)(self, _cmd, required);
    }

    NSOperatingSystemVersion current = UCParsedOperatingSystemVersion(version);
    if (current.majorVersion != required.majorVersion) return current.majorVersion > required.majorVersion;
    if (current.minorVersion != required.minorVersion) return current.minorVersion > required.minorVersion;
    return current.patchVersion >= required.patchVersion;
}

static NSDictionary *UCInfoDictionaryWithVersion(NSDictionary *source) {
    NSString *version = UCStringSetting(kUCAppVersionKey);
    if (!version.length) return source;
    NSMutableDictionary *result = [source mutableCopy] ?: [NSMutableDictionary dictionary];
    result[@"CFBundleShortVersionString"] = version;
    result[@"CFBundleVersion"] = version;
    return result.copy;
}

static NSDictionary *UCHookedBundleInfoDictionary(NSBundle *self, SEL _cmd) {
    NSDictionary *source = ((id (*)(id, SEL))UCOriginalBundleInfoDictionary)(self, _cmd);
    return self == NSBundle.mainBundle ? UCInfoDictionaryWithVersion(source) : source;
}

static NSDictionary *UCHookedBundleLocalizedInfoDictionary(NSBundle *self, SEL _cmd) {
    NSDictionary *source = ((id (*)(id, SEL))UCOriginalBundleLocalizedInfoDictionary)(self, _cmd);
    return self == NSBundle.mainBundle ? UCInfoDictionaryWithVersion(source) : source;
}

static id UCHookedBundleObjectForInfoKey(NSBundle *self, SEL _cmd, NSString *key) {
    if (self == NSBundle.mainBundle && ([key isEqualToString:@"CFBundleShortVersionString"] || [key isEqualToString:@"CFBundleVersion"])) {
        NSString *version = UCStringSetting(kUCAppVersionKey);
        if (version.length) return version;
    }
    return ((id (*)(id, SEL, id))UCOriginalBundleObjectForInfoKey)(self, _cmd, key);
}

static BOOL UCHookedDeviceBoolean(id self, SEL _cmd) {
    NSInteger mode = UCDeviceMode();
    if (mode >= 0) {
        NSString *selector = NSStringFromSelector(_cmd).lowercaseString;
        BOOL asksForPad = [selector containsString:@"ipad"] || [selector containsString:@"ispad"];
        BOOL asksForPhone = [selector containsString:@"iphone"] || [selector containsString:@"isphone"] || [selector containsString:@"smallphone"];
        if (asksForPad) return mode == 1;
        if (asksForPhone) return mode == 0;
    }

    IMP original = [UCOriginalDeviceBooleanMethods[NSStringFromSelector(_cmd)] pointerValue];
    return original ? ((BOOL (*)(id, SEL))original)(self, _cmd) : NO;
}

static void UCSwizzleInstanceMethod(Class cls, SEL selector, IMP replacement, IMP *original) {
    Method method = class_getInstanceMethod(cls, selector);
    if (!method) return;
    *original = method_getImplementation(method);
    method_setImplementation(method, replacement);
}

static void UCSwizzleDeviceBooleanSelector(NSString *name, BOOL classMethod) {
    Class cls = UIDevice.class;
    SEL selector = NSSelectorFromString(name);
    Method method = classMethod ? class_getClassMethod(cls, selector) : class_getInstanceMethod(cls, selector);
    if (!method) return;
    IMP original = method_getImplementation(method);
    if (!UCOriginalDeviceBooleanMethods) UCOriginalDeviceBooleanMethods = [NSMutableDictionary dictionary];
    UCOriginalDeviceBooleanMethods[name] = [NSValue valueWithPointer:original];
    method_setImplementation(method, (IMP)UCHookedDeviceBoolean);
}

@implementation UCSimulatorTool

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        UCSwizzleInstanceMethod(UIDevice.class, @selector(systemVersion), (IMP)UCHookedSystemVersion, &UCOriginalSystemVersion);
        UCSwizzleInstanceMethod(UIDevice.class, @selector(model), (IMP)UCHookedDeviceModel, &UCOriginalDeviceModel);
        UCSwizzleInstanceMethod(UIDevice.class, @selector(localizedModel), (IMP)UCHookedLocalizedModel, &UCOriginalLocalizedModel);
        UCSwizzleInstanceMethod(UIDevice.class, @selector(name), (IMP)UCHookedDeviceName, &UCOriginalDeviceName);
        UCSwizzleInstanceMethod(UIDevice.class, @selector(userInterfaceIdiom), (IMP)UCHookedUserInterfaceIdiom, &UCOriginalUserInterfaceIdiom);
        UCSwizzleInstanceMethod(UIDevice.class, @selector(identifierForVendor), (IMP)UCHookedIdentifierForVendor, &UCOriginalIdentifierForVendor);
        UCSwizzleInstanceMethod(NSProcessInfo.class, @selector(operatingSystemVersion), (IMP)UCHookedOperatingSystemVersion, &UCOriginalOperatingSystemVersion);
        UCSwizzleInstanceMethod(NSProcessInfo.class, @selector(operatingSystemVersionString), (IMP)UCHookedOperatingSystemVersionString, &UCOriginalOperatingSystemVersionString);
        UCSwizzleInstanceMethod(NSProcessInfo.class, @selector(isOperatingSystemAtLeastVersion:), (IMP)UCHookedIsOperatingSystemAtLeastVersion, &UCOriginalIsOperatingSystemAtLeastVersion);
        UCSwizzleInstanceMethod(NSBundle.class, @selector(infoDictionary), (IMP)UCHookedBundleInfoDictionary, &UCOriginalBundleInfoDictionary);
        UCSwizzleInstanceMethod(NSBundle.class, @selector(localizedInfoDictionary), (IMP)UCHookedBundleLocalizedInfoDictionary, &UCOriginalBundleLocalizedInfoDictionary);
        UCSwizzleInstanceMethod(NSBundle.class, @selector(objectForInfoDictionaryKey:), (IMP)UCHookedBundleObjectForInfoKey, &UCOriginalBundleObjectForInfoKey);

        for (NSString *name in @[@"sf_isiPad", @"sf_isiPhone"]) {
            UCSwizzleDeviceBooleanSelector(name, NO);
        }
        for (NSString *name in @[@"bd_isIpad", @"bd_isIphone", @"vk_isiPad", @"vk_isiPhone", @"vk_isLargeiPad", @"mf_isPad", @"mf_isSmallPhone"]) {
            UCSwizzleDeviceBooleanSelector(name, YES);
        }
    });
}

+ (void)presentFromViewController:(UIViewController *)viewController {
    if (!viewController) return;

    NSString *systemVersion = UCStringSetting(kUCSystemVersionKey) ?: UIDevice.currentDevice.systemVersion;
    NSString *appVersion = UCStringSetting(kUCAppVersionKey) ?: [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"1.0";
    NSInteger deviceMode = UCDeviceMode();
    NSString *modeText = deviceMode == 1 ? @"iPad" : (deviceMode == 0 ? @"iPhone" : @"真实设备");
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"设备模拟器"
                                                                   message:[NSString stringWithFormat:@"当前设备模式：%@\n保存后立即对常用系统接口生效。", modeText]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"系统版本，例如 18.5";
        field.text = systemVersion;
        field.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"软件版本，例如 3.2.1";
        field.text = appVersion;
        field.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
    }];

    void (^save)(NSInteger) = ^(NSInteger mode) {
        NSString *newSystemVersion = [alert.textFields[0].text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        NSString *newAppVersion = [alert.textFields[1].text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (newSystemVersion.length) [NSUserDefaults.standardUserDefaults setObject:newSystemVersion forKey:kUCSystemVersionKey];
        if (newAppVersion.length) [NSUserDefaults.standardUserDefaults setObject:newAppVersion forKey:kUCAppVersionKey];
        [NSUserDefaults.standardUserDefaults setInteger:mode forKey:kUCDeviceModeKey];
        [NSUserDefaults.standardUserDefaults synchronize];
    };

    [alert addAction:[UIAlertAction actionWithTitle:@"保存为 iPhone" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        save(0);
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"保存为 iPad" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        save(1);
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"恢复真实信息" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        [NSUserDefaults.standardUserDefaults removeObjectForKey:kUCSystemVersionKey];
        [NSUserDefaults.standardUserDefaults removeObjectForKey:kUCAppVersionKey];
        [NSUserDefaults.standardUserDefaults removeObjectForKey:kUCDeviceModeKey];
        [NSUserDefaults.standardUserDefaults synchronize];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [viewController presentViewController:alert animated:YES completion:nil];
}

@end
