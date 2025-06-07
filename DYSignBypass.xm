#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <dlfcn.h>
#import <sys/sysctl.h>
#import <objc/runtime.h>

@interface AWELoginViewController : UIViewController
- (void)loginSuccess:(id)arg1;
- (void)loginFailed:(id)arg1;
@end

@class NSURLSession, AWEDelegateProxy, TMHookManager;
@class AWEUserDefaultsService, BDPRuntimeGlobalConfiguration;
@class NSMutableURLRequest, UIAlertController;

// 手动定义需要的常量
#ifndef PT_DENY_ATTACH
#define PT_DENY_ATTACH 31
#endif

// 日志
#define DYLog(fmt, ...) NSLog(@"[DYSignBypass] " fmt, ##__VA_ARGS__)
#define DYDebug(fmt, ...) NSLog(@"[DYSignBypass-DEBUG] " fmt, ##__VA_ARGS__)

// 全局变量
static BOOL g_bypassApplied = NO;
static BOOL g_loginBypassActive = NO;
static NSMutableDictionary *g_securityHeaders = nil;
static NSMutableDictionary *g_responseCache = nil;

// sysctl拦截 - 保持不变
%hookf(int, sysctl, int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    DYLog(@"拦截sysctl调用");
    
    // 拦截所有系统信息查询，确保安全
    if (name && namelen > 0) {
        if (namelen >= 4 && name[0] == CTL_KERN && name[1] == KERN_PROC) {
            DYLog(@"伪装sysctl内核进程查询");
            return 0;
        }
        
        // 拦截其他可能的系统检测
        if (name[0] == CTL_HW || name[0] == CTL_KERN) {
            if (oldp != NULL && oldlenp != NULL) {
                // 填充一些安全的默认值
                memset(oldp, 0, *oldlenp);
            }
        }
    }
    
    return %orig;
}

// ptrace拦截
%hookf(int, ptrace, int request, pid_t pid, caddr_t addr, int data) {
    DYLog(@"拦截ptrace调用: request=%d", request);
    
    // 禁用所有ptrace调用，不仅是PT_DENY_ATTACH
    // 注意：31是PT_DENY_ATTACH的值
    if (request == 31) {
        DYLog(@"阻止PT_DENY_ATTACH");
        return 0;
    }
    
    return %orig;
}

// dlopen拦截
%hookf(void*, dlopen, const char* path, int mode) {
    if (path) {
        NSString *pathStr = [NSString stringWithUTF8String:path];
        
        // 扩展检测的敏感库列表
        NSArray *sensitiveLibs = @[
            @"frida", @"substrate", @"cycript", @"substitute",
            @"cynject", @"libfridacore", @"FridaGadget", @"dylib"
        ];
        
        for (NSString *lib in sensitiveLibs) {
            if ([pathStr.lowercaseString containsString:lib.lowercaseString]) {
                DYLog(@"阻止加载敏感库: %@", pathStr);
                return NULL;
            }
        }
    }
    
    return %orig;
}


// 处理AWEDelegateProxy
%hook AWEDelegateProxy

+ (BOOL)redirectDebuggerAttachmentAttempt {
    DYLog(@"绕过反调试检测");
    return NO;
}

- (BOOL)isDebugged {
    DYLog(@"绕过调试检测");
    return NO;
}

- (void)reportDebugStatus:(BOOL)status {
    DYLog(@"拦截调试状态报告");
    %orig(NO);
}

%new
- (BOOL)isDebugged:(id)arg1 {
    DYLog(@"绕过调试检测isDebugged:");
    return NO;
}

%new
- (BOOL)isDeviceJailbroken {
    DYLog(@"绕过越狱检测isDeviceJailbroken");
    return NO;
}

%new
+ (BOOL)isJailbroken {
    DYLog(@"绕过越狱检测isJailbroken");
    return NO;
}

%end

// 处理TMHookManager
%hook TMHookManager

+ (BOOL)isMethodHooked:(Class)cls selector:(SEL)sel isClassMethod:(BOOL)isClassMethod {
    DYLog(@"绕过方法Hook检测");
    return NO;
}

+ (BOOL)isHookByObjcMsgSend {
    DYLog(@"绕过ObjcMsgSend Hook检测");
    return NO;
}

