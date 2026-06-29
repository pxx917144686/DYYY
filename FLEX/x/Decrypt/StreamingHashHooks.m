#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonCrypto.h>
#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonHMAC.h>
#import <Security/Security.h>
#import <dlfcn.h>
#import "fishhook.h"
#import "DatabaseManager.h"

#define LOG(fmt, ...) NSLog(@"[StreamingHash] " fmt, ##__VA_ARGS__)

extern NSString *CurrentBundleID(void);
extern NSString *HexStringFromBytes(const void *bytes, size_t length);
extern void IZXAddDecryptionKeyCandidate(NSData *keyData, NSData *ivData, NSString *source);

extern int CCDigest(uint32_t algorithm, const void *data, size_t dataLength, void *output);

#pragma mark - 工具函数

static NSString *Base64StringFromBytes(const void *bytes, size_t length) {
    if (!bytes || length == 0) return @"";
    return [[NSData dataWithBytes:bytes length:length] base64EncodedStringWithOptions:0] ?: @"";
}

static NSString *ReadableStringFromBytes(const void *bytes, size_t length) {
    if (!bytes || length == 0) return @"";
    NSString *text = [[NSString alloc] initWithBytes:bytes length:length encoding:NSUTF8StringEncoding];
    return text ?: @"(非 UTF-8 数据)";
}

static NSString *DigestAlgoName(uint32_t algorithm) {
    switch (algorithm) {
        case 1: return @"MD5";
        case 2: return @"SHA1";
        case 3: return @"SHA224";
        case 4: return @"SHA256";
        case 5: return @"SHA384";
        case 6: return @"SHA512";
        default: return [NSString stringWithFormat:@"Algo:%u", (unsigned int)algorithm];
    }
}

static NSUInteger DigestOutputLen(uint32_t algorithm) {
    switch (algorithm) {
        case 1: return CC_MD5_DIGEST_LENGTH;
        case 2: return CC_SHA1_DIGEST_LENGTH;
        case 3: return CC_SHA224_DIGEST_LENGTH;
        case 4: return CC_SHA256_DIGEST_LENGTH;
        case 5: return CC_SHA384_DIGEST_LENGTH;
        case 6: return CC_SHA512_DIGEST_LENGTH;
        default: return 0;
    }
}

static NSString *HMACAlgoName(CCHmacAlgorithm algorithm) {
    switch (algorithm) {
        case kCCHmacAlgSHA1:   return @"HmacSHA1";
        case kCCHmacAlgMD5:    return @"HmacMD5";
        case kCCHmacAlgSHA256: return @"HmacSHA256";
        case kCCHmacAlgSHA384: return @"HmacSHA384";
        case kCCHmacAlgSHA512: return @"HmacSHA512";
        case kCCHmacAlgSHA224: return @"HmacSHA224";
        default: return [NSString stringWithFormat:@"HmacAlg:%u", (unsigned int)algorithm];
    }
}

static NSUInteger HMACOutputLen(CCHmacAlgorithm algorithm) {
    switch (algorithm) {
        case kCCHmacAlgSHA1:   return CC_SHA1_DIGEST_LENGTH;
        case kCCHmacAlgMD5:    return CC_MD5_DIGEST_LENGTH;
        case kCCHmacAlgSHA256: return CC_SHA256_DIGEST_LENGTH;
        case kCCHmacAlgSHA384: return CC_SHA384_DIGEST_LENGTH;
        case kCCHmacAlgSHA512: return CC_SHA512_DIGEST_LENGTH;
        case kCCHmacAlgSHA224: return CC_SHA224_DIGEST_LENGTH;
        default: return 0;
    }
}

#pragma mark - Hash 上下文追踪

static NSMutableDictionary *HashCtxMap(void) {
    static NSMutableDictionary *map = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ map = [NSMutableDictionary dictionary]; });
    return map;
}

static NSString *PtrKey(const void *ptr) {
    return [NSString stringWithFormat:@"%p", ptr];
}

static void StoreHashCtx(const void *ctx, NSString *algo, NSUInteger digestLen) {
    @synchronized (HashCtxMap()) {
        HashCtxMap()[PtrKey(ctx)] = [@{
            @"algo": algo,
            @"digestLen": @(digestLen),
            @"data": [NSMutableData data]
        } mutableCopy];
    }
}

