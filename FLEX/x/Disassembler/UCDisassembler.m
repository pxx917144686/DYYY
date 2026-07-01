#import "UCDisassembler.h"
#import <objc/runtime.h>
#import <mach/mach.h>
#import <dlfcn.h>
#include <capstone/capstone.h>
#include <capstone/aarch64.h>

#pragma mark - 静态变量

static csh g_capstoneHandle = 0;
static BOOL g_capstoneInitialized = NO;
static dispatch_queue_t g_disasmQueue = NULL;

#pragma mark - 实现

@implementation UCDisasmOperand
@end

@implementation UCDisasmInstruction
@end

@implementation UCDisasmResult
@end

@implementation UCBasicBlock
- (instancetype)init {
    self = [super init];
    if (self) {
        _successors = [NSMutableArray array];
        _predecessors = [NSMutableArray array];
    }
    return self;
}
// 打破 successors/predecessors 互相强引用导致的 retain cycle
- (void)dealloc {
    _successors = nil;
    _predecessors = nil;
}
@end

@implementation UCFunction
// 释放时清空 basicBlocks，间接触发 UCBasicBlock dealloc 打破循环
- (void)dealloc {
    for (UCBasicBlock *block in self.basicBlocks) {
        block.successors = nil;
        block.predecessors = nil;
    }
    self.basicBlocks = nil;
}
@end

@implementation UCSymbolInfo
+ (instancetype)infoWithAddress:(uint64_t)address name:(NSString *)name type:(NSString *)type {
    UCSymbolInfo *info = [[UCSymbolInfo alloc] init];
    info.address = address;
    info.name = name;
    info.type = type;
    return info;
}
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
        return [NSString stringWithFormat:@"Capstone %d (Pro)", cs_version(NULL, NULL)];
    }
    return @"HexDump (Fallback)";
}

#pragma mark - Capstone 初始化

- (void)initCapstone {
    if (g_capstoneInitialized) return;
    
    cs_err err = cs_open(CS_ARCH_AARCH64, CS_MODE_LITTLE_ENDIAN, &g_capstoneHandle);
    if (err != CS_ERR_OK) {
        NSLog(@"[UCDisassembler] cs_open failed: %s", cs_strerror(err));
        return;
    }
    
    cs_err err2 = cs_option(g_capstoneHandle, CS_OPT_DETAIL, CS_OPT_ON);
    if (err2 != CS_ERR_OK) {
        NSLog(@"[UCDisassembler] cs_option DETAIL failed: %s", cs_strerror(err2));
    }
    
    cs_err err3 = cs_option(g_capstoneHandle, CS_OPT_SKIPDATA, CS_OPT_ON);
    if (err3 != CS_ERR_OK) {
        NSLog(@"[UCDisassembler] cs_option SKIPDATA failed: %s", cs_strerror(err3));
    }
    
    g_disasmQueue = dispatch_queue_create("com.ucdisassembler.queue", DISPATCH_QUEUE_SERIAL);
    
    g_capstoneInitialized = YES;
    NSLog(@"[UCDisassembler] Capstone AArch64 engine initialized (Pro mode)");
}

- (void)dealloc {
    // 全局句柄由单例管理，非单例实例释放时不关闭
    // 避免 [[UCDisassembler alloc] init] 释放后影响 sharedInstance
}

#pragma mark - 公共反汇编方法

- (UCDisasmResult *)disassembleAtAddress:(uint64_t)address size:(NSUInteger)size {
    if (address == 0 || size == 0) return nil;
    
    if (![UCDisassembler isAddressReadable:address size:MIN(size, 4)]) {
        return nil;
    }
    
    UCDisasmResult *result = [[UCDisasmResult alloc] init];
    result.startAddress = address;
    result.engineName = self.engineName;
    
    if (g_capstoneInitialized) {
        result.instructions = [self disassembleWithCapstone:address size:size];
    } else {
        result.instructions = [self hexDumpAtAddress:address size:size];
    }
    
    result.instructionCount = result.instructions.count;
    
    if (result.instructions.count > 0) {
        NSMutableDictionary *addrMap = [NSMutableDictionary dictionaryWithCapacity:result.instructions.count];
        for (UCDisasmInstruction *insn in result.instructions) {
            addrMap[@(insn.address)] = insn;
        }
        result.addressMap = addrMap;
        
        [self analyzeAndAnnotateResult:result];
    }
    
    return result;
}

