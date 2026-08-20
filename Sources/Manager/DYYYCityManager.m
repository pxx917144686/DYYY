#import "DYYYCityManagerPrivate.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <Photos/Photos.h>
#import <objc/runtime.h>
#import <objc/message.h>

@implementation DYYYCityManager

+ (instancetype)sharedInstance {
    static DYYYCityManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _provincesDict = @{};
        _citiesDict = @{};
        _allDistrictsDict = @{};
        _allStreetsDict = @{};
        _addressCache = [NSMutableDictionary dictionary];
        [self loadGeoData];
    }
    return self;
}

@end
