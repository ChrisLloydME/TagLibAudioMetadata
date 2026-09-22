// WAV has independent RIFF INFO and ID3v2 surfaces. TagLib's File::properties()
// switches wholesale to ID3v2 once a tag exists, hiding unrelated INFO fields.
// Present their union, with explicit ID3v2 values taking precedence per key.
static TagLib::PropertyMap VisibleMetadataProperties(TagLib::File *file)
{
    if (auto *wav = dynamic_cast<TagLib::RIFF::WAV::File *>(file)) {
        TagLib::PropertyMap properties;
        if (wav->hasInfoTag()) properties = wav->InfoTag()->properties();
        if (wav->hasID3v2Tag()) {
            const TagLib::PropertyMap id3 = wav->ID3v2Tag()->properties();
            for (auto iterator = id3.begin(); iterator != id3.end(); ++iterator) {
                properties.replace(iterator->first, iterator->second);
            }
        }
        return properties;
    }
    return file->properties();
}

static bool SaveMetadataPreservingOtherTagSurfaces(TagLib::File *file)
{
    if (auto *wav = dynamic_cast<TagLib::RIFF::WAV::File *>(file)) {
        // WAV's default save may strip INFO while writing ID3v2.
        return wav->save(TagLib::RIFF::WAV::File::ID3v2, TagLib::File::StripNone);
    }
    return file->save();
}

static NSString* _Nullable TagStringToNSString(const TagLib::String& str) {
    if (str.isEmpty()) {
        return nil;
    }
    std::string utf8 = str.to8Bit(true);
    return [NSString stringWithUTF8String:utf8.c_str()];
}

// Extract number from string (e.g., "3/12" -> 3)
static NSInteger ExtractNumber(const TagLib::String& str) {
    if (str.isEmpty()) {
        return 0;
    }
    return str.toInt();
}

// Parse track/disc number string (e.g., "3/12" -> (3, 12))
static void ParseNumberPair(const TagLib::String& str, NSInteger& number, NSInteger& total) {
    if (str.isEmpty()) {
        return;
    }

    std::string s = str.to8Bit(true);
    size_t slashPos = s.find('/');

    if (slashPos != std::string::npos) {
        number = atoi(s.substr(0, slashPos).c_str());
        total = atoi(s.substr(slashPos + 1).c_str());
    } else {
        number = str.toInt();
    }
}

// Convert NSString to TagLib::String (UTF-8)
static TagLib::String NSStringToTagString(NSString * _Nullable string) {
    if (!string || string.length == 0) {
        return TagLib::String();
    }
    return TagLib::String(string.UTF8String, TagLib::String::UTF8);
}

static void ApplyBasicTagMetadata(TagLib::Tag * _Nullable tag,
                                  TagLibAudioMetadata *metadata)
{
    if (!tag || !metadata) {
        return;
    }

    if (!metadata.title) {
        metadata.title = TagStringToNSString(tag->title());
    }
    if (!metadata.artist) {
        metadata.artist = TagStringToNSString(tag->artist());
    }
    if (!metadata.album) {
        metadata.album = TagStringToNSString(tag->album());
    }
    if (!metadata.genre) {
        metadata.genre = TagStringToNSString(tag->genre());
    }
    if (!metadata.comment) {
        metadata.comment = TagStringToNSString(tag->comment());
    }

    if (metadata.year.length == 0 && tag->year() > 0) {
        metadata.year = [NSString stringWithFormat:@"%u", tag->year()];
    }

    if (metadata.trackNumber <= 0 && tag->track() > 0) {
        metadata.trackNumber = tag->track();
    }

    if (metadata.trackNumberText.length == 0 && tag->track() > 0) {
        metadata.trackNumberText = PreferredNumberText(
            metadata.trackNumberText,
            [NSString stringWithFormat:@"%u", tag->track()]
        );
    }
}

static void ApplyPreferredBasicTagMetadata(TagLib::Tag * _Nullable tag,
                                           TagLibAudioMetadata *metadata)
{
    if (!tag || !metadata) {
        return;
    }

    NSString *title = TagStringToNSString(tag->title());
    if (title.length > 0) {
        metadata.title = title;
    }

    NSString *artist = TagStringToNSString(tag->artist());
    if (artist.length > 0) {
        metadata.artist = artist;
    }

    NSString *album = TagStringToNSString(tag->album());
    if (album.length > 0) {
        metadata.album = album;
    }

    NSString *genre = TagStringToNSString(tag->genre());
    if (genre.length > 0) {
        metadata.genre = genre;
    }

    NSString *comment = TagStringToNSString(tag->comment());
    if (comment.length > 0) {
        metadata.comment = comment;
    }

    if (tag->year() > 0) {
        metadata.year = [NSString stringWithFormat:@"%u", tag->year()];
    }

    if (tag->track() > 0) {
        metadata.trackNumber = tag->track();
        metadata.trackNumberText = PreferredNumberText(
            metadata.trackNumberText,
            [NSString stringWithFormat:@"%u", tag->track()]
        );
    }
}

