// 遇到问题联系中文翻译作者：pxx917144686
#import "FLEXAddressExplorerViewController.h"
#import "FLEXObjectExplorerFactory.h"
#import "FLEXUtility.h"
#import "FLEXRuntimeUtility.h"
#import "FLEXAlert.h"
#import "FLEXRuntimeSafety.h" // 包含 FLEXPointerIsValidObjcObject

@implementation FLEXAddressExplorerViewController

#pragma mark - 初始化

+ (instancetype)new {
    return [[self alloc] init];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // 初始化代码（如果需要）
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"地址浏览器";
    
    // 添加一个文本输入框和按钮，或者在 globals 入口处理输入
    // 这里假设输入通过 FLEXAddressExplorerCoordinator 处理
}

#pragma mark - 公共方法

- (void)tryExploreAddress:(NSString *)addressString safely:(BOOL)safely {
    NSScanner *scanner = [NSScanner scannerWithString:addressString];
    unsigned long long address = 0;
    
    // 扫描十六进制地址
    if([scanner scanHexLongLong:&address]) {
        const void *pointerValue = (const void *)address; // 将地址转换为指针
        id object = nil;
        
        BOOL isValid = NO;
        if (safely) {
            // 安全模式：检查指针是否指向有效的 Objective-C 对象
            isValid = [FLEXRuntimeUtility pointerIsValidObjcObject:pointerValue];
        } else {
            // 不安全模式：直接假设指针有效（可能导致崩溃）
            isValid = YES;
        }
        
        if (isValid) {
            object = (__bridge id)pointerValue; // 桥接为 Objective-C 对象
            // 探索对象
            UIViewController *explorer = [FLEXObjectExplorerFactory explorerViewControllerForObject:object];
            [self.navigationController pushViewController:explorer animated:YES];
        } else {
            // 地址无效或不安全模式下指针无效
            [FLEXAlert showAlert:@"无效地址" message:@"在该地址未找到有效的 Objective-C 对象，或者指针无效。" from:self];
        }
    } else {
        // 输入不是有效的十六进制地址
        [FLEXAlert showAlert:@"无效输入" message:@"请输入有效的十六进制地址，以 '0x' 开头。" from:self];
    }
}

@end

#pragma mark - FLEXGlobalsEntry

@implementation FLEXAddressExplorerViewController (Globals)

+ (NSString *)globalsEntryTitle:(FLEXGlobalsRow)row {
    // 全局入口标题
    return @"🔍  地址浏览器";
}

+ (UIViewController *)globalsEntryViewController:(FLEXGlobalsRow)row {
    // 返回此视图控制器的新实例
    // 注意：实际的地址输入逻辑由 FLEXAddressExplorerCoordinator 处理
    return [self new];
}

@end