#import "FLEXFileBrowserController+RuntimeBrowser.h"
#import "FLEXTableListViewController.h"
#import "FLEXObjectExplorerFactory.h"
#import "FLEXMachOClassBrowserViewController.h"
#import "FLEXWebViewController.h"
#import "FLEXAlert.h"
#import <dlfcn.h>
#import <objc/runtime.h>

@implementation FLEXFileBrowserController (RuntimeBrowser)

- (void)analyzeRuntimeMachOFile:(NSString *)path {
    const char *imagePath = path.UTF8String;
    void *handle = dlopen(imagePath, RTLD_LAZY | RTLD_NOLOAD);
    
    NSMutableArray *classNames = [NSMutableArray array];
    
    if (handle) {
        unsigned int count = 0;
        const char **classNamesC = objc_copyClassNamesForImage(imagePath, &count);
        
        for (unsigned int i = 0; i < count; i++) {
            NSString *className = @(classNamesC[i]);
            [classNames addObject:className];
        }
        
        free(classNamesC);
        dlclose(handle);
        
        FLEXMachOClassBrowserViewController *classBrowser = [[FLEXMachOClassBrowserViewController alloc] init];
        classBrowser.classNames = classNames;
        classBrowser.title = [NSString stringWithFormat:@"Classes in %@", path.lastPathComponent];
        [self.navigationController pushViewController:classBrowser animated:YES];
        
    } else {
        [FLEXAlert makeAlert:^(FLEXAlert *make) {
            make.title(@"分析失败");
            make.message([NSString stringWithFormat:@"无法加载Mach-O文件: %@", path]);
            make.button(@"确定").handler(^(NSArray<NSString *> *strings) {
                // 空的 handler 实现
            });
        } showFrom:self];
    }
}

- (void)analyzePlistFile:(NSString *)path {
    NSError *error;
    NSData *plistData = [NSData dataWithContentsOfFile:path];
    
    if (!plistData) {
        [FLEXAlert makeAlert:^(FLEXAlert *make) {
            make.title(@"错误");
            make.message(@"无法读取文件");
            make.button(@"确定").handler(^(NSArray<NSString *> *strings) {
                // 空的 handler 实现
            });
        } showFrom:self];
        return;
    }
    
    id plistObject = [NSPropertyListSerialization propertyListWithData:plistData
                                                               options:NSPropertyListImmutable
                                                                format:NULL
                                                                 error:&error];
    
    if (error) {
        [FLEXAlert makeAlert:^(FLEXAlert *make) {
            make.title(@"解析错误");
            make.message(error.localizedDescription);
            make.button(@"确定").handler(^(NSArray<NSString *> *strings) {
                // 空的 handler 实现
            });
        } showFrom:self];
        return;
    }
    
    // 使用对象浏览器显示plist内容
    UIViewController *objectExplorer = [FLEXObjectExplorerFactory explorerViewControllerForObject:plistObject];
    objectExplorer.title = path.lastPathComponent;
    [self.navigationController pushViewController:objectExplorer animated:YES];
}

- (void)previewTextFile:(NSString *)path {
    NSError *error;
    NSString *content = [NSString stringWithContentsOfFile:path 
                                                   encoding:NSUTF8StringEncoding 
                                                      error:&error];
    
    if (error) {
        content = [NSString stringWithContentsOfFile:path 
                                            encoding:NSASCIIStringEncoding 
                                               error:&error];
    }
    
    if (error) {
        [FLEXAlert makeAlert:^(FLEXAlert *make) {
            make.title(@"读取错误");
            make.message(error.localizedDescription);
            make.button(@"确定").handler(^(NSArray<NSString *> *strings) {
                // 空的 handler 实现
            });
        } showFrom:self];
        return;
    }
    
    // 使用Web视图显示文本内容
    FLEXWebViewController *webViewController = [[FLEXWebViewController alloc] initWithText:content];
    webViewController.title = path.lastPathComponent;
    [self.navigationController pushViewController:webViewController animated:YES];
}

- (void)analyzeFileAtPath:(NSString *)path {
    NSString *extension = [path.pathExtension lowercaseString];
    
    if ([extension isEqualToString:@"dylib"] || [extension isEqualToString:@"framework"]) {
        [self analyzeRuntimeMachOFile:path];
    } else if ([extension isEqualToString:@"plist"]) {
        [self analyzePlistFile:path];
    } else if ([@[@"txt", @"log", @"json", @"xml", @"h", @"m", @"mm", @"c", @"cpp"] containsObject:extension]) {
        [self previewTextFile:path];
    } else {
        [FLEXAlert makeAlert:^(FLEXAlert *make) {
            make.title(@"不支持的文件类型");
            make.message([NSString stringWithFormat:@"无法分析文件类型: %@", extension]);
            make.button(@"确定").handler(^(NSArray<NSString *> *strings) {
                // 空的 handler 实现
            });
        } showFrom:self];
    }
}

@end