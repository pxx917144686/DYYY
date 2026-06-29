#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonCrypto.h>
#if __has_include(<CommonCrypto/CommonCryptorSPI.h>)
#import <CommonCrypto/CommonCryptorSPI.h>
#else
typedef uint32_t CCMode;
typedef uint32_t CCPadding;
typedef uint32_t CCModeOptions;
#ifndef kCCModeECB
#define kCCModeECB 1
#define kCCModeCBC 2
#define kCCModeCFB 3
#define kCCModeCTR 4
#define kCCModeF8 5
#define kCCModeLRW 6
#define kCCModeOFB 7
#define kCCModeXTS 8
#define kCCModeRC4 9
#define kCCModeCFB8 10
#define kCCModeGCM 11
#endif
#ifndef ccNoPadding
#define ccNoPadding 0
#define ccPKCS7Padding 1
#endif
#endif
#import <Security/Security.h>
#import <dlfcn.h>
#import "fishhook.h"
#import "DatabaseManager.h"

#define LOG(fmt, ...) NSLog(@"[CryptoCapture] " fmt, ##__VA_ARGS__)

extern NSString *CurrentBundleID(void);
extern NSString *HexStringFromBytes(const void *bytes, size_t length);
extern NSString * const IZXURLResponseCapturedNotification;
extern NSString * const IZXURLResponseCapturedTextKey;

static NSString *ReadableStringFromBytes(const void *bytes, size_t length) {
    if (!bytes || length == 0) return @"";
    NSString *text = [[NSString alloc] initWithBytes:bytes
                                             length:length
                                           encoding:NSUTF8StringEncoding];
    return text ?: @"(非 UTF-8 数据)";
}

static NSString *Base64StringFromBytes(const void *bytes, size_t length) {
    if (!bytes || length == 0) return @"";
    NSData *data = [NSData dataWithBytes:bytes length:length];
    return [data base64EncodedStringWithOptions:0] ?: @"";
}

static NSString *EncodingNameForBytes(const void *bytes, size_t length) {
    if (!bytes || length == 0) return @"empty";
    NSString *text = [[NSString alloc] initWithBytes:bytes length:length encoding:NSUTF8StringEncoding];
    return text ? @"UTF8" : @"raw-bytes";
}

static size_t HMACLength(CCHmacAlgorithm algorithm) {
    switch (algorithm) {
        case kCCHmacAlgSHA1:   return CC_SHA1_DIGEST_LENGTH;
        case kCCHmacAlgMD5:    return CC_MD5_DIGEST_LENGTH;
        case kCCHmacAlgSHA256: return CC_SHA256_DIGEST_LENGTH;
        case kCCHmacAlgSHA384: return CC_SHA384_DIGEST_LENGTH;
        case kCCHmacAlgSHA512: return CC_SHA512_DIGEST_LENGTH;
        case kCCHmacAlgSHA224: return CC_SHA224_DIGEST_LENGTH;
    }
    return 0;
}

static size_t IVLength(CCAlgorithm algorithm) {
    switch (algorithm) {
        case kCCAlgorithmAES:      return kCCBlockSizeAES128;
        case kCCAlgorithmDES:      return kCCBlockSizeDES;
        case kCCAlgorithm3DES:     return kCCBlockSize3DES;
        case kCCAlgorithmCAST:     return kCCBlockSizeCAST;
        case kCCAlgorithmRC2:      return kCCBlockSizeRC2;
        case kCCAlgorithmBlowfish: return kCCBlockSizeBlowfish;
        default:                   return 0;
    }
}

static NSString *AlgorithmName(CCAlgorithm algorithm) {
    switch (algorithm) {
        case kCCAlgorithmAES:      return @"AES";
        case kCCAlgorithmDES:      return @"DES";
        case kCCAlgorithm3DES:     return @"3DES";
        case kCCAlgorithmCAST:     return @"CAST";
        case kCCAlgorithmRC4:      return @"RC4";
        case kCCAlgorithmRC2:      return @"RC2";
        case kCCAlgorithmBlowfish: return @"Blowfish";
        default: return [NSString stringWithFormat:@"Alg:%u", (unsigned int)algorithm];
    }
}

static NSString *OperationName(CCOperation op) {
    return (op == kCCEncrypt) ? @"Encrypt" : (op == kCCDecrypt ? @"Decrypt" : [NSString stringWithFormat:@"Op:%u", (unsigned int)op]);
}

static NSString *ModeNameFromOptions(CCOptions options) {
    return (options & kCCOptionECBMode) ? @"ECB" : @"CBC";
}

static NSString *PaddingNameFromOptions(CCOptions options) {
    return (options & kCCOptionPKCS7Padding) ? @"PKCS7Padding" : @"NoPadding";
}

static NSString *ModeName(CCMode mode) {
    switch ((uint32_t)mode) {
        case kCCModeECB:  return @"ECB";
        case kCCModeCBC:  return @"CBC";
        case kCCModeCFB:  return @"CFB";
        case kCCModeCTR:  return @"CTR";
        case kCCModeOFB:  return @"OFB";
        case kCCModeXTS:  return @"XTS";
        case kCCModeRC4:  return @"RC4";
        case kCCModeCFB8: return @"CFB8";
        case kCCModeGCM:  return @"GCM";
        default: return [NSString stringWithFormat:@"Mode:%u", (unsigned int)mode];
    }
}

static NSString *PaddingName(CCPadding padding) {
    switch ((uint32_t)padding) {
        case ccNoPadding:    return @"NoPadding";
        case ccPKCS7Padding: return @"PKCS7Padding";
        default: return [NSString stringWithFormat:@"Padding:%u", (unsigned int)padding];
    }
}

static unsigned char* (*orig_CC_MD5)(const void *data, CC_LONG len, unsigned char *md);
static unsigned char* (*orig_CC_SHA1)(const void *data, CC_LONG len, unsigned char *md);
static unsigned char* (*orig_CC_SHA256)(const void *data, CC_LONG len, unsigned char *md);
static unsigned char* (*orig_CC_SHA384)(const void *data, CC_LONG len, unsigned char *md);
static unsigned char* (*orig_CC_SHA512)(const void *data, CC_LONG len, unsigned char *md);
static void (*orig_CCHmac)(CCHmacAlgorithm algorithm, const void *key, size_t keyLen, const void *data, size_t dataLen, void *macOut);
static CCCryptorStatus (*orig_CCCrypt)(CCOperation op, CCAlgorithm alg, CCOptions options, const void *key, size_t keyLen, const void *iv, const void *dataIn, size_t dataInLen, void *dataOut, size_t dataOutAvailable, size_t *dataOutMoved);
static CCCryptorStatus (*orig_CCCryptorCreate)(CCOperation op, CCAlgorithm alg, CCOptions options, const void *key, size_t keyLength, const void *iv, CCCryptorRef *cryptorRef);
static CCCryptorStatus (*orig_CCCryptorUpdate)(CCCryptorRef cryptorRef, const void *dataIn, size_t dataInLength, void *dataOut, size_t dataOutAvailable, size_t *dataOutMoved);
static CCCryptorStatus (*orig_CCCryptorFinal)(CCCryptorRef cryptorRef, void *dataOut, size_t dataOutAvailable, size_t *dataOutMoved);
static CCCryptorStatus (*orig_CCCryptorRelease)(CCCryptorRef cryptorRef);
static CCCryptorStatus (*orig_CCCryptorCreateWithMode)(CCOperation op, CCMode mode, CCAlgorithm alg, CCPadding padding, const void *iv, const void *key, size_t keyLen, const void *tweak, size_t tweakLen, int numRounds, CCModeOptions options, CCCryptorRef *cryptorRef);
static OSStatus (*orig_SecKeyEncrypt)(SecKeyRef key, SecPadding padding, const uint8_t *plainText, size_t plainTextLen, uint8_t *cipherText, size_t *cipherTextLen);
static OSStatus (*orig_SecKeyDecrypt)(SecKeyRef key, SecPadding padding, const uint8_t *cipherText, size_t cipherTextLen, uint8_t *plainText, size_t *plainTextLen);
static OSStatus (*orig_SecKeyRawSign)(SecKeyRef key, SecPadding padding, const uint8_t *dataToSign, size_t dataToSignLen, uint8_t *sig, size_t *sigLen);

static unsigned char* (*orig_CC_SHA224)(const void *data, CC_LONG len, unsigned char *md);

static int (*orig_CCKeyDerivationPBKDF)(uint32_t algorithm, const char *password, size_t passwordLen, const uint8_t *salt, size_t saltLen, uint32_t prf, uint32_t rounds, uint8_t *derivedKey, size_t derivedKeyLen);

static CFDataRef (*orig_SecKeyCreateDecryptedData)(SecKeyRef key, SecKeyAlgorithm algorithm, CFDataRef ciphertext, CFErrorRef *error);
static CFDataRef (*orig_SecKeyCreateEncryptedData)(SecKeyRef key, SecKeyAlgorithm algorithm, CFDataRef plaintext, CFErrorRef *error);
static CFDataRef (*orig_SecKeyCreateSignature)(SecKeyRef key, SecKeyAlgorithm algorithm, CFDataRef dataToSign, CFErrorRef *error);
static Boolean (*orig_SecKeyVerifySignature)(SecKeyRef key, SecKeyAlgorithm algorithm, CFDataRef signedData, CFDataRef signature, CFErrorRef *error);

static CCCryptorStatus (*orig_CCCryptorGCMAddIV)(CCCryptorRef cryptorRef, const void *iv, size_t ivLen);
static CCCryptorStatus (*orig_CCCryptorGCMAddAAD)(CCCryptorRef cryptorRef, const void *aData, size_t aDataLen);
static CCCryptorStatus (*orig_CCCryptorGCMUpdate)(CCCryptorRef cryptorRef, const void *dataIn, size_t dataInLength, void *dataOut);
static CCCryptorStatus (*orig_CCCryptorGCMFinal)(CCCryptorRef cryptorRef, void *dataOut, void *tagOut, size_t *tagLength);

