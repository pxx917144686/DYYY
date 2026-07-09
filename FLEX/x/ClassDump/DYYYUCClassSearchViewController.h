//
//  DYYYUCClassSearchViewController.h
//  FLEX++
//
//  类名搜索和单类头文件查看器
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 搜索界面的使用模式
typedef NS_ENUM(NSInteger, UCClassSearchMode) {
    UCClassSearchModeClassDump = 0,  ///< 类头文件模式：点击类名显示头文件
    UCClassSearchModeDisassembler,   ///< 反汇编模式：点击类名显示方法列表，再选择反汇编
};

@interface DYYYUCClassSearchViewController : UIViewController

/// 搜索模式，默认为 UCClassSearchModeClassDump
@property (nonatomic, assign) UCClassSearchMode searchMode;

/// 便利构造方法
+ (instancetype)searchViewControllerWithMode:(UCClassSearchMode)mode;

@end

NS_ASSUME_NONNULL_END
