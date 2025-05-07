// 遇到问题联系中文翻译作者：pxx917144686
//
// FLEXCurlLogger.h
//
//
// 由 Ji Pei 创建于 07/27/16
//

#import <Foundation/Foundation.h>

@interface FLEXNetworkCurlLogger : NSObject

/**
 * 生成一个等效于给定请求的 cURL 命令。
 *
 * @param request 要转换的请求
 */
+ (NSString *)curlCommandString:(NSURLRequest *)request;

@end
