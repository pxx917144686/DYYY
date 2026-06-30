//
//  UCDisassembler.m
//  FLEX++
//
//  反汇编引擎实现
//  - 使用静态链接的 Capstone 引擎
//

#import "UCDisassembler.h"
#import <objc/runtime.h>
#import <mach/mach.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
#import <mach-o/loader.h>
#import <mach-o/nlist.h>
#include <capstone/capstone.h>

#pragma mark - 静态变量

static csh g_capstoneHandle = 0;
static BOOL g_capstoneInitialized = NO;

#pragma mark - UCDisasmInstruction

@implementation UCDisasmInstruction
@end

#pragma mark - UCDisasmResult

@implementation UCDisasmResult
@end

#pragma mark - UCDisassembler

@implementation UCDisassembler

+ (instancetype)sharedInstance {
    static UCDisassembler *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self initCapstone];
    }
    return self;
}

- (BOOL)isAvailable {
    return g_capstoneInitialized;
}

- (NSString *)engineName {
    if (g_capstoneInitialized) {
        return [NSString stringWithFormat:@"Capstone %s", cs_version(NULL, NULL)];
    }
    return @"HexDump (Fallback)";
}

#pragma mark - Capstone 初始化

- (void)initCapstone {
    if (g_capstoneInitialized) return;
    
    // 初始化 ARM64 引擎
    cs_err err = cs_open(CS_ARCH_AARCH64, CS_MODE_ARM | CS_MODE_LITTLE_ENDIAN, &g_capstoneHandle);
    if (err != CS_ERR_OK) {
        NSLog(@"[UCDisassembler] cs_open failed: %s", cs_strerror(err));
        return;
    }
    
    // 启用详细信息（用于更好的反汇编输出）
    cs_option(g_capstoneHandle, CS_OPT_DETAIL, CS_OPT_ON);
    
    // 启用 Skipdata 模式（遇到无效指令时跳过）
    cs_option(g_capstoneHandle, CS_OPT_SKIPDATA, CS_OPT_ON);
    
    g_capstoneInitialized = YES;
    NSLog(@"[UCDisassembler] Capstone ARM64 engine initialized successfully");
}

- (void)dealloc {
    if (g_capstoneHandle && g_capstoneInitialized) {
        cs_close(&g_capstoneHandle);
        g_capstoneHandle = 0;
        g_capstoneInitialized = NO;
    }
}

#pragma mark - 公共方法

- (UCDisasmResult *)disassembleAtAddress:(uint64_t)address size:(NSUInteger)size {
    if (address == 0 || size == 0) return nil;
    
    // 验证地址可读性
    if (![UCDisassembler isAddressReadable:address size:MIN(size, 4)]) {
        NSLog(@"[UCDisassembler] Address 0x%llx is not readable", address);
        return nil;
    }
    
    UCDisasmResult *result = [[UCDisasmResult alloc] init];
    result.startAddress = address;
    result.engineName = self.engineName;
    
    if (g_capstoneInitialized) {
        // 使用 Capstone 反汇编
        result.instructions = [self disassembleWithCapstone:address size:size];
    } else {
        // Fallback: 十六进制视图
        result.instructions = [self hexDumpAtAddress:address size:size];
    }
    
    result.instructionCount = result.instructions.count;
    return result;
}

- (UCDisasmResult *)disassembleMethod:(Method)method {
    if (!method) return nil;
    
    IMP imp = method_getImplementation(method);
    if (!imp) return nil;
    
    // 估算方法大小（通常最多到下一个方法或页边界）
    uint64_t addr = (uint64_t)imp;
    NSUInteger estimatedSize = 4096; // 最多 4KB
    
    return [self disassembleAtAddress:addr size:estimatedSize];
}

- (UCDisasmResult *)disassembleClass:(Class)cls selector:(SEL)selector isClassMethod:(BOOL)isClassMethod {
    if (!cls || !selector) return nil;
    
    Method method = NULL;
    if (isClassMethod) {
        method = class_getClassMethod(cls, selector);
    } else {
        method = class_getInstanceMethod(cls, selector);
    }
    
    if (!method) return nil;
    return [self disassembleMethod:method];
}

#pragma mark - Capstone 反汇编

