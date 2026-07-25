static BOOL WriteRawPropertyMapToFile(FileType &file,
                                      NSDictionary<NSString *, NSString *> *properties,
                                      NSError **error,
                                      NSInteger openErrorCode,
                                      NSString *openErrorMessage,
                                      NSInteger saveErrorCode,
                                      NSString *saveErrorMessage,
                                      NSString *logContext)
{
    if (!file.isValid()) {
        if (error) {
            *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                         code:openErrorCode
                                     userInfo:@{ NSLocalizedDescriptionKey : openErrorMessage }];
        }
        TLog(@"Failed to open %@ for raw property-map writing", logContext);
        return NO;
    }

    file.setProperties(BuildRawPropertyMap(properties));

    if (!file.save()) {
        if (error) {
            *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                         code:saveErrorCode
                                     userInfo:@{ NSLocalizedDescriptionKey : saveErrorMessage }];
        }
        TLog(@"TagLib save() failed after raw property-map write for %@", logContext);
        return NO;
    }

    return YES;
}

template <typename FileType>
static BOOL WriteRawPropertyMapValuesToFile(FileType &file,
                                            NSDictionary<NSString *, NSArray<NSString *> *> *properties,
                                            NSError **error,
                                            NSInteger openErrorCode,
                                            NSString *openErrorMessage,
                                            NSInteger saveErrorCode,
                                            NSString *saveErrorMessage,
                                            NSString *logContext)
{
    if (!file.isValid()) {
        if (error) {
            *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                         code:openErrorCode
                                     userInfo:@{ NSLocalizedDescriptionKey : openErrorMessage }];
        }
        TLog(@"Failed to open %@ for raw multi-value property-map writing", logContext);
        return NO;
    }

    file.setProperties(BuildRawPropertyMapValues(properties));

    if (!file.save()) {
        if (error) {
            *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                         code:saveErrorCode
                                     userInfo:@{ NSLocalizedDescriptionKey : saveErrorMessage }];
        }
        TLog(@"TagLib save() failed after raw multi-value property-map write for %@", logContext);
        return NO;
    }

    return YES;
}

template <typename FileType>
static bool WritePropertyMapNumberTextToFile(FileType &file,
                                             NSString * _Nullable trackNumberText,
                                             NSString * _Nullable discNumberText,
                                             NSError **error,
                                             NSInteger openErrorCode,
                                             NSString *openErrorMessage,
                                             NSInteger saveErrorCode,
                                             NSString *saveErrorMessage,
                                             NSString *logContext)
{
    if (!file.isValid()) {
        if (error) {
            *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                         code:openErrorCode
                                     userInfo:@{ NSLocalizedDescriptionKey : openErrorMessage }];
        }
        TLog(@"Failed to open %@ for track/disc write", logContext);
        return false;
    }

    TagLib::PropertyMap properties = file.properties();
    NSString *trimmedTrackNumberText = TrimmedStringOrNil(trackNumberText);
    if (trimmedTrackNumberText) {
        NSInteger explicitTrackNumber = 0;
        NSInteger explicitTrackTotal = 0;
        NSInteger padWidth = 0;
        ParseNumberPairFromNSString(trimmedTrackNumberText, explicitTrackNumber, explicitTrackTotal, padWidth);
        (void)padWidth;
        NSInteger effectiveTrackTotal = explicitTrackTotal > 0
            ? explicitTrackTotal
            : PropertyMapNumberTotal(properties, "TRACKNUMBER", "TRACKTOTAL", "TOTALTRACKS");

        SetPropertyMapNumberText(
            properties,
            "TRACKNUMBER",
            BuildPropertyMapNumberTextPreservingFormatting(trimmedTrackNumberText, explicitTrackNumber)
        );
        if (explicitTrackTotal > 0) {
            SetPropertyMapString(
                properties,
                "TRACKTOTAL",
                [NSString stringWithFormat:@"%ld", (long)explicitTrackTotal]
            );
            SetPropertyMapString(
                properties,
                "TOTALTRACKS",
                [NSString stringWithFormat:@"%ld", (long)explicitTrackTotal]
            );
        } else if (effectiveTrackTotal <= 0) {
            SetPropertyMapString(properties, "TRACKTOTAL", nil);
            SetPropertyMapString(properties, "TOTALTRACKS", nil);
        }
    } else {
        SetPropertyMapNumberText(properties, "TRACKNUMBER", nil);
        SetPropertyMapString(properties, "TRACKTOTAL", nil);
        SetPropertyMapString(properties, "TOTALTRACKS", nil);
    }

    if (discNumberText != nil) {
        NSString *trimmedDiscNumberText = TrimmedStringOrNil(discNumberText);
        if (trimmedDiscNumberText) {
            NSInteger explicitDiscNumber = 0;
            NSInteger explicitDiscTotal = 0;
            NSInteger padWidth = 0;
            ParseNumberPairFromNSString(trimmedDiscNumberText, explicitDiscNumber, explicitDiscTotal, padWidth);
            (void)padWidth;
            NSInteger effectiveDiscTotal = explicitDiscTotal > 0
                ? explicitDiscTotal
                : PropertyMapNumberTotal(properties, "DISCNUMBER", "DISCTOTAL", "TOTALDISCS");

            SetPropertyMapNumberText(
                properties,
                "DISCNUMBER",
                BuildPropertyMapNumberTextPreservingFormatting(trimmedDiscNumberText, explicitDiscNumber)
            );
            if (explicitDiscTotal > 0) {
                SetPropertyMapString(
                    properties,
                    "DISCTOTAL",
                    [NSString stringWithFormat:@"%ld", (long)explicitDiscTotal]
                );
                SetPropertyMapString(
                    properties,
                    "TOTALDISCS",
                    [NSString stringWithFormat:@"%ld", (long)explicitDiscTotal]
                );
            } else if (effectiveDiscTotal <= 0) {
                SetPropertyMapString(properties, "DISCTOTAL", nil);
                SetPropertyMapString(properties, "TOTALDISCS", nil);
            }
        } else {
            SetPropertyMapNumberText(properties, "DISCNUMBER", nil);
            SetPropertyMapString(properties, "DISCTOTAL", nil);
            SetPropertyMapString(properties, "TOTALDISCS", nil);
        }
    }
    file.setProperties(properties);

    if (!file.save()) {
        if (error) {
            *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                         code:saveErrorCode
                                     userInfo:@{ NSLocalizedDescriptionKey : saveErrorMessage }];
        }
        TLog(@"TagLib save() failed after track/disc write for %@", logContext);
        return false;
    }

    return true;
}

