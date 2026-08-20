//
//  DYYYPlayInteractionAdditions.h
//  DYYY
//
//  AWEPlayInteractionViewController 的 %new 方法声明（拆分自 AWEPlayInteractionViewController.xm）。
//  三个 hook 文件共享本声明。
//

#import <UIKit/UIKit.h>
#import "AwemeHeaders.h"
#import "DYYYMenuComponents.h"

@interface AWEPlayInteractionViewController (DYYYAdditions)
- (BOOL)isViewContainsButton:(UIView *)view button:(UIButton *)button;
- (void)applyViewModeChange:(BOOL)isListView;
- (void)applyPerformanceOptimizations:(UIView *)view withResources:(NSDictionary *)resources;
- (void)optimizeRenderPath:(UIView *)rootView;
- (void)preloadVisibleContent:(UIScrollView *)scrollView;
- (void)syncWithDisplayRefresh:(CADisplayLink *)displayLink;
- (void)syncRenderLoop:(CADisplayLink *)displayLink;

- (void)updateParallaxEffectsForScrollView:(UIScrollView *)scrollView;
- (void)normalizeListViewFonts:(UIScrollView *)scrollView;
- (void)updateHeaderControlsColorForBackground:(UIColor *)backgroundColor;
- (void)updateViewIconColors:(UIView *)view withColor:(UIColor *)color;

- (void)applySmartTextColorToAllMenuItems;
- (void)safelyUpdateUI:(void (^)(void))block;
- (UIBlurEffectStyle)inferVisualEffectStyle:(UIVisualEffect *)effect;
- (void)updateTextColorsInView:(UIView *)view withTextColor:(UIColor *)textColor;

- (void)enhanceModernVisualStyle:(UIScrollView *)scrollView;
- (UIColor *)getOptimalTextColorForBackground:(UIColor *)backgroundColor;
- (void)applyTextColorForButton:(UIButton *)button withBackgroundColor:(UIColor *)backgroundColor;

- (void)changeVisualStyle:(DYYYMenuVisualStyle)style;

// 添加性能优化和异步加载相关的方法声明
- (void)optimizeMenuPerformance;
- (void)reduceViewHierarchyForActiveMenu;
- (void)enableRasterizationForMenuItems;
- (void)loadModuleDataAsynchronously;
- (NSArray<DYYYMenuModule *> *)applySmartOrderingToModules:(NSArray<DYYYMenuModule *> *)modules;
- (void)recreateMenuButtonsWithModules:(NSArray<DYYYMenuModule *> *)modules;

// 添加缺失的流体滚动相关方法声明
- (void)addParallaxEffectToModulesIn:(UIScrollView *)scrollView;
- (void)updateParallaxEffectForScrollView:(UIScrollView *)scrollView;

// 添加缺失的快捷操作面板相关方法声明
- (void)hideQuickActionsPanel:(id)sender;
- (void)autoHideQuickPanel:(NSTimer *)timer;
- (void)handleQuickPanelDrag:(UIPanGestureRecognizer *)gesture;
- (void)handleQuickAction:(UIButton *)sender;

// 添加缺失的暗黑模式适配方法声明
- (void)updateMenuAppearanceForDarkMode:(BOOL)isDarkMode menuContainer:(UIView *)menuContainer;
- (void)updateMenuContentsForDarkMode:(BOOL)isDarkMode menuContainer:(UIView *)menuContainer;
- (void)recursivelyUpdateView:(UIView *)view forDarkMode:(BOOL)isDarkMode;

// 添加缺失的手势控制增强方法声明
- (void)handleMenuPinch:(UIPinchGestureRecognizer *)gesture;
- (void)handleMenuSwipeDown:(UISwipeGestureRecognizer *)gesture;
- (void)handleMenuDoubleTap:(UITapGestureRecognizer *)gesture;
- (void)enhanceGestureControlsForMenu:(UIView *)menuContainer;

- (void)addMaterialEntranceCompleteEffect:(UIView *)container;
- (void)updateDragPosition:(DYYYDraggableButton *)button withTranslation:(CGPoint)translation;
- (void)enhanceCardHoverEffect:(UIButton *)button;
- (void)restoreCardNormalEffect:(UIButton *)button;
- (void)addBreathingEffectToHeaderView:(UIView *)headerView;
- (void)removeBreathingEffectFromHeaderView:(UIView *)headerView;
- (void)addVisualGuidanceToHeaderView:(UIView *)headerView;
- (void)removeVisualGuidanceFromHeaderView:(UIView *)headerView;
- (void)optimizeSpaceUtilizationAfterHeaderHidden;
- (void)restoreOriginalLayoutAfterHeaderShown;