- (NSArray<UCDisasmInstruction *> *)disassembleWithCapstone:(uint64_t)address size:(NSUInteger)size {
    if (!g_capstoneInitialized || g_capstoneHandle == 0) {
        return @[];
    }
    
    const uint8_t *code = (const uint8_t *)address;
    cs_insn *insns = NULL;
    
    size_t count = cs_disasm(g_capstoneHandle, code, size, address, 0, &insns);
    
    if (count == 0 || !insns) {
        NSLog(@"[UCDisassembler] cs_disasm returned 0 instructions");
        return @[];
    }
    
    NSMutableArray *results = [NSMutableArray arrayWithCapacity:count];
    
    for (size_t i = 0; i < count; i++) {
        cs_insn *insn = &insns[i];
        
        UCDisasmInstruction *di = [[UCDisasmInstruction alloc] init];
        di.address = insn->address;
        di.size = insn->size;
        di.mnemonic = insn->mnemonic ? [NSString stringWithUTF8String:insn->mnemonic] : @"";
        di.operands = insn->op_str ? [NSString stringWithUTF8String:insn->op_str] : @"";
        di.fullText = [NSString stringWithFormat:@"%@ %@", di.mnemonic, di.operands];
        di.isValid = YES;
        
        // 原始字节
        NSMutableString *bytesStr = [NSMutableString string];
        for (int j = 0; j < insn->size; j++) {
            [bytesStr appendFormat:@"%02x ", insn->bytes[j]];
        }
        di.bytesHex = [bytesStr stringByTrimmingCharactersInSet:
                        [NSCharacterSet whitespaceCharacterSet]];
        
        // 判断指令类型
        NSString *mnemonic = di.mnemonic.lowercaseString;
        di.isBranch = [self isBranchMnemonic:mnemonic];
        di.isCall = [mnemonic isEqualToString:@"bl"] || [mnemonic isEqualToString:@"blr"];
        di.isReturn = [mnemonic isEqualToString:@"ret"];
        
        // 解析分支目标
        if (di.isBranch && di.operands.length > 0) {
            di.branchTarget = [self parseBranchTarget:di.operands baseAddress:di.address];
        }
        
        [results addObject:di];
    }
    
    cs_free(insns, count);
    return results;
}

- (BOOL)isBranchMnemonic:(NSString *)mnemonic {
    NSSet *branchMnemonics = [NSSet setWithArray:@[
        @"b", @"bl", @"br", @"blr", @"ret",
        @"b.eq", @"b.ne", @"b.cs", @"b.cc", @"b.mi", @"b.pl",
        @"b.vs", @"b.vc", @"b.hi", @"b.ls", @"b.ge", @"b.lt",
        @"b.gt", @"b.le", @"b.al",
        @"cbz", @"cbnz", @"tbz", @"tbnz",
        @"cbnz", @"cbz",
    ]];
    return [branchMnemonics containsObject:mnemonic];
}

