static void AppendUnifiedRawID3v2Frames(
    TagLib::ID3v2::Tag *tag,
    NSMutableArray<NSDictionary<NSString *, NSObject *> *> *framesOut
)
{
    if (!tag) return;
    TagLib::ID3v2::FrameList frames = tag->frameList();
    for (auto iterator = frames.begin(); iterator != frames.end(); ++iterator) {
        TagLib::ID3v2::Frame *frame = *iterator;
        if (!frame) continue;

        TagLib::ByteVector frameIDBytes = frame->frameID();
        std::string frameIDString(frameIDBytes.data(), frameIDBytes.size());
        NSString *frameID = frameIDString.empty() ? @"" : [NSString stringWithUTF8String:frameIDString.c_str()];
        NSMutableDictionary<NSString *, NSObject *> *entry = [@{
            @"id": frameID ?: @"",
            @"value": TagStringToNSString(frame->toString()) ?: @"",
        } mutableCopy];

        if (auto *userText = dynamic_cast<TagLib::ID3v2::UserTextIdentificationFrame *>(frame)) {
            NSString *description = TagStringToNSString(userText->description()) ?: @"";
            if (description.length > 0) entry[@"description"] = description;
        }
        if (auto *comment = dynamic_cast<TagLib::ID3v2::CommentsFrame *>(frame)) {
            NSString *description = TagStringToNSString(comment->description()) ?: @"";
            NSString *language = TagStringToNSString(comment->language()) ?: @"";
            if (description.length > 0) entry[@"description"] = description;
            if (language.length > 0) entry[@"language"] = language;
        }
        [framesOut addObject:entry];
    }
}

static NSError *UnifiedExtractionError(NSInteger code, NSString *description)
{
    return [NSError errorWithDomain:@"TagLibMetadataExtractor"
                               code:code
                           userInfo:@{ NSLocalizedDescriptionKey : description }];
}

+ (nullable NSDictionary<NSString *, NSObject *> *)metadataProjectionsForURL:(NSURL *)fileURL
                                                                       error:(NSError **)error
{
    return [self metadataProjectionsForURL:fileURL
                                   options:TagLibMetadataExtractionOptionAll
                                     error:error];
}

