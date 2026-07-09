#import "DYYYUCAppGroupHelper.h"
#import <dlfcn.h>

static NSArray<NSString *> *UCProvisioningAppGroupIdentifiers(void) {
    NSString *profilePath = [NSBundle.mainBundle pathForResource:@"embedded" ofType:@"mobileprovision"];
    NSData *profile = profilePath.length ? [NSData dataWithContentsOfFile:profilePath] : nil;
    if (!profile.length) return @[];

    NSString *text = [[NSString alloc] initWithData:profile encoding:NSISOLatin1StringEncoding];
    NSRange start = [text rangeOfString:@"<?xml"];
    NSRange end = [text rangeOfString:@"</plist>" options:NSBackwardsSearch];
    if (start.location == NSNotFound || end.location == NSNotFound || end.location < start.location) return @[];

    NSUInteger length = NSMaxRange(end) - start.location;
    NSData *plistData = [[text substringWithRange:NSMakeRange(start.location, length)] dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *profilePlist = [NSPropertyListSerialization propertyListWithData:plistData options:0 format:nil error:nil];
    if (![profilePlist isKindOfClass:NSDictionary.class]) return @[];
    NSDictionary *entitlements = profilePlist[@"Entitlements"];
    if (![entitlements isKindOfClass:NSDictionary.class]) return @[];
    id value = entitlements[@"com.apple.security.application-groups"];
    return [value isKindOfClass:NSArray.class] ? value : @[];
}

static NSArray<NSString *> *UCEntitledAppGroupIdentifiers(void) {
    NSMutableOrderedSet<NSString *> *identifiers = [NSMutableOrderedSet orderedSet];

    typedef CFTypeRef (*SecTaskCreateFromSelfFunction)(CFAllocatorRef allocator);
    typedef CFTypeRef (*SecTaskCopyValueFunction)(CFTypeRef task, CFStringRef entitlement, CFErrorRef *error);
    SecTaskCreateFromSelfFunction createTask = (SecTaskCreateFromSelfFunction)dlsym(RTLD_DEFAULT, "SecTaskCreateFromSelf");
    SecTaskCopyValueFunction copyValue = (SecTaskCopyValueFunction)dlsym(RTLD_DEFAULT, "SecTaskCopyValueForEntitlement");
    if (createTask && copyValue) {
        CFTypeRef task = createTask(kCFAllocatorDefault);
        if (task) {
            CFTypeRef value = copyValue(task, CFSTR("com.apple.security.application-groups"), NULL);
            if (value && CFGetTypeID(value) == CFArrayGetTypeID()) {
                for (id identifier in (__bridge NSArray *)value) {
                    if ([identifier isKindOfClass:NSString.class] && [identifier length]) {
                        [identifiers addObject:identifier];
                    }
                }
            }
            if (value) CFRelease(value);
            CFRelease(task);
        }
    }

    id infoValue = [NSBundle.mainBundle objectForInfoDictionaryKey:@"com.apple.security.application-groups"];
    if ([infoValue isKindOfClass:NSArray.class]) {
        for (id identifier in infoValue) {
            if ([identifier isKindOfClass:NSString.class] && [identifier length]) {
                [identifiers addObject:identifier];
            }
        }
    }

    for (NSString *identifier in UCProvisioningAppGroupIdentifiers()) {
        if ([identifier isKindOfClass:NSString.class] && identifier.length) {
            [identifiers addObject:identifier];
        }
    }

    return identifiers.array;
}

@implementation DYYYUCAppGroupHelper

+ (NSArray<NSDictionary<NSString *,NSString *> *> *)accessibleAppGroups {
    NSMutableArray<NSDictionary<NSString *, NSString *> *> *groups = [NSMutableArray array];
    NSMutableSet<NSString *> *seenPaths = [NSMutableSet set];
    NSFileManager *manager = NSFileManager.defaultManager;

    for (NSString *identifier in UCEntitledAppGroupIdentifiers()) {
        NSURL *url = [manager containerURLForSecurityApplicationGroupIdentifier:identifier];
        NSString *path = url.path.stringByStandardizingPath;
        if (!path.length || [seenPaths containsObject:path]) continue;
        BOOL isDirectory = NO;
        if (![manager fileExistsAtPath:path isDirectory:&isDirectory] || !isDirectory) continue;
        [seenPaths addObject:path];
        [groups addObject:@{@"identifier": identifier, @"path": path}];
    }

    return groups.copy;
}

+ (NSArray<NSString *> *)accessibleAppGroupPaths {
    NSMutableArray<NSString *> *paths = [NSMutableArray array];
    for (NSDictionary<NSString *, NSString *> *group in self.accessibleAppGroups) {
        NSString *path = group[@"path"];
        if (path.length) [paths addObject:path];
    }
    return paths.copy;
}

@end