// Ensure an ID3v2 text frame exists and set its text
static void SetID3v2TextFrame(TagLib::ID3v2::Tag *tag,
                              const char *frameID,
                              NSString * _Nullable value) {
    if (!tag || !frameID || std::strlen(frameID) != 4) {
        return;
    }
    NSString *trimmed = TrimmedStringOrNil(value);
    TagLib::ID3v2::FrameList frames = tag->frameList(frameID);

    if (!trimmed) {
        for (auto it = frames.begin(); it != frames.end(); ++it) {
            tag->removeFrame(*it);
        }
        return;
    }

    TagLib::ID3v2::TextIdentificationFrame *textFrame = nullptr;

    if (!frames.isEmpty()) {
        textFrame = dynamic_cast<TagLib::ID3v2::TextIdentificationFrame *>(frames.front());
    }

    TagLib::String tValue(trimmed.UTF8String, TagLib::String::UTF8);

    if (!textFrame) {
        TagLib::ByteVector id(frameID, 4);
        textFrame = new TagLib::ID3v2::TextIdentificationFrame(id, TagLib::String::UTF8);
        tag->addFrame(textFrame);
    }

    textFrame->setText(tValue);
}

// Ensure an ID3v2 user text frame (TXXX) with given description exists and set its text
static void SetID3v2UserTextFrame(TagLib::ID3v2::Tag *tag,
                                  const char *description,
                                  NSString * _Nullable value)
{
    if (!tag || !description) {
        return;
    }

    TagLib::String descStr(description, TagLib::String::UTF8);

    // Find existing TXXX frame with matching description
    TagLib::ID3v2::FrameList frames = tag->frameList("TXXX");
    TagLib::ID3v2::UserTextIdentificationFrame *userFrame = nullptr;

    for (auto it = frames.begin(); it != frames.end(); ++it) {
        auto *f = dynamic_cast<TagLib::ID3v2::UserTextIdentificationFrame *>(*it);
        if (!f) continue;
        if (f->description().upper() == descStr.upper()) {
            userFrame = f;
            break;
        }
    }

    // If the value is empty or nil, remove the frame (clear the field)
    if (!value || value.length == 0) {
        if (userFrame) {
            tag->removeFrame(userFrame);
        }
        return;
    }

    TagLib::String tValue(value.UTF8String, TagLib::String::UTF8);
    TagLib::StringList textList;
    textList.append(tValue);

    if (!userFrame) {
        // Create a new TXXX frame with the given description
        userFrame = new TagLib::ID3v2::UserTextIdentificationFrame(TagLib::String::UTF8);
        userFrame->setDescription(descStr);
        tag->addFrame(userFrame);
    }

    userFrame->setText(textList);
}

static void SetID3v2LyricsFrame(TagLib::ID3v2::Tag *tag,
                                NSString * _Nullable value)
{
    if (!tag) {
        return;
    }

    NSString *trimmed = TrimmedStringOrNil(value);
    TagLib::ID3v2::FrameList frames = tag->frameList("USLT");
    for (auto it = frames.begin(); it != frames.end(); ++it) {
        tag->removeFrame(*it);
    }

    if (!trimmed) {
        return;
    }

    auto *lyricsFrame = new TagLib::ID3v2::UnsynchronizedLyricsFrame(TagLib::String::UTF8);
    lyricsFrame->setDescription(TagLib::String());
    lyricsFrame->setLanguage(TagLib::ByteVector("eng", 3));
    lyricsFrame->setText(NSStringToTagString(trimmed));
    tag->addFrame(lyricsFrame);
}

typedef NSString * _Nullable (*AudioMatorMetadataStringGetter)(TagLibAudioMetadata *metadata);

static NSString * _Nullable StringFromIntegerField(NSInteger value) {
    return value > 0 ? [NSString stringWithFormat:@"%ld", (long)value] : nil;
}

