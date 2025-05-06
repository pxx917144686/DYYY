//
//  FLEXTypeEncodingParser.m
//  FLEX
//
//  由 Tanner Bennett 创建于 8/22/19.
//  版权所有 © 2020 FLEX Team。保留所有权利。
//
// 遇到问题联系中文翻译作者：pxx917144686

#import "FLEXTypeEncodingParser.h"
#import "FLEXRuntimeUtility.h"

#define S(__ch) ({ \
    unichar __c = __ch; \
    [[NSString alloc] initWithCharacters:&__c length:1]; \
})

typedef struct FLEXTypeInfo {
    /// 大小未对齐。如果完全不支持，则为 -1。
    ssize_t size;
    ssize_t align;
    /// 如果类型完全不受支持，则为 NO
    /// 如果类型完全或部分受支持，则为 YES。
    BOOL supported;
    /// 如果类型仅部分受支持，则为 YES，例如
    /// 指针类型中的联合，或没有成员信息的命名结构类型。
    /// 这些可以手动更正，因为它们可以被修复或替换为较少的信息。
    BOOL fixesApplied;
    /// 此类型是否为联合，或者其成员之一
    /// 递归包含联合（不包括指针）。
    ///
    /// 联合比较棘手，因为它们受 \c NSGetSizeAndAlignment 支持，
    /// 但不受 \c NSMethodSignature 支持，因此我们需要跟踪
    /// 类型何时包含联合，以便将其从指针类型中清除。
    BOOL containsUnion;
    /// 如果不是 void，则 size 只能为 0
    BOOL isVoid;
} FLEXTypeInfo;

/// 完全不受支持的类型的类型信息。
static FLEXTypeInfo FLEXTypeInfoUnsupported = (FLEXTypeInfo){ -1, 0, NO, NO, NO, NO };
/// void 返回类型的类型信息。
static FLEXTypeInfo FLEXTypeInfoVoid = (FLEXTypeInfo){ 0, 0, YES, NO, NO, YES };

/// 为完全或部分受支持的类型构建类型信息。
static inline FLEXTypeInfo FLEXTypeInfoMake(ssize_t size, ssize_t align, BOOL fixed) {
    return (FLEXTypeInfo){ size, align, YES, fixed, NO, NO };
}

/// 为完全或部分受支持的类型构建类型信息。
static inline FLEXTypeInfo FLEXTypeInfoMakeU(ssize_t size, ssize_t align, BOOL fixed, BOOL hasUnion) {
    return (FLEXTypeInfo){ size, align, YES, fixed, hasUnion, NO };
}

BOOL FLEXGetSizeAndAlignment(const char *type, NSUInteger *sizep, NSUInteger *alignp) {
    NSInteger size = 0;
    ssize_t align = 0;
    size = [FLEXTypeEncodingParser sizeForTypeEncoding:@(type) alignment:&align];
    
    if (size == -1) {
        return NO;
    }
    
    if (sizep) {
        *sizep = (NSUInteger)size;
    }
    
    if (alignp) {
        *alignp = (NSUInteger)size;
    }
    
    return YES;
}

@interface FLEXTypeEncodingParser ()
@property (nonatomic, readonly) NSScanner *scan;
@property (nonatomic, readonly) NSString *scanned;
@property (nonatomic, readonly) NSString *unscanned;
@property (nonatomic, readonly) char nextChar;

/// 在扫描时根据需要对此字符串进行替换
@property (nonatomic) NSMutableString *cleaned;
/// \c cleaned 中进行进一步替换的偏移量
@property (nonatomic, readonly) NSUInteger cleanedReplacingOffset;
@end

@implementation FLEXTypeEncodingParser

- (NSString *)scanned {
    return [self.scan.string substringToIndex:self.scan.scanLocation];
}

- (NSString *)unscanned {
    return [self.scan.string substringFromIndex:self.scan.scanLocation];
}

#pragma mark 初始化