- (void)handleModuleDrag:(UILongPressGestureRecognizer *)gesture;
- (void)startDragMode:(DYYYDraggableButton *)button;
- (void)updateDragPosition:(DYYYDraggableButton *)button withNewCenter:(CGPoint)newCenter;
- (void)finishDragMode:(DYYYDraggableButton *)button;
- (void)reorderModulesAfterDrag:(DYYYDraggableButton *)draggedButton;
- (void)saveModuleOrder:(NSArray<DYYYMenuModule *> *)modules;
- (UIView *)createDragPreviewForButton:(UIButton *)button;
- (NSInteger)findInsertionIndexForY:(CGFloat)yPosition inScrollView:(UIScrollView *)scrollView;
- (void)animateModuleReorderFromIndex:(NSInteger)fromIndex 
                              toIndex:(NSInteger)toIndex 
                        inScrollView:(UIScrollView *)scrollView 
                     excludingButton:(DYYYDraggableButton *)excludedButton;

// 添加缺失的拖拽相关方法声明
- (void)updateDragPositionWithLocation:(CGPoint)location button:(DYYYDraggableButton *)button scrollView:(UIScrollView *)scrollView;
- (void)reorderOtherButtonsFromIndex:(NSInteger)fromIndex 
                             toIndex:(NSInteger)toIndex 
                       inScrollView:(UIScrollView *)scrollView 
                    excludingButton:(DYYYDraggableButton *)excludedButton;
- (void)showDragPositionIndicatorAtY:(CGFloat)yPosition inScrollView:(UIScrollView *)scrollView;
- (void)hideDragPositionIndicator:(UIScrollView *)scrollView;
- (CGPoint)calculateCenterForIndex:(NSInteger)index isListView:(BOOL)isListView moduleView:(UIView *)moduleView;
- (void)updateModuleOrderAfterDrag:(DYYYDraggableButton *)draggedButton inScrollView:(UIScrollView *)scrollView;

// 添加头部控制区隐藏管理方法
- (void)setupHeaderAutoHideTimer;
- (void)invalidateHeaderAutoHideTimer;
- (void)hideHeaderControlsWithAnimation;
- (void)showHeaderControlsWithAnimation;
- (void)resetHeaderControlVisibility;

// 添加缺失的手势和视觉提示方法声明
- (void)addTapToShowGestureToMenuContainer:(UIView *)menuContainer;
- (void)removeTapToShowGestureFromMenuContainer:(UIView *)menuContainer;
- (void)handleTapToShowControls:(UITapGestureRecognizer *)gesture;
- (void)addVisualHintToMenuContainer:(UIView *)menuContainer;
- (void)removeVisualHintFromMenuContainer:(UIView *)menuContainer;
- (void)startDotsAnimationForContainer:(UIView *)dotsContainer;

// 添加创建菜单样式方法
- (void)createIOS19ListStyleMenuWithModules:(NSArray *)modules inScrollView:(UIScrollView *)scrollView moduleViews:(NSMutableArray *)moduleViews;
- (void)createCardStyleMenuWithModules:(NSArray *)modules inScrollView:(UIScrollView *)scrollView moduleViews:(NSMutableArray *)moduleViews;

- (void)applyContentParallaxEffect:(UIView *)parentView;
- (void)removeContentParallaxEffect:(UIView *)parentView;

- (void)applyFluentCardDecorator:(UIViewController *)viewController;
- (void)removeFluentCardDecorator:(UIViewController *)viewController;
- (void)enhanceVisibleCellsWithCardEffect:(UIViewController *)viewController;
- (void)restoreOriginalCellAppearance:(UIViewController *)viewController;
- (NSArray *)findVideoCellsInView:(UIView *)view;
- (void)applyFluentDesignToCell:(UIView *)cell;
- (void)applyCardStyleToCell:(UIView *)cell;
- (void)layoutDidUpdateNotification:(NSNotification *)notification;
- (void)createFluentDesignDraggableMenuWithAwemeModel:(AWEAwemeModel *)awemeModel touchPoint:(CGPoint)touchPoint;
- (void)dismissFluentMenu:(UITapGestureRecognizer *)gesture;
- (void)dismissFluentMenuByButton:(UIButton *)button;
- (void)handleModuleTap:(UITapGestureRecognizer *)gesture;
- (void)resetModulePositions:(UIButton *)sender;
- (void)showDYYYSettingPanelFromMenuButton:(UIButton *)button;
- (void)dismissDYYYSettingPanel:(UIButton *)button;
- (void)moduleButtonTouchDown:(UIButton *)sender;
- (void)handleModuleButtonTap:(UIButton *)sender;
- (void)resizeMenuPan:(UIPanGestureRecognizer *)pan;
- (void)customMenuButtonTapped:(UIButton *)button;
- (void)handleDYYYBackgroundColorChanged:(NSNotification *)notification;
- (void)dyyy_handleSettingPanelPan:(UIPanGestureRecognizer *)pan;
- (void)toggleBlurStyle:(UIButton *)button;
- (void)showBlurColorPicker:(UIButton *)button;
- (void)updateBlurEffectWithColor:(UIColor *)color;
- (void)updateColorPickerButtonWithColor:(UIColor *)color;
- (UIImage *)imageWithColor:(UIColor *)color size:(CGSize)size;
- (void)refreshCurrentView;
- (void)showVideoDebugInfo:(AWEAwemeModel *)model;
- (void)dyyy_startCustomScreenshotProcess;
- (void)performScreenshotAction;

