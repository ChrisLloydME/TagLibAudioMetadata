static bool IsMP4LikeExtension(NSString * _Nullable ext) {
    return DetectTagFileFormat(ext) == AudioMatorTagFileFormatMP4;
}

static void SetMP4TextItem(TagLib::MP4::Tag *tag,
                           const char *key,
                           NSString * _Nullable value)
{
    if (!tag || !key) return;

    NSString *trimmed = TrimmedStringOrNil(value);
    if (!trimmed) {
        tag->removeItem(key);
        return;
    }

    TagLib::StringList list;
    list.append(NSStringToTagString(trimmed));
    tag->setItem(key, TagLib::MP4::Item(list));
}

static NSString * _Nullable MP4TextItemValue(const TagLib::MP4::ItemMap &items,
                                             const char *key)
{
    if (!key || !items.contains(key)) {
        return nil;
    }

    return TrimmedStringOrNil(TagStringToNSString(items[key].toStringList().toString(", ")));
}

static void SetMP4IntPairItem(TagLib::MP4::Tag *tag,
                              const char *key,
                              NSInteger number,
                              NSInteger total)
{
    if (!tag || !key) return;

    int first = (number > 0) ? (int)number : 0;
    int second = (total > 0) ? (int)total : 0;

    if (first <= 0 && second <= 0) {
        tag->removeItem(key);
        return;
    }

    tag->setItem(key, TagLib::MP4::Item(first, second));
}

static NSString * _Nullable MP4FreeformDescriptionForItemKey(const TagLib::String &itemKey)
{
    static const std::string prefix = "----:com.apple.iTunes:";
    std::string rawKey = itemKey.to8Bit(true);
    if (rawKey.rfind(prefix, 0) != 0) {
        return nil;
    }

    return TrimmedStringOrNil([NSString stringWithUTF8String:rawKey.substr(prefix.size()).c_str()]);
}

static void SetMP4FreeformTextItem(TagLib::MP4::Tag *tag,
                                   NSString * _Nullable description,
                                   NSString * _Nullable value)
{
    NSString *trimmedDescription = TrimmedStringOrNil(description);
    if (!trimmedDescription) {
        return;
    }

    NSString *fullKey = [@"----:com.apple.iTunes:" stringByAppendingString:trimmedDescription];
    std::string key = fullKey.UTF8String ? fullKey.UTF8String : "";
    if (key.empty()) {
        return;
    }

    SetMP4TextItem(tag, key.c_str(), value);
}

static void SetPropertyMapString(TagLib::PropertyMap &properties,
                                 const char *key,
                                 NSString * _Nullable value)
{
    if (!key) return;

    NSString *trimmed = TrimmedStringOrNil(value);
    if (!trimmed) {
        properties.erase(key);
        return;
    }

    TagLib::StringList values;
    values.append(NSStringToTagString(trimmed));
    properties.replace(key, values);
}

static void SetPropertyMapNumberText(TagLib::PropertyMap &properties,
                                     const char *key,
                                     NSString * _Nullable value)
{
    SetPropertyMapString(properties, key, value);
}

static void ParseNumberPairFromNSString(NSString *text,
                                        NSInteger &number,
                                        NSInteger &total,
                                        NSInteger &padWidth);

static NSInteger PropertyMapNumberTotal(TagLib::PropertyMap properties,
                                        const char *numberKey,
                                        const char *primaryTotalKey,
                                        const char *alternateTotalKey)
{
    if (numberKey && properties.contains(numberKey)) {
        NSInteger number = 0;
        NSInteger total = 0;
        NSInteger padWidth = 0;
        ParseNumberPairFromNSString(
            TrimmedStringOrNil(TagStringToNSString(properties[numberKey].toString(", "))),
            number,
            total,
            padWidth
        );
        if (total > 0) {
            return total;
        }
    }

    if (primaryTotalKey && properties.contains(primaryTotalKey)) {
        return ExtractNumber(properties[primaryTotalKey].toString(", "));
    }

    if (alternateTotalKey && properties.contains(alternateTotalKey)) {
        return ExtractNumber(properties[alternateTotalKey].toString(", "));
    }

    return 0;
}

static void SetPropertyMapDynamicString(TagLib::PropertyMap &properties,
                                        NSString * _Nullable key,
                                        NSString * _Nullable value)
{
    NSString *trimmedKey = TrimmedStringOrNil(key);
    if (!trimmedKey) {
        return;
    }

    TagLib::String dynamicKey(trimmedKey.UTF8String, TagLib::String::UTF8);
    NSString *trimmedValue = TrimmedStringOrNil(value);
    if (!trimmedValue) {
        properties.erase(dynamicKey);
        return;
    }

    TagLib::StringList values;
    values.append(NSStringToTagString(trimmedValue));
    properties.replace(dynamicKey, values);
}