+ (nullable NSDictionary<NSString *, NSObject *> *)metadataProjectionsForURL:(NSURL *)fileURL
                                                                     options:(TagLibMetadataExtractionOptions)options
                                                                       error:(NSError **)error
{
    try {
    if (!fileURL || !fileURL.isFileURL) {
        if (error) *error = UnifiedExtractionError(9200, @"Metadata extraction requires a file URL");
        return nil;
    }

    NSString *extension = fileURL.pathExtension.lowercaseString;
    AudioMatorTagFileFormat format = DetectTagFileFormat(extension);
    if (format == AudioMatorTagFileFormatUnknown) {
        if (error) *error = UnifiedExtractionError(9201, @"Unsupported audio format");
        return nil;
    }

    const char *filePath = fileURL.path.UTF8String;
    if (!filePath) {
        if (error) *error = UnifiedExtractionError(9202, @"Invalid audio file path");
        return nil;
    }

    TAGLIB_BRIDGE_SERIAL_GUARD();
    TagLib::FileRef fileRef(filePath, true, TagLib::AudioProperties::Accurate);
    TagLib::File *baseFile = fileRef.file();
    if (fileRef.isNull() || !baseFile || !baseFile->isValid()) {
        if (error) *error = UnifiedExtractionError(9203, @"Unable to open audio file with its extension-selected parser");
        return nil;
    }

    TagLibAudioMetadata *basic = [[TagLibAudioMetadata alloc] init];
    NSMutableArray<NSDictionary<NSString *, NSObject *> *> *propertiesOut = [NSMutableArray array];
    NSMutableArray<NSDictionary<NSString *, NSObject *> *> *rawFramesOut = [NSMutableArray array];
    NSMutableArray<NSDictionary<NSString *, NSObject *> *> *structuredFramesOut = [NSMutableArray array];
    NSMutableArray<NSDictionary<NSString *, NSObject *> *> *mp4AtomsOut = [NSMutableArray array];
    NSMutableArray<NSDictionary<NSString *, NSObject *> *> *asfAttributesOut = [NSMutableArray array];
    NSMutableArray<NSDictionary<NSString *, NSObject *> *> *artworkOut = [NSMutableArray array];
    NSMutableArray<NSDictionary<NSString *, NSObject *> *> *lyricsOut = [NSMutableArray array];
    NSMutableArray<NSDictionary<NSString *, NSObject *> *> *commentsOut = [NSMutableArray array];
    NSMutableArray<NSString *> *warningsOut = [NSMutableArray array];
    const bool wantsBasic = (options & TagLibMetadataExtractionOptionBasic) != 0;
    const bool wantsRaw = (options & TagLibMetadataExtractionOptionRaw) != 0;
    const bool wantsStructured = (options & TagLibMetadataExtractionOptionStructured) != 0;
    const bool explicitlyWantsPropertyMap =
        (options & TagLibMetadataExtractionOptionPropertyMap) != 0;
    const bool explicitlyWantsRawFrames =
        (options & TagLibMetadataExtractionOptionRawFrames) != 0;
    const bool wantsPropertyMap = wantsRaw || wantsStructured || explicitlyWantsPropertyMap;
    const bool wantsRawFrames = wantsRaw || explicitlyWantsRawFrames;

    bool openedExpectedType = false;
    auto applyCommon = [&](TagLib::File *file) {
        ApplyBasicTagMetadata(file->tag(), basic);
        ApplyGenericPropertyMapMetadata(file->properties(), basic);
        ApplyAudioPropertiesMetadata(file->audioProperties(), basic);
        if (wantsPropertyMap) AppendRawPropertyEntries(propertiesOut, file->properties());
    };

    if (format == AudioMatorTagFileFormatMPEGID3 || format == AudioMatorTagFileFormatMPEGAAC) {
        if (auto *file = dynamic_cast<TagLib::MPEG::File *>(baseFile)) {
            openedExpectedType = true;
            applyCommon(file);
            basic.codec = format == AudioMatorTagFileFormatMPEGAAC ? @"AAC" : ([extension isEqualToString:@"mp2"] ? @"MP2" : @"MP3");
            if (format == AudioMatorTagFileFormatMPEGID3) {
                if (file->ID3v2Tag()) ExtractID3v2Metadata(file->ID3v2Tag(), basic);
                if (file->APETag()) ExtractAPEMetadata(file->APETag(), basic);
                if (file->ID3v1Tag()) ApplyBasicTagMetadata(file->ID3v1Tag(), basic);
                if (wantsRawFrames) AppendUnifiedRawID3v2Frames(file->ID3v2Tag(), rawFramesOut);
                if (wantsStructured) AppendStructuredID3v2(file->ID3v2Tag(), structuredFramesOut, artworkOut, lyricsOut, commentsOut);
            }
        }
    } else if (format == AudioMatorTagFileFormatMP4) {
        if (auto *file = dynamic_cast<TagLib::MP4::File *>(baseFile)) {
            openedExpectedType = true;
            applyCommon(file);
            basic.codec = [extension isEqualToString:@"mp4"] ? @"MP4" : @"AAC";
            if (file->tag()) {
                ExtractMP4Metadata(file->tag(), basic);
                if (wantsStructured) AppendStructuredMP4(file->tag(), mp4AtomsOut, artworkOut);
            }
        }
    } else if (format == AudioMatorTagFileFormatFLAC) {
        if (auto *file = dynamic_cast<TagLib::FLAC::File *>(baseFile)) {
            openedExpectedType = true;
            applyCommon(file);
            basic.codec = @"FLAC";
            if (file->xiphComment()) ExtractXiphCommentMetadata(file->xiphComment(), basic);
            if (file->audioProperties()) basic.bitDepth = file->audioProperties()->bitsPerSample();
            ExtractFLACPicture(file, basic);
            if (wantsStructured) AppendStructuredComplexPictures(file, @"flac", artworkOut);
        }
    } else if (format == AudioMatorTagFileFormatOggVorbis) {
        if (auto *file = dynamic_cast<TagLib::Ogg::Vorbis::File *>(baseFile)) {
            openedExpectedType = true;
            applyCommon(file);
            basic.codec = @"Vorbis";
            if (file->tag()) {
                ExtractXiphCommentMetadata(file->tag(), basic);
                ExtractArtworkFromComplexProperties(file->tag(), basic);
                if (wantsStructured) AppendStructuredComplexPictures(file->tag(), @"xiph", artworkOut);
            }
        }
    } else if (format == AudioMatorTagFileFormatOggOpus) {
        if (auto *file = dynamic_cast<TagLib::Ogg::Opus::File *>(baseFile)) {
            openedExpectedType = true;
            applyCommon(file);
            basic.codec = @"Opus";
            if (file->tag()) {
                ExtractXiphCommentMetadata(file->tag(), basic);
                ExtractArtworkFromComplexProperties(file->tag(), basic);
                if (wantsStructured) AppendStructuredComplexPictures(file->tag(), @"xiph", artworkOut);
            }
        }
    } else if (format == AudioMatorTagFileFormatOggFlac) {
        if (auto *file = dynamic_cast<TagLib::Ogg::FLAC::File *>(baseFile)) {
            openedExpectedType = true;
            applyCommon(file);
            basic.codec = @"OGG FLAC";
            if (file->tag()) {
                ExtractXiphCommentMetadata(file->tag(), basic);
                ExtractArtworkFromComplexProperties(file->tag(), basic);
                if (wantsStructured) AppendStructuredComplexPictures(file->tag(), @"xiph", artworkOut);
            }
        }
    } else if (format == AudioMatorTagFileFormatOggSpeex) {
        if (auto *file = dynamic_cast<TagLib::Ogg::Speex::File *>(baseFile)) {
            openedExpectedType = true;
            applyCommon(file);
            basic.codec = @"Speex";
            if (file->tag()) {
                ExtractXiphCommentMetadata(file->tag(), basic);
                ExtractArtworkFromComplexProperties(file->tag(), basic);
                if (wantsStructured) AppendStructuredComplexPictures(file->tag(), @"xiph", artworkOut);
            }
        }
    } else if (format == AudioMatorTagFileFormatAPE) {
        if (auto *file = dynamic_cast<TagLib::APE::File *>(baseFile)) {
            openedExpectedType = true;
            applyCommon(file);
            basic.codec = @"APE";
            if (file->APETag()) ExtractAPEMetadata(file->APETag(), basic);
        }
    } else if (format == AudioMatorTagFileFormatWavPack) {
        if (auto *file = dynamic_cast<TagLib::WavPack::File *>(baseFile)) {
            openedExpectedType = true;
            applyCommon(file);
            basic.codec = @"WavPack";
            if (file->APETag()) ExtractAPEMetadata(file->APETag(), basic);
        }
    } else if (format == AudioMatorTagFileFormatMPC) {
        if (auto *file = dynamic_cast<TagLib::MPC::File *>(baseFile)) {
            openedExpectedType = true;
            applyCommon(file);
            basic.codec = @"Musepack";
            if (file->APETag()) ExtractAPEMetadata(file->APETag(), basic);
        }
    } else if (format == AudioMatorTagFileFormatWAV) {
        if (auto *file = dynamic_cast<TagLib::RIFF::WAV::File *>(baseFile)) {
            openedExpectedType = true;
            applyCommon(file);
            basic.codec = @"WAV";
            if (file->ID3v2Tag()) ExtractID3v2Metadata(file->ID3v2Tag(), basic);
            if (file->audioProperties()) basic.bitDepth = file->audioProperties()->bitsPerSample();
            if (wantsRawFrames) AppendUnifiedRawID3v2Frames(file->ID3v2Tag(), rawFramesOut);
            if (wantsStructured) {
                AppendStructuredID3v2(file->ID3v2Tag(), structuredFramesOut, artworkOut, lyricsOut, commentsOut);
                [warningsOut addObject:@"WAV structured writes default to ID3v2 while preserving existing RIFF INFO fields."];
            }
        }
    } else if (format == AudioMatorTagFileFormatAIFF) {
        if (auto *file = dynamic_cast<TagLib::RIFF::AIFF::File *>(baseFile)) {
            openedExpectedType = true;
            applyCommon(file);
            basic.codec = @"AIFF";
            if (file->tag()) ExtractID3v2Metadata(file->tag(), basic);
            if (file->audioProperties()) basic.bitDepth = file->audioProperties()->bitsPerSample();
            if (wantsRawFrames) AppendUnifiedRawID3v2Frames(file->tag(), rawFramesOut);
            if (wantsStructured) {
                AppendStructuredID3v2(file->tag(), structuredFramesOut, artworkOut, lyricsOut, commentsOut);
                [warningsOut addObject:@"AIFF structured writes use ID3v2."];
            }
        }
    } else if (format == AudioMatorTagFileFormatTTA) {
        if (auto *file = dynamic_cast<TagLib::TrueAudio::File *>(baseFile)) {
            openedExpectedType = true;
            applyCommon(file);
            basic.codec = @"TrueAudio";
            if (file->ID3v2Tag()) ExtractID3v2Metadata(file->ID3v2Tag(), basic);
            if (file->ID3v1Tag()) ApplyBasicTagMetadata(file->ID3v1Tag(), basic);
            if (file->audioProperties()) basic.bitDepth = file->audioProperties()->bitsPerSample();
            if (wantsRawFrames) AppendUnifiedRawID3v2Frames(file->ID3v2Tag(), rawFramesOut);
            if (wantsStructured) AppendStructuredID3v2(file->ID3v2Tag(), structuredFramesOut, artworkOut, lyricsOut, commentsOut);
        }
    } else if (format == AudioMatorTagFileFormatASF) {
        if (auto *file = dynamic_cast<TagLib::ASF::File *>(baseFile)) {
            openedExpectedType = true;
            applyCommon(file);
            basic.codec = @"WMA";
            if (file->tag()) {
                ExtractArtworkFromComplexProperties(file->tag(), basic);
                if (wantsStructured) AppendStructuredASF(file->tag(), asfAttributesOut, artworkOut);
            }
        }
    } else if (format == AudioMatorTagFileFormatDSF) {
        if (auto *file = dynamic_cast<TagLib::DSF::File *>(baseFile)) {
            openedExpectedType = true;
            applyCommon(file);
            basic.codec = @"DSF";
            if (auto *tag = dynamic_cast<TagLib::ID3v2::Tag *>(file->tag())) ExtractID3v2Metadata(tag, basic);
        }
    } else if (format == AudioMatorTagFileFormatDSDIFF) {
        if (auto *file = dynamic_cast<TagLib::DSDIFF::File *>(baseFile)) {
            openedExpectedType = true;
            applyCommon(file);
            basic.codec = @"DSDIFF";
            if (file->hasID3v2Tag()) ExtractID3v2Metadata(file->ID3v2Tag(), basic);
        }
    } else if (format == AudioMatorTagFileFormatShorten) {
        if (auto *file = dynamic_cast<TagLib::Shorten::File *>(baseFile)) {
            openedExpectedType = true;
            applyCommon(file);
            basic.codec = @"Shorten";
            if (wantsStructured) [warningsOut addObject:@"Structured container metadata is not available for Shorten; PropertyMap entries are returned when possible."];
        }
    } else if (format == AudioMatorTagFileFormatMOD) {
        if (auto *file = dynamic_cast<TagLib::Mod::File *>(baseFile)) {
            openedExpectedType = true; applyCommon(file); basic.codec = @"MOD";
        }
    } else if (format == AudioMatorTagFileFormatS3M) {
        if (auto *file = dynamic_cast<TagLib::S3M::File *>(baseFile)) {
            openedExpectedType = true; applyCommon(file); basic.codec = @"S3M";
        }
    } else if (format == AudioMatorTagFileFormatIT) {
        if (auto *file = dynamic_cast<TagLib::IT::File *>(baseFile)) {
            openedExpectedType = true; applyCommon(file); basic.codec = @"IT";
        }
    } else if (format == AudioMatorTagFileFormatXM) {
        if (auto *file = dynamic_cast<TagLib::XM::File *>(baseFile)) {
            openedExpectedType = true; applyCommon(file); basic.codec = @"XM";
        }
    }

    const bool isTrackerFormat =
        format == AudioMatorTagFileFormatMOD || format == AudioMatorTagFileFormatS3M ||
        format == AudioMatorTagFileFormatIT || format == AudioMatorTagFileFormatXM;
    const bool hasFormatCredibleProperties = isTrackerFormat
        ? basic.channels > 0
        : HasCredibleAudioProperties(basic);
    if (!openedExpectedType || !hasFormatCredibleProperties) {
        if (error) *error = UnifiedExtractionError(9204, @"The extension-selected parser did not produce credible audio properties");
        return nil;
    }

    if (isTrackerFormat) {
        if (wantsStructured) [warningsOut addObject:@"Tracker fields vary by module format; only PropertyMap entries exposed by TagLib are returned."];
    }

    NSDictionary<NSString *, NSObject *> *raw = @{
        @"properties": propertiesOut,
        @"id3v2Frames": rawFramesOut,
    };
    NSDictionary<NSString *, NSObject *> *structured = @{
        @"properties": propertiesOut,
        @"id3v2Frames": structuredFramesOut,
        @"mp4Atoms": mp4AtomsOut,
        @"asfAttributes": asfAttributesOut,
        @"artwork": artworkOut,
        @"lyrics": lyricsOut,
        @"comments": commentsOut,
        @"warnings": warningsOut,
    };
    NSMutableDictionary<NSString *, NSObject *> *result = [NSMutableDictionary dictionary];
    if (wantsBasic) result[@"basic"] = basic;
    if (wantsRaw || explicitlyWantsPropertyMap || explicitlyWantsRawFrames) result[@"raw"] = raw;
    if (wantsStructured) result[@"structured"] = structured;
    return result;
    TAGLIB_BRIDGE_CATCH_WITH_ERROR(error, @"Unified metadata extraction", nil)
}
