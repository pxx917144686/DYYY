#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Photos/Photos.h>

@protocol CitySelectorDelegate <NSObject>
- (void)citySelectorDidSelect:(NSString *)provinceCode 
                 provinceName:(NSString *)provinceName 
                     cityCode:(NSString *)cityCode 
                     cityName:(NSString *)cityName 
                 districtCode:(NSString *)districtCode 
                 districtName:(NSString *)districtName;
@end

@interface CityManager : NSObject

@property (nonatomic, strong) NSMutableDictionary *addressCache;

+ (instancetype)sharedInstance;

- (NSString *)getProvinceNameWithCode:(NSString *)provinceCode;
- (NSString *)getCityNameWithCode:(NSString *)cityCode;
- (NSString *)getDistrictNameWithCode:(NSString *)districtCode;
- (NSString *)getStreetNameWithCode:(NSString *)streetCode;
- (NSDictionary *)getDistrictsInCity:(NSString *)parentCode;
- (NSArray *)getStreetsInDistrict:(NSString *)districtCode;
- (NSDictionary<NSString *, NSString *> *)getAllProvinces;
- (NSDictionary<NSString *, NSString *> *)getCitiesInProvince:(NSString *)provinceCode;

- (void)showCitySelectorInViewController:(UIViewController *)viewController 
                                delegate:(id<CitySelectorDelegate>)delegate
                    initialSelectedCode:(NSString *)initialCode;

- (NSString *)searchLocationByCode:(NSString *)code;
- (NSString *)searchCodeByName:(NSString *)name inType:(int)type;

- (NSString *)getFullAddressWithProvince:(NSString *)provinceCode 
                                    city:(NSString *)cityCode 
                                district:(NSString *)districtCode 
                                  street:(NSString *)streetCode;

- (NSString *)generateRandomFourLevelAddressForCityCode:(NSString *)cityCode 
                                          showProvince:(BOOL)showProvince
                                              showCity:(BOOL)showCity
                                           showDistrict:(BOOL)showDistrict
                                           showLocation:(BOOL)showLocation;
- (NSDictionary *)provinceInfoForCityCode:(NSString *)cityCode;
- (NSDictionary *)cityInfoForCityCode:(NSString *)cityCode inProvince:(NSDictionary *)provinceInfo;
- (NSDictionary *)districtInfoForCityCode:(NSString *)cityCode inCity:(NSDictionary *)cityInfo;

- (void)getLocationFromPHAsset:(PHAsset *)asset completion:(void (^)(NSString *location))completion;

- (NSArray *)getAllCityCodes;

@end