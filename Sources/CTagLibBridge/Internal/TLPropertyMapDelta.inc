static NSError *PropertyMapDeltaError(NSInteger code, NSString *description)
{
    return [NSError errorWithDomain:@"TagLibMetadataExtractor"
                               code:code
                           userInfo:@{ NSLocalizedDescriptionKey : description }];
}

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

+ (BOOL)writeNumberPairsInPlaceWithTrackNumber:(NSInteger)trackNumber
                                   totalTracks:(NSInteger)totalTracks
                               updateTrackPair:(BOOL)updateTrackPair
                                    discNumber:(NSInteger)discNumber
                                     totalDiscs:(NSInteger)totalDiscs
                                updateDiscPair:(BOOL)updateDiscPair
                                          toURL:(NSURL *)fileURL
                                          error:(NSError **)error
{
    try {
    if (!fileURL || !fileURL.isFileURL || trackNumber < 0 || totalTracks < 0 ||
        discNumber < 0 || totalDiscs < 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                         code:9260
                                     userInfo:@{ NSLocalizedDescriptionKey : @"Number-pair changes require a file URL and non-negative values" }];
        }
        return NO;
    }

    const char *filePath = fileURL.path.UTF8String;
    if (!filePath) {
        if (error) *error = PropertyMapDeltaError(9261, @"Invalid audio file path");
        return NO;
    }

    TAGLIB_BRIDGE_SERIAL_GUARD();
    AudioMatorTagFileFormat format = DetectTagFileFormat(fileURL.pathExtension.lowercaseString);
    NSString *trackText = BuildTRCKString(trackNumber, totalTracks, 0);
    NSString *discText = BuildTRCKString(discNumber, totalDiscs, 0);

    if (format == AudioMatorTagFileFormatMP4) {
        TagLib::MP4::File file(filePath);
        if (!file.isValid() || !file.tag()) {
            if (error) *error = PropertyMapDeltaError(9262, @"Unable to open MP4/M4A file for native number-pair mutation");
            return NO;
        }
        TagLib::MP4::Tag *tag = file.tag();
        if (updateTrackPair) {
            tag->setTrack(trackNumber > 0 ? (unsigned int)trackNumber : 0);
            SetMP4IntPairItem(tag, "trkn", trackNumber, totalTracks);
            SetMP4TextItem(tag, kAudioMatorMP4TrackNumberTextKey, trackText);
        }
        if (updateDiscPair) {
            SetMP4IntPairItem(tag, "disk", discNumber, totalDiscs);
            SetMP4TextItem(tag, kAudioMatorMP4DiscNumberTextKey, discText);
        }
        if (!file.save()) {
            if (error) *error = PropertyMapDeltaError(9263, @"TagLib could not save native MP4/M4A number pairs");
            return NO;
        }
        return YES;
    }

    if (format == AudioMatorTagFileFormatMPEGID3 || format == AudioMatorTagFileFormatMPEGAAC) {
        TagLib::MPEG::File file(filePath);
        if (!file.isValid()) {
            if (error) *error = PropertyMapDeltaError(9264, @"Unable to open MPEG file for native number-pair mutation");
            return NO;
        }
        TagLib::ID3v2::Tag *tag = file.ID3v2Tag(true);
        if (updateTrackPair) {
            if (file.tag()) file.tag()->setTrack(trackNumber > 0 ? (unsigned int)trackNumber : 0);
            TagLib::ID3v2::FrameList frames = tag->frameList("TRCK");
            for (auto iterator = frames.begin(); iterator != frames.end(); ++iterator) tag->removeFrame(*iterator);
            SetID3v2TextFrame(tag, "TRCK", trackText);
        }
        if (updateDiscPair) {
            TagLib::ID3v2::FrameList frames = tag->frameList("TPOS");
            for (auto iterator = frames.begin(); iterator != frames.end(); ++iterator) tag->removeFrame(*iterator);
            SetID3v2TextFrame(tag, "TPOS", discText);
        }
        if (!file.save()) {
            if (error) *error = PropertyMapDeltaError(9265, @"TagLib could not save native MPEG number pairs");
            return NO;
        }
        return YES;
    }

    TagLib::FileRef fileRef(filePath, true, TagLib::AudioProperties::Fast);
    TagLib::File *file = fileRef.file();
    if (fileRef.isNull() || !file || !file->isValid()) {
        if (error) *error = PropertyMapDeltaError(9266, @"Unable to open audio file for number-pair mutation");
        return NO;
    }
    TagLib::PropertyMap properties = file->properties();
    if (updateTrackPair) {
        SetPropertyMapDynamicString(properties, @"TRACKNUMBER", trackText);
        SetPropertyMapDynamicString(properties, @"TRACKTOTAL", totalTracks > 0 ? [NSString stringWithFormat:@"%ld", (long)totalTracks] : nil);
        properties.erase("TOTALTRACKS");
    }
    if (updateDiscPair) {
        SetPropertyMapDynamicString(properties, @"DISCNUMBER", discText);
        SetPropertyMapDynamicString(properties, @"DISCTOTAL", totalDiscs > 0 ? [NSString stringWithFormat:@"%ld", (long)totalDiscs] : nil);
        properties.erase("TOTALDISCS");
    }
    file->setProperties(properties);
    if (!file->save()) {
        if (error) *error = PropertyMapDeltaError(9267, @"TagLib could not save number-pair changes");
        return NO;
    }
    return YES;
    TAGLIB_BRIDGE_CATCH_WITH_ERROR(error, @"Number-pair mutation", NO)
}