static void SetCustomMetadataField(TagLibAudioMetadata *metadata,
                                   NSString * _Nullable key,
                                   NSString * _Nullable value)
{
    if (!metadata) {
        return;
    }

    NSString *trimmedKey = TrimmedStringOrNil(key);
    NSString *trimmedValue = TrimmedStringOrNil(value);
    if (!trimmedKey || !trimmedValue || IsKnownMetadataFieldKey(trimmedKey)) {
        return;
    }

    NSMutableDictionary<NSString *, NSString *> *customFields =
        metadata.customFields ? [metadata.customFields mutableCopy] : [NSMutableDictionary dictionary];
    customFields[trimmedKey] = trimmedValue;
    metadata.customFields = customFields.count > 0 ? [customFields copy] : nil;
}

static void MergeCustomPropertyMapFields(const TagLib::PropertyMap &properties,
                                         TagLibAudioMetadata *metadata)
{
    if (!metadata || properties.isEmpty()) {
        return;
    }

    for (const auto &[key, values] : properties) {
        if (values.isEmpty()) {
            continue;
        }

        NSString *fieldKey = TrimmedStringOrNil(TagStringToNSString(key));
        if (!fieldKey || IsKnownMetadataFieldKey(fieldKey)) {
            continue;
        }

        NSString *fieldValue = TrimmedStringOrNil(TagStringToNSString(values.toString("; ")));
        SetCustomMetadataField(metadata, fieldKey, fieldValue);
    }
}

static void ApplyCustomFieldsToPropertyMap(TagLib::PropertyMap &properties,
                                           NSDictionary<NSString *, NSString *> * _Nullable customFields)
{
    if (!customFields || customFields.count == 0) {
        return;
    }

    for (NSString *key in customFields) {
        if (IsKnownMetadataFieldKey(key)) {
            continue;
        }

        SetPropertyMapDynamicString(properties, key, customFields[key]);
    }
}

static bool ParseExplicitTagValue(const TagLib::String &value, BOOL &explicitContent)
{
    if (value.isEmpty()) {
        return false;
    }

    TagLib::String upper = value.upper();
    std::string raw = upper.to8Bit(true);

    if (upper == "EXPLICIT" || upper == "TRUE" || upper == "YES") {
        explicitContent = YES;
        return true;
    }

    if (upper == "CLEAN" || upper == "FALSE" || upper == "NO" || upper == "NONE") {
        explicitContent = NO;
        return true;
    }

    if (raw == "4" || raw == "1") {
        explicitContent = YES;
        return true;
    }

    if (raw == "2" || raw == "0" || raw == "-1") {
        explicitContent = NO;
        return true;
    }

    return false;
}

static void SetParsedExplicitAdvisory(TagLibAudioMetadata *metadata, BOOL explicitContent)
{
    metadata.explicitAdvisory = explicitContent
        ? TagLibExplicitAdvisoryExplicit
        : TagLibExplicitAdvisoryClean;
}

static NSString * _Nullable SerializedExplicitAdvisory(TagLibAudioMetadata *metadata)
{
    switch (metadata.explicitAdvisory) {
        case TagLibExplicitAdvisoryExplicit: return @"1";
        case TagLibExplicitAdvisoryClean: return @"2";
        case TagLibExplicitAdvisoryUnspecified: return nil;
    }
}

static void ApplyExplicitPropertyKeys(const TagLib::PropertyMap &properties,
                                      TagLibAudioMetadata *metadata)
{
    if (!metadata || properties.isEmpty()) return;

    static const char *kExplicitKeys[] = {
        "ITUNESADVISORY",
        "ADVISORY",
        "EXPLICITCONTENT",
        "EXPLICIT"
    };

    for (const char *key : kExplicitKeys) {
        if (!properties.contains(key) || properties[key].isEmpty()) {
            continue;
        }

        for (const auto &explicitCandidate : properties[key]) {
            BOOL explicitValue = NO;
            if (ParseExplicitTagValue(explicitCandidate, explicitValue)) {
                SetParsedExplicitAdvisory(metadata, explicitValue);
                return;
            }
        }
    }
}

