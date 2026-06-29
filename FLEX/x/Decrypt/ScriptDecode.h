#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NSString *IZXScriptDetectType(NSString *script);
NSString *IZXDecodeScriptText(NSString *script, NSString *source);
void IZXTryRecordDecodedScript(NSString *script, NSString *source);

NS_ASSUME_NONNULL_END
