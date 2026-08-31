+ (BOOL)writeMetadataInPlace:(TagLibAudioMetadata *)metadata
                       toURL:(NSURL *)fileURL
                       error:(NSError **)error
{
    TagLibAtomicMutationScope scope;
    return [self writeMetadata:metadata toURL:fileURL error:error];
}

+ (BOOL)writeTrackNumberTextInPlace:(NSString *)trackNumberText
                     discNumberText:(NSString *)discNumberText
                              toURL:(NSURL *)fileURL
                              error:(NSError **)error
{
    TagLibAtomicMutationScope scope;
    return [self writeTrackNumberText:trackNumberText
                       discNumberText:discNumberText
                                toURL:fileURL
                                error:error];
}

+ (BOOL)writeRawPropertyMapInPlace:(NSDictionary<NSString *, NSString *> *)properties
                            toURL:(NSURL *)fileURL
                            error:(NSError **)error
{
    TagLibAtomicMutationScope scope;
    return [self writeRawPropertyMap:properties toURL:fileURL error:error];
}

+ (BOOL)writeRawPropertyMapValuesInPlace:(NSDictionary<NSString *, NSArray<NSString *> *> *)properties
                                  toURL:(NSURL *)fileURL
                                  error:(NSError **)error
{
    TagLibAtomicMutationScope scope;
    return [self writeRawPropertyMapValues:properties toURL:fileURL error:error];
}

+ (BOOL)writeStructuredMetadataInPlace:(NSDictionary<NSString *, NSObject *> *)metadata
                                 toURL:(NSURL *)fileURL
                                 error:(NSError **)error
{
    TagLibAtomicMutationScope scope;
    return [self writeStructuredMetadata:metadata toURL:fileURL error:error];
}

+ (BOOL)wipeMetadataInPlaceFromURL:(NSURL *)fileURL
                             error:(NSError **)error
{
    TagLibAtomicMutationScope scope;
    return [self wipeMetadataFromURL:fileURL error:error];
}
