#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "DYYYUCDisassembler.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, UCDisasmViewMode) {
    UCDisasmViewModeGraph = 0,
};

@interface DYYYUCDisasmViewController : UIViewController

@property (nonatomic, assign) UCDisasmViewMode viewMode;

- (instancetype)initWithAddress:(uint64_t)address
                           size:(NSUInteger)size
                          title:(nullable NSString *)title;

- (instancetype)initWithMethod:(Method)method
                         class:(nullable NSString *)className
                      selector:(nullable NSString *)selectorName;

- (instancetype)initWithClass:(Class)cls
                     selector:(SEL)selector
               isClassMethod:(BOOL)isClassMethod;

- (instancetype)initWithFunction:(DYYYUCFunction *)function
                           title:(nullable NSString *)title;

@end

@interface DYYYUCCFGView : UIView

@property (nonatomic, strong, nullable) NSArray<DYYYUCBasicBlock *> *basicBlocks;
@property (nonatomic, copy, nullable) void (^blockTapHandler)(DYYYUCBasicBlock *block);
@property (nonatomic, strong, readonly, nullable) NSMutableDictionary<NSNumber *, UIView *> *blockViewMap;

- (void)layoutGraph;

@end

@interface DYYYUCFuncListViewController : UIViewController

- (instancetype)initWithFunctions:(NSArray<DYYYUCFunction *> *)functions;

@end

NS_ASSUME_NONNULL_END