static bool ApplyKnownCustomMetadataField(NSString * _Nullable key,
                                          NSString * _Nullable value,
                                          TagLibAudioMetadata *metadata)
{
    if (!metadata) {
        return false;
    }

    NSString *normalizedKey = UppercaseTrimmedString(key);
    NSString *trimmedValue = TrimmedStringOrNil(value);
    if (!normalizedKey) {
        return false;
    }

    if ([normalizedKey isEqualToString:@"RELEASETYPE"] ||
        [normalizedKey isEqualToString:@"MUSICBRAINZ ALBUM TYPE"] ||
        [normalizedKey isEqualToString:@"MUSICBRAINZ_ALBUMTYPE"]) {
        metadata.releaseType = trimmedValue;
        return true;
    }

    if ([normalizedKey isEqualToString:@"RELEASESTATUS"] ||
        [normalizedKey isEqualToString:@"MUSICBRAINZ ALBUM STATUS"] ||
        [normalizedKey isEqualToString:@"MUSICBRAINZ_ALBUMSTATUS"]) {
        metadata.releaseStatus = trimmedValue;
        return true;
    }

    if ([normalizedKey isEqualToString:@"BARCODE"] ||
        [normalizedKey isEqualToString:@"UPC"] ||
        [normalizedKey isEqualToString:@"EAN"]) {
        metadata.barcode = trimmedValue;
        return true;
    }

    if ([normalizedKey isEqualToString:@"CATALOGNUMBER"] ||
        [normalizedKey isEqualToString:@"CATALOG NUMBER"] ||
        [normalizedKey isEqualToString:@"CATALOG"]) {
        metadata.catalogNumber = trimmedValue;
        return true;
    }

    if ([normalizedKey isEqualToString:@"RELEASECOUNTRY"] ||
        [normalizedKey isEqualToString:@"MUSICBRAINZ ALBUM RELEASE COUNTRY"] ||
        [normalizedKey isEqualToString:@"MUSICBRAINZ_ALBUMRELEASECOUNTRY"]) {
        metadata.releaseCountry = trimmedValue;
        return true;
    }

    if ([normalizedKey isEqualToString:@"ARTISTTYPE"] ||
        [normalizedKey isEqualToString:@"MUSICBRAINZ ARTIST TYPE"] ||
        [normalizedKey isEqualToString:@"MUSICBRAINZ_ARTISTTYPE"]) {
        metadata.artistType = trimmedValue;
        return true;
    }

    if ([normalizedKey isEqualToString:@"MUSICBRAINZ ARTIST ID"] ||
        [normalizedKey isEqualToString:@"MUSICBRAINZ ARTISTID"] ||
        [normalizedKey isEqualToString:@"MUSICBRAINZ_ARTISTID"]) {
        metadata.musicBrainzArtistId = trimmedValue;
        return true;
    }

    if ([normalizedKey isEqualToString:@"MUSICBRAINZ ALBUM ID"] ||
        [normalizedKey isEqualToString:@"MUSICBRAINZ ALBUMID"] ||
        [normalizedKey isEqualToString:@"MUSICBRAINZ_ALBUMID"]) {
        metadata.musicBrainzAlbumId = trimmedValue;
        return true;
    }

    if ([normalizedKey isEqualToString:@"MUSICBRAINZ ALBUM ARTIST ID"] ||
        [normalizedKey isEqualToString:@"MUSICBRAINZ ALBUMARTISTID"] ||
        [normalizedKey isEqualToString:@"MUSICBRAINZ_ALBUMARTISTID"]) {
        metadata.musicBrainzAlbumArtistId = trimmedValue;
        return true;
    }

    if ([normalizedKey isEqualToString:@"MUSICBRAINZ TRACK ID"] ||
        [normalizedKey isEqualToString:@"MUSICBRAINZ TRACKID"] ||
        [normalizedKey isEqualToString:@"MUSICBRAINZ_TRACKID"]) {
        metadata.musicBrainzTrackId = trimmedValue;
        return true;
    }

    if ([normalizedKey isEqualToString:@"MUSICBRAINZ RELEASE GROUP ID"] ||
        [normalizedKey isEqualToString:@"MUSICBRAINZ RELEASEGROUPID"] ||
        [normalizedKey isEqualToString:@"MUSICBRAINZ_RELEASEGROUPID"]) {
        metadata.musicBrainzReleaseGroupId = trimmedValue;
        return true;
    }

    if ([normalizedKey isEqualToString:@"MUSICBRAINZ RELEASE TRACK ID"] ||
        [normalizedKey isEqualToString:@"MUSICBRAINZ RELEASETRACKID"] ||
        [normalizedKey isEqualToString:@"MUSICBRAINZ_RELEASETRACKID"]) {
        metadata.musicBrainzReleaseTrackId = trimmedValue;
        return true;
    }

    if ([normalizedKey isEqualToString:@"MUSICBRAINZ WORK ID"] ||
        [normalizedKey isEqualToString:@"MUSICBRAINZ WORKID"] ||
        [normalizedKey isEqualToString:@"MUSICBRAINZ_WORKID"]) {
        metadata.musicBrainzWorkId = trimmedValue;
        return true;
    }

    if ([normalizedKey isEqualToString:@"ACOUSTID ID"] ||
        [normalizedKey isEqualToString:@"ACOUSTID_ID"]) {
        metadata.acoustId = trimmedValue;
        return true;
    }

    if ([normalizedKey isEqualToString:@"ACOUSTID FINGERPRINT"] ||
        [normalizedKey isEqualToString:@"ACOUSTID_FINGERPRINT"]) {
        metadata.acoustIdFingerprint = trimmedValue;
        return true;
    }

    if ([normalizedKey isEqualToString:@"MUSICIP_PUID"]) {
        metadata.musicIpPuid = trimmedValue;
        return true;
    }

    if ([normalizedKey isEqualToString:@"ASIN"]) {
        metadata.asin = trimmedValue;
        return true;
    }

    if ([normalizedKey isEqualToString:@"ORIGINALALBUM"]) {
        metadata.originalAlbum = trimmedValue;
        return true;
    }

    if ([normalizedKey isEqualToString:@"ORIGINALARTIST"]) {
        metadata.originalArtist = trimmedValue;
        return true;
    }

    if ([normalizedKey isEqualToString:@"LABEL"]) {
        metadata.label = trimmedValue;
        return true;
    }

    if ([normalizedKey isEqualToString:@"YEAR"]) {
        metadata.year = trimmedValue;
        if (metadata.releaseDate.length == 0 && trimmedValue.length > 0) {
            metadata.releaseDate = trimmedValue;
        }
        return true;
    }

    if ([normalizedKey isEqualToString:@"TRACKNUMBER"] ||
        [normalizedKey isEqualToString:@"TRACK"]) {
        metadata.trackNumberText = PreferredNumberText(metadata.trackNumberText, trimmedValue);
        if (trimmedValue.length > 0) {
            NSInteger trackNum = 0, trackTotal = 0;
            ParseNumberPair(NSStringToTagString(trimmedValue), trackNum, trackTotal);
            if (trackNum > 0) metadata.trackNumber = trackNum;
            if (trackTotal > 0) metadata.totalTracks = trackTotal;
        }
        return true;
    }

    if ([normalizedKey isEqualToString:@"TRACKTOTAL"] ||
        [normalizedKey isEqualToString:@"TOTALTRACKS"]) {
        metadata.totalTracks = trimmedValue.length > 0 ? trimmedValue.integerValue : 0;
        return true;
    }

    if ([normalizedKey isEqualToString:@"DISCNUMBER"] ||
        [normalizedKey isEqualToString:@"DISC"]) {
        metadata.discNumberText = PreferredNumberText(metadata.discNumberText, trimmedValue);
        if (trimmedValue.length > 0) {
            NSInteger discNum = 0, discTotal = 0;
            ParseNumberPair(NSStringToTagString(trimmedValue), discNum, discTotal);
            if (discNum > 0) metadata.discNumber = discNum;
            if (discTotal > 0) metadata.totalDiscs = discTotal;
        }
        return true;
    }

    if ([normalizedKey isEqualToString:@"DISCTOTAL"] ||
        [normalizedKey isEqualToString:@"TOTALDISCS"]) {
        metadata.totalDiscs = trimmedValue.length > 0 ? trimmedValue.integerValue : 0;
        return true;
    }

    if ([normalizedKey isEqualToString:@"ISRC"]) {
        metadata.isrc = trimmedValue;
        return true;
    }

    if ([normalizedKey isEqualToString:@"ENCODEDBY"] ||
        [normalizedKey isEqualToString:@"ENCODING"]) {
        metadata.encodedBy = trimmedValue;
        return true;
    }

    if ([normalizedKey isEqualToString:@"ENCODERSETTINGS"]) {
        metadata.encoderSettings = trimmedValue;
        return true;
    }

    if ([normalizedKey isEqualToString:@"SUBTITLE"]) {
        metadata.subtitle = trimmedValue;
        return true;
    }

    if ([normalizedKey isEqualToString:@"DISCSUBTITLE"]) {
        metadata.discSubtitle = trimmedValue;
        return true;
    }

    if ([normalizedKey isEqualToString:@"GROUPING"]) {
        metadata.grouping = trimmedValue;
        return true;
    }

    if ([normalizedKey isEqualToString:@"LYRICIST"]) {
        metadata.lyricist = trimmedValue;
        return true;
    }

    if ([normalizedKey isEqualToString:@"CONDUCTOR"]) {
        metadata.conductor = trimmedValue;
        return true;
    }

    if ([normalizedKey isEqualToString:@"REMIXER"]) {
        metadata.remixer = trimmedValue;
        return true;
    }

    if ([normalizedKey isEqualToString:@"PRODUCER"]) {
        metadata.producer = trimmedValue;
        return true;
    }

    if ([normalizedKey isEqualToString:@"ENGINEER"]) {
        metadata.engineer = trimmedValue;
        return true;
    }

    if ([normalizedKey isEqualToString:@"MOVEMENT"] ||
        [normalizedKey isEqualToString:@"MOVEMENTNAME"]) {
        metadata.movement = trimmedValue;
        return true;
    }

    if ([normalizedKey isEqualToString:@"MOVEMENTNUMBER"]) {
        metadata.movementNumber = trimmedValue.length > 0 ? trimmedValue.integerValue : 0;
        return true;
    }

    if ([normalizedKey isEqualToString:@"MOVEMENTCOUNT"]) {
        metadata.movementCount = trimmedValue.length > 0 ? trimmedValue.integerValue : 0;
        return true;
    }

    if ([normalizedKey isEqualToString:@"WORK"]) {
        metadata.work = trimmedValue;
        return true;
    }

    if ([normalizedKey isEqualToString:@"MOOD"]) {
        metadata.mood = trimmedValue;
        return true;
    }

    if ([normalizedKey isEqualToString:@"LANGUAGE"]) {
        metadata.language = trimmedValue;
        return true;
    }

    if ([normalizedKey isEqualToString:@"INITIALKEY"] ||
        [normalizedKey isEqualToString:@"KEY"]) {
        metadata.musicalKey = trimmedValue;
        return true;
    }

    if ([normalizedKey isEqualToString:@"ORIGINAL YEAR"]) {
        metadata.originalReleaseDate = trimmedValue;
        return true;
    }

    if ([normalizedKey isEqualToString:@"MEDIATYPE"] ||
        [normalizedKey isEqualToString:@"MEDIA TYPE"] ||
        [normalizedKey isEqualToString:@"MEDIA"]) {
        metadata.mediaType = trimmedValue;
        return true;
    }

    if ([normalizedKey isEqualToString:@"ITUNESALBUMID"]) {
        metadata.itunesAlbumId = trimmedValue;
        return true;
    }

    if ([normalizedKey isEqualToString:@"ITUNESARTISTID"]) {
        metadata.itunesArtistId = trimmedValue;
        return true;
    }

    if ([normalizedKey isEqualToString:@"ITUNESCATALOGID"]) {
        metadata.itunesCatalogId = trimmedValue;
        return true;
    }

    if ([normalizedKey isEqualToString:@"ITUNESGENREID"]) {
        metadata.itunesGenreId = trimmedValue;
        return true;
    }

    if ([normalizedKey isEqualToString:@"ITUNESMEDIATYPE"]) {
        metadata.itunesMediaType = trimmedValue;
        return true;
    }

    if ([normalizedKey isEqualToString:@"ITUNESPURCHASEDATE"]) {
        metadata.itunesPurchaseDate = trimmedValue;
        return true;
    }

    if ([normalizedKey isEqualToString:@"ITUNNORM"]) {
        metadata.itunesNorm = trimmedValue;
        return true;
    }

    if ([normalizedKey isEqualToString:@"ITUNSMPB"]) {
        metadata.itunesSmpb = trimmedValue;
        return true;
    }

    if ([normalizedKey isEqualToString:@"REPLAYGAIN_TRACK_GAIN"]) {
        metadata.replayGainTrack = trimmedValue;
        return true;
    }

    if ([normalizedKey isEqualToString:@"REPLAYGAIN_ALBUM_GAIN"]) {
        metadata.replayGainAlbum = trimmedValue;
        return true;
    }

    if ([normalizedKey isEqualToString:@"ITUNESADVISORY"] ||
        [normalizedKey isEqualToString:@"ADVISORY"] ||
        [normalizedKey isEqualToString:@"EXPLICITCONTENT"] ||
        [normalizedKey isEqualToString:@"EXPLICIT"]) {
        BOOL explicitValue = NO;
        TagLib::String explicitString(trimmedValue.UTF8String, TagLib::String::UTF8);
        if (ParseExplicitTagValue(explicitString, explicitValue)) {
            SetParsedExplicitAdvisory(metadata, explicitValue);
        }
        return true;
    }

    return false;
}

