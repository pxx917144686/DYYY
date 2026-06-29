//
//  NSString+FLEX.h
//  FLEX
//
//  由 Tanner 创建于 3/26/17.
//  版权所有 © 2017 Tanner Bennett. 保留所有权利。
//

#import "FLEXRuntimeConstants.h"

@interface NSString (FLEXTypeEncoding)

@property (nonatomic, readonly) BOOL flex_typeIsConst;
@property (nonatomic, readonly) FLEXTypeEncoding flex_firstNonConstType;
@property (nonatomic, readonly) FLEXTypeEncoding flex_pointeeType;
@property (nonatomic, readonly) BOOL flex_typeIsObjectOrClass;
@property (nonatomic, readonly) Class flex_typeClass;
@property (nonatomic, readonly) BOOL flex_typeIsNonObjcPointer;

@end

@interface NSString (KeyPaths)

- (NSString *)flex_stringByRemovingLastKeyPathComponent;
- (NSString *)flex_stringByReplacingLastKeyPathComponent:(NSString *)replacement;

@end
