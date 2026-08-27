+ (BOOL)writeRawPropertyMap:(NSDictionary<NSString *, NSString *> *)properties
                     toURL:(NSURL *)fileURL
                     error:(NSError **)error
{
    try {
    TAGLIB_BRIDGE_SERIAL_GUARD();
    if (TagLibAtomicMutationDepth == 0) {
        return PerformAtomicTagLibMutation(fileURL, error, @"Raw property-map write", ^BOOL(NSURL *temporaryURL, NSError **mutationError) {
            return [self writeRawPropertyMap:properties toURL:temporaryURL error:mutationError];
        });
    }
    if (!fileURL || !fileURL.isFileURL) {
        if (error) {
            *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                         code:100
                                     userInfo:@{ NSLocalizedDescriptionKey : @"Invalid file URL" }];
        }
        return NO;
    }

    NSString *ext = fileURL.pathExtension.lowercaseString;
    AudioMatorTagFileFormat format = DetectTagFileFormat(ext);
    if (!IsWritableTagFileFormat(format)) {
        if (error) {
            *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                         code:101
                                     userInfo:@{ NSLocalizedDescriptionKey : @"Unsupported audio format" }];
        }
        return NO;
    }

    const char *filePath = fileURL.path.UTF8String;
    if (!filePath) {
        if (error) {
            *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                         code:102
                                     userInfo:@{ NSLocalizedDescriptionKey : @"Invalid file path" }];
        }
        return NO;
    }

    NSDictionary<NSString *, NSString *> *normalizedProperties = NormalizedRawPropertiesForWrite(properties ?: @{}, ext);

    if (format == AudioMatorTagFileFormatMPEGID3 || format == AudioMatorTagFileFormatMPEGAAC) {
        TagLib::MPEG::File file(filePath);
        return WriteRawPropertyMapToFile(file,
                                         normalizedProperties,
                                         error,
                                         166,
                                         @"Unable to open MPEG audio file for metadata editing",
                                         167,
                                         @"TagLib failed to save MPEG metadata property changes",
                                         [NSString stringWithFormat:@"MPEG '%@'", fileURL.lastPathComponent]);
    }

    if (format == AudioMatorTagFileFormatMP4) {
        TagLib::MP4::File file(filePath);
        return WriteRawPropertyMapToFile(file,
                                         normalizedProperties,
                                         error,
                                         168,
                                         @"Unable to open MP4/M4A file for metadata editing",
                                         169,
                                         @"TagLib failed to save MP4/M4A metadata property changes",
                                         [NSString stringWithFormat:@"MP4 '%@'", fileURL.lastPathComponent]);
    }

    if (format == AudioMatorTagFileFormatFLAC) {
        TagLib::FLAC::File file(filePath);
        return WriteRawPropertyMapToFile(file,
                                         normalizedProperties,
                                         error,
                                         170,
                                         @"Unable to open FLAC file for metadata editing",
                                         171,
                                         @"TagLib failed to save FLAC metadata property changes",
                                         [NSString stringWithFormat:@"FLAC '%@'", fileURL.lastPathComponent]);
    }

    if (format == AudioMatorTagFileFormatOggVorbis) {
        TagLib::Ogg::Vorbis::File file(filePath);
        return WriteRawPropertyMapToFile(file,
                                         normalizedProperties,
                                         error,
                                         172,
                                         @"Unable to open Ogg Vorbis file for metadata editing",
                                         173,
                                         @"TagLib failed to save Ogg Vorbis metadata property changes",
                                         [NSString stringWithFormat:@"Ogg Vorbis '%@'", fileURL.lastPathComponent]);
    }

    if (format == AudioMatorTagFileFormatOggOpus) {
        TagLib::Ogg::Opus::File file(filePath);
        return WriteRawPropertyMapToFile(file,
                                         normalizedProperties,
                                         error,
                                         174,
                                         @"Unable to open Opus file for metadata editing",
                                         175,
                                         @"TagLib failed to save Opus metadata property changes",
                                         [NSString stringWithFormat:@"Opus '%@'", fileURL.lastPathComponent]);
    }

    if (format == AudioMatorTagFileFormatOggFlac) {
        TagLib::Ogg::FLAC::File file(filePath);
        return WriteRawPropertyMapToFile(file,
                                         normalizedProperties,
                                         error,
                                         176,
                                         @"Unable to open Ogg FLAC file for metadata editing",
                                         177,
                                         @"TagLib failed to save Ogg FLAC metadata property changes",
                                         [NSString stringWithFormat:@"Ogg FLAC '%@'", fileURL.lastPathComponent]);
    }

    if (format == AudioMatorTagFileFormatOggSpeex) {
        TagLib::Ogg::Speex::File file(filePath);
        return WriteRawPropertyMapToFile(file,
                                         normalizedProperties,
                                         error,
                                         178,
                                         @"Unable to open Speex file for metadata editing",
                                         179,
                                         @"TagLib failed to save Speex metadata property changes",
                                         [NSString stringWithFormat:@"Speex '%@'", fileURL.lastPathComponent]);
    }

    if (format == AudioMatorTagFileFormatAPE) {
        TagLib::APE::File file(filePath);
        return WriteRawPropertyMapToFile(file,
                                         normalizedProperties,
                                         error,
                                         180,
                                         @"Unable to open APE file for metadata editing",
                                         181,
                                         @"TagLib failed to save APE metadata property changes",
                                         [NSString stringWithFormat:@"APE '%@'", fileURL.lastPathComponent]);
    }

    if (format == AudioMatorTagFileFormatWavPack) {
        TagLib::WavPack::File file(filePath);
        return WriteRawPropertyMapToFile(file,
                                         normalizedProperties,
                                         error,
                                         182,
                                         @"Unable to open WavPack file for metadata editing",
                                         183,
                                         @"TagLib failed to save WavPack metadata property changes",
                                         [NSString stringWithFormat:@"WavPack '%@'", fileURL.lastPathComponent]);
    }

    if (format == AudioMatorTagFileFormatMPC) {
        TagLib::MPC::File file(filePath);
        return WriteRawPropertyMapToFile(file,
                                         normalizedProperties,
                                         error,
                                         184,
                                         @"Unable to open Musepack file for metadata editing",
                                         185,
                                         @"TagLib failed to save Musepack metadata property changes",
                                         [NSString stringWithFormat:@"Musepack '%@'", fileURL.lastPathComponent]);
    }

    if (format == AudioMatorTagFileFormatWAV) {
        TagLib::RIFF::WAV::File file(filePath);
        return WriteRawPropertyMapToFile(file,
                                         normalizedProperties,
                                         error,
                                         186,
                                         @"Unable to open WAV file for metadata editing",
                                         187,
                                         @"TagLib failed to save WAV metadata property changes",
                                         [NSString stringWithFormat:@"WAV '%@'", fileURL.lastPathComponent]);
    }

    if (format == AudioMatorTagFileFormatAIFF) {
        TagLib::RIFF::AIFF::File file(filePath);
        return WriteRawPropertyMapToFile(file,
                                         normalizedProperties,
                                         error,
                                         188,
                                         @"Unable to open AIFF file for metadata editing",
                                         189,
                                         @"TagLib failed to save AIFF metadata property changes",
                                         [NSString stringWithFormat:@"AIFF '%@'", fileURL.lastPathComponent]);
    }

    if (format == AudioMatorTagFileFormatTTA) {
        TagLib::TrueAudio::File file(filePath);
        return WriteRawPropertyMapToFile(file,
                                         normalizedProperties,
                                         error,
                                         190,
                                         @"Unable to open TrueAudio file for metadata editing",
                                         191,
                                         @"TagLib failed to save TrueAudio metadata property changes",
                                         [NSString stringWithFormat:@"TrueAudio '%@'", fileURL.lastPathComponent]);
    }

    if (format == AudioMatorTagFileFormatASF) {
        TagLib::ASF::File file(filePath);
        return WriteRawPropertyMapToFile(file,
                                         normalizedProperties,
                                         error,
                                         192,
                                         @"Unable to open ASF/WMA file for metadata editing",
                                         193,
                                         @"TagLib failed to save ASF/WMA metadata property changes",
                                         [NSString stringWithFormat:@"ASF/WMA '%@'", fileURL.lastPathComponent]);
    }

    if (format == AudioMatorTagFileFormatDSF) {
        TagLib::DSF::File file(filePath);
        return WriteRawPropertyMapToFile(file,
                                         normalizedProperties,
                                         error,
                                         194,
                                         @"Unable to open DSF file for metadata editing",
                                         195,
                                         @"TagLib failed to save DSF metadata property changes",
                                         [NSString stringWithFormat:@"DSF '%@'", fileURL.lastPathComponent]);
    }

    if (format == AudioMatorTagFileFormatDSDIFF) {
        TagLib::DSDIFF::File file(filePath);
        return WriteRawPropertyMapToFile(file,
                                         normalizedProperties,
                                         error,
                                         196,
                                         @"Unable to open DSDIFF file for metadata editing",
                                         197,
                                         @"TagLib failed to save DSDIFF metadata property changes",
                                         [NSString stringWithFormat:@"DSDIFF '%@'", fileURL.lastPathComponent]);
    }

    if (format == AudioMatorTagFileFormatMOD) {
        TagLib::Mod::File file(filePath);
        return WriteRawPropertyMapToFile(file,
                                         normalizedProperties,
                                         error,
                                         214,
                                         @"Unable to open MOD file for metadata editing",
                                         215,
                                         @"TagLib failed to save MOD metadata property changes",
                                         [NSString stringWithFormat:@"MOD '%@'", fileURL.lastPathComponent]);
    }

    if (format == AudioMatorTagFileFormatS3M) {
        TagLib::S3M::File file(filePath);
        return WriteRawPropertyMapToFile(file,
                                         normalizedProperties,
                                         error,
                                         216,
                                         @"Unable to open S3M file for metadata editing",
                                         217,
                                         @"TagLib failed to save S3M metadata property changes",
                                         [NSString stringWithFormat:@"S3M '%@'", fileURL.lastPathComponent]);
    }

    if (format == AudioMatorTagFileFormatIT) {
        TagLib::IT::File file(filePath);
        return WriteRawPropertyMapToFile(file,
                                         normalizedProperties,
                                         error,
                                         218,
                                         @"Unable to open IT file for metadata editing",
                                         219,
                                         @"TagLib failed to save IT metadata property changes",
                                         [NSString stringWithFormat:@"IT '%@'", fileURL.lastPathComponent]);
    }

    if (format == AudioMatorTagFileFormatXM) {
        TagLib::XM::File file(filePath);
        return WriteRawPropertyMapToFile(file,
                                         normalizedProperties,
                                         error,
                                         220,
                                         @"Unable to open XM file for metadata editing",
                                         221,
                                         @"TagLib failed to save XM metadata property changes",
                                         [NSString stringWithFormat:@"XM '%@'", fileURL.lastPathComponent]);
    }

    if (error) {
        *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                     code:101
                                 userInfo:@{ NSLocalizedDescriptionKey : @"Unsupported audio format" }];
    }
    return NO;
    TAGLIB_BRIDGE_CATCH_WITH_ERROR(error, @"Raw property-map write", NO)
}