static TagLib::PropertyMap PreservedUnknownPropertyMapEntries(const TagLib::PropertyMap &existingProperties)
{
    TagLib::PropertyMap properties;
    if (existingProperties.isEmpty()) {
        return properties;
    }

    for (const auto &[key, values] : existingProperties) {
        if (values.isEmpty()) {
            continue;
        }

        NSString *fieldKey = TrimmedStringOrNil(TagStringToNSString(key));
        if (!fieldKey) {
            continue;
        }

        if (IsHiddenInternalMetadataFieldKey(fieldKey) || IsKnownMetadataFieldKey(fieldKey)) {
            continue;
        }

        properties.replace(key, values);
    }

    return properties;
}

static TagLib::PropertyMap BuildGenericPropertyMap(
    TagLibAudioMetadata *metadata,
    const TagLib::PropertyMap * _Nullable existingProperties = nullptr
)
{
    TagLib::PropertyMap properties;
    if (existingProperties) {
        properties = PreservedUnknownPropertyMapEntries(*existingProperties);
    }
    if (!metadata) return properties;

    NSString *yearValue = TrimmedStringOrNil(metadata.year);
    if (!yearValue && metadata.releaseDate.length >= 4) {
        yearValue = [metadata.releaseDate substringToIndex:4];
    }

    SetPropertyMapString(properties, "TITLE", metadata.title);
    SetPropertyMapString(properties, "ARTIST", metadata.artist);
    SetPropertyMapString(properties, "ALBUM", metadata.album);
    SetPropertyMapString(properties, "COMPOSER", metadata.composer);
    SetPropertyMapString(properties, "GENRE", metadata.genre);
    SetPropertyMapString(properties, "COMMENT", metadata.comment);
    SetPropertyMapString(properties, "ALBUMARTIST", metadata.albumArtist);
    SetPropertyMapString(properties, "DATE", metadata.releaseDate.length > 0 ? metadata.releaseDate : metadata.year);
    SetPropertyMapString(properties, "YEAR", yearValue);
    SetPropertyMapString(properties, "ORIGINALDATE", metadata.originalReleaseDate);
    SetPropertyMapString(properties, "COPYRIGHT", metadata.copyright);
    SetPropertyMapString(properties, "LABEL", metadata.label);
    SetPropertyMapString(properties, "LYRICS", metadata.lyrics);
    SetPropertyMapString(properties, "ISRC", metadata.isrc);
    SetPropertyMapString(properties, "ENCODEDBY", metadata.encodedBy);
    SetPropertyMapString(properties, "ENCODERSETTINGS", metadata.encoderSettings);
    SetPropertyMapString(properties, "TITLESORT", metadata.sortTitle);
    SetPropertyMapString(properties, "ARTISTSORT", metadata.sortArtist);
    SetPropertyMapString(properties, "ALBUMSORT", metadata.sortAlbum);
    SetPropertyMapString(properties, "ALBUMARTISTSORT", metadata.sortAlbumArtist);
    SetPropertyMapString(properties, "COMPOSERSORT", metadata.sortComposer);
    SetPropertyMapString(properties, "CONDUCTOR", metadata.conductor);
    SetPropertyMapString(properties, "REMIXER", metadata.remixer);
    SetPropertyMapString(properties, "PRODUCER", metadata.producer);
    SetPropertyMapString(properties, "ENGINEER", metadata.engineer);
    SetPropertyMapString(properties, "LYRICIST", metadata.lyricist);
    SetPropertyMapString(properties, "SUBTITLE", metadata.subtitle);
    SetPropertyMapString(properties, "DISCSUBTITLE", metadata.discSubtitle);
    SetPropertyMapString(properties, "GROUPING", metadata.grouping);
    SetPropertyMapString(properties, "MOVEMENT", metadata.movement);
    SetPropertyMapString(properties, "MOVEMENTNAME", metadata.movement);
    SetPropertyMapString(
        properties,
        "MOVEMENTNUMBER",
        metadata.movementNumber > 0 ? [NSString stringWithFormat:@"%ld", (long)metadata.movementNumber] : nil
    );
    SetPropertyMapString(
        properties,
        "MOVEMENTCOUNT",
        metadata.movementCount > 0 ? [NSString stringWithFormat:@"%ld", (long)metadata.movementCount] : nil
    );
    SetPropertyMapString(properties, "WORK", metadata.work);
    SetPropertyMapString(properties, "MOOD", metadata.mood);
    SetPropertyMapString(properties, "LANGUAGE", metadata.language);
    SetPropertyMapString(properties, "INITIALKEY", metadata.musicalKey);
    SetPropertyMapString(properties, "RELEASETYPE", metadata.releaseType);
    SetPropertyMapString(properties, "RELEASESTATUS", metadata.releaseStatus);
    SetPropertyMapString(properties, "BARCODE", metadata.barcode);
    SetPropertyMapString(properties, "CATALOGNUMBER", metadata.catalogNumber);
    SetPropertyMapString(properties, "RELEASECOUNTRY", metadata.releaseCountry);
    SetPropertyMapString(properties, "ASIN", metadata.asin);
    SetPropertyMapString(properties, "ORIGINALALBUM", metadata.originalAlbum);
    SetPropertyMapString(properties, "ORIGINALARTIST", metadata.originalArtist);
    SetPropertyMapString(properties, "MUSICBRAINZ_ARTISTTYPE", metadata.artistType);
    SetPropertyMapString(properties, "MUSICBRAINZ_ARTISTID", metadata.musicBrainzArtistId);
    SetPropertyMapString(properties, "MUSICBRAINZ_ALBUMID", metadata.musicBrainzAlbumId);
    SetPropertyMapString(properties, "MUSICBRAINZ_ALBUMARTISTID", metadata.musicBrainzAlbumArtistId);
    SetPropertyMapString(properties, "MUSICBRAINZ_TRACKID", metadata.musicBrainzTrackId);
    SetPropertyMapString(properties, "MUSICBRAINZ_RELEASEGROUPID", metadata.musicBrainzReleaseGroupId);
    SetPropertyMapString(properties, "MUSICBRAINZ_RELEASETRACKID", metadata.musicBrainzReleaseTrackId);
    SetPropertyMapString(properties, "MUSICBRAINZ_WORKID", metadata.musicBrainzWorkId);
    SetPropertyMapString(properties, "ACOUSTID_ID", metadata.acoustId);
    SetPropertyMapString(properties, "ACOUSTID_FINGERPRINT", metadata.acoustIdFingerprint);
    SetPropertyMapString(properties, "MUSICIP_PUID", metadata.musicIpPuid);
    SetPropertyMapString(properties, "REPLAYGAIN_TRACK_GAIN", metadata.replayGainTrack);
    SetPropertyMapString(properties, "REPLAYGAIN_ALBUM_GAIN", metadata.replayGainAlbum);
    SetPropertyMapString(properties, "MEDIATYPE", metadata.mediaType);
    SetPropertyMapString(properties, "ITUNESALBUMID", metadata.itunesAlbumId);
    SetPropertyMapString(properties, "ITUNESARTISTID", metadata.itunesArtistId);
    SetPropertyMapString(properties, "ITUNESCATALOGID", metadata.itunesCatalogId);
    SetPropertyMapString(properties, "ITUNESGENREID", metadata.itunesGenreId);
    SetPropertyMapString(properties, "ITUNESMEDIATYPE", metadata.itunesMediaType);
    SetPropertyMapString(properties, "ITUNESPURCHASEDATE", metadata.itunesPurchaseDate);
    SetPropertyMapString(properties, "ITUNNORM", metadata.itunesNorm);
    SetPropertyMapString(properties, "ITUNSMPB", metadata.itunesSmpb);
    SetPropertyMapString(
        properties,
        "BPM",
        metadata.bpm > 0 ? [NSString stringWithFormat:@"%ld", (long)metadata.bpm] : nil
    );
    SetPropertyMapString(properties, "COMPILATION", metadata.compilation ? @"1" : nil);
    SetPropertyMapString(properties, "ITUNESADVISORY", SerializedExplicitAdvisory(metadata));

    NSString *trackText = BuildPropertyMapNumberTextPreservingFormatting(
        metadata.trackNumberText,
        metadata.trackNumber
    );
    if (!trackText && metadata.trackNumber > 0) {
        trackText = [NSString stringWithFormat:@"%ld", (long)metadata.trackNumber];
    }
    SetPropertyMapNumberText(properties, "TRACKNUMBER", trackText);
    SetPropertyMapString(
        properties,
        "TRACKTOTAL",
        metadata.totalTracks > 0 ? [NSString stringWithFormat:@"%ld", (long)metadata.totalTracks] : nil
    );

    NSString *discText = BuildPropertyMapNumberTextPreservingFormatting(
        metadata.discNumberText,
        metadata.discNumber
    );
    if (!discText && metadata.discNumber > 0) {
        discText = [NSString stringWithFormat:@"%ld", (long)metadata.discNumber];
    }
    SetPropertyMapNumberText(properties, "DISCNUMBER", discText);
    SetPropertyMapString(
        properties,
        "DISCTOTAL",
        metadata.totalDiscs > 0 ? [NSString stringWithFormat:@"%ld", (long)metadata.totalDiscs] : nil
    );
    ApplyCustomFieldsToPropertyMap(properties, metadata.customFields);

    return properties;
}