static void AppendHashCtx(const void *ctx, const void *data, size_t len) {
    @synchronized (HashCtxMap()) {
        NSMutableDictionary *entry = HashCtxMap()[PtrKey(ctx)];
        if (entry) {
            NSMutableData *accum = entry[@"data"];
            if (accum && data && len) [accum appendBytes:data length:len];
        }
    }
}

static void FinalizeHashCtx(const void *ctx, const unsigned char *md) {
    NSMutableDictionary *entry = nil;
    @synchronized (HashCtxMap()) {
        entry = [HashCtxMap()[PtrKey(ctx)] mutableCopy];
        [HashCtxMap() removeObjectForKey:PtrKey(ctx)];
    }
    if (!entry || !md) return;

    NSString *algo = entry[@"algo"];
    NSUInteger digestLen = [entry[@"digestLen"] unsignedIntegerValue];
    NSData *accumulatedData = entry[@"data"];
    NSString *bundleID = CurrentBundleID();
    DatabaseManager *db = [DatabaseManager sharedManager];

    NSString *hashHex = HexStringFromBytes(md, digestLen);
    NSString *hashB64 = Base64StringFromBytes(md, digestLen);

    NSString *info = [NSString stringWithFormat:
                      @"[流式Hash] %@\n输入数据 Hex: %@\n输入数据 Base64: %@\n输入数据 UTF8: %@\n输入长度: %lu\nHash Hex: %@\nHash Base64: %@",
                      algo,
                      HexStringFromBytes(accumulatedData.bytes, accumulatedData.length),
                      Base64StringFromBytes(accumulatedData.bytes, accumulatedData.length),
                      ReadableStringFromBytes(accumulatedData.bytes, accumulatedData.length),
                      (unsigned long)accumulatedData.length,
                      hashHex, hashB64];
    [db insertDataIntoTable:@"zhaiyao" bundleID:bundleID text:info];
    [db insertDataIntoTable:@"jiamisuanfa" bundleID:bundleID text:info];
    LOG(@"%@", info);

    NSData *keyData = [NSData dataWithBytes:md length:digestLen];
    IZXAddDecryptionKeyCandidate(keyData, [NSData data],
                                  [NSString stringWithFormat:@"流式Hash %@ 派生密钥", algo]);
}

#pragma mark - HMAC 上下文追踪

static NSMutableDictionary *HMACCtxMap(void) {
    static NSMutableDictionary *map = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ map = [NSMutableDictionary dictionary]; });
    return map;
}

static void StoreHMACCtx(const void *ctx, CCHmacAlgorithm algorithm, const void *key, size_t keyLen) {
    @synchronized (HMACCtxMap()) {
        HMACCtxMap()[PtrKey(ctx)] = [@{
            @"algo": HMACAlgoName(algorithm),
            @"digestLen": @(HMACOutputLen(algorithm)),
            @"keyHex": HexStringFromBytes(key, keyLen) ?: @"",
            @"keyB64": Base64StringFromBytes(key, keyLen) ?: @"",
            @"keyData": [NSData dataWithBytes:key length:keyLen],
            @"data": [NSMutableData data]
        } mutableCopy];
    }
}

static void AppendHMACCtx(const void *ctx, const void *data, size_t len) {
    @synchronized (HMACCtxMap()) {
        NSMutableDictionary *entry = HMACCtxMap()[PtrKey(ctx)];
        if (entry) {
            NSMutableData *accum = entry[@"data"];
            if (accum && data && len) [accum appendBytes:data length:len];
        }
    }
}

