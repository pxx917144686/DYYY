//
//  FLEXBlockDescription.m
//  FLEX
//
//  创建者：Oliver Letterer，日期：2012-09-01
//  派生自 CTObjectiveCRuntimeAdditions (MIT 许可证)
//  https://github.com/ebf/CTObjectiveCRuntimeAdditions
//
//  版权所有 (c) 2020 FLEX Team-EDV Beratung Föllmer GmbH
//  特此授予任何人免费获得本软件和相关文档文件（“软件”）副本的许可，
//  可以不受限制地处理本软件，包括但不限于使用、复制、修改、合并、
//  发布、分发、再许可和/或销售本软件副本的权利，并允许获得本软件的
//  人这样做，但须符合以下条件：
//  上述版权声明和本许可声明应包含在本软件的所有副本或
//  实质部分中。
//
//  本软件按“原样”提供，不作任何明示或暗示的保证，包括但
//  不限于对适销性、特定用途适用性和非侵权性的保证。在任何情况下，
//  作者或版权持有人均不对任何索赔、损害或其他责任承担任何责任，无论是在
//  合同诉讼、侵权行为还是其他方面，由本软件或本软件的使用或其他交易引起或与之相关。
//
// 遇到问题联系中文翻译作者：pxx917144686

#import "FLEXBlockDescription.h"
#import "FLEXRuntimeUtility.h"

struct block_object {
    void *isa;
    int flags;
    int reserved;
    void (*invoke)(void *, ...);
    struct block_descriptor {
        unsigned long int reserved;    // NULL
        unsigned long int size;     // sizeof(struct Block_literal_1)
        // 可选的辅助函数
        void (*copy_helper)(void *dst, void *src);     // 当 (1<<25) 标志位被设置时
        void (*dispose_helper)(void *src);             // 当 (1<<25) 标志位被设置时
        // 必需的 ABI.2010.3.16
        const char *signature;                         // 当 (1<<30) 标志位被设置时
    } *descriptor;
    // 导入的变量
};

@implementation FLEXBlockDescription

+ (instancetype)describing:(id)block {
    return [[self alloc] initWithObjcBlock:block];
}

- (id)initWithObjcBlock:(id)block {
    self = [super init];
    if (self) {
        _block = block;
        
        struct block_object *blockRef = (__bridge struct block_object *)block;
        _flags = blockRef->flags;
        _size = blockRef->descriptor->size;
        
        if (_flags & FLEXBlockOptionHasSignature) {
            void *signatureLocation = blockRef->descriptor;
            signatureLocation += sizeof(unsigned long int);
            signatureLocation += sizeof(unsigned long int);
            
            if (_flags & FLEXBlockOptionHasCopyDispose) {
                signatureLocation += sizeof(void(*)(void *dst, void *src));
                signatureLocation += sizeof(void (*)(void *src));
            }
            
            const char *signature = (*(const char **)signatureLocation);
            _signatureString = @(signature);
            
            @try {
                _signature = [NSMethodSignature signatureWithObjCTypes:signature];
            } @catch (NSException *exception) { } // 捕获异常，保持为空
        }
        
        NSMutableString *summary = [NSMutableString stringWithFormat:
            @"类型签名: %@\n尺寸: %@\n是全局的: %@\n有构造器: %@\n是 stret: %@", // "Type Signature: %@\nSize: %@\nIs Global: %@\nHas Ctor: %@\nHas Stret: %@"
            self.signatureString ?: @"nil", @(self.size),
            @((BOOL)(_flags & FLEXBlockOptionIsGlobal)),
            @((BOOL)(_flags & FLEXBlockOptionHasCtor)),
            @((BOOL)(_flags & FLEXBlockOptionHasStret))
        ];
        
        if (!self.signature) {
            [summary appendFormat:@"\n参数数量: %@", @(self.signature.numberOfArguments)];
        }
        
        _summary = summary.copy;
        _sourceDeclaration = [self buildLikelyDeclaration];
    }
    
    return self;
}

- (BOOL)isCompatibleForBlockSwizzlingWithMethodSignature:(NSMethodSignature *)methodSignature {
    if (!self.signature) {
        return NO;
    }
    
    if (self.signature.numberOfArguments != methodSignature.numberOfArguments + 1) {
        return NO;
    }
    
    if (strcmp(self.signature.methodReturnType, methodSignature.methodReturnType) != 0) {
        return NO;
    }
    
    for (int i = 0; i < methodSignature.numberOfArguments; i++) {
        if (i == 1) {
            // 方法中的 SEL，块中的 IMP
            if (strcmp([methodSignature getArgumentTypeAtIndex:i], ":") != 0) {
                return NO;
            }
            
            if (strcmp([self.signature getArgumentTypeAtIndex:i + 1], "^?") != 0) {
                return NO;
            }
        } else {
            if (strcmp([methodSignature getArgumentTypeAtIndex:i], [self.signature getArgumentTypeAtIndex:i + 1]) != 0) {
                return NO;
            }
        }
    }
    
    return YES;
}

- (NSString *)buildLikelyDeclaration {
    NSMethodSignature *signature = self.signature;
    NSUInteger numberOfArguments = signature.numberOfArguments;
    const char *returnType       = signature.methodReturnType;
    
    // 返回类型
    NSMutableString *decl = [NSMutableString stringWithString:@"^"];
    if (returnType[0] != FLEXTypeEncodingVoid) {
        [decl appendString:[FLEXRuntimeUtility readableTypeForEncoding:@(returnType)]];
        [decl appendString:@" "];
    }
    
    // 参数
    if (numberOfArguments) {
        [decl appendString:@"("];
        for (NSUInteger i = 1; i < numberOfArguments; i++) {
            const char *argType = [self.signature getArgumentTypeAtIndex:i] ?: "?";
            NSString *readableArgType = [FLEXRuntimeUtility readableTypeForEncoding:@(argType)];
            [decl appendFormat:@"%@ arg%@, ", readableArgType, @(i)];
        }
        
        [decl deleteCharactersInRange:NSMakeRange(decl.length-2, 2)];
        [decl appendString:@")"];
    }
    
    return decl.copy;
}

@end
