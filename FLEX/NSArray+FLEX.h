//
//  NSArray+FLEX.h
//  FLEX
//
//  由 Tanner Bennett 创建于 9/25/19.
//  版权所有 © 2020 FLEX Team. 保留所有权利。
//

#import <Foundation/Foundation.h>

@interface NSArray<T> (Functional)

/// 实际上更像 flatmap，但它似乎是 objc 中允许返回 nil 来忽略对象的方式。
/// 所以，从块中返回 nil 来忽略对象，返回一个对象将其包含在新数组中。
/// 然而，与 flatmap 不同的是，这不会将数组的数组展平为单个数组。
- (__kindof NSArray *)flex_mapped:(id(^)(T obj, NSUInteger idx))mapFunc;
/// 类似 flex_mapped，但期望返回数组，并将它们展平为一个数组。
- (__kindof NSArray *)flex_flatmapped:(NSArray *(^)(id, NSUInteger idx))block;
- (instancetype)flex_filtered:(BOOL(^)(T obj, NSUInteger idx))filterFunc;
- (void)flex_forEach:(void(^)(T obj, NSUInteger idx))block;

/// 与 \c subArrayWithRange: 不同，如果 \c maxLength
/// 大于数组的大小，这不会抛出异常。如果数组有一个元素且
/// \c maxLength 大于 1，你会得到一个包含 1 个元素的数组。
- (instancetype)flex_subArrayUpto:(NSUInteger)maxLength;

+ (instancetype)flex_forEachUpTo:(NSUInteger)bound map:(T(^)(NSUInteger i))block;
+ (instancetype)flex_mapped:(id<NSFastEnumeration>)collection block:(id(^)(T obj, NSUInteger idx))mapFunc;

- (instancetype)flex_sortedUsingSelector:(SEL)selector;

- (T)flex_firstWhere:(BOOL(^)(T obj))meetingCriteria;

@end

@interface NSMutableArray<T> (Functional)

- (void)flex_filter:(BOOL(^)(T obj, NSUInteger idx))filterFunc;

@end