static void FinalizeHMACCtx(const void *ctx, void *macOut) {
    NSMutableDictionary *entry = nil;
    @synchronized (HMACCtxMap()) {
        entry = [HMACCtxMap()[PtrKey(ctx)] mutableCopy];
        [HMACCtxMap() removeObjectForKey:PtrKey(ctx)];
    }
    if (!entry || !macOut) return;

    NSString *algo = entry[@"algo"];
    NSUInteger digestLen = [entry[@"digestLen"] unsignedIntegerValue];
    NSData *accumulatedData = entry[@"data"];
    NSString *keyHex = entry[@"keyHex"];
    NSString *keyB64 = entry[@"keyB64"];
    NSString *bundleID = CurrentBundleID();
    DatabaseManager *db = [DatabaseManager sharedManager];

    NSString *macHex = HexStringFromBytes(macOut, digestLen);
    NSString *macB64 = Base64StringFromBytes(macOut, digestLen);

    NSString *info = [NSString stringWithFormat:
                      @"[流式HMAC] %@\nKey Hex: %@\nKey Base64: %@\n输入数据 Hex: %@\n输入数据 Base64: %@\n输入数据 UTF8: %@\n输入长度: %lu\nMAC Hex: %@\nMAC Base64: %@",
                      algo, keyHex, keyB64,
                      HexStringFromBytes(accumulatedData.bytes, accumulatedData.length),
                      Base64StringFromBytes(accumulatedData.bytes, accumulatedData.length),
                      ReadableStringFromBytes(accumulatedData.bytes, accumulatedData.length),
                      (unsigned long)accumulatedData.length,
                      macHex, macB64];
    [db insertDataIntoTable:@"hanmiyao" bundleID:bundleID text:info];
    [db insertDataIntoTable:@"jiamisuanfa" bundleID:bundleID text:info];
    LOG(@"%@", info);

    NSData *keyData = [NSData dataWithBytes:macOut length:digestLen];
    IZXAddDecryptionKeyCandidate(keyData, [NSData data],
                                  [NSString stringWithFormat:@"流式HMAC %@ 派生密钥", algo]);
}

#pragma mark - 原始函数指针

static int (*orig_CC_MD5_Init)(CC_MD5_CTX *c);
static int (*orig_CC_MD5_Update)(CC_MD5_CTX *c, const void *data, CC_LONG len);
static int (*orig_CC_MD5_Final)(unsigned char *md, CC_MD5_CTX *c);

static int (*orig_CC_SHA1_Init)(CC_SHA1_CTX *c);
static int (*orig_CC_SHA1_Update)(CC_SHA1_CTX *c, const void *data, CC_LONG len);
static int (*orig_CC_SHA1_Final)(unsigned char *md, CC_SHA1_CTX *c);

static int (*orig_CC_SHA256_Init)(CC_SHA256_CTX *c);
static int (*orig_CC_SHA256_Update)(CC_SHA256_CTX *c, const void *data, CC_LONG len);
static int (*orig_CC_SHA256_Final)(unsigned char *md, CC_SHA256_CTX *c);

static int (*orig_CC_SHA512_Init)(CC_SHA512_CTX *c);
static int (*orig_CC_SHA512_Update)(CC_SHA512_CTX *c, const void *data, CC_LONG len);
static int (*orig_CC_SHA512_Final)(unsigned char *md, CC_SHA512_CTX *c);

static int (*orig_CC_SHA224_Init)(CC_SHA256_CTX *c);
static int (*orig_CC_SHA224_Update)(CC_SHA256_CTX *c, const void *data, CC_LONG len);
static int (*orig_CC_SHA224_Final)(unsigned char *md, CC_SHA256_CTX *c);

static int (*orig_CC_SHA384_Init)(CC_SHA512_CTX *c);
static int (*orig_CC_SHA384_Update)(CC_SHA512_CTX *c, const void *data, CC_LONG len);
static int (*orig_CC_SHA384_Final)(unsigned char *md, CC_SHA512_CTX *c);

static int (*orig_CCDigest)(uint32_t algorithm, const void *data, size_t dataLength, void *output);

static void (*orig_CCHmacInit)(CCHmacContext *ctx, CCHmacAlgorithm algorithm, const void *key, size_t keyLength);
static void (*orig_CCHmacUpdate)(CCHmacContext *ctx, const void *data, size_t dataLength);
static void (*orig_CCHmacFinal)(CCHmacContext *ctx, void *macOut);

#pragma mark - Hook 函数

int my_CC_MD5_Init(CC_MD5_CTX *c) {
    int result = orig_CC_MD5_Init(c);
    StoreHashCtx(c, @"MD5", CC_MD5_DIGEST_LENGTH);
    return result;
}

int my_CC_MD5_Update(CC_MD5_CTX *c, const void *data, CC_LONG len) {
    AppendHashCtx(c, data, len);
    return orig_CC_MD5_Update(c, data, len);
}

int my_CC_MD5_Final(unsigned char *md, CC_MD5_CTX *c) {
    int result = orig_CC_MD5_Final(md, c);
    FinalizeHashCtx(c, md);
    return result;
}

