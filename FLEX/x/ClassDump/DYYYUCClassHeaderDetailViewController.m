#import "DYYYUCClassHeaderDetailViewController.h"
#import "DYYYUCClassDumpTool.h"
#import "DYYYFLEXColor.h"
#import "DYYYFLEXActivityViewController.h"
#import <objc/runtime.h>

@interface DYYYUCClassHeaderDetailViewController () <UISearchBarDelegate>

@property (nonatomic, copy) NSString *headerContent;
@property (nonatomic, strong) UITextView *textView;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, strong) NSString *searchText;
@property (nonatomic, strong) NSArray<NSValue *> *matchRanges;
@property (nonatomic, assign) NSInteger currentMatchIndex;
@property (nonatomic, assign) NSInteger fontSize;
@property (nonatomic, strong) UISearchBar *searchBar;

@end

@implementation DYYYUCClassHeaderDetailViewController

- (instancetype)initWithClassName:(NSString *)className {
    self = [super init];
    if (self) {
        _className = className ?: @"";
        _fontSize = 11;
        _matchRanges = @[];
        _currentMatchIndex = 0;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = DYYYFLEXColor.primaryBackgroundColor;
    self.title = [NSString stringWithFormat:@"%@.h", self.className];
    
    UIBarButtonItem *copy = [[UIBarButtonItem alloc]
        initWithTitle:@"复制"
        style:UIBarButtonItemStylePlain
        target:self
        action:@selector(copyAction)];
    
    UIBarButtonItem *share = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemAction
        target:self
        action:@selector(shareAction)];
    
    UIBarButtonItem *font = [[UIBarButtonItem alloc]
        initWithTitle:@"字体"
        style:UIBarButtonItemStylePlain
        target:self
        action:@selector(fontAction)];
    
    UIBarButtonItem *export = [[UIBarButtonItem alloc]
        initWithTitle:@"导出"
        style:UIBarButtonItemStylePlain
        target:self
        action:@selector(exportAction)];
    
    self.navigationItem.rightBarButtonItems = @[export, share, copy, font];
    
    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectZero];
    [self.searchBar sizeToFit];
    self.searchBar.delegate = self;
    self.searchBar.placeholder = @"搜索头文件内容...";
    self.searchBar.backgroundColor = DYYYFLEXColor.primaryBackgroundColor;
    self.searchBar.searchBarStyle = UISearchBarStyleMinimal;
    self.searchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.searchBar.autocorrectionType = UITextAutocorrectionTypeNo;
    self.searchBar.tintColor = [UIColor colorWithRed:0.2 green:0.6 blue:1.0 alpha:1.0];
    self.searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.searchBar];
    
    self.loadingIndicator = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.loadingIndicator.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin |
                                              UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    self.loadingIndicator.hidesWhenStopped = YES;
    self.loadingIndicator.center = CGPointMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2);
    [self.view addSubview:self.loadingIndicator];
    [self.loadingIndicator startAnimating];
    
    self.textView = [[UITextView alloc] initWithFrame:CGRectZero];
    self.textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.textView.backgroundColor = DYYYFLEXColor.primaryBackgroundColor;
    self.textView.textColor = DYYYFLEXColor.primaryTextColor;
    self.textView.font = [UIFont fontWithName:@"Menlo-Regular" size:self.fontSize];
    self.textView.editable = NO;
    self.textView.selectable = YES;
    self.textView.textContainerInset = UIEdgeInsetsMake(8, 8, 8, 8);
    self.textView.hidden = YES;
    [self.view addSubview:self.textView];
    
    [self loadHeader];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat width = self.view.bounds.size.width;
    CGFloat height = self.view.bounds.size.height;
    CGFloat safeTop = self.view.safeAreaInsets.top;
    
    [self.searchBar sizeToFit];
    CGFloat searchBarHeight = self.searchBar.frame.size.height;
    self.searchBar.frame = CGRectMake(0, safeTop, width, searchBarHeight);
    
    self.loadingIndicator.center = CGPointMake(width / 2, height / 2);
    
    CGFloat topOffset = safeTop + searchBarHeight;
    self.textView.frame = CGRectMake(0, topOffset, width, height - topOffset);
}

