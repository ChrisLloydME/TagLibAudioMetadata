static void ExtractID3v2Metadata(TagLib::ID3v2::Tag* tag, TagLibAudioMetadata* metadata) {
    if (!tag) return;

    // Prefer ID3v2's basic fields over any generic/ID3v1 fallback values that may
    // have been populated earlier through FileRef.tag() or the file property map.
    ApplyPreferredBasicTagMetadata(tag, metadata);
    // DATE in the engine map can be TDRC's YEAR projection. Read each
    // independent native slot, including absence, before exposing the model.
    metadata.year = nil;
    metadata.standaloneDate = nil;
    metadata.releaseDate = nil;
    metadata.originalReleaseDate = nil;

    const TagLib::ID3v2::FrameList& frames = tag->frameList();

    for (auto it = frames.begin(); it != frames.end(); ++it) {
        TagLib::ID3v2::Frame* frame = *it;
        TagLib::ByteVector frameID = frame->frameID();
        std::string frameIDStr(frameID.data(), frameID.size());

        // User-defined text frames (TXXX) - handle these before generic text frames
        // because UserTextIdentificationFrame is also a TextIdentificationFrame.
        if (auto userFrame = dynamic_cast<TagLib::ID3v2::UserTextIdentificationFrame*>(frame)) {
            TagLib::String description = userFrame->description();
            TagLib::StringList userFields = userFrame->fieldList();
            if (userFields.isEmpty()) {
                continue;
            }
            TagLib::String userValue = userFields.back();
            NSString *descriptionString = TagStringToNSString(description);
            NSString *userValueString = TagStringToNSString(userValue);

            if ([descriptionString.uppercaseString isEqualToString:@"DATE"]) {
                metadata.standaloneDate = userValueString;
            } else if (!ApplyKnownCustomMetadataField(descriptionString, userValueString, metadata)) {
                SetCustomMetadataField(metadata, descriptionString, userValueString);
            }
        }
        // Text identification frames
        else if (auto textFrame = dynamic_cast<TagLib::ID3v2::TextIdentificationFrame*>(frame)) {
            TagLib::StringList fieldList = textFrame->fieldList();
            if (fieldList.isEmpty()) continue;

            TagLib::String value = fieldList.toString(", ");

            if (frameIDStr == "TIT2") {
                metadata.title = TagStringToNSString(value);
            }
            else if (frameIDStr == "TPE1") {
                metadata.artist = TagStringToNSString(value);
            }
            else if (frameIDStr == "TALB") {
                metadata.album = TagStringToNSString(value);
            }
            else if (frameIDStr == "TCOM") {
                metadata.composer = TagStringToNSString(value);
            }
            else if (frameIDStr == "TCON") {
                metadata.genre = TagStringToNSString(value);
            }
            // Track number
            else if (frameIDStr == "TRCK") {
                NSInteger trackNum = 0, trackTotal = 0;
                ParseNumberPair(value, trackNum, trackTotal);
                metadata.trackNumberText = PreferredNumberText(
                    metadata.trackNumberText,
                    TagStringToNSString(value)
                );
                metadata.trackNumber = trackNum;
                metadata.totalTracks = trackTotal;
            }
            // Disc number
            else if (frameIDStr == "TPOS") {
                NSInteger discNum = 0, discTotal = 0;
                ParseNumberPair(value, discNum, discTotal);
                metadata.discNumberText = PreferredNumberText(
                    metadata.discNumberText,
                    TagStringToNSString(value)
                );
                metadata.discNumber = discNum;
                metadata.totalDiscs = discTotal;
            }
            // BPM
            else if (frameIDStr == "TBPM") {
                metadata.bpm = value.toInt();
            }
            // Album Artist
            else if (frameIDStr == "TPE2") {
                metadata.albumArtist = TagStringToNSString(value);
            }
            // Sort fields
            else if (frameIDStr == "TSOT") {
                metadata.sortTitle = TagStringToNSString(value);
            }
            else if (frameIDStr == "TSOP") {
                metadata.sortArtist = TagStringToNSString(value);
            }
            else if (frameIDStr == "TSOA") {
                metadata.sortAlbum = TagStringToNSString(value);
            }
            else if (frameIDStr == "TSO2") {
                metadata.sortAlbumArtist = TagStringToNSString(value);
            }
            else if (frameIDStr == "TSOC") {
                metadata.sortComposer = TagStringToNSString(value);
            }
            // Date fields
            else if (frameIDStr == "TDRL") {
                metadata.releaseDate = TagStringToNSString(value);
            }
            else if (frameIDStr == "TDRC") {
                NSString *dateValue = TagStringToNSString(value);
                if (dateValue.length > 0) {
                    // Preserve the complete stored text; Year is not a
                    // four-character projection.
                    metadata.year = dateValue;
                }
            }
            else if (frameIDStr == "TYER") {
                NSString *yearValue = TagStringToNSString(value);
                if (yearValue.length > 0) {
                    metadata.year = yearValue;
                }
            }
            else if (frameIDStr == "TDAT") {
                metadata.standaloneDate = TagStringToNSString(value);
            }
            else if (frameIDStr == "TDOR" || frameIDStr == "TORY") {
                metadata.originalReleaseDate = TagStringToNSString(value);
            }
            // Personnel
            else if (frameIDStr == "TPE3") {
                metadata.conductor = TagStringToNSString(value);
            }
            else if (frameIDStr == "TPE4") {
                metadata.remixer = TagStringToNSString(value);
            }
            else if (frameIDStr == "TEXT") {
                metadata.lyricist = TagStringToNSString(value);
            }
            else if (frameIDStr == "TPUB") {
                metadata.label = TagStringToNSString(value);
            }
            else if (frameIDStr == "TENC") {
                metadata.encodedBy = TagStringToNSString(value);
            }
            else if (frameIDStr == "TSSE") {
                metadata.encoderSettings = TagStringToNSString(value);
            }
            else if (frameIDStr == "TSRC") {
                metadata.isrc = TagStringToNSString(value);
            }
            else if (frameIDStr == "TCOP") {
                metadata.copyright = TagStringToNSString(value);
            }
            else if (frameIDStr == "TIT3") {
                metadata.subtitle = TagStringToNSString(value);
            }
            else if (frameIDStr == "TIT1") {
                metadata.grouping = TagStringToNSString(value);
            }
            else if (frameIDStr == "TLAN") {
                metadata.language = TagStringToNSString(value);
            }
            else if (frameIDStr == "TKEY") {
                metadata.musicalKey = TagStringToNSString(value);
            }
            else if (frameIDStr == "TMOO") {
                metadata.mood = TagStringToNSString(value);
            }
            else if (frameIDStr == "TMED") {
                metadata.mediaType = TagStringToNSString(value);
            }
            else if (frameIDStr == "MVNM") {
                metadata.movement = TagStringToNSString(value);
            }
            else if (frameIDStr == "MVIN") {
                NSInteger movementNumber = 0, movementCount = 0;
                ParseNumberPair(value, movementNumber, movementCount);
                metadata.movementNumber = movementNumber;
                metadata.movementCount = movementCount;
            }
            else if (frameIDStr == "TSST") {
                metadata.discSubtitle = TagStringToNSString(value);
            }
            else if (frameIDStr == "TOAL") {
                metadata.originalAlbum = TagStringToNSString(value);
            }
            else if (frameIDStr == "TOPE") {
                metadata.originalArtist = TagStringToNSString(value);
            }
            // Compilation flag
            else if (frameIDStr == "TCMP") {
                metadata.compilation = (value == "1");
            }
        }
        // Comments
        else if (auto commFrame = dynamic_cast<TagLib::ID3v2::CommentsFrame*>(frame)) {
            if (metadata.comment == nil) {
                metadata.comment = TagStringToNSString(commFrame->text());
            }
        }
        // Lyrics
        else if (auto lyricsFrame = dynamic_cast<TagLib::ID3v2::UnsynchronizedLyricsFrame*>(frame)) {
            if (metadata.lyrics == nil) {
                metadata.lyrics = TagStringToNSString(lyricsFrame->text());
            }
        }
        // Attached picture (album art)
        else if (auto picFrame = dynamic_cast<TagLib::ID3v2::AttachedPictureFrame*>(frame)) {
            if (metadata.artworkData == nil &&
                picFrame->type() == TagLib::ID3v2::AttachedPictureFrame::FrontCover) {
                TagLib::ByteVector picData = picFrame->picture();
                metadata.artworkData = [NSData dataWithBytes:picData.data() length:picData.size()];
                metadata.artworkMimeType = TagStringToNSString(picFrame->mimeType());
            }
        }
    }
}

