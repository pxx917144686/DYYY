#ifndef DYYYSettingViewController_h
#define DYYYSettingViewController_h

#import <UIKit/UIKit.h>

// 添加缺失的枚举定义
typedef NS_ENUM(NSInteger, DYYYSettingItemType) {
    DYYYSettingItemTypeSwitch,
    DYYYSettingItemTypeTextField,
    DYYYSettingItemTypeSpeedPicker,
    DYYYSettingItemTypeColorPicker,
    DYYYSettingItemTypeCustomPicker
};

// 为按钮大小定义枚举
typedef NS_ENUM(NSInteger, DYYYButtonSize) {
    DYYYButtonSizeSmall = 30,
    DYYYButtonSizeMedium = 40,
    DYYYButtonSizeLarge = 50
};

@interface DYYYIconOptionsDialogView : UIView

@property (nonatomic, copy) void (^onClear)(void);
@property (nonatomic, copy) void (^onSelect)(void);

- (instancetype)initWithTitle:(NSString *)title previewImage:(UIImage *)previewImage;
- (void)show;

@end

@class DYYYSettingItem;
@class DYYYBackupPickerDelegate;

@interface DYYYSettingViewController : UIViewController <UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) NSMutableSet *expandedSections;
@property (nonatomic, assign) BOOL isSearching;
@property (nonatomic, assign) BOOL isKVOAdded;
@property (nonatomic, strong) UIImpactFeedbackGenerator *feedbackGenerator;
@property (nonatomic, strong) NSArray *filteredSections;
@property (nonatomic, strong) NSArray *filteredSectionTitles;
@property (nonatomic, strong) NSMutableArray *sectionTitles;
@property (nonatomic, strong) NSArray *settingSections;
@property (nonatomic, strong) UILabel *footerLabel;
@property (nonatomic, strong) UIView *backgroundColorView;
@property (nonatomic, strong) UIView *avatarContainerView;
@property (nonatomic, strong) UIImageView *avatarImageView;
@property (nonatomic, strong) UILabel *avatarTapLabel;
@property (nonatomic, strong) DYYYBackupPickerDelegate *backupPickerDelegate;
@property (nonatomic, strong) DYYYBackupPickerDelegate *restorePickerDelegate;

// 添加热更新功能相关方法
- (void)saveCurrentABTestData;
- (void)loadABTestConfigFile;
- (void)deleteABTestConfigFile;
- (void)handleABTestBlockEnabled:(BOOL)enabled;
- (void)handleABTestPatchEnabled:(BOOL)enabled;

@end

#endif /* DYYYSettingViewController_h */