- (void)loadHeader {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *header = [DYYYUCClassDumpTool headerForClassName:self.className];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.loadingIndicator stopAnimating];
            self.textView.hidden = NO;
            
            if (header.length > 0) {
                self.headerContent = header;
                self.textView.text = header;
            } else {
                self.textView.text = [NSString stringWithFormat:@"// 错误: 无法找到类 %@ 的头文件\n// 请确认类名是否正确", self.className];
                self.textView.textColor = [UIColor redColor];
            }
        });
    });
}

#pragma mark - 操作

- (void)copyAction {
    NSString *content = self.headerContent;
    if (content.length == 0) return;
    
    UIPasteboard.generalPasteboard.string = content;
    
    UILabel *toast = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 120, 40)];
    toast.center = CGPointMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2);
    toast.backgroundColor = [UIColor colorWithWhite:0 alpha:0.8];
    toast.textColor = [UIColor whiteColor];
    toast.textAlignment = NSTextAlignmentCenter;
    toast.font = [UIFont systemFontOfSize:14];
    toast.text = @"已复制";
    toast.layer.cornerRadius = 8;
    toast.clipsToBounds = YES;
    toast.alpha = 0;
    [self.view addSubview:toast];
    
    [UIView animateWithDuration:0.2 animations:^{
        toast.alpha = 1;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.3 delay:0.8 options:0 animations:^{
            toast.alpha = 0;
        } completion:^(BOOL finished) {
            [toast removeFromSuperview];
        }];
    }];
}

- (void)shareAction {
    if (self.headerContent.length == 0) return;
    
    NSString *fileName = [NSString stringWithFormat:@"%@.h", self.className];
    NSString *tmpPath = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
    NSError *writeError = nil;
    BOOL success = [self.headerContent writeToFile:tmpPath atomically:YES encoding:NSUTF8StringEncoding error:&writeError];
    if (!success) {
        NSLog(@"Failed to write file: %@", writeError);
        return;
    }
    NSURL *fileURL = [NSURL fileURLWithPath:tmpPath];
    
    UIViewController *activityVC = [DYYYFLEXActivityViewController sharing:@[fileURL] source:self.navigationItem.rightBarButtonItems.firstObject];
    [self presentViewController:activityVC animated:YES completion:nil];
}

