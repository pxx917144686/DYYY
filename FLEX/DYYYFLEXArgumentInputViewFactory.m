//
//  DYYYFLEXArgumentInputViewFactory.m
//  FLEXInjected
//
//  Created by Ryan Olson on 6/15/14.
//
//

#import "DYYYFLEXArgumentInputViewFactory.h"
#import "DYYYFLEXArgumentInputView.h"
#import "DYYYFLEXArgumentInputObjectView.h"
#import "DYYYFLEXArgumentInputNumberView.h"
#import "DYYYFLEXArgumentInputSwitchView.h"
#import "DYYYFLEXArgumentInputStructView.h"
#import "DYYYFLEXArgumentInputNotSupportedView.h"
#import "DYYYFLEXArgumentInputStringView.h"
#import "DYYYFLEXArgumentInputFontView.h"
#import "DYYYFLEXArgumentInputColorView.h"
#import "DYYYFLEXArgumentInputDateView.h"
#import "DYYYFLEXRuntimeUtility.h"

@implementation DYYYFLEXArgumentInputViewFactory

+ (DYYYFLEXArgumentInputView *)argumentInputViewForTypeEncoding:(const char *)typeEncoding {
    return [self argumentInputViewForTypeEncoding:typeEncoding currentValue:nil];
}

+ (DYYYFLEXArgumentInputView *)argumentInputViewForTypeEncoding:(const char *)typeEncoding currentValue:(id)currentValue {
    Class subclass = [self argumentInputViewSubclassForTypeEncoding:typeEncoding currentValue:currentValue];
    if (!subclass) {
        // Fall back to a DYYYFLEXArgumentInputNotSupportedView if we can't find a subclass that fits the type encoding.
        // The unsupported view shows "nil" and does not allow user input.
        subclass = [DYYYFLEXArgumentInputNotSupportedView class];
    }
    // Remove the field name if there is any (e.g. \"width\"d -> d)
    const NSUInteger fieldNameOffset = [DYYYFLEXRuntimeUtility fieldNameOffsetForTypeEncoding:typeEncoding];
    return [[subclass alloc] initWithArgumentTypeEncoding:typeEncoding + fieldNameOffset];
}

+ (Class)argumentInputViewSubclassForTypeEncoding:(const char *)typeEncoding currentValue:(id)currentValue {
    // Remove the field name if there is any (e.g. \"width\"d -> d)
    const NSUInteger fieldNameOffset = [DYYYFLEXRuntimeUtility fieldNameOffsetForTypeEncoding:typeEncoding];
    Class argumentInputViewSubclass = nil;
    NSArray<Class> *inputViewClasses = @[[DYYYFLEXArgumentInputColorView class],
                                         [DYYYFLEXArgumentInputFontView class],
                                         [DYYYFLEXArgumentInputStringView class],
                                         [DYYYFLEXArgumentInputStructView class],
                                         [DYYYFLEXArgumentInputSwitchView class],
                                         [DYYYFLEXArgumentInputDateView class],
                                         [DYYYFLEXArgumentInputNumberView class],
                                         [DYYYFLEXArgumentInputObjectView class]];

    // Note that order is important here since multiple subclasses may support the same type.
    // An example is the number subclass and the bool subclass for the type @encode(BOOL).
    // Both work, but we'd prefer to use the bool subclass.
    for (Class inputViewClass in inputViewClasses) {
        if ([inputViewClass supportsObjCType:typeEncoding + fieldNameOffset withCurrentValue:currentValue]) {
            argumentInputViewSubclass = inputViewClass;
            break;
        }
    }

    return argumentInputViewSubclass;
}

+ (BOOL)canEditFieldWithTypeEncoding:(const char *)typeEncoding currentValue:(id)currentValue {
    return [self argumentInputViewSubclassForTypeEncoding:typeEncoding currentValue:currentValue] != nil;
}

/// Enable displaying ivar names for custom struct types
+ (void)registerFieldNames:(NSArray<NSString *> *)names forTypeEncoding:(NSString *)typeEncoding {
    [DYYYFLEXArgumentInputStructView registerFieldNames:names forTypeEncoding:typeEncoding];
}

@end
