#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <CFNetwork/CFNetwork.h>
#import <objc/runtime.h>
#import "fishhook.h"
#import "DatabaseManager.h"

#define LOG(fmt, ...) NSLog(@"[SSLHook] " fmt, ##__VA_ARGS__)

extern NSString *CurrentBundleID(void);
extern NSString *HexStringFromBytes(const void *bytes, size_t length);

static CFDictionaryRef (*orig_CFNetworkCopySystemProxySettings)(void);

CFDictionaryRef hooked_CFNetworkCopySystemProxySettings(void) {
    if (!orig_CFNetworkCopySystemProxySettings) return NULL;
    CFDictionaryRef original = orig_CFNetworkCopySystemProxySettings();
    NSString *bundleID = CurrentBundleID();
    DatabaseManager *db = [DatabaseManager sharedManager];

    if ([db getSwitch:@"proxy_bypass" bundleID:bundleID defaultValue:NO]) {

        if (original) {
            NSDictionary *proxyDict = (__bridge NSDictionary *)original;
            NSString *proxyInfo = [NSString stringWithFormat:@"Proxy Settings: %@", proxyDict];
            [db insertDataIntoTable:@"proxy_settings" bundleID:bundleID text:proxyInfo];
            LOG(@"%@", proxyInfo);
        }

        NSMutableDictionary *modified = [NSMutableDictionary dictionary];
        if (original) {
            NSDictionary *origDict = (__bridge NSDictionary *)original;
            for (id key in origDict) {
                if ([key isEqualToString:@"HTTPEnable"] ||
                    [key isEqualToString:@"HTTPSEnable"] ||
                    [key isEqualToString:@"SOCKSEnable"]) {
                    modified[key] = @(NO);
                } else if ([key isEqualToString:@"HTTPProxy"] ||
                          [key isEqualToString:@"HTTPSProxy"] ||
                          [key isEqualToString:@"SOCKSProxy"]) {
                    modified[key] = origDict[key];
                } else {
                    modified[key] = origDict[key];
                }
            }
        }

        CFDictionaryRef result = CFBridgingRetain(modified);
        if (original) CFRelease(original);
        LOG(@"Proxy detection bypassed");
        return result;
    }

    return original;
}

void ssl2_kill(void) {
    LOG(@"SSL2 kill activated");
    [[DatabaseManager sharedManager] insertLogText:@"SSL2 kill activated"];
}

void ssl3_kill(void) {
    LOG(@"SSL3 kill activated");
    [[DatabaseManager sharedManager] insertLogText:@"SSL3 kill activated"];
}

static const char* (*orig_SSL_get_psk_identity)(void *ssl);
const char* replaced_SSL_get_psk_identity(void *ssl) {
    if (!orig_SSL_get_psk_identity) return NULL;
    const char* identity = orig_SSL_get_psk_identity(ssl);
    if (identity) {
        NSString *bundleID = CurrentBundleID();
        NSString *pskInfo = [NSString stringWithFormat:@"PSK Identity: %s", identity];
        [[DatabaseManager sharedManager] insertDataIntoTable:@"ssl_psk" bundleID:bundleID text:pskInfo];
        LOG(@"%@", pskInfo);
    }
    return identity;
}

void RegisterSSLHooks(void) {

    struct rebinding proxy_rebindings[] = {
        {"CFNetworkCopySystemProxySettings", hooked_CFNetworkCopySystemProxySettings, (void **)&orig_CFNetworkCopySystemProxySettings},
    };
    rebind_symbols(proxy_rebindings, sizeof(proxy_rebindings) / sizeof(proxy_rebindings[0]));

    struct rebinding psk_rebindings[] = {
        {"SSL_get_psk_identity", replaced_SSL_get_psk_identity, (void **)&orig_SSL_get_psk_identity},
    };
    rebind_symbols(psk_rebindings, sizeof(psk_rebindings) / sizeof(psk_rebindings[0]));

    LOG(@"SSL hooks registered");
}
