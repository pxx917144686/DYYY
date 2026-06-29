#import "FLEXMachOClassBrowserViewController.h"
#import "FLEXObjectExplorerFactory.h"
#import "FLEXRuntimeHeaderViewController.h"
#import "UIBarButtonItem+FLEX.h"

@implementation FLEXMachOClassBrowserViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"ClassCell"];
    
    // 添加导出头文件功能
    self.navigationItem.rightBarButtonItem = [UIBarButtonItem 
        flex_itemWithTitle:@"导出所有"
        target:self 
        action:@selector(exportAllHeaders)];
}

#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.classNames.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ClassCell" forIndexPath:indexPath];
    
    NSString *className = self.classNames[indexPath.row];
    cell.textLabel.text = className;
    cell.textLabel.font = [UIFont fontWithName:@"Menlo" size:14];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSString *className = self.classNames[indexPath.row];
    Class cls = NSClassFromString(className);
    
    if (cls) {
        // 创建类浏览器
        UIViewController *classExplorer = [FLEXObjectExplorerFactory explorerViewControllerForObject:cls];
        [self.navigationController pushViewController:classExplorer animated:YES];
    }
}

- (void)exportAllHeaders {
    // 从 RuntimeBrowser 移植的功能
    NSMutableString *allHeaders = [NSMutableString string];
    
    for (NSString *className in self.classNames) {
        Class cls = NSClassFromString(className);
        if (cls) {
            NSString *header = [self generateHeaderForClass:cls];
            [allHeaders appendFormat:@"// %@\n%@\n\n", className, header];
        }
    }
    
    // 创建临时文件并分享
    NSString *fileName = [NSString stringWithFormat:@"%@_headers.h", self.title];
    NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
    
    NSError *error;
    BOOL success = [allHeaders writeToFile:tempPath 
                                atomically:YES 
                                  encoding:NSUTF8StringEncoding 
                                     error:&error];
    
    if (success) {
        NSURL *fileURL = [NSURL fileURLWithPath:tempPath];
        UIActivityViewController *shareVC = [[UIActivityViewController alloc] 
                                           initWithActivityItems:@[fileURL] 
                                           applicationActivities:nil];
        [self presentViewController:shareVC animated:YES completion:nil];
    }
}

- (NSString *)generateHeaderForClass:(Class)cls {
    // 从 RTBRuntimeHeader 移植的头文件生成功能
    NSMutableString *header = [NSMutableString string];
    
    if (!cls) return @"";
    
    // 类声明
    Class superclass = class_getSuperclass(cls);
    NSString *superclassName = superclass ? NSStringFromClass(superclass) : @"NSObject";
    
    [header appendFormat:@"@interface %@ : %@\n\n", NSStringFromClass(cls), superclassName];
    
    // 属性
    unsigned int propertyCount;
    objc_property_t *properties = class_copyPropertyList(cls, &propertyCount);
    
    if (propertyCount > 0) {
        [header appendString:@"// Properties\n"];
        for (unsigned int i = 0; i < propertyCount; i++) {
            objc_property_t property = properties[i];
            const char *propertyName = property_getName(property);
            const char *propertyAttributes = property_getAttributes(property);
            
            [header appendFormat:@"@property %s %s;\n", propertyAttributes, propertyName];
        }
        [header appendString:@"\n"];
    }
    free(properties);
    
    // 实例方法
    unsigned int methodCount;
    Method *methods = class_copyMethodList(cls, &methodCount);
    
    if (methodCount > 0) {
        [header appendString:@"// Instance Methods\n"];
        for (unsigned int i = 0; i < methodCount; i++) {
            Method method = methods[i];
            SEL selector = method_getName(method);
            const char *typeEncoding = method_getTypeEncoding(method);
            
            [header appendFormat:@"- (%s)%s;\n", typeEncoding, sel_getName(selector)];
        }
        [header appendString:@"\n"];
    }
    free(methods);
    
    // 类方法
    methods = class_copyMethodList(object_getClass(cls), &methodCount);
    
    if (methodCount > 0) {
        [header appendString:@"// Class Methods\n"];
        for (unsigned int i = 0; i < methodCount; i++) {
            Method method = methods[i];
            SEL selector = method_getName(method);
            const char *typeEncoding = method_getTypeEncoding(method);
            
            [header appendFormat:@"+ (%s)%s;\n", typeEncoding, sel_getName(selector)];
        }
        [header appendString:@"\n"];
    }
    free(methods);
    
    [header appendString:@"@end"];
    
    return header;
}

@end