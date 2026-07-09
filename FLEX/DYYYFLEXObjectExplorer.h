//
//  DYYYFLEXObjectExplorer.h
//  FLEX
//
//  Created by Tanner Bennett on 8/28/19.
//  Copyright © 2020 FLEX Team. All rights reserved.
//

#import "DYYYFLEXRuntime+UIKitHelpers.h"

/// Carries state about the current user defaults settings
@interface DYYYFLEXObjectExplorerDefaults : NSObject
+ (instancetype)canEdit:(BOOL)editable wantsPreviews:(BOOL)showPreviews;

/// Only \c YES for properties and ivars
@property (nonatomic, readonly) BOOL isEditable;
/// Only affects properties and ivars
@property (nonatomic, readonly) BOOL wantsDynamicPreviews;
@end

@interface DYYYFLEXObjectExplorer : NSObject

+ (instancetype)forObject:(id)objectOrClass;

+ (void)configureDefaultsForItems:(NSArray<id<FLEXObjectExplorerItem>> *)items;

@property (nonatomic, readonly) id object;
/// Subclasses can override to provide a more useful description
@property (nonatomic, readonly) NSString *objectDescription;

/// @return \c YES if \c object is an instance of a class,
/// or \c NO if \c object is a class itself.
@property (nonatomic, readonly) BOOL objectIsInstance;

/// An index into the `classHierarchy` array.
///
/// This property determines which set of data comes out of the metadata arrays below
/// For example, \c properties contains the properties of the selected class scope,
/// while \c allProperties is an array of arrays where each array is a set of
/// properties for a class in the class hierarchy of the current object.
@property (nonatomic) NSInteger classScope;

@property (nonatomic, readonly) NSArray<NSArray<DYYYFLEXProperty *> *> *allProperties;
@property (nonatomic, readonly) NSArray<DYYYFLEXProperty *> *properties;

@property (nonatomic, readonly) NSArray<NSArray<DYYYFLEXProperty *> *> *allClassProperties;
@property (nonatomic, readonly) NSArray<DYYYFLEXProperty *> *classProperties;

@property (nonatomic, readonly) NSArray<NSArray<DYYYFLEXIvar *> *> *allIvars;
@property (nonatomic, readonly) NSArray<DYYYFLEXIvar *> *ivars;

@property (nonatomic, readonly) NSArray<NSArray<DYYYFLEXMethod *> *> *allMethods;
@property (nonatomic, readonly) NSArray<DYYYFLEXMethod *> *methods;

@property (nonatomic, readonly) NSArray<NSArray<DYYYFLEXMethod *> *> *allClassMethods;
@property (nonatomic, readonly) NSArray<DYYYFLEXMethod *> *classMethods;

@property (nonatomic, readonly) NSArray<Class> *classHierarchyClasses;
@property (nonatomic, readonly) NSArray<DYYYFLEXStaticMetadata *> *classHierarchy;

@property (nonatomic, readonly) NSArray<NSArray<DYYYFLEXProtocol *> *> *allConformedProtocols;
@property (nonatomic, readonly) NSArray<DYYYFLEXProtocol *> *conformedProtocols;

@property (nonatomic, readonly) NSArray<DYYYFLEXStaticMetadata *> *allInstanceSizes;
@property (nonatomic, readonly) DYYYFLEXStaticMetadata *instanceSize;

@property (nonatomic, readonly) NSArray<DYYYFLEXStaticMetadata *> *allImageNames;
@property (nonatomic, readonly) DYYYFLEXStaticMetadata *imageName;

- (void)reloadMetadata;
- (void)reloadClassHierarchy;

@end


@interface DYYYFLEXObjectExplorer (Reflex)

/// Do not enable this property manually; Reflex will flip the switch when it is loaded.
/// If you wish, you may \e disable it manually.
@property (nonatomic, class) BOOL reflexAvailable;

@end