int my_CC_SHA1_Init(CC_SHA1_CTX *c) {
    int result = orig_CC_SHA1_Init(c);
    StoreHashCtx(c, @"SHA1", CC_SHA1_DIGEST_LENGTH);
    return result;
}

int my_CC_SHA1_Update(CC_SHA1_CTX *c, const void *data, CC_LONG len) {
    AppendHashCtx(c, data, len);
    return orig_CC_SHA1_Update(c, data, len);
}

int my_CC_SHA1_Final(unsigned char *md, CC_SHA1_CTX *c) {
    int result = orig_CC_SHA1_Final(md, c);
    FinalizeHashCtx(c, md);
    return result;
}

int my_CC_SHA256_Init(CC_SHA256_CTX *c) {
    int result = orig_CC_SHA256_Init(c);
    StoreHashCtx(c, @"SHA256", CC_SHA256_DIGEST_LENGTH);
    return result;
}

int my_CC_SHA256_Update(CC_SHA256_CTX *c, const void *data, CC_LONG len) {
    AppendHashCtx(c, data, len);
    return orig_CC_SHA256_Update(c, data, len);
}

int my_CC_SHA256_Final(unsigned char *md, CC_SHA256_CTX *c) {
    int result = orig_CC_SHA256_Final(md, c);
    FinalizeHashCtx(c, md);
    return result;
}

int my_CC_SHA512_Init(CC_SHA512_CTX *c) {
    int result = orig_CC_SHA512_Init(c);
    StoreHashCtx(c, @"SHA512", CC_SHA512_DIGEST_LENGTH);
    return result;
}

int my_CC_SHA512_Update(CC_SHA512_CTX *c, const void *data, CC_LONG len) {
    AppendHashCtx(c, data, len);
    return orig_CC_SHA512_Update(c, data, len);
}

int my_CC_SHA512_Final(unsigned char *md, CC_SHA512_CTX *c) {
    int result = orig_CC_SHA512_Final(md, c);
    FinalizeHashCtx(c, md);
    return result;
}

int my_CC_SHA224_Init(CC_SHA256_CTX *c) {
    int result = orig_CC_SHA224_Init(c);
    StoreHashCtx(c, @"SHA224", CC_SHA224_DIGEST_LENGTH);
    return result;
}

int my_CC_SHA224_Update(CC_SHA256_CTX *c, const void *data, CC_LONG len) {
    AppendHashCtx(c, data, len);
    return orig_CC_SHA224_Update(c, data, len);
}

int my_CC_SHA224_Final(unsigned char *md, CC_SHA256_CTX *c) {
    int result = orig_CC_SHA224_Final(md, c);
    FinalizeHashCtx(c, md);
    return result;
}

int my_CC_SHA384_Init(CC_SHA512_CTX *c) {
    int result = orig_CC_SHA384_Init(c);
    StoreHashCtx(c, @"SHA384", CC_SHA384_DIGEST_LENGTH);
    return result;
}

int my_CC_SHA384_Update(CC_SHA512_CTX *c, const void *data, CC_LONG len) {
    AppendHashCtx(c, data, len);
    return orig_CC_SHA384_Update(c, data, len);
}

int my_CC_SHA384_Final(unsigned char *md, CC_SHA512_CTX *c) {
    int result = orig_CC_SHA384_Final(md, c);
    FinalizeHashCtx(c, md);
    return result;
}

int my_CCDigest(uint32_t algorithm, const void *data, size_t dataLength, void *output) {
    int result = orig_CCDigest(algorithm, data, dataLength, output);
    NSString *algoName = DigestAlgoName(algorithm);
    NSUInteger digestLen = DigestOutputLen(algorithm);
    if (digestLen == 0) return result;

    NSString *bundleID = CurrentBundleID();
    DatabaseManager *db = [DatabaseManager sharedManager];
    NSString *hashHex = HexStringFromBytes(output, digestLen);
    NSString *hashB64 = Base64StringFromBytes(output, digestLen);

    NSString *info = [NSString stringWithFormat:
                      @"[CCDigest] %@\n输入数据 Hex: %@\n输入数据 Base64: %@\n输入数据 UTF8: %@\n输入长度: %lu\nHash Hex: %@\nHash Base64: %@",
                      algoName,
                      HexStringFromBytes(data, dataLength),
                      Base64StringFromBytes(data, dataLength),
                      ReadableStringFromBytes(data, dataLength),
                      (unsigned long)dataLength,
                      hashHex, hashB64];
    [db insertDataIntoTable:@"zhaiyao" bundleID:bundleID text:info];
    [db insertDataIntoTable:@"jiamisuanfa" bundleID:bundleID text:info];
    LOG(@"%@", info);

    NSData *keyData = [NSData dataWithBytes:output length:digestLen];
    IZXAddDecryptionKeyCandidate(keyData, [NSData data],
                                  [NSString stringWithFormat:@"CCDigest %@ 派生密钥", algoName]);
    return result;
}