- (void)fontAction {
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"字体大小"
        message:nil
        preferredStyle:UIAlertControllerStyleActionSheet];
    
    NSArray *sizes = @[@10, @11, @12, @14, @16, @18, @20];
    for (NSNumber *size in sizes) {
        NSString *title = [NSString stringWithFormat:@"%@ pt", size];
        if (size.integerValue == self.fontSize) {
            title = [title stringByAppendingString:@" ✓"];
        }
        [alert addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            self.fontSize = size.integerValue;
            self.textView.font = [UIFont fontWithName:@"Menlo-Regular" size:self.fontSize];
            [self refreshHighlight];
        }]];
    }
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    
    alert.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItems.lastObject;
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)exportAction {
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"导出类资料"
        message:@"选择要导出的内容格式"
        preferredStyle:UIAlertControllerStyleActionSheet];
    
    __weak typeof(self) weakSelf = self;
    
    [alert addAction:[UIAlertAction actionWithTitle:@"完整类信息 (JSON)"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction * _Nonnull action) {
        [weakSelf exportFullClassInfoAsJSON];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"属性列表 (JSON)"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction * _Nonnull action) {
        [weakSelf exportPropertiesAsJSON];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"方法列表 (JSON)"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction * _Nonnull action) {
        [weakSelf exportMethodsAsJSON];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Ivar 内存布局 (JSON)"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction * _Nonnull action) {
        [weakSelf exportIvarsAsJSON];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    
    alert.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItems.firstObject;
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - 导出功能

+ (NSString *)typeFromEncoding:(const char *)encoding {
    if (!encoding) return @"id";
    
    NSString *e = [NSString stringWithUTF8String:encoding];
    if (e.length == 0) return @"id";
    
    if ([e hasPrefix:@"@\""]) {
        NSRange r1 = [e rangeOfString:@"\""];
        NSRange r2 = [e rangeOfString:@"\"" options:NSBackwardsSearch];
        if (r1.location != NSNotFound && r2.location != NSNotFound && r2.location > r1.location) {
            NSString *cls = [e substringWithRange:NSMakeRange(r1.location + 1, r2.location - r1.location - 1)];
            if (cls.length) return [NSString stringWithFormat:@"%@ *", cls];
        }
    }
    
    unichar c = [e characterAtIndex:0];
    switch (c) {
        case 'v': return @"void";
        case '@': return @"id";
        case '#': return @"Class";
        case ':': return @"SEL";
        case 'c': return @"char";
        case 'C': return @"unsigned char";
        case 's': return @"short";
        case 'S': return @"unsigned short";
        case 'i': return @"int";
        case 'I': return @"unsigned int";
        case 'l': return @"long";
        case 'L': return @"unsigned long";
        case 'q': return @"long long";
        case 'Q': return @"unsigned long long";
        case 'f': return @"float";
        case 'd': return @"double";
        case 'B': return @"BOOL";
        case '*': return @"char *";
        case '^': return @"void *";
        case '{': return @"struct";
        case '[': return @"void *";
        default: return @"id";
    }
}

- (NSArray<NSDictionary *> *)getProperties {
    Class cls = NSClassFromString(self.className);
    if (!cls) return @[];
    
    NSMutableArray<NSDictionary *> *props = [NSMutableArray array];
    unsigned int count = 0;
    objc_property_t *properties = class_copyPropertyList(cls, &count);
    
    for (unsigned int i = 0; i < count; i++) {
        objc_property_t property = properties[i];
        const char *name = property_getName(property);
        const char *attrs = property_getAttributes(property);
        
        NSString *propName = name ? [NSString stringWithUTF8String:name] : @"";
        NSString *propAttrs = attrs ? [NSString stringWithUTF8String:attrs] : @"";
        
        NSString *type = @"id";
        NSString *getter = @"";
        NSString *setter = @"";
        BOOL isReadonly = NO;
        BOOL isAtomic = YES;
        BOOL isDynamic = NO;
        NSString *ivar = @"";
        
        NSArray<NSString *> *attrComponents = [propAttrs componentsSeparatedByString:@","];
        for (NSString *comp in attrComponents) {
            if (comp.length == 0) continue;
            if ([comp hasPrefix:@"T"]) {
                NSString *typeEnc = [comp substringFromIndex:1];
                type = [DYYYUCClassHeaderDetailViewController typeFromEncoding:typeEnc.UTF8String];
            } else if ([comp isEqualToString:@"R"]) {
                isReadonly = YES;
            } else if ([comp isEqualToString:@"N"]) {
                isAtomic = NO;
            } else if ([comp isEqualToString:@"D"]) {
                isDynamic = YES;
            } else if ([comp hasPrefix:@"G"]) {
                getter = [comp substringFromIndex:1];
            } else if ([comp hasPrefix:@"S"]) {
                setter = [comp substringFromIndex:1];
            } else if ([comp hasPrefix:@"V"]) {
                ivar = [comp substringFromIndex:1];
            }
        }
        
        if (getter.length == 0) getter = propName;
        if (setter.length == 0 && !isReadonly) {
            NSString *firstChar = [propName substringToIndex:1].uppercaseString;
            NSString *rest = [propName substringFromIndex:1];
            setter = [NSString stringWithFormat:@"set%@%@:", firstChar, rest];
        }
        
        [props addObject:@{
            @"name": propName,
            @"type": type,
            @"typeEncoding": propAttrs.length > 0 ? propAttrs : @"",
            @"getter": getter,
            @"setter": setter,
            @"readonly": @(isReadonly),
            @"atomic": @(isAtomic),
            @"dynamic": @(isDynamic),
            @"ivar": ivar
        }];
    }
    
    free(properties);
    return props;
}

- (NSArray<NSDictionary *> *)getMethods {
    Class cls = NSClassFromString(self.className);
    if (!cls) return @[];
    
    NSMutableArray<NSDictionary *> *methods = [NSMutableArray array];
    unsigned int count = 0;
    Method *methodList = class_copyMethodList(cls, &count);
    
    for (unsigned int i = 0; i < count; i++) {
        Method method = methodList[i];
        SEL sel = method_getName(method);
        const char *name = sel_getName(sel);
        NSString *methodName = name ? [NSString stringWithUTF8String:name] : @"";
        
        const char *encoding = method_getTypeEncoding(method);
        NSString *methodEncoding = encoding ? [NSString stringWithUTF8String:encoding] : @"";
        
        NSUInteger argCount = method_getNumberOfArguments(method);
        
        NSMutableArray<NSString *> *argTypes = [NSMutableArray array];
        for (unsigned int j = 2; j < argCount; j++) {
            char argType[256];
            method_getArgumentType(method, j, argType, 256);
            [argTypes addObject:[NSString stringWithUTF8String:argType]];
        }
        
        char returnType[256];
        method_getReturnType(method, returnType, 256);
        NSString *returnTypeName = [DYYYUCClassHeaderDetailViewController typeFromEncoding:returnType];
        
        IMP imp = method_getImplementation(method);
        
        [methods addObject:@{
            @"name": methodName,
            @"encoding": methodEncoding,
            @"returnType": returnTypeName,
            @"argumentCount": @(argCount - 2),
            @"argumentTypes": argTypes,
            @"implementation": [NSString stringWithFormat:@"%p", imp]
        }];
    }
    
    free(methodList);
    return methods;
}

- (NSArray<NSDictionary *> *)getIvars {
    Class cls = NSClassFromString(self.className);
    if (!cls) return @[];
    
    NSMutableArray<NSDictionary *> *ivars = [NSMutableArray array];
    unsigned int count = 0;
    Ivar *ivarList = class_copyIvarList(cls, &count);
    
    for (unsigned int i = 0; i < count; i++) {
        Ivar ivar = ivarList[i];
        const char *name = ivar_getName(ivar);
        const char *type = ivar_getTypeEncoding(ivar);
        NSString *ivarName = name ? [NSString stringWithUTF8String:name] : @"";
        NSString *typeName = [DYYYUCClassHeaderDetailViewController typeFromEncoding:type];
        ptrdiff_t offset = ivar_getOffset(ivar);
        
        size_t size = 0;
        if (type) {
            char c = type[0];
            switch (c) {
                case 'c': case 'C': case 'B': size = 1; break;
                case 's': case 'S': size = 2; break;
                case 'i': case 'I': case 'l': case 'L': case 'f': size = 4; break;
                case 'q': case 'Q': case 'd': case '@': case '#': case ':': case '^': case '*': size = 8; break;
                default: size = sizeof(id); break;
            }
        }
        
        [ivars addObject:@{
            @"name": ivarName,
            @"type": typeName,
            @"typeEncoding": type ? [NSString stringWithUTF8String:type] : @"",
            @"offset": @(offset),
            @"size": @(size)
        }];
    }
    
    free(ivarList);
    return ivars;
}

- (void)exportIvarsAsJSON {
    NSArray *ivars = [self getIvars];
    NSDictionary *info = @{
        @"className": self.className,
        @"ivarCount": @(ivars.count),
        @"ivars": ivars
    };
    [self exportDictionary:info asFile:[NSString stringWithFormat:@"%@_ivars.json", self.className]];
}

- (void)exportPropertiesAsJSON {
    NSArray *props = [self getProperties];
    NSDictionary *info = @{
        @"className": self.className,
        @"propertyCount": @(props.count),
        @"properties": props
    };
    [self exportDictionary:info asFile:[NSString stringWithFormat:@"%@_properties.json", self.className]];
}

- (void)exportMethodsAsJSON {
    NSArray *methods = [self getMethods];
    NSDictionary *info = @{
        @"className": self.className,
        @"methodCount": @(methods.count),
        @"methods": methods
    };
    [self exportDictionary:info asFile:[NSString stringWithFormat:@"%@_methods.json", self.className]];
}

- (void)exportFullClassInfoAsJSON {
    NSDictionary *info = @{
        @"className": self.className,
        @"properties": [self getProperties],
        @"methods": [self getMethods],
        @"ivars": [self getIvars]
    };
    [self exportDictionary:info asFile:[NSString stringWithFormat:@"%@_info.json", self.className]];
}

- (void)exportDictionary:(NSDictionary *)dict asFile:(NSString *)fileName {
    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:&error];
    if (!jsonData) {
        [self showError:[NSString stringWithFormat:@"JSON 生成失败: %@", error.localizedDescription]];
        return;
    }
    
    NSString *tmpPath = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
    BOOL success = [jsonData writeToFile:tmpPath atomically:YES];
    if (!success) {
        [self showError:@"文件写入失败"];
        return;
    }
    
    [self shareFileAtPath:tmpPath];
}

- (void)shareFileAtPath:(NSString *)path {
    NSURL *fileURL = [NSURL fileURLWithPath:path];
    UIViewController *activityVC = [DYYYFLEXActivityViewController sharing:@[fileURL] source:self.navigationItem.rightBarButtonItems.firstObject];
    [self presentViewController:activityVC animated:YES completion:nil];
}

- (void)showError:(NSString *)message {
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"错误"
        message:message
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    self.searchText = searchText;
    [self refreshHighlight];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

#pragma mark - 搜索高亮

- (void)refreshHighlight {
    if (self.headerContent.length == 0) return;
    
    NSString *search = self.searchText.lowercaseString;
    if (search.length == 0) {
        self.textView.attributedText = [[NSAttributedString alloc]
            initWithString:self.headerContent
            attributes:@{NSFontAttributeName: [UIFont fontWithName:@"Menlo-Regular" size:self.fontSize],
                         NSForegroundColorAttributeName: DYYYFLEXColor.primaryTextColor}];
        self.matchRanges = @[];
        return;
    }
    
    NSMutableAttributedString *attrText = [[NSMutableAttributedString alloc]
        initWithString:self.headerContent
        attributes:@{NSFontAttributeName: [UIFont fontWithName:@"Menlo-Regular" size:self.fontSize],
                     NSForegroundColorAttributeName: DYYYFLEXColor.primaryTextColor}];
    
    NSMutableArray<NSValue *> *ranges = [NSMutableArray array];
    NSString *text = self.headerContent.lowercaseString;
    NSRange searchRange = NSMakeRange(0, text.length);
    
    while (searchRange.location < text.length) {
        NSRange foundRange = [text rangeOfString:search options:0 range:searchRange];
        if (foundRange.location == NSNotFound) break;
        
        [ranges addObject:[NSValue valueWithRange:foundRange]];
        [attrText addAttribute:NSBackgroundColorAttributeName
                         value:[UIColor colorWithRed:1.0 green:1.0 blue:0.0 alpha:0.4]
                         range:foundRange];
        
        searchRange.location = foundRange.location + foundRange.length;
        searchRange.length = text.length - searchRange.location;
    }
    
    self.matchRanges = ranges;
    self.currentMatchIndex = 0;
    self.textView.attributedText = attrText;
    
    if (ranges.count > 0) {
        [self scrollToMatch:0];
    }
}

- (void)scrollToMatch:(NSInteger)index {
    if (index < 0 || index >= self.matchRanges.count) return;
    
    NSRange range = [self.matchRanges[index] rangeValue];
    [self.textView scrollRangeToVisible:range];
}

@end