static NSString *InferredArtworkMimeType(NSData * _Nullable data)
{
    if (data.length >= 3) {
        const unsigned char *bytes = static_cast<const unsigned char *>(data.bytes);
        if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return @"image/jpeg";
    }
    if (data.length >= 8) {
        const unsigned char *bytes = static_cast<const unsigned char *>(data.bytes);
        static const unsigned char png[] = { 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A };
        if (memcmp(bytes, png, sizeof(png)) == 0) return @"image/png";
    }
    if (data.length >= 6) {
        const char *bytes = static_cast<const char *>(data.bytes);
        if (memcmp(bytes, "GIF87a", 6) == 0 || memcmp(bytes, "GIF89a", 6) == 0) return @"image/gif";
    }
    if (data.length >= 2) {
        const unsigned char *bytes = static_cast<const unsigned char *>(data.bytes);
        if (bytes[0] == 'B' && bytes[1] == 'M') return @"image/bmp";
    }
    if (data.length >= 4) {
        const unsigned char *bytes = static_cast<const unsigned char *>(data.bytes);
        if ((bytes[0] == 'I' && bytes[1] == 'I' && bytes[2] == 0x2A && bytes[3] == 0x00) ||
            (bytes[0] == 'M' && bytes[1] == 'M' && bytes[2] == 0x00 && bytes[3] == 0x2A)) {
            return @"image/tiff";
        }
    }
    if (data.length >= 12) {
        const char *bytes = static_cast<const char *>(data.bytes);
        if (memcmp(bytes, "RIFF", 4) == 0 && memcmp(bytes + 8, "WEBP", 4) == 0) return @"image/webp";
    }
    return nil;
}