- (id)initWithObjCTypes:(NSString *)typeEncoding {
    self = [super init];
    if (self) {
        _scan = [NSScanner scannerWithString:typeEncoding];
        _scan.caseSensitive = YES;
        _cleaned = typeEncoding.mutableCopy;
    }

    return self;
}


#pragma mark 公开

+ (BOOL)methodTypeEncodingSupported:(NSString *)typeEncoding cleaned:(NSString * __autoreleasing *)cleanedEncoding {
    if (!typeEncoding.length) {
        return NO;
    }
    
    FLEXTypeEncodingParser *parser = [[self alloc] initWithObjCTypes:typeEncoding];
    
    while (!parser.scan.isAtEnd) {
        FLEXTypeInfo info = [parser parseNextType];
        
        if (!info.supported || info.containsUnion || (info.size == 0 && !info.isVoid)) {
            return NO;
        }
    }
    
    if (cleanedEncoding) {
        *cleanedEncoding = parser.cleaned.copy;
    }
    
    return YES;
}

+ (NSString *)type:(NSString *)typeEncoding forMethodArgumentAtIndex:(NSUInteger)idx {
    FLEXTypeEncodingParser *parser = [[self alloc] initWithObjCTypes:typeEncoding];

    // 扫描到我们想要的参数
    for (NSUInteger i = 0; i < idx; i++) {
        if (![parser scanPastArg]) {
            [NSException raise:NSRangeException
                format:@"索引 %@ 超出类型编码 '%@' 的范围", 
                @(idx), typeEncoding
            ];
        }
    }

    return [parser scanArg];
}

+ (ssize_t)size:(NSString *)typeEncoding forMethodArgumentAtIndex:(NSUInteger)idx {
    return [self sizeForTypeEncoding:[self type:typeEncoding forMethodArgumentAtIndex:idx] alignment:nil];
}

+ (ssize_t)sizeForTypeEncoding:(NSString *)type alignment:(ssize_t *)alignOut {
    return [self sizeForTypeEncoding:type alignment:alignOut unaligned:NO];
}

+ (ssize_t)sizeForTypeEncoding:(NSString *)type alignment:(ssize_t *)alignOut unaligned:(BOOL)unaligned {
    FLEXTypeInfo info = [self parseType:type];
    
    ssize_t size = info.size;
    ssize_t align = info.align;
    
    if (info.supported) {
        if (alignOut) {
            *alignOut = align;
        }

        if (!unaligned) {
            size += size % align;
        }
    }
    
    // 如果不支持，则 size 为 -1
    return size;
}

+ (FLEXTypeInfo)parseType:(NSString *)type cleaned:(NSString * __autoreleasing *)cleanedEncoding {
    FLEXTypeEncodingParser *parser = [[self alloc] initWithObjCTypes:type];
    FLEXTypeInfo info = [parser parseNextType];
    if (cleanedEncoding) {
        *cleanedEncoding = parser.cleaned;
    }
    
    return info;
}

+ (FLEXTypeInfo)parseType:(NSString *)type {
    return [self parseType:type cleaned:nil];
}

#pragma mark 私有

- (NSCharacterSet *)identifierFirstCharCharacterSet {
    static NSCharacterSet *identifierFirstSet = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *allowed = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_$";
        identifierFirstSet = [NSCharacterSet characterSetWithCharactersInString:allowed];
    });
    
    return identifierFirstSet;
}

- (NSCharacterSet *)identifierCharacterSet {
    static NSCharacterSet *identifierSet = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *allowed = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_$1234567890";
        identifierSet = [NSCharacterSet characterSetWithCharactersInString:allowed];
    });
    
    return identifierSet;
}

- (char)nextChar {
    NSScanner *scan = self.scan;
    return [scan.string characterAtIndex:scan.scanLocation];
}

/// 用于扫描结构体/类名
- (NSString *)scanIdentifier {
    NSString *prefix = nil, *suffix = nil;
    
    // 标识符不能以数字开头
    if (![self.scan scanCharactersFromSet:self.identifierFirstCharCharacterSet intoString:&prefix]) {
        return nil;
    }
    
    // 可选，因为标识符可能只有一个字符
    [self.scan scanCharactersFromSet:self.identifierCharacterSet intoString:&suffix];
    
    if (suffix) {
        return [prefix stringByAppendingString:suffix];
    }
    
    return prefix;
}