// Extract MP4 metadata
static void ExtractMP4Metadata(TagLib::MP4::Tag* tag, TagLibAudioMetadata* metadata) {
    if (!tag) return;

    ApplyGenericPropertyMapMetadata(tag->properties(), metadata);

    const TagLib::MP4::ItemMap& items = tag->itemMap();

    // Track number
    if (items.contains("trkn")) {
        TagLib::MP4::Item::IntPair trackPair = MP4UnsignedPair(items["trkn"]);
        metadata.trackNumber = trackPair.first;
        metadata.totalTracks = trackPair.second;
        metadata.trackNumberText = trackPair.second > 0
            ? [NSString stringWithFormat:@"%d/%d", trackPair.first, trackPair.second]
            : (trackPair.first > 0 ? [NSString stringWithFormat:@"%d", trackPair.first] : nil);
    }

    // Disc number
    if (items.contains("disk")) {
        TagLib::MP4::Item::IntPair discPair = MP4UnsignedPair(items["disk"]);
        metadata.discNumber = discPair.first;
        metadata.totalDiscs = discPair.second;
        metadata.discNumberText = discPair.second > 0
            ? [NSString stringWithFormat:@"%d/%d", discPair.first, discPair.second]
            : (discPair.first > 0 ? [NSString stringWithFormat:@"%d", discPair.first] : nil);
    }

    // Legacy private text is a display projection only when it is numerically
    // identical to every native component. It never overrides the native pair
    // and is never renamed or canonicalized during an unrelated save.
    NSString *storedTrackNumberText = MP4TextItemValue(
        items,
        items.contains(kTagLibAudioMetadataMP4TrackNumberTextKey)
            ? kTagLibAudioMetadataMP4TrackNumberTextKey
            : kLegacyAudioMatorMP4TrackNumberTextKey
    );
    NSString *storedDiscNumberText = MP4TextItemValue(
        items,
        items.contains(kTagLibAudioMetadataMP4DiscNumberTextKey)
            ? kTagLibAudioMetadataMP4DiscNumberTextKey
            : kLegacyAudioMatorMP4DiscNumberTextKey
    );
    if (storedTrackNumberText) {
        NSInteger textNumber = 0, textTotal = 0, ignoredPad = 0;
        ParseNumberPairFromNSString(storedTrackNumberText, textNumber, textTotal, ignoredPad);
        if (textTotal == metadata.totalTracks && textNumber == metadata.trackNumber &&
            (textTotal > 0 || textNumber > 0)) {
            metadata.trackNumberText = PreferredNumberText(metadata.trackNumberText, storedTrackNumberText);
        }
    }
    if (storedDiscNumberText) {
        NSInteger textNumber = 0, textTotal = 0, ignoredPad = 0;
        ParseNumberPairFromNSString(storedDiscNumberText, textNumber, textTotal, ignoredPad);
        if (textTotal == metadata.totalDiscs && textNumber == metadata.discNumber &&
            (textTotal > 0 || textNumber > 0)) {
            metadata.discNumberText = PreferredNumberText(metadata.discNumberText, storedDiscNumberText);
        }
    }

    // BPM
    if (items.contains("tmpo")) {
        metadata.bpm = items["tmpo"].toInt();
    }

    // Album Artist
    if (items.contains("aART")) {
        metadata.albumArtist = TagStringToNSString(items["aART"].toStringList().toString(", "));
    }

    // Composer
    if (items.contains("\xA9" "wrt")) {
        metadata.composer = TagStringToNSString(items["\xA9" "wrt"].toStringList().toString(", "));
    }

    // Compilation
    if (items.contains("cpil")) {
        metadata.compilation = items["cpil"].toBool();
    }

    // Apple/iTunes rating: present 0 = not explicit, 1 = explicit, 2 = clean.
    // Unknown historic codes (for example 4) remain raw provenance instead of
    // being silently recoded as explicit or clean.
    if (items.contains("rtng")) {
        const TagLib::MP4::Item &ratingItem = items["rtng"];
        std::string ratingRaw = std::to_string(ratingItem.toInt());
        TagLib::String ratingString(ratingRaw.c_str(), TagLib::String::UTF8);
        SetExplicitAdvisoryFromRawValue(metadata, ratingString);
    } else if (items.contains("----:com.apple.iTunes:ITUNESADVISORY")) {
        SetExplicitAdvisoryFromRawValue(
            metadata,
            items["----:com.apple.iTunes:ITUNESADVISORY"].toStringList().toString()
        );
    }

    // Sort fields
    if (items.contains("sonm")) {
        metadata.sortTitle = TagStringToNSString(items["sonm"].toStringList().toString());
    }
    if (items.contains("soar")) {
        metadata.sortArtist = TagStringToNSString(items["soar"].toStringList().toString());
    }
    if (items.contains("soal")) {
        metadata.sortAlbum = TagStringToNSString(items["soal"].toStringList().toString());
    }
    if (items.contains("soaa")) {
        metadata.sortAlbumArtist = TagStringToNSString(items["soaa"].toStringList().toString());
    }
    if (items.contains("soco")) {
        metadata.sortComposer = TagStringToNSString(items["soco"].toStringList().toString());
    }

    // Grouping
    if (items.contains("©grp")) {
        metadata.grouping = TagStringToNSString(items["©grp"].toStringList().toString());
    }

    // Copyright
    if (items.contains("cprt")) {
        metadata.copyright = TagStringToNSString(items["cprt"].toStringList().toString());
    }

    // Lyrics
    if (items.contains("©lyr")) {
        metadata.lyrics = TagStringToNSString(items["©lyr"].toStringList().toString());
    }

    // Encoded by
    if (items.contains("©too")) {
        metadata.encodedBy = TagStringToNSString(items["©too"].toStringList().toString());
    }

    // Cover art
    if (items.contains("covr")) {
        TagLib::MP4::CoverArtList coverArtList = items["covr"].toCoverArtList();
        if (!coverArtList.isEmpty()) {
            TagLib::MP4::CoverArt coverArt = coverArtList.front();
            TagLib::ByteVector imageData = coverArt.data();
            metadata.artworkData = [NSData dataWithBytes:imageData.data() length:imageData.size()];

            // Determine MIME type
            switch (coverArt.format()) {
                case TagLib::MP4::CoverArt::JPEG:
                    metadata.artworkMimeType = @"image/jpeg";
                    break;
                case TagLib::MP4::CoverArt::PNG:
                    metadata.artworkMimeType = @"image/png";
                    break;
                case TagLib::MP4::CoverArt::BMP:
                    metadata.artworkMimeType = @"image/bmp";
                    break;
                case TagLib::MP4::CoverArt::GIF:
                    metadata.artworkMimeType = @"image/gif";
                    break;
                default:
                    metadata.artworkMimeType = @"image/jpeg";
                    break;
            }
        }
    }

    // Date fields
    // Standard iTunes/MP4 release date atom (©day, e.g. "2024-11-12")
    // NOTE: We split the string literal so that the \xA9 escape stops before 'd',
    //       avoiding an out-of-range hex escape like "\xA9d".
    if (items.contains("\xA9" "day")) {
        metadata.year = TagStringToNSString(items["\xA9" "day"].toStringList().toString());
    } else {
        // The engine DATE projection may come from independent F(DATE).
        metadata.year = nil;
    }
    if (items.contains("----:com.apple.iTunes:RELEASEDATE")) {
        metadata.releaseDate = TagStringToNSString(
            items["----:com.apple.iTunes:RELEASEDATE"].toStringList().toString()
        );
    } else {
        metadata.releaseDate = nil;
    }
    if (items.contains("----:com.apple.iTunes:DATE")) {
        metadata.standaloneDate = TagStringToNSString(
            items["----:com.apple.iTunes:DATE"].toStringList().toString()
        );
    } else {
        metadata.standaloneDate = nil;
    }

    // Target ORIGINALDATE; the older ORIGINAL YEAR freeform remains readable.
    if (items.contains("----:com.apple.iTunes:ORIGINALDATE")) {
        metadata.originalReleaseDate = TagStringToNSString(items["----:com.apple.iTunes:ORIGINALDATE"].toStringList().toString());
    } else if (items.contains("----:com.apple.iTunes:ORIGINAL YEAR")) {
        metadata.originalReleaseDate = TagStringToNSString(items["----:com.apple.iTunes:ORIGINAL YEAR"].toStringList().toString());
    } else {
        metadata.originalReleaseDate = nil;
    }

    // Professional music player fields - freeform atoms
    // MP4 uses freeform identifiers like ----:com.apple.iTunes:FIELDNAME
    if (items.contains("----:com.apple.iTunes:RELEASETYPE")) {
        metadata.releaseType = TagStringToNSString(items["----:com.apple.iTunes:RELEASETYPE"].toStringList().toString());
    } else if (items.contains("----:com.apple.iTunes:MusicBrainz Album Type")) {
        metadata.releaseType = TagStringToNSString(items["----:com.apple.iTunes:MusicBrainz Album Type"].toStringList().toString());
    }

    if (items.contains("----:com.apple.iTunes:BARCODE")) {
        metadata.barcode = TagStringToNSString(items["----:com.apple.iTunes:BARCODE"].toStringList().toString());
    }

    if (items.contains("----:com.apple.iTunes:LABEL")) {
        metadata.label = TagStringToNSString(items["----:com.apple.iTunes:LABEL"].toStringList().toString());
    }

    if (items.contains("----:com.apple.iTunes:CATALOGNUMBER")) {
        metadata.catalogNumber = TagStringToNSString(items["----:com.apple.iTunes:CATALOGNUMBER"].toStringList().toString());
    }

    if (items.contains("----:com.apple.iTunes:MusicBrainz Album Release Country")) {
        metadata.releaseCountry = TagStringToNSString(items["----:com.apple.iTunes:MusicBrainz Album Release Country"].toStringList().toString());
    }

    for (const auto &[itemKey, itemValue] : items) {
        NSString *description = MP4FreeformDescriptionForItemKey(itemKey);
        if (!description) {
            continue;
        }

        if ((items.contains("trkn") && IsMP4TrackNumberPairAlias(description)) ||
            (items.contains("disk") && IsMP4DiscNumberPairAlias(description))) {
            continue;
        }

        NSString *itemValueString = TrimmedStringOrNil(
            TagStringToNSString(itemValue.toStringList().toString(", "))
        );
        if (!itemValueString) {
            continue;
        }

        if (!ApplyKnownCustomMetadataField(description, itemValueString, metadata)) {
            NSMutableDictionary *custom = [metadata.customFields mutableCopy] ?: [NSMutableDictionary dictionary];
            for (NSString *key in [custom allKeys]) {
                if ([key caseInsensitiveCompare:description] == NSOrderedSame) [custom removeObjectForKey:key];
            }
            metadata.customFields = custom;
            SetCustomMetadataField(metadata, description.uppercaseString, itemValueString);
        }
    }
    // Canonical native owners take precedence over old freeform projections.
    if (items.contains("\xA9" "mvn")) metadata.movement = MP4TextItemValue(items, "\xA9" "mvn") ?: @"";
    if (items.contains("\xA9" "mvi")) metadata.movementNumber = items["\xA9" "mvi"].toInt();
    if (items.contains("\xA9" "mvc")) metadata.movementCount = items["\xA9" "mvc"].toInt();
    metadata.encodedBy = MP4TextItemValue(items, "\xA9" "enc") ?: MP4TextItemValue(items, "----:com.apple.iTunes:ENCODEDBY");
    metadata.encoderSettings = MP4TextItemValue(items, "\xA9" "too")
        ?: MP4TextItemValue(items, "----:com.apple.iTunes:ENCODERSETTINGS")
        ?: MP4TextItemValue(items, "----:com.apple.iTunes:ENCODING");

}

