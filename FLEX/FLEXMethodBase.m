// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXMethodBase.m
//  FLEX
//
//  派生自 MirrorKit。
//  由 Tanner 创建于 7/5/15.
//  版权所有 (c) 2020 FLEX Team。保留所有权利。

#import "FLEXMethodBase.h"


@implementation FLEXMethodBase

#pragma mark Initializers

+ (instancetype)buildMethodNamed:(NSString *)name withTypes:(NSString *)typeEncoding implementation:(IMP)implementation {
    return [[self alloc] initWithSelector:sel_registerName(name.UTF8String) types:typeEncoding imp:implementation];
}

- (id)initWithSelector:(SEL)selector types:(NSString *)types imp:(IMP)imp {
    NSParameterAssert(selector); NSParameterAssert(types); NSParameterAssert(imp);
    
    self = [super init];
    if (self) {
        _selector = selector;
        _typeEncoding = types;
        _implementation = imp;
        _name = NSStringFromSelector(self.selector);
    }
    
    return self;
}

- (NSString *)selectorString {
    return _name;
}

#pragma mark Overrides

- (NSString *)description {
    if (!_flex_description) {
        _flex_description = [NSString stringWithFormat:@"%@ '%@'", _name, _typeEncoding];
    }

    return _flex_description;
}

@end
