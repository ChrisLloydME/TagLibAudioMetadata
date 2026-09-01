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
        for (const auto &mapping : kAudioMatorMetadataFieldMappings) {
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
static constexpr const char *kAudioMatorMP4TrackNumberTextKey = "----:com.apple.iTunes:AUDIOMATOR_TRACKNUMBER_TEXT";
static constexpr const char *kAudioMatorMP4DiscNumberTextKey = "----:com.apple.iTunes:AUDIOMATOR_DISCNUMBER_TEXT";

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
} AudioMatorMetadataFieldMapping;

static const AudioMatorMetadataFieldMapping kAudioMatorMetadataFieldMappings[] = {
    { "TITLE", { nullptr }, "TIT2", nullptr, "\xA9" "nam", nullptr, false, false, false },
    { "ARTIST", { "ARTISTS", nullptr }, "TPE1", nullptr, "\xA9" "ART", nullptr, true, true, false },
    { "ALBUM", { nullptr }, "TALB", nullptr, "\xA9" "alb", nullptr, false, false, false },
    { "ALBUMARTIST", { "ALBUM ARTIST", nullptr }, "TPE2", nullptr, "aART", nullptr, true, true, false },
    { "DATE", { "YEAR", "RELEASEDATE", nullptr }, "TDRC", nullptr, "\xA9" "day", nullptr, false, false, false },
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

typedef NS_ENUM(NSInteger, AudioMatorTagFileFormat) {
    AudioMatorTagFileFormatUnknown = 0,
    AudioMatorTagFileFormatMPEGID3,
    AudioMatorTagFileFormatMPEGAAC,
    AudioMatorTagFileFormatMP4,
    AudioMatorTagFileFormatFLAC,
    AudioMatorTagFileFormatOggVorbis,
    AudioMatorTagFileFormatOggOpus,
    AudioMatorTagFileFormatOggFlac,
    AudioMatorTagFileFormatOggSpeex,
    AudioMatorTagFileFormatAPE,
    AudioMatorTagFileFormatWavPack,
    AudioMatorTagFileFormatMPC,
    AudioMatorTagFileFormatWAV,
    AudioMatorTagFileFormatAIFF,
    AudioMatorTagFileFormatTTA,
    AudioMatorTagFileFormatASF,
    AudioMatorTagFileFormatDSF,
    AudioMatorTagFileFormatDSDIFF,
    AudioMatorTagFileFormatShorten,
    AudioMatorTagFileFormatMOD,
    AudioMatorTagFileFormatS3M,
    AudioMatorTagFileFormatIT,
    AudioMatorTagFileFormatXM,
};

typedef NS_OPTIONS(NSUInteger, AudioMatorMetadataContainerMask) {
    AudioMatorMetadataContainerNone = 0,
    AudioMatorMetadataContainerTag = 1 << 0,
    AudioMatorMetadataContainerPropertyMap = 1 << 1,
    AudioMatorMetadataContainerID3v1 = 1 << 2,
    AudioMatorMetadataContainerID3v2 = 1 << 3,
    AudioMatorMetadataContainerAPE = 1 << 4,
    AudioMatorMetadataContainerMP4ItemMap = 1 << 5,
    AudioMatorMetadataContainerXiph = 1 << 6,
    AudioMatorMetadataContainerASF = 1 << 7,
    AudioMatorMetadataContainerRIFFInfo = 1 << 8,
};

static const char *kMPEGID3Extensions[] = { "mp3", "mp2", nullptr };
static const char *kMPEGAACExtensions[] = { "aac", nullptr };
static const char *kMP4Extensions[] = { "m4a", "m4r", "m4b", "m4p", "mp4", "m4v", "3g2", nullptr };
static const char *kFLACExtensions[] = { "flac", nullptr };
static const char *kOggVorbisExtensions[] = { "ogg", nullptr };
static const char *kOggOpusExtensions[] = { "opus", nullptr };
static const char *kOggFlacExtensions[] = { "oga", nullptr };
static const char *kOggSpeexExtensions[] = { "spx", nullptr };
static const char *kAPEExtensions[] = { "ape", nullptr };
static const char *kWavPackExtensions[] = { "wv", nullptr };
static const char *kMPCExtensions[] = { "mpc", nullptr };
static const char *kWAVExtensions[] = { "wav", nullptr };
static const char *kAIFFExtensions[] = { "aiff", "aif", "aifc", "afc", nullptr };
static const char *kTTAExtensions[] = { "tta", nullptr };
static const char *kASFExtensions[] = { "wma", "asf", nullptr };
static const char *kDSFExtensions[] = { "dsf", nullptr };
static const char *kDSDIFFExtensions[] = { "dff", "dsdiff", nullptr };
static const char *kShortenExtensions[] = { "shn", nullptr };
static const char *kMODExtensions[] = { "mod", "module", "nst", "wow", nullptr };
static const char *kS3MExtensions[] = { "s3m", nullptr };
static const char *kITExtensions[] = { "it", nullptr };
static const char *kXMExtensions[] = { "xm", nullptr };

struct AudioMatorFormatCapabilityDescriptor {
    AudioMatorTagFileFormat format;
    const char *identifier;
    const char *displayName;
    const char *codecName;
    const char * const *extensions;
    const char *structuredReadSupport;
    const char *structuredWriteSupport;
    bool canReadArtwork;
    bool canWriteArtwork;
    bool preservesMultiValueProperties;
    const char *readOnlyReason;
    const char *notes;
};

static const AudioMatorFormatCapabilityDescriptor kFormatCapabilityDescriptors[] = {
    { AudioMatorTagFileFormatMPEGID3, "mpeg-id3", "MPEG Audio / ID3", "MP3/MP2", kMPEGID3Extensions, "container", "container", true, true, false, nullptr, "ID3v2 is the preferred rich metadata container; ID3v1 is treated as a low-fidelity fallback." },
    { AudioMatorTagFileFormatMPEGAAC, "mpeg-aac", "Raw AAC", "AAC", kMPEGAACExtensions, "propertyMap", "propertyMap", true, true, false, nullptr, "Raw AAC uses the generic TagLib PropertyMap path for textual metadata." },
    { AudioMatorTagFileFormatMP4, "mp4", "MP4 / MPEG-4 Audio", "AAC/MP4", kMP4Extensions, "container", "container", true, true, false, nullptr, "MP4 atoms and iTunes freeform atoms are exposed for structured editing." },
    { AudioMatorTagFileFormatFLAC, "flac", "FLAC", "FLAC", kFLACExtensions, "container", "propertyMap", true, true, true, nullptr, "Structured reads expose FLAC pictures; structured writes fall back to PropertyMap values unless artwork is written through the basic API." },
    { AudioMatorTagFileFormatOggVorbis, "ogg-vorbis", "Ogg Vorbis", "Vorbis", kOggVorbisExtensions, "container", "propertyMap", true, true, true, nullptr, "Xiph comments preserve repeated PropertyMap values." },
    { AudioMatorTagFileFormatOggOpus, "ogg-opus", "Ogg Opus", "Opus", kOggOpusExtensions, "container", "propertyMap", true, true, true, nullptr, "Xiph comments preserve repeated PropertyMap values." },
    { AudioMatorTagFileFormatOggFlac, "ogg-flac", "Ogg FLAC", "Ogg FLAC", kOggFlacExtensions, "container", "propertyMap", true, true, true, nullptr, "Xiph comments preserve repeated PropertyMap values." },
    { AudioMatorTagFileFormatOggSpeex, "ogg-speex", "Ogg Speex", "Speex", kOggSpeexExtensions, "container", "propertyMap", true, true, true, nullptr, "Xiph comments preserve repeated PropertyMap values." },
    { AudioMatorTagFileFormatAPE, "ape", "Monkey's Audio", "APE", kAPEExtensions, "propertyMap", "propertyMap", true, true, true, nullptr, "APE item metadata is currently surfaced through PropertyMap values." },
    { AudioMatorTagFileFormatWavPack, "wavpack", "WavPack", "WavPack", kWavPackExtensions, "propertyMap", "propertyMap", true, true, true, nullptr, "APE item metadata is currently surfaced through PropertyMap values." },
    { AudioMatorTagFileFormatMPC, "musepack", "Musepack", "Musepack", kMPCExtensions, "propertyMap", "propertyMap", true, true, true, nullptr, "APE item metadata is currently surfaced through PropertyMap values." },
    { AudioMatorTagFileFormatWAV, "wav", "WAV / RIFF", "WAV", kWAVExtensions, "container", "container", true, true, false, nullptr, "Structured writes use ID3v2 and preserve existing RIFF INFO fields." },
    { AudioMatorTagFileFormatAIFF, "aiff", "AIFF", "AIFF", kAIFFExtensions, "container", "container", true, true, false, nullptr, "Structured writes use ID3v2." },
    { AudioMatorTagFileFormatTTA, "trueaudio", "TrueAudio", "TrueAudio", kTTAExtensions, "container", "propertyMap", true, true, false, nullptr, "Structured reads expose the ID3v2 tag; structured writes are currently limited to PropertyMap values." },
    { AudioMatorTagFileFormatASF, "asf", "ASF / WMA", "WMA", kASFExtensions, "container", "container", true, true, false, nullptr, "ASF attributes are exposed for structured editing." },
    { AudioMatorTagFileFormatDSF, "dsf", "DSF", "DSF", kDSFExtensions, "propertyMap", "propertyMap", true, true, false, nullptr, "DSF uses ID3v2 tags internally, but structured editing is currently limited to PropertyMap values." },
    { AudioMatorTagFileFormatDSDIFF, "dsdiff", "DSDIFF", "DSDIFF", kDSDIFFExtensions, "propertyMap", "propertyMap", true, true, false, nullptr, "DSDIFF uses ID3v2 tags internally, but structured editing is currently limited to PropertyMap values." },
    { AudioMatorTagFileFormatShorten, "shorten", "Shorten", "Shorten", kShortenExtensions, "propertyMap", "none", false, false, true, "TagLib 2.3.1 exposes Shorten metadata for reading but does not support saving it.", "Read-only format." },
    { AudioMatorTagFileFormatMOD, "mod", "MOD Tracker Module", "MOD", kMODExtensions, "propertyMap", "none", false, false, false, "TagLib exposes MOD metadata for reading but does not support saving it.", "MOD metadata is limited to title, comment, and a format-derived tracker name." },
    { AudioMatorTagFileFormatS3M, "s3m", "Scream Tracker 3 Module", "S3M", kS3MExtensions, "propertyMap", "propertyMap", false, false, false, nullptr, "Writes are limited to title and comment; fixed-width tracker storage may normalize text." },
    { AudioMatorTagFileFormatIT, "it", "Impulse Tracker Module", "IT", kITExtensions, "propertyMap", "propertyMap", false, false, false, nullptr, "Writes are limited to title and comment; fixed-width tracker storage may normalize text." },
    { AudioMatorTagFileFormatXM, "xm", "FastTracker Module", "XM", kXMExtensions, "propertyMap", "propertyMap", false, false, false, nullptr, "Writes are limited to title, comment, and tracker name; fixed-width instrument/sample fields normalize comment text and may pad the tracker name." },
};

static bool DescriptorContainsExtension(const AudioMatorFormatCapabilityDescriptor &descriptor,
                                        NSString *lowerExtension)
{
    for (const char * const *extension = descriptor.extensions; *extension; ++extension) {
        if ([lowerExtension isEqualToString:@(*extension)]) {
            return true;
        }
    }
    return false;
}

static const AudioMatorFormatCapabilityDescriptor *DescriptorForFormat(AudioMatorTagFileFormat format)
{
    for (const auto &descriptor : kFormatCapabilityDescriptors) {
        if (descriptor.format == format) {
            return &descriptor;
        }
    }
    return nullptr;
}

static const AudioMatorFormatCapabilityDescriptor *DescriptorForExtension(NSString * _Nullable ext)
{
    if (!ext) return nullptr;
    NSString *lower = ext.lowercaseString;
    for (const auto &descriptor : kFormatCapabilityDescriptors) {
        if (DescriptorContainsExtension(descriptor, lower)) {
            return &descriptor;
        }
    }
    return nullptr;
}

static AudioMatorTagFileFormat DetectTagFileFormat(NSString * _Nullable ext)
{
    const AudioMatorFormatCapabilityDescriptor *descriptor = DescriptorForExtension(ext);
    return descriptor ? descriptor->format : AudioMatorTagFileFormatUnknown;
}

static AudioMatorMetadataContainerMask ContainerMaskForFormat(AudioMatorTagFileFormat format)
{
    switch (format) {
        case AudioMatorTagFileFormatMPEGID3:
            return AudioMatorMetadataContainerTag
                 | AudioMatorMetadataContainerPropertyMap
                 | AudioMatorMetadataContainerID3v1
                 | AudioMatorMetadataContainerID3v2
                 | AudioMatorMetadataContainerAPE;
        case AudioMatorTagFileFormatMPEGAAC:
            return AudioMatorMetadataContainerTag
                 | AudioMatorMetadataContainerPropertyMap;
        case AudioMatorTagFileFormatMP4:
            return AudioMatorMetadataContainerTag
                 | AudioMatorMetadataContainerPropertyMap
                 | AudioMatorMetadataContainerMP4ItemMap;
        case AudioMatorTagFileFormatFLAC:
            return AudioMatorMetadataContainerTag
                 | AudioMatorMetadataContainerPropertyMap
                 | AudioMatorMetadataContainerXiph
                 | AudioMatorMetadataContainerID3v1
                 | AudioMatorMetadataContainerID3v2;
        case AudioMatorTagFileFormatOggVorbis:
        case AudioMatorTagFileFormatOggOpus:
        case AudioMatorTagFileFormatOggFlac:
        case AudioMatorTagFileFormatOggSpeex:
            return AudioMatorMetadataContainerPropertyMap
                 | AudioMatorMetadataContainerXiph;
        case AudioMatorTagFileFormatAPE:
        case AudioMatorTagFileFormatWavPack:
        case AudioMatorTagFileFormatMPC:
            return AudioMatorMetadataContainerTag
                 | AudioMatorMetadataContainerPropertyMap
                 | AudioMatorMetadataContainerAPE;
        case AudioMatorTagFileFormatWAV:
        case AudioMatorTagFileFormatAIFF:
            return AudioMatorMetadataContainerTag
                 | AudioMatorMetadataContainerPropertyMap
                 | AudioMatorMetadataContainerID3v2
                 | AudioMatorMetadataContainerRIFFInfo;
        case AudioMatorTagFileFormatTTA:
            return AudioMatorMetadataContainerTag
                 | AudioMatorMetadataContainerPropertyMap
                 | AudioMatorMetadataContainerID3v1
                 | AudioMatorMetadataContainerID3v2;
        case AudioMatorTagFileFormatASF:
            return AudioMatorMetadataContainerTag
                 | AudioMatorMetadataContainerPropertyMap
                 | AudioMatorMetadataContainerASF;
        case AudioMatorTagFileFormatDSF:
        case AudioMatorTagFileFormatDSDIFF:
            return AudioMatorMetadataContainerTag
                 | AudioMatorMetadataContainerPropertyMap
                 | AudioMatorMetadataContainerID3v2;
        case AudioMatorTagFileFormatShorten:
            return AudioMatorMetadataContainerTag
                 | AudioMatorMetadataContainerPropertyMap;
        case AudioMatorTagFileFormatMOD:
        case AudioMatorTagFileFormatS3M:
        case AudioMatorTagFileFormatIT:
        case AudioMatorTagFileFormatXM:
            return AudioMatorMetadataContainerTag
                 | AudioMatorMetadataContainerPropertyMap;
        case AudioMatorTagFileFormatUnknown:
            return AudioMatorMetadataContainerNone;
    }
}

static bool IsWritableTagFileFormat(AudioMatorTagFileFormat format)
{
    switch (format) {
        case AudioMatorTagFileFormatUnknown:
        case AudioMatorTagFileFormatShorten:
        case AudioMatorTagFileFormatMOD:
            return false;
        default:
            return true;
    }
}

static NSSet<NSString *> *HiddenInternalMetadataFieldKeys()
{
    static NSSet<NSString *> *keys = [NSSet setWithArray:@[
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
            normalizedProperties[@"AUDIOMATOR_TRACKNUMBER_TEXT"] = trackText;
        }

        if (discText) {
            normalizedProperties[@"AUDIOMATOR_DISCNUMBER_TEXT"] = discText;
        }
    }

    return [normalizedProperties copy];
}