- (UIWindow *)getKeyWindow;
- (void)pauseCurrentVideo;
- (void)resumeCurrentVideo;
- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo;
- (void)viewModeChanged:(UISegmentedControl *)segmentControl;

// 方法声明
- (void)recreateMenuButtonsForViewMode:(BOOL)isListView;
- (void)createMenuButtonsInScrollView:(UIScrollView *)scrollView forViewMode:(BOOL)isListView;

- (UIViewController *)findCurrentFeedViewController;
- (UIViewController *)searchForFeedControllerInViewController:(UIViewController *)vc;
- (UITableView *)findTableViewInViewController:(UIViewController *)vc;
- (UITableView *)findTableViewInView:(UIView *)view;
- (UICollectionView *)findCollectionViewInViewController:(UIViewController *)vc;
- (UICollectionView *)findCollectionViewInView:(UIView *)view;
- (void)switchToListMode:(UIViewController *)feedVC;
- (void)switchToCardMode:(UIViewController *)feedVC;

- (void)setGlobalFeedModeSettings:(BOOL)isListView;
- (void)forceResetLayoutWithManager:(id)manager isListView:(BOOL)isListView;
- (UIView *)findBackgroundViewIn:(UIView *)view;

// 添加缺失的方法声明
- (void)handleMenuContainerTap:(UITapGestureRecognizer *)gesture;
- (void)moduleButtonTouchUpForIOS19:(UIButton *)sender;
- (void)moduleButtonTouchUpForCard:(UIButton *)sender;

// 工厂模式相关方法
- (UIScrollView *)findScrollViewInTopViewController:(UIViewController *)topVC;
- (UIScrollView *)findScrollViewInView:(UIView *)view;
- (NSArray<DYYYMenuModule *> *)createMenuModulesForCurrentContext;
- (AWEAwemeModel *)getCurrentAwemeModel;
- (DYYYMenuModule *)createDownloadModuleForAweme:(AWEAwemeModel *)awemeModel;
- (DYYYMenuModule *)createScreenshotModule;
- (DYYYMenuModule *)createAudioModuleForAweme:(AWEAwemeModel *)awemeModel;
- (DYYYMenuModule *)createCopyTextModuleForAweme:(AWEAwemeModel *)awemeModel;
- (DYYYMenuModule *)createCommentModule;
- (DYYYMenuModule *)createLikeModule;
- (DYYYMenuModule *)createAdvancedModule;
- (BOOL)shouldShowDownloadModule;
- (BOOL)shouldShowScreenshotModule;
- (BOOL)shouldShowAudioModule;
- (BOOL)shouldShowCopyTextModule;
- (BOOL)shouldShowCommentModule;
- (BOOL)shouldShowLikeModule;
- (BOOL)shouldShowAdvancedModule;

// 添加缺失的按钮查找方法声明
- (UIView *)findCommentButtonInView:(UIView *)view;
- (UIView *)findLikeButtonInView:(UIView *)view;
- (UIView *)findShareButtonInView:(UIView *)view;
- (UIView *)findMoreButtonInView:(UIView *)view;

// 添加缺失的功能方法声明
- (void)performCommentAction;
- (void)performLikeAction;
- (void)showSharePanel;
- (void)showDislikeOnVideo;
- (void)dismissCurrentMenuPanel;
- (void)dismissCurrentMenuPanelWithCompletion:(void(^)(void))completion;

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 140000
- (void)colorPickerViewControllerDidSelectColor:(UIColorPickerViewController *)viewController API_AVAILABLE(ios(14.0));
- (void)colorPickerViewControllerDidFinish:(UIColorPickerViewController *)viewController API_AVAILABLE(ios(14.0));
#endif
@end
