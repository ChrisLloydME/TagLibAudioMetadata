static NSError *PropertyMapDeltaError(NSInteger code, NSString *description)
{
    return [NSError errorWithDomain:@"TagLibMetadataExtractor"
                               code:code
                           userInfo:@{ NSLocalizedDescriptionKey : description }];
}

static void RemoveRecognizedMP4AdvisoryFreeformItems(TagLib::MP4::Tag *tag)
{
    if (!tag) return;
    const std::initializer_list<const char *> recognizedKeys = {
        "----:COM.APPLE.ITUNES:ITUNESADVISORY",
        "----:COM.APPLE.ITUNES:ADVISORY",
        "----:COM.APPLE.ITUNES:EXPLICITCONTENT",
        "----:COM.APPLE.ITUNES:EXPLICIT",
    };
    TagLib::StringList keysToRemove;
    const TagLib::MP4::ItemMap &items = tag->itemMap();
    for (auto iterator = items.begin(); iterator != items.end(); ++iterator) {
        TagLib::String upperKey = iterator->first.upper();
        for (const char *recognizedKey : recognizedKeys) {
            if (upperKey == TagLib::String(recognizedKey, TagLib::String::UTF8)) {
                keysToRemove.append(iterator->first);
                break;
            }
        }
    }
    for (const TagLib::String &key : keysToRemove) {
        tag->removeItem(key);
    }
}

static void RemoveID3v2ExplicitAdvisoryAliases(TagLib::ID3v2::Tag *tag)
{
    if (!tag) return;
    TagLib::ID3v2::FrameList frames = tag->frameList("TXXX");
    for (auto iterator = frames.begin(); iterator != frames.end(); ++iterator) {
        auto *userText = dynamic_cast<TagLib::ID3v2::UserTextIdentificationFrame *>(*iterator);
        if (!userText) continue;
        NSString *description = [TagStringToNSString(userText->description()) uppercaseString];
        if ([description isEqualToString:@"ITUNESADVISORY"] ||
            [description isEqualToString:@"ADVISORY"] ||
            [description isEqualToString:@"EXPLICITCONTENT"] ||
            [description isEqualToString:@"EXPLICIT"]) {
            tag->removeFrame(*iterator);
        }
    }
}

static void RemoveID3v2UserTextFrames(TagLib::ID3v2::Tag *tag,
                                        NSArray<NSString *> *descriptions)
{
    if (!tag || descriptions.count == 0) return;
    TagLib::ID3v2::FrameList frames = tag->frameList("TXXX");
    for (auto iterator = frames.begin(); iterator != frames.end(); ++iterator) {
        auto *userText = dynamic_cast<TagLib::ID3v2::UserTextIdentificationFrame *>(*iterator);
        if (!userText) continue;
        NSString *description = [TagStringToNSString(userText->description()) uppercaseString];
        if (description && [descriptions containsObject:description]) {
            tag->removeFrame(*iterator);
        }
    }
}

static void ApplyCanonicalID3v2Advisory(TagLib::ID3v2::Tag *tag,
                                        TagLibExplicitAdvisory advisory)
{
    if (!tag) return;
    RemoveID3v2ExplicitAdvisoryAliases(tag);
    SetID3v2UserTextFrame(tag, "ITUNESADVISORY", SerializedExplicitAdvisoryValue(advisory));
}

static void ApplyCanonicalMP4Advisory(TagLib::MP4::Tag *tag,
                                      TagLibExplicitAdvisory advisory)
{
    if (!tag) return;
    RemoveRecognizedMP4AdvisoryFreeformItems(tag);
    if (advisory == TagLibExplicitAdvisoryNotExplicit) {
        tag->setItem("rtng", TagLib::MP4::Item(0));
    } else if (advisory == TagLibExplicitAdvisoryExplicit) {
        tag->setItem("rtng", TagLib::MP4::Item(1));
    } else if (advisory == TagLibExplicitAdvisoryClean) {
        tag->setItem("rtng", TagLib::MP4::Item(2));
    } else {
        tag->removeItem("rtng");
    }
}