static NSMutableDictionary *CryptoContextMap(void) {
    static NSMutableDictionary *map = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        map = [NSMutableDictionary dictionary];
    });
    return map;
}

static NSMutableArray *RecentCryptoSpecs(void) {
    static NSMutableArray *specs = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        specs = [NSMutableArray array];
    });
    return specs;
}

static NSData *DataFromBytesSafe(const void *bytes, size_t length) {
    if (!bytes || length == 0) return [NSData data];
    return [NSData dataWithBytes:bytes length:length];
}

static void AddRecentCryptoSpec(NSDictionary *spec) {
    if (!spec) return;
    @synchronized (RecentCryptoSpecs()) {
        [RecentCryptoSpecs() insertObject:spec atIndex:0];
        while (RecentCryptoSpecs().count > 64) {
            [RecentCryptoSpecs() removeLastObject];
        }
    }
}

void IZXAddDecryptionKeyCandidate(NSData *keyData, NSData *ivData, NSString *source) {
    if (!keyData.length) return;
    NSDictionary *spec = @{
        @"op": @(kCCDecrypt), @"alg": @(kCCAlgorithmAES),
        @"options": @(kCCOptionPKCS7Padding),
        @"opName": @"Decrypt", @"algName": @"AES",
        @"modeName": @"CBC", @"paddingName": @"PKCS7Padding",
        @"keyHex": HexStringFromBytes(keyData.bytes, keyData.length) ?: @"",
        @"keyB64": Base64StringFromBytes(keyData.bytes, keyData.length) ?: @"",
        @"ivHex": ivData.length ? HexStringFromBytes(ivData.bytes, ivData.length) : @"(null)",
        @"ivB64": ivData.length ? Base64StringFromBytes(ivData.bytes, ivData.length) : @"(null)",
        @"keyData": keyData, @"ivData": ivData ?: [NSData data],
        @"source": source ?: @"unknown"
    };
    AddRecentCryptoSpec(spec);
}

