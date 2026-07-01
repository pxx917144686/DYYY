#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, UCDisasmOperandType) {
    UCDisasmOperandTypeUnknown = 0,
    UCDisasmOperandTypeRegister,
    UCDisasmOperandTypeImmediate,
    UCDisasmOperandTypeMemory,
    UCDisasmOperandTypeFPRegister,
};

typedef NS_ENUM(NSInteger, UCBasicBlockType) {
    UCBasicBlockTypeNormal = 0,
    UCBasicBlockTypeEntry,
    UCBasicBlockTypeExit,
    UCBasicBlockTypeConditionalTrue,
    UCBasicBlockTypeConditionalFalse,
};

@class UCDisasmInstruction;
@class UCBasicBlock;
@class UCFunction;

@interface UCDisasmOperand : NSObject
@property (nonatomic, assign) UCDisasmOperandType type;
@property (nonatomic, copy) NSString *text;
@property (nonatomic, assign) uint64_t immediateValue;
@property (nonatomic, copy) NSString *registerName;
@property (nonatomic, assign) int64_t memoryOffset;
@property (nonatomic, copy) NSString *memoryBaseReg;
@property (nonatomic, copy) NSString *memoryIndexReg;
@property (nonatomic, assign) uint32_t memoryScale;
@end

@interface UCDisasmInstruction : NSObject
@property (nonatomic, assign) uint64_t address;
@property (nonatomic, assign) NSUInteger size;
@property (nonatomic, copy) NSString *mnemonic;
@property (nonatomic, copy) NSString *operands;
@property (nonatomic, copy) NSString *fullText;
@property (nonatomic, copy) NSString *bytesHex;
@property (nonatomic, assign) BOOL isBranch;
@property (nonatomic, assign) BOOL isCall;
@property (nonatomic, assign) BOOL isReturn;
@property (nonatomic, assign) BOOL isConditionalBranch;
@property (nonatomic, assign) BOOL isUnconditionalBranch;
@property (nonatomic, assign) uint64_t branchTarget;
@property (nonatomic, assign) BOOL isValid;
@property (nonatomic, assign) BOOL isNop;
@property (nonatomic, assign) BOOL setsFramePointer;
@property (nonatomic, strong) NSArray<UCDisasmOperand *> *operandList;
@property (nonatomic, copy, nullable) NSString *comment;
@property (nonatomic, copy, nullable) NSString *xrefComment;
@property (nonatomic, strong, nullable) NSArray<NSNumber *> *xrefFrom;
@property (nonatomic, assign) BOOL isFunctionStart;
@property (nonatomic, copy, nullable) NSString *functionName;
@property (nonatomic, assign) BOOL isBasicBlockStart;
@property (nonatomic, weak, nullable) UCBasicBlock *basicBlock;
@end

@interface UCDisasmResult : NSObject
@property (nonatomic, assign) uint64_t startAddress;
@property (nonatomic, assign) NSUInteger instructionCount;
@property (nonatomic, strong) NSArray<UCDisasmInstruction *> *instructions;
@property (nonatomic, copy) NSString *engineName;
@property (nonatomic, strong, nullable) NSArray<UCFunction *> *functions;
@property (nonatomic, strong, nullable) NSDictionary<NSNumber *, UCDisasmInstruction *> *addressMap;
@end

@interface UCBasicBlock : NSObject
@property (nonatomic, assign) uint64_t startAddress;
@property (nonatomic, assign) uint64_t endAddress;
@property (nonatomic, assign) NSUInteger instructionCount;
@property (nonatomic, strong) NSArray<UCDisasmInstruction *> *instructions;
@property (nonatomic, assign) UCBasicBlockType type;
@property (nonatomic, strong, nullable) NSMutableArray<UCBasicBlock *> *successors;
@property (nonatomic, strong, nullable) NSMutableArray<UCBasicBlock *> *predecessors;
@property (nonatomic, weak, nullable) UCFunction *function;
@property (nonatomic, assign) NSInteger blockId;
@property (nonatomic, assign) CGPoint layoutPosition;
@property (nonatomic, assign) CGSize layoutSize;
@end

@interface UCFunction : NSObject
@property (nonatomic, assign) uint64_t startAddress;
@property (nonatomic, assign) uint64_t endAddress;
@property (nonatomic, assign) NSUInteger size;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy, nullable) NSString *demangledName;
@property (nonatomic, strong) NSArray<UCDisasmInstruction *> *instructions;
@property (nonatomic, strong) NSArray<UCBasicBlock *> *basicBlocks;
@property (nonatomic, assign) NSUInteger basicBlockCount;
@property (nonatomic, strong, nullable) NSSet<NSNumber *> *callSites;
@property (nonatomic, strong, nullable) NSSet<NSNumber *> *calledFrom;
@end

@interface UCSymbolInfo : NSObject
@property (nonatomic, assign) uint64_t address;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *type;
@property (nonatomic, copy, nullable) NSString *imageName;
+ (instancetype)infoWithAddress:(uint64_t)address name:(NSString *)name type:(NSString *)type;
@end

@interface UCDisassembler : NSObject

+ (instancetype)sharedInstance;

@property (nonatomic, readonly) BOOL isAvailable;
@property (nonatomic, readonly) NSString *engineName;

- (nullable UCDisasmResult *)disassembleAtAddress:(uint64_t)address
                                             size:(NSUInteger)size;

- (nullable UCDisasmResult *)disassembleMethod:(Method)method;

- (nullable UCDisasmResult *)disassembleClass:(Class)cls
                                     selector:(SEL)selector
                                isClassMethod:(BOOL)isClassMethod;

- (nullable UCFunction *)analyzeFunctionAtAddress:(uint64_t)address
                                        maxSize:(NSUInteger)maxSize;

- (nullable NSArray<UCBasicBlock *> *)buildCFG:(NSArray<UCDisasmInstruction *> *)instructions;

- (nullable NSArray<UCFunction *> *)scanFunctionsInRange:(uint64_t)start
                                                    size:(NSUInteger)size;

+ (nullable NSString *)symbolNameAtAddress:(uint64_t)address;

+ (nullable UCSymbolInfo *)symbolInfoAtAddress:(uint64_t)address;

+ (nullable NSString *)objcMethodNameAtAddress:(uint64_t)address;

+ (nullable NSString *)stringAtAddress:(uint64_t)address maxLength:(NSUInteger)maxLen;

+ (nullable NSString *)objcClassNameFromClassRef:(uint64_t)address;

+ (BOOL)isAddressReadable:(uint64_t)address size:(NSUInteger)size;

- (void)analyzeAndAnnotateResult:(UCDisasmResult *)result;

@end

NS_ASSUME_NONNULL_END