+ (BOOL)writeRawPropertyMapValues:(NSDictionary<NSString *, NSArray<NSString *> *> *)properties
                            toURL:(NSURL *)fileURL
                            error:(NSError **)error
{
    try {
    TAGLIB_BRIDGE_SERIAL_GUARD();
    if (TagLibAtomicMutationDepth == 0) {
        return PerformAtomicTagLibMutation(fileURL, error, @"Raw multi-value property-map write", ^BOOL(NSURL *temporaryURL, NSError **mutationError) {
            return [self writeRawPropertyMapValues:properties toURL:temporaryURL error:mutationError];
        });
    }
    if (!fileURL || !fileURL.isFileURL) {
        if (error) {
            *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                         code:222
                                     userInfo:@{ NSLocalizedDescriptionKey : @"Invalid file URL" }];
        }
        return NO;
    }

    NSString *ext = fileURL.pathExtension.lowercaseString;
    AudioMatorTagFileFormat format = DetectTagFileFormat(ext);
    if (!IsWritableTagFileFormat(format)) {
        if (error) {
            *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                         code:223
                                     userInfo:@{ NSLocalizedDescriptionKey : @"Unsupported audio format" }];
        }
        return NO;
    }

    const char *filePath = fileURL.path.UTF8String;
    if (!filePath) {
        if (error) {
            *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                         code:224
                                     userInfo:@{ NSLocalizedDescriptionKey : @"Invalid file path" }];
        }
        return NO;
    }