/// @return 以字节为单位的大小
- (ssize_t)sizeForType:(FLEXTypeEncoding)type {
    switch (type) {
        case FLEXTypeEncodingChar: return sizeof(char);
        case FLEXTypeEncodingInt: return sizeof(int);
        case FLEXTypeEncodingShort: return sizeof(short);
        case FLEXTypeEncodingLong: return sizeof(long);
        case FLEXTypeEncodingLongLong: return sizeof(long long);
        case FLEXTypeEncodingUnsignedChar: return sizeof(unsigned char);
        case FLEXTypeEncodingUnsignedInt: return sizeof(unsigned int);
        case FLEXTypeEncodingUnsignedShort: return sizeof(unsigned short);
        case FLEXTypeEncodingUnsignedLong: return sizeof(unsigned long);
        case FLEXTypeEncodingUnsignedLongLong: return sizeof(unsigned long long);
        case FLEXTypeEncodingFloat: return sizeof(float);
        case FLEXTypeEncodingDouble: return sizeof(double);
        case FLEXTypeEncodingLongDouble: return sizeof(long double);
        case FLEXTypeEncodingCBool: return sizeof(_Bool);
        case FLEXTypeEncodingVoid: return 0;
        case FLEXTypeEncodingCString: return sizeof(char *);
        case FLEXTypeEncodingObjcObject:  return sizeof(id);
        case FLEXTypeEncodingObjcClass:  return sizeof(Class);
        case FLEXTypeEncodingSelector: return sizeof(SEL);
        // 未知 / '?' 通常是指针。在极少数情况下
        // 它不是，例如在 '{?=...}' 中，它永远不会传递到这里。
        case FLEXTypeEncodingUnknown:
        case FLEXTypeEncodingPointer: return sizeof(uintptr_t);

        default: return -1;
    }
}

