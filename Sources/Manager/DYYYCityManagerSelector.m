#import "DYYYCityManagerPrivate.h"
#import <objc/runtime.h>

@implementation DYYYCityManager (Selector)
- (void)showCitySelectorInViewController:(UIViewController *)viewController 
                                delegate:(id<CitySelectorDelegate>)delegate
                    initialSelectedCode:(NSString *)initialCode {
    // 创建一个简单的四级联动选择器视图控制器
    UIViewController *pickerVC = [[UIViewController alloc] init];
    pickerVC.modalPresentationStyle = UIModalPresentationFormSheet;
    pickerVC.view.backgroundColor = [UIColor whiteColor];
    
    // 标题
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 20, viewController.view.bounds.size.width, 40)];
    titleLabel.text = @"选择地区";
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.font = [UIFont boldSystemFontOfSize:18];
    [pickerVC.view addSubview:titleLabel];
    
    // 保存当前选择的值
    __block NSString *selectedProvinceCode = nil;
    __block NSString *selectedProvinceName = nil;
    __block NSString *selectedCityCode = nil;
    __block NSString *selectedCityName = nil;
    __block NSString *selectedDistrictCode = nil;
    __block NSString *selectedDistrictName = nil;
    
    // 如果有初始代码，尝试解析并预选
    if (initialCode.length >= 2) {
        NSString *provincePrefix = [initialCode substringToIndex:2];
        NSString *guessedProvinceCode = [provincePrefix stringByAppendingString:@"0000"];
        selectedProvinceName = [self getProvinceNameWithCode:guessedProvinceCode];
        selectedProvinceCode = guessedProvinceCode;
        
        if (initialCode.length >= 4) {
            NSString *cityPrefix = [initialCode substringToIndex:4];
            NSString *guessedCityCode = [cityPrefix stringByAppendingString:@"00"];
            selectedCityName = [self getCityNameWithCode:guessedCityCode];
            selectedCityCode = guessedCityCode;
            
            if (initialCode.length >= 6) {
                selectedDistrictCode = initialCode;
                selectedDistrictName = [self getDistrictNameWithCode:initialCode];
            }
        }
    }
    
    // 创建四个 UIPickerView 容器视图
    UIView *pickerContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 60, viewController.view.bounds.size.width, 200)];
    [pickerVC.view addSubview:pickerContainer];
    
    // 1. 省份选择器
    UIPickerView *provincePicker = [[UIPickerView alloc] initWithFrame:CGRectMake(0, 0, pickerContainer.bounds.size.width, 200)];
    provincePicker.tag = 1;
    // 2. 城市选择器
    UIPickerView *cityPicker = [[UIPickerView alloc] initWithFrame:CGRectMake(0, 0, pickerContainer.bounds.size.width, 200)];
    cityPicker.tag = 2;
    cityPicker.hidden = YES;
    // 3. 区县选择器
    UIPickerView *districtPicker = [[UIPickerView alloc] initWithFrame:CGRectMake(0, 0, pickerContainer.bounds.size.width, 200)];
    districtPicker.tag = 3;
    districtPicker.hidden = YES;
    // 4. 街道选择器
    UIPickerView *streetPicker = [[UIPickerView alloc] initWithFrame:CGRectMake(0, 0, pickerContainer.bounds.size.width, 200)];
    streetPicker.tag = 4;
    streetPicker.hidden = YES;
    
    [pickerContainer addSubview:provincePicker];
    [pickerContainer addSubview:cityPicker];
    [pickerContainer addSubview:districtPicker];
    [pickerContainer addSubview:streetPicker];
    
    // 获取所有省份
    NSMutableArray<NSString *> *provinceNames = [NSMutableArray array];
    NSMutableArray<NSString *> *provinceCodes = [NSMutableArray array];
    
    [self.provincesDict enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSString * _Nonnull name, BOOL * _Nonnull stop) {
        [provinceNames addObject:name];
        [provinceCodes addObject:key];
    }];
    
    // 对数据进行排序
    NSMutableArray *tempArray = [NSMutableArray array];
    for (NSInteger i = 0; i < provinceNames.count; i++) {
        [tempArray addObject:@{@"name": provinceNames[i], @"code": provinceCodes[i]}];
    }
    
    [tempArray sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        NSString *code1 = [obj1 objectForKey:@"code"];
        NSString *code2 = [obj2 objectForKey:@"code"];
        return [code1 compare:code2];
    }];
    
    [provinceNames removeAllObjects];
    [provinceCodes removeAllObjects];
    
    for (NSDictionary *dict in tempArray) {
        [provinceNames addObject:dict[@"name"]];
        [provinceCodes addObject:dict[@"code"]];
    }
    
    // 城市和区县数据数组 (会在选择省份时填充)
    __block NSMutableArray<NSString *> *cityNames = [NSMutableArray array];
    __block NSMutableArray<NSString *> *cityCodes = [NSMutableArray array];
    __block NSMutableArray<NSString *> *districtNames = [NSMutableArray array];
    __block NSMutableArray<NSString *> *districtCodes = [NSMutableArray array];
    __block NSMutableArray<NSString *> *streetNames = [NSMutableArray array];
    __block NSMutableArray<NSString *> *streetCodes = [NSMutableArray array];
    
    // 数据源和代理
    id<UIPickerViewDataSource, UIPickerViewDelegate> dataSource = [[NSObject alloc] init];
    
    // 使用runtime添加方法
    class_addMethod([dataSource class], @selector(numberOfComponentsInPickerView:), 
        (IMP)imp_implementationWithBlock(^NSInteger(id self, UIPickerView *pickerView) {
        return 1;
    }), "l@:@");
    
    class_addMethod([dataSource class], @selector(pickerView:numberOfRowsInComponent:), 
        (IMP)imp_implementationWithBlock(^NSInteger(id self, UIPickerView *pickerView, NSInteger component) {
        switch (pickerView.tag) {
            case 1: return provinceNames.count;
            case 2: return cityNames.count;
            case 3: return districtNames.count;
            case 4: return streetNames.count;
            default: return 0;
        }
    }), "l@:@l");
    
    class_addMethod([dataSource class], @selector(pickerView:titleForRow:forComponent:), 
        (IMP)imp_implementationWithBlock(^NSString *(id self, UIPickerView *pickerView, NSInteger row, NSInteger component) { 
        switch (pickerView.tag) {
            case 1: return provinceNames[row];
            case 2: return cityNames[row];
            case 3: return districtNames[row];
            case 4: return streetNames[row];
            default: return @"";
        }
    }), "@@:@ll");
    
    class_addMethod([dataSource class], @selector(pickerView:didSelectRow:inComponent:), 
        (IMP)imp_implementationWithBlock(^(id self, UIPickerView *pickerView, NSInteger row, NSInteger component) {
        switch (pickerView.tag) {
            case 1: {
                // 选择省份后，更新城市列表
                selectedProvinceCode = provinceCodes[row];
                selectedProvinceName = provinceNames[row];
                
                [cityNames removeAllObjects];
                [cityCodes removeAllObjects];
                
                // 获取该省份下所有城市
                NSDictionary<NSString *, NSString *> *cities = [[DYYYCityManager sharedInstance] getCitiesInProvince:selectedProvinceCode];
                
                // 将字典转换为排序数组
                NSMutableArray *tempCities = [NSMutableArray array];
                [cities enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSString * _Nonnull name, BOOL * _Nonnull stop) {
                    [tempCities addObject:@{@"name": name, @"code": key}];
                }];
                
                [tempCities sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
                    NSString *code1 = [obj1 objectForKey:@"code"];
                    NSString *code2 = [obj2 objectForKey:@"code"];
                    return [code1 compare:code2];
                }];
                
                for (NSDictionary *dict in tempCities) {
                    [cityNames addObject:dict[@"name"]];
                    [cityCodes addObject:dict[@"code"]];
                }
                
                // 重置区和街道
                selectedCityCode = nil;
                selectedCityName = nil;
                selectedDistrictCode = nil;
                selectedDistrictName = nil;
                
                [districtNames removeAllObjects];
                [districtCodes removeAllObjects];
                [streetNames removeAllObjects];
                [streetCodes removeAllObjects];
                
                // 更新界面
                [cityPicker reloadAllComponents];
                cityPicker.hidden = NO;
                districtPicker.hidden = YES;
                streetPicker.hidden = YES;
                
                break;
            }
            case 2: {
                // 选择城市后，更新区县列表
                if (row < cityCodes.count) {
                    selectedCityCode = cityCodes[row];
                    selectedCityName = cityNames[row];
                    
                    [districtNames removeAllObjects];
                    [districtCodes removeAllObjects];
                    
                    // 获取该城市下所有区县
                    NSDictionary<NSString *, NSString *> *districts = [[DYYYCityManager sharedInstance] getDistrictsInCity:selectedCityCode];
                    
                    // 将字典转换为排序数组
                    NSMutableArray *tempDistricts = [NSMutableArray array];
                    [districts enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSString * _Nonnull name, BOOL * _Nonnull stop) {
                        [tempDistricts addObject:@{@"name": name, @"code": key}];
                    }];
                    
                    [tempDistricts sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
                        NSString *code1 = [obj1 objectForKey:@"code"];
                        NSString *code2 = [obj2 objectForKey:@"code"];
                        return [code1 compare:code2];
                    }];
                    
                    for (NSDictionary *dict in tempDistricts) {
                        [districtNames addObject:dict[@"name"]];
                        [districtCodes addObject:dict[@"code"]];
                    }
                    
                    // 重置街道
                    selectedDistrictCode = nil;
                    selectedDistrictName = nil;
                    
                    [streetNames removeAllObjects];
                    [streetCodes removeAllObjects];
                    
                    // 更新界面
                    [districtPicker reloadAllComponents];
                    districtPicker.hidden = NO;
                    streetPicker.hidden = YES;
                }
                break;
            }
            case 3: {
                // 选择区县后，更新街道列表
                if (row < districtCodes.count) {
                    selectedDistrictCode = districtCodes[row];
                    selectedDistrictName = districtNames[row];
                    
                    [streetNames removeAllObjects];
                    [streetCodes removeAllObjects];
                    
                    // 获取该区县下所有街道
                    NSArray<NSString *> *streets = [[DYYYCityManager sharedInstance] getStreetsInDistrict:selectedDistrictCode];
                    
                    for (int i = 0; i < streets.count; i++) {
                        [streetNames addObject:streets[i]];
                        [streetCodes addObject:[NSString stringWithFormat:@"%@%03d", selectedDistrictCode, i+1]];
                    }
                    
                    // 更新界面
                    [streetPicker reloadAllComponents];
                    streetPicker.hidden = (streets.count == 0);
                }
                break;
            }
            case 4: {
                // 选择了街道，但我们不需要更新任何东西
                break;
            }
        }
    }), "v@:@ll");
    
    provincePicker.dataSource = dataSource;
    provincePicker.delegate = dataSource;
    cityPicker.dataSource = dataSource;
    cityPicker.delegate = dataSource;
    districtPicker.dataSource = dataSource;
    districtPicker.delegate = dataSource;
    streetPicker.dataSource = dataSource;
    streetPicker.delegate = dataSource;
    
    // 添加按钮
    UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
    cancelButton.frame = CGRectMake(20, pickerContainer.frame.origin.y + pickerContainer.frame.size.height + 20, 100, 44);
    [cancelButton setTitle:@"取消" forState:UIControlStateNormal];
    [cancelButton addTarget:pickerVC action:@selector(dismissViewControllerAnimated:completion:) forControlEvents:UIControlEventTouchUpInside];
    [pickerVC.view addSubview:cancelButton];
    
    UIButton *confirmButton = [UIButton buttonWithType:UIButtonTypeSystem];
    confirmButton.frame = CGRectMake(pickerVC.view.bounds.size.width - 120, pickerContainer.frame.origin.y + pickerContainer.frame.size.height + 20, 100, 44);
    [confirmButton setTitle:@"确定" forState:UIControlStateNormal];
    [pickerVC.view addSubview:confirmButton];
    
    // 确认按钮事件
    [confirmButton addTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
    objc_setAssociatedObject(confirmButton, "confirmAction", ^{
        // 当选择完成后调用代理方法
        if ([delegate respondsToSelector:@selector(citySelectorDidSelect:provinceName:cityCode:cityName:districtCode:districtName:)]) {
            [delegate citySelectorDidSelect:selectedProvinceCode 
                             provinceName:selectedProvinceName 
                                 cityCode:selectedCityCode 
                                 cityName:selectedCityName 
                             districtCode:selectedDistrictCode 
                             districtName:selectedDistrictName];
        }
        [pickerVC dismissViewControllerAnimated:YES completion:nil];
    }, OBJC_ASSOCIATION_COPY);
    
    // 使用方法交换为按钮添加事件处理
    Method originalMethod = class_getInstanceMethod([confirmButton class], @selector(sendAction:to:forEvent:));
    Method swizzledMethod = class_getInstanceMethod([NSObject class], @selector(confirmButton_sendAction:to:forEvent:));
    if (!swizzledMethod) {
        class_addMethod([NSObject class], @selector(confirmButton_sendAction:to:forEvent:), imp_implementationWithBlock(^(id self, SEL action, id target, UIEvent *event) {
            // 调用原始方法
            ((void (*)(id, SEL, SEL, id, UIEvent *))objc_msgSend)(self, @selector(confirmButton_sendAction:to:forEvent:), action, target, event);
            
            // 执行确认操作
            void (^confirmAction)(void) = objc_getAssociatedObject(self, "confirmAction");
            if (confirmAction) {
                confirmAction();
            }
        }), method_getTypeEncoding(originalMethod));
        swizzledMethod = class_getInstanceMethod([NSObject class], @selector(confirmButton_sendAction:to:forEvent:));
    }
    method_exchangeImplementations(originalMethod, swizzledMethod);
    
    // 如果有初始代码，尝试预选
    if (selectedProvinceCode) {
        for (NSInteger i = 0; i < provinceCodes.count; i++) {
            if ([provinceCodes[i] isEqualToString:selectedProvinceCode]) {
                [provincePicker selectRow:i inComponent:0 animated:NO];
                [provincePicker.delegate pickerView:provincePicker didSelectRow:i inComponent:0];
                
                if (selectedCityCode) {
                    for (NSInteger j = 0; j < cityCodes.count; j++) {
                        if ([cityCodes[j] isEqualToString:selectedCityCode]) {
                            [cityPicker selectRow:j inComponent:0 animated:NO];
                            [cityPicker.delegate pickerView:cityPicker didSelectRow:j inComponent:0];
                            
                            if (selectedDistrictCode) {
                                for (NSInteger k = 0; k < districtCodes.count; k++) {
                                    if ([districtCodes[k] isEqualToString:selectedDistrictCode]) {
                                        [districtPicker selectRow:k inComponent:0 animated:NO];
                                        [districtPicker.delegate pickerView:districtPicker didSelectRow:k inComponent:0];
                                        break;
                                    }
                                }
                            }
                            break;
                        }
                    }
                }
                break;
            }
        }
    }
    
    [viewController presentViewController:pickerVC animated:YES completion:nil];
}
@end