#define WRITE_VALUES_FOR_FILE(TYPE, LABEL) \
    do { \
        TYPE file(filePath); \
        return WriteRawPropertyMapValuesToFile(file, properties ?: @{}, error, 225, \
            [NSString stringWithFormat:@"Unable to open %@ file for metadata editing", LABEL], 226, \
            [NSString stringWithFormat:@"TagLib failed to save %@ metadata property changes", LABEL], \
            [NSString stringWithFormat:@"%@ '%@'", LABEL, fileURL.lastPathComponent]); \
    } while (false)

    switch (format) {
        case AudioMatorTagFileFormatMPEGID3:
        case AudioMatorTagFileFormatMPEGAAC:
            WRITE_VALUES_FOR_FILE(TagLib::MPEG::File, @"MPEG");
        case AudioMatorTagFileFormatMP4:
            WRITE_VALUES_FOR_FILE(TagLib::MP4::File, @"MP4");
        case AudioMatorTagFileFormatFLAC:
            WRITE_VALUES_FOR_FILE(TagLib::FLAC::File, @"FLAC");
        case AudioMatorTagFileFormatOggVorbis:
            WRITE_VALUES_FOR_FILE(TagLib::Ogg::Vorbis::File, @"Ogg Vorbis");
        case AudioMatorTagFileFormatOggOpus:
            WRITE_VALUES_FOR_FILE(TagLib::Ogg::Opus::File, @"Opus");
        case AudioMatorTagFileFormatOggFlac:
            WRITE_VALUES_FOR_FILE(TagLib::Ogg::FLAC::File, @"Ogg FLAC");
        case AudioMatorTagFileFormatOggSpeex:
            WRITE_VALUES_FOR_FILE(TagLib::Ogg::Speex::File, @"Speex");
        case AudioMatorTagFileFormatAPE:
            WRITE_VALUES_FOR_FILE(TagLib::APE::File, @"APE");
        case AudioMatorTagFileFormatWavPack:
            WRITE_VALUES_FOR_FILE(TagLib::WavPack::File, @"WavPack");
        case AudioMatorTagFileFormatMPC:
            WRITE_VALUES_FOR_FILE(TagLib::MPC::File, @"Musepack");
        case AudioMatorTagFileFormatWAV:
            WRITE_VALUES_FOR_FILE(TagLib::RIFF::WAV::File, @"WAV");
        case AudioMatorTagFileFormatAIFF:
            WRITE_VALUES_FOR_FILE(TagLib::RIFF::AIFF::File, @"AIFF");
        case AudioMatorTagFileFormatTTA:
            WRITE_VALUES_FOR_FILE(TagLib::TrueAudio::File, @"TrueAudio");
        case AudioMatorTagFileFormatASF:
            WRITE_VALUES_FOR_FILE(TagLib::ASF::File, @"ASF/WMA");
        case AudioMatorTagFileFormatDSF:
            WRITE_VALUES_FOR_FILE(TagLib::DSF::File, @"DSF");
        case AudioMatorTagFileFormatDSDIFF:
            WRITE_VALUES_FOR_FILE(TagLib::DSDIFF::File, @"DSDIFF");
        case AudioMatorTagFileFormatMOD:
            WRITE_VALUES_FOR_FILE(TagLib::Mod::File, @"MOD");
        case AudioMatorTagFileFormatS3M:
            WRITE_VALUES_FOR_FILE(TagLib::S3M::File, @"S3M");
        case AudioMatorTagFileFormatIT:
            WRITE_VALUES_FOR_FILE(TagLib::IT::File, @"IT");
        case AudioMatorTagFileFormatXM:
            WRITE_VALUES_FOR_FILE(TagLib::XM::File, @"XM");
        case AudioMatorTagFileFormatUnknown:
        case AudioMatorTagFileFormatShorten:
            break;
    }