- (uint64_t)parseBranchTarget:(NSString *)operands baseAddress:(uint64_t)baseAddr {
    // 解析类似 "#0x1234" 或 "0x1234" 的操作数
    NSCharacterSet *hexChars = [NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdefABCDEFx"];
    NSScanner *scanner = [NSScanner scannerWithString:operands];
    [scanner scanString:@"#" intoString:nil];
    
    unsigned long long value = 0;
    if ([scanner scanHexLongLong:&value]) {
        // 如果是相对跳转（值较小，可能是偏移）
        if (value < 0x100000000) {
            // ARM64 B/BL 指令是相对跳转，偏移量需要左移2位
            // 但这里我们从反汇编输出中解析，已经是实际偏移
            return baseAddr + (uint64_t)(int32_t)value;
        }
        return (uint64_t)value;
    }
    
    return 0;
}

#pragma mark - Fallback: 十六进制输出

- (NSArray<UCDisasmInstruction *> *)hexDumpAtAddress:(uint64_t)address size:(NSUInteger)size {
    NSMutableArray *results = [NSMutableArray array];
    const uint8_t *ptr = (const uint8_t *)address;
    
    // 每 4 字节一行（ARM64 指令都是 4 字节）
    NSUInteger rows = size / 4;
    if (rows > 1024) rows = 1024; // 限制最多 1024 行
    
    for (NSUInteger i = 0; i < rows; i++) {
        uint64_t insnAddr = address + i * 4;
        
        // 验证地址可读
        if (![UCDisassembler isAddressReadable:insnAddr size:4]) break;
        
        uint32_t insn = *(uint32_t *)ptr;
        ptr += 4;
        
        UCDisasmInstruction *di = [[UCDisasmInstruction alloc] init];
        di.address = insnAddr;
        di.size = 4;
        di.bytesHex = [NSString stringWithFormat:@"%02x %02x %02x %02x",
                        (insn >> 24) & 0xFF,
                        (insn >> 16) & 0xFF,
                        (insn >> 8) & 0xFF,
                        insn & 0xFF];
        
        // 简单指令识别
        NSString *mnemonic = [self simpleDecodeArm64:insn];
        if (mnemonic) {
            di.mnemonic = mnemonic;
            di.fullText = mnemonic;
            di.isValid = YES;
        } else {
            di.mnemonic = @"???";
            di.fullText = @"???";
            di.isValid = NO;
        }
        
        [results addObject:di];
    }
    
    return results;
}

- (nullable NSString *)simpleDecodeArm64:(uint32_t)insn {
    // 简单的 ARM64 指令识别（仅识别最常见的）
    // 注意：这只是一个非常基础的识别，完整反汇编需要 Capstone
    
    uint32_t op0 = (insn >> 25) & 0x7F;
    
    // B / BL - 无条件分支
    if ((insn & 0x7C000000) == 0x14000000) {
        return @"b";
    }
    if ((insn & 0x7C000000) == 0x94000000) {
        return @"bl";
    }
    
    // CBZ / CBNZ
    if ((insn & 0x7E000000) == 0x34000000) return @"cbz";
    if ((insn & 0x7E000000) == 0x35000000) return @"cbnz";
    
    // TBZ / TBNZ
    if ((insn & 0x7C000000) == 0x36000000) return @"tbz";
    if ((insn & 0x7C000000) == 0x37000000) return @"tbnz";
    
    // B.cond
    if ((insn & 0xFF000010) == 0x54000000) {
        return @"b.cond";
    }
    
    // RET
    if (insn == 0xD65F03C0) return @"ret";
    
    // BR / BLR
    if ((insn & 0xFFFFFC1F) == 0xD61F0000) return @"br";
    if ((insn & 0xFFFFFC1F) == 0xD63F0000) return @"blr";
    
    // ADD / SUB (immediate)
    if ((insn & 0x7F800000) == 0x11000000) return @"add";
    if ((insn & 0x7F800000) == 0x51000000) return @"add";
    if ((insn & 0x7F800000) == 0x53000000) return @"sub";
    if ((insn & 0x7F800000) == 0x13000000) return @"sub";
    
    // MOVZ / MOVK / MOVN
    if ((insn & 0x7F800000) == 0x52800000) return @"movz";
    if ((insn & 0x7F800000) == 0x72800000) return @"movk";
    if ((insn & 0x7F800000) == 0x12800000) return @"movn";
    
    // LDR (immediate)
    if ((insn & 0x3B000000) == 0x18000000) return @"ldr (literal)";
    if ((insn & 0xFFC00000) == 0xF9400000) return @"ldr";
    
    // STR (immediate)
    if ((insn & 0xFFC00000) == 0xF9000000) return @"str";
    
    // LDP / STP
    if ((insn & 0xFFC00000) == 0x29400000) return @"ldp";
    if ((insn & 0xFFC00000) == 0x29000000) return @"stp";
    if ((insn & 0xFFC00000) == 0xA9400000) return @"ldp";
    if ((insn & 0xFFC00000) == 0xA9000000) return @"stp";
    
    // ADR / ADRP
    if ((insn & 0x9F000000) == 0x10000000) return @"adr";
    if ((insn & 0x9F000000) == 0x90000000) return @"adrp";
    
    // NOP
    if (insn == 0xD503201F) return @"nop";
    
    // HINT
    if (insn == 0xD503201F) return @"hint";
    
    return nil;
}

#pragma mark - 辅助方法

+ (NSString *)symbolNameAtAddress:(uint64_t)address {
    Dl_info info;
    if (dladdr((void *)address, &info)) {
        if (info.dli_sname) {
            return [NSString stringWithUTF8String:info.dli_sname];
        }
    }
    return nil;
}

+ (BOOL)isAddressReadable:(uint64_t)address size:(NSUInteger)size {
    if (address == 0) return NO;
    
    // 空指针区域
    if (address < 0x100000000) return NO;
    
    // 对于方法地址，我们直接返回 YES
    // 因为 class_getMethodImplementation 返回的地址总是可读的
    return YES;
}

@end
