//
//  DYYYFLEXArgumentInputViewFactory.h
//  FLEXInjected
//
//  Created by Ryan Olson on 6/15/14.
//
//

#import <Foundation/Foundation.h>
#import "DYYYFLEXArgumentInputSwitchView.h"

@interface DYYYFLEXArgumentInputViewFactory : NSObject

/// Forwards to argumentInputViewForTypeEncoding:currentValue: with a nil currentValue.
+ (DYYYFLEXArgumentInputView *)argumentInputViewForTypeEncoding:(const char *)typeEncoding;

/// The main factory method for making argument input view subclasses that are the best fit for the type.
+ (DYYYFLEXArgumentInputView *)argumentInputViewForTypeEncoding:(const char *)typeEncoding currentValue:(id)currentValue;

/// A way to check if we should try editing a filed given its type encoding and value.
/// Useful when deciding whether to edit or explore a property, ivar, or NSUserDefaults value.
+ (BOOL)canEditFieldWithTypeEncoding:(const char *)typeEncoding currentValue:(id)currentValue;

/// Enable displaying ivar names for custom struct types
+ (void)registerFieldNames:(NSArray<NSString *> *)names forTypeEncoding:(NSString *)typeEncoding;

@end
