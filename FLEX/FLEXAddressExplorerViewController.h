// 遇到问题联系中文翻译作者：pxx917144686
#import "FLEXTableViewController.h"
#import "FLEXGlobalsEntry.h"

NS_ASSUME_NONNULL_BEGIN

// 用于通过内存地址探索对象的视图控制器
@interface FLEXAddressExplorerViewController : FLEXTableViewController

// 创建一个新的地址浏览器视图控制器
+ (instancetype)new;
- (instancetype)init;

// 尝试探索给定地址处的对象。
// @param addressString 要探索的十六进制地址字符串 (例如 "0x1234abcd")。
// @param safely 如果为 YES，则在尝试访问对象之前验证指针是否指向有效的 Objective-C 对象。
//               如果为 NO，则直接访问地址，如果地址无效可能导致崩溃。
- (void)tryExploreAddress:(NSString *)addressString safely:(BOOL)safely;

@end

// 使其成为 FLEX 全局菜单中的一个条目
@interface FLEXAddressExplorerViewController (Globals) <FLEXGlobalsEntry>
@end

NS_ASSUME_NONNULL_END