void my_CCHmacInit(CCHmacContext *ctx, CCHmacAlgorithm algorithm, const void *key, size_t keyLength) {
    StoreHMACCtx(ctx, algorithm, key, keyLength);
    orig_CCHmacInit(ctx, algorithm, key, keyLength);
}

void my_CCHmacUpdate(CCHmacContext *ctx, const void *data, size_t dataLength) {
    AppendHMACCtx(ctx, data, dataLength);
    orig_CCHmacUpdate(ctx, data, dataLength);
}

void my_CCHmacFinal(CCHmacContext *ctx, void *macOut) {
    orig_CCHmacFinal(ctx, macOut);
    FinalizeHMACCtx(ctx, macOut);
}

#pragma mark - 注册 Hook

void RegisterStreamingHashHooks(void) {
    struct rebinding rebindings[] = {

        {"CC_MD5_Init",    my_CC_MD5_Init,    (void **)&orig_CC_MD5_Init},
        {"CC_MD5_Update",  my_CC_MD5_Update,  (void **)&orig_CC_MD5_Update},
        {"CC_MD5_Final",   my_CC_MD5_Final,   (void **)&orig_CC_MD5_Final},

        {"CC_SHA1_Init",   my_CC_SHA1_Init,   (void **)&orig_CC_SHA1_Init},
        {"CC_SHA1_Update", my_CC_SHA1_Update, (void **)&orig_CC_SHA1_Update},
        {"CC_SHA1_Final",  my_CC_SHA1_Final,  (void **)&orig_CC_SHA1_Final},

        {"CC_SHA256_Init",   my_CC_SHA256_Init,   (void **)&orig_CC_SHA256_Init},
        {"CC_SHA256_Update", my_CC_SHA256_Update, (void **)&orig_CC_SHA256_Update},
        {"CC_SHA256_Final",  my_CC_SHA256_Final,  (void **)&orig_CC_SHA256_Final},

        {"CC_SHA512_Init",   my_CC_SHA512_Init,   (void **)&orig_CC_SHA512_Init},
        {"CC_SHA512_Update", my_CC_SHA512_Update, (void **)&orig_CC_SHA512_Update},
        {"CC_SHA512_Final",  my_CC_SHA512_Final,  (void **)&orig_CC_SHA512_Final},

        {"CC_SHA224_Init",   my_CC_SHA224_Init,   (void **)&orig_CC_SHA224_Init},
        {"CC_SHA224_Update", my_CC_SHA224_Update, (void **)&orig_CC_SHA224_Update},
        {"CC_SHA224_Final",  my_CC_SHA224_Final,  (void **)&orig_CC_SHA224_Final},

        {"CC_SHA384_Init",   my_CC_SHA384_Init,   (void **)&orig_CC_SHA384_Init},
        {"CC_SHA384_Update", my_CC_SHA384_Update, (void **)&orig_CC_SHA384_Update},
        {"CC_SHA384_Final",  my_CC_SHA384_Final,  (void **)&orig_CC_SHA384_Final},

        {"CCDigest", my_CCDigest, (void **)&orig_CCDigest},

        {"CCHmacInit",   my_CCHmacInit,   (void **)&orig_CCHmacInit},
        {"CCHmacUpdate", my_CCHmacUpdate, (void **)&orig_CCHmacUpdate},
        {"CCHmacFinal",  my_CCHmacFinal,  (void **)&orig_CCHmacFinal},
    };

    int result = rebind_symbols(rebindings, sizeof(rebindings) / sizeof(rebindings[0]));
    LOG(@"Streaming hash hooks registered: %d (%zu hooks)", result, sizeof(rebindings) / sizeof(rebindings[0]));
}