static NSString *NormalizedArtworkMimeType(NSString * _Nullable mimeType,
                                            NSData * _Nullable data)
{
    NSString *trimmed = TrimmedStringOrNil(mimeType);
    if (!trimmed) {
        return InferredArtworkMimeType(data) ?: @"application/octet-stream";
    }

    NSString *lower = trimmed.lowercaseString;
    if ([lower isEqualToString:@"image/jpg"]) {
        return @"image/jpeg";
    }

    return lower;
}

static TagLib::List<TagLib::VariantMap> BuildPictureComplexProperties(TagLibAudioMetadata *metadata)
{
    TagLib::List<TagLib::VariantMap> pictures;
    if (!metadata || metadata.artworkData.length == 0) {
        return pictures;
    }

    TagLib::VariantMap picture;
    picture.insert("data", TagLib::ByteVector((const char *)metadata.artworkData.bytes,
                                               (unsigned int)metadata.artworkData.length));
    picture.insert("mimeType", NSStringToTagString(NormalizedArtworkMimeType(metadata.artworkMimeType,
                                                                              metadata.artworkData)));
    picture.insert("pictureType", NSStringToTagString(@"Front Cover"));
    pictures.append(picture);

    return pictures;
}

template <typename ComplexPropertyTarget>
static bool ApplyPictureComplexProperties(ComplexPropertyTarget *target,
                                          TagLibAudioMetadata *metadata,
                                          NSError **error,
                                          NSInteger clearErrorCode,
                                          NSString *clearErrorMessage,
                                          NSInteger writeErrorCode,
                                          NSString *writeErrorMessage,
                                          NSString *logContext)
{
    if (!target || !metadata) {
        return true;
    }

    if (metadata.removeArtwork) {
        if (!target->setComplexProperties("PICTURE", TagLib::List<TagLib::VariantMap>())) {
            if (error) {
                *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                             code:clearErrorCode
                                         userInfo:@{ NSLocalizedDescriptionKey : clearErrorMessage }];
            }
            TLog(@"Failed to clear artwork for %@ via complex properties", logContext);
            return false;
        }
    } else if (metadata.artworkData.length > 0) {
        if (!target->setComplexProperties("PICTURE", BuildPictureComplexProperties(metadata))) {
            if (error) {
                *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                             code:writeErrorCode
                                         userInfo:@{ NSLocalizedDescriptionKey : writeErrorMessage }];
            }
            TLog(@"Failed to write artwork for %@ via complex properties", logContext);
            return false;
        }
    }

    return true;
}

