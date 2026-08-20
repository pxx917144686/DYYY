//
//  DYYYSettingViewControllerPrivate.h
//  DYYY
//
//  DYYYSettingViewController 拆分后跨文件共享的私有声明。
//  主文件与各 category（+Appearance/+Backup/+Table/+Presentation）都引用本头文件；
//  对外 API 仍走 DYYYSettingViewController.h。
//

#import "DYYYSettingViewController.h"
#import "DYYYSettingItem.h"

NS_ASSUME_NONNULL_BEGIN

@interface UISwitch (DYYY_FuturisticEffects)
- (void)applyFuturisticEffects;
- (void)updateFuturisticEffectsWithState:(BOOL)isOn animated:(BOOL)animated;
@end

@interface DYYYSettingViewController ()

@property (nonatomic, assign) BOOL isExiting;

#pragma mark - +Appearance（生命周期、外观、头像、搜索栏、table 搭建）

- (void)ensureCustomAlbumSizeDefault;
- (void)backButtonTapped:(id)sender;
- (void)setupAppearance;
- (void)setupBackgroundColorView;
- (void)setupAvatarView;
- (void)setupSearchBar;
- (void)searchBarTapped:(UITapGestureRecognizer *)gesture;
- (void)addRippleEffectAtPoint:(CGPoint)point inView:(UIView *)view;
- (void)handleBackgroundColorChanged;
- (void)setupTableView;
- (void)setupSettingItems;
- (void)setupFooterLabel;
- (void)setupSectionTitles;
- (void)avatarTapped:(UITapGestureRecognizer *)gesture;
- (NSString *)avatarImagePath;
- (NSString *)saveCustomAlbumImage:(UIImage *)image;

#pragma mark - +Backup（清理、备份恢复、ABTest 配置）

- (void)setupCleanupOptions;
- (void)handleCleanCache;
- (void)setupBackupFunctions;
- (void)backupSettings;
- (void)restoreSettings;
- (void)saveCurrentABTestData;
- (void)loadABTestConfigFile;
- (void)processABTestConfigFile:(NSURL *)url;
- (void)deleteABTestConfigFile;

#pragma mark - +Table（data source、delegate、搜索过滤、图标和颜色）

- (void)filterContentForSearchText:(NSString *)searchText;
- (void)toggleGroupHeaderAtIndexPath:(NSIndexPath *)indexPath;
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView;
- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section;
- (NSString *)iconNameForSection:(NSInteger)section;
- (UIColor *)iconColorForSection:(NSInteger)section;
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath;
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section;
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section;
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath;
- (UIImage *)iconImageForSettingItem:(DYYYSettingItem *)item;
- (UIColor *)colorForSettingItem:(DYYYSettingItem *)item;
- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section;
- (NSArray<NSIndexPath *> *)rowsForSection:(NSInteger)section;
- (nullable NSIndexPath *)visibleIndexPathForSettingKey:(NSString *)key;

#pragma mark - +Presentation（颜色选择、样式选择、源码弹窗、长按和重置）

- (void)showColorPicker;
- (UIImage *)imageWithColor:(UIColor *)color size:(CGSize)size;
- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture;
- (void)showImagePickerForCustomAlbum;
- (void)showImagePickerWithSourceType:(UIImagePickerControllerSourceType)sourceType forCustomAlbum:(BOOL)isCustomAlbum;
- (void)resetButtonTapped:(UIButton *)sender;
- (void)showSourceCodePopup;
- (void)showScheduleStylePicker;
- (NSString *)getShortNameForStyleValue:(NSString *)styleValue;

@end

NS_ASSUME_NONNULL_END