%new
+ (BOOL)isHooked {
    DYLog(@"绕过其他Hook检测: isHooked");
    return NO;
}

%end

// 处理BDPRuntimeGlobalConfiguration
%hook BDPRuntimeGlobalConfiguration

- (BOOL)verifyEnvironment {
    DYLog(@"绕过环境验证");
    return YES;
}

%end

// 监控并修改网络请求头
%hook NSMutableURLRequest

- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    // 初始化安全头字典
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        g_securityHeaders = [NSMutableDictionary dictionary];
    });
    
    // 存储所有安全相关的头
    if ([field.lowercaseString containsString:@"x-"] || 
        [field.lowercaseString containsString:@"security"] || 
        [field.lowercaseString containsString:@"argus"]) {
        DYLog(@"捕获请求头: %@ = %@", field, value);
        g_securityHeaders[field] = value;
    }
    
    %orig;
}

// 拦截URL请求构建过程
- (id)initWithURL:(NSURL *)URL {
    id request = %orig;
    NSString *urlString = URL.absoluteString;
    
    // 对敏感URL进行记录
    if ([urlString containsString:@"login"] || 
        [urlString containsString:@"auth"] || 
        [urlString containsString:@"security"] || 
        [urlString containsString:@"verify"]) {
        DYLog(@"监控URL请求: %@", urlString);
    }
    
    return request;
}

%end

// 处理登录网络请求
%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request 
                            completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler 
{
    // 初始化响应缓存字典
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        g_responseCache = [NSMutableDictionary dictionary];
    });
    
    // 获取URL字符串
    NSString *urlString = request.URL.absoluteString;
    
    // 扩展处理的URL关键词
    BOOL isSecurityRequest = [urlString containsString:@"login"] || 
                            [urlString containsString:@"auth"] || 
                            [urlString containsString:@"security"] || 
                            [urlString containsString:@"verify"] || 
                            [urlString containsString:@"device"] || 
                            [urlString containsString:@"check"];
    
    if (!isSecurityRequest) {
        return %orig;
    }
    
    DYLog(@"拦截安全请求: %@", urlString);
    
    // 创建增强的completionHandler
    void (^enhancedHandler)(NSData *, NSURLResponse *, NSError *) = ^(NSData *data, NSURLResponse *response, NSError *error) {
        // 检查是否出错
        if (error) {
            DYLog(@"安全请求错误: %@, 域: %@", error.localizedDescription, error.domain);
            
            // 检测安全相关错误
            if ([error.domain containsString:@"Security"] || 
                [error.localizedDescription containsString:@"安全"] ||
                [error.localizedDescription containsString:@"环境"] ||
                [error.localizedDescription containsString:@"验证"] ||
                error.code == 403) {
                
                DYLog(@"修复安全错误响应");
                
                // 创建成功的伪造响应
                NSDictionary *fakeResponse = @{
                    @"status_code": @0,
                    @"message": @"success",
                    @"data": @{
                        @"user_status": @1,
                        @"security_status": @"normal",
                        @"device_status": @"verified",
                        @"login_status": @"success"
                    }
                };
                
                NSData *fakeData = [NSJSONSerialization dataWithJSONObject:fakeResponse options:0 error:nil];
                NSHTTPURLResponse *fakeHTTPResponse = [[NSHTTPURLResponse alloc] 
                    initWithURL:request.URL statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:nil];
                
                // 缓存成功的伪造响应
                g_responseCache[urlString] = fakeData;
                
                // 返回成功响应
                completionHandler(fakeData, fakeHTTPResponse, nil);
                return;
            }
        }
        
        // 处理响应数据
        if (data) {
            // 尝试读取响应内容
            NSString *responseStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            
            // 检查缓存中是否已有成功响应
            if (g_responseCache[urlString]) {
                DYLog(@"使用缓存响应: %@", urlString);
                completionHandler(g_responseCache[urlString], response, nil);
                return;
            }
            
            // 检查是否包含安全验证失败标识
            BOOL needModify = [responseStr containsString:@"security_check"] || 
                             [responseStr containsString:@"unsafe_device"] || 
                             [responseStr containsString:@"environment"] || 
                             [responseStr containsString:@"verification"] ||
                             [responseStr containsString:@"login_status"] ||
                             [responseStr containsString:@"error_code"];
            
            if (needModify) {
                DYLog(@"修改安全验证响应: %@", urlString);
                
                // 尝试解析为JSON
                NSError *jsonError = nil;
                id jsonObject = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&jsonError];
                
                if (jsonObject && !jsonError) {
                    // 字典类型响应处理
                    if ([jsonObject isKindOfClass:[NSDictionary class]]) {
                        NSMutableDictionary *respDict = (NSMutableDictionary *)jsonObject;
                        
                        // 统一设置成功状态
                        [respDict setObject:@0 forKey:@"status_code"];
                        [respDict setObject:@"success" forKey:@"message"];
                        
                        // 移除错误码
                        [respDict removeObjectForKey:@"error_code"];
                        
                        // 处理data字段
                        if (respDict[@"data"] && [respDict[@"data"] isKindOfClass:[NSDictionary class]]) {
                            NSMutableDictionary *dataDict = [respDict[@"data"] mutableCopy];
                            
                            // 设置各种安全状态为正常
                            [dataDict setObject:@"normal" forKey:@"security_status"];
                            [dataDict setObject:@1 forKey:@"user_status"];
                            [dataDict setObject:@"verified" forKey:@"device_status"];
                            [dataDict setObject:@"success" forKey:@"login_status"];
                            
                            // 移除错误标识
                            [dataDict removeObjectForKey:@"security_check_failed"];
                            [dataDict removeObjectForKey:@"unsafe_device"];
                            [dataDict removeObjectForKey:@"environment_error"];
                            
                            respDict[@"data"] = dataDict;
                        }
                        
                        // 重新生成JSON数据
                        NSData *modifiedData = [NSJSONSerialization dataWithJSONObject:respDict options:0 error:nil];
                        if (modifiedData) {
                            // 缓存修改后的响应
                            g_responseCache[urlString] = modifiedData;
                            completionHandler(modifiedData, response, nil);
                            return;
                        }
                    }
                }
            }
        }
        
        // 如果无需或无法修改，使用原始数据
        completionHandler(data, response, error);
    };
    
    // 使用增强的Handler拦截响应
    return %orig(request, enhancedHandler);
}

