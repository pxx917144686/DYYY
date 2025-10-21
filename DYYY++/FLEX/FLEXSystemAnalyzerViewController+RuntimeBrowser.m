#import "FLEXSystemAnalyzerViewController+RuntimeBrowser.h"
#import "FLEXRuntimeClient+RuntimeBrowser.h"
#import "FLEXMemoryAnalyzer+RuntimeBrowser.h"
#import "FLEXHookDetector+RuntimeBrowser.h"

@implementation FLEXSystemAnalyzerViewController (RuntimeBrowser)

- (NSDictionary *)getAdvancedSystemAnalysis {
    NSMutableDictionary *analysis = [NSMutableDictionary dictionary];
    
    // 运行时分析
    FLEXRuntimeClient *runtime = [FLEXRuntimeClient runtime];
    analysis[@"runtime"] = @{
        @"totalClasses": @([[runtime sortedClassStubs] count]),
        @"rootClasses": @([[runtime rootClasses] count]),
        @"classHierarchy": [self getClassHierarchyTree]
    };
    
    // 内存分析
    FLEXMemoryAnalyzer *memoryAnalyzer = [FLEXMemoryAnalyzer sharedAnalyzer];
    analysis[@"memory"] = [memoryAnalyzer getDetailedHeapSnapshot];
    
    // Hook 分析
    FLEXHookDetector *hookDetector = [FLEXHookDetector sharedDetector];
    analysis[@"hooks"] = [hookDetector getDetailedHookAnalysis];
    
    // Bundle 分析
    analysis[@"bundles"] = [self getBundleAnalysis];
    
    // 框架信息
    analysis[@"frameworks"] = [self getLoadedFrameworksInfo];
    
    return analysis;
}

- (NSArray *)getLoadedFrameworksInfo {
    NSMutableArray *frameworks = [NSMutableArray array];
    
    unsigned int imageCount = 0;
    const char **imageNames = objc_copyImageNames(&imageCount);
    
    if (imageNames) {
        for (unsigned int i = 0; i < imageCount; i++) {
            NSString *imagePath = @(imageNames[i]);
            
            // 获取框架信息
            NSDictionary *info = [self analyzeFrameworkAtPath:imagePath];
            if (info) {
                [frameworks addObject:info];
            }
        }
        
        free(imageNames);
    }
    
    return frameworks;
}

- (NSDictionary *)analyzeFrameworkAtPath:(NSString *)path {
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    
    info[@"path"] = path;
    info[@"name"] = [path lastPathComponent];
    
    // 获取该镜像中的类
    unsigned int classCount = 0;
    const char **classNames = objc_copyClassNamesForImage(path.UTF8String, &classCount);
    
    if (classNames) {
        NSMutableArray *classes = [NSMutableArray array];
        for (unsigned int i = 0; i < classCount; i++) {
            [classes addObject:@(classNames[i])];
        }
        
        info[@"classes"] = classes;
        info[@"classCount"] = @(classCount);
        
        free(classNames);
    }
    
    // 获取文件大小
    NSError *error;
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:&error];
    if (attributes) {
        info[@"fileSize"] = attributes[NSFileSize];
    }
    
    return info;
}

- (NSDictionary *)getBundleAnalysis {
    NSMutableDictionary *analysis = [NSMutableDictionary dictionary];
    
    // 主 Bundle 信息
    NSBundle *mainBundle = [NSBundle mainBundle];
    analysis[@"mainBundle"] = @{
        @"bundleIdentifier": mainBundle.bundleIdentifier ?: @"unknown",
        @"version": mainBundle.infoDictionary[@"CFBundleShortVersionString"] ?: @"unknown",
        @"build": mainBundle.infoDictionary[@"CFBundleVersion"] ?: @"unknown",
        @"path": mainBundle.bundlePath
    };
    
    // 加载的 Bundle
    NSMutableArray *loadedBundles = [NSMutableArray array];
    for (NSBundle *bundle in [NSBundle allBundles]) {
        [loadedBundles addObject:@{
            @"identifier": bundle.bundleIdentifier ?: @"unknown",
            @"path": bundle.bundlePath,
            @"loaded": @([bundle isLoaded])
        }];
    }
    
    analysis[@"loadedBundles"] = loadedBundles;
    analysis[@"bundleCount"] = @(loadedBundles.count);
    
    return analysis;
}

- (NSArray *)getClassHierarchyTree {
    NSMutableArray *tree = [NSMutableArray array];
    
    FLEXRuntimeClient *runtime = [FLEXRuntimeClient runtime];
    NSArray *rootClasses = [runtime rootClasses];
    
    for (NSString *rootClassName in rootClasses) {
        Class rootClass = NSClassFromString(rootClassName);
        if (rootClass) {
            NSDictionary *node = [self buildClassTreeForClass:rootClass];
            [tree addObject:node];
        }
    }
    
    return tree;
}

- (NSDictionary *)buildClassTreeForClass:(Class)cls {
    NSMutableDictionary *node = [NSMutableDictionary dictionary];
    
    node[@"className"] = NSStringFromClass(cls);
    node[@"instanceSize"] = @(class_getInstanceSize(cls));
    
    // 获取子类
    NSMutableArray *subclasses = [NSMutableArray array];
    
    unsigned int classCount = 0;
    Class *classes = objc_copyClassList(&classCount);
    
    for (unsigned int i = 0; i < classCount; i++) {
        Class currentClass = classes[i];
        if (class_getSuperclass(currentClass) == cls) {
            NSDictionary *subnode = [self buildClassTreeForClass:currentClass];
            [subclasses addObject:subnode];
        }
    }
    
    free(classes);
    
    if (subclasses.count > 0) {
        node[@"subclasses"] = subclasses;
    }
    
    return node;
}

@end