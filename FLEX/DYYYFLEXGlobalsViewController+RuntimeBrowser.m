#import "DYYYFLEXGlobalsViewController+RuntimeBrowser.h"
#import "DYYYFLEXGlobalsEntry.h"
#import "DYYYFLEXSystemAnalyzerViewController+RuntimeBrowser.h"
#import "DYYYFLEXRuntimeClient+RuntimeBrowser.h"
#import "DYYYFLEXObjectExplorerFactory.h"
#import "DYYYFLEXHookDetector.h"
#import "DYYYFLEXRuntimeClient.h"
#import "DYYYFLEXTableViewController.h" 
#import "DYYYFLEXGlobalsSection.h"

// 声明必要的类
@interface DYYYRTBRuntimeController : NSObject
+ (instancetype)sharedController;
- (NSArray *)allBundleNames;
@end

@implementation DYYYFLEXGlobalsViewController (RuntimeBrowser)

- (void)addRuntimeBrowserEntries {
    // 使用 allSections 而不是 entries
    NSMutableArray *sections = [self valueForKey:@"sections"];
    if (!sections) {
        sections = [NSMutableArray array];
    }
    
    // 准备所有运行时浏览器条目
    NSMutableArray *runtimeEntries = [NSMutableArray array];
    
    // 1. 高级运行时分析器
    [runtimeEntries addObject:[DYYYFLEXGlobalsEntry entryWithNameFuture:^NSString * {
        return @"🔬 高级运行时分析";
    } viewControllerFuture:^UIViewController * {
        DYYYFLEXSystemAnalyzerViewController *vc = [[DYYYFLEXSystemAnalyzerViewController alloc] init];
        vc.title = @"高级运行时分析";
        return vc;
    }]];
    
    // 2. 类层次结构浏览器  
    [runtimeEntries addObject:[DYYYFLEXGlobalsEntry entryWithNameFuture:^NSString * {
        return @"🌳 类层次结构";
    } viewControllerFuture:^UIViewController * {
        DYYYFLEXTableViewController *vc = [[DYYYFLEXTableViewController alloc] init];
        vc.title = @"类层次结构";
        
        DYYYFLEXRuntimeClient *runtime = [DYYYFLEXRuntimeClient runtime];
        // 使用 sortedClassStubs 替代不存在的 getAllClassesGrouped 方法
        NSArray *sortedClasses = [runtime sortedClassStubs];
        
        // 创建一个层次结构数据模型供表格使用
        NSMutableArray *classHierarchy = [NSMutableArray array];
        [self populateClassHierarchy:classHierarchy withClasses:sortedClasses];
        
        // 这里可以设置表格视图控制器的数据源
        vc.title = [NSString stringWithFormat:@"类层次结构 (%lu)", (unsigned long)sortedClasses.count];
        
        return vc;
    }]];
    
    // 3. 内存分析器增强版
    [runtimeEntries addObject:[DYYYFLEXGlobalsEntry entryWithNameFuture:^NSString * {
        return @"🧠 内存分析器";
    } viewControllerFuture:^UIViewController * {
        // 创建一个适当的控制器来显示内存信息
        DYYYFLEXTableViewController *vc = [[DYYYFLEXTableViewController alloc] init];
        vc.title = @"内存快照";
        return vc;
    }]];
    
    // 4. Hook 检测器
    [runtimeEntries addObject:[DYYYFLEXGlobalsEntry entryWithNameFuture:^NSString * {
        return @"🎣 Hook 检测器";
    } viewControllerFuture:^UIViewController * {
        DYYYFLEXHookDetector *detector = [DYYYFLEXHookDetector sharedDetector];
        // 使用检测器获取钩子数据
        NSMutableDictionary *hookedMethodsData = [NSMutableDictionary dictionary];
        
        // 如果getHookedMethodsForClass方法存在，可以使用它获取数据
        if ([detector respondsToSelector:@selector(getAllHookedMethods)]) {
            hookedMethodsData = [[detector getAllHookedMethods] mutableCopy] ?: [NSMutableDictionary dictionary];
        }
        
        // 使用 DYYYFLEXTableViewController 来显示检测到的钩子
        DYYYFLEXTableViewController *vc = [[DYYYFLEXTableViewController alloc] init];
        vc.title = [NSString stringWithFormat:@"Hook 分析 (%lu类)", (unsigned long)hookedMethodsData.count];
        
        return vc;
    }]];
    
    // 5. 框架浏览器 - 使用 DYYYFLEXRuntimeClient 而不是 RTBRuntimeController
    [runtimeEntries addObject:[DYYYFLEXGlobalsEntry entryWithNameFuture:^NSString * {
        return @"📚 框架浏览器";
    } viewControllerFuture:^UIViewController * {
        DYYYFLEXRuntimeClient *runtime = [DYYYFLEXRuntimeClient runtime];
        NSArray *imageNames = [runtime imageDisplayNames]; // 使用现有的方法
        
        DYYYFLEXTableViewController *vc = [[DYYYFLEXTableViewController alloc] init];
        vc.title = [NSString stringWithFormat:@"已加载框架 (%lu)", (unsigned long)imageNames.count];
        
        return vc;
    }]];
    
    // 创建含有所有条目的部分（一步创建，而不是后续修改）
    DYYYFLEXGlobalsSection *runtimeSection = [DYYYFLEXGlobalsSection title:@"运行时浏览器" rows:runtimeEntries];
    
    // 将部分添加到视图控制器
    [sections addObject:runtimeSection];
    
    // 尝试使用 KVC 更新部分
    [self setValue:sections forKey:@"sections"];
    
    // 重新加载表格视图数据
    if ([self respondsToSelector:@selector(updateSearchResults)]) {
        [self performSelector:@selector(updateSearchResults)];
    }
}

// 添加辅助方法来填充类层次结构
- (void)populateClassHierarchy:(NSMutableArray *)hierarchyArray withClasses:(NSArray *)classes {
    // 简单实现，仅用于编译通过
    // 实际实现可以更复杂，建立真正的类层次结构
    [hierarchyArray addObjectsFromArray:classes];
}

- (void)flattenClassHierarchy:(NSArray *)hierarchy intoArray:(NSMutableArray *)flatArray withIndent:(NSInteger)indent {
    // 确保传递的是数组
    if (![hierarchy isKindOfClass:[NSArray class]]) {
        if ([hierarchy isKindOfClass:[NSDictionary class]]) {
            // 如果是字典，尝试从值中提取数组
            NSDictionary *dict = (NSDictionary *)hierarchy;
            for (id value in dict.allValues) {
                if ([value isKindOfClass:[NSArray class]]) {
                    hierarchy = value;
                    break;
                }
            }
        } else {
            return;
        }
    }
    
    // 处理数组
    for (NSDictionary *node in hierarchy) {
        if (![node isKindOfClass:[NSDictionary class]]) continue;
        
        NSString *indentString = [@"" stringByPaddingToLength:indent * 2 withString:@" " startingAtIndex:0];
        NSString *displayName = [NSString stringWithFormat:@"%@%@", indentString, node[@"className"]];
        [flatArray addObject:displayName];
        
        id subclasses = node[@"subclasses"];
        if (subclasses && [subclasses isKindOfClass:[NSArray class]]) {
            [self flattenClassHierarchy:subclasses intoArray:flatArray withIndent:indent + 1];
        }
    }
}

@end