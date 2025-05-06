// 遇到问题联系中文翻译作者：pxx917144686
//
//  NSArray+FLEX.h
//  FLEX
//
//  由 Tanner Bennett 创建于 9/25/19.
//  版权所有 © 2020 FLEX Team。保留所有权利。
//

#import <Foundation/Foundation.h>

@interface NSArray<T> (Functional)

/// 实际上更像是 flatmap，但这似乎是 Objective-C 允许返回 nil 来省略对象的方式。
/// 因此，从块中返回 nil 以省略对象，返回一个对象以将其包含在新数组中。
/// 然而，与 flatmap 不同的是，这不会将数组的数组展平为单个数组。
- (__kindof NSArray *)flex_mapped:(id(^)(T obj, NSUInteger idx))mapFunc;
/// 类似于 flex_mapped，但期望返回数组，并将它们展平为一个数组。
- (__kindof NSArray *)flex_flatmapped:(NSArray *(^)(id, NSUInteger idx))block;
- (instancetype)flex_filtered:(BOOL(^)(T obj, NSUInteger idx))filterFunc;
- (void)flex_forEach:(void(^)(T obj, NSUInteger idx))block;

/// 与 \c subArrayWithRange: 不同，如果 \c maxLength
/// 大于数组的大小，则此方法不会引发异常。如果数组有一个元素且
/// \c maxLength 大于 1，则返回一个包含 1 个元素的数组。
- (instancetype)flex_subArrayUpto:(NSUInteger)maxLength;

+ (instancetype)flex_forEachUpTo:(NSUInteger)bound map:(T(^)(NSUInteger i))block;
+ (instancetype)flex_mapped:(id<NSFastEnumeration>)collection block:(id(^)(T obj, NSUInteger idx))mapFunc;

- (instancetype)flex_sortedUsingSelector:(SEL)selector;

- (T)flex_firstWhere:(BOOL(^)(T obj))meetingCriteria;

@end

@interface NSMutableArray<T> (Functional)

- (void)flex_filter:(BOOL(^)(T obj, NSUInteger idx))filterFunc;

@end