static void ApplyAudioPropertiesMetadata(TagLib::AudioProperties * _Nullable properties,
                                         TagLibAudioMetadata *metadata)
{
    if (!properties || !metadata) {
        return;
    }

    if (metadata.duration <= 0.0) {
        metadata.duration = (NSTimeInterval)properties->lengthInMilliseconds() / 1000.0;
    }
    if (metadata.bitrate <= 0) {
        metadata.bitrate = properties->bitrate();
    }
    if (metadata.sampleRate <= 0) {
        metadata.sampleRate = properties->sampleRate();
    }
    if (metadata.channels <= 0) {
        metadata.channels = properties->channels();
    }
}

static bool HasCredibleAudioProperties(TagLibAudioMetadata *metadata)
{
    return metadata && metadata.duration > 0.0 && metadata.sampleRate > 0 && metadata.channels > 0;
}

static NSString * _Nullable TrimmedStringOrNil(NSString * _Nullable value) {
    if (!value) {
        return nil;
    }
    NSString *trimmed = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return trimmed.length > 0 ? trimmed : nil;
}

static bool ParseUnsignedDecimalString(NSString * _Nullable value,
                                       unsigned long long maximum,
                                       unsigned long long &result)
{
    NSString *trimmed = TrimmedStringOrNil(value);
    if (!trimmed) {
        result = 0;
        return true;
    }

    const char *utf8 = trimmed.UTF8String;
    if (!utf8 || utf8[0] == '-' || utf8[0] == '+') {
        return false;
    }

    errno = 0;
    char *end = nullptr;
    unsigned long long parsed = std::strtoull(utf8, &end, 10);
    if (errno == ERANGE || !end || end == utf8 || *end != '\0' || parsed > maximum) {
        return false;
    }

    result = parsed;
    return true;
}

static BOOL SetNumericValidationError(NSError **error, NSString *description)
{
    if (error) {
        *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                     code:245
                                 userInfo:@{ NSLocalizedDescriptionKey : description }];
    }
    return NO;
}

static BOOL ValidateNonnegativeIntValue(NSInteger value, NSString *name, NSError **error)
{
    if (value < 0 || value > std::numeric_limits<int>::max()) {
        return SetNumericValidationError(
            error,
            [NSString stringWithFormat:@"%@ must be between 0 and %d", name, std::numeric_limits<int>::max()]
        );
    }
    return YES;
}

static BOOL ValidateBasicMetadataNumbers(TagLibAudioMetadata *metadata, NSError **error)
{
    if (!metadata) {
        return SetNumericValidationError(error, @"Metadata is required");
    }

    struct IntegerField {
        NSInteger value;
        __unsafe_unretained NSString *name;
    } fields[] = {
        { metadata.trackNumber, @"track number" },
        { metadata.totalTracks, @"total tracks" },
        { metadata.discNumber, @"disc number" },
        { metadata.totalDiscs, @"total discs" },
        { metadata.movementNumber, @"movement number" },
        { metadata.movementCount, @"movement count" },
        { metadata.bpm, @"BPM" },
    };

    for (const auto &field : fields) {
        if (!ValidateNonnegativeIntValue(field.value, field.name, error)) {
            return NO;
        }
    }

    unsigned long long ignoredYear = 0;
    if (!ParseUnsignedDecimalString(metadata.year,
                                    std::numeric_limits<unsigned int>::max(),
                                    ignoredYear)) {
        return SetNumericValidationError(
            error,
            [NSString stringWithFormat:@"Year must be an unsigned decimal value no greater than %u",
                                       std::numeric_limits<unsigned int>::max()]
        );
    }

    switch (metadata.explicitAdvisory) {
        case TagLibExplicitAdvisoryUnspecified:
        case TagLibExplicitAdvisoryNotExplicit:
        case TagLibExplicitAdvisoryClean:
        case TagLibExplicitAdvisoryExplicit:
            break;
        default:
            return SetNumericValidationError(error, @"Explicit advisory has an unsupported rating value");
    }

    return YES;
}

static unsigned int ValidatedBasicYearValue(NSString * _Nullable year)
{
    unsigned long long parsed = 0;
    bool valid = ParseUnsignedDecimalString(year, std::numeric_limits<unsigned int>::max(), parsed);
    return valid ? static_cast<unsigned int>(parsed) : 0;
}

static NSString * _Nullable UppercaseTrimmedString(NSString * _Nullable value) {
    NSString *trimmed = TrimmedStringOrNil(value);
    return trimmed ? trimmed.uppercaseString : nil;
}