- (FLEXTypeInfo)parseNextType {
    NSUInteger start = self.scan.scanLocation;

    // 首先检查 void
    if ([self scanChar:FLEXTypeEncodingVoid]) {
        // 跳过方法签名中的参数帧
        [self scanSize];
        return FLEXTypeInfoVoid;
    }

    // 扫描可选的 const
    [self scanChar:FLEXTypeEncodingConst];

    // 检查指针，然后扫描下一个
    if ([self scanChar:FLEXTypeEncodingPointer]) {
        // 递归扫描其他内容
        NSUInteger pointerTypeStart = self.scan.scanLocation;
        if ([self scanPastArg]) {
            // 确保指针类型受支持，如果不支持则清理它
            NSUInteger pointerTypeLength = self.scan.scanLocation - pointerTypeStart;
            NSString *pointerType = [self.scan.string
                substringWithRange:NSMakeRange(pointerTypeStart, pointerTypeLength)
            ];
            
            // 深层嵌套的清理信息会在这里丢失
            NSString *cleaned = nil;
            FLEXTypeInfo info = [self.class parseType:pointerType cleaned:&cleaned];
            BOOL needsCleaning = !info.supported || info.containsUnion || info.fixesApplied;
            
            // 如果类型不受支持、格式错误或包含联合，则清理该类型。
            // （联合受 NSGetSizeAndAlignment 支持，但由于某种原因
            // 不受 NSMethodSignature 支持）
            if (needsCleaning) {
                // 如果不受支持，则上面的 parseType:cleaned: 中没有发生清理。
                // 否则，类型部分受支持并且我们确实清理了它，
                // 我们将用上面清理后的类型替换此类型。
                if (!info.supported || info.containsUnion) {
                    cleaned = [self cleanPointeeTypeAtLocation:pointerTypeStart];
                }
                
                NSInteger offset = self.cleanedReplacingOffset;
                NSInteger location = pointerTypeStart - offset;
                [self.cleaned replaceCharactersInRange:NSMakeRange(
                    location, pointerTypeLength
                ) withString:cleaned];
            }
            
            // 跳过可选的帧偏移量
            [self scanSize];
            
            ssize_t size = [self sizeForType:FLEXTypeEncodingPointer];
            return FLEXTypeInfoMake(size, size, !info.supported || info.fixesApplied);
        } else {
            // 扫描失败，中止
            self.scan.scanLocation = start;
            return FLEXTypeInfoUnsupported;
        }
    }

    // 检查结构体/联合/数组
    char next = self.nextChar;
    BOOL didScanSUA = YES, structOrUnion = NO, isUnion = NO;
    FLEXTypeEncoding opening = FLEXTypeEncodingNull, closing = FLEXTypeEncodingNull;
    switch (next) {
        case FLEXTypeEncodingStructBegin:
            structOrUnion = YES;
            opening = FLEXTypeEncodingStructBegin;
            closing = FLEXTypeEncodingStructEnd;
            break;
        case FLEXTypeEncodingUnionBegin:
            structOrUnion = isUnion = YES;
            opening = FLEXTypeEncodingUnionBegin;
            closing = FLEXTypeEncodingUnionEnd;
            break;
        case FLEXTypeEncodingArrayBegin:
            opening = FLEXTypeEncodingArrayBegin;
            closing = FLEXTypeEncodingArrayEnd;
            break;
            
        default:
            didScanSUA = NO;
            break;
    }
    
    if (didScanSUA) {
        BOOL containsUnion = isUnion;
        BOOL fixesApplied = NO;
        
        NSUInteger backup = self.scan.scanLocation;

        // 确保我们有一个结束标记
        if (![self scanPair:opening close:closing]) {
            // 扫描失败，中止
            self.scan.scanLocation = start;
            return FLEXTypeInfoUnsupported;
        }

        // 将光标移到开始标记（结构体/联合/数组）之后
        NSInteger arrayCount = -1;
        self.scan.scanLocation = backup + 1;
        
        if (!structOrUnion) {
            arrayCount = [self scanSize];
            if (!arrayCount || self.nextChar == FLEXTypeEncodingArrayEnd) {
                // 格式错误的数组类型：
                // 1. 数组必须在左大括号后有一个计数
                // 2. 数组必须在计数后有一个元素类型
                self.scan.scanLocation = start;
                return FLEXTypeInfoUnsupported;
            }
        } else {
            // 如果我们遇到类似 {?=b8b4b1b1b18[8S]} 中的 ?= 部分，
            // 那么我们跳过它，因为它在这种情况下对我们没有任何意义。
            // 它是完全可选的，如果失败，我们会回到原来的位置。
            if (![self scanTypeName] && self.nextChar == FLEXTypeEncodingUnknown) {
                // 例外：我们正在尝试解析无效的 {?}
                self.scan.scanLocation = start;
                return FLEXTypeInfoUnsupported;
            }
        }

        // 将成员的大小相加：
        // 在检查其他成员之前扫描位域
        //
        // 数组只有一个“成员”，但
        // 此逻辑仍然适用于它们
        ssize_t sizeSoFar = 0;
        ssize_t maxAlign = 0;
        NSMutableString *cleanedBackup = self.cleaned.mutableCopy;
        
        while (![self scanChar:closing]) {
            next = self.nextChar;
            // 检查位域，我们无法支持，因为
            // 位域的类型编码不包括对齐信息
            if (next == FLEXTypeEncodingBitField) {
                self.scan.scanLocation = start;
                return FLEXTypeInfoUnsupported;
            }

            // 结构体字段可以命名
            if (next == FLEXTypeEncodingQuote) {
                [self scanPair:FLEXTypeEncodingQuote close:FLEXTypeEncodingQuote];
            }

            FLEXTypeInfo info = [self parseNextType];
            if (!info.supported || info.containsUnion) {
                // 上面的调用是此方法中唯一一次
                // `cleaned` 可能被递归修改的地方，所以这是
                // 唯一需要保留和恢复备份的地方
                //
                // 例如，如果我们一直在迭代一个结构的成员，
                // 并且到目前为止遇到了一些需要清理的指针，
                // 然后突然遇到一个不受支持的成员，我们需要能够“倒带”并
                // 撤消对 `self.cleaned` 的任何更改，以便调用堆栈中的父调用
                // 可以在需要时完全清除当前结构。示例如下：
                //
                //      初始: ^{foo=^{pair<d,d>}{^pair<i,i>}{invalid_type<d>}}
                //                       v-- 此处
                //    第一次清理: ^{foo=^{?=}{^pair<i,i>}{invalid_type<d>}
                //                           v-- 此处
                //    第二次清理: ^{foo=^{?=}{?=}{invalid_type<d>}
                //                               v-- 此处
                //  无法清理: ^{foo=^{?=}{?=}{invalid_type<d>}
                //                 v-- 到此处
                //       倒带: ^{foo=^{pair<d,d>}{^pair<i,i>}{invalid_type<d>}}
                //  最终清理: ^{foo=}
                self.cleaned = cleanedBackup;
                self.scan.scanLocation = start;
                return FLEXTypeInfoUnsupported;
            }
            
            // 联合的大小是其最大成员的大小，
            // 数组是 element.size x length，并且
            // 结构体是其成员的总和
            if (structOrUnion) {
                if (isUnion) { // 联合
                    sizeSoFar = MAX(sizeSoFar, info.size);
                } else { // 结构体
                    sizeSoFar += info.size;
                }
            } else { // 数组
                sizeSoFar = info.size * arrayCount;
            }
            
            // 传播最大对齐和其他元数据
            maxAlign = MAX(maxAlign, info.align);
            containsUnion = containsUnion || info.containsUnion;
            fixesApplied = fixesApplied || info.fixesApplied;
        }
        
        // 跳过可选的帧偏移量
        [self scanSize];

        return FLEXTypeInfoMakeU(sizeSoFar, maxAlign, fixesApplied, containsUnion);
    }
    
    // 扫描单个内容和可能的大小并返回
    ssize_t size = -1;
    char t = self.nextChar;
    switch (t) {
        case FLEXTypeEncodingUnknown:
        case FLEXTypeEncodingChar:
        case FLEXTypeEncodingInt:
        case FLEXTypeEncodingShort:
        case FLEXTypeEncodingLong:
        case FLEXTypeEncodingLongLong:
        case FLEXTypeEncodingUnsignedChar:
        case FLEXTypeEncodingUnsignedInt:
        case FLEXTypeEncodingUnsignedShort:
        case FLEXTypeEncodingUnsignedLong:
        case FLEXTypeEncodingUnsignedLongLong:
        case FLEXTypeEncodingFloat:
        case FLEXTypeEncodingDouble:
        case FLEXTypeEncodingLongDouble:
        case FLEXTypeEncodingCBool:
        case FLEXTypeEncodingCString:
        case FLEXTypeEncodingSelector:
        case FLEXTypeEncodingBitField: {
            self.scan.scanLocation++;
            // 跳过可选的帧偏移量
            [self scanSize];
            
            if (t == FLEXTypeEncodingBitField) {
                self.scan.scanLocation = start;
                return FLEXTypeInfoUnsupported;
            } else {
                // 计算大小
                size = [self sizeForType:t];
            }
        }
            break;
        
        case FLEXTypeEncodingObjcObject:
        case FLEXTypeEncodingObjcClass: {
            self.scan.scanLocation++;
            // 这些后面可能有数字或引号
            // 跳过可选的帧偏移量
            [self scanSize];
            [self scanPair:FLEXTypeEncodingQuote close:FLEXTypeEncodingQuote];
            size = sizeof(id);
        }
            break;
            
        default: break;
    }

    if (size > 0) {
        // 标量类型的对齐方式是其大小
        return FLEXTypeInfoMake(size, size, NO);
    }

    self.scan.scanLocation = start;
    return FLEXTypeInfoUnsupported;
}