- (UCDisasmResult *)disassembleMethod:(Method)method {
    if (!method) return nil;

    IMP imp = method_getImplementation(method);
    if (!imp) return nil;

    uint64_t addr = (uint64_t)imp;

    UCFunction *func = [self analyzeFunctionAtAddress:addr maxSize:65536];

    // 复用 analyzeFunctionAtAddress 已产生的反汇编结果，避免重复反汇编
    UCDisasmResult *result = [[UCDisasmResult alloc] init];
    result.startAddress = addr;
    result.engineName = self.engineName;

    if (func && func.instructions.count > 0) {
        result.instructions = func.instructions;
        result.instructionCount = func.instructions.count;

        NSMutableDictionary *addrMap = [NSMutableDictionary dictionaryWithCapacity:func.instructions.count];
        for (UCDisasmInstruction *insn in func.instructions) {
            addrMap[@(insn.address)] = insn;
        }
        result.addressMap = addrMap;

        [self analyzeAndAnnotateResult:result];
        result.functions = @[func];
    } else {
        // 回退：分析失败时直接反汇编
        NSUInteger actualSize = func ? func.size : 4096;
        UCDisasmResult *fallback = [self disassembleAtAddress:addr size:actualSize];
        if (fallback) {
            result.instructions = fallback.instructions;
            result.instructionCount = fallback.instructionCount;
            result.addressMap = fallback.addressMap;
        }
        if (func) {
            result.functions = @[func];
        }
    }

    return result;
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

#pragma mark - Capstone 反汇编核心

- (NSArray<UCDisasmInstruction *> *)disassembleWithCapstone:(uint64_t)address size:(NSUInteger)size {
    if (!g_capstoneInitialized || g_capstoneHandle == 0) {
        return @[];
    }
    
    if (address == 0 || size == 0) return @[];
    
    if (size > 1048576) size = 1048576;
    
    if (![UCDisassembler isAddressReadable:address size:MIN(size, 4096)]) {
        return @[];
    }
    
    const uint8_t *code = (const uint8_t *)address;
    __block cs_insn *insns = NULL;

    __block size_t count = 0;
    if (g_disasmQueue) {
        dispatch_sync(g_disasmQueue, ^{
            count = cs_disasm(g_capstoneHandle, code, size, address, 0, &insns);
        });
    } else {
        count = cs_disasm(g_capstoneHandle, code, size, address, 0, &insns);
    }
    
    if (count == 0 || !insns) {
        return @[];
    }
    
    NSMutableArray *results = [NSMutableArray arrayWithCapacity:count];
    
    for (size_t i = 0; i < count; i++) {
        cs_insn *insn = &insns[i];
        
        UCDisasmInstruction *di = [[UCDisasmInstruction alloc] init];
        di.address = insn->address;
        di.size = insn->size;
        di.mnemonic = [NSString stringWithUTF8String:insn->mnemonic];
        di.operands = [NSString stringWithUTF8String:insn->op_str];
        di.fullText = [NSString stringWithFormat:@"%@ %@", di.mnemonic, di.operands];
        di.isValid = YES;
        
        NSMutableString *bytesStr = [NSMutableString string];
        int bytesLen = insn->size;
        if (bytesLen > (int)sizeof(insn->bytes)) {
            bytesLen = (int)sizeof(insn->bytes);
        }
        for (int j = 0; j < bytesLen; j++) {
            [bytesStr appendFormat:@"%02x ", insn->bytes[j]];
        }
        di.bytesHex = [bytesStr stringByTrimmingCharactersInSet:
                        [NSCharacterSet whitespaceCharacterSet]];
        
        di.operandList = [self parseOperands:insn];
        [self classifyInstruction:di];
        
        [results addObject:di];
    }
    
    cs_free(insns, count);
    return results;
}

- (NSArray<UCDisasmOperand *> *)parseOperands:(cs_insn *)insn {
    NSMutableArray *operands = [NSMutableArray array];
    
    if (!insn->detail) return operands;
    
    cs_aarch64 *arm64 = &(insn->detail->aarch64);
    
    for (int i = 0; i < arm64->op_count; i++) {
        cs_aarch64_op *op = &(arm64->operands[i]);
        UCDisasmOperand *operand = [[UCDisasmOperand alloc] init];
        
        switch (op->type) {
            case AARCH64_OP_REG: {
                operand.type = UCDisasmOperandTypeRegister;
                const char *regName = cs_reg_name(g_capstoneHandle, op->reg);
                operand.registerName = regName ? [NSString stringWithUTF8String:regName] : @"?";
                operand.text = operand.registerName;
                break;
            }
            case AARCH64_OP_IMM:
                operand.type = UCDisasmOperandTypeImmediate;
                operand.immediateValue = (uint64_t)op->imm;
                if (op->imm < 0) {
                    operand.text = [NSString stringWithFormat:@"#-0x%llx", (unsigned long long)(-op->imm)];
                } else {
                    operand.text = [NSString stringWithFormat:@"#0x%llx", (unsigned long long)op->imm];
                }
                break;
            case AARCH64_OP_MEM: {
                operand.type = UCDisasmOperandTypeMemory;
                const char *baseName = cs_reg_name(g_capstoneHandle, op->mem.base);
                operand.memoryBaseReg = baseName ? [NSString stringWithUTF8String:baseName] : @"?";
                operand.memoryOffset = op->mem.disp;
                if (op->mem.index != AARCH64_REG_INVALID) {
                    const char *idxName = cs_reg_name(g_capstoneHandle, op->mem.index);
                    operand.memoryIndexReg = idxName ? [NSString stringWithUTF8String:idxName] : @"?";
                }
                if (operand.memoryIndexReg) {
                    operand.text = [NSString stringWithFormat:@"[%@, %@]",
                                     operand.memoryBaseReg, operand.memoryIndexReg];
                } else if (operand.memoryOffset != 0) {
                    operand.text = [NSString stringWithFormat:@"[%@, #%lld]",
                                     operand.memoryBaseReg, (long long)operand.memoryOffset];
                } else {
                    operand.text = [NSString stringWithFormat:@"[%@]", operand.memoryBaseReg];
                }
                break;
            }
            case AARCH64_OP_FP:
                operand.type = UCDisasmOperandTypeFPRegister;
                operand.text = [NSString stringWithFormat:@"#%g", op->fp];
                break;
            default:
                operand.type = UCDisasmOperandTypeUnknown;
                operand.text = @"?";
                break;
        }
        
        [operands addObject:operand];
    }
    
    return operands;
}

- (void)classifyInstruction:(UCDisasmInstruction *)di {
    NSString *mnemonic = di.mnemonic.lowercaseString;
    
    di.isNop = [mnemonic isEqualToString:@"nop"] || [mnemonic isEqualToString:@"hint"];
    
    NSArray *condSuffixes = @[@".eq", @".ne", @".cs", @".cc", @".mi", @".pl",
                              @".vs", @".vc", @".hi", @".ls", @".ge", @".lt",
                              @".gt", @".le", @".al", @".nv"];
    
    if ([mnemonic isEqualToString:@"ret"]) {
        di.isReturn = YES;
        di.isBranch = YES;
        di.isUnconditionalBranch = YES;
        di.branchTarget = 0;
        return;
    }
    
    if ([mnemonic isEqualToString:@"bl"] || [mnemonic isEqualToString:@"blr"]) {
        di.isCall = YES;
        di.isBranch = YES;
        di.isUnconditionalBranch = YES;
    }
    
    if ([mnemonic isEqualToString:@"b"] || [mnemonic isEqualToString:@"br"]) {
        di.isBranch = YES;
        di.isUnconditionalBranch = YES;
    }
    
    for (NSString *suffix in condSuffixes) {
        if ([mnemonic hasSuffix:suffix]) {
            NSString *base = [mnemonic substringToIndex:mnemonic.length - suffix.length];
            if ([base isEqualToString:@"b"]) {
                di.isBranch = YES;
                di.isConditionalBranch = YES;
            }
            break;
        }
    }
    
    if ([mnemonic isEqualToString:@"cbz"] || [mnemonic isEqualToString:@"cbnz"] ||
        [mnemonic isEqualToString:@"tbz"] || [mnemonic isEqualToString:@"tbnz"]) {
        di.isBranch = YES;
        di.isConditionalBranch = YES;
    }
    
    if (di.isBranch && di.operandList.count > 0) {
        UCDisasmOperand *targetOp = di.operandList.lastObject;
        if (targetOp.type == UCDisasmOperandTypeImmediate) {
            di.branchTarget = targetOp.immediateValue;
        }
    }
    
    if (([mnemonic isEqualToString:@"stp"] || [mnemonic isEqualToString:@"stur"]) &&
        di.operandList.count >= 2) {
        UCDisasmOperand *op0 = di.operandList[0];
        if (op0.type == UCDisasmOperandTypeRegister &&
            ([op0.registerName isEqualToString:@"x29"] || [op0.registerName isEqualToString:@"fp"])) {
            di.setsFramePointer = YES;
        }
    }
}

#pragma mark - Hex Dump Fallback

- (NSArray<UCDisasmInstruction *> *)hexDumpAtAddress:(uint64_t)address size:(NSUInteger)size {
    NSMutableArray *results = [NSMutableArray array];
    const uint8_t *ptr = (const uint8_t *)address;
    
    NSUInteger rows = size / 4;
    if (rows > 1024) rows = 1024;
    
    for (NSUInteger i = 0; i < rows; i++) {
        uint64_t insnAddr = address + i * 4;
        
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
    if ((insn & 0x7C000000) == 0x14000000) return @"b";
    if ((insn & 0x7C000000) == 0x94000000) return @"bl";
    if ((insn & 0x7E000000) == 0x34000000) return @"cbz";
    if ((insn & 0x7E000000) == 0x35000000) return @"cbnz";
    if ((insn & 0x7C000000) == 0x36000000) return @"tbz";
    if ((insn & 0x7C000000) == 0x37000000) return @"tbnz";
    if ((insn & 0xFF000010) == 0x54000000) return @"b.cond";
    if (insn == 0xD65F03C0) return @"ret";
    if ((insn & 0xFFFFFC1F) == 0xD61F0000) return @"br";
    if ((insn & 0xFFFFFC1F) == 0xD63F0000) return @"blr";
    return nil;
}

#pragma mark - 函数分析

- (nullable UCFunction *)analyzeFunctionAtAddress:(uint64_t)address maxSize:(NSUInteger)maxSize {
    if (address == 0 || maxSize == 0) return nil;
    
    NSArray<UCDisasmInstruction *> *insns = [self disassembleWithCapstone:address size:maxSize];
    if (insns.count == 0) return nil;
    
    uint64_t funcStart = address;
    uint64_t funcEnd = 0;
    BOOL foundEnd = NO;
    
    for (NSUInteger i = 0; i < insns.count; i++) {
        UCDisasmInstruction *insn = insns[i];
        
        if (insn.isReturn) {
            funcEnd = insn.address + insn.size;
            foundEnd = YES;
            
            if (i + 1 < insns.count) {
                UCDisasmInstruction *next = insns[i + 1];
                if (next.setsFramePointer || [next.mnemonic.lowercaseString isEqualToString:@"stp"]) {
                    if (next.operandList.count >= 1) {
                        UCDisasmOperand *op = next.operandList[0];
                        if (op.type == UCDisasmOperandTypeRegister &&
                            ([op.registerName isEqualToString:@"x29"] || [op.registerName isEqualToString:@"fp"])) {
                            break;
                        }
                    }
                }
            }
        }
        
        if (foundEnd && i > 0) {
            UCDisasmInstruction *prev = insns[i - 1];
            if (prev.isUnconditionalBranch && !prev.isCall && !prev.isReturn) {
                uint64_t target = prev.branchTarget;
                if (target >= funcStart && target < (funcStart + maxSize)) {
                    uint64_t maxEnd = MAX(funcEnd, target);
                    if (maxEnd > funcEnd + 256) {
                        break;
                    }
                }
            }
        }
    }
    
    if (!foundEnd) {
        funcEnd = address + MIN(maxSize, (NSUInteger)4096);
    }
    
    if (funcEnd < funcStart) {
        funcEnd = funcStart + 4;
    }
    
    NSUInteger funcSize = (NSUInteger)(funcEnd - funcStart);
    if (funcSize > maxSize) {
        funcSize = maxSize;
    }
    NSArray *funcInsns = [self disassembleWithCapstone:funcStart size:funcSize];
    
    UCFunction *func = [[UCFunction alloc] init];
    func.startAddress = funcStart;
    func.endAddress = funcEnd;
    func.size = funcSize;
    func.name = [UCDisassembler symbolNameAtAddress:funcStart] ?:
                [NSString stringWithFormat:@"sub_%llx", funcStart];
    func.instructions = funcInsns;
    
    func.basicBlocks = [self buildCFG:funcInsns];
    func.basicBlockCount = func.basicBlocks.count;
    
    return func;
}

#pragma mark - CFG 构建

- (nullable NSArray<UCBasicBlock *> *)buildCFG:(NSArray<UCDisasmInstruction *> *)instructions {
    if (instructions.count == 0) return nil;
    
    NSMutableDictionary<NSNumber *, UCDisasmInstruction *> *addrMap = [NSMutableDictionary dictionary];
    NSMutableSet<NSNumber *> *blockStarts = [NSMutableSet set];

    for (UCDisasmInstruction *insn in instructions) {
        addrMap[@(insn.address)] = insn;
    }

    [blockStarts addObject:@(instructions.firstObject.address)];

    for (UCDisasmInstruction *insn in instructions) {
        if (insn.isBranch) {
            if (insn.branchTarget > 0) {
                [blockStarts addObject:@(insn.branchTarget)];
            }
            
            NSUInteger idx = [instructions indexOfObject:insn];
            if (idx < instructions.count - 1) {
                UCDisasmInstruction *next = instructions[idx + 1];
                [blockStarts addObject:@(next.address)];
            }
        }
    }
    
    NSArray *sortedStarts = [[blockStarts allObjects] sortedArrayUsingSelector:@selector(compare:)];
    
    NSMutableArray<UCBasicBlock *> *blocks = [NSMutableArray array];
    NSMutableDictionary<NSNumber *, UCBasicBlock *> *blockMap = [NSMutableDictionary dictionary];
    
    for (NSUInteger i = 0; i < sortedStarts.count; i++) {
        uint64_t startAddr = [sortedStarts[i] unsignedLongLongValue];
        UCDisasmInstruction *startInsn = addrMap[@(startAddr)];
        if (!startInsn) continue;
        
        NSUInteger startIdx = [instructions indexOfObject:startInsn];
        if (startIdx == NSNotFound) continue;
        
        UCBasicBlock *block = [[UCBasicBlock alloc] init];
        block.startAddress = startAddr;
        block.blockId = i;
        
        NSMutableArray *blockInsns = [NSMutableArray array];
        
        for (NSUInteger j = startIdx; j < instructions.count; j++) {
            UCDisasmInstruction *insn = instructions[j];
            insn.isBasicBlockStart = (j == startIdx);
            insn.basicBlock = block;
            [blockInsns addObject:insn];
            
            if (insn.isBranch || j == instructions.count - 1) {
                block.endAddress = insn.address + insn.size;
                break;
            }
            
            if (j + 1 < instructions.count) {
                UCDisasmInstruction *next = instructions[j + 1];
                if ([blockStarts containsObject:@(next.address)]) {
                    block.endAddress = insn.address + insn.size;
                    break;
                }
            }
        }
        
        block.instructions = blockInsns;
        block.instructionCount = blockInsns.count;
        
        [blocks addObject:block];
        blockMap[@(block.startAddress)] = block;
    }
    
    for (UCBasicBlock *block in blocks) {
        UCDisasmInstruction *lastInsn = block.instructions.lastObject;
        
        if (lastInsn.isConditionalBranch && lastInsn.branchTarget > 0) {
            UCBasicBlock *targetBlock = blockMap[@(lastInsn.branchTarget)];
            if (targetBlock) {
                [block.successors addObject:targetBlock];
                [targetBlock.predecessors addObject:block];
                targetBlock.type = UCBasicBlockTypeConditionalTrue;
            }

            NSUInteger idx = [instructions indexOfObject:lastInsn];
            if (idx < instructions.count - 1) {
                UCDisasmInstruction *next = instructions[idx + 1];
                UCBasicBlock *fallthrough = blockMap[@(next.address)];
                // 去重：true 目标和 fall-through 相同时不重复添加
                if (fallthrough && fallthrough != targetBlock) {
                    [block.successors addObject:fallthrough];
                    [fallthrough.predecessors addObject:block];
                    fallthrough.type = UCBasicBlockTypeConditionalFalse;
                }
            }
        } else if (lastInsn.isUnconditionalBranch && !lastInsn.isReturn && !lastInsn.isCall) {
            if (lastInsn.branchTarget > 0) {
                UCBasicBlock *targetBlock = blockMap[@(lastInsn.branchTarget)];
                if (targetBlock) {
                    [block.successors addObject:targetBlock];
                    [targetBlock.predecessors addObject:block];
                }
            }
        } else if (!lastInsn.isReturn) {
            NSUInteger idx = [instructions indexOfObject:lastInsn];
            if (idx < instructions.count - 1) {
                UCDisasmInstruction *next = instructions[idx + 1];
                UCBasicBlock *fallthrough = blockMap[@(next.address)];
                if (fallthrough) {
                    [block.successors addObject:fallthrough];
                    [fallthrough.predecessors addObject:block];
                }
            }
        }
        
        if (block.predecessors.count == 0 && block.blockId == 0) {
            block.type = UCBasicBlockTypeEntry;
        }
        if (lastInsn.isReturn) {
            block.type = UCBasicBlockTypeExit;
        }
    }
    
    return blocks;
}

#pragma mark - 函数扫描

- (nullable NSArray<UCFunction *> *)scanFunctionsInRange:(uint64_t)start size:(NSUInteger)size {
    if (start == 0 || size == 0) return nil;
    
    NSMutableArray<UCFunction *> *functions = [NSMutableArray array];
    NSMutableSet<NSNumber *> *seenAddresses = [NSMutableSet set];
    
    uint64_t addr = start;
    uint64_t end = start + size;
    
    while (addr < end) {
        if (![UCDisassembler isAddressReadable:addr size:4]) break;
        
        uint32_t insn = *(uint32_t *)addr;
        
        BOOL isPrologue = NO;
        
        if ((insn & 0xFFC003E0) == 0xA98003E0) {
            uint32_t rt = insn & 0x1F;
            uint32_t rt2 = (insn >> 10) & 0x1F;
            if (rt == 29 && rt2 == 30) {
                isPrologue = YES;
            }
        }
        
        if (isPrologue && ![seenAddresses containsObject:@(addr)]) {
            UCFunction *func = [self analyzeFunctionAtAddress:addr maxSize:65536];
            if (func) {
                func.name = [UCDisassembler symbolNameAtAddress:addr] ?:
                            [NSString stringWithFormat:@"sub_%llx", addr];
                [functions addObject:func];
                [seenAddresses addObject:@(addr)];
                
                addr = func.endAddress;
                continue;
            }
        }
        
        addr += 4;
    }
    
    return functions;
}

#pragma mark - 结果注解

- (void)analyzeAndAnnotateResult:(UCDisasmResult *)result {
    if (result.instructions.count == 0) return;
    
    NSMutableDictionary<NSNumber *, NSMutableArray<NSNumber *> *> *xrefMap = [NSMutableDictionary dictionary];
    
    for (UCDisasmInstruction *insn in result.instructions) {
        NSMutableArray *xrefs = [NSMutableArray array];
        
        if (insn.isBranch && insn.branchTarget > 0) {
            NSNumber *targetAddr = @(insn.branchTarget);
            if (!xrefMap[targetAddr]) {
                xrefMap[targetAddr] = [NSMutableArray array];
            }
            [xrefMap[targetAddr] addObject:@(insn.address)];
        }
        
        if (insn.isCall) {
            NSString *targetName = nil;
            if (insn.branchTarget > 0) {
                targetName = [UCDisassembler symbolNameAtAddress:insn.branchTarget];
                if (!targetName) {
                    targetName = [UCDisassembler objcMethodNameAtAddress:insn.branchTarget];
                }
                if (targetName) {
                    insn.comment = [NSString stringWithFormat:@"%@", targetName];
                }
            }
        }
        
        NSString *refString = [self findStringReference:insn];
        if (refString) {
            if (insn.comment) {
                insn.comment = [NSString stringWithFormat:@"%@ ; \"%@\"", insn.comment, refString];
            } else {
                insn.comment = [NSString stringWithFormat:@"\"%@\"", refString];
            }
        }
        
        NSString *className = [self findObjcClassRef:insn];
        if (className) {
            if (insn.comment) {
                insn.comment = [NSString stringWithFormat:@"%@ ; %@", insn.comment, className];
            } else {
                insn.comment = className;
            }
        }
    }
    
    for (UCDisasmInstruction *insn in result.instructions) {
        NSArray *xrefs = xrefMap[@(insn.address)];
        if (xrefs.count > 0) {
            insn.xrefFrom = xrefs;
            if (xrefs.count == 1) {
                insn.xrefComment = [NSString stringWithFormat:@"; XREF: 0x%llx",
                                     [xrefs.firstObject unsignedLongLongValue]];
            } else {
                insn.xrefComment = [NSString stringWithFormat:@"; XREF: %lu refs", (unsigned long)xrefs.count];
            }
        }
    }
}

- (nullable NSString *)findStringReference:(UCDisasmInstruction *)insn {
    if (insn.operandList.count < 2) return nil;
    
    NSString *mnemonic = insn.mnemonic.lowercaseString;
    if (![mnemonic isEqualToString:@"adrp"]) return nil;
    
    UCDisasmOperand *op2 = insn.operandList[1];
    if (op2.type != UCDisasmOperandTypeImmediate) return nil;
    
    uint64_t pageBase = (insn.address & ~0xFFFULL) + op2.immediateValue;
    
    __block uint64_t ldrOffset = 0;
    __block BOOL foundLDR = NO;
    
    NSUInteger maxLookAhead = 10;
    
    for (NSInteger i = 1; i <= maxLookAhead; i++) {
        uint64_t nextAddr = insn.address + i * 4;
        if (![UCDisassembler isAddressReadable:nextAddr size:4]) break;
        
        uint32_t nextInsn = *(uint32_t *)nextAddr;
        
        if ((nextInsn & 0x3B000000) == 0x18000000) {
            continue;
        }
        
        if ((nextInsn & 0xFFC00000) == 0xF9400000) {
            uint32_t imm12 = (nextInsn >> 10) & 0xFFF;
            ldrOffset = imm12 * 8;
            foundLDR = YES;
            break;
        }
    }
    
    if (!foundLDR) return nil;
    
    uint64_t strAddr = pageBase + ldrOffset;
    
    return [UCDisassembler stringAtAddress:strAddr maxLength:256];
}

- (nullable NSString *)findObjcClassRef:(UCDisasmInstruction *)insn {
    return nil;
}

#pragma mark - 符号与辅助方法

+ (NSString *)symbolNameAtAddress:(uint64_t)address {
    Dl_info info;
    if (dladdr((void *)address, &info)) {
        if (info.dli_sname) {
            return [NSString stringWithUTF8String:info.dli_sname];
        }
    }
    return nil;
}

+ (UCSymbolInfo *)symbolInfoAtAddress:(uint64_t)address {
    Dl_info info;
    if (dladdr((void *)address, &info)) {
        if (info.dli_sname) {
            NSString *name = [NSString stringWithUTF8String:info.dli_sname];
            NSString *image = info.dli_fname ? [NSString stringWithUTF8String:info.dli_fname].lastPathComponent : nil;
            UCSymbolInfo *sym = [UCSymbolInfo infoWithAddress:address name:name type:@"function"];
            sym.imageName = image;
            return sym;
        }
    }
    return nil;
}

+ (NSString *)objcMethodNameAtAddress:(uint64_t)address {
    return nil;
}

+ (NSString *)stringAtAddress:(uint64_t)address maxLength:(NSUInteger)maxLen {
    if (address == 0 || maxLen == 0) return nil;
    if (![self isAddressReadable:address size:1]) return nil;
    
    const char *ptr = (const char *)address;
    NSMutableString *str = [NSMutableString string];
    
    for (NSUInteger i = 0; i < maxLen; i++) {
        if (![self isAddressReadable:address + i size:1]) break;
        char c = ptr[i];
        if (c == 0) break;
        if (c < 0x20 || c > 0x7E) {
            if (c != '\n' && c != '\t' && c != '\r') {
                return nil;
            }
        }
        [str appendFormat:@"%c", c];
    }
    
    if (str.length == 0) return nil;
    return str;
}

+ (NSString *)objcClassNameFromClassRef:(uint64_t)address {
    return nil;
}

+ (BOOL)isAddressReadable:(uint64_t)address size:(NSUInteger)size {
    if (address == 0 || size == 0) return NO;
    if (address < 0x100000000) return NO;
    
    vm_address_t addr = (vm_address_t)address;
    vm_size_t vmsize = 0;
    vm_region_basic_info_data_64_t info;
    mach_msg_type_number_t count = VM_REGION_BASIC_INFO_COUNT_64;
    mach_port_t object_name = MACH_PORT_NULL;
    
    kern_return_t kr = vm_region_64(mach_task_self(), &addr, &vmsize,
                                     VM_REGION_BASIC_INFO_64,
                                     (vm_region_info_t)&info,
                                     &count, &object_name);
    
    if (kr != KERN_SUCCESS) return NO;
    
    if (object_name != MACH_PORT_NULL) {
        mach_port_deallocate(mach_task_self(), object_name);
    }
    
    if (address < addr) return NO;
    if (address + size > addr + vmsize) return NO;
    
    if (!(info.protection & VM_PROT_READ)) return NO;
    
    return YES;
}

@end