static NSString *HexToCleanString(NSString *text) {
    if (!text.length) return @"";
    NSMutableString *out = [NSMutableString stringWithCapacity:text.length];
    NSCharacterSet *hexSet = [NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdefABCDEF"];
    for (NSUInteger i = 0; i < text.length; i++) {
        unichar c = [text characterAtIndex:i];
        if ([hexSet characterIsMember:c]) [out appendFormat:@"%C", c];
    }
    return out;
}

static NSData *DataFromHexString(NSString *hex) {
    NSString *clean = HexToCleanString(hex);
    if (clean.length < 2 || clean.length % 2 != 0) return nil;
    NSMutableData *data = [NSMutableData dataWithCapacity:clean.length / 2];
    for (NSUInteger i = 0; i < clean.length; i += 2) {
        unsigned int value = 0;
        NSString *byteString = [clean substringWithRange:NSMakeRange(i, 2)];
        NSScanner *scanner = [NSScanner scannerWithString:byteString];
        if (![scanner scanHexInt:&value]) return nil;
        uint8_t b = (uint8_t)value;
        [data appendBytes:&b length:1];
    }
    return data;
}

static NSArray<NSData *> *DecryptInputCandidates(NSData *data) {
    if (!data.length) return @[];
    NSMutableArray<NSData *> *items = [NSMutableArray arrayWithObject:data];
    NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (text.length) {
        NSString *compact = [[text componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] componentsJoinedByString:@""];
        if (compact.length >= 8) {
            NSData *b64 = [[NSData alloc] initWithBase64EncodedString:compact options:NSDataBase64DecodingIgnoreUnknownCharacters];
            if (b64.length && ![items containsObject:b64]) [items addObject:b64];
            NSData *hex = DataFromHexString(compact);
            if (hex.length && ![items containsObject:hex]) [items addObject:hex];
        }
    }
    return items;
}

static NSString *PreviewStringFromData(NSData *data) {
    if (!data.length) return @"";
    NSString *utf8 = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (utf8.length) return utf8;
    return [NSString stringWithFormat:@"(raw-bytes %lu bytes)\nHex: %@", (unsigned long)data.length, HexStringFromBytes(data.bytes, MIN((NSUInteger)data.length, (NSUInteger)65536))];
}

static NSString *KeyForCryptor(CCCryptorRef cryptorRef) {
    return [NSString stringWithFormat:@"%p", cryptorRef];
}

static void SaveCryptorContext(CCCryptorRef cryptorRef, NSDictionary *ctx) {
    if (!cryptorRef || !ctx) return;
    @synchronized (CryptoContextMap()) {
        CryptoContextMap()[KeyForCryptor(cryptorRef)] = ctx;
    }
}

static NSDictionary *GetCryptorContext(CCCryptorRef cryptorRef) {
    if (!cryptorRef) return nil;
    @synchronized (CryptoContextMap()) {
        return CryptoContextMap()[KeyForCryptor(cryptorRef)];
    }
}

static void RemoveCryptorContext(CCCryptorRef cryptorRef) {
    if (!cryptorRef) return;
    @synchronized (CryptoContextMap()) {
        [CryptoContextMap() removeObjectForKey:KeyForCryptor(cryptorRef)];
    }
}

static NSString *SafeString(id obj) {
    return obj ? [obj description] : @"(unknown)";
}

static void StoreCryptoRecord(NSString *info, BOOL isDecrypt) {
    if (info.length == 0) return;
    NSString *bundleID = CurrentBundleID();
    DatabaseManager *db = [DatabaseManager sharedManager];
    [db insertDataIntoTable:@"jiamisuanfa" bundleID:bundleID text:info];
    if (isDecrypt) {
        [db insertDataIntoTable:@"decrypt_data" bundleID:bundleID text:info];
    }
    LOG(@"%@", info);
    dispatch_async(dispatch_get_main_queue(), ^{
        if (IZXURLResponseCapturedNotification && IZXURLResponseCapturedTextKey) {
            [[NSNotificationCenter defaultCenter] postNotificationName:IZXURLResponseCapturedNotification
                                                                object:nil
                                                              userInfo:@{IZXURLResponseCapturedTextKey: info ?: @""}];
        }
    });
}

static NSString *FormatIOBlock(NSString *title,
                               const void *input, size_t inputLength,
                               const void *output, size_t outputLength) {
    NSString *inputText = ReadableStringFromBytes(input, inputLength);
    NSString *outputText = ReadableStringFromBytes(output, outputLength);
    return [NSString stringWithFormat:
            @"%@\n输入编码: %@\nInput UTF8/raw: %@\nInput Hex: %@\nInput Base64: %@\n输出编码: %@\nOutput UTF8/raw: %@\nOutput Hex: %@\nOutput Base64: %@",
            title ?: @"[Crypto IO]",
            EncodingNameForBytes(input, inputLength), inputText,
            HexStringFromBytes(input, inputLength), Base64StringFromBytes(input, inputLength),
            EncodingNameForBytes(output, outputLength), outputText,
            HexStringFromBytes(output, outputLength), Base64StringFromBytes(output, outputLength)];
}

static void CaptureDigest(const void *data, size_t len, const unsigned char *result, int digLen, const char *name) {
    NSString *bundleID = CurrentBundleID();
    DatabaseManager *db = [DatabaseManager sharedManager];

    if (![db isDigestCaptureEnabledForBundle:bundleID]) return;

    NSString *dataHex = HexStringFromBytes(data, len);
    NSString *resultHex = HexStringFromBytes(result, digLen);

    NSString *info = [NSString stringWithFormat:@"[%s] Data(%lu): %@\nHash: %@", name, (unsigned long)len, dataHex, resultHex];
    [db insertDataIntoTable:@"zhaiyao" bundleID:bundleID text:info];
    LOG(@"%@", info);
}

unsigned char* my_CC_MD5(const void *data, CC_LONG len, unsigned char *md) {
    unsigned char* result = orig_CC_MD5(data, len, md);
    CaptureDigest(data, len, result, CC_MD5_DIGEST_LENGTH, "MD5");
    return result;
}

unsigned char* my_CC_SHA1(const void *data, CC_LONG len, unsigned char *md) {
    unsigned char* result = orig_CC_SHA1(data, len, md);
    CaptureDigest(data, len, result, CC_SHA1_DIGEST_LENGTH, "SHA1");
    return result;
}

unsigned char* my_CC_SHA256(const void *data, CC_LONG len, unsigned char *md) {
    unsigned char* result = orig_CC_SHA256(data, len, md);
    CaptureDigest(data, len, result, CC_SHA256_DIGEST_LENGTH, "SHA256");
    return result;
}

unsigned char* my_CC_SHA384(const void *data, CC_LONG len, unsigned char *md) {
    unsigned char* result = orig_CC_SHA384(data, len, md);
    CaptureDigest(data, len, result, CC_SHA384_DIGEST_LENGTH, "SHA384");
    return result;
}

unsigned char* my_CC_SHA512(const void *data, CC_LONG len, unsigned char *md) {
    unsigned char* result = orig_CC_SHA512(data, len, md);
    CaptureDigest(data, len, result, CC_SHA512_DIGEST_LENGTH, "SHA512");
    return result;
}

unsigned char* my_CC_SHA224(const void *data, CC_LONG len, unsigned char *md) {
    unsigned char* result = orig_CC_SHA224(data, len, md);
    CaptureDigest(data, len, result, CC_SHA224_DIGEST_LENGTH, "SHA224");
    return result;
}

void my_CCHmac(CCHmacAlgorithm algorithm, const void *key, size_t keyLen, const void *data, size_t dataLen, void *macOut) {
    NSString *bundleID = CurrentBundleID();
    DatabaseManager *db = [DatabaseManager sharedManager];

    BOOL enabled = [db isHMACCaptureEnabledForBundle:bundleID];
    orig_CCHmac(algorithm, key, keyLen, data, dataLen, macOut);

    if (enabled) {
        NSString *keyHex = HexStringFromBytes(key, keyLen);
        NSString *dataHex = HexStringFromBytes(data, dataLen);
        NSString *macHex = HexStringFromBytes(macOut, HMACLength(algorithm));

        NSString *info = [NSString stringWithFormat:@"[HMAC] Alg: %u\nKey: %@\nData: %@\nMAC: %@",
                          (unsigned int)algorithm, keyHex, dataHex, macHex];
        [db insertDataIntoTable:@"hanmiyao" bundleID:bundleID text:info];
        LOG(@"%@", info);
    }
}

CCCryptorStatus my_CCCrypt(CCOperation op, CCAlgorithm alg, CCOptions options, const void *key, size_t keyLen, const void *iv, const void *dataIn, size_t dataInLen, void *dataOut, size_t dataOutAvailable, size_t *dataOutMoved) {
    NSString *bundleID = CurrentBundleID();
    DatabaseManager *db = [DatabaseManager sharedManager];
    BOOL enabled = [db isCryptoCaptureEnabledForBundle:bundleID];

    CCCryptorStatus status = orig_CCCrypt(op, alg, options, key, keyLen, iv,
                                         dataIn, dataInLen, dataOut,
                                         dataOutAvailable, dataOutMoved);

    if (enabled) {
        NSString *opName = OperationName(op);
        NSString *algName = AlgorithmName(alg);
        NSString *modeName = ModeNameFromOptions(options);
        NSString *paddingName = PaddingNameFromOptions(options);
        NSString *keyHex = HexStringFromBytes(key, keyLen);
        NSString *keyB64 = Base64StringFromBytes(key, keyLen);
        size_t ivLength = IVLength(alg);
        NSString *ivHex = (iv && ivLength) ? HexStringFromBytes(iv, ivLength) : @"(null)";
        NSString *ivB64 = (iv && ivLength) ? Base64StringFromBytes(iv, ivLength) : @"(null)";
        NSString *inputHex = HexStringFromBytes(dataIn, dataInLen);
        NSString *inputB64 = Base64StringFromBytes(dataIn, dataInLen);
        NSString *inputText = ReadableStringFromBytes(dataIn, dataInLen);
        NSString *inputEncoding = EncodingNameForBytes(dataIn, dataInLen);
        size_t outputLength = (status == kCCSuccess && dataOutMoved) ? *dataOutMoved : 0;
        outputLength = MIN(outputLength, dataOutAvailable);
        NSString *outputHex = HexStringFromBytes(dataOut, outputLength);
        NSString *outputB64 = Base64StringFromBytes(dataOut, outputLength);
        NSString *outputText = ReadableStringFromBytes(dataOut, outputLength);
        NSString *outputEncoding = EncodingNameForBytes(dataOut, outputLength);

        NSDictionary *spec = @{
            @"op": @(op), @"alg": @(alg), @"options": @((uint32_t)options),
            @"opName": opName, @"algName": algName, @"modeName": modeName, @"paddingName": paddingName,
            @"keyHex": keyHex ?: @"", @"keyB64": keyB64 ?: @"",
            @"ivHex": ivHex ?: @"(null)", @"ivB64": ivB64 ?: @"(null)",
            @"keyData": DataFromBytesSafe(key, keyLen),
            @"ivData": (iv && ivLength) ? DataFromBytesSafe(iv, ivLength) : [NSData data]
        };
        AddRecentCryptoSpec(spec);

        NSString *info = [NSString stringWithFormat:
                          @"[CCCrypt] %@ %@ Status:%d\n算法: %@\n模式: %@\n填充: %@\nKey Hex: %@\nKey Base64: %@\nIV Hex: %@\nIV Base64: %@\n输入编码: %@\nInput UTF8/raw: %@\nInput Hex: %@\nInput Base64: %@\n输出编码: %@\nOutput UTF8/raw: %@\nOutput Hex: %@\nOutput Base64: %@",
                          opName, algName, status, algName, modeName, paddingName,
                          keyHex, keyB64, ivHex, ivB64, inputEncoding, inputText, inputHex, inputB64,
                          outputEncoding, outputText, outputHex, outputB64];
        [db insertDataIntoTable:@"jiamisuanfa" bundleID:bundleID text:info];
        if (op == kCCDecrypt || op == kCCEncrypt) {
            NSString *plainLabel = (op == kCCDecrypt) ? @"" : @"[加密前明文捕获]\n";
            [db insertDataIntoTable:@"decrypt_data" bundleID:bundleID text:[plainLabel stringByAppendingString:info]];
        }
        LOG(@"%@", info);
    }

    return status;
}

CCCryptorStatus my_CCCryptorCreateWithMode(CCOperation op, CCMode mode, CCAlgorithm alg, CCPadding padding,
                                           const void *iv, const void *key, size_t keyLen,
                                           const void *tweak, size_t tweakLen, int numRounds,
                                           CCModeOptions options, CCCryptorRef *cryptorRef) {
    NSString *bundleID = CurrentBundleID();
    DatabaseManager *db = [DatabaseManager sharedManager];
    BOOL enabled = [db isCryptoCaptureEnabledForBundle:bundleID];

    CCCryptorStatus status = orig_CCCryptorCreateWithMode(op, mode, alg, padding, iv, key, keyLen,
                                                          tweak, tweakLen, numRounds, options, cryptorRef);
    if (status == kCCSuccess && cryptorRef && *cryptorRef) {
        NSData *keyData = DataFromBytesSafe(key, keyLen);
        NSData *ivData = (iv && IVLength(alg)) ? DataFromBytesSafe(iv, IVLength(alg)) : [NSData data];
        NSMutableDictionary *ctx = [@{
            @"op": @(op),
            @"alg": @(alg),
            @"mode": @((uint32_t)mode),
            @"padding": @((uint32_t)padding),
            @"modeOptions": @((uint32_t)options),
            @"opName": OperationName(op),
            @"algName": AlgorithmName(alg),
            @"modeName": ModeName(mode),
            @"paddingName": PaddingName(padding),
            @"keyHex": HexStringFromBytes(key, keyLen) ?: @"",
            @"keyB64": Base64StringFromBytes(key, keyLen) ?: @"",
            @"ivHex": ((iv && IVLength(alg)) ? HexStringFromBytes(iv, IVLength(alg)) : @"(null)"),
            @"ivB64": ((iv && IVLength(alg)) ? Base64StringFromBytes(iv, IVLength(alg)) : @"(null)"),
            @"keyData": keyData,
            @"ivData": ivData,
            @"inputAccum": [NSMutableData data],
            @"outputAccum": [NSMutableData data]
        } mutableCopy];
        SaveCryptorContext(*cryptorRef, ctx);
        AddRecentCryptoSpec(ctx);
    }
    if (enabled) {
        size_t ivLength = IVLength(alg);
        NSString *algName = AlgorithmName(alg);
        NSString *info = [NSString stringWithFormat:
                          @"[CCCryptorCreateWithMode] %@ %@ Status:%d\n算法: %@\n模式: %@\n填充: %@\nKey Hex: %@\nKey Base64: %@\nIV Hex: %@\nIV Base64: %@\nTweak Hex: %@\nTweak Base64: %@\nRounds: %d\nOptions: %u",
                          OperationName(op), algName, status, algName, ModeName(mode), PaddingName(padding),
                          HexStringFromBytes(key, keyLen), Base64StringFromBytes(key, keyLen),
                          (iv && ivLength) ? HexStringFromBytes(iv, ivLength) : @"(null)",
                          (iv && ivLength) ? Base64StringFromBytes(iv, ivLength) : @"(null)",
                          HexStringFromBytes(tweak, tweakLen), Base64StringFromBytes(tweak, tweakLen),
                          numRounds, (unsigned int)options];
        [db insertDataIntoTable:@"jiamisuanfa" bundleID:bundleID text:info];
        [db insertDataIntoTable:@"crypto_keys" bundleID:bundleID text:info];
        LOG(@"%@", info);
    }
    return status;
}

CCCryptorStatus my_CCCryptorCreate(CCOperation op, CCAlgorithm alg, CCOptions options,
                                   const void *key, size_t keyLength, const void *iv,
                                   CCCryptorRef *cryptorRef) {
    NSString *bundleID = CurrentBundleID();
    DatabaseManager *db = [DatabaseManager sharedManager];
    BOOL enabled = [db isCryptoCaptureEnabledForBundle:bundleID];

    CCCryptorStatus status = orig_CCCryptorCreate(op, alg, options, key, keyLength, iv, cryptorRef);
    if (status == kCCSuccess && cryptorRef && *cryptorRef) {
        NSData *keyData = DataFromBytesSafe(key, keyLength);
        NSData *ivData = (iv && IVLength(alg)) ? DataFromBytesSafe(iv, IVLength(alg)) : [NSData data];
        NSMutableDictionary *ctx = [@{
            @"op": @(op),
            @"alg": @(alg),
            @"options": @((uint32_t)options),
            @"opName": OperationName(op),
            @"algName": AlgorithmName(alg),
            @"modeName": ModeNameFromOptions(options),
            @"paddingName": PaddingNameFromOptions(options),
            @"keyHex": HexStringFromBytes(key, keyLength) ?: @"",
            @"keyB64": Base64StringFromBytes(key, keyLength) ?: @"",
            @"ivHex": ((iv && IVLength(alg)) ? HexStringFromBytes(iv, IVLength(alg)) : @"(null)"),
            @"ivB64": ((iv && IVLength(alg)) ? Base64StringFromBytes(iv, IVLength(alg)) : @"(null)"),
            @"keyData": keyData,
            @"ivData": ivData,
            @"inputAccum": [NSMutableData data],
            @"outputAccum": [NSMutableData data]
        } mutableCopy];
        SaveCryptorContext(*cryptorRef, ctx);
        AddRecentCryptoSpec(ctx);
    }

    if (enabled) {
        NSString *info = [NSString stringWithFormat:
                          @"[CCCryptorCreate] %@ %@ Status:%d\n算法: %@\n模式: %@\n填充: %@\nKey Hex: %@\nKey Base64: %@\nIV Hex: %@\nIV Base64: %@",
                          OperationName(op), AlgorithmName(alg), status,
                          AlgorithmName(alg), ModeNameFromOptions(options), PaddingNameFromOptions(options),
                          HexStringFromBytes(key, keyLength), Base64StringFromBytes(key, keyLength),
                          (iv && IVLength(alg)) ? HexStringFromBytes(iv, IVLength(alg)) : @"(null)",
                          (iv && IVLength(alg)) ? Base64StringFromBytes(iv, IVLength(alg)) : @"(null)"];
        [db insertDataIntoTable:@"jiamisuanfa" bundleID:bundleID text:info];
        [db insertDataIntoTable:@"crypto_keys" bundleID:bundleID text:info];
        LOG(@"%@", info);
    }
    return status;
}

CCCryptorStatus my_CCCryptorUpdate(CCCryptorRef cryptorRef,
                                   const void *dataIn, size_t dataInLength,
                                   void *dataOut, size_t dataOutAvailable,
                                   size_t *dataOutMoved) {
    NSString *bundleID = CurrentBundleID();
    DatabaseManager *db = [DatabaseManager sharedManager];
    BOOL enabled = [db isCryptoCaptureEnabledForBundle:bundleID];
    NSDictionary *ctx = GetCryptorContext(cryptorRef);

    CCCryptorStatus status = orig_CCCryptorUpdate(cryptorRef, dataIn, dataInLength, dataOut, dataOutAvailable, dataOutMoved);

    if (enabled) {
        size_t moved = (status == kCCSuccess && dataOutMoved) ? *dataOutMoved : 0;
        moved = MIN(moved, dataOutAvailable);
        BOOL isDecrypt = [ctx[@"op"] unsignedIntValue] == kCCDecrypt;
        if ([ctx isKindOfClass:[NSMutableDictionary class]]) {
            NSMutableData *inputAccum = ((NSMutableDictionary *)ctx)[@"inputAccum"];
            NSMutableData *outputAccum = ((NSMutableDictionary *)ctx)[@"outputAccum"];
            if (dataIn && dataInLength && [inputAccum respondsToSelector:@selector(appendBytes:length:)]) [inputAccum appendBytes:dataIn length:dataInLength];
            if (dataOut && moved && [outputAccum respondsToSelector:@selector(appendBytes:length:)]) [outputAccum appendBytes:dataOut length:moved];
        }
        NSString *header = [NSString stringWithFormat:
                            @"[CCCryptorUpdate] %@ %@ Status:%d\n算法: %@\n模式: %@\n填充: %@\nKey Hex: %@\nKey Base64: %@\nIV Hex: %@\nIV Base64: %@",
                            SafeString(ctx[@"opName"]), SafeString(ctx[@"algName"]), status,
                            SafeString(ctx[@"algName"]), SafeString(ctx[@"modeName"]), SafeString(ctx[@"paddingName"]),
                            SafeString(ctx[@"keyHex"]), SafeString(ctx[@"keyB64"]),
                            SafeString(ctx[@"ivHex"]), SafeString(ctx[@"ivB64"])] ;
        NSString *io = FormatIOBlock(header, dataIn, dataInLength, dataOut, moved);
        StoreCryptoRecord(io, isDecrypt);
        if (!isDecrypt && dataInLength > 0) {
            [[DatabaseManager sharedManager] insertDataIntoTable:@"decrypt_data" bundleID:bundleID text:[@"[加密前明文捕获/CCCryptorUpdate]\n" stringByAppendingString:io]];
        }
    }
    return status;
}

CCCryptorStatus my_CCCryptorFinal(CCCryptorRef cryptorRef,
                                  void *dataOut, size_t dataOutAvailable,
                                  size_t *dataOutMoved) {
    NSString *bundleID = CurrentBundleID();
    DatabaseManager *db = [DatabaseManager sharedManager];
    BOOL enabled = [db isCryptoCaptureEnabledForBundle:bundleID];
    NSDictionary *ctx = GetCryptorContext(cryptorRef);

    CCCryptorStatus status = orig_CCCryptorFinal(cryptorRef, dataOut, dataOutAvailable, dataOutMoved);

    if (enabled) {
        size_t moved = (status == kCCSuccess && dataOutMoved) ? *dataOutMoved : 0;
        moved = MIN(moved, dataOutAvailable);
        BOOL isDecrypt = [ctx[@"op"] unsignedIntValue] == kCCDecrypt;
        NSString *header = [NSString stringWithFormat:
                            @"[CCCryptorFinal] %@ %@ Status:%d\n算法: %@\n模式: %@\n填充: %@\nKey Hex: %@\nKey Base64: %@\nIV Hex: %@\nIV Base64: %@",
                            SafeString(ctx[@"opName"]), SafeString(ctx[@"algName"]), status,
                            SafeString(ctx[@"algName"]), SafeString(ctx[@"modeName"]), SafeString(ctx[@"paddingName"]),
                            SafeString(ctx[@"keyHex"]), SafeString(ctx[@"keyB64"]),
                            SafeString(ctx[@"ivHex"]), SafeString(ctx[@"ivB64"])] ;
        NSString *io = FormatIOBlock(header, NULL, 0, dataOut, moved);
        StoreCryptoRecord(io, isDecrypt);
        if ([ctx isKindOfClass:[NSMutableDictionary class]]) {
            NSMutableData *outputAccum = ((NSMutableDictionary *)ctx)[@"outputAccum"];
            if (dataOut && moved && [outputAccum respondsToSelector:@selector(appendBytes:length:)]) [outputAccum appendBytes:dataOut length:moved];
            NSData *fullInput = ((NSMutableDictionary *)ctx)[@"inputAccum"];
            NSData *fullOutput = ((NSMutableDictionary *)ctx)[@"outputAccum"];
            if (fullOutput.length || fullInput.length) {
                NSString *wholeHeader = [NSString stringWithFormat:
                    @"[CCCryptor 完整%@结果] %@ %@ Status:%d\n算法: %@\n模式: %@\n填充: %@\nKey Hex: %@\nKey Base64: %@\nIV Hex: %@\nIV Base64: %@",
                    isDecrypt ? @"解密" : @"加密", SafeString(ctx[@"opName"]), SafeString(ctx[@"algName"]), status,
                    SafeString(ctx[@"algName"]), SafeString(ctx[@"modeName"]), SafeString(ctx[@"paddingName"]),
                    SafeString(ctx[@"keyHex"]), SafeString(ctx[@"keyB64"]),
                    SafeString(ctx[@"ivHex"]), SafeString(ctx[@"ivB64"])] ;
                NSString *whole = FormatIOBlock(wholeHeader, fullInput.bytes, fullInput.length, fullOutput.bytes, fullOutput.length);
                StoreCryptoRecord(whole, isDecrypt);
                if (!isDecrypt && fullInput.length > 0) {
                    [[DatabaseManager sharedManager] insertDataIntoTable:@"decrypt_data" bundleID:bundleID text:[@"[加密前完整明文捕获]\n" stringByAppendingString:whole]];
                }
            }
        }
    }
    return status;
}

CCCryptorStatus my_CCCryptorRelease(CCCryptorRef cryptorRef) {
    RemoveCryptorContext(cryptorRef);
    return orig_CCCryptorRelease(cryptorRef);
}

static BOOL IZXPlainLooksUseful(NSData *data) {
    if (data.length == 0) return NO;
    NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (text.length == 0) return NO;
    NSUInteger printable = 0;
    for (NSUInteger i = 0; i < text.length; i++) {
        unichar c = [text characterAtIndex:i];
        if ((c >= 0x20 && c <= 0x7e) || c == '\n' || c == '\r' || c == '\t' || c > 0x7f) printable++;
    }
    if (printable * 100 / MAX((NSUInteger)1, text.length) < 80) return NO;
    if ([text rangeOfString:@"{"].location != NSNotFound || [text rangeOfString:@"["].location != NSNotFound) return YES;
    if ([text rangeOfString:@"http" options:NSCaseInsensitiveSearch].location != NSNotFound) return YES;
    if ([text rangeOfString:@"prd_" options:NSCaseInsensitiveSearch].location != NSNotFound) return YES;
    if (text.length >= 4) return YES;
    return NO;
}

static NSArray<NSNumber *> *IZXOptionAttemptsForSpec(NSDictionary *spec) {
    NSMutableArray<NSNumber *> *opts = [NSMutableArray array];
    NSNumber *original = spec[@"options"];
    if (original) [opts addObject:original];
    NSArray *fallback = @[@(kCCOptionPKCS7Padding), @(0), @(kCCOptionPKCS7Padding | kCCOptionECBMode), @(kCCOptionECBMode)];
    for (NSNumber *n in fallback) if (![opts containsObject:n]) [opts addObject:n];
    return opts;
}

static NSString *TryDecryptOnce(NSData *key, NSData *iv, NSData *ciphertext,
                                 CCAlgorithm alg, CCMode mode, CCPadding padding,
                                 NSString *source, NSString *patternDesc) {
    if (!key.length || !ciphertext.length) return nil;
    if (!orig_CCCryptorCreateWithMode && !orig_CCCrypt) return nil;

    NSMutableData *out = [NSMutableData dataWithLength:ciphertext.length + 128];
    size_t moved = 0;
    CCCryptorStatus status = kCCParamError;

    if (orig_CCCryptorCreateWithMode && orig_CCCryptorUpdate && orig_CCCryptorFinal && orig_CCCryptorRelease) {
        CCCryptorRef ref = NULL;
        status = orig_CCCryptorCreateWithMode(kCCDecrypt, mode, alg, padding,
                                               iv.length ? iv.bytes : NULL,
                                               key.bytes, key.length,
                                               NULL, 0, 0, 0, &ref);
        if (status == kCCSuccess && ref) {
            size_t updateMoved = 0, finalMoved = 0;
            status = orig_CCCryptorUpdate(ref, ciphertext.bytes, ciphertext.length,
                                          out.mutableBytes, out.length, &updateMoved);
            if (status == kCCSuccess) {
                status = orig_CCCryptorFinal(ref, ((uint8_t *)out.mutableBytes) + updateMoved,
                                             out.length - updateMoved, &finalMoved);
            }
            moved = updateMoved + finalMoved;
            orig_CCCryptorRelease(ref);
        }
    } else if (orig_CCCrypt) {
        CCOptions options = 0;
        if (mode == kCCModeECB) options |= kCCOptionECBMode;
        if (padding == ccPKCS7Padding) options |= kCCOptionPKCS7Padding;
        status = orig_CCCrypt(kCCDecrypt, alg, options,
                              key.bytes, key.length,
                              (options & kCCOptionECBMode) ? NULL : (iv.length ? iv.bytes : NULL),
                              ciphertext.bytes, ciphertext.length,
                              out.mutableBytes, out.length, &moved);
    }

    if (status == kCCSuccess && moved > 0 && moved <= out.length) {
        out.length = moved;
        if (!IZXPlainLooksUseful(out)) return nil;
        NSString *plain = PreviewStringFromData(out);
        NSString *info = [NSString stringWithFormat:
                          @"[自动解密成功 (%@)]\n来源: %@\n算法: %@\n模式: %@\n填充: %@\nKey Hex: %@\nKey Base64: %@\nIV Hex: %@\nIV Base64: %@\n密文 Hex: %@\n密文 Base64: %@\n密文长度: %lu\n明文长度: %lu\n\n明文 UTF8/raw:\n%@\n\n明文 Hex:\n%@\n\n明文 Base64:\n%@",
                          patternDesc, source ?: @"(unknown)",
                          AlgorithmName(alg), ModeName(mode), PaddingName(padding),
                          HexStringFromBytes(key.bytes, key.length),
                          Base64StringFromBytes(key.bytes, key.length),
                          iv.length ? HexStringFromBytes(iv.bytes, iv.length) : @"(null/zero)",
                          iv.length ? Base64StringFromBytes(iv.bytes, iv.length) : @"(null/zero)",
                          HexStringFromBytes(ciphertext.bytes, ciphertext.length),
                          Base64StringFromBytes(ciphertext.bytes, ciphertext.length),
                          (unsigned long)ciphertext.length, (unsigned long)out.length,
                          plain, HexStringFromBytes(out.bytes, out.length),
                          Base64StringFromBytes(out.bytes, out.length)];
        NSString *bundleID = CurrentBundleID();
        DatabaseManager *db = [DatabaseManager sharedManager];
        [db insertDataIntoTable:@"decrypt_data" bundleID:bundleID text:info];
        [db insertDataIntoTable:@"jiamisuanfa" bundleID:bundleID text:info];
        LOG(@"%@", info);
        return info;
    }
    return nil;
}

NSString *IZXTryAutoDecryptData(NSData *encryptedData, NSString *source) {
    if (!encryptedData.length) return nil;
    if (!orig_CCCrypt && !orig_CCCryptorCreateWithMode) return nil;
    NSArray *specs = nil;
    @synchronized (RecentCryptoSpecs()) {
        specs = [RecentCryptoSpecs() copy];
    }
    if (specs.count == 0) return nil;

    NSArray<NSData *> *candidates = DecryptInputCandidates(encryptedData);
    NSMutableArray<NSString *> *debugLines = [NSMutableArray array];
    NSUInteger specIndex = 0;
    for (NSDictionary *spec in specs) {
        specIndex++;
        NSData *keyData = spec[@"keyData"];
        NSData *ivData = spec[@"ivData"];
        if (keyData.length == 0) continue;
        CCAlgorithm alg = (CCAlgorithm)[spec[@"alg"] unsignedIntValue];

        for (NSData *candidate in candidates) {
            if (candidate.length == 0 || candidate.length > 1024 * 1024) continue;

            NSMutableArray<NSDictionary *> *attempts = [NSMutableArray array];
            if (spec[@"mode"] && orig_CCCryptorCreateWithMode && orig_CCCryptorUpdate && orig_CCCryptorFinal && orig_CCCryptorRelease) {
                [attempts addObject:@{@"kind": @"mode", @"mode": spec[@"mode"], @"padding": spec[@"padding"] ?: @(ccPKCS7Padding), @"modeOptions": spec[@"modeOptions"] ?: @(0), @"modeName": spec[@"modeName"] ?: @"CreateWithMode", @"paddingName": spec[@"paddingName"] ?: @"PKCS7Padding"}];
                NSArray *extraModes = @[@(kCCModeCBC), @(kCCModeECB), @(kCCModeCFB), @(kCCModeCTR), @(kCCModeOFB), @(kCCModeGCM)];
                NSArray *extraPaddings = @[@(ccPKCS7Padding), @(ccNoPadding)];
                for (NSNumber *m in extraModes) {
                    for (NSNumber *pad in extraPaddings) {
                        [attempts addObject:@{@"kind": @"mode", @"mode": m, @"padding": pad, @"modeOptions": @(0), @"modeName": ModeName((CCMode)m.unsignedIntValue), @"paddingName": PaddingName((CCPadding)pad.unsignedIntValue)}];
                    }
                }
            }
            if (orig_CCCrypt) {
                for (NSNumber *opt in IZXOptionAttemptsForSpec(spec)) {
                    [attempts addObject:@{@"kind": @"cccrypt", @"options": opt, @"modeName": ModeNameFromOptions((CCOptions)opt.unsignedIntValue), @"paddingName": PaddingNameFromOptions((CCOptions)opt.unsignedIntValue)}];
                }
            }

            for (NSDictionary *attempt in attempts) {
                NSMutableData *out = [NSMutableData dataWithLength:candidate.length + IVLength(alg) + 128];
                size_t moved = 0;
                CCCryptorStatus status = kCCParamError;
                NSString *modeName = attempt[@"modeName"] ?: spec[@"modeName"] ?: @"CBC/ECB";
                NSString *paddingName = attempt[@"paddingName"] ?: spec[@"paddingName"] ?: @"PKCS7Padding/NoPadding";

                if ([attempt[@"kind"] isEqual:@"mode"]) {
                    CCCryptorRef ref = NULL;
                    CCMode mode = (CCMode)[attempt[@"mode"] unsignedIntValue];
                    CCPadding padding = (CCPadding)[attempt[@"padding"] unsignedIntValue];
                    CCModeOptions modeOptions = (CCModeOptions)[attempt[@"modeOptions"] unsignedIntValue];
                    status = orig_CCCryptorCreateWithMode(kCCDecrypt, mode, alg, padding,
                                                          ivData.length ? ivData.bytes : NULL,
                                                          keyData.bytes, keyData.length,
                                                          NULL, 0, 0, modeOptions, &ref);
                    if (status == kCCSuccess && ref) {
                        size_t updateMoved = 0;
                        status = orig_CCCryptorUpdate(ref, candidate.bytes, candidate.length,
                                                      out.mutableBytes, out.length, &updateMoved);
                        if (status == kCCSuccess) {
                            size_t finalMoved = 0;
                            status = orig_CCCryptorFinal(ref,
                                                         ((uint8_t *)out.mutableBytes) + updateMoved,
                                                         out.length - updateMoved, &finalMoved);
                            moved = updateMoved + finalMoved;
                        }
                        orig_CCCryptorRelease(ref);
                    }
                } else {
                    CCOptions options = (CCOptions)[attempt[@"options"] unsignedIntValue];
                    status = orig_CCCrypt(kCCDecrypt, alg, options, keyData.bytes, keyData.length,
                                          (options & kCCOptionECBMode) ? NULL : (ivData.length ? ivData.bytes : NULL),
                                          candidate.bytes, candidate.length,
                                          out.mutableBytes, out.length, &moved);
                }

                if (debugLines.count < 12) {
                    [debugLines addObject:[NSString stringWithFormat:@"spec%lu %@/%@ candidate:%lu status:%d moved:%lu", (unsigned long)specIndex, modeName, paddingName, (unsigned long)candidate.length, status, (unsigned long)moved]];
                }
                if (status == kCCSuccess && moved > 0 && moved <= out.length) {
                    out.length = moved;
                    if (!IZXPlainLooksUseful(out)) continue;
                    NSString *plain = PreviewStringFromData(out);
                    NSString *inputKind = (candidate == encryptedData) ? @"raw-body" : @"base64/hex/json-field-decoded-body";
                    NSString *info = [NSString stringWithFormat:
                                      @"[自动尝试解密成功] %@\n来源: %@\n使用第 %lu 个已捕获密钥/参数\n算法: %@\n模式: %@\n填充: %@\nKey Hex: %@\nKey Base64: %@\nIV Hex: %@\nIV Base64: %@\n输入格式: %@\n密文长度: %lu\n明文长度: %lu\n\n明文 UTF8/raw:\n%@\n\n明文 Hex:\n%@\n\n明文 Base64:\n%@",
                                      source ?: @"URL Response", source ?: @"(unknown)", (unsigned long)specIndex,
                                      spec[@"algName"] ?: AlgorithmName(alg), modeName, paddingName,
                                      spec[@"keyHex"] ?: @"", spec[@"keyB64"] ?: @"", spec[@"ivHex"] ?: @"(null)", spec[@"ivB64"] ?: @"(null)", inputKind,
                                      (unsigned long)candidate.length, (unsigned long)out.length,
                                      plain, HexStringFromBytes(out.bytes, out.length), Base64StringFromBytes(out.bytes, out.length)];
                    NSString *bundleID = CurrentBundleID();
                    DatabaseManager *db = [DatabaseManager sharedManager];
                    [db insertDataIntoTable:@"decrypt_data" bundleID:bundleID text:info];
                    [db insertDataIntoTable:@"jiamisuanfa" bundleID:bundleID text:info];
                    LOG(@"%@", info);
                    return info;
                }
            }
        }
    }

    {
        NSArray<NSData *> *allCandidates = DecryptInputCandidates(encryptedData);

        for (NSDictionary *spec in specs) {
            NSData *origKey = spec[@"keyData"];
            if (!origKey.length) continue;
            CCAlgorithm alg = (CCAlgorithm)[spec[@"alg"] unsignedIntValue];
            if (alg != kCCAlgorithmAES) continue;

            NSMutableArray<NSData *> *keyVariants = [NSMutableArray array];
            NSMutableSet<NSNumber *> *triedLens = [NSMutableSet set];
            for (NSNumber *klenNum in @[@16, @24, @32, @(origKey.length)]) {
                NSUInteger klen = klenNum.unsignedIntegerValue;
                if (origKey.length >= klen && ![triedLens containsObject:@(klen)]) {
                    [triedLens addObject:@(klen)];
                    [keyVariants addObject:[origKey subdataWithRange:NSMakeRange(0, klen)]];
                }
            }

            for (NSData *variantKey in keyVariants) {
                for (NSData *candidate in allCandidates) {
                    if (candidate.length == 0 || candidate.length > 1024 * 1024) continue;

                    if (candidate.length > 16 && (candidate.length % 16) == 0) {
                        NSData *ivPart = [candidate subdataWithRange:NSMakeRange(0, 16)];
                        NSData *cipherPart = [candidate subdataWithRange:NSMakeRange(16, candidate.length - 16)];

                        for (NSNumber *padNum in @[@(ccPKCS7Padding), @(ccNoPadding)]) {
                            CCPadding pad = (CCPadding)padNum.unsignedIntValue;
                            NSString *desc = [NSString stringWithFormat:@"IV前缀拆分/CBC/%@/Key%lu", PaddingName(pad), (unsigned long)variantKey.length];
                            NSString *result = TryDecryptOnce(variantKey, ivPart, cipherPart,
                                                              alg, kCCModeCBC, pad, source, desc);
                            if (result) return result;
                        }

                        for (NSNumber *padNum in @[@(ccPKCS7Padding), @(ccNoPadding)]) {
                            CCPadding pad = (CCPadding)padNum.unsignedIntValue;
                            NSString *desc = [NSString stringWithFormat:@"IV前缀拆分后ECB/%@/Key%lu", PaddingName(pad), (unsigned long)variantKey.length];
                            NSString *result = TryDecryptOnce(variantKey, [NSData data], cipherPart,
                                                              alg, kCCModeECB, pad, source, desc);
                            if (result) return result;
                        }
                    }

                    if ((candidate.length % 16) == 0) {
                        for (NSNumber *padNum in @[@(ccPKCS7Padding), @(ccNoPadding)]) {
                            CCPadding pad = (CCPadding)padNum.unsignedIntValue;
                            NSString *desc = [NSString stringWithFormat:@"全数据ECB/%@/Key%lu", PaddingName(pad), (unsigned long)variantKey.length];
                            NSString *result = TryDecryptOnce(variantKey, [NSData data], candidate,
                                                              alg, kCCModeECB, pad, source, desc);
                            if (result) return result;
                        }
                    }

                    if ((candidate.length % 16) == 0) {
                        uint8_t zeroIV[16] = {0};
                        NSData *zeroIVData = [NSData dataWithBytes:zeroIV length:16];
                        for (NSNumber *padNum in @[@(ccPKCS7Padding), @(ccNoPadding)]) {
                            CCPadding pad = (CCPadding)padNum.unsignedIntValue;
                            NSString *desc = [NSString stringWithFormat:@"零IV/CBC/%@/Key%lu", PaddingName(pad), (unsigned long)variantKey.length];
                            NSString *result = TryDecryptOnce(variantKey, zeroIVData, candidate,
                                                              alg, kCCModeCBC, pad, source, desc);
                            if (result) return result;
                        }
                    }
                }
            }
        }
    }

    if (debugLines.count) {
        NSString *info = [NSString stringWithFormat:@"[自动解密未命中] %@\n已捕获参数数: %lu\n输入长度: %lu\n尝试摘要:\n%@", source ?: @"(unknown)", (unsigned long)specs.count, (unsigned long)encryptedData.length, [debugLines componentsJoinedByString:@"\n"]];
        NSString *bundleID = CurrentBundleID();
        [[DatabaseManager sharedManager] insertDataIntoTable:@"decrypt_data" bundleID:bundleID text:info];
        LOG(@"%@", info);
    }
    return nil;
}

OSStatus my_SecKeyEncrypt(SecKeyRef key, SecPadding padding, const uint8_t *plainText, size_t plainTextLen, uint8_t *cipherText, size_t *cipherTextLen) {
    NSString *bundleID = CurrentBundleID();
    DatabaseManager *db = [DatabaseManager sharedManager];
    BOOL enabled = [db getSwitch:@"rsa_encrypt" bundleID:bundleID defaultValue:NO];
    OSStatus status = orig_SecKeyEncrypt(key, padding, plainText, plainTextLen,
                                        cipherText, cipherTextLen);

    if (enabled) {
        size_t outputLength = (status == errSecSuccess && cipherTextLen) ? *cipherTextLen : 0;
        NSString *input = HexStringFromBytes(plainText, plainTextLen);
        NSString *output = HexStringFromBytes(cipherText, outputLength);
        NSString *info = [NSString stringWithFormat:@"[RSA Encrypt] Padding:%u Status:%d\nInput: %@\nOutput: %@",
                          (unsigned int)padding, (int)status, input, output];
        [db insertDataIntoTable:@"rsa_data" bundleID:bundleID text:info];
        LOG(@"%@", info);
    }
    return status;
}

OSStatus my_SecKeyDecrypt(SecKeyRef key, SecPadding padding, const uint8_t *cipherText, size_t cipherTextLen, uint8_t *plainText, size_t *plainTextLen) {
    NSString *bundleID = CurrentBundleID();
    DatabaseManager *db = [DatabaseManager sharedManager];
    BOOL enabled = [db getSwitch:@"rsa_decrypt" bundleID:bundleID defaultValue:NO];
    OSStatus status = orig_SecKeyDecrypt(key, padding, cipherText, cipherTextLen,
                                        plainText, plainTextLen);

    if (enabled) {
        size_t outputLength = (status == errSecSuccess && plainTextLen) ? *plainTextLen : 0;
        NSString *input = HexStringFromBytes(cipherText, cipherTextLen);
        NSString *output = HexStringFromBytes(plainText, outputLength);
        NSString *outputText = ReadableStringFromBytes(plainText, outputLength);
        NSString *info = [NSString stringWithFormat:
                          @"[RSA Decrypt] Padding:%u Status:%d\nInput: %@\nOutput: %@\nOutput UTF8: %@",
                          (unsigned int)padding, (int)status, input, output, outputText];
        [db insertDataIntoTable:@"rsa_data" bundleID:bundleID text:info];
        [db insertDataIntoTable:@"decrypt_data" bundleID:bundleID text:info];
        LOG(@"%@", info);
    }
    return status;
}

OSStatus my_SecKeyRawSign(SecKeyRef key, SecPadding padding, const uint8_t *dataToSign, size_t dataToSignLen, uint8_t *sig, size_t *sigLen) {
    NSString *bundleID = CurrentBundleID();
    DatabaseManager *db = [DatabaseManager sharedManager];

    if ([db getSwitch:@"rsa_sign" bundleID:bundleID defaultValue:NO]) {
        NSString *data = HexStringFromBytes(dataToSign, dataToSignLen);
        NSString *info = [NSString stringWithFormat:@"[RSA Sign] Padding: %u\nData: %@", (unsigned int)padding, data];
        [db insertDataIntoTable:@"rsa_data" bundleID:bundleID text:info];
        LOG(@"%@", info);
    }
    return orig_SecKeyRawSign(key, padding, dataToSign, dataToSignLen, sig, sigLen);
}

int my_CCKeyDerivationPBKDF(uint32_t algorithm, const char *password, size_t passwordLen,
                             const uint8_t *salt, size_t saltLen,
                             uint32_t prf, uint32_t rounds,
                             uint8_t *derivedKey, size_t derivedKeyLen) {
    int result = orig_CCKeyDerivationPBKDF(algorithm, password, passwordLen, salt, saltLen, prf, rounds, derivedKey, derivedKeyLen);
    NSString *bundleID = CurrentBundleID();
    DatabaseManager *db = [DatabaseManager sharedManager];
    if ([db isCryptoCaptureEnabledForBundle:bundleID]) {
        NSString *prfName;
        switch (prf) {
            case 1: prfName = @"HmacSHA1"; break;
            case 2: prfName = @"HmacSHA224"; break;
            case 3: prfName = @"HmacSHA256"; break;
            case 4: prfName = @"HmacSHA384"; break;
            case 5: prfName = @"HmacSHA512"; break;
            default: prfName = [NSString stringWithFormat:@"PRF:%u", (unsigned int)prf]; break;
        }
        NSString *passwordStr = [[NSString alloc] initWithBytes:password length:passwordLen encoding:NSUTF8StringEncoding];
        if (!passwordStr) passwordStr = [NSString stringWithFormat:@"%@ (non-UTF8)", HexStringFromBytes(password, passwordLen)];
        NSString *derivedKeyHex = HexStringFromBytes(derivedKey, derivedKeyLen);
        NSString *info = [NSString stringWithFormat:
                          @"[PBKDF2 密钥派生] PRF:%@ Rounds:%u\nPassword: %@\nSalt Hex: %@\nSalt Base64: %@\nDerivedKey Hex: %@\nDerivedKey Base64: %@\nDerivedKeyLen: %lu",
                          prfName, (unsigned int)rounds, passwordStr ?: @"(null)",
                          HexStringFromBytes(salt, saltLen), Base64StringFromBytes(salt, saltLen),
                          derivedKeyHex, Base64StringFromBytes(derivedKey, derivedKeyLen),
                          (unsigned long)derivedKeyLen];
        [db insertDataIntoTable:@"jiamisuanfa" bundleID:bundleID text:info];
        [db insertDataIntoTable:@"crypto_keys" bundleID:bundleID text:info];

        NSData *keyData = [NSData dataWithBytes:derivedKey length:derivedKeyLen];
        NSDictionary *spec = @{
            @"op": @(kCCDecrypt), @"alg": @(kCCAlgorithmAES),
            @"options": @(kCCOptionPKCS7Padding),
            @"opName": @"Decrypt", @"algName": @"AES",
            @"modeName": @"CBC", @"paddingName": @"PKCS7Padding",
            @"keyHex": derivedKeyHex ?: @"",
            @"keyB64": Base64StringFromBytes(derivedKey, derivedKeyLen) ?: @"",
            @"ivHex": @"(null)", @"ivB64": @"(null)",
            @"keyData": keyData, @"ivData": [NSData data]
        };
        AddRecentCryptoSpec(spec);
        LOG(@"%@", info);
    }
    return result;
}

CFDataRef my_SecKeyCreateDecryptedData(SecKeyRef key, SecKeyAlgorithm algorithm, CFDataRef ciphertext, CFErrorRef *error) {
    CFDataRef result = orig_SecKeyCreateDecryptedData(key, algorithm, ciphertext, error);
    NSString *bundleID = CurrentBundleID();
    DatabaseManager *db = [DatabaseManager sharedManager];
    if ([db getSwitch:@"rsa_decrypt" bundleID:bundleID defaultValue:NO]) {
        NSData *cipherData = (__bridge NSData *)ciphertext;
        NSData *plainData = result ? CFBridgingRelease(CFRetain(result)) : nil;
        NSString *algStr = (__bridge NSString *)algorithm;
        NSString *plainText = plainData ? ReadableStringFromBytes(plainData.bytes, plainData.length) : @"(null)";
        NSString *info = [NSString stringWithFormat:
                          @"[RSA Decrypt (现代API)] Algorithm: %@\nStatus: %@\nInput Hex: %@\nInput Base64: %@\nInput Len: %lu\nOutput UTF8: %@\nOutput Hex: %@\nOutput Base64: %@\nOutput Len: %lu",
                          algStr ?: @"(unknown)", result ? @"Success" : @"Failed",
                          HexStringFromBytes(cipherData.bytes, cipherData.length),
                          Base64StringFromBytes(cipherData.bytes, cipherData.length),
                          (unsigned long)cipherData.length,
                          plainText,
                          plainData ? HexStringFromBytes(plainData.bytes, plainData.length) : @"(null)",
                          plainData ? Base64StringFromBytes(plainData.bytes, plainData.length) : @"(null)",
                          plainData ? (unsigned long)plainData.length : 0];
        [db insertDataIntoTable:@"rsa_data" bundleID:bundleID text:info];
        [db insertDataIntoTable:@"decrypt_data" bundleID:bundleID text:info];
        LOG(@"%@", info);
    }
    return result;
}

CFDataRef my_SecKeyCreateEncryptedData(SecKeyRef key, SecKeyAlgorithm algorithm, CFDataRef plaintext, CFErrorRef *error) {
    CFDataRef result = orig_SecKeyCreateEncryptedData(key, algorithm, plaintext, error);
    NSString *bundleID = CurrentBundleID();
    DatabaseManager *db = [DatabaseManager sharedManager];
    if ([db getSwitch:@"rsa_encrypt" bundleID:bundleID defaultValue:NO]) {
        NSData *plainData = (__bridge NSData *)plaintext;
        NSData *cipherData = result ? CFBridgingRelease(CFRetain(result)) : nil;
        NSString *algStr = (__bridge NSString *)algorithm;
        NSString *info = [NSString stringWithFormat:
                          @"[RSA Encrypt (现代API)] Algorithm: %@\nStatus: %@\nPlaintext UTF8: %@\nPlaintext Hex: %@\nCiphertext Hex: %@\nCiphertext Base64: %@",
                          algStr ?: @"(unknown)", result ? @"Success" : @"Failed",
                          ReadableStringFromBytes(plainData.bytes, plainData.length),
                          HexStringFromBytes(plainData.bytes, plainData.length),
                          cipherData ? HexStringFromBytes(cipherData.bytes, cipherData.length) : @"(null)",
                          cipherData ? Base64StringFromBytes(cipherData.bytes, cipherData.length) : @"(null)"];
        [db insertDataIntoTable:@"rsa_data" bundleID:bundleID text:info];
        [db insertDataIntoTable:@"decrypt_data" bundleID:bundleID text:[@"[加密前明文捕获/现代RSA]\n" stringByAppendingString:info]];
        LOG(@"%@", info);
    }
    return result;
}

CFDataRef my_SecKeyCreateSignature(SecKeyRef key, SecKeyAlgorithm algorithm, CFDataRef dataToSign, CFErrorRef *error) {
    CFDataRef result = orig_SecKeyCreateSignature(key, algorithm, dataToSign, error);
    NSString *bundleID = CurrentBundleID();
    DatabaseManager *db = [DatabaseManager sharedManager];
    if ([db getSwitch:@"rsa_sign" bundleID:bundleID defaultValue:NO]) {
        NSData *signData = (__bridge NSData *)dataToSign;
        NSData *sigData = result ? CFBridgingRelease(CFRetain(result)) : nil;
        NSString *algStr = (__bridge NSString *)algorithm;
        NSString *info = [NSString stringWithFormat:
                          @"[RSA Sign (现代API)] Algorithm: %@\nData Hex: %@\nData UTF8: %@\nSignature Hex: %@\nSignature Base64: %@",
                          algStr ?: @"(unknown)",
                          HexStringFromBytes(signData.bytes, signData.length),
                          ReadableStringFromBytes(signData.bytes, signData.length),
                          sigData ? HexStringFromBytes(sigData.bytes, sigData.length) : @"(null)",
                          sigData ? Base64StringFromBytes(sigData.bytes, sigData.length) : @"(null)"];
        [db insertDataIntoTable:@"rsa_data" bundleID:bundleID text:info];
        LOG(@"%@", info);
    }
    return result;
}

Boolean my_SecKeyVerifySignature(SecKeyRef key, SecKeyAlgorithm algorithm, CFDataRef signedData, CFDataRef signature, CFErrorRef *error) {
    Boolean result = orig_SecKeyVerifySignature(key, algorithm, signedData, signature, error);
    NSString *bundleID = CurrentBundleID();
    DatabaseManager *db = [DatabaseManager sharedManager];
    if ([db getSwitch:@"rsa_sign" bundleID:bundleID defaultValue:NO]) {
        NSData *signData = (__bridge NSData *)signedData;
        NSData *sigData = (__bridge NSData *)signature;
        NSString *algStr = (__bridge NSString *)algorithm;
        NSString *info = [NSString stringWithFormat:
                          @"[RSA Verify (现代API)] Algorithm: %@\nVerified: %@\nSignedData Hex: %@\nSignature Hex: %@",
                          algStr ?: @"(unknown)", result ? @"YES" : @"NO",
                          HexStringFromBytes(signData.bytes, signData.length),
                          HexStringFromBytes(sigData.bytes, sigData.length)];
        [db insertDataIntoTable:@"rsa_data" bundleID:bundleID text:info];
        LOG(@"%@", info);
    }
    return result;
}

CCCryptorStatus my_CCCryptorGCMAddIV(CCCryptorRef cryptorRef, const void *iv, size_t ivLen) {
    CCCryptorStatus status = orig_CCCryptorGCMAddIV(cryptorRef, iv, ivLen);
    NSString *bundleID = CurrentBundleID();
    DatabaseManager *db = [DatabaseManager sharedManager];
    if ([db isCryptoCaptureEnabledForBundle:bundleID]) {
        NSDictionary *ctx = GetCryptorContext(cryptorRef);
        if (ctx && [ctx isKindOfClass:[NSMutableDictionary class]]) {
            NSMutableDictionary *mctx = (NSMutableDictionary *)ctx;
            mctx[@"gcmIVHex"] = HexStringFromBytes(iv, ivLen);
            mctx[@"gcmIVB64"] = Base64StringFromBytes(iv, ivLen);
            mctx[@"gcmIVData"] = DataFromBytesSafe(iv, ivLen);
            if (!mctx[@"modeName"]) mctx[@"modeName"] = @"GCM";
        }
        NSString *info = [NSString stringWithFormat:
                          @"[GCM AddIV] Status:%d\nIV Hex: %@\nIV Base64: %@\nIV Length: %lu",
                          status, HexStringFromBytes(iv, ivLen), Base64StringFromBytes(iv, ivLen), (unsigned long)ivLen];
        [db insertDataIntoTable:@"jiamisuanfa" bundleID:bundleID text:info];
        LOG(@"%@", info);
    }
    return status;
}

CCCryptorStatus my_CCCryptorGCMAddAAD(CCCryptorRef cryptorRef, const void *aData, size_t aDataLen) {
    CCCryptorStatus status = orig_CCCryptorGCMAddAAD(cryptorRef, aData, aDataLen);
    NSString *bundleID = CurrentBundleID();
    DatabaseManager *db = [DatabaseManager sharedManager];
    if ([db isCryptoCaptureEnabledForBundle:bundleID]) {
        NSDictionary *ctx = GetCryptorContext(cryptorRef);
        if (ctx && [ctx isKindOfClass:[NSMutableDictionary class]]) {
            NSMutableDictionary *mctx = (NSMutableDictionary *)ctx;
            mctx[@"gcmAADHex"] = HexStringFromBytes(aData, aDataLen);
            mctx[@"gcmAADB64"] = Base64StringFromBytes(aData, aDataLen);
        }
        NSString *info = [NSString stringWithFormat:
                          @"[GCM AddAAD] Status:%d\nAAD Hex: %@\nAAD Base64: %@\nAAD UTF8: %@\nAAD Length: %lu",
                          status, HexStringFromBytes(aData, aDataLen), Base64StringFromBytes(aData, aDataLen),
                          ReadableStringFromBytes(aData, aDataLen), (unsigned long)aDataLen];
        [db insertDataIntoTable:@"jiamisuanfa" bundleID:bundleID text:info];
        LOG(@"%@", info);
    }
    return status;
}

CCCryptorStatus my_CCCryptorGCMUpdate(CCCryptorRef cryptorRef, const void *dataIn, size_t dataInLength, void *dataOut) {
    NSString *bundleID = CurrentBundleID();
    DatabaseManager *db = [DatabaseManager sharedManager];
    BOOL enabled = [db isCryptoCaptureEnabledForBundle:bundleID];
    NSDictionary *ctx = GetCryptorContext(cryptorRef);

    CCCryptorStatus status = orig_CCCryptorGCMUpdate(cryptorRef, dataIn, dataInLength, dataOut);

    if (enabled) {

        if (ctx && [ctx isKindOfClass:[NSMutableDictionary class]]) {
            NSMutableDictionary *mctx = (NSMutableDictionary *)ctx;
            NSMutableData *inputAccum = mctx[@"inputAccum"];
            NSMutableData *outputAccum = mctx[@"outputAccum"];
            if (!inputAccum) { inputAccum = [NSMutableData data]; mctx[@"inputAccum"] = inputAccum; }
            if (!outputAccum) { outputAccum = [NSMutableData data]; mctx[@"outputAccum"] = outputAccum; }
            if (dataIn && dataInLength) [inputAccum appendBytes:dataIn length:dataInLength];
            if (dataOut && dataInLength) [outputAccum appendBytes:dataOut length:dataInLength];
        }

        BOOL isDecrypt = ctx ? ([ctx[@"op"] unsignedIntValue] == kCCDecrypt) : NO;
        NSString *header = [NSString stringWithFormat:
                            @"[CCCryptorGCMUpdate] %@ %@ Status:%d\n算法: %@\n模式: GCM\nKey Hex: %@\nIV Hex: %@",
                            SafeString(ctx[@"opName"]), SafeString(ctx[@"algName"]), status,
                            SafeString(ctx[@"algName"]), SafeString(ctx[@"keyHex"]),
                            SafeString(ctx[@"gcmIVHex"] ?: ctx[@"ivHex"])];
        NSString *io = FormatIOBlock(header, dataIn, dataInLength, dataOut, dataInLength);
        StoreCryptoRecord(io, isDecrypt);
    }
    return status;
}

CCCryptorStatus my_CCCryptorGCMFinal(CCCryptorRef cryptorRef, void *dataOut, void *tagOut, size_t *tagLength) {
    NSString *bundleID = CurrentBundleID();
    DatabaseManager *db = [DatabaseManager sharedManager];
    BOOL enabled = [db isCryptoCaptureEnabledForBundle:bundleID];
    NSDictionary *ctx = GetCryptorContext(cryptorRef);

    CCCryptorStatus status = orig_CCCryptorGCMFinal(cryptorRef, dataOut, tagOut, tagLength);

    if (enabled) {
        size_t tagLen = (status == kCCSuccess && tagLength) ? *tagLength : 0;
        BOOL isDecrypt = ctx ? ([ctx[@"op"] unsignedIntValue] == kCCDecrypt) : NO;
        NSString *tagHex = HexStringFromBytes(tagOut, tagLen);
        NSString *tagB64 = Base64StringFromBytes(tagOut, tagLen);

        NSString *tagInfo = [NSString stringWithFormat:
                             @"[GCM Final Tag] %@ %@ Status:%d\nTag Hex: %@\nTag Base64: %@\nTag Length: %lu",
                             SafeString(ctx[@"opName"]), SafeString(ctx[@"algName"]), status,
                             tagHex, tagB64, (unsigned long)tagLen];
        StoreCryptoRecord(tagInfo, isDecrypt);

        if (ctx && [ctx isKindOfClass:[NSMutableDictionary class]]) {
            NSData *fullInput = ((NSMutableDictionary *)ctx)[@"inputAccum"];
            NSData *fullOutput = ((NSMutableDictionary *)ctx)[@"outputAccum"];
            if (fullOutput.length || fullInput.length) {
                NSString *wholeHeader = [NSString stringWithFormat:
                    @"[GCM 完整%@结果] %@ %@ Status:%d\n算法: %@\n模式: GCM\nKey Hex: %@\nKey Base64: %@\nIV Hex: %@\nIV Base64: %@\nAAD Hex: %@\nTag Hex: %@\nTag Base64: %@",
                    isDecrypt ? @"解密" : @"加密", SafeString(ctx[@"opName"]), SafeString(ctx[@"algName"]), status,
                    SafeString(ctx[@"algName"]),
                    SafeString(ctx[@"keyHex"]), SafeString(ctx[@"keyB64"]),
                    SafeString(ctx[@"gcmIVHex"] ?: ctx[@"ivHex"]),
                    SafeString(ctx[@"gcmIVB64"] ?: ctx[@"ivB64"]),
                    SafeString(((NSDictionary *)ctx)[@"gcmAADHex"] ?: @"(null)"),
                    tagHex, tagB64];
                NSString *whole = FormatIOBlock(wholeHeader, fullInput.bytes, fullInput.length, fullOutput.bytes, fullOutput.length);
                StoreCryptoRecord(whole, isDecrypt);
                if (!isDecrypt && fullInput.length > 0) {
                    [[DatabaseManager sharedManager] insertDataIntoTable:@"decrypt_data" bundleID:bundleID text:[@"[GCM 加密前明文捕获]\n" stringByAppendingString:whole]];
                }
            }
        }
    }
    return status;
}

void RegisterCryptoHooks(void) {
    struct rebinding rebindings[] = {
        {"CC_MD5", my_CC_MD5, (void **)&orig_CC_MD5},
        {"CC_SHA1", my_CC_SHA1, (void **)&orig_CC_SHA1},
        {"CC_SHA224", my_CC_SHA224, (void **)&orig_CC_SHA224},
        {"CC_SHA256", my_CC_SHA256, (void **)&orig_CC_SHA256},
        {"CC_SHA384", my_CC_SHA384, (void **)&orig_CC_SHA384},
        {"CC_SHA512", my_CC_SHA512, (void **)&orig_CC_SHA512},
        {"CCHmac", my_CCHmac, (void **)&orig_CCHmac},
        {"CCCrypt", my_CCCrypt, (void **)&orig_CCCrypt},
        {"CCCryptorCreate", my_CCCryptorCreate, (void **)&orig_CCCryptorCreate},
        {"CCCryptorCreateWithMode", my_CCCryptorCreateWithMode, (void **)&orig_CCCryptorCreateWithMode},
        {"CCCryptorUpdate", my_CCCryptorUpdate, (void **)&orig_CCCryptorUpdate},
        {"CCCryptorFinal", my_CCCryptorFinal, (void **)&orig_CCCryptorFinal},
        {"CCCryptorRelease", my_CCCryptorRelease, (void **)&orig_CCCryptorRelease},
        {"CCKeyDerivationPBKDF", my_CCKeyDerivationPBKDF, (void **)&orig_CCKeyDerivationPBKDF},
        {"CCCryptorGCMAddIV", my_CCCryptorGCMAddIV, (void **)&orig_CCCryptorGCMAddIV},
        {"CCCryptorGCMAddAAD", my_CCCryptorGCMAddAAD, (void **)&orig_CCCryptorGCMAddAAD},
        {"CCCryptorGCMUpdate", my_CCCryptorGCMUpdate, (void **)&orig_CCCryptorGCMUpdate},
        {"CCCryptorGCMFinal", my_CCCryptorGCMFinal, (void **)&orig_CCCryptorGCMFinal},
        {"SecKeyEncrypt", my_SecKeyEncrypt, (void **)&orig_SecKeyEncrypt},
        {"SecKeyDecrypt", my_SecKeyDecrypt, (void **)&orig_SecKeyDecrypt},
        {"SecKeyRawSign", my_SecKeyRawSign, (void **)&orig_SecKeyRawSign},
        {"SecKeyCreateDecryptedData", my_SecKeyCreateDecryptedData, (void **)&orig_SecKeyCreateDecryptedData},
        {"SecKeyCreateEncryptedData", my_SecKeyCreateEncryptedData, (void **)&orig_SecKeyCreateEncryptedData},
        {"SecKeyCreateSignature", my_SecKeyCreateSignature, (void **)&orig_SecKeyCreateSignature},
        {"SecKeyVerifySignature", my_SecKeyVerifySignature, (void **)&orig_SecKeyVerifySignature},
    };

    int result = rebind_symbols(rebindings, sizeof(rebindings) / sizeof(rebindings[0]));
    LOG(@"Crypto hooks registered: %d", result);
}