// Extract Xiph Comment metadata (FLAC, OGG Vorbis, Opus, etc.)
static void ExtractXiphCommentMetadata(TagLib::Ogg::XiphComment* tag, TagLibAudioMetadata* metadata) {
    if (!tag) return;

    ApplyBasicTagMetadata(tag, metadata);
    ApplyGenericPropertyMapMetadata(tag->properties(), metadata);
}

// Extract FLAC picture
static void ExtractFLACPicture(TagLib::FLAC::File* file, TagLibAudioMetadata* metadata) {
    if (!file) return;

    const TagLib::List<TagLib::FLAC::Picture*>& pictures = file->pictureList();
    for (auto pic : pictures) {
        if (pic->type() == TagLib::FLAC::Picture::FrontCover) {
            TagLib::ByteVector imageData = pic->data();
            metadata.artworkData = [NSData dataWithBytes:imageData.data() length:imageData.size()];
            metadata.artworkMimeType = TagStringToNSString(pic->mimeType());
            break;
        }
    }
}

static bool FirstTextAPEItemValue(const TagLib::APE::ItemListMap& items,
                                  std::initializer_list<const char *> keys,
                                  TagLib::String& value)
{
    for (const char *key : keys) {
        if (!items.contains(key)) {
            continue;
        }

        const TagLib::APE::Item& item = items[key];
        if (item.type() != TagLib::APE::Item::Text) {
            continue;
        }

        const TagLib::StringList values = item.values();
        if (values.isEmpty()) {
            continue;
        }

        value = values.front();
        return true;
    }

    return false;
}