template <typename ComplexPropertyTarget>
static void ExtractArtworkFromComplexProperties(ComplexPropertyTarget *target,
                                                TagLibAudioMetadata *metadata)
{
    if (!target || !metadata || metadata.artworkData.length > 0) {
        return;
    }

    TagLib::List<TagLib::VariantMap> pictures = target->complexProperties("PICTURE");
    if (pictures.isEmpty()) {
        return;
    }

    TagLib::ByteVector fallbackData;
    NSString *fallbackMimeType = nil;

    for (const auto &picture : pictures) {
        TagLib::ByteVector imageData = picture.value("data").value<TagLib::ByteVector>();
        if (imageData.isEmpty()) {
            continue;
        }

        NSString *mimeType = TagStringToNSString(picture.value("mimeType").value<TagLib::String>());
        TagLib::String pictureType = picture.value("pictureType").value<TagLib::String>();

        if (fallbackData.isEmpty()) {
            fallbackData = imageData;
            fallbackMimeType = mimeType;
        }

        if (pictureType.isEmpty() || pictureType.upper() == "FRONT COVER") {
            metadata.artworkData = [NSData dataWithBytes:imageData.data() length:imageData.size()];
            metadata.artworkMimeType = mimeType;
            return;
        }
    }

    if (!fallbackData.isEmpty()) {
        metadata.artworkData = [NSData dataWithBytes:fallbackData.data() length:fallbackData.size()];
        metadata.artworkMimeType = fallbackMimeType;
    }
}

