//
//  FLEXKeychain.h
//
//  Derived from:
//  SSKeychain.h in SSKeychain
//  Created by Sam Soffes on 5/19/10.
//  Copyright (c) 2010-2014 Sam Soffes. All rights reserved.
//
// 遇到问题联系中文翻译作者：pxx917144686

#import <Foundation/Foundation.h>

/// FLEXKeychain特有的错误代码，可在NSError对象中返回。
/// 对于操作系统返回的代码，请参阅您平台上的SecBase.h。
typedef NS_ENUM(OSStatus, FLEXKeychainErrorCode) {
    /// 部分参数无效。
    FLEXKeychainErrorBadArguments = -1001,
};

/// FLEXKeychain错误域
extern NSString *const kFLEXKeychainErrorDomain;

/// 账户名称。
extern NSString *const kFLEXKeychainAccountKey;

/// 项目创建时间。
///
/// 值将是一个字符串。
extern NSString *const kFLEXKeychainCreatedAtKey;

/// 项目类别。
extern NSString *const kFLEXKeychainClassKey;

/// 项目描述。
extern NSString *const kFLEXKeychainDescriptionKey;

/// 项目分组。
extern NSString *const kFLEXKeychainGroupKey;

/// 项目标签。
extern NSString *const kFLEXKeychainLabelKey;

/// 项目最后修改时间。
///
/// 值将是一个字符串。
extern NSString *const kFLEXKeychainLastModifiedKey;

/// 项目创建地点。
extern NSString *const kFLEXKeychainWhereKey;

/// 一个简单的封装，用于使用系统钥匙串访问账户、
/// 获取密码、设置密码和删除密码。
@interface FLEXKeychain : NSObject

#pragma mark - 经典方法

/// @param serviceName 要返回对应密码的服务名称。
/// @param account 要返回对应密码的账户。
/// @return 返回包含给定账户和服务密码的字符串，
/// 如果钥匙串中没有给定参数的密码，则返回`nil`。
+ (NSString *)passwordForService:(NSString *)serviceName account:(NSString *)account;
+ (NSString *)passwordForService:(NSString *)serviceName account:(NSString *)account error:(NSError **)error;

/// 返回包含给定账户和服务密码的nsdata，
/// 如果钥匙串中没有给定参数的密码，则返回`nil`。
///
/// @param serviceName 要返回对应密码的服务名称。
/// @param account 要返回对应密码的账户。
/// @return 返回包含给定账户和服务密码的nsdata，
/// 如果钥匙串中没有给定参数的密码，则返回`nil`。
+ (NSData *)passwordDataForService:(NSString *)serviceName account:(NSString *)account;
+ (NSData *)passwordDataForService:(NSString *)serviceName account:(NSString *)account error:(NSError **)error;


/// 从钥匙串中删除密码。
///
/// @param serviceName 要删除对应密码的服务名称。
/// @param account 要删除对应密码的账户。
/// @return 成功返回`YES`，失败返回`NO`。
+ (BOOL)deletePasswordForService:(NSString *)serviceName account:(NSString *)account;
+ (BOOL)deletePasswordForService:(NSString *)serviceName account:(NSString *)account error:(NSError **)error;


/// 在钥匙串中设置密码。
///
/// @param password 要存储在钥匙串中的密码。
/// @param serviceName 要设置对应密码的服务名称。
/// @param account 要设置对应密码的账户。
/// @return 成功返回`YES`，失败返回`NO`。
+ (BOOL)setPassword:(NSString *)password forService:(NSString *)serviceName account:(NSString *)account;
+ (BOOL)setPassword:(NSString *)password forService:(NSString *)serviceName account:(NSString *)account error:(NSError **)error;

/// 在钥匙串中设置密码。
///
/// @param password 要存储在钥匙串中的密码。
/// @param serviceName 要设置对应密码的服务名称。
/// @param account 要设置对应密码的账户。
/// @return 成功返回`YES`，失败返回`NO`。
+ (BOOL)setPasswordData:(NSData *)password forService:(NSString *)serviceName account:(NSString *)account;
+ (BOOL)setPasswordData:(NSData *)password forService:(NSString *)serviceName account:(NSString *)account error:(NSError **)error;

/// @return 包含钥匙串账户的字典数组，如果钥匙串没有任何账户则返回`nil`。
/// 数组中对象的顺序未定义。
///
/// @note 有关可用于访问此方法返回的字典的键的列表，
/// 请参见FLEXKeychain.h中声明的`NSString`常量。
+ (NSArray<NSDictionary<NSString *, id> *> *)allAccounts;
+ (NSArray<NSDictionary<NSString *, id> *> *)allAccounts:(NSError *__autoreleasing *)error;

/// @param serviceName 要返回对应账户的服务名称。
/// @return 包含给定`serviceName`的钥匙串账户的字典数组，
/// 如果钥匙串没有给定`serviceName`的账户则返回`nil`。
/// 数组中对象的顺序未定义。
///
/// @note 有关可用于访问此方法返回的字典的键的列表，
/// 请参见FLEXKeychain.h中声明的`NSString`常量。
+ (NSArray<NSDictionary<NSString *, id> *> *)accountsForService:(NSString *)serviceName;
+ (NSArray<NSDictionary<NSString *, id> *> *)accountsForService:(NSString *)serviceName error:(NSError *__autoreleasing *)error;


#pragma mark - 配置

#if __IPHONE_4_0 && TARGET_OS_IPHONE
/// 返回所有未来保存到钥匙串的密码的可访问性类型。
///
/// @return `NULL`或"钥匙串项目可访问性常量"之一，
/// 用于确定何时应该可以读取钥匙串项目。
+ (CFTypeRef)accessibilityType;

/// 设置所有未来保存到钥匙串的密码的可访问性类型。
///
/// @param accessibilityType "钥匙串项目可访问性常量"之一，
/// 用于确定何时应该可以读取钥匙串项目。
/// 如果值为`NULL`（默认值），将使用钥匙串默认值，
/// 这是高度不安全的。您真的应该至少使用`kSecAttrAccessibleAfterFirstUnlock`
/// 对于后台应用程序，或者对于所有其他应用程序使用`kSecAttrAccessibleWhenUnlocked`。
///
/// @note 参见Security/SecItem.h
+ (void)setAccessibilityType:(CFTypeRef)accessibilityType;
#endif

@end

