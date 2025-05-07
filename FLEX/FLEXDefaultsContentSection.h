// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXDefaultsContentSection.h
//  FLEX
//
//  创建者：Tanner Bennett，日期：8/28/19.
//  版权所有 © 2020 FLEX Team。保留所有权利。
//

#import "FLEXCollectionContentSection.h"
#import "FLEXObjectInfoSection.h"

@interface FLEXDefaultsContentSection : FLEXCollectionContentSection <FLEXObjectInfoSection>

/// 使用 \c NSUserDefaults.standardUserDefaults
+ (instancetype)standard;
+ (instancetype)forDefaults:(NSUserDefaults *)userDefaults;

/// 是否过滤掉应用用户默认设置文件中不存在的键。
///
/// 这对于过滤掉一些似乎出现在每个应用的默认设置中，
/// 但实际上从未被应用使用或接触过的无用键很有用。
/// 仅适用于使用 \c NSUserDefaults.standardUserDefaults 的实例。
/// 这是任何使用 \c standardUserDefaults 的实例的默认行为，因此
/// 如果您不希望出现此行为，则必须在这些实例中选择退出。
@property (nonatomic) BOOL onlyShowKeysForAppPrefs;

@end
