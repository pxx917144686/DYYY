#import "DYYYCityManagerPrivate.h"

@implementation DYYYCityManager (Address)
- (NSString *)generateRandomFourLevelAddressForCityCode:(NSString *)cityCode {
    // 检查缓存
    NSString *cachedAddress = self.addressCache[cityCode];
    if (cachedAddress) {
        return cachedAddress;
    }
    
    __block NSString *provinceName = @"";
    __block NSString *cityName = @"";
    __block NSString *districtName = @"";
    __block NSString *streetName = @"";
    
    // 1. 获取省份
    NSString *provinceCode = cityCode.length >= 2 ? [[cityCode substringToIndex:2] stringByAppendingString:@"0000"] : @"000000";
    provinceName = [self getProvinceNameWithCode:provinceCode] ?: provinceName;

    // 2. 获取城市
    cityName = [self getCityNameWithCode:cityCode] ?: cityName;

    // 3. 获取区县
    NSDictionary *districts = [self getDistrictsInCity:cityCode];
    if (districts.count > 0) {
        NSArray *districtCodes = [districts allKeys];
        NSString *randomDistrictCode = districtCodes[arc4random_uniform((uint32_t)districtCodes.count)];
        districtName = districts[randomDistrictCode] ?: districtName;
    } else {
        // 基于城市代码选择真实区县名称
        NSDictionary *fallbackDistricts = @{
            // 直辖市
            @"110100": @[@"朝阳区", @"海淀区", @"东城区", @"西城区", @"通州区", @"丰台区", @"石景山区", @"昌平区"],
            @"120100": @[@"和平区", @"河东区", @"河西区", @"南开区", @"河北区", @"红桥区", @"滨海新区", @"东丽区"],
            @"310100": @[@"浦东新区", @"徐汇区", @"黄浦区", @"静安区", @"长宁区", @"普陀区", @"虹口区", @"杨浦区"],
            @"500100": @[@"渝中区", @"江北区", @"南岸区", @"沙坪坝区", @"九龙坡区", @"大渡口区", @"渝北区", @"巴南区"],
            
            // 河北省
            @"130100": @[@"长安区", @"桥西区", @"新华区", @"裕华区", @"井陉矿区", @"藁城区", @"鹿泉区", @"栾城区"],
            @"130200": @[@"路南区", @"路北区", @"开平区", @"丰南区", @"丰润区", @"曹妃甸区", @"古冶区", @"高新区"],
            @"130300": @[@"海港区", @"山海关区", @"北戴河区", @"抚宁区", @"昌黎县", @"青龙县", @"卢龙县"],
            
            // 山西省
            @"140100": @[@"小店区", @"迎泽区", @"杏花岭区", @"尖草坪区", @"万柏林区", @"晋源区", @"古交市", @"清徐县"],
            @"140200": @[@"城区", @"矿区", @"南郊区", @"新荣区", @"阳高县", @"天镇县", @"广灵县", @"灵丘县"],
            
            // 内蒙古
            @"150100": @[@"回民区", @"新城区", @"玉泉区", @"赛罕区", @"土默特左旗", @"托克托县", @"和林格尔县"],
            @"150200": @[@"东河区", @"昆都仑区", @"青山区", @"石拐区", @"白云鄂博矿区", @"九原区", @"土默特右旗"],
            
            // 辽宁省
            @"210100": @[@"和平区", @"沈河区", @"大东区", @"皇姑区", @"铁西区", @"苏家屯区", @"浑南区", @"于洪区"],
            @"210200": @[@"中山区", @"西岗区", @"沙河口区", @"甘井子区", @"旅顺口区", @"金州区", @"普兰店区", @"瓦房店市"],
            
            // 吉林省
            @"220100": @[@"南关区", @"宽城区", @"朝阳区", @"二道区", @"绿园区", @"双阳区", @"九台区", @"榆树市"],
            @"220200": @[@"昌邑区", @"龙潭区", @"船营区", @"丰满区", @"蛟河市", @"桦甸市", @"舒兰市", @"磐石市"],
            
            // 黑龙江省
            @"230100": @[@"道里区", @"南岗区", @"道外区", @"平房区", @"松北区", @"香坊区", @"呼兰区", @"阿城区"],
            @"230200": @[@"龙沙区", @"建华区", @"铁锋区", @"昂昂溪区", @"富拉尔基区", @"碾子山区", @"梅里斯区"],
            
            // 江苏省
            @"320100": @[@"玄武区", @"秦淮区", @"建邺区", @"鼓楼区", @"浦口区", @"栖霞区", @"雨花台区", @"江宁区"],
            @"320200": @[@"锡山区", @"惠山区", @"滨湖区", @"梁溪区", @"新吴区", @"江阴市", @"宜兴市"],
            @"320300": @[@"鼓楼区", @"云龙区", @"贾汪区", @"泉山区", @"铜山区", @"丰县", @"沛县", @"睢宁县"],
            @"320400": @[@"天宁区", @"钟楼区", @"新北区", @"武进区", @"金坛区", @"溧阳市"],
            @"320500": @[@"虎丘区", @"吴中区", @"相城区", @"姑苏区", @"吴江区", @"常熟市", @"张家港市", @"昆山市"],
            
            // 浙江省
            @"330100": @[@"西湖区", @"滨江区", @"上城区", @"下城区", @"余杭区", @"拱墅区", @"江干区", @"萧山区", @"富阳区"],
            @"330200": @[@"海曙区", @"江北区", @"北仑区", @"镇海区", @"鄞州区", @"奉化区", @"余姚市", @"慈溪市"],
            @"330300": @[@"鹿城区", @"龙湾区", @"瓯海区", @"洞头区", @"永嘉县", @"平阳县", @"苍南县", @"文成县"],
            
            // 安徽省
            @"340100": @[@"瑶海区", @"庐阳区", @"蜀山区", @"包河区", @"长丰县", @"肥东县", @"肥西县", @"庐江县"],
            @"340200": @[@"镜湖区", @"弋江区", @"鸠江区", @"三山区", @"芜湖县", @"繁昌县", @"南陵县", @"无为市"],
            
            // 福建省
            @"350100": @[@"鼓楼区", @"台江区", @"仓山区", @"马尾区", @"晋安区", @"长乐区", @"闽侯县", @"连江县"],
            @"350200": @[@"思明区", @"海沧区", @"湖里区", @"集美区", @"同安区", @"翔安区"],
            @"350300": @[@"城厢区", @"涵江区", @"荔城区", @"秀屿区", @"仙游县"],
            
            // 江西省
            @"360100": @[@"东湖区", @"西湖区", @"青云谱区", @"湾里区", @"青山湖区", @"新建区", @"南昌县", @"安义县"],
            @"360200": @[@"昌江区", @"珠山区", @"浮梁县", @"乐平市"],
            
            // 山东省
            @"370100": @[@"历下区", @"市中区", @"槐荫区", @"天桥区", @"历城区", @"长清区", @"章丘区", @"济阳区"],
            @"370200": @[@"市南区", @"市北区", @"黄岛区", @"崂山区", @"李沧区", @"城阳区", @"即墨区", @"胶州市"],
            @"370300": @[@"淄川区", @"张店区", @"博山区", @"临淄区", @"周村区", @"桓台县", @"高青县", @"沂源县"],
            @"370400": @[@"市中区", @"薛城区", @"峄城区", @"台儿庄区", @"山亭区", @"滕州市"],
            
            // 河南省
            @"410100": @[@"中原区", @"二七区", @"管城回族区", @"金水区", @"上街区", @"惠济区", @"中牟县", @"巩义市"],
            @"410200": @[@"龙亭区", @"顺河回族区", @"鼓楼区", @"禹王台区", @"祥符区", @"杞县", @"通许县", @"尉氏县"],
            @"410300": @[@"老城区", @"西工区", @"瀍河回族区", @"涧西区", @"吉利区", @"洛龙区", @"孟津县", @"新安县"],
            
            // 湖北省
            @"420100": @[@"江岸区", @"江汉区", @"硚口区", @"汉阳区", @"武昌区", @"青山区", @"洪山区", @"东西湖区"],
            @"420200": @[@"黄石港区", @"西塞山区", @"下陆区", @"铁山区", @"阳新县", @"大冶市"],
            @"420300": @[@"茅箭区", @"张湾区", @"郧阳区", @"郧西县", @"竹山县", @"竹溪县", @"房县", @"丹江口市"],
            
            // 湖南省
            @"430100": @[@"芙蓉区", @"天心区", @"岳麓区", @"开福区", @"雨花区", @"望城区", @"长沙县", @"浏阳市"],
            @"430200": @[@"荷塘区", @"芦淞区", @"石峰区", @"天元区", @"渌口区", @"攸县", @"茶陵县", @"炎陵县"],
            @"430300": @[@"雨湖区", @"岳塘区", @"湘潭县", @"湘乡市", @"韶山市"],
            
            // 广东省
            @"440100": @[@"天河区", @"越秀区", @"海珠区", @"白云区", @"黄埔区", @"荔湾区", @"番禺区", @"花都区", @"南沙区"],
            @"440200": @[@"武江区", @"浈江区", @"曲江区", @"始兴县", @"仁化县", @"翁源县", @"乐昌市", @"南雄市"],
            @"440300": @[@"罗湖区", @"福田区", @"南山区", @"宝安区", @"龙岗区", @"盐田区", @"龙华区", @"坪山区"],
            @"440400": @[@"香洲区", @"斗门区", @"金湾区"],
            @"440500": @[@"龙湖区", @"金平区", @"濠江区", @"潮阳区", @"潮南区", @"澄海区", @"南澳县"],
            
            // 广西壮族自治区
            @"450100": @[@"兴宁区", @"青秀区", @"江南区", @"西乡塘区", @"良庆区", @"邕宁区", @"武鸣区", @"隆安县"],
            @"450200": @[@"城中区", @"鱼峰区", @"柳南区", @"柳北区", @"柳江区", @"柳城县", @"鹿寨县", @"融安县"],
            
            // 海南省
            @"460100": @[@"秀英区", @"龙华区", @"琼山区", @"美兰区"],
            @"460200": @[@"海棠区", @"吉阳区", @"天涯区", @"崖州区"],
            
            // 四川省
            @"510100": @[@"锦江区", @"青羊区", @"金牛区", @"武侯区", @"成华区", @"龙泉驿区", @"青白江区", @"新都区"],
            @"510300": @[@"自流井区", @"贡井区", @"大安区", @"沿滩区", @"荣县", @"富顺县"],
            @"510400": @[@"东区", @"西区", @"仁和区", @"米易县", @"盐边县"],
            
            // 贵州省
            @"520100": @[@"南明区", @"云岩区", @"花溪区", @"乌当区", @"白云区", @"观山湖区", @"开阳县", @"息烽县"],
            @"520200": @[@"钟山区", @"六枝特区", @"水城县", @"盘州市"],
            
            // 云南省
            @"530100": @[@"五华区", @"盘龙区", @"官渡区", @"西山区", @"东川区", @"呈贡区", @"晋宁区", @"富民县"],
            @"530300": @[@"红塔区", @"江川区", @"澄江县", @"通海县", @"华宁县", @"易门县", @"峨山县", @"新平县"],
            
            // 西藏自治区
            @"540100": @[@"城关区", @"堆龙德庆区", @"达孜区", @"林周县", @"当雄县", @"尼木县", @"曲水县", @"墨竹工卡县"],
            @"540200": @[@"桑珠孜区", @"南木林县", @"江孜县", @"定日县", @"萨迦县", @"拉孜县", @"昂仁县", @"谢通门县"],
            
            // 陕西省
            @"610100": @[@"新城区", @"碑林区", @"莲湖区", @"灞桥区", @"未央区", @"雁塔区", @"阎良区", @"临潼区"],
            @"610200": @[@"王益区", @"印台区", @"耀州区", @"宜君县"],
            @"610300": @[@"渭滨区", @"金台区", @"陈仓区", @"凤翔县", @"岐山县", @"扶风县", @"眉县", @"陇县"],
            
            // 甘肃省
            @"620100": @[@"城关区", @"七里河区", @"西固区", @"安宁区", @"红古区", @"永登县", @"皋兰县", @"榆中县"],
            @"620200": @[@"嘉峪关市区"], // 嘉峪关市不设区
            @"620300": @[@"金川区", @"永昌县"],
            
            // 青海省
            @"630100": @[@"城东区", @"城中区", @"城西区", @"城北区", @"大通回族土族自治县", @"湟中县", @"湟源县"],
            @"630200": @[@"乐都区", @"平安区", @"民和回族土族自治县", @"互助土族自治县", @"化隆回族自治县", @"循化撒拉族自治县"],
            
            // 宁夏回族自治区
            @"640100": @[@"兴庆区", @"西夏区", @"金凤区", @"永宁县", @"贺兰县", @"灵武市"],
            @"640200": @[@"大武口区", @"惠农区", @"平罗县"],
            
            // 新疆维吾尔自治区
            @"650100": @[@"天山区", @"沙依巴克区", @"新市区", @"水磨沟区", @"头屯河区", @"达坂城区", @"米东区", @"乌鲁木齐县"],
            @"650200": @[@"独山子区", @"克拉玛依区", @"白碱滩区", @"乌尔禾区"],
            
            // 香港特别行政区
            @"810000": @[@"中西区", @"湾仔区", @"东区", @"南区", @"油尖旺区", @"深水埗区", @"九龙城区", @"黄大仙区"],
            
            // 澳门特别行政区
            @"820000": @[@"花地玛堂区", @"花王堂区", @"望德堂区", @"大堂区", @"风顺堂区", @"嘉模堂区"],
            
            // 台湾省主要城市
            @"710100": @[@"中正区", @"大同区", @"中山区", @"松山区", @"大安区", @"万华区", @"信义区", @"士林区"],
            
            // 默认
            @"000000": @[@"中心区", @"新城区", @"高新区", @"经济开发区", @"工业园区"]
        };
        NSString *key = cityCode.length >= 6 ? cityCode : @"000000";
        NSArray *districtPool = fallbackDistricts[key] ?: fallbackDistricts[@"000000"];
        districtName = districtPool[arc4random_uniform((uint32_t)districtPool.count)];
    }

    // 4. 获取街道
    NSArray *streets = [self getStreetsInDistrict:districtName];
    if (streets.count > 0) {
        streetName = streets[arc4random_uniform((uint32_t)streets.count)] ?: streetName;
    } else {
        // 基于区县生成真实感街道 - 使用真实街道命名规则
        // 提取区县关键词（去掉"区"、"新区"、"县"等后缀）
        NSString *districtKey = districtName;
        NSArray *suffixes = @[@"新区", @"自治县", @"回族区", @"满族区", @"藏族区", @"壮族区",
                              @"维吾尔区", @"蒙古区", @"朝鲜区", @"苗族区", @"彝族区", @"瑶族区",
                              @"土家族区", @"哈尼族区", @"哈萨克区", @"傣族区", @"黎族区",
                              @"傈僳族区", @"佤族区", @"畲族区", @"高山族区", @"拉祜族区",
                              @"水族", @"东乡族", @"纳西族", @"景颇族", @"柯尔克孜族",
                              @"土族", @"达斡尔族", @"仫佬族", @"羌族", @"布朗族",
                              @"撒拉族", @"毛南族", @"仡佬族", @"锡伯族", @"阿昌族",
                              @"普米族", @"朝鲜族", @"塔吉克族", @"怒族", @"乌孜别克族",
                              @"俄罗斯族", @"鄂温克族", @"德昂族", @"保安族", @"裕固族",
                              @"京族", @"塔塔尔族", @"独龙族", @"鄂伦春族", @"赫哲族",
                              @"门巴族", @"珞巴族", @"基诺族",
                              @"区", @"县", @"市", @"旗", @"自治旗"];
        for (NSString *suffix in suffixes) {
            if ([districtName hasSuffix:suffix]) {
                districtKey = [districtName substringToIndex:districtName.length - suffix.length];
                break;
            }
        }
        
        // 根据城市特色选择街道类型权重
        NSArray *roadTypes;
        NSString *provincePrefix = cityCode.length >= 2 ? [cityCode substringToIndex:2] : @"00";
        if ([provincePrefix isEqualToString:@"11"]) {
            // 北京：胡同、里、条、巷
            roadTypes = @[@"胡同", @"街", @"路", @"里", @"条", @"巷", @"大街", @"社区"];
        } else if ([provincePrefix isEqualToString:@"31"]) {
            // 上海：弄、坊、里、路
            roadTypes = @[@"路", @"街", @"弄", @"坊", @"里", @"新村", @"大道", @"小区"];
        } else if ([provincePrefix isEqualToString:@"12"]) {
            // 天津：胡同、里、街
            roadTypes = @[@"胡同", @"街", @"路", @"里", @"大道", @"社区", @"新村", @"小区"];
        } else if ([provincePrefix isEqualToString:@"50"]) {
            // 重庆：坡、坎、巷、梯
            roadTypes = @[@"路", @"街", @"巷", @"坡", @"坎", @"社区", @"小区", @"新村"];
        } else if ([provincePrefix isEqualToString:@"32"] || [provincePrefix isEqualToString:@"33"]) {
            // 江浙：弄、坊、巷
            roadTypes = @[@"路", @"街", @"弄", @"坊", @"巷", @"新村", @"社区", @"小区"];
        } else if ([provincePrefix isEqualToString:@"44"] || [provincePrefix isEqualToString:@"45"]) {
            // 两广：大道、路、街
            roadTypes = @[@"大道", @"路", @"街", @"巷", @"社区", @"小区", @"广场", @"花园"];
        } else if ([provincePrefix isEqualToString:@"51"] || [provincePrefix isEqualToString:@"52"] || [provincePrefix isEqualToString:@"53"]) {
            // 西南：街、巷、路
            roadTypes = @[@"街", @"路", @"巷", @"社区", @"小区", @"花园", @"新村", @"广场"];
        } else {
            // 其他：路、街为主
            roadTypes = @[@"路", @"街", @"巷", @"社区", @"小区", @"花园", @"新村", @"广场"];
        }
        
        NSString *roadType = roadTypes[arc4random_uniform((uint32_t)roadTypes.count)];
        
        // 生成街道名称的多种真实模式
        NSInteger nameMode = arc4random_uniform(7);
        NSMutableString *streetBase = [NSMutableString string];
        
        if (nameMode == 0) {
            // 模式1：数字序号（最常见，如"五一路"、"三道街"）
            NSArray *numberPrefixes = @[@"一", @"二", @"三", @"四", @"五", @"六", @"七", @"八", @"九", @"十",
                                        @"十一", @"十二", @"十三", @"十四", @"十五", @"十六", @"十七", @"十八", @"十九", @"二十",
                                        @"廿一", @"廿二", @"廿三", @"廿四", @"廿五"];
            NSArray *numberFormats = @[@"%@%@", @"第%@%@", @"%@道", @"%@路", @"%@大街", @"%@条"];
            NSString *num = numberPrefixes[arc4random_uniform((uint32_t)numberPrefixes.count)];
            NSString *fmt = numberFormats[arc4random_uniform((uint32_t)numberFormats.count)];
            streetName = [NSString stringWithFormat:fmt, num, roadType];
            if ([streetName hasSuffix:roadType] && streetName.length > roadType.length + 1) {
                // 已经有后缀了
            } else {
                streetName = [streetName stringByAppendingString:roadType];
            }
            
        } else if (nameMode == 1) {
            // 模式2：方位词（如"东街"、"北门外"、"南关"）
            NSArray *directionPrefixes = @[@"东", @"西", @"南", @"北", @"中", @"前", @"后", @"左", @"右",
                                            @"上", @"下", @"里", @"外", @"内", @"新", @"旧", @"大", @"小"];
            NSArray *directionSuffixes = @[@"门", @"关", @"口", @"头", @"尾", @"梢", @"坡", @"岗",
                                            @"桥", @"坝", @"堰", @"塘", @"湾", @"滩", @"洲", @"岛"];
            NSString *dir = directionPrefixes[arc4random_uniform((uint32_t)directionPrefixes.count)];
            if (arc4random_uniform(2) == 0) {
                streetBase.string = [NSString stringWithFormat:@"%@%@", dir, roadType];
            } else {
                NSString *suf = directionSuffixes[arc4random_uniform((uint32_t)directionSuffixes.count)];
                streetBase.string = [NSString stringWithFormat:@"%@%@%@", dir, districtKey.length > 0 ? districtKey : @"城", suf];
            }
            streetName = streetBase;
            
        } else if (nameMode == 2) {
            // 模式3：山/水/自然景观名（如"虎山路"、"长江街"、"湖滨巷"）
            NSArray *mountainNames = @[@"泰山", @"华山", @"衡山", @"恒山", @"嵩山", @"黄山", @"庐山",
                                       @"峨眉山", @"五台山", @"普陀山", @"九华山", @"武当山", @"青城山",
                                       @"龙虎山", @"崂山", @"千山", @"凤凰山", @"白云山", @"紫金山",
                                       @"香山", @"景山", @"万寿山", @"玉泉山", @"西山", @"北山",
                                       @"南山", @"东山", @"灵山", @"翠山"];
            NSArray *waterNames = @[@"长江", @"黄河", @"珠江", @"淮河", @"海河", @"松花江", @"黑龙江",
                                    @"钱塘江", @"闽江", @"赣江", @"湘江", @"汉江", @"嘉陵江", @"岷江",
                                    @"大渡河", @"雅鲁藏布江", @"怒江", @"澜沧江", @"塔里木河", @"额尔齐斯河",
                                    @"太湖", @"鄱阳湖", @"洞庭湖", @"洪泽湖", @"巢湖", @"青海湖",
                                    @"西湖", @"东湖", @"南湖", @"北湖"];
            NSArray *naturePrefixes = @[@"山", @"水", @"江", @"河", @"湖", @"海", @"溪", @"泉",
                                        @"潭", @"池", @"瀑", @"涧", @"沟", @"谷", @"峰", @"岭",
                                        @"岩", @"石", @"洞", @"峡", @"滩", @"洲", @"岛", @"湾",
                                        @"港", @"滨", @"浦", @"渡", @"码头"];
            if (arc4random_uniform(3) == 0) {
                NSString *mountain = mountainNames[arc4random_uniform((uint32_t)mountainNames.count)];
                streetName = [NSString stringWithFormat:@"%@%@", mountain, roadType];
            } else if (arc4random_uniform(2) == 0) {
                NSString *water = waterNames[arc4random_uniform((uint32_t)waterNames.count)];
                streetName = [NSString stringWithFormat:@"%@%@", water, roadType];
            } else {
                NSString *nature = naturePrefixes[arc4random_uniform((uint32_t)naturePrefixes.count)];
                streetName = [NSString stringWithFormat:@"%@%@%@", districtKey.length > 0 ? districtKey : @"青", nature, roadType];
            }
            
        } else if (nameMode == 3) {
            // 模式4：历史名人/事件（如"中山路"、"人民路"、"解放路"）
            NSArray *famousNames = @[@"中山", @"人民", @"解放", @"和平", @"建设", @"建国", @"新华",
                                     @"民主", @"自由", @"平等", @"公正", @"法治", @"爱国", @"敬业",
                                     @"诚信", @"友善", @"文明", @"和谐", @"富强", @"复兴",
                                     @"胜利", @"光明", @"前进", @"奋斗", @"振兴", @"崛起",
                                     @"朝阳", @"晨曦", @"晚霞", @"旭日"];
            NSString *name = famousNames[arc4random_uniform((uint32_t)famousNames.count)];
            streetName = [NSString stringWithFormat:@"%@%@", name, roadType];
            
        } else if (nameMode == 4) {
            // 模式5：颜色+事物（如"红旗街"、"青年路"、"蓝湖路"）
            NSArray *colorPrefixes = @[@"红", @"黄", @"蓝", @"绿", @"青", @"白", @"黑", @"灰",
                                       @"紫", @"金", @"银", @"彩", @"翠", @"碧", @"素", @"丹",
                                       @"赤", @"橙", @"粉", @"墨"];
            NSArray *colorThings = @[@"旗", @"云", @"霞", @"虹", @"日", @"月", @"星", @"光",
                                     @"山", @"水", @"河", @"湖", @"海", @"田", @"园", @"林",
                                     @"叶", @"花", @"草", @"树"];
            NSString *color = colorPrefixes[arc4random_uniform((uint32_t)colorPrefixes.count)];
            NSString *thing = colorThings[arc4random_uniform((uint32_t)colorThings.count)];
            streetName = [NSString stringWithFormat:@"%@%@%@", color, thing, roadType];
            
        } else if (nameMode == 5) {
            // 模式6：地名特色（用区县名/当地特色 + 街道类型）
            if (districtKey.length > 0) {
                NSArray *districtFormats = @[@"%@%@", @"%@东%@", @"%@西%@", @"%@南%@", @"%@北%@",
                                              @"%@新%@", @"%@老%@", @"%@大%@", @"%@小%@", @"%@中%@",
                                              @"%@前%@", @"%@后%@", @"%@上%@", @"%@下%@"];
                NSString *fmt = districtFormats[arc4random_uniform((uint32_t)districtFormats.count)];
                streetName = [NSString stringWithFormat:fmt, districtKey, roadType];
            } else {
                streetName = [NSString stringWithFormat:@"%@%@", @"中心", roadType];
            }
            
        } else if (nameMode == 6) {
            // 模式7：吉祥/祝福语（如"吉祥街"、"福寿路"、"康宁巷"）
            NSArray *auspiciousNames = @[@"吉祥", @"如意", @"福寿", @"康宁", @"平安", @"喜乐",
                                         @"富贵", @"荣华", @"兴旺", @"昌盛", @"兴隆", @"繁盛",
                                         @"繁荣", @"富强", @"兴旺", @"发达", @"昌盛", @"兴隆",
                                         @"幸福", @"美满", @"和谐", @"安康", @"快乐", @"喜悦",
                                         @"朝阳", @"迎春", @"喜来", @"福临", @"德昌", @"仁和"];
            NSString *aus = auspiciousNames[arc4random_uniform((uint32_t)auspiciousNames.count)];
            streetName = [NSString stringWithFormat:@"%@%@", aus, roadType];
        }
        
        // 30% 概率在街道名前加区县名前缀，增加真实感
        if (districtKey.length > 0 && arc4random_uniform(10) < 3) {
            streetName = [NSString stringWithFormat:@"%@%@", districtKey, streetName];
        }
    }

    // 5. 拼接四级地址（根据用户设置的开关独立控制每一级）
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL showProvince = [defaults boolForKey:@"DYYYisEnableAreaProvince"];
    BOOL showCity = [defaults boolForKey:@"DYYYisEnableAreaCity"];
    BOOL showDistrict = [defaults boolForKey:@"DYYYisEnableAreaDistrict"];
    BOOL showStreet = [defaults boolForKey:@"DYYYisEnableAreaStreet"];
    
    // 如果总开关关闭，全部不显示
    BOOL mainSwitch = [defaults boolForKey:@"DYYYisEnableArea"];
    if (!mainSwitch) {
        showProvince = NO;
        showCity = NO;
        showDistrict = NO;
        showStreet = NO;
    }
    
    NSMutableString *address = [NSMutableString string];
    
    if (showProvince && provinceName.length > 0) {
        [address appendString:provinceName];
    }
    
    // 直辖市处理，避免重复
    NSString *provincePrefix = cityCode.length >= 2 ? [cityCode substringToIndex:2] : @"00";
    NSArray *municipalities = @[@"11", @"12", @"31", @"50"];
    if (showCity && cityName.length > 0) {
        if (![municipalities containsObject:provincePrefix]) {
            if (address.length > 0) {
                [address appendString:@"-"];
            }
            [address appendString:cityName];
        }
    }
    
    if (showDistrict && districtName.length > 0) {
        if (address.length > 0) {
            [address appendString:@"-"];
        }
        [address appendString:districtName];
    }
    
    if (showStreet && streetName.length > 0) {
        if (address.length > 0) {
            [address appendString:@"-"];
        }
        [address appendString:streetName];
    }

    // 缓存结果
    self.addressCache[cityCode] = address;
    return [address copy];
}

// 根据省份代码获取省份名称
@end