// Exact Xiph/APE text-key mutation. The engine PropertyMap dialect does not
// expose every native key (for example Vorbis YEAR alongside DATE), so a date
// edit must address the native field list directly instead of round-tripping
// the whole projection.
+ (BOOL)applyNativeTextKeyValuesInPlace:(NSDictionary<NSString *, NSArray<NSString *> *> *)valuesToSet
                          removingKeys:(NSArray<NSString *> *)keysToRemove
                                 toURL:(NSURL *)fileURL
                                 error:(NSError **)error
{
    try {
    if (!fileURL || !fileURL.isFileURL) {
        if (error) *error = PropertyMapDeltaError(9280, @"Native text-key changes require a file URL");
        return NO;
    }
    const char *filePath = fileURL.path.UTF8String;
    if (!filePath) {
        if (error) *error = PropertyMapDeltaError(9281, @"Invalid audio file path");
        return NO;
    }
    TAGLIB_BRIDGE_SERIAL_GUARD();
    TagLib::FileRef fileRef(filePath, true, TagLib::AudioProperties::Fast);
    TagLib::File *file = fileRef.file();
    if (fileRef.isNull() || !file || !file->isValid()) {
        if (error) *error = PropertyMapDeltaError(9282, @"Unable to open audio file for native text-key mutation");
        return NO;
    }

    bool changed = false;
    if (auto *xiph = NativeXiphComment(file)) {
        for (NSString *key in keysToRemove ?: @[]) {
            NSString *trimmed = TrimmedStringOrNil(key);
            if (trimmed) { xiph->removeFields(NSStringToTagString(trimmed)); changed = true; }
        }
        for (NSString *key in valuesToSet ?: @{}) {
            NSString *trimmed = TrimmedStringOrNil(key);
            if (!trimmed) continue;
            xiph->removeFields(NSStringToTagString(trimmed));
            for (NSString *value in valuesToSet[key]) {
                NSString *trimmedValue = value;
                if (trimmedValue) xiph->addField(NSStringToTagString(trimmed), NSStringToTagString(trimmedValue), false);
            }
            changed = true;
        }
    } else if (auto *ape = NativeAPETag(file)) {
        for (NSString *key in keysToRemove ?: @[]) {
            NSString *trimmed = TrimmedStringOrNil(key);
            if (trimmed) { ape->removeItem(NSStringToTagString(trimmed)); changed = true; }
        }
        for (NSString *key in valuesToSet ?: @{}) {
            NSString *trimmed = TrimmedStringOrNil(key);
            if (!trimmed) continue;
            ape->removeItem(NSStringToTagString(trimmed));
            TagLib::StringList values;
            for (NSString *value in valuesToSet[key]) {
                NSString *trimmedValue = value;
                if (trimmedValue) values.append(NSStringToTagString(trimmedValue));
            }
            if (!values.isEmpty()) {
                ape->setItem(NSStringToTagString(trimmed), TagLib::APE::Item(NSStringToTagString(trimmed), values));
            }
            changed = true;
        }
    } else if (auto *asf = dynamic_cast<TagLib::ASF::File *>(file)) {
        TagLib::ASF::Tag *tag = asf->tag();
        for (NSString *key in keysToRemove ?: @[]) {
            NSString *trimmed = TrimmedStringOrNil(key);
            if (trimmed) { RemoveASFCommonAttributeAlias(tag, trimmed.uppercaseString.UTF8String); changed = true; }
        }
        for (NSString *key in valuesToSet ?: @{}) {
            NSString *trimmed = TrimmedStringOrNil(key);
            if (!trimmed) continue;
            RemoveASFCommonAttributeAlias(tag, trimmed.uppercaseString.UTF8String);
            for (NSString *value in valuesToSet[key]) {
                NSString *trimmedValue = value;
                if (trimmedValue) {
                    tag->addAttribute(
                        NSStringToTagString(trimmed),
                        TagLib::ASF::Attribute(NSStringToTagString(trimmedValue))
                    );
                }
            }
            changed = true;
        }
    } else {
        if (error) *error = PropertyMapDeltaError(9283, @"The selected format has no native text-key surface");
        return NO;
    }
    if (changed && !SaveMetadataPreservingOtherTagSurfaces(file)) {
        if (error) *error = PropertyMapDeltaError(9284, @"TagLib could not save native text-key changes");
        return NO;
    }
    return YES;
    TAGLIB_BRIDGE_CATCH_WITH_ERROR(error, @"Native text-key mutation", NO)
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

    // WAV exposes RIFF INFO and ID3v2 through the same file-level
    // PropertyMap. Applying a file-level setProperties call writes everything
    // into ID3v2 and duplicates INFO values. Apply the delta to the surface(s)
    // that actually own each key, and create new keys in ID3v2.
    if (auto *wav = dynamic_cast<TagLib::RIFF::WAV::File *>(file)) {
        TagLib::PropertyMap info = wav->InfoTag()->properties();
        TagLib::PropertyMap id3 = wav->ID3v2Tag()->properties();
        bool infoChanged = false;
        bool id3Changed = false;

        for (NSString *key in keysToRemove ?: @[]) {
            NSString *trimmedKey = TrimmedStringOrNil(key);
            if (!trimmedKey) continue;
            TagLib::String tagKey = NSStringToTagString(trimmedKey);
            if (info.contains(tagKey)) { info.erase(tagKey); infoChanged = true; }
            if (id3.contains(tagKey)) { id3.erase(tagKey); id3Changed = true; }
        }

        for (NSString *key in valuesToSet ?: @{}) {
            NSString *trimmedKey = TrimmedStringOrNil(key);
            if (!trimmedKey) continue;
            TagLib::String tagKey = NSStringToTagString(trimmedKey);
            TagLib::StringList values;
            for (NSString *value in valuesToSet[key]) {
                values.append(NSStringToTagString(value));
            }
            const bool inInfo = info.contains(tagKey);
            const bool inID3 = id3.contains(tagKey);
            if (inInfo) { info.replace(tagKey, values); infoChanged = true; }
            if (inID3 || !inInfo) { id3.replace(tagKey, values); id3Changed = true; }
        }

        wav->InfoTag()->setProperties(info);
        SetID3PropertiesPreservingNativeDates(wav->ID3v2Tag(), id3);
        if (infoChanged &&
            !wav->save(TagLib::RIFF::WAV::File::Info, TagLib::File::StripNone)) {
            if (error) {
                *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                             code:9253
                                         userInfo:@{ NSLocalizedDescriptionKey : @"TagLib could not save RIFF INFO metadata changes" }];
            }
            return NO;
        }
        if (id3Changed &&
            !wav->save(TagLib::RIFF::WAV::File::ID3v2, TagLib::File::StripNone)) {
            if (error) {
                *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                             code:9253
                                         userInfo:@{ NSLocalizedDescriptionKey : @"TagLib could not save ID3v2 metadata changes" }];
            }
            return NO;
        }
        return YES;
    }

    // TagLib uppercases freeform descriptions when projecting/replaying a
    // PropertyMap. Restore untouched native items and target existing custom
    // descriptions directly, so a delta cannot manufacture case duplicates.
    TagLib::MP4::Tag *mp4 = nullptr;
    TagLib::MP4::ItemMap originalMP4Items;
    if (auto *mp4File = dynamic_cast<TagLib::MP4::File *>(file)) {
        mp4 = mp4File->tag();
        originalMP4Items = mp4->itemMap();
    }
    TagLib::PropertyMap properties = file->properties();
    for (NSString *key in keysToRemove ?: @[]) {
        NSString *trimmedKey = TrimmedStringOrNil(key);
        if (trimmedKey) properties.erase(NSStringToTagString(trimmedKey));
    }

    // Delta callers specify actual value arrays, not a display projection.
    // Preserve whitespace, empty strings, duplicates, and value boundaries.
    TagLib::PropertyMap replacements;
    for (NSString *key in valuesToSet ?: @{}) {
        TagLib::StringList values;
        for (NSString *value in valuesToSet[key]) {
            values.append(NSStringToTagString(value));
        }
        replacements.replace(NSStringToTagString(key), values);
    }
    for (auto iterator = replacements.begin(); iterator != replacements.end(); ++iterator) {
        properties.replace(iterator->first, iterator->second);
    }

    if (auto *asf = dynamic_cast<TagLib::ASF::File *>(file)) {
        const auto beforeProperties = file->properties();
        for (const char *key : { "TITLE", "ARTIST", "ALBUM", "COMMENT", "GENRE" }) {
            NSString *name = @(key);
            if ([keysToRemove containsObject:name] && !valuesToSet[name]) {
                RemoveASFCommonAttributeAlias(asf->tag(), key);
            } else if (valuesToSet[name]) {
                TagLib::StringList requested;
                for (NSString *value in valuesToSet[name]) requested.append(NSStringToTagString(value));
                auto current = beforeProperties;
                if (current[key] != requested) RemoveASFCommonAttributeAlias(asf->tag(), key);
            }
        }
    }
    SetPropertiesPreservingNativeDates(file, properties);
    if (NativeXiphComment(file) || NativeAPETag(file)) {
        auto dates = VisibleMetadataProperties(file);
        NSMutableSet<NSString *> *changedDates = [NSMutableSet set];
        for (NSString *key in keysToRemove ?: @[]) {
            NSString *upper = key.uppercaseString;
            if ([upper isEqualToString:@"YEAR"] || [upper isEqualToString:@"DATE"]) {
                dates.erase(NSStringToTagString(upper));
                [changedDates addObject:upper];
            }
        }
        for (NSString *key in valuesToSet ?: @{}) {
            NSString *upper = key.uppercaseString;
            if ([upper isEqualToString:@"YEAR"] || [upper isEqualToString:@"DATE"]) {
                TagLib::StringList values;
                for (NSString *value in valuesToSet[key]) values.append(NSStringToTagString(value));
                dates.replace(NSStringToTagString(upper), values);
                [changedDates addObject:upper];
            }
        }
        for (NSString *key in changedDates) SetExactNativeDateKeys(file, dates, key.UTF8String);
    }
    if (mp4) {
        NSMutableSet<NSString *> *descriptions = [NSMutableSet set];
        for (const auto &[key, item] : originalMP4Items) {
            NSString *description = MP4FreeformDescriptionForItemKey(key);
            if (description) [descriptions addObject:description.uppercaseString];
        }
        const auto generated = mp4->itemMap();
        for (const auto &[key, item] : generated) {
            NSString *description = MP4FreeformDescriptionForItemKey(key);
            if (description && [descriptions containsObject:description.uppercaseString]) mp4->removeItem(key);
        }
        for (const auto &mapping : kMetadataFieldMappings) {
            if (!mapping.mp4FreeformDescription) continue;
            bool originallyFreeform = false;
            for (const auto &[key, item] : originalMP4Items) {
                if (MP4FreeformDescriptionForItemKey(key) && MP4ItemMatchesField(key, mapping)) originallyFreeform = true;
            }
            if (!originallyFreeform) continue;
            bool edited = valuesToSet[@(mapping.canonicalPropertyKey)] || [keysToRemove containsObject:@(mapping.canonicalPropertyKey)];
            for (const char *alias : mapping.propertyAliases) {
                if (alias) edited |= valuesToSet[@(alias)] || [keysToRemove containsObject:@(alias)];
            }
            if (edited) continue;
            for (const auto &[key, item] : generated) {
                if (!originalMP4Items.contains(key) && MP4ItemMatchesField(key, mapping)) mp4->removeItem(key);
            }
        }
        NSMutableSet<NSString *> *written = [NSMutableSet set];
        for (const auto &[key, item] : originalMP4Items) {
            NSString *description = MP4FreeformDescriptionForItemKey(key);
            if (!description) continue;
            NSString *normalized = description.uppercaseString;
            NSArray<NSString *> *replacement = valuesToSet[normalized];
            if (replacement) {
                if ([written containsObject:normalized]) continue;
                TagLib::StringList values;
                for (NSString *value in replacement) values.append(NSStringToTagString(value));
                mp4->setItem(key, TagLib::MP4::Item(values));
                [written addObject:normalized];
            } else if (![keysToRemove containsObject:normalized]) {
                mp4->setItem(key, item);
            }
        }
    }
    if (!SaveMetadataPreservingOtherTagSurfaces(file)) {
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

+ (BOOL)applyPropertyMapValuesPreservingInfoSurfaceInPlace:(NSDictionary<NSString *, NSArray<NSString *> *> *)valuesToSet
                                             removingKeys:(NSArray<NSString *> *)keysToRemove
                                   preserveInfoOnlyValues:(BOOL)preserveInfoOnlyValues
                                                    toURL:(NSURL *)fileURL
                                                    error:(NSError **)error
{
    try {
    TAGLIB_BRIDGE_SERIAL_GUARD();
    if (DetectTagFileFormat(fileURL.pathExtension) != TLTagFileFormatWAV) {
        return [self applyPropertyMapValuesInPlace:valuesToSet removingKeys:keysToRemove toURL:fileURL error:error];
    }
    TagLib::RIFF::WAV::File wav(fileURL.path.UTF8String);
    if (!wav.isValid()) {
        return [self applyPropertyMapValuesInPlace:valuesToSet removingKeys:keysToRemove toURL:fileURL error:error];
    }

    TagLib::PropertyMap info = wav.InfoTag()->properties();
    TagLib::PropertyMap id3 = wav.ID3v2Tag()->properties();
    for (NSString *key in keysToRemove ?: @[]) {
        NSString *trimmedKey = TrimmedStringOrNil(key);
        if (!trimmedKey) continue;
        id3.erase(NSStringToTagString(trimmedKey));
    }
    for (NSString *key in valuesToSet ?: @{}) {
        NSString *trimmedKey = TrimmedStringOrNil(key);
        if (!trimmedKey) continue;
        TagLib::String tagKey = NSStringToTagString(trimmedKey);
        // RIFF INFO is already preserved by the Basic writer leaving that
        // surface untouched. Do not copy INFO-only values into ID3.
        if (preserveInfoOnlyValues && info.contains(tagKey) && !id3.contains(tagKey)) {
            continue;
        }
        TagLib::StringList values;
        for (NSString *value in valuesToSet[key]) {
            values.append(NSStringToTagString(value));
        }
        id3.replace(tagKey, values);
    }
    SetID3PropertiesPreservingNativeDates(wav.ID3v2Tag(), id3);
    if (!wav.save(TagLib::RIFF::WAV::File::ID3v2, TagLib::File::StripNone)) {
        if (error) {
            *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                         code:9254
                                     userInfo:@{ NSLocalizedDescriptionKey : @"TagLib could not save ID3v2 metadata changes" }];
        }
        return NO;
    }
    return YES;
    TAGLIB_BRIDGE_CATCH_WITH_ERROR(error, @"INFO-preserving property-map mutation", NO)
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
    return [self writeNumberPairsInPlaceWithTrackNumber:trackNumber
                                            totalTracks:totalTracks
                                        updateTrackPair:updateTrackPair
                                             discNumber:discNumber
                                              totalDiscs:totalDiscs
                                         updateDiscPair:updateDiscPair
                                         movementNumber:0
                                           movementCount:0
                                      updateMovementPair:NO
                                                   toURL:fileURL
                                                   error:error];
}

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
                                          error:(NSError **)error
{
    try {
    if (!fileURL || !fileURL.isFileURL || trackNumber < 0 || totalTracks < 0 ||
        discNumber < 0 || totalDiscs < 0 || movementNumber < 0 || movementCount < 0 ||
        trackNumber > std::numeric_limits<int>::max() || totalTracks > std::numeric_limits<int>::max() ||
        discNumber > std::numeric_limits<int>::max() || totalDiscs > std::numeric_limits<int>::max() ||
        movementNumber > std::numeric_limits<int>::max() || movementCount > std::numeric_limits<int>::max()) {
        if (error) {
            *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                         code:9260
                                     userInfo:@{ NSLocalizedDescriptionKey : @"Number-pair changes require a file URL and values between 0 and INT_MAX" }];
        }
        return NO;
    }

    const char *filePath = fileURL.path.UTF8String;
    if (!filePath) {
        if (error) *error = PropertyMapDeltaError(9261, @"Invalid audio file path");
        return NO;
    }

    TAGLIB_BRIDGE_SERIAL_GUARD();
    TLTagFileFormat format = DetectTagFileFormat(fileURL);
    NSString *trackText = BuildTRCKString(trackNumber, totalTracks, 0);
    NSString *discText = BuildTRCKString(discNumber, totalDiscs, 0);
    NSString *movementText = BuildTRCKString(movementNumber, movementCount, 0);

    if (format == TLTagFileFormatMP4) {
        if (updateMovementPair && (movementNumber > std::numeric_limits<short>::max() || movementCount > std::numeric_limits<short>::max())) {
            if (error) *error = PropertyMapDeltaError(9260, @"MP4 movement integers must be between 0 and 32767");
            return NO;
        }
        TagLib::MP4::File file(filePath);
        if (!file.isValid() || !file.tag()) {
            if (error) *error = PropertyMapDeltaError(9262, @"Unable to open MP4/M4A file for native number-pair mutation");
            return NO;
        }
        TagLib::MP4::Tag *tag = file.tag();
        if (updateTrackPair) {
            // Never create or rename private number-text provenance. Native
            // trkn/disk are the only totals. Legacy atoms are read-only until an
            // explicit, version-guarded normalization plan retires them.
            RemoveRecognizedMP4NumberPairFreeformItems(tag, true, false);
            tag->setTrack(trackNumber > 0 ? (unsigned int)trackNumber : 0);
            SetMP4IntPairItem(tag, "trkn", trackNumber, totalTracks);
        }
        if (updateDiscPair) {
            RemoveRecognizedMP4NumberPairFreeformItems(tag, false, true);
            SetMP4IntPairItem(tag, "disk", discNumber, totalDiscs);
        }
        if (updateMovementPair) {
            SetMP4MovementItem(tag, "\xA9" "mvi", @"MOVEMENTNUMBER", movementNumber);
            SetMP4MovementItem(tag, "\xA9" "mvc", @"MOVEMENTCOUNT", movementCount);
        }
        if (!file.save()) {
            if (error) *error = PropertyMapDeltaError(9263, @"TagLib could not save native MP4/M4A number pairs");
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
    if (auto *tag = NativeID3v2TagForWrite(file)) {
        if (updateTrackPair) SetNativeID3NumberPair(tag, "TRCK", trackText, @[ @"TRACKTOTAL", @"TOTALTRACKS" ]);
        if (updateDiscPair) SetNativeID3NumberPair(tag, "TPOS", discText, @[ @"DISCTOTAL", @"TOTALDISCS" ]);
        if (updateMovementPair) SetNativeID3NumberPair(tag, "MVIN", movementText, @[ @"MOVEMENTNUMBER", @"MOVEMENTCOUNT" ]);
        if (!SaveMetadataPreservingOtherTagSurfaces(file)) {
            if (error) *error = PropertyMapDeltaError(9265, @"TagLib could not save native ID3 number pairs");
            return NO;
        }
        return YES;
    }
    TagLib::PropertyMap properties = file->properties();
    const bool isAPE = dynamic_cast<TagLib::APE::File *>(file) != nullptr ||
        dynamic_cast<TagLib::WavPack::File *>(file) != nullptr ||
        dynamic_cast<TagLib::MPC::File *>(file) != nullptr;
    if (updateTrackPair) {
        NSString *existingTrackNumber = FirstStringFromProperty(properties, {"TRACKNUMBER", "TRACK"});
        properties.erase("TRACK");
        properties.erase("TRACKNUMBER");
        properties.erase("TOTALTRACKS");
        SetPropertyMapDynamicString(
            properties,
            isAPE ? @"TRACK" : @"TRACKNUMBER",
            BuildPropertyMapNumberTextPreservingFormatting(existingTrackNumber, trackNumber)
        );
        SetPropertyMapDynamicString(properties, @"TRACKTOTAL", totalTracks > 0 ? [NSString stringWithFormat:@"%ld", (long)totalTracks] : nil);
    }
    if (updateDiscPair) {
        NSString *existingDiscNumber = FirstStringFromProperty(properties, {"DISCNUMBER", "DISC"});
        properties.erase("DISC");
        properties.erase("DISCNUMBER");
        properties.erase("TOTALDISCS");
        SetPropertyMapDynamicString(
            properties,
            isAPE ? @"DISC" : @"DISCNUMBER",
            BuildPropertyMapNumberTextPreservingFormatting(existingDiscNumber, discNumber)
        );
        SetPropertyMapDynamicString(properties, @"DISCTOTAL", totalDiscs > 0 ? [NSString stringWithFormat:@"%ld", (long)totalDiscs] : nil);
    }
    if (updateMovementPair) {
        SetPropertyMapDynamicString(
            properties,
            @"MOVEMENTNUMBER",
            movementNumber > 0 ? [NSString stringWithFormat:@"%ld", (long)movementNumber] : nil
        );
        SetPropertyMapDynamicString(
            properties,
            @"MOVEMENTCOUNT",
            movementCount > 0 ? [NSString stringWithFormat:@"%ld", (long)movementCount] : nil
        );
    }
    if (dynamic_cast<TagLib::ASF::File *>(file)) CombineASFNumberTotals(properties);
    SetPropertiesPreservingNativeDates(file, properties);
    if (!SaveMetadataPreservingOtherTagSurfaces(file)) {
        if (error) *error = PropertyMapDeltaError(9267, @"TagLib could not save number-pair changes");
        return NO;
    }
    return YES;
    TAGLIB_BRIDGE_CATCH_WITH_ERROR(error, @"Number-pair mutation", NO)
}

+ (BOOL)writeExplicitAdvisoryInPlace:(TagLibExplicitAdvisory)advisory
                               toURL:(NSURL *)fileURL
                               error:(NSError **)error
{
    try {
    const bool validAdvisory = advisory == TagLibExplicitAdvisoryUnspecified ||
        advisory == TagLibExplicitAdvisoryNotExplicit ||
        advisory == TagLibExplicitAdvisoryExplicit ||
        advisory == TagLibExplicitAdvisoryClean;
    if (!fileURL || !fileURL.isFileURL || !validAdvisory) {
        if (error) *error = PropertyMapDeltaError(9270, @"Explicit-advisory changes require a file URL and valid advisory state");
        return NO;
    }

    const char *filePath = fileURL.path.UTF8String;
    if (!filePath) {
        if (error) *error = PropertyMapDeltaError(9271, @"Invalid audio file path");
        return NO;
    }

    TAGLIB_BRIDGE_SERIAL_GUARD();
    TLTagFileFormat format = DetectTagFileFormat(fileURL);
    NSString *serialized = nil;
    switch (advisory) {
        case TagLibExplicitAdvisoryNotExplicit: serialized = @"0"; break;
        case TagLibExplicitAdvisoryExplicit: serialized = @"1"; break;
        case TagLibExplicitAdvisoryClean: serialized = @"2"; break;
        case TagLibExplicitAdvisoryUnspecified: break;
    }

    if (format == TLTagFileFormatMP4) {
        TagLib::MP4::File file(filePath);
        if (!file.isValid() || !file.tag()) {
            if (error) *error = PropertyMapDeltaError(9272, @"Unable to open MP4/M4A file for native advisory mutation");
            return NO;
        }
        TagLib::MP4::Tag *tag = file.tag();
        ApplyCanonicalMP4Advisory(tag, advisory);
        if (!file.save()) {
            if (error) *error = PropertyMapDeltaError(9273, @"TagLib could not save native MP4/M4A advisory metadata");
            return NO;
        }
        return YES;
    }

    if (format == TLTagFileFormatMPEGID3 || format == TLTagFileFormatMPEGAAC) {
        TagLib::MPEG::File file(filePath);
        if (!file.isValid()) {
            if (error) *error = PropertyMapDeltaError(9274, @"Unable to open MPEG file for advisory mutation");
            return NO;
        }
        TagLib::ID3v2::Tag *tag = PrepareMPEGID3v2Tag(file);
        const std::initializer_list<const char *> descriptions = {
            "ITUNESADVISORY", "ADVISORY", "EXPLICITCONTENT", "EXPLICIT"
        };
        TagLib::ID3v2::FrameList frames = tag->frameList("TXXX");
        for (auto iterator = frames.begin(); iterator != frames.end(); ++iterator) {
            auto *frame = dynamic_cast<TagLib::ID3v2::UserTextIdentificationFrame *>(*iterator);
            if (!frame) continue;
            for (const char *description : descriptions) {
                if (frame->description().upper() == TagLib::String(description, TagLib::String::UTF8)) {
                    tag->removeFrame(frame);
                    break;
                }
            }
        }
        if (serialized) SetID3v2UserTextFrame(tag, "ITUNESADVISORY", serialized);
        if (!SaveMetadataPreservingOtherTagSurfaces(&file)) {
            if (error) *error = PropertyMapDeltaError(9275, @"TagLib could not save MPEG advisory metadata");
            return NO;
        }
        return YES;
    }

    TagLib::FileRef fileRef(filePath, true, TagLib::AudioProperties::Fast);
    TagLib::File *file = fileRef.file();
    if (fileRef.isNull() || !file || !file->isValid()) {
        if (error) *error = PropertyMapDeltaError(9276, @"Unable to open audio file for advisory mutation");
        return NO;
    }
    if (auto *asf = dynamic_cast<TagLib::ASF::File *>(file)) {
        for (const char *key : { "ITUNESADVISORY", "ADVISORY", "EXPLICITCONTENT", "EXPLICIT" }) asf->tag()->removeItem(key);
        if (serialized) asf->tag()->setAttribute("ITUNESADVISORY", TagLib::ASF::Attribute(NSStringToTagString(serialized)));
        if (!SaveMetadataPreservingOtherTagSurfaces(file)) {
            if (error) *error = PropertyMapDeltaError(9277, @"Could not save native ASF advisory");
            return NO;
        }
        return YES;
    }
    TagLib::PropertyMap properties = file->properties();
    for (const char *key : { "ITUNESADVISORY", "ADVISORY", "EXPLICITCONTENT", "EXPLICIT", "RTNG" }) {
        properties.erase(key);
    }
    SetPropertyMapDynamicString(properties, @"ITUNESADVISORY", serialized);
    SetPropertiesPreservingNativeDates(file, properties);
    if (!SaveMetadataPreservingOtherTagSurfaces(file)) {
        if (error) *error = PropertyMapDeltaError(9277, @"TagLib could not save advisory metadata");
        return NO;
    }
    return YES;
    TAGLIB_BRIDGE_CATCH_WITH_ERROR(error, @"Explicit-advisory mutation", NO)
}
