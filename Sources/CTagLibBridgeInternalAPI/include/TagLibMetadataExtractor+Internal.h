#pragma once

#import "TagLibMetadataExtractor.h"

NS_ASSUME_NONNULL_BEGIN

typedef BOOL (^TagLibFileMutationCoordinationBlock)(NSError *_Nullable *_Nullable error);

/// Package-only primitives used to keep multi-step Swift verification inside
/// the bridge's atomic staging transaction. This module is not a package product.
@interface TagLibMetadataExtractor (PackageInternalMutation)

+ (BOOL)writeMetadataInPlace:(TagLibAudioMetadata *)metadata
                       toURL:(NSURL *)fileURL
                       error:(NSError *_Nullable *_Nullable)error
NS_SWIFT_NAME(writeMetadataInPlace(_:to:));
+ (BOOL)writeTrackNumberTextInPlace:(NSString *)trackNumberText
                     discNumberText:(nullable NSString *)discNumberText
                              toURL:(NSURL *)fileURL
                              error:(NSError *_Nullable *_Nullable)error
NS_SWIFT_NAME(writeTrackNumberTextInPlace(_:discNumberText:to:));
+ (BOOL)writeRawPropertyMapInPlace:(NSDictionary<NSString *, NSString *> *)properties
                            toURL:(NSURL *)fileURL
                            error:(NSError *_Nullable *_Nullable)error
NS_SWIFT_NAME(writeRawPropertyMapInPlace(_:to:));
+ (BOOL)writeRawPropertyMapValuesInPlace:(NSDictionary<NSString *, NSArray<NSString *> *> *)properties
                                  toURL:(NSURL *)fileURL
                                  error:(NSError *_Nullable *_Nullable)error
NS_SWIFT_NAME(writeRawPropertyMapValuesInPlace(_:to:));
+ (BOOL)applyPropertyMapValuesInPlace:(NSDictionary<NSString *, NSArray<NSString *> *> *)valuesToSet
                         removingKeys:(NSArray<NSString *> *)keysToRemove
                                toURL:(NSURL *)fileURL
                                error:(NSError *_Nullable *_Nullable)error
NS_SWIFT_NAME(applyPropertyMapValuesInPlace(_:removingKeys:to:));
+ (BOOL)writeNumberPairsInPlaceWithTrackNumber:(NSInteger)trackNumber
                                   totalTracks:(NSInteger)totalTracks
                               updateTrackPair:(BOOL)updateTrackPair
                                     discNumber:(NSInteger)discNumber
                                     totalDiscs:(NSInteger)totalDiscs
                                updateDiscPair:(BOOL)updateDiscPair
                                          toURL:(NSURL *)fileURL
                                          error:(NSError *_Nullable *_Nullable)error
NS_SWIFT_NAME(writeNumberPairsInPlace(trackNumber:totalTracks:updateTrackPair:discNumber:totalDiscs:updateDiscPair:to:));
+ (BOOL)writeNumberPairsInPlaceWithTrackNumber:(NSInteger)trackNumber
                                   totalTracks:(NSInteger)totalTracks
                               updateTrackPair:(BOOL)updateTrackPair
                                    discNumber:(NSInteger)discNumber
                                     totalDiscs:(NSInteger)totalDiscs
                                updateDiscPair:(BOOL)updateDiscPair
                                movementNumber:(NSInteger)movementNumber
                                  movementCount:(NSInteger)movementCount
                             updateMovementPair:(BOOL)updateMovementPair
                                          toURL:(NSURL *)fileURL
                                          error:(NSError *_Nullable *_Nullable)error
NS_SWIFT_NAME(writeNumberPairsInPlace(trackNumber:totalTracks:updateTrackPair:discNumber:totalDiscs:updateDiscPair:movementNumber:movementCount:updateMovementPair:to:));
+ (BOOL)writeExplicitAdvisoryInPlace:(TagLibExplicitAdvisory)advisory
                               toURL:(NSURL *)fileURL
                               error:(NSError *_Nullable *_Nullable)error
NS_SWIFT_NAME(writeExplicitAdvisoryInPlace(_:to:));
+ (BOOL)writeStructuredMetadataInPlace:(NSDictionary<NSString *, NSObject *> *)metadata
                                 toURL:(NSURL *)fileURL
                                 error:(NSError *_Nullable *_Nullable)error
NS_SWIFT_NAME(writeStructuredMetadataInPlace(_:to:));
+ (BOOL)wipeMetadataInPlaceFromURL:(NSURL *)fileURL
                             error:(NSError *_Nullable *_Nullable)error
NS_SWIFT_NAME(wipeMetadataInPlace(from:));

+ (BOOL)coordinateMutationAtURL:(NSURL *)fileURL
                          error:(NSError *_Nullable *_Nullable)error
                       mutation:(TagLibFileMutationCoordinationBlock)mutation
NS_SWIFT_NAME(coordinateMutation(at:_:));

@end

NS_ASSUME_NONNULL_END
