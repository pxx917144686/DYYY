//
//  UCDisassembler.h
//  FLEX++
//
//  反汇编引擎封装
//  支持 ARM64 架构的反汇编
//  优先使用 Capstone 引擎，如不可用则提供基础功能
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN

/// 反汇编指令信息
@interface UCDisasmInstruction : NSObject

/// 指令地址
@property (nonatomic, assign) uint64_t address;

/// 指令大小（字节）
@property (nonatomic, assign) NSUInteger size;

/// 指令助记符 (如 "add", "bl", "str")
@property (nonatomic, copy) NSString *mnemonic;

/// 操作数字符串
@property (nonatomic, copy) NSString *operands;

/// 完整指令字符串
@property (nonatomic, copy) NSString *fullText;

/// 原始字节 (十六进制)
@property (nonatomic, copy) NSString *bytesHex;

/// 是否是分支指令 (b, bl, br, b.xx, cbz, cbnz, tbz, tbnz 等)
@property (nonatomic, assign) BOOL isBranch;

/// 是否是调用指令 (bl, blr)
@property (nonatomic, assign) BOOL isCall;

/// 是否是返回指令 (ret)
@property (nonatomic, assign) BOOL isReturn;

/// 分支目标地址（如果是分支指令）
@property (nonatomic, assign) uint64_t branchTarget;

/// 是否是有效指令
@property (nonatomic, assign) BOOL isValid;

@end

/// 反汇编结果
@interface UCDisasmResult : NSObject

/// 起始地址
@property (nonatomic, assign) uint64_t startAddress;

/// 反汇编的指令数
@property (nonatomic, assign) NSUInteger instructionCount;

/// 指令列表
@property (nonatomic, strong) NSArray<UCDisasmInstruction *> *instructions;

/// 反汇编使用的引擎
@property (nonatomic, copy) NSString *engineName;

@end

/// 反汇编引擎
@interface UCDisassembler : NSObject

/// 单例
+ (instancetype)sharedInstance;

/// 是否可用（Capstone 引擎是否加载成功）
@property (nonatomic, readonly) BOOL isAvailable;

/// 引擎名称
@property (nonatomic, readonly) NSString *engineName;

/// 反汇编指定地址的代码
/// @param address 起始地址
/// @param size 数据大小（字节）
/// @param isThumb 是否是 Thumb 模式（仅 ARM32）
/// @return 反汇编结果
- (nullable UCDisasmResult *)disassembleAtAddress:(uint64_t)address
                                             size:(NSUInteger)size;

/// 反汇编指定方法的代码
/// @param method Method 指针
/// @return 反汇编结果
- (nullable UCDisasmResult *)disassembleMethod:(Method)method;

/// 反汇编指定类方法的代码
/// @param cls 类
/// @param selector 方法选择子
/// @param isClassMethod 是否是类方法
/// @return 反汇编结果
- (nullable UCDisasmResult *)disassembleClass:(Class)cls
                                     selector:(SEL)selector
                                isClassMethod:(BOOL)isClassMethod;

/// 从地址查找函数符号名
/// @param address 地址
/// @return 符号名，如果找不到则返回 nil
+ (nullable NSString *)symbolNameAtAddress:(uint64_t)address;

/// 验证地址是否可读
/// @param address 地址
/// @param size 大小
/// @return 是否可读
+ (BOOL)isAddressReadable:(uint64_t)address size:(NSUInteger)size;

@end

NS_ASSUME_NONNULL_END