%end

// 处理登录状态
%hook AWEUserDefaultsService

- (void)setBool:(BOOL)value forKey:(NSString *)defaultName {
    // 拦截安全相关的状态设置
    if ([defaultName containsString:@"Security"] || 
        [defaultName containsString:@"Login"] ||
        [defaultName containsString:@"Device"] ||
        [defaultName containsString:@"Check"] ||
        [defaultName containsString:@"Verify"]) {
        
        DYLog(@"拦截用户设置: %@ = %d", defaultName, value);
        
        if ([defaultName containsString:@"Failed"] || 
            [defaultName containsString:@"Blocked"] ||
            [defaultName containsString:@"Error"]) {
            DYLog(@"阻止设置负面状态");
            value = NO; // 阻止设置失败状态
        } else {
            value = YES; // 设置成功状态
        }
    }
    %orig(value, defaultName);
}

- (BOOL)boolForKey:(NSString *)defaultName {
    // 强制安全验证通过
    if ([defaultName containsString:@"Security"] ||
        [defaultName containsString:@"Verify"] ||
        [defaultName containsString:@"Check"]) {
        BOOL origValue = %orig;
        DYLog(@"读取安全状态: %@ = %d, 修改为 YES", defaultName, origValue);
        return YES;
    }
    
    // 强制阻止失败状态
    if ([defaultName containsString:@"Failed"] || 
        [defaultName containsString:@"Blocked"] ||
        [defaultName containsString:@"Error"]) {
        BOOL origValue = %orig;
        DYLog(@"读取错误状态: %@ = %d, 修改为 NO", defaultName, origValue);
        return NO;
    }
    
    return %orig;
}

%end

