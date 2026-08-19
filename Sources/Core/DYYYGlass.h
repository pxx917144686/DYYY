#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class UIGlassEffect;

#ifdef __cplusplus
extern "C" {
#endif

UIGlassEffect * _Nullable DYYYGlassMakeEffect(BOOL clear,
                                              UIUserInterfaceStyle style,
                                              BOOL interactive);

BOOL DYYYGlassNeedsUpdate(UIVisualEffectView *glass,
                          BOOL clear,
                          UIUserInterfaceStyle style);

void DYYYGlassInstallEffect(UIVisualEffectView *glass,
                            UIGlassEffect *effect,
                            BOOL clear,
                            UIUserInterfaceStyle style);

void DYYYGlassRunAnimation(UIViewController * _Nullable controller,
                           BOOL animated,
                           dispatch_block_t changes);

UIVisualEffectView *DYYYGlassMakeShell(void);
void DYYYGlassPlaceShell(UIVisualEffectView *glass, UIView *slot);
void DYYYGlassEnsureBackmost(UIView *slot, UIView *glass);

UIUserInterfaceStyle DYYYGlassStyleForView(UIView *view);
UIUserInterfaceStyle DYYYGlassOverrideStyle(BOOL clear,
                                             UIUserInterfaceStyle style);
UIColor * _Nullable DYYYGlassTintForStyle(UIUserInterfaceStyle style);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
