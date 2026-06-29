//
//  DYYYSDKPatch.h
//  DYYY
//
//

#ifndef DYYYSDKPatch_h
#define DYYYSDKPatch_h

#import <Foundation/Foundation.h>
#import <mach-o/loader.h>
#import <mach-o/fat.h>

#ifdef __cplusplus
extern "C" {
#endif

// Mach-O 二进制修改函数声明
void LCPatchMachOForSDK26(void);
void _locateMachosAndChangeToSDK26(void);

#ifdef __cplusplus
}
#endif

#endif /* DYYYSDKPatch_h */