static NSString * _Nullable GetAlbumArtist(TagLibAudioMetadata *m) { return m.albumArtist; }
static NSString * _Nullable GetComposer(TagLibAudioMetadata *m) { return m.composer; }
static NSString * _Nullable GetCopyright(TagLibAudioMetadata *m) { return m.copyright; }
static NSString * _Nullable GetSortTitle(TagLibAudioMetadata *m) { return m.sortTitle; }
static NSString * _Nullable GetSortArtist(TagLibAudioMetadata *m) { return m.sortArtist; }
static NSString * _Nullable GetSortAlbum(TagLibAudioMetadata *m) { return m.sortAlbum; }
static NSString * _Nullable GetSortAlbumArtist(TagLibAudioMetadata *m) { return m.sortAlbumArtist; }
static NSString * _Nullable GetSortComposer(TagLibAudioMetadata *m) { return m.sortComposer; }
static NSString * _Nullable GetConductor(TagLibAudioMetadata *m) { return m.conductor; }
static NSString * _Nullable GetRemixer(TagLibAudioMetadata *m) { return m.remixer; }
static NSString * _Nullable GetLyricist(TagLibAudioMetadata *m) { return m.lyricist; }
static NSString * _Nullable GetEncodedBy(TagLibAudioMetadata *m) { return m.encodedBy; }
static NSString * _Nullable GetEncoderSettings(TagLibAudioMetadata *m) { return m.encoderSettings; }
static NSString * _Nullable GetISRC(TagLibAudioMetadata *m) { return m.isrc; }
static NSString * _Nullable GetSubtitle(TagLibAudioMetadata *m) { return m.subtitle; }
static NSString * _Nullable GetGrouping(TagLibAudioMetadata *m) { return m.grouping; }
static NSString * _Nullable GetLanguage(TagLibAudioMetadata *m) { return m.language; }
static NSString * _Nullable GetMusicalKey(TagLibAudioMetadata *m) { return m.musicalKey; }
static NSString * _Nullable GetMood(TagLibAudioMetadata *m) { return m.mood; }
static NSString * _Nullable GetMediaType(TagLibAudioMetadata *m) { return m.mediaType; }
static NSString * _Nullable GetMovement(TagLibAudioMetadata *m) { return m.movement; }
static NSString * _Nullable GetCompilation(TagLibAudioMetadata *m) { return m.compilation ? @"1" : nil; }
static NSString * _Nullable GetReleaseDate(TagLibAudioMetadata *m) { return m.releaseDate.length > 0 ? m.releaseDate : m.year; }
static NSString * _Nullable GetOriginalReleaseDate(TagLibAudioMetadata *m) { return m.originalReleaseDate; }
static NSString * _Nullable GetLabel(TagLibAudioMetadata *m) { return m.label; }
static NSString * _Nullable GetReleaseType(TagLibAudioMetadata *m) { return m.releaseType; }
static NSString * _Nullable GetReleaseStatus(TagLibAudioMetadata *m) { return m.releaseStatus; }
static NSString * _Nullable GetBarcode(TagLibAudioMetadata *m) { return m.barcode; }
static NSString * _Nullable GetCatalogNumber(TagLibAudioMetadata *m) { return m.catalogNumber; }
static NSString * _Nullable GetASIN(TagLibAudioMetadata *m) { return m.asin; }
static NSString * _Nullable GetOriginalAlbum(TagLibAudioMetadata *m) { return m.originalAlbum; }
static NSString * _Nullable GetOriginalArtist(TagLibAudioMetadata *m) { return m.originalArtist; }
static NSString * _Nullable GetDiscSubtitle(TagLibAudioMetadata *m) { return m.discSubtitle; }
static NSString * _Nullable GetWork(TagLibAudioMetadata *m) { return m.work; }
static NSString * _Nullable GetItunesAlbumId(TagLibAudioMetadata *m) { return m.itunesAlbumId; }
static NSString * _Nullable GetItunesArtistId(TagLibAudioMetadata *m) { return m.itunesArtistId; }
static NSString * _Nullable GetItunesCatalogId(TagLibAudioMetadata *m) { return m.itunesCatalogId; }
static NSString * _Nullable GetItunesGenreId(TagLibAudioMetadata *m) { return m.itunesGenreId; }
static NSString * _Nullable GetItunesMediaType(TagLibAudioMetadata *m) { return m.itunesMediaType; }
static NSString * _Nullable GetItunesPurchaseDate(TagLibAudioMetadata *m) { return m.itunesPurchaseDate; }
static NSString * _Nullable GetItunesNorm(TagLibAudioMetadata *m) { return m.itunesNorm; }
static NSString * _Nullable GetItunesSmpb(TagLibAudioMetadata *m) { return m.itunesSmpb; }
static NSString * _Nullable GetReleaseCountry(TagLibAudioMetadata *m) { return m.releaseCountry; }
static NSString * _Nullable GetArtistType(TagLibAudioMetadata *m) { return m.artistType; }
static NSString * _Nullable GetMusicBrainzArtistId(TagLibAudioMetadata *m) { return m.musicBrainzArtistId; }
static NSString * _Nullable GetMusicBrainzAlbumId(TagLibAudioMetadata *m) { return m.musicBrainzAlbumId; }
static NSString * _Nullable GetMusicBrainzAlbumArtistId(TagLibAudioMetadata *m) { return m.musicBrainzAlbumArtistId; }
static NSString * _Nullable GetMusicBrainzTrackId(TagLibAudioMetadata *m) { return m.musicBrainzTrackId; }
static NSString * _Nullable GetMusicBrainzReleaseGroupId(TagLibAudioMetadata *m) { return m.musicBrainzReleaseGroupId; }
static NSString * _Nullable GetMusicBrainzReleaseTrackId(TagLibAudioMetadata *m) { return m.musicBrainzReleaseTrackId; }
static NSString * _Nullable GetMusicBrainzWorkId(TagLibAudioMetadata *m) { return m.musicBrainzWorkId; }
static NSString * _Nullable GetAcoustId(TagLibAudioMetadata *m) { return m.acoustId; }
static NSString * _Nullable GetAcoustIdFingerprint(TagLibAudioMetadata *m) { return m.acoustIdFingerprint; }
static NSString * _Nullable GetMusicIpPuid(TagLibAudioMetadata *m) { return m.musicIpPuid; }
static NSString * _Nullable GetReplayGainTrack(TagLibAudioMetadata *m) { return m.replayGainTrack; }
static NSString * _Nullable GetReplayGainAlbum(TagLibAudioMetadata *m) { return m.replayGainAlbum; }
static NSString * _Nullable GetProducer(TagLibAudioMetadata *m) { return m.producer; }
static NSString * _Nullable GetEngineer(TagLibAudioMetadata *m) { return m.engineer; }
static NSString * _Nullable GetBPM(TagLibAudioMetadata *m) { return StringFromIntegerField(m.bpm); }
static NSString * _Nullable GetMovementNumber(TagLibAudioMetadata *m) { return StringFromIntegerField(m.movementNumber); }
static NSString * _Nullable GetMovementCount(TagLibAudioMetadata *m) { return StringFromIntegerField(m.movementCount); }
static NSString * _Nullable GetMovementNumberPair(TagLibAudioMetadata *m) {
    if (m.movementNumber <= 0 && m.movementCount <= 0) return nil;
    if (m.movementCount > 0) {
        return [NSString stringWithFormat:@"%ld/%ld", (long)MAX(0, m.movementNumber), (long)m.movementCount];
    }
    return StringFromIntegerField(m.movementNumber);
}

typedef struct {
    const char *id3v2TextFrame;
    const char *id3v2UserTextDescription;
    const char *mp4Atom;
    const char *mp4FreeformDescription;
    AudioMatorMetadataStringGetter getter;
} AudioMatorWritableTextMapping;

static const AudioMatorWritableTextMapping kAudioMatorWritableTextMappings[] = {
    { "TPE2", nullptr, "aART", nullptr, GetAlbumArtist },
    { "TCOM", nullptr, "\xA9" "wrt", nullptr, GetComposer },
    { "TBPM", nullptr, nullptr, nullptr, GetBPM },
    { "TSOT", nullptr, "sonm", nullptr, GetSortTitle },
    { "TSOP", nullptr, "soar", nullptr, GetSortArtist },
    { "TSOA", nullptr, "soal", nullptr, GetSortAlbum },
    { "TSO2", nullptr, "soaa", nullptr, GetSortAlbumArtist },
    { "TSOC", nullptr, "soco", nullptr, GetSortComposer },
    { "TPE3", nullptr, nullptr, "CONDUCTOR", GetConductor },
    { "TPE4", nullptr, nullptr, "REMIXER", GetRemixer },
    { "TEXT", nullptr, nullptr, "LYRICIST", GetLyricist },
    { "TENC", nullptr, "\xA9" "too", nullptr, GetEncodedBy },
    { "TSSE", nullptr, nullptr, "ENCODERSETTINGS", GetEncoderSettings },
    { "TSRC", nullptr, nullptr, "ISRC", GetISRC },
    { "TCOP", nullptr, "cprt", nullptr, GetCopyright },
    { "TIT3", nullptr, nullptr, "SUBTITLE", GetSubtitle },
    { "TIT1", nullptr, "\xA9" "grp", nullptr, GetGrouping },
    { "TLAN", nullptr, nullptr, "LANGUAGE", GetLanguage },
    { "TKEY", nullptr, nullptr, "INITIALKEY", GetMusicalKey },
    { "TMOO", nullptr, nullptr, "MOOD", GetMood },
    { "TMED", nullptr, nullptr, "MEDIATYPE", GetMediaType },
    { "MVNM", nullptr, nullptr, "MOVEMENT", GetMovement },
    { "MVIN", nullptr, nullptr, nullptr, GetMovementNumberPair },
    { nullptr, nullptr, nullptr, "MOVEMENTNUMBER", GetMovementNumber },
    { nullptr, nullptr, nullptr, "MOVEMENTCOUNT", GetMovementCount },
    { "TCMP", nullptr, nullptr, nullptr, GetCompilation },
    { "TDRL", nullptr, "\xA9" "day", nullptr, GetReleaseDate },
    { "TDRC", nullptr, nullptr, nullptr, GetReleaseDate },
    { "TDOR", nullptr, nullptr, "ORIGINAL YEAR", GetOriginalReleaseDate },
    { "TPUB", nullptr, nullptr, "LABEL", GetLabel },
    { nullptr, "RELEASETYPE", nullptr, "RELEASETYPE", GetReleaseType },
    { nullptr, "RELEASESTATUS", nullptr, "RELEASESTATUS", GetReleaseStatus },
    { nullptr, "BARCODE", nullptr, "BARCODE", GetBarcode },
    { nullptr, "CATALOGNUMBER", nullptr, "CATALOGNUMBER", GetCatalogNumber },
    { nullptr, "ASIN", nullptr, "ASIN", GetASIN },
    { "TOAL", nullptr, nullptr, "ORIGINALALBUM", GetOriginalAlbum },
    { "TOPE", nullptr, nullptr, "ORIGINALARTIST", GetOriginalArtist },
    { "TSST", nullptr, nullptr, "DISCSUBTITLE", GetDiscSubtitle },
    { nullptr, "WORK", nullptr, "WORK", GetWork },
    { nullptr, "ITUNESALBUMID", nullptr, "ITUNESALBUMID", GetItunesAlbumId },
    { nullptr, "ITUNESARTISTID", nullptr, "ITUNESARTISTID", GetItunesArtistId },
    { nullptr, "ITUNESCATALOGID", nullptr, "ITUNESCATALOGID", GetItunesCatalogId },
    { nullptr, "ITUNESGENREID", nullptr, "ITUNESGENREID", GetItunesGenreId },
    { nullptr, "ITUNESMEDIATYPE", nullptr, "ITUNESMEDIATYPE", GetItunesMediaType },
    { nullptr, "ITUNESPURCHASEDATE", nullptr, "ITUNESPURCHASEDATE", GetItunesPurchaseDate },
    { nullptr, "ITUNNORM", nullptr, "ITUNNORM", GetItunesNorm },
    { nullptr, "ITUNSMPB", nullptr, "ITUNSMPB", GetItunesSmpb },
    { nullptr, "RELEASECOUNTRY", nullptr, "MusicBrainz Album Release Country", GetReleaseCountry },
    { nullptr, "ARTISTTYPE", nullptr, "ARTISTTYPE", GetArtistType },
    { nullptr, "MusicBrainz Artist Id", nullptr, "MusicBrainz Artist Id", GetMusicBrainzArtistId },
    { nullptr, "MusicBrainz Album Id", nullptr, "MusicBrainz Album Id", GetMusicBrainzAlbumId },
    { nullptr, "MusicBrainz Album Artist Id", nullptr, "MusicBrainz Album Artist Id", GetMusicBrainzAlbumArtistId },
    { nullptr, "MusicBrainz Track Id", nullptr, "MusicBrainz Track Id", GetMusicBrainzTrackId },
    { nullptr, "MusicBrainz Release Group Id", nullptr, "MusicBrainz Release Group Id", GetMusicBrainzReleaseGroupId },
    { nullptr, "MusicBrainz Release Track Id", nullptr, "MusicBrainz Release Track Id", GetMusicBrainzReleaseTrackId },
    { nullptr, "MusicBrainz Work Id", nullptr, "MusicBrainz Work Id", GetMusicBrainzWorkId },
    { nullptr, "Acoustid Id", nullptr, "Acoustid Id", GetAcoustId },
    { nullptr, "Acoustid Fingerprint", nullptr, "Acoustid Fingerprint", GetAcoustIdFingerprint },
    { nullptr, "MusicIP PUID", nullptr, "MusicIP PUID", GetMusicIpPuid },
    { nullptr, "PRODUCER", nullptr, "PRODUCER", GetProducer },
    { nullptr, "ENGINEER", nullptr, "ENGINEER", GetEngineer },
    { nullptr, "REPLAYGAIN_TRACK_GAIN", nullptr, "REPLAYGAIN_TRACK_GAIN", GetReplayGainTrack },
    { nullptr, "REPLAYGAIN_ALBUM_GAIN", nullptr, "REPLAYGAIN_ALBUM_GAIN", GetReplayGainAlbum },
};

static void ApplyWritableTextMappingsToID3v2Tag(TagLib::ID3v2::Tag *tag,
                                                TagLibAudioMetadata *metadata)
{
    if (!tag || !metadata) {
        return;
    }

    for (const auto &mapping : kAudioMatorWritableTextMappings) {
        NSString *value = mapping.getter ? mapping.getter(metadata) : nil;
        if (mapping.id3v2TextFrame) {
            SetID3v2TextFrame(tag, mapping.id3v2TextFrame, value);
        }
        if (mapping.id3v2UserTextDescription) {
            SetID3v2UserTextFrame(tag, mapping.id3v2UserTextDescription, value);
        }
    }
}

static void ApplyWritableTextMappingsToMP4Tag(TagLib::MP4::Tag *tag,
                                              TagLibAudioMetadata *metadata)
{
    if (!tag || !metadata) {
        return;
    }

    for (const auto &mapping : kAudioMatorWritableTextMappings) {
        NSString *value = mapping.getter ? mapping.getter(metadata) : nil;
        if (mapping.mp4Atom) {
            SetMP4TextItem(tag, mapping.mp4Atom, value);
        }
        if (mapping.mp4FreeformDescription) {
            SetMP4FreeformTextItem(tag, @(mapping.mp4FreeformDescription), value);
        }
    }
}

static void ApplyCustomFieldsToID3v2Tag(TagLib::ID3v2::Tag *tag,
                                        NSDictionary<NSString *, NSString *> * _Nullable customFields)
{
    if (!tag) {
        return;
    }

    if (!customFields || customFields.count == 0) {
        return;
    }

    // Preserve unknown TXXX frames by default; only upsert keys explicitly
    // provided by the current edit payload.
    for (NSString *key in customFields) {
        if (IsKnownMetadataFieldKey(key)) {
            continue;
        }

        SetID3v2UserTextFrame(tag, key.UTF8String, customFields[key]);
    }
}

static void ApplyCustomFieldsToMP4Tag(TagLib::MP4::Tag *tag,
                                      NSDictionary<NSString *, NSString *> * _Nullable customFields)
{
    if (!tag) {
        return;
    }

    if (!customFields || customFields.count == 0) {
        return;
    }

    // Preserve unknown freeform atoms by default; only upsert keys explicitly
    // provided by the current edit payload.
    for (NSString *key in customFields) {
        if (IsKnownMetadataFieldKey(key)) {
            continue;
        }

        SetMP4FreeformTextItem(tag, key, customFields[key]);
    }
}

static NSString * _Nullable FirstStringFromProperty(const TagLib::PropertyMap &properties,
                                                    std::initializer_list<const char *> keys,
                                                    bool joinMultipleValues = false)
{
    for (const char *key : keys) {
        if (!key) continue;
        if (properties.contains(key) && !properties[key].isEmpty()) {
            NSMutableArray<NSString *> *trimmedValues = [NSMutableArray array];
            for (const auto &value : properties[key]) {
                NSString *trimmed = TrimmedStringOrNil(TagStringToNSString(value));
                if (trimmed) {
                    [trimmedValues addObject:trimmed];
                }
            }

            if (trimmedValues.count == 0) {
                continue;
            }

            if (joinMultipleValues && trimmedValues.count > 1) {
                return [trimmedValues componentsJoinedByString:@"; "];
            }

            return trimmedValues.firstObject;
        }
    }
    return nil;
}

static void ApplyGenericPropertyMapMetadata(const TagLib::PropertyMap &properties,
                                            TagLibAudioMetadata *metadata)
{
    if (!metadata || properties.isEmpty()) return;

    metadata.title = FirstStringFromProperty(properties, {"TITLE"}) ?: metadata.title;
    metadata.artist = FirstStringFromProperty(properties, {"ARTIST", "ARTISTS"}, true) ?: metadata.artist;
    metadata.album = FirstStringFromProperty(properties, {"ALBUM"}) ?: metadata.album;
    metadata.comment = FirstStringFromProperty(properties, {"COMMENT"}) ?: metadata.comment;
    metadata.genre = FirstStringFromProperty(properties, {"GENRE"}, true) ?: metadata.genre;
    metadata.composer = FirstStringFromProperty(properties, {"COMPOSER"}, true) ?: metadata.composer;
    metadata.albumArtist = FirstStringFromProperty(properties, {"ALBUMARTIST"}, true) ?: metadata.albumArtist;

    NSString *dateValue = FirstStringFromProperty(properties, {"RELEASEDATE", "DATE", "YEAR"});
    if (dateValue.length > 0) {
        metadata.releaseDate = dateValue;
        if (metadata.year.length == 0 && dateValue.length >= 4) {
            metadata.year = [dateValue substringToIndex:4];
        }
    }

    NSString *originalDate = FirstStringFromProperty(properties, {"ORIGINALDATE"});
    if (originalDate.length > 0) {
        metadata.originalReleaseDate = originalDate;
    }

    const char *trackKey = nullptr;
    if (properties.contains("TRACKNUMBER") && !properties["TRACKNUMBER"].isEmpty()) {
        trackKey = "TRACKNUMBER";
    } else if (properties.contains("TRACK") && !properties["TRACK"].isEmpty()) {
        trackKey = "TRACK";
    }
    if (trackKey) {
        for (const auto &trackValue : properties[trackKey]) {
            NSString *trackText = TrimmedStringOrNil(TagStringToNSString(trackValue));
            NSInteger trackNum = 0, trackTotal = 0;
            ParseNumberPair(trackValue, trackNum, trackTotal);
            metadata.trackNumberText = PreferredNumberText(metadata.trackNumberText, trackText);
            if (trackNum > 0) metadata.trackNumber = trackNum;
            if (trackTotal > 0) metadata.totalTracks = trackTotal;
        }
    }
    NSString *trackTotalValue = FirstStringFromProperty(properties, {"TRACKTOTAL", "TOTALTRACKS"});
    if (trackTotalValue.length > 0) metadata.totalTracks = trackTotalValue.integerValue;

    const char *discKey = nullptr;
    if (properties.contains("DISCNUMBER") && !properties["DISCNUMBER"].isEmpty()) {
        discKey = "DISCNUMBER";
    } else if (properties.contains("DISC") && !properties["DISC"].isEmpty()) {
        discKey = "DISC";
    }
    if (discKey) {
        for (const auto &discValue : properties[discKey]) {
            NSString *discText = TrimmedStringOrNil(TagStringToNSString(discValue));
            NSInteger discNum = 0, discTotal = 0;
            ParseNumberPair(discValue, discNum, discTotal);
            metadata.discNumberText = PreferredNumberText(metadata.discNumberText, discText);
            if (discNum > 0) metadata.discNumber = discNum;
            if (discTotal > 0) metadata.totalDiscs = discTotal;
        }
    }
    NSString *discTotalValue = FirstStringFromProperty(properties, {"DISCTOTAL", "TOTALDISCS"});
    if (discTotalValue.length > 0) metadata.totalDiscs = discTotalValue.integerValue;

    NSString *copyrightValue = FirstStringFromProperty(properties, {"COPYRIGHT"});
    if (copyrightValue.length > 0) metadata.copyright = copyrightValue;

    NSString *lyricsValue = FirstStringFromProperty(properties, {"LYRICS"}, true);
    if (lyricsValue.length > 0) metadata.lyrics = lyricsValue;

    NSString *labelValue = FirstStringFromProperty(properties, {"LABEL"});
    if (labelValue.length > 0) metadata.label = labelValue;

    NSString *isrcValue = FirstStringFromProperty(properties, {"ISRC"});
    if (isrcValue.length > 0) metadata.isrc = isrcValue;

    NSString *encodedByValue = FirstStringFromProperty(properties, {"ENCODEDBY", "ENCODING"});
    if (encodedByValue.length > 0) metadata.encodedBy = encodedByValue;
    NSString *encoderSettingsValue = FirstStringFromProperty(properties, {"ENCODERSETTINGS"});
    if (encoderSettingsValue.length > 0) metadata.encoderSettings = encoderSettingsValue;

    NSString *sortTitle = FirstStringFromProperty(properties, {"TITLESORT"});
    if (sortTitle.length > 0) metadata.sortTitle = sortTitle;
    NSString *sortArtist = FirstStringFromProperty(properties, {"ARTISTSORT"});
    if (sortArtist.length > 0) metadata.sortArtist = sortArtist;
    NSString *sortAlbum = FirstStringFromProperty(properties, {"ALBUMSORT"});
    if (sortAlbum.length > 0) metadata.sortAlbum = sortAlbum;
    NSString *sortAlbumArtist = FirstStringFromProperty(properties, {"ALBUMARTISTSORT"});
    if (sortAlbumArtist.length > 0) metadata.sortAlbumArtist = sortAlbumArtist;
    NSString *sortComposer = FirstStringFromProperty(properties, {"COMPOSERSORT"});
    if (sortComposer.length > 0) metadata.sortComposer = sortComposer;

    NSString *groupingValue = FirstStringFromProperty(properties, {"GROUPING"}, true);
    if (groupingValue.length > 0) metadata.grouping = groupingValue;

    NSString *subtitleValue = FirstStringFromProperty(properties, {"SUBTITLE"});
    if (subtitleValue.length > 0) metadata.subtitle = subtitleValue;
    NSString *discSubtitleValue = FirstStringFromProperty(properties, {"DISCSUBTITLE"});
    if (discSubtitleValue.length > 0) metadata.discSubtitle = discSubtitleValue;

    NSString *lyricistValue = FirstStringFromProperty(properties, {"LYRICIST"}, true);
    if (lyricistValue.length > 0) metadata.lyricist = lyricistValue;

    NSString *conductorValue = FirstStringFromProperty(properties, {"CONDUCTOR"}, true);
    if (conductorValue.length > 0) metadata.conductor = conductorValue;

    NSString *remixerValue = FirstStringFromProperty(properties, {"REMIXER"}, true);
    if (remixerValue.length > 0) metadata.remixer = remixerValue;

    NSString *producerValue = FirstStringFromProperty(properties, {"PRODUCER"}, true);
    if (producerValue.length > 0) metadata.producer = producerValue;

    NSString *engineerValue = FirstStringFromProperty(properties, {"ENGINEER"}, true);
    if (engineerValue.length > 0) metadata.engineer = engineerValue;
    NSString *movementValue = FirstStringFromProperty(properties, {"MOVEMENT", "MOVEMENTNAME"});
    if (movementValue.length > 0) metadata.movement = movementValue;
    NSString *movementNumberValue = FirstStringFromProperty(properties, {"MOVEMENTNUMBER"});
    if (movementNumberValue.length > 0) metadata.movementNumber = movementNumberValue.integerValue;
    NSString *movementCountValue = FirstStringFromProperty(properties, {"MOVEMENTCOUNT"});
    if (movementCountValue.length > 0) metadata.movementCount = movementCountValue.integerValue;
    NSString *workValue = FirstStringFromProperty(properties, {"WORK"});
    if (workValue.length > 0) metadata.work = workValue;

    NSString *moodValue = FirstStringFromProperty(properties, {"MOOD"}, true);
    if (moodValue.length > 0) metadata.mood = moodValue;

    NSString *languageValue = FirstStringFromProperty(properties, {"LANGUAGE"}, true);
    if (languageValue.length > 0) metadata.language = languageValue;
    NSString *musicalKeyValue = FirstStringFromProperty(properties, {"INITIALKEY", "KEY"});
    if (musicalKeyValue.length > 0) metadata.musicalKey = musicalKeyValue;

    NSString *releaseTypeValue = FirstStringFromProperty(properties, {"RELEASETYPE"});
    if (releaseTypeValue.length > 0) metadata.releaseType = releaseTypeValue;
    NSString *releaseStatusValue = FirstStringFromProperty(properties, {"RELEASESTATUS"});
    if (releaseStatusValue.length > 0) metadata.releaseStatus = releaseStatusValue;

    NSString *barcodeValue = FirstStringFromProperty(properties, {"BARCODE", "UPC", "EAN"});
    if (barcodeValue.length > 0) metadata.barcode = barcodeValue;

    NSString *catalogValue = FirstStringFromProperty(properties, {"CATALOGNUMBER"});
    if (catalogValue.length > 0) metadata.catalogNumber = catalogValue;

    NSString *releaseCountryValue = FirstStringFromProperty(properties, {"RELEASECOUNTRY"});
    if (releaseCountryValue.length > 0) metadata.releaseCountry = releaseCountryValue;
    NSString *asinValue = FirstStringFromProperty(properties, {"ASIN"});
    if (asinValue.length > 0) metadata.asin = asinValue;
    NSString *originalAlbumValue = FirstStringFromProperty(properties, {"ORIGINALALBUM"});
    if (originalAlbumValue.length > 0) metadata.originalAlbum = originalAlbumValue;
    NSString *originalArtistValue = FirstStringFromProperty(properties, {"ORIGINALARTIST"});
    if (originalArtistValue.length > 0) metadata.originalArtist = originalArtistValue;
    NSString *artistTypeValue = FirstStringFromProperty(properties, {"MUSICBRAINZ_ARTISTTYPE", "ARTISTTYPE"});
    if (artistTypeValue.length > 0) metadata.artistType = artistTypeValue;

    NSString *mbArtistValue = FirstStringFromProperty(properties, {"MUSICBRAINZ_ARTISTID"});
    if (mbArtistValue.length > 0) metadata.musicBrainzArtistId = mbArtistValue;
    NSString *mbAlbumValue = FirstStringFromProperty(properties, {"MUSICBRAINZ_ALBUMID"});
    if (mbAlbumValue.length > 0) metadata.musicBrainzAlbumId = mbAlbumValue;
    NSString *mbAlbumArtistValue = FirstStringFromProperty(properties, {"MUSICBRAINZ_ALBUMARTISTID"});
    if (mbAlbumArtistValue.length > 0) metadata.musicBrainzAlbumArtistId = mbAlbumArtistValue;
    NSString *mbTrackValue = FirstStringFromProperty(properties, {"MUSICBRAINZ_TRACKID"});
    if (mbTrackValue.length > 0) metadata.musicBrainzTrackId = mbTrackValue;
    NSString *mbReleaseGroupValue = FirstStringFromProperty(properties, {"MUSICBRAINZ_RELEASEGROUPID"});
    if (mbReleaseGroupValue.length > 0) metadata.musicBrainzReleaseGroupId = mbReleaseGroupValue;
    NSString *mbReleaseTrackValue = FirstStringFromProperty(properties, {"MUSICBRAINZ_RELEASETRACKID"});
    if (mbReleaseTrackValue.length > 0) metadata.musicBrainzReleaseTrackId = mbReleaseTrackValue;
    NSString *mbWorkValue = FirstStringFromProperty(properties, {"MUSICBRAINZ_WORKID"});
    if (mbWorkValue.length > 0) metadata.musicBrainzWorkId = mbWorkValue;
    NSString *acoustIdValue = FirstStringFromProperty(properties, {"ACOUSTID_ID"});
    if (acoustIdValue.length > 0) metadata.acoustId = acoustIdValue;
    NSString *acoustFingerprintValue = FirstStringFromProperty(properties, {"ACOUSTID_FINGERPRINT"});
    if (acoustFingerprintValue.length > 0) metadata.acoustIdFingerprint = acoustFingerprintValue;
    NSString *musicIpPuidValue = FirstStringFromProperty(properties, {"MUSICIP_PUID"});
    if (musicIpPuidValue.length > 0) metadata.musicIpPuid = musicIpPuidValue;

    NSString *replayGainTrackValue = FirstStringFromProperty(properties, {"REPLAYGAIN_TRACK_GAIN"});
    if (replayGainTrackValue.length > 0) metadata.replayGainTrack = replayGainTrackValue;
    NSString *replayGainAlbumValue = FirstStringFromProperty(properties, {"REPLAYGAIN_ALBUM_GAIN"});
    if (replayGainAlbumValue.length > 0) metadata.replayGainAlbum = replayGainAlbumValue;

    NSString *mediaTypeValue = FirstStringFromProperty(properties, {"MEDIATYPE", "MEDIA", "MEDIA TYPE"});
    if (mediaTypeValue.length > 0) metadata.mediaType = mediaTypeValue;

    NSString *itunesAlbumIdValue = FirstStringFromProperty(properties, {"ITUNESALBUMID"});
    if (itunesAlbumIdValue.length > 0) metadata.itunesAlbumId = itunesAlbumIdValue;
    NSString *itunesArtistIdValue = FirstStringFromProperty(properties, {"ITUNESARTISTID"});
    if (itunesArtistIdValue.length > 0) metadata.itunesArtistId = itunesArtistIdValue;
    NSString *itunesCatalogIdValue = FirstStringFromProperty(properties, {"ITUNESCATALOGID"});
    if (itunesCatalogIdValue.length > 0) metadata.itunesCatalogId = itunesCatalogIdValue;
    NSString *itunesGenreIdValue = FirstStringFromProperty(properties, {"ITUNESGENREID"});
    if (itunesGenreIdValue.length > 0) metadata.itunesGenreId = itunesGenreIdValue;
    NSString *itunesMediaTypeValue = FirstStringFromProperty(properties, {"ITUNESMEDIATYPE"});
    if (itunesMediaTypeValue.length > 0) metadata.itunesMediaType = itunesMediaTypeValue;
    NSString *itunesPurchaseDateValue = FirstStringFromProperty(properties, {"ITUNESPURCHASEDATE"});
    if (itunesPurchaseDateValue.length > 0) metadata.itunesPurchaseDate = itunesPurchaseDateValue;
    NSString *itunesNormValue = FirstStringFromProperty(properties, {"ITUNNORM"});
    if (itunesNormValue.length > 0) metadata.itunesNorm = itunesNormValue;
    NSString *itunesSmpbValue = FirstStringFromProperty(properties, {"ITUNSMPB"});
    if (itunesSmpbValue.length > 0) metadata.itunesSmpb = itunesSmpbValue;

    if (properties.contains("BPM") && !properties["BPM"].isEmpty()) {
        metadata.bpm = ExtractNumber(properties["BPM"].front());
    }

    if (properties.contains("COMPILATION") && !properties["COMPILATION"].isEmpty()) {
        TagLib::String comp = properties["COMPILATION"].front();
        metadata.compilation = (comp == "1" || comp.upper() == "TRUE");
    }

    ApplyExplicitPropertyKeys(properties, metadata);
    MergeCustomPropertyMapFields(properties, metadata);
}

#pragma mark - Format-Specific Extraction

// Extract ID3v2 metadata (MP3)