static NSSet<NSString *> *KnownMetadataFieldKeys()
{
    static NSSet<NSString *> *keys = [] {
        NSMutableSet<NSString *> *mappedKeys = [NSMutableSet set];
        for (const auto &mapping : kMetadataFieldMappings) {
            if (mapping.canonicalPropertyKey) {
                [mappedKeys addObject:@(mapping.canonicalPropertyKey)];
            }
            for (const char *alias : mapping.propertyAliases) {
                if (alias) {
                    [mappedKeys addObject:@(alias)];
                }
            }
        }
        [mappedKeys addObjectsFromArray:@[
        @"TITLE", @"ARTIST", @"ARTISTS", @"ALBUM", @"COMMENT", @"GENRE", @"COMPOSER", @"ALBUMARTIST",
        @"DATE", @"YEAR", @"RELEASEDATE", @"ORIGINALDATE", @"ORIGINAL YEAR",
        @"TRACKNUMBER", @"TRACK", @"TRACKTOTAL", @"TOTALTRACKS", @"DISCNUMBER", @"DISC", @"DISCTOTAL", @"TOTALDISCS",
        @"TAGLIBAUDIOMETADATA_TRACKNUMBER_TEXT", @"TAGLIBAUDIOMETADATA_DISCNUMBER_TEXT",
        @"AUDIOMATOR_TRACKNUMBER_TEXT", @"AUDIOMATOR_DISCNUMBER_TEXT",
        @"COPYRIGHT", @"LYRICS", @"LABEL", @"ISRC", @"ENCODEDBY", @"ENCODING", @"ENCODERSETTINGS",
        @"TITLESORT", @"ARTISTSORT", @"ALBUMSORT", @"ALBUMARTISTSORT", @"COMPOSERSORT",
        @"GROUPING", @"SUBTITLE", @"DISCSUBTITLE", @"LYRICIST", @"CONDUCTOR", @"REMIXER", @"PRODUCER", @"ENGINEER",
        @"MOVEMENT", @"MOVEMENTNAME", @"MOVEMENTNUMBER", @"MOVEMENTCOUNT", @"WORK", @"MOOD", @"LANGUAGE", @"INITIALKEY", @"KEY", @"MEDIATYPE", @"MEDIA", @"MEDIA TYPE",
        @"ITUNESALBUMID", @"ITUNESARTISTID", @"ITUNESCATALOGID", @"ITUNESGENREID",
        @"ITUNESMEDIATYPE", @"ITUNESPURCHASEDATE", @"ITUNNORM", @"ITUNSMPB",
        @"RELEASETYPE", @"RELEASESTATUS", @"BARCODE", @"UPC", @"EAN", @"CATALOGNUMBER", @"CATALOG", @"RELEASECOUNTRY",
        @"ASIN", @"ORIGINALALBUM", @"ORIGINALARTIST",
        @"ARTISTTYPE", @"MUSICBRAINZ ARTIST TYPE", @"MUSICBRAINZ_ARTISTTYPE",
        @"BPM", @"COMPILATION", @"ITUNESADVISORY", @"ADVISORY", @"EXPLICITCONTENT", @"EXPLICIT",
        @"MUSICBRAINZ_ARTISTID", @"MUSICBRAINZ ARTISTID", @"MUSICBRAINZ ARTIST ID",
        @"MUSICBRAINZ_ALBUMID", @"MUSICBRAINZ ALBUMID", @"MUSICBRAINZ ALBUM ID",
        @"MUSICBRAINZ_ALBUMARTISTID", @"MUSICBRAINZ ALBUMARTISTID", @"MUSICBRAINZ ALBUM ARTIST ID",
        @"MUSICBRAINZ_TRACKID", @"MUSICBRAINZ TRACKID", @"MUSICBRAINZ TRACK ID",
        @"MUSICBRAINZ_RELEASEGROUPID", @"MUSICBRAINZ RELEASEGROUPID", @"MUSICBRAINZ RELEASE GROUP ID",
        @"MUSICBRAINZ_RELEASETRACKID", @"MUSICBRAINZ RELEASETRACKID", @"MUSICBRAINZ RELEASE TRACK ID",
        @"MUSICBRAINZ_WORKID", @"MUSICBRAINZ WORKID", @"MUSICBRAINZ WORK ID",
        @"MUSICBRAINZ_ALBUMTYPE", @"MUSICBRAINZ ALBUM TYPE",
        @"MUSICBRAINZ_ALBUMSTATUS", @"MUSICBRAINZ ALBUM STATUS",
        @"MUSICBRAINZ_ALBUMRELEASECOUNTRY", @"MUSICBRAINZ ALBUM RELEASE COUNTRY",
        @"ACOUSTID_ID", @"ACOUSTID ID", @"ACOUSTID_FINGERPRINT", @"ACOUSTID FINGERPRINT", @"MUSICIP_PUID",
        @"REPLAYGAIN_TRACK_GAIN", @"REPLAYGAIN_ALBUM_GAIN", @"TRACKERNAME"
        ]];
        return [mappedKeys copy];
    }();
    return keys;
}

static bool IsKnownMetadataFieldKey(NSString * _Nullable key)
{
    NSString *normalizedKey = UppercaseTrimmedString(key);
    return normalizedKey && [KnownMetadataFieldKeys() containsObject:normalizedKey];
}