// Extract APE metadata
static void ExtractAPEMetadata(TagLib::APE::Tag* tag, TagLibAudioMetadata* metadata) {
    if (!tag) return;

    ApplyBasicTagMetadata(tag, metadata);

    const TagLib::APE::ItemListMap& items = tag->itemListMap();

    // Track/Disc numbers
    TagLib::String trackStr;
    if (FirstTextAPEItemValue(items, { "TRACK" }, trackStr)) {
        NSInteger trackNum = 0, trackTotal = 0;
        ParseNumberPair(trackStr, trackNum, trackTotal);
        metadata.trackNumberText = PreferredNumberText(
            metadata.trackNumberText,
            TagStringToNSString(trackStr)
        );
        metadata.trackNumber = trackNum;
        if (trackTotal > 0) metadata.totalTracks = trackTotal;
    }
    TagLib::String discStr;
    if (FirstTextAPEItemValue(items, { "DISC" }, discStr)) {
        NSInteger discNum = 0, discTotal = 0;
        ParseNumberPair(discStr, discNum, discTotal);
        metadata.discNumberText = PreferredNumberText(
            metadata.discNumberText,
            TagStringToNSString(discStr)
        );
        metadata.discNumber = discNum;
        if (discTotal > 0) metadata.totalDiscs = discTotal;
    }

    // Album Artist
    TagLib::String textValue;
    if (FirstTextAPEItemValue(items, { "ALBUM ARTIST", "ALBUMARTIST" }, textValue)) {
        metadata.albumArtist = TagStringToNSString(textValue);
    }

    // BPM
    if (FirstTextAPEItemValue(items, { "BPM" }, textValue)) {
        metadata.bpm = textValue.toInt();
    }

    // Other metadata
    if (FirstTextAPEItemValue(items, { "COPYRIGHT" }, textValue)) {
        metadata.copyright = TagStringToNSString(textValue);
    }
    if (FirstTextAPEItemValue(items, { "LYRICS" }, textValue)) {
        metadata.lyrics = TagStringToNSString(textValue);
    }
    if (FirstTextAPEItemValue(items, { "ISRC" }, textValue)) {
        metadata.isrc = TagStringToNSString(textValue);
    }
    if (FirstTextAPEItemValue(items, { "LABEL" }, textValue)) {
        metadata.label = TagStringToNSString(textValue);
    }

    // Professional music player fields
    if (FirstTextAPEItemValue(items, { "RELEASETYPE" }, textValue)) {
        metadata.releaseType = TagStringToNSString(textValue);
    }
    if (FirstTextAPEItemValue(items, { "BARCODE", "UPC" }, textValue)) {
        metadata.barcode = TagStringToNSString(textValue);
    }
    if (FirstTextAPEItemValue(items, { "CATALOGNUMBER" }, textValue)) {
        metadata.catalogNumber = TagStringToNSString(textValue);
    }
    if (FirstTextAPEItemValue(items, { "RELEASECOUNTRY" }, textValue)) {
        metadata.releaseCountry = TagStringToNSString(textValue);
    }

    // Cover art
    if (items.contains("COVER ART (FRONT)")) {
        TagLib::ByteVector coverData = items["COVER ART (FRONT)"].binaryData();
        // APE cover art typically has description followed by null byte, then image data
        if (coverData.size() > 0) {
            // Find first null byte to skip description
            unsigned int startPos = 0;
            for (unsigned int i = 0; i < coverData.size(); ++i) {
                if (coverData[i] == 0) {
                    startPos = i + 1;
                    break;
                }
            }
            if (startPos < coverData.size()) {
                metadata.artworkData = [NSData dataWithBytes:coverData.data() + startPos
                                                      length:coverData.size() - startPos];
            }
        }
    }
}

#pragma mark - Main Extraction Method