// 处理登录界面
%hook AWELoginViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    DYLog(@"登录界面出现，执行强化绕过");
    
    if (!g_loginBypassActive) {
        g_loginBypassActive = YES;
        
        // 立即执行绕过，不等待延迟
        dispatch_async(dispatch_get_main_queue(), ^{
            DYLog(@"立即执行登录安全绕过");
            
            // 清除安全状态
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            NSArray *keysToRemove = @[
                @"SecurityCheckFailed", @"DeviceBlocked", @"LoginFailed",
                @"SecurityVerificationRequired", @"DeviceVerificationFailed"
            ];
            
            for (NSString *key in keysToRemove) {
                [defaults removeObjectForKey:key];
            }
            
            // 设置安全状态为通过
            [defaults setBool:YES forKey:@"SecurityCheckPassed"];
            [defaults setBool:YES forKey:@"DeviceVerified"];
            [defaults synchronize];
            
            // 尝试多种方法设置安全状态
            Class securityClass = NSClassFromString(@"AWESecurityManager");
            if (securityClass && [securityClass respondsToSelector:@selector(sharedInstance)]) {
                id instance = [securityClass performSelector:@selector(sharedInstance)];
                
                // 遍历所有可能的安全状态设置方法
                SEL selectors[] = {
                    @selector(setSecurityStatus:),
                    @selector(setVerificationStatus:),
                    @selector(setDeviceStatus:),
                    @selector(setLoginStatus:),
                    @selector(resetSecurityCheck),
                    @selector(bypassSecurityCheck)
                };
                
                for (int i = 0; i < sizeof(selectors)/sizeof(SEL); i++) {
                    SEL sel = selectors[i];
                    if ([instance respondsToSelector:sel]) {
                        DYLog(@"调用安全方法: %@", NSStringFromSelector(sel));
                        [instance performSelector:sel withObject:@1];
                    }
                }
                
                DYLog(@"安全状态设置完成");
            }
        });
        
        // 延迟后再次尝试
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            // 尝试强制调用登录成功方法
            SEL loginSuccessSelector = @selector(loginSuccess:);
            if ([self respondsToSelector:loginSuccessSelector]) {
                DYLog(@"直接调用登录成功方法");
                [self performSelector:loginSuccessSelector withObject:nil];
            }
        });
    }
}

// 尝试拦截登录失败
- (void)loginFailed:(id)arg1 {
    DYLog(@"拦截登录失败，转为成功");
    [self loginSuccess:arg1];
}

%end

// 拦截安全错误弹窗
%hook UIAlertController

+ (id)alertControllerWithTitle:(NSString *)title message:(NSString *)message preferredStyle:(UIAlertControllerStyle)preferredStyle {
    // 扩大拦截范围
    NSArray *blockKeywords = @[@"立即升级", @"应用版本过低", @"security", @"verify", @"fail", @"error"];
    
    BOOL shouldBlock = NO;
    
    // 检查标题
    if (title) {
        for (NSString *keyword in blockKeywords) {
            if ([title containsString:keyword]) {
                shouldBlock = YES;
                break;
            }
        }
    }
    
    // 检查消息
    if (!shouldBlock && message) {
        for (NSString *keyword in blockKeywords) {
            if ([message containsString:keyword]) {
                shouldBlock = YES;
                break;
            }
        }
    }
    
    if (shouldBlock) {
        DYLog(@"拦截错误弹窗: %@ - %@", title, message);
        return nil;
    }
    
    return %orig;
}

%end

%ctor {
    @autoreleasepool {
        DYLog(@"抖音登录拦截绕过 - 初始化增强版");
        
        // 立即执行一些绕过逻辑
        dispatch_async(dispatch_get_main_queue(), ^{
            // 预处理安全状态
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            [defaults setBool:YES forKey:@"SecurityCheckPassed"];
            [defaults setBool:YES forKey:@"DeviceVerified"];
            [defaults synchronize];
            
            DYLog(@"初始化安全状态完成");
            g_bypassApplied = YES;
        });
        
        // 延迟执行其他操作
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            DYLog(@"延迟加载额外绕过逻辑");
            
            // 额外操作
            Class appDelegate = NSClassFromString(@"AppDelegate");
            if (appDelegate) {
                id delegate = [UIApplication sharedApplication].delegate;
                if ([delegate isKindOfClass:appDelegate]) {
                    DYLog(@"应用已完全初始化");
                }
            }
        });
    }
}