static NSInteger NumberTextPreferenceScore(NSString * _Nullable value) {
    NSString *trimmed = TrimmedStringOrNil(value);
    if (!trimmed) {
        return NSIntegerMin;
    }

    NSArray<NSString *> *parts = [trimmed componentsSeparatedByString:@"/"];
    NSString *leftPart = parts.count > 0 ? parts[0] : trimmed;
    NSString *leftTrimmed = [leftPart stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    BOOL hasLeadingZeros = leftTrimmed.length > 1 && [leftTrimmed hasPrefix:@"0"];
    BOOL hasExplicitTotal = [trimmed containsString:@"/"];

    return (hasLeadingZeros ? 1000 : 0)
        + (hasExplicitTotal ? 100 : 0)
        + (NSInteger)trimmed.length;
}

static NSString * _Nullable PreferredNumberText(NSString * _Nullable currentValue,
                                                NSString * _Nullable candidateValue) {
    NSString *trimmedCurrent = TrimmedStringOrNil(currentValue);
    NSString *trimmedCandidate = TrimmedStringOrNil(candidateValue);

    if (!trimmedCandidate) {
        return trimmedCurrent;
    }

    if (!trimmedCurrent) {
        return trimmedCandidate;
    }

    return NumberTextPreferenceScore(trimmedCandidate) > NumberTextPreferenceScore(trimmedCurrent)
        ? trimmedCandidate
        : trimmedCurrent;
}

// Internal-only MP4 freeform atoms used to preserve the user's exact track/disc text
// (for example "01/10") across formats that otherwise normalize numeric pairs.
// Legacy AudioMator keys remain readable and are migrated only when the relevant
// number pair is modified.
static constexpr const char *kTagLibAudioMetadataMP4TrackNumberTextKey = "----:com.apple.iTunes:TAGLIBAUDIOMETADATA_TRACKNUMBER_TEXT";
static constexpr const char *kTagLibAudioMetadataMP4DiscNumberTextKey = "----:com.apple.iTunes:TAGLIBAUDIOMETADATA_DISCNUMBER_TEXT";
static constexpr const char *kLegacyAudioMatorMP4TrackNumberTextKey = "----:com.apple.iTunes:AUDIOMATOR_TRACKNUMBER_TEXT";
static constexpr const char *kLegacyAudioMatorMP4DiscNumberTextKey = "----:com.apple.iTunes:AUDIOMATOR_DISCNUMBER_TEXT";

static bool IsMP4LikeExtension(NSString * _Nullable ext);

typedef struct {
    const char *canonicalPropertyKey;
    const char *propertyAliases[6];
    const char *id3v2TextFrame;
    const char *id3v2UserTextDescription;
    const char *mp4Atom;
    const char *mp4FreeformDescription;
    bool multiValue;
    bool peopleField;
    bool roleQualified;
} TLMetadataFieldMapping;

static const TLMetadataFieldMapping kMetadataFieldMappings[] = {
    { "TITLE", { nullptr }, "TIT2", nullptr, "\xA9" "nam", nullptr, false, false, false },
    { "ARTIST", { "ARTISTS", nullptr }, "TPE1", nullptr, "\xA9" "ART", nullptr, true, true, false },
    { "ALBUM", { nullptr }, "TALB", nullptr, "\xA9" "alb", nullptr, false, false, false },
    { "ALBUMARTIST", { "ALBUM ARTIST", nullptr }, "TPE2", nullptr, "aART", nullptr, true, true, false },
    { "DATE", { "YEAR", nullptr }, "TDRC", nullptr, nullptr, nullptr, false, false, false },
    { "RELEASEDATE", { nullptr }, "TDRL", nullptr, "\xA9" "day", nullptr, false, false, false },
    { "ORIGINALDATE", { "ORIGINAL YEAR", nullptr }, "TDOR", nullptr, nullptr, "ORIGINAL YEAR", false, false, false },
    { "TRACKNUMBER", { "TRACK", nullptr }, "TRCK", nullptr, "trkn", nullptr, false, false, false },
    { "TRACKTOTAL", { "TOTALTRACKS", nullptr }, "TRCK", nullptr, "trkn", nullptr, false, false, false },
    { "DISCNUMBER", { "DISC", nullptr }, "TPOS", nullptr, "disk", nullptr, false, false, false },
    { "DISCTOTAL", { "TOTALDISCS", nullptr }, "TPOS", nullptr, "disk", nullptr, false, false, false },
    { "PICTURE", { nullptr }, "APIC", nullptr, "covr", nullptr, false, false, false },
    { "LYRICS", { nullptr }, "USLT", nullptr, "\xA9" "lyr", nullptr, false, false, false },
    { "COMMENT", { nullptr }, "COMM", nullptr, "\xA9" "cmt", nullptr, false, false, false },
    { "GENRE", { nullptr }, "TCON", nullptr, "\xA9" "gen", nullptr, true, false, false },
    { "COMPOSER", { nullptr }, "TCOM", nullptr, "\xA9" "wrt", nullptr, true, true, false },
    { "TITLESORT", { nullptr }, "TSOT", nullptr, "sonm", nullptr, false, false, false },
    { "ARTISTSORT", { nullptr }, "TSOP", nullptr, "soar", nullptr, false, false, false },
    { "ALBUMSORT", { nullptr }, "TSOA", nullptr, "soal", nullptr, false, false, false },
    { "ALBUMARTISTSORT", { nullptr }, "TSO2", nullptr, "soaa", nullptr, false, false, false },
    { "COMPOSERSORT", { nullptr }, "TSOC", nullptr, "soco", nullptr, false, false, false },
    { "CONDUCTOR", { nullptr }, "TPE3", nullptr, nullptr, "CONDUCTOR", true, true, false },
    { "REMIXER", { nullptr }, "TPE4", nullptr, nullptr, "REMIXER", true, true, false },
    { "PRODUCER", { nullptr }, nullptr, "PRODUCER", nullptr, "PRODUCER", true, true, false },
    { "ENGINEER", { nullptr }, nullptr, "ENGINEER", nullptr, "ENGINEER", true, true, false },
    { "LYRICIST", { nullptr }, "TEXT", nullptr, nullptr, "LYRICIST", true, true, false },
    { "PERFORMER", { nullptr }, "TMCL", nullptr, nullptr, "PERFORMER", true, true, true },
    { "INVOLVEDPEOPLE", { nullptr }, "TIPL", nullptr, nullptr, "INVOLVEDPEOPLE", true, true, true },
    { "MUSICIANCREDITS", { nullptr }, "TMCL", nullptr, nullptr, "MUSICIANCREDITS", true, true, true },
    { "COPYRIGHT", { nullptr }, "TCOP", nullptr, "cprt", nullptr, false, false, false },
    { "LABEL", { "PUBLISHER", nullptr }, "TPUB", nullptr, nullptr, "LABEL", false, false, false },
    { "ENCODEDBY", { "ENCODING", nullptr }, "TENC", nullptr, "\xA9" "too", nullptr, false, false, false },
    { "ENCODERSETTINGS", { nullptr }, "TSSE", nullptr, nullptr, "ENCODERSETTINGS", false, false, false },
    { "ISRC", { nullptr }, "TSRC", nullptr, nullptr, "ISRC", false, false, false },
    { "BARCODE", { "UPC", "EAN", nullptr }, nullptr, "BARCODE", nullptr, "BARCODE", false, false, false },
    { "CATALOGNUMBER", { "CATALOG NUMBER", "CATALOG", nullptr }, nullptr, "CATALOGNUMBER", nullptr, "CATALOGNUMBER", false, false, false },
    { "RELEASETYPE", { "MUSICBRAINZ_ALBUMTYPE", "MUSICBRAINZ ALBUM TYPE", nullptr }, nullptr, "RELEASETYPE", nullptr, "RELEASETYPE", false, false, false },
    { "RELEASESTATUS", { "MUSICBRAINZ_ALBUMSTATUS", "MUSICBRAINZ ALBUM STATUS", nullptr }, nullptr, "RELEASESTATUS", nullptr, "RELEASESTATUS", false, false, false },
    { "RELEASECOUNTRY", { "MUSICBRAINZ_ALBUMRELEASECOUNTRY", "MUSICBRAINZ ALBUM RELEASE COUNTRY", nullptr }, nullptr, "RELEASECOUNTRY", nullptr, "MusicBrainz Album Release Country", false, false, false },
    { "ASIN", { nullptr }, nullptr, "ASIN", nullptr, "ASIN", false, false, false },
    { "MEDIATYPE", { "MEDIA", "MEDIA TYPE", nullptr }, "TMED", nullptr, nullptr, "MEDIATYPE", false, false, false },
    { "SUBTITLE", { nullptr }, "TIT3", nullptr, nullptr, "SUBTITLE", false, false, false },
    { "GROUPING", { nullptr }, "TIT1", nullptr, "\xA9" "grp", nullptr, true, false, false },
    { "DISCSUBTITLE", { nullptr }, "TSST", nullptr, nullptr, "DISCSUBTITLE", false, false, false },
    { "MOVEMENT", { "MOVEMENTNAME", nullptr }, "MVNM", nullptr, nullptr, "MOVEMENT", false, false, false },
    { "MOVEMENTNUMBER", { nullptr }, "MVIN", nullptr, nullptr, "MOVEMENTNUMBER", false, false, false },
    { "MOVEMENTCOUNT", { nullptr }, "MVIN", nullptr, nullptr, "MOVEMENTCOUNT", false, false, false },
    { "WORK", { nullptr }, nullptr, "WORK", nullptr, "WORK", false, false, false },
    { "MOOD", { nullptr }, "TMOO", nullptr, nullptr, "MOOD", true, false, false },
    { "LANGUAGE", { nullptr }, "TLAN", nullptr, nullptr, "LANGUAGE", true, false, false },
    { "INITIALKEY", { "KEY", nullptr }, "TKEY", nullptr, nullptr, "INITIALKEY", false, false, false },
    { "MUSICBRAINZ_ARTISTID", { "MUSICBRAINZ ARTISTID", "MUSICBRAINZ ARTIST ID", nullptr }, nullptr, "MusicBrainz Artist Id", nullptr, "MusicBrainz Artist Id", false, false, false },
    { "MUSICBRAINZ_ALBUMID", { "MUSICBRAINZ ALBUMID", "MUSICBRAINZ ALBUM ID", nullptr }, nullptr, "MusicBrainz Album Id", nullptr, "MusicBrainz Album Id", false, false, false },
    { "MUSICBRAINZ_ALBUMARTISTID", { "MUSICBRAINZ ALBUMARTISTID", "MUSICBRAINZ ALBUM ARTIST ID", nullptr }, nullptr, "MusicBrainz Album Artist Id", nullptr, "MusicBrainz Album Artist Id", false, false, false },
    { "MUSICBRAINZ_TRACKID", { "MUSICBRAINZ TRACKID", "MUSICBRAINZ TRACK ID", nullptr }, nullptr, "MusicBrainz Track Id", nullptr, "MusicBrainz Track Id", false, false, false },
    { "MUSICBRAINZ_RELEASEGROUPID", { "MUSICBRAINZ RELEASEGROUPID", "MUSICBRAINZ RELEASE GROUP ID", nullptr }, nullptr, "MusicBrainz Release Group Id", nullptr, "MusicBrainz Release Group Id", false, false, false },
    { "MUSICBRAINZ_RELEASETRACKID", { "MUSICBRAINZ RELEASETRACKID", "MUSICBRAINZ RELEASE TRACK ID", nullptr }, nullptr, "MusicBrainz Release Track Id", nullptr, "MusicBrainz Release Track Id", false, false, false },
    { "MUSICBRAINZ_WORKID", { "MUSICBRAINZ WORKID", "MUSICBRAINZ WORK ID", nullptr }, nullptr, "MusicBrainz Work Id", nullptr, "MusicBrainz Work Id", false, false, false },
    { "MUSICBRAINZ_ARTISTTYPE", { "ARTISTTYPE", "MUSICBRAINZ ARTIST TYPE", nullptr }, nullptr, "ARTISTTYPE", nullptr, "ARTISTTYPE", false, false, false },
    { "ACOUSTID_ID", { "ACOUSTID ID", nullptr }, nullptr, "Acoustid Id", nullptr, "Acoustid Id", false, false, false },
    { "ACOUSTID_FINGERPRINT", { "ACOUSTID FINGERPRINT", nullptr }, nullptr, "Acoustid Fingerprint", nullptr, "Acoustid Fingerprint", false, false, false },
    { "MUSICIP_PUID", { nullptr }, nullptr, "MusicIP PUID", nullptr, "MusicIP PUID", false, false, false },
    { "REPLAYGAIN_TRACK_GAIN", { nullptr }, nullptr, "REPLAYGAIN_TRACK_GAIN", nullptr, "REPLAYGAIN_TRACK_GAIN", false, false, false },
    { "REPLAYGAIN_ALBUM_GAIN", { nullptr }, nullptr, "REPLAYGAIN_ALBUM_GAIN", nullptr, "REPLAYGAIN_ALBUM_GAIN", false, false, false },
    { "ITUNESALBUMID", { nullptr }, nullptr, "ITUNESALBUMID", nullptr, "ITUNESALBUMID", false, false, false },
    { "ITUNESARTISTID", { nullptr }, nullptr, "ITUNESARTISTID", nullptr, "ITUNESARTISTID", false, false, false },
    { "ITUNESCATALOGID", { nullptr }, nullptr, "ITUNESCATALOGID", nullptr, "ITUNESCATALOGID", false, false, false },
    { "ITUNESGENREID", { nullptr }, nullptr, "ITUNESGENREID", nullptr, "ITUNESGENREID", false, false, false },
    { "ITUNESMEDIATYPE", { nullptr }, nullptr, "ITUNESMEDIATYPE", nullptr, "ITUNESMEDIATYPE", false, false, false },
    { "ITUNESPURCHASEDATE", { nullptr }, nullptr, "ITUNESPURCHASEDATE", nullptr, "ITUNESPURCHASEDATE", false, false, false },
    { "ITUNNORM", { nullptr }, nullptr, "ITUNNORM", nullptr, "ITUNNORM", false, false, false },
    { "ITUNSMPB", { nullptr }, nullptr, "ITUNSMPB", nullptr, "ITUNSMPB", false, false, false },
    { "ITUNESADVISORY", { "ADVISORY", "EXPLICITCONTENT", "EXPLICIT", nullptr }, nullptr, "ITUNESADVISORY", "rtng", "ITUNESADVISORY", false, false, false },
    { "BPM", { nullptr }, "TBPM", nullptr, "tmpo", nullptr, false, false, false },
    { "COMPILATION", { nullptr }, "TCMP", nullptr, "cpil", nullptr, false, false, false },
    { "ORIGINALALBUM", { nullptr }, "TOAL", nullptr, nullptr, "ORIGINALALBUM", false, false, false },
    { "ORIGINALARTIST", { nullptr }, "TOPE", nullptr, nullptr, "ORIGINALARTIST", true, true, false },
};

static TLTagFileFormat DetectTagFileFormat(NSString * _Nullable ext)
{
    const TLFormatCapabilityDescriptor *descriptor = DescriptorForExtension(ext);
    return descriptor ? descriptor->format : TLTagFileFormatUnknown;
}

static bool OggPacketStartsWith(const unsigned char *packet,
                                size_t packetLength,
                                const unsigned char *signature,
                                size_t signatureLength)
{
    return packetLength >= signatureLength &&
        std::memcmp(packet, signature, signatureLength) == 0;
}

static TLTagFileFormat DetectOggCodecAtURL(NSURL * _Nullable fileURL, bool &isOgg)
{
    isOgg = false;
    if (!fileURL || !fileURL.isFileURL) {
        return TLTagFileFormatUnknown;
    }

    int descriptor = open(fileURL.path.fileSystemRepresentation, O_RDONLY);
    if (descriptor < 0) {
        return TLTagFileFormatUnknown;
    }

    // The page header and lacing table occupy at most 282 bytes. Codec
    // signatures fit in the next eight; do not read 64 KiB for every parser.
    unsigned char bytes[290] = {};
    ssize_t byteCount;
    do {
        byteCount = read(descriptor, bytes, sizeof(bytes));
    } while (byteCount < 0 && errno == EINTR);
    close(descriptor);
    if (byteCount < 4 || std::memcmp(bytes, "OggS", 4) != 0) {
        return TLTagFileFormatUnknown;
    }
    isOgg = true;
    // Accept only a version-zero beginning-of-stream identification page,
    // not a continued data packet that happens to contain a codec signature.
    if (byteCount < 27 || bytes[4] != 0 || (bytes[5] & 0x03) != 0x02) {
        return TLTagFileFormatUnknown;
    }

    size_t segmentCount = bytes[26];
    size_t packetOffset = 27 + segmentCount;
    if (packetOffset > static_cast<size_t>(byteCount)) {
        return TLTagFileFormatUnknown;
    }

    size_t packetLength = 0;
    bool packetComplete = false;
    for (size_t index = 0; index < segmentCount; ++index) {
        unsigned char lace = bytes[27 + index];
        packetLength += lace;
        if (lace < 255) {
            packetComplete = true;
            break;
        }
    }
    if (!packetComplete || packetLength == 0 || packetOffset >= static_cast<size_t>(byteCount)) {
        return TLTagFileFormatUnknown;
    }
    packetLength = std::min(packetLength, static_cast<size_t>(byteCount) - packetOffset);

    const unsigned char *packet = bytes + packetOffset;
    static const unsigned char vorbisSignature[] = { 0x01, 'v', 'o', 'r', 'b', 'i', 's' };
    static const unsigned char opusSignature[] = { 'O', 'p', 'u', 's', 'H', 'e', 'a', 'd' };
    static const unsigned char speexSignature[] = { 'S', 'p', 'e', 'e', 'x', ' ', ' ', ' ' };
    static const unsigned char oggFlacSignature[] = { 0x7f, 'F', 'L', 'A', 'C' };
    static const unsigned char nativeFlacSignature[] = { 'f', 'L', 'a', 'C' };

    if (OggPacketStartsWith(packet, packetLength, vorbisSignature, sizeof(vorbisSignature))) {
        return TLTagFileFormatOggVorbis;
    }
    if (OggPacketStartsWith(packet, packetLength, opusSignature, sizeof(opusSignature))) {
        return TLTagFileFormatOggOpus;
    }
    if (OggPacketStartsWith(packet, packetLength, speexSignature, sizeof(speexSignature))) {
        return TLTagFileFormatOggSpeex;
    }
    if (OggPacketStartsWith(packet, packetLength, oggFlacSignature, sizeof(oggFlacSignature)) ||
        OggPacketStartsWith(packet, packetLength, nativeFlacSignature, sizeof(nativeFlacSignature))) {
        return TLTagFileFormatOggFlac;
    }
    return TLTagFileFormatUnknown;
}

static TLTagFileFormat DetectTagFileFormat(NSURL * _Nullable fileURL)
{
    bool isOgg = false;
    TLTagFileFormat oggFormat = DetectOggCodecAtURL(fileURL, isOgg);
    if (isOgg) {
        return oggFormat;
    }
    return DetectTagFileFormat(fileURL.pathExtension.lowercaseString);
}

static TLMetadataContainerMask ContainerMaskForFormat(TLTagFileFormat format)
{
    switch (format) {
        case TLTagFileFormatMPEGID3:
            return TLMetadataContainerTag
                 | TLMetadataContainerPropertyMap
                 | TLMetadataContainerID3v1
                 | TLMetadataContainerID3v2
                 | TLMetadataContainerAPE;
        case TLTagFileFormatMPEGAAC:
            return TLMetadataContainerTag
                 | TLMetadataContainerPropertyMap;
        case TLTagFileFormatMP4:
            return TLMetadataContainerTag
                 | TLMetadataContainerPropertyMap
                 | TLMetadataContainerMP4ItemMap;
        case TLTagFileFormatFLAC:
            return TLMetadataContainerTag
                 | TLMetadataContainerPropertyMap
                 | TLMetadataContainerXiph
                 | TLMetadataContainerID3v1
                 | TLMetadataContainerID3v2;
        case TLTagFileFormatOggVorbis:
        case TLTagFileFormatOggOpus:
        case TLTagFileFormatOggFlac:
        case TLTagFileFormatOggSpeex:
            return TLMetadataContainerPropertyMap
                 | TLMetadataContainerXiph;
        case TLTagFileFormatAPE:
        case TLTagFileFormatWavPack:
        case TLTagFileFormatMPC:
            return TLMetadataContainerTag
                 | TLMetadataContainerPropertyMap
                 | TLMetadataContainerAPE;
        case TLTagFileFormatWAV:
        case TLTagFileFormatAIFF:
            return TLMetadataContainerTag
                 | TLMetadataContainerPropertyMap
                 | TLMetadataContainerID3v2
                 | TLMetadataContainerRIFFInfo;
        case TLTagFileFormatTTA:
            return TLMetadataContainerTag
                 | TLMetadataContainerPropertyMap
                 | TLMetadataContainerID3v1
                 | TLMetadataContainerID3v2;
        case TLTagFileFormatASF:
            return TLMetadataContainerTag
                 | TLMetadataContainerPropertyMap
                 | TLMetadataContainerASF;
        case TLTagFileFormatDSF:
        case TLTagFileFormatDSDIFF:
            return TLMetadataContainerTag
                 | TLMetadataContainerPropertyMap
                 | TLMetadataContainerID3v2;
        case TLTagFileFormatShorten:
            return TLMetadataContainerTag
                 | TLMetadataContainerPropertyMap;
        case TLTagFileFormatMOD:
        case TLTagFileFormatS3M:
        case TLTagFileFormatIT:
        case TLTagFileFormatXM:
            return TLMetadataContainerTag
                 | TLMetadataContainerPropertyMap;
        case TLTagFileFormatUnknown:
            return TLMetadataContainerNone;
    }
}

static bool IsWritableTagFileFormat(TLTagFileFormat format)
{
    switch (format) {
        case TLTagFileFormatUnknown:
        case TLTagFileFormatShorten:
        case TLTagFileFormatMOD:
            return false;
        default:
            return true;
    }
}

static NSSet<NSString *> *HiddenInternalMetadataFieldKeys()
{
    static NSSet<NSString *> *keys = [NSSet setWithArray:@[
        @"TAGLIBAUDIOMETADATA_TRACKNUMBER_TEXT",
        @"TAGLIBAUDIOMETADATA_DISCNUMBER_TEXT",
        @"----:COM.APPLE.ITUNES:TAGLIBAUDIOMETADATA_TRACKNUMBER_TEXT",
        @"----:COM.APPLE.ITUNES:TAGLIBAUDIOMETADATA_DISCNUMBER_TEXT",
        @"AUDIOMATOR_TRACKNUMBER_TEXT",
        @"AUDIOMATOR_DISCNUMBER_TEXT",
        @"----:COM.APPLE.ITUNES:AUDIOMATOR_TRACKNUMBER_TEXT",
        @"----:COM.APPLE.ITUNES:AUDIOMATOR_DISCNUMBER_TEXT",
    ]];
    return keys;
}

static bool IsHiddenInternalMetadataFieldKey(NSString * _Nullable key)
{
    NSString *normalizedKey = UppercaseTrimmedString(key);
    return normalizedKey && [HiddenInternalMetadataFieldKeys() containsObject:normalizedKey];
}

static NSString * _Nullable RawPropertyValueForCandidateKeys(NSDictionary<NSString *, NSString *> *properties,
                                                             NSArray<NSString *> *candidateKeys)
{
    if (!properties || properties.count == 0 || candidateKeys.count == 0) {
        return nil;
    }

    NSSet<NSString *> *normalizedCandidates = [NSSet setWithArray:candidateKeys];
    for (NSString *rawKey in properties) {
        NSString *normalizedKey = UppercaseTrimmedString(rawKey);
        if (!normalizedKey || ![normalizedCandidates containsObject:normalizedKey]) {
            continue;
        }

        NSString *value = TrimmedStringOrNil(properties[rawKey]);
        if (value) {
            return value;
        }
    }

    return nil;
}

static NSDictionary<NSString *, NSString *> *NormalizedRawPropertiesForWrite(NSDictionary<NSString *, NSString *> *properties,
                                                                             NSString *ext)
{
    NSMutableDictionary<NSString *, NSString *> *normalizedProperties = [NSMutableDictionary dictionary];

    for (NSString *rawKey in properties ?: @{}) {
        NSString *trimmedKey = TrimmedStringOrNil(rawKey);
        NSString *trimmedValue = TrimmedStringOrNil(properties[rawKey]);
        if (!trimmedKey || !trimmedValue) {
            continue;
        }

        if (IsHiddenInternalMetadataFieldKey(trimmedKey)) {
            continue;
        }

        normalizedProperties[trimmedKey] = trimmedValue;
    }

    if (IsMP4LikeExtension(ext)) {
        NSString *trackText = RawPropertyValueForCandidateKeys(normalizedProperties, @[ @"TRACKNUMBER", @"TRACK" ]);
        NSString *discText = RawPropertyValueForCandidateKeys(normalizedProperties, @[ @"DISCNUMBER", @"DISC" ]);

        if (trackText) {
            normalizedProperties[@"TAGLIBAUDIOMETADATA_TRACKNUMBER_TEXT"] = trackText;
        }

        if (discText) {
            normalizedProperties[@"TAGLIBAUDIOMETADATA_DISCNUMBER_TEXT"] = discText;
        }
    }

    return [normalizedProperties copy];
}