- (BOOL)scanString:(NSString *)str {
    return [self.scan scanString:str intoString:nil];
}

- (BOOL)canScanString:(NSString *)str {
    NSScanner *scan = self.scan;
    NSUInteger len = str.length;
    unichar buff1[len], buff2[len];
    
    [str getCharacters:buff1];
    [scan.string getCharacters:buff2 range:NSMakeRange(scan.scanLocation, len)];
    if (memcmp(buff1, buff2, len) == 0) {
        return YES;
    }

    return NO;
}

- (BOOL)canScanChar:(char)c {
    // 通过避免对这两个我们知道不会被释放的对象进行任何 ARC 调用，
    // 我们在这个解析器中获得了巨大的性能提升，因为这个方法是解析器中使用最频繁的方法之一。
    // 这可能是这个类中性能最关键的方法。
    __unsafe_unretained NSScanner *scan = self.scan;
    __unsafe_unretained NSString *string = scan.string;
    if (scan.scanLocation >= string.length) return NO;
    
    return [string characterAtIndex:scan.scanLocation] == c;
}

- (BOOL)scanChar:(char)c {
    if ([self canScanChar:c]) {
        self.scan.scanLocation++;
        return YES;
    }
    
    return NO;
}

- (BOOL)scanChar:(char)c into:(char *)ref {
    if ([self scanChar:c]) {
        *ref = c;
        return YES;
    }

    return NO;
}

- (ssize_t)scanSize {
    NSInteger size = 0;
    if ([self.scan scanInteger:&size]) {
        return size;
    }

    return 0;
}

- (NSString *)scanPair:(char)c1 close:(char)c2 {
    // 起始位置和字符串变量
    NSUInteger start = self.scan.scanLocation;
    NSString *s1 = S(c1);

    // 扫描开始标记
    if (![self scanChar:c1]) {
        self.scan.scanLocation = start;
        return nil;
    }

    // 用于扫描到任一符号的字符集
    NSCharacterSet *bothChars = ({
        unichar buff[2] = { c1, c2 };
        NSString *bothCharsStr = [[NSString alloc] initWithCharacters:buff length:2];
        [NSCharacterSet characterSetWithCharactersInString:bothCharsStr];
    });

    // 用于查找配对的堆栈，从开始符号开始
    NSMutableArray *stack = [NSMutableArray arrayWithObject:s1];

    // 扫描到一对开始/结束符号的结束端的算法
    // scanUpToCharactersFromSet:intoString: 如果您已经在其中一个字符处，则返回 NO，
    // 因此我们需要检查如果它返回 NO，我们是否真的可以扫描一个
    while ([self.scan scanUpToCharactersFromSet:bothChars intoString:nil] ||
           [self canScanChar:c1] || [self canScanChar:c2]) {
        // 找到结束符号
        if ([self scanChar:c2]) {
            if (!stack.count) {
                // 中止，没有匹配的开始符号
                self.scan.scanLocation = start;
                return nil;
            }

            // 找到配对，弹出开始符号
            [stack removeLastObject];
            // 如果我们到达了需要的结束大括号，则退出循环
            if (!stack.count) {
                break;
            }
        }
        // 找到开始符号
        if ([self scanChar:c1]) {
            // 开始配对
            [stack addObject:s1];
        }
    }

    if (stack.count) {
        // 中止，没有匹配的结束符号
        self.scan.scanLocation = start;
        return nil;
    }

    // 切出我们刚刚扫描的字符串
    return [self.scan.string
        substringWithRange:NSMakeRange(start, self.scan.scanLocation - start)
    ];
}

- (BOOL)scanPastArg {
    NSUInteger start = self.scan.scanLocation;

    // 首先检查 void
    if ([self scanChar:FLEXTypeEncodingVoid]) {
        return YES;
    }

    // 扫描可选的 const
    [self scanChar:FLEXTypeEncodingConst];

    // 检查指针，然后扫描下一个
    if ([self scanChar:FLEXTypeEncodingPointer]) {
        // 递归扫描其他内容
        if ([self scanPastArg]) {
            return YES;
        } else {
            // 扫描失败，中止
            self.scan.scanLocation = start;
            return NO;
        }
    }
    
    char next = self.nextChar;

    // 检查结构体/联合/数组，扫描过去
    FLEXTypeEncoding opening = FLEXTypeEncodingNull, closing = FLEXTypeEncodingNull;
    BOOL checkPair = YES;
    switch (next) {
        case FLEXTypeEncodingStructBegin:
            opening = FLEXTypeEncodingStructBegin;
            closing = FLEXTypeEncodingStructEnd;
            break;
        case FLEXTypeEncodingUnionBegin:
            opening = FLEXTypeEncodingUnionBegin;
            closing = FLEXTypeEncodingUnionEnd;
            break;
        case FLEXTypeEncodingArrayBegin:
            opening = FLEXTypeEncodingArrayBegin;
            closing = FLEXTypeEncodingArrayEnd;
            break;
            
        default:
            checkPair = NO;
            break;
    }
    
    if (checkPair && [self scanPair:opening close:closing]) {
        return YES;
    }

    // 扫描单个内容和可能的大小并返回
    switch (next) {
        case FLEXTypeEncodingUnknown:
        case FLEXTypeEncodingChar:
        case FLEXTypeEncodingInt:
        case FLEXTypeEncodingShort:
        case FLEXTypeEncodingLong:
        case FLEXTypeEncodingLongLong:
        case FLEXTypeEncodingUnsignedChar:
        case FLEXTypeEncodingUnsignedInt:
        case FLEXTypeEncodingUnsignedShort:
        case FLEXTypeEncodingUnsignedLong:
        case FLEXTypeEncodingUnsignedLongLong:
        case FLEXTypeEncodingFloat:
        case FLEXTypeEncodingDouble:
        case FLEXTypeEncodingLongDouble:
        case FLEXTypeEncodingCBool:
        case FLEXTypeEncodingCString:
        case FLEXTypeEncodingSelector:
        case FLEXTypeEncodingBitField: {
            self.scan.scanLocation++;
            // 大小是可选的
            [self scanSize];
            return YES;
        }
        
        case FLEXTypeEncodingObjcObject:
        case FLEXTypeEncodingObjcClass: {
            self.scan.scanLocation++;
            // 这些后面可能有数字或引号
            [self scanSize] || [self scanPair:FLEXTypeEncodingQuote close:FLEXTypeEncodingQuote];
            return YES;
        }
            
        default: break;
    }

    self.scan.scanLocation = start;
    return NO;
}

- (NSString *)scanArg {
    NSUInteger start = self.scan.scanLocation;
    if (![self scanPastArg]) {
        return nil;
    }

    return [self.scan.string
        substringWithRange:NSMakeRange(start, self.scan.scanLocation - start)
    ];
}

- (BOOL)scanTypeName {
    NSUInteger start = self.scan.scanLocation;

    // 类似 {?=b8b4b1b1b18[8S]} 中的 ?= 部分
    if ([self scanChar:FLEXTypeEncodingUnknown]) {
        if (![self scanString:@"="]) {
            // 对于像 {?=} 这样的字符串，没有可用的大小信息
            self.scan.scanLocation = start;
            return NO;
        }
    } else {
        if (![self scanIdentifier] || ![self scanString:@"="]) {
            // 1. 不是有效的标识符
            // 2. 对于像 {CGPoint} 这样的字符串，没有可用的大小信息
            self.scan.scanLocation = start;
            return NO;
        }
    }

    return YES;
}

- (NSString *)extractTypeNameFromScanLocation:(BOOL)allowMissingTypeInfo closing:(FLEXTypeEncoding)closeTag {
    NSUInteger start = self.scan.scanLocation;

    // 类似 {?=b8b4b1b1b18[8S]} 中的 ?= 部分
    if ([self scanChar:FLEXTypeEncodingUnknown]) {
        return @"?";
    } else {
        NSString *typeName = [self scanIdentifier];
        char next = self.nextChar;
        
        if (!typeName) {
            // 没有扫描到标识符
            self.scan.scanLocation = start;
            return nil;
        }
        
        switch (next) {
            case '=':
                return typeName;
                
            default: {
                // = 是非可选的，除非我们 allowMissingTypeInfo，在这种情况下
                // 下一个字符需要是结束大括号
                if (allowMissingTypeInfo && next == closeTag) {
                    return typeName;
                } else {
                    // 不是有效的标识符；可能是通用的 C++ 类型
                    // 例如 {pair<T, U>} 其中 `name` 被找到为 `pair`
                    self.scan.scanLocation = start;
                    return nil;
                }
            }
        }
    }
}

- (NSString *)cleanPointeeTypeAtLocation:(NSUInteger)scanLocation {
    NSUInteger start = self.scan.scanLocation;
    self.scan.scanLocation = scanLocation;
    
    // 当扫描的类型已经干净时的返回/清理代码
    NSString * (^typeIsClean)(void) = ^NSString * {
        NSString *clean = [self.scan.string
            substringWithRange:NSMakeRange(scanLocation, self.scan.scanLocation - scanLocation)
        ];
        // 即使成功也要重置扫描位置，因为此方法不应该更改它
        self.scan.scanLocation = start;
        return clean;
    };

    // 没有 void，这不是返回类型

    // 扫描可选的 const
    [self scanChar:FLEXTypeEncodingConst];
    
    char next = self.nextChar;
    switch (next) {
        case FLEXTypeEncodingPointer:
            // 递归扫描其他内容
            [self scanChar:next];
            return [self cleanPointeeTypeAtLocation:self.scan.scanLocation];
            
        case FLEXTypeEncodingArrayBegin:
            // 所有数组都受支持，扫描过去
            if ([self scanPair:FLEXTypeEncodingArrayBegin close:FLEXTypeEncodingArrayEnd]) {
                return typeIsClean();
            }
            break;
            
        case FLEXTypeEncodingUnionBegin:
            // NSMethodSignature 中完全不支持联合
            // 我们可以检查结束标记以确保安全，但是嗯
            self.scan.scanLocation = start;
            return @"?";
            
        case FLEXTypeEncodingStructBegin: {
            FLEXTypeInfo info = [self.class parseType:self.unscanned];
            if (info.supported && !info.fixesApplied) {
                [self scanPastArg];
                return typeIsClean();
            }
            
            // 我们刚刚尝试扫描的结构不受支持，所以如果它有名称，
            // 只返回其名称。如果没有，则只返回一个问号。
            self.scan.scanLocation++; // 跳过 {
            NSString *name = [self extractTypeNameFromScanLocation:YES closing:FLEXTypeEncodingStructEnd];
            if (name) {
                // 获取名称，扫描到结束标记
                [self.scan scanUpToString:@"}" intoString:nil];
                if (![self scanChar:FLEXTypeEncodingStructEnd]) {
                    // 缺少结构体结束标记
                    self.scan.scanLocation = start;
                    return nil;
                }
            } else {
                // 没有扫描到有效的标识符，可能是 C++ 类型
                self.scan.scanLocation = start;
                return @"{?=}";
            }
            
            // 即使成功也要重置扫描位置，因为此方法不应该更改它
            self.scan.scanLocation = start;
            return ({ // "{name=}"
                NSMutableString *format = @"{".mutableCopy;
                [format appendString:name];
                [format appendString:@"=}"];
                format;
            });
        }
        
        default:
            break;
    }
    
    // 检查其他类型，理论上这些类型都有效，但无所谓
    FLEXTypeInfo info = [self parseNextType];
    if (info.supported && !info.fixesApplied) {
        return typeIsClean();
    }
    
    self.scan.scanLocation = start;
    return @"?";
}

- (NSUInteger)cleanedReplacingOffset {
    return self.scan.string.length - self.cleaned.length;
}

@end
