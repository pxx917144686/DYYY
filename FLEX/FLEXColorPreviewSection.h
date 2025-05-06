//
//  FLEXColorPreviewSection.h
//  FLEX
//
//  创建者：Tanner Bennett，日期：12/12/19.
//  版权所有 © 2020 FLEX Team。保留所有权利。
//
// 遇到问题联系中文翻译作者：pxx917144686

#import "FLEXSingleRowSection.h"
#import "FLEXObjectInfoSection.h"

@interface FLEXColorPreviewSection : FLEXSingleRowSection <FLEXObjectInfoSection>

+ (instancetype)forObject:(UIColor *)color;

@end