template <typename FileType>
static void ApplyGenericPropertyMapToFile(FileType &file, TagLibAudioMetadata *metadata)
{
    TagLib::PropertyMap existingProperties = file.properties();
    TagLib::PropertyMap properties = BuildGenericPropertyMap(metadata, &existingProperties);
    file.setProperties(properties);
}

static TagLib::PropertyMap BuildRawPropertyMap(NSDictionary<NSString *, NSString *> *properties)
{
    TagLib::PropertyMap propertyMap;

    if (!properties || properties.count == 0) {
        return propertyMap;
    }

    for (NSString *key in properties) {
        NSString *trimmedKey = TrimmedStringOrNil(key);
        NSString *trimmedValue = TrimmedStringOrNil(properties[key]);
        if (!trimmedKey || !trimmedValue) {
            continue;
        }

        SetPropertyMapDynamicString(propertyMap, trimmedKey, trimmedValue);
    }

    return propertyMap;
}

static TagLib::PropertyMap BuildRawPropertyMapValues(NSDictionary<NSString *, NSArray<NSString *> *> *properties)
{
    TagLib::PropertyMap propertyMap;

    if (!properties || properties.count == 0) {
        return propertyMap;
    }

    for (NSString *key in properties) {
        NSString *trimmedKey = TrimmedStringOrNil(key);
        if (!trimmedKey || IsHiddenInternalMetadataFieldKey(trimmedKey)) {
            continue;
        }

        TagLib::StringList values;
        for (NSString *value in properties[key] ?: @[]) {
            NSString *trimmedValue = TrimmedStringOrNil(value);
            if (trimmedValue) {
                values.append(NSStringToTagString(trimmedValue));
            }
        }

        if (!values.isEmpty()) {
            propertyMap.replace(NSStringToTagString(trimmedKey), values);
        }
    }

    return propertyMap;
}

static void AppendRawPropertyEntries(NSMutableArray<NSDictionary<NSString *, NSObject *> *> *propertiesOut,
                                     const TagLib::PropertyMap &propertyMap)
{
    if (!propertiesOut) {
        return;
    }

    for (auto pit = propertyMap.begin(); pit != propertyMap.end(); ++pit) {
        NSString *nsKey = TagStringToNSString(pit->first) ?: @"";
        if (IsHiddenInternalMetadataFieldKey(nsKey)) {
            continue;
        }

        NSMutableArray<NSString *> *values = [NSMutableArray array];
        for (auto vit = pit->second.begin(); vit != pit->second.end(); ++vit) {
            [values addObject:(TagStringToNSString(*vit) ?: @"")];
        }
        NSString *joined = values.count ? [values componentsJoinedByString:@"; "] : @"";
        [propertiesOut addObject:@{ @"key": nsKey, @"value": joined, @"values": values, @"count": @(values.count) }];
    }
}

static NSString * _Nullable BuildTRCKString(NSInteger trackNumber, NSInteger totalTracks, NSInteger padWidth);
static NSString * _Nullable BuildPropertyMapNumberTextPreservingFormatting(NSString * _Nullable existingText,
                                                                           NSInteger number);

template <typename FileType>
