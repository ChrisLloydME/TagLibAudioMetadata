+ (BOOL)applyPropertyMapValuesInPlace:(NSDictionary<NSString *, NSArray<NSString *> *> *)valuesToSet
                         removingKeys:(NSArray<NSString *> *)keysToRemove
                                toURL:(NSURL *)fileURL
                                error:(NSError **)error
{
    try {
    if (!fileURL || !fileURL.isFileURL) {
        if (error) {
            *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                         code:9250
                                     userInfo:@{ NSLocalizedDescriptionKey : @"Property-map changes require a file URL" }];
        }
        return NO;
    }

    const char *filePath = fileURL.path.UTF8String;
    if (!filePath) {
        if (error) {
            *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                         code:9251
                                     userInfo:@{ NSLocalizedDescriptionKey : @"Invalid audio file path" }];
        }
        return NO;
    }

    TAGLIB_BRIDGE_SERIAL_GUARD();
    TagLib::FileRef fileRef(filePath, true, TagLib::AudioProperties::Fast);
    TagLib::File *file = fileRef.file();
    if (fileRef.isNull() || !file || !file->isValid()) {
        if (error) {
            *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                         code:9252
                                     userInfo:@{ NSLocalizedDescriptionKey : @"Unable to open audio file for targeted property-map mutation" }];
        }
        return NO;
    }

    TagLib::PropertyMap properties = file->properties();
    for (NSString *key in keysToRemove ?: @[]) {
        NSString *trimmedKey = TrimmedStringOrNil(key);
        if (trimmedKey) properties.erase(NSStringToTagString(trimmedKey));
    }

    TagLib::PropertyMap replacements = BuildRawPropertyMapValues(valuesToSet ?: @{});
    for (auto iterator = replacements.begin(); iterator != replacements.end(); ++iterator) {
        properties.replace(iterator->first, iterator->second);
    }

    file->setProperties(properties);
    if (!file->save()) {
        if (error) {
            *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                         code:9253
                                     userInfo:@{ NSLocalizedDescriptionKey : @"TagLib could not save targeted property-map changes" }];
        }
        return NO;
    }
    return YES;
    TAGLIB_BRIDGE_CATCH_WITH_ERROR(error, @"Targeted property-map mutation", NO)
}