#undef WRITE_VALUES_FOR_FILE

    if (error) {
        *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                     code:223
                                 userInfo:@{ NSLocalizedDescriptionKey : @"Unsupported audio format" }];
    }
    return NO;
    TAGLIB_BRIDGE_CATCH_WITH_ERROR(error, @"Raw multi-value property-map write", NO)
}

// Parse an NSString like "03/12" or "03" into numeric components and an inferred pad width.
// padWidth is inferred only from the *track/disc part* (before '/'): if it contains leading zeros,
// we treat its string length as the desired pad width.
static void ParseNumberPairFromNSString(NSString *text,
                                       NSInteger &number,
                                       NSInteger &total,
                                       NSInteger &padWidth)
{
    number = 0;
    total = 0;
    padWidth = 0;

    if (!text || text.length == 0) {
        return;
    }

    NSString *trimmed = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0) {
        return;
    }

    NSArray<NSString *> *parts = [trimmed componentsSeparatedByString:@"/"];
    NSString *left = parts.count > 0 ? parts[0] : trimmed;

    // Infer padding width from leading zeros in the left part.
    // Example: "01" -> padWidth=2, "1" -> padWidth=0.
    NSString *leftTrim = [left stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (leftTrim.length > 1 && [leftTrim hasPrefix:@"0"]) {
        padWidth = (NSInteger)leftTrim.length;
    }

    // Parse numbers.
    number = leftTrim.integerValue;
    if (parts.count >= 2) {
        NSString *right = [parts[1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        total = right.integerValue;
    }
}

// Write only track/disc number text. This is useful for auto-renumbering where the UI
// may already have produced a padded representation like "01/10".
+ (BOOL)writeTrackNumberText:(NSString *)trackNumberText
              discNumberText:(NSString *)discNumberText
                       toURL:(NSURL *)fileURL
                       error:(NSError **)error
{
    try {
    TAGLIB_BRIDGE_SERIAL_GUARD();
    if (TagLibAtomicMutationDepth == 0) {
        return PerformAtomicTagLibMutation(fileURL, error, @"Track/disc-number write", ^BOOL(NSURL *temporaryURL, NSError **mutationError) {
            return [self writeTrackNumberText:trackNumberText
                               discNumberText:discNumberText
                                        toURL:temporaryURL
                                        error:mutationError];
        });
    }
    if (!fileURL || ![fileURL isFileURL]) {
        if (error) {
            *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                         code:50
                                     userInfo:@{ NSLocalizedDescriptionKey : @"Invalid file URL" }];
        }
        return NO;
    }

    NSString *ext = fileURL.pathExtension.lowercaseString;
    AudioMatorTagFileFormat format = DetectTagFileFormat(ext);
    if (!IsWritableTagFileFormat(format)) {
        if (error) {
            *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                         code:51
                                     userInfo:@{ NSLocalizedDescriptionKey : @"Writing track/disc numbers is currently supported for every format that AudioMator can edit metadata for" }];
        }
        TLog(@"Track/disc write skipped for '%@' (extension '%@' not supported)", fileURL.lastPathComponent, ext);
        return NO;
    }

    const char *filePath = fileURL.path.UTF8String;
    if (format == AudioMatorTagFileFormatMPEGID3 || format == AudioMatorTagFileFormatMPEGAAC) {
        TagLib::MPEG::File mpegFile(filePath);

        if (format == AudioMatorTagFileFormatMPEGAAC) {
            if (!WritePropertyMapNumberTextToFile(mpegFile,
                                                  TrimmedStringOrNil(trackNumberText),
                                                  discNumberText,
                                                  error,
                                                  52,
                                                  @"Unable to open AAC file for writing track/disc numbers",
                                                  54,
                                                  @"TagLib failed to save AAC track/disc numbers",
                                                  [NSString stringWithFormat:@"AAC '%@'", fileURL.lastPathComponent])) {
                return NO;
            }
        } else {
            if (!mpegFile.isValid()) {
                if (error) {
                    *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                                 code:52
                                             userInfo:@{ NSLocalizedDescriptionKey : @"Unable to open file for writing track/disc numbers" }];
                }
                TLog(@"Failed to open '%@' for track/disc write", fileURL.lastPathComponent);
                return NO;
            }

            TagLib::Tag *tag = mpegFile.tag();
            if (!tag) {
                if (error) {
                    *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                                 code:53
                                             userInfo:@{ NSLocalizedDescriptionKey : @"No tag found to write track/disc numbers into" }];
                }
                TLog(@"No tag object available for '%@' (track/disc write)", fileURL.lastPathComponent);
                return NO;
            }

            TagLib::ID3v2::Tag *id3v2Tag = mpegFile.ID3v2Tag(true);

            NSString *trimmedTrackText = TrimmedStringOrNil(trackNumberText);
            if (trimmedTrackText) {
                NSInteger trackNumber = 0;
                NSInteger totalTracks = 0;
                NSInteger padWidth = 0;
                ParseNumberPairFromNSString(trimmedTrackText, trackNumber, totalTracks, padWidth);
                if (totalTracks <= 0 && id3v2Tag) {
                    TagLib::ID3v2::FrameList existingFrames = id3v2Tag->frameList("TRCK");
                    if (!existingFrames.isEmpty()) {
                        NSString *existingText = TagStringToNSString(existingFrames.front()->toString());
                        NSInteger existingNumber = 0;
                        NSInteger existingTotal = 0;
                        NSInteger existingPadWidth = 0;
                        ParseNumberPairFromNSString(existingText, existingNumber, existingTotal, existingPadWidth);
                        (void)existingNumber;
                        (void)existingPadWidth;
                        totalTracks = existingTotal;
                    }
                }
                tag->setTrack(trackNumber > 0 ? (unsigned int)trackNumber : 0);

                if (id3v2Tag) {
                    NSString *trckToWrite = BuildTRCKString(trackNumber, totalTracks, padWidth) ?: trimmedTrackText;
                    SetID3v2TextFrame(id3v2Tag, "TRCK", trckToWrite);
                }
            } else {
                tag->setTrack(0);
                SetID3v2TextFrame(id3v2Tag, "TRCK", nil);
            }

            if (discNumberText != nil && id3v2Tag) {
                NSString *trimmedDiscText = TrimmedStringOrNil(discNumberText);
                if (trimmedDiscText) {
                    NSInteger discNumber = 0;
                    NSInteger totalDiscs = 0;
                    NSInteger padWidth = 0;
                    ParseNumberPairFromNSString(trimmedDiscText, discNumber, totalDiscs, padWidth);
                    if (totalDiscs <= 0) {
                        TagLib::ID3v2::FrameList existingFrames = id3v2Tag->frameList("TPOS");
                        if (!existingFrames.isEmpty()) {
                            NSString *existingText = TagStringToNSString(existingFrames.front()->toString());
                            NSInteger existingNumber = 0;
                            NSInteger existingTotal = 0;
                            NSInteger existingPadWidth = 0;
                            ParseNumberPairFromNSString(existingText, existingNumber, existingTotal, existingPadWidth);
                            (void)existingNumber;
                            (void)existingPadWidth;
                            totalDiscs = existingTotal;
                        }
                    }
                    NSString *tposToWrite = BuildTRCKString(discNumber, totalDiscs, padWidth) ?: trimmedDiscText;
                    SetID3v2TextFrame(id3v2Tag, "TPOS", tposToWrite);
                } else {
                    SetID3v2TextFrame(id3v2Tag, "TPOS", nil);
                }
            }

            if (!mpegFile.save()) {
                if (error) {
                    *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                                 code:54
                                             userInfo:@{ NSLocalizedDescriptionKey : @"TagLib failed to save after writing track/disc numbers" }];
                }
                TLog(@"TagLib save() failed after track/disc write for '%@'", fileURL.lastPathComponent);
                return NO;
            }
        }
    } else if (format == AudioMatorTagFileFormatMP4) {
        TagLib::MP4::File mp4File(filePath);

        if (!mp4File.isValid()) {
            if (error) {
                *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                             code:55
                                         userInfo:@{ NSLocalizedDescriptionKey : @"Unable to open MP4/M4A file for writing track/disc numbers" }];
            }
            TLog(@"Failed to open MP4 '%@' for track/disc write", fileURL.lastPathComponent);
            return NO;
        }

        TagLib::MP4::Tag *mp4Tag = mp4File.tag();
        if (!mp4Tag) {
            if (error) {
                *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                             code:56
                                         userInfo:@{ NSLocalizedDescriptionKey : @"No MP4 tag found to write track/disc numbers into" }];
            }
            TLog(@"No MP4 tag object available for '%@' (track/disc write)", fileURL.lastPathComponent);
            return NO;
        }

        NSString *trimmedTrackText = TrimmedStringOrNil(trackNumberText);
        if (trimmedTrackText) {
            NSInteger trackNumber = 0;
            NSInteger totalTracks = 0;
            NSInteger padWidth = 0;
            ParseNumberPairFromNSString(trimmedTrackText, trackNumber, totalTracks, padWidth);
            if (totalTracks <= 0 && mp4Tag->itemMap().contains("trkn")) {
                totalTracks = mp4Tag->itemMap()["trkn"].toIntPair().second;
            }
            (void)padWidth;
            mp4Tag->setTrack(trackNumber > 0 ? (unsigned int)trackNumber : 0);
            SetMP4IntPairItem(mp4Tag, "trkn", trackNumber, totalTracks);
            SetMP4TextItem(mp4Tag, kAudioMatorMP4TrackNumberTextKey, trimmedTrackText);
        } else {
            mp4Tag->removeItem("trkn");
            mp4Tag->setTrack(0);
            SetMP4TextItem(mp4Tag, kAudioMatorMP4TrackNumberTextKey, nil);
        }

        if (discNumberText) {
            NSString *trimmedDiscText = TrimmedStringOrNil(discNumberText);
            if (trimmedDiscText) {
                NSInteger discNumber = 0;
                NSInteger totalDiscs = 0;
                NSInteger padWidth = 0;
                ParseNumberPairFromNSString(trimmedDiscText, discNumber, totalDiscs, padWidth);
                if (totalDiscs <= 0 && mp4Tag->itemMap().contains("disk")) {
                    totalDiscs = mp4Tag->itemMap()["disk"].toIntPair().second;
                }
                (void)padWidth;
                SetMP4IntPairItem(mp4Tag, "disk", discNumber, totalDiscs);
                SetMP4TextItem(mp4Tag, kAudioMatorMP4DiscNumberTextKey, trimmedDiscText);
            } else {
                mp4Tag->removeItem("disk");
                SetMP4TextItem(mp4Tag, kAudioMatorMP4DiscNumberTextKey, nil);
            }
        }

        if (!mp4File.save()) {
            if (error) {
                *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                             code:57
                                         userInfo:@{ NSLocalizedDescriptionKey : @"TagLib failed to save MP4/M4A track/disc numbers" }];
            }
            TLog(@"TagLib save() failed after MP4 track/disc write for '%@'", fileURL.lastPathComponent);
            return NO;
        }
    } else if (format == AudioMatorTagFileFormatFLAC) {
        TagLib::FLAC::File flacFile(filePath);
        if (!WritePropertyMapNumberTextToFile(flacFile,
                                              TrimmedStringOrNil(trackNumberText),
                                              discNumberText,
                                              error,
                                              58,
                                              @"Unable to open FLAC file for writing track/disc numbers",
                                              59,
                                              @"TagLib failed to save FLAC track/disc numbers",
                                              [NSString stringWithFormat:@"FLAC '%@'", fileURL.lastPathComponent])) {
            return NO;
        }
    } else if (format == AudioMatorTagFileFormatOggVorbis) {
        TagLib::Ogg::Vorbis::File vorbisFile(filePath);
        if (!WritePropertyMapNumberTextToFile(vorbisFile,
                                              TrimmedStringOrNil(trackNumberText),
                                              discNumberText,
                                              error,
                                              96,
                                              @"Unable to open Ogg Vorbis file for writing track/disc numbers",
                                              97,
                                              @"TagLib failed to save Ogg Vorbis track/disc numbers",
                                              [NSString stringWithFormat:@"Ogg Vorbis '%@'", fileURL.lastPathComponent])) {
            return NO;
        }
    } else if (format == AudioMatorTagFileFormatOggOpus) {
        TagLib::Ogg::Opus::File opusFile(filePath);
        if (!WritePropertyMapNumberTextToFile(opusFile,
                                              TrimmedStringOrNil(trackNumberText),
                                              discNumberText,
                                              error,
                                              98,
                                              @"Unable to open Opus file for writing track/disc numbers",
                                              99,
                                              @"TagLib failed to save Opus track/disc numbers",
                                              [NSString stringWithFormat:@"Opus '%@'", fileURL.lastPathComponent])) {
            return NO;
        }
    } else if (format == AudioMatorTagFileFormatOggFlac) {
        TagLib::Ogg::FLAC::File oggFlacFile(filePath);
        if (!WritePropertyMapNumberTextToFile(oggFlacFile,
                                              TrimmedStringOrNil(trackNumberText),
                                              discNumberText,
                                              error,
                                              100,
                                              @"Unable to open Ogg FLAC file for writing track/disc numbers",
                                              101,
                                              @"TagLib failed to save Ogg FLAC track/disc numbers",
                                              [NSString stringWithFormat:@"Ogg FLAC '%@'", fileURL.lastPathComponent])) {
            return NO;
        }
    } else if (format == AudioMatorTagFileFormatOggSpeex) {
        TagLib::Ogg::Speex::File speexFile(filePath);
        if (!WritePropertyMapNumberTextToFile(speexFile,
                                              TrimmedStringOrNil(trackNumberText),
                                              discNumberText,
                                              error,
                                              102,
                                              @"Unable to open Speex file for writing track/disc numbers",
                                              103,
                                              @"TagLib failed to save Speex track/disc numbers",
                                              [NSString stringWithFormat:@"Speex '%@'", fileURL.lastPathComponent])) {
            return NO;
        }
    } else if (format == AudioMatorTagFileFormatAPE) {
        TagLib::APE::File apeFile(filePath);
        if (!WritePropertyMapNumberTextToFile(apeFile,
                                              TrimmedStringOrNil(trackNumberText),
                                              discNumberText,
                                              error,
                                              104,
                                              @"Unable to open APE file for writing track/disc numbers",
                                              105,
                                              @"TagLib failed to save APE track/disc numbers",
                                              [NSString stringWithFormat:@"APE '%@'", fileURL.lastPathComponent])) {
            return NO;
        }
    } else if (format == AudioMatorTagFileFormatWavPack) {
        TagLib::WavPack::File wavPackFile(filePath);
        if (!WritePropertyMapNumberTextToFile(wavPackFile,
                                              TrimmedStringOrNil(trackNumberText),
                                              discNumberText,
                                              error,
                                              106,
                                              @"Unable to open WavPack file for writing track/disc numbers",
                                              107,
                                              @"TagLib failed to save WavPack track/disc numbers",
                                              [NSString stringWithFormat:@"WavPack '%@'", fileURL.lastPathComponent])) {
            return NO;
        }
    } else if (format == AudioMatorTagFileFormatMPC) {
        TagLib::MPC::File mpcFile(filePath);
        if (!WritePropertyMapNumberTextToFile(mpcFile,
                                              TrimmedStringOrNil(trackNumberText),
                                              discNumberText,
                                              error,
                                              108,
                                              @"Unable to open Musepack file for writing track/disc numbers",
                                              109,
                                              @"TagLib failed to save Musepack track/disc numbers",
                                              [NSString stringWithFormat:@"Musepack '%@'", fileURL.lastPathComponent])) {
            return NO;
        }
    } else if (format == AudioMatorTagFileFormatWAV) {
        TagLib::RIFF::WAV::File wavFile(filePath);
        if (!WritePropertyMapNumberTextToFile(wavFile,
                                              TrimmedStringOrNil(trackNumberText),
                                              discNumberText,
                                              error,
                                              64,
                                              @"Unable to open WAV file for writing track/disc numbers",
                                              65,
                                              @"TagLib failed to save WAV track/disc numbers",
                                              [NSString stringWithFormat:@"WAV '%@'", fileURL.lastPathComponent])) {
            return NO;
        }
    } else if (format == AudioMatorTagFileFormatAIFF) {
        TagLib::RIFF::AIFF::File aiffFile(filePath);
        if (!WritePropertyMapNumberTextToFile(aiffFile,
                                              TrimmedStringOrNil(trackNumberText),
                                              discNumberText,
                                              error,
                                              66,
                                              @"Unable to open AIFF file for writing track/disc numbers",
                                              67,
                                              @"TagLib failed to save AIFF track/disc numbers",
                                              [NSString stringWithFormat:@"AIFF '%@'", fileURL.lastPathComponent])) {
            return NO;
        }
    } else if (format == AudioMatorTagFileFormatTTA) {
        TagLib::TrueAudio::File ttaFile(filePath);
        if (!WritePropertyMapNumberTextToFile(ttaFile,
                                              TrimmedStringOrNil(trackNumberText),
                                              discNumberText,
                                              error,
                                              110,
                                              @"Unable to open TrueAudio file for writing track/disc numbers",
                                              111,
                                              @"TagLib failed to save TrueAudio track/disc numbers",
                                              [NSString stringWithFormat:@"TrueAudio '%@'", fileURL.lastPathComponent])) {
            return NO;
        }
    } else if (format == AudioMatorTagFileFormatASF) {
        TagLib::ASF::File asfFile(filePath);
        if (!WritePropertyMapNumberTextToFile(asfFile,
                                              TrimmedStringOrNil(trackNumberText),
                                              discNumberText,
                                              error,
                                              112,
                                              @"Unable to open ASF/WMA file for writing track/disc numbers",
                                              113,
                                              @"TagLib failed to save ASF/WMA track/disc numbers",
                                              [NSString stringWithFormat:@"ASF/WMA '%@'", fileURL.lastPathComponent])) {
            return NO;
        }
    } else if (format == AudioMatorTagFileFormatDSF) {
        TagLib::DSF::File dsfFile(filePath);
        if (!WritePropertyMapNumberTextToFile(dsfFile,
                                              TrimmedStringOrNil(trackNumberText),
                                              discNumberText,
                                              error,
                                              114,
                                              @"Unable to open DSF file for writing track/disc numbers",
                                              115,
                                              @"TagLib failed to save DSF track/disc numbers",
                                              [NSString stringWithFormat:@"DSF '%@'", fileURL.lastPathComponent])) {
            return NO;
        }
    } else if (format == AudioMatorTagFileFormatDSDIFF) {
        TagLib::DSDIFF::File dsdiffFile(filePath);
        if (!WritePropertyMapNumberTextToFile(dsdiffFile,
                                              TrimmedStringOrNil(trackNumberText),
                                              discNumberText,
                                              error,
                                              116,
                                              @"Unable to open DSDIFF file for writing track/disc numbers",
                                              117,
                                              @"TagLib failed to save DSDIFF track/disc numbers",
                                              [NSString stringWithFormat:@"DSDIFF '%@'", fileURL.lastPathComponent])) {
            return NO;
        }
    } else if (format == AudioMatorTagFileFormatMOD) {
        TagLib::Mod::File modFile(filePath);
        if (!WritePropertyMapNumberTextToFile(modFile,
                                              TrimmedStringOrNil(trackNumberText),
                                              discNumberText,
                                              error,
                                              206,
                                              @"Unable to open MOD file for writing track/disc numbers",
                                              207,
                                              @"TagLib failed to save MOD track/disc numbers",
                                              [NSString stringWithFormat:@"MOD '%@'", fileURL.lastPathComponent])) {
            return NO;
        }
    } else if (format == AudioMatorTagFileFormatS3M) {
        TagLib::S3M::File s3mFile(filePath);
        if (!WritePropertyMapNumberTextToFile(s3mFile,
                                              TrimmedStringOrNil(trackNumberText),
                                              discNumberText,
                                              error,
                                              208,
                                              @"Unable to open S3M file for writing track/disc numbers",
                                              209,
                                              @"TagLib failed to save S3M track/disc numbers",
                                              [NSString stringWithFormat:@"S3M '%@'", fileURL.lastPathComponent])) {
            return NO;
        }
    } else if (format == AudioMatorTagFileFormatIT) {
        TagLib::IT::File itFile(filePath);
        if (!WritePropertyMapNumberTextToFile(itFile,
                                              TrimmedStringOrNil(trackNumberText),
                                              discNumberText,
                                              error,
                                              210,
                                              @"Unable to open IT file for writing track/disc numbers",
                                              211,
                                              @"TagLib failed to save IT track/disc numbers",
                                              [NSString stringWithFormat:@"IT '%@'", fileURL.lastPathComponent])) {
            return NO;
        }
    } else if (format == AudioMatorTagFileFormatXM) {
        TagLib::XM::File xmFile(filePath);
        if (!WritePropertyMapNumberTextToFile(xmFile,
                                              TrimmedStringOrNil(trackNumberText),
                                              discNumberText,
                                              error,
                                              212,
                                              @"Unable to open XM file for writing track/disc numbers",
                                              213,
                                              @"TagLib failed to save XM track/disc numbers",
                                              [NSString stringWithFormat:@"XM '%@'", fileURL.lastPathComponent])) {
            return NO;
        }
    } else {
        if (error) {
            *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                         code:51
                                     userInfo:@{ NSLocalizedDescriptionKey : @"Writing track/disc numbers is currently supported for every format that AudioMator can edit metadata for" }];
        }
        return NO;
    }

    TLog(@"Successfully wrote track/disc text to '%@' (TRCK=%@, TPOS=%@)",
         fileURL.lastPathComponent,
         trackNumberText ?: @"<nil>",
         discNumberText ?: @"<nil>");

    return YES;
    TAGLIB_BRIDGE_CATCH_WITH_ERROR(error, @"Track/disc-number write", NO)
}
// Write metadata to file (MPEG, MP4/M4A, FLAC, WAV, AIFF supported)
