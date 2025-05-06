// 遇到问题联系中文翻译作者：pxx917144686
//
//  FLEXActivityViewController.h
//  FLEX
//
//  Created by Tanner Bennett on 5/26/22.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 包装 UIActivityViewController 以便可以防止它关闭其他视图控制器
/// (注意：防止关闭的功能在 .m 文件中未实现)
@interface FLEXActivityViewController : UIActivityViewController

/// 创建并配置一个用于共享内容的 UIActivityViewController。
/// @param items 要共享的内容数组。
/// @param source (可选) 用于 iPad popover 定位的来源。可以是 \c UIView、\c UIBarButtonItem 或包含 \c CGRect 的 \c NSValue。
+ (id)sharing:(NSArray *)items source:(nullable id)source;

@end

NS_ASSUME_NONNULL_END
