+ (nullable TagLibAudioMetadata *)extractMetadataFromURL:(NSURL *)fileURL
                                                   error:(NSError **)error {
    try {
    if (!fileURL || ![fileURL isFileURL]) {
        if (error) {
            *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                         code:1
                                     userInfo:@{NSLocalizedDescriptionKey: @"Invalid file URL"}];
        }
        return nil;
    }

    const char* filePath = [fileURL.path UTF8String];
    NSString *extension = fileURL.pathExtension.lowercaseString;
    std::string ext = [extension UTF8String];
    AudioMatorTagFileFormat format = DetectTagFileFormat(extension);

    TagLibAudioMetadata* metadata = [[TagLibAudioMetadata alloc] init];
    TLog(@"Created TagLibAudioMetadata object for '%@'", fileURL.lastPathComponent);
    bool openedSpecificFile = false;

    // Extract format-specific metadata
    // MP3
    if (format == AudioMatorTagFileFormatMPEGID3 || format == AudioMatorTagFileFormatMPEGAAC) {
        TagLib::MPEG::File mpegFile(filePath);
        if (mpegFile.isValid()) {
            bool isAAC = (format == AudioMatorTagFileFormatMPEGAAC);
            openedSpecificFile = true;

            ApplyBasicTagMetadata(mpegFile.tag(), metadata);
            ApplyGenericPropertyMapMetadata(mpegFile.properties(), metadata);
            ApplyAudioPropertiesMetadata(mpegFile.audioProperties(), metadata);

            if (format == AudioMatorTagFileFormatMPEGAAC) {
                metadata.codec = @"AAC";
            } else if (ext == "mp2") {
                metadata.codec = @"MP2";
            } else {
                metadata.codec = @"MP3";
            }

            if (!isAAC) {
                if (mpegFile.ID3v2Tag()) {
                    ExtractID3v2Metadata(mpegFile.ID3v2Tag(), metadata);
                }

                if (mpegFile.APETag()) {
                    ExtractAPEMetadata(mpegFile.APETag(), metadata);
                }

                if (mpegFile.ID3v1Tag()) {
                    // ID3v1 is a low-fidelity fallback. It must not overwrite richer
                    // values already gathered from PropertyMap / ID3v2.
                    ApplyBasicTagMetadata(mpegFile.ID3v1Tag(), metadata);
                }
            }
        }
    }
    // MP4/M4A
    else if (format == AudioMatorTagFileFormatMP4) {
        TagLib::MP4::File mp4File(filePath);
        if (mp4File.isValid()) {
            openedSpecificFile = true;
            metadata.codec = ext == "mp4" ? @"MP4" : @"AAC";

            ApplyGenericPropertyMapMetadata(mp4File.properties(), metadata);
            ApplyAudioPropertiesMetadata(mp4File.audioProperties(), metadata);

            if (mp4File.tag()) {
                ApplyBasicTagMetadata(mp4File.tag(), metadata);
                ExtractMP4Metadata(mp4File.tag(), metadata);
            }
        }
    }
    // FLAC
    else if (format == AudioMatorTagFileFormatFLAC) {
        TagLib::FLAC::File flacFile(filePath);
        if (flacFile.isValid()) {
            openedSpecificFile = true;
            metadata.codec = @"FLAC";

            ApplyGenericPropertyMapMetadata(flacFile.properties(), metadata);
            ApplyAudioPropertiesMetadata(flacFile.audioProperties(), metadata);

            if (flacFile.xiphComment()) {
                ExtractXiphCommentMetadata(flacFile.xiphComment(), metadata);
            }

            // Extract bit depth
            if (flacFile.audioProperties()) {
                metadata.bitDepth = flacFile.audioProperties()->bitsPerSample();
            }

            // Extract cover art
            ExtractFLACPicture(&flacFile, metadata);
        }
    }
    // OGG Vorbis
    else if (format == AudioMatorTagFileFormatOggVorbis) {
        TagLib::Ogg::Vorbis::File vorbisFile(filePath);
        if (vorbisFile.isValid()) {
            openedSpecificFile = true;
            metadata.codec = @"Vorbis";

            ApplyGenericPropertyMapMetadata(vorbisFile.properties(), metadata);
            ApplyAudioPropertiesMetadata(vorbisFile.audioProperties(), metadata);

            if (vorbisFile.tag()) {
                ExtractXiphCommentMetadata(vorbisFile.tag(), metadata);
                ExtractArtworkFromComplexProperties(vorbisFile.tag(), metadata);
            }
        }
    }
    // Opus
    else if (format == AudioMatorTagFileFormatOggOpus) {
        TagLib::Ogg::Opus::File opusFile(filePath);
        if (opusFile.isValid()) {
            openedSpecificFile = true;
            metadata.codec = @"Opus";

            ApplyGenericPropertyMapMetadata(opusFile.properties(), metadata);
            ApplyAudioPropertiesMetadata(opusFile.audioProperties(), metadata);

            if (opusFile.tag()) {
                ExtractXiphCommentMetadata(opusFile.tag(), metadata);
                ExtractArtworkFromComplexProperties(opusFile.tag(), metadata);
            }
        }
    }
    // OGG FLAC
    else if (format == AudioMatorTagFileFormatOggFlac) {
        TagLib::Ogg::FLAC::File oggFlacFile(filePath);
        if (oggFlacFile.isValid()) {
            openedSpecificFile = true;
            metadata.codec = @"OGG FLAC";

            ApplyGenericPropertyMapMetadata(oggFlacFile.properties(), metadata);
            ApplyAudioPropertiesMetadata(oggFlacFile.audioProperties(), metadata);

            if (oggFlacFile.tag()) {
                ExtractXiphCommentMetadata(oggFlacFile.tag(), metadata);
                ExtractArtworkFromComplexProperties(oggFlacFile.tag(), metadata);
            }
        }
    }
    // APE (Monkey's Audio)
    else if (format == AudioMatorTagFileFormatAPE) {
        TagLib::APE::File apeFile(filePath);
        if (apeFile.isValid()) {
            openedSpecificFile = true;
            metadata.codec = @"APE";

            ApplyGenericPropertyMapMetadata(apeFile.properties(), metadata);
            ApplyAudioPropertiesMetadata(apeFile.audioProperties(), metadata);

            if (apeFile.APETag()) {
                ExtractAPEMetadata(apeFile.APETag(), metadata);
            }
        }
    }
    // WavPack
    else if (format == AudioMatorTagFileFormatWavPack) {
        TagLib::WavPack::File wvFile(filePath);
        if (wvFile.isValid()) {
            openedSpecificFile = true;
            metadata.codec = @"WavPack";

            ApplyGenericPropertyMapMetadata(wvFile.properties(), metadata);
            ApplyAudioPropertiesMetadata(wvFile.audioProperties(), metadata);

            if (wvFile.APETag()) {
                ExtractAPEMetadata(wvFile.APETag(), metadata);
            }
        }
    }
    // WAV
    else if (format == AudioMatorTagFileFormatWAV) {
        TagLib::RIFF::WAV::File wavFile(filePath);
        if (wavFile.isValid()) {
            openedSpecificFile = true;
            metadata.codec = @"WAV";

            ApplyGenericPropertyMapMetadata(wavFile.properties(), metadata);
            ApplyAudioPropertiesMetadata(wavFile.audioProperties(), metadata);

            if (wavFile.ID3v2Tag()) {
                ExtractID3v2Metadata(wavFile.ID3v2Tag(), metadata);
            }

            // Extract bit depth
            if (wavFile.audioProperties()) {
                metadata.bitDepth = wavFile.audioProperties()->bitsPerSample();
            }
        }
    }
    // AIFF
    else if (format == AudioMatorTagFileFormatAIFF) {
        TagLib::RIFF::AIFF::File aiffFile(filePath);
        if (aiffFile.isValid()) {
            openedSpecificFile = true;
            metadata.codec = @"AIFF";

            ApplyGenericPropertyMapMetadata(aiffFile.properties(), metadata);
            ApplyAudioPropertiesMetadata(aiffFile.audioProperties(), metadata);

            if (aiffFile.tag()) {
                ExtractID3v2Metadata(aiffFile.tag(), metadata);
            }

            // Extract bit depth
            if (aiffFile.audioProperties()) {
                metadata.bitDepth = aiffFile.audioProperties()->bitsPerSample();
            }
        }
    }
    // TrueAudio
    else if (format == AudioMatorTagFileFormatTTA) {
        TagLib::TrueAudio::File ttaFile(filePath);
        if (ttaFile.isValid()) {
            openedSpecificFile = true;
            metadata.codec = @"TrueAudio";

            ApplyGenericPropertyMapMetadata(ttaFile.properties(), metadata);
            ApplyAudioPropertiesMetadata(ttaFile.audioProperties(), metadata);

            if (ttaFile.ID3v2Tag()) {
                ExtractID3v2Metadata(ttaFile.ID3v2Tag(), metadata);
            }

            if (ttaFile.ID3v1Tag()) {
                // ID3v1 is only used to fill gaps for legacy files.
                ApplyBasicTagMetadata(ttaFile.ID3v1Tag(), metadata);
            }
            // Extract bit depth
            if (ttaFile.audioProperties()) {
                metadata.bitDepth = ttaFile.audioProperties()->bitsPerSample();
            }
        }
    }
    // Musepack
    else if (format == AudioMatorTagFileFormatMPC) {
        TagLib::MPC::File mpcFile(filePath);
        if (mpcFile.isValid()) {
            openedSpecificFile = true;
            metadata.codec = @"Musepack";

            ApplyGenericPropertyMapMetadata(mpcFile.properties(), metadata);
            ApplyAudioPropertiesMetadata(mpcFile.audioProperties(), metadata);

            if (mpcFile.APETag()) {
                ExtractAPEMetadata(mpcFile.APETag(), metadata);
            }
        }
    }
    // Speex
    else if (format == AudioMatorTagFileFormatOggSpeex) {
        TagLib::Ogg::Speex::File speexFile(filePath);
        if (speexFile.isValid()) {
            openedSpecificFile = true;
            metadata.codec = @"Speex";

            ApplyGenericPropertyMapMetadata(speexFile.properties(), metadata);
            ApplyAudioPropertiesMetadata(speexFile.audioProperties(), metadata);

            if (speexFile.tag()) {
                ExtractXiphCommentMetadata(speexFile.tag(), metadata);
                ExtractArtworkFromComplexProperties(speexFile.tag(), metadata);
            }
        }
    }
    // ASF/WMA
    else if (format == AudioMatorTagFileFormatASF) {
        TagLib::ASF::File asfFile(filePath);
        if (asfFile.isValid()) {
            openedSpecificFile = true;
            metadata.codec = @"WMA";
            ApplyBasicTagMetadata(asfFile.tag(), metadata);
            ApplyGenericPropertyMapMetadata(asfFile.properties(), metadata);
            ApplyAudioPropertiesMetadata(asfFile.audioProperties(), metadata);
            if (asfFile.tag()) {
                ExtractArtworkFromComplexProperties(asfFile.tag(), metadata);
            }
        }
    }
    // DSF
    else if (format == AudioMatorTagFileFormatDSF) {
        TagLib::DSF::File dsfFile(filePath);
        if (dsfFile.isValid()) {
            openedSpecificFile = true;
            metadata.codec = @"DSF";

            ApplyGenericPropertyMapMetadata(dsfFile.properties(), metadata);
            ApplyAudioPropertiesMetadata(dsfFile.audioProperties(), metadata);

            // DSF files use ID3v2 tags, but accessed via tag() method
            if (dsfFile.tag()) {
                // The tag() method returns an ID3v2::Tag*
                if (auto id3tag = dynamic_cast<TagLib::ID3v2::Tag*>(dsfFile.tag())) {
                    ExtractID3v2Metadata(id3tag, metadata);
                }
            }
        }
    }
    // DSDIFF
    else if (format == AudioMatorTagFileFormatDSDIFF) {
        TagLib::DSDIFF::File dsdiffFile(filePath);
        if (dsdiffFile.isValid()) {
            openedSpecificFile = true;
            metadata.codec = @"DSDIFF";

            ApplyGenericPropertyMapMetadata(dsdiffFile.properties(), metadata);
            ApplyAudioPropertiesMetadata(dsdiffFile.audioProperties(), metadata);

            if (dsdiffFile.hasID3v2Tag()) {
                ExtractID3v2Metadata(dsdiffFile.ID3v2Tag(), metadata);
            }
        }
    }
    // Shorten
    else if (format == AudioMatorTagFileFormatShorten) {
        TagLib::Shorten::File shortenFile(filePath);
        if (shortenFile.isValid()) {
            openedSpecificFile = true;
            metadata.codec = @"Shorten";

            ApplyBasicTagMetadata(shortenFile.tag(), metadata);
            ApplyGenericPropertyMapMetadata(shortenFile.properties(), metadata);
            ApplyAudioPropertiesMetadata(shortenFile.audioProperties(), metadata);
        }
    }
    // Tracker/module formats
    else if (format == AudioMatorTagFileFormatMOD) {
        TagLib::Mod::File modFile(filePath);
        if (modFile.isValid()) {
            openedSpecificFile = true;
            metadata.codec = @"MOD";

            ApplyBasicTagMetadata(modFile.tag(), metadata);
            ApplyGenericPropertyMapMetadata(modFile.properties(), metadata);
            ApplyAudioPropertiesMetadata(modFile.audioProperties(), metadata);
        }
    }
    else if (format == AudioMatorTagFileFormatS3M) {
        TagLib::S3M::File s3mFile(filePath);
        if (s3mFile.isValid()) {
            openedSpecificFile = true;
            metadata.codec = @"S3M";

            ApplyBasicTagMetadata(s3mFile.tag(), metadata);
            ApplyGenericPropertyMapMetadata(s3mFile.properties(), metadata);
            ApplyAudioPropertiesMetadata(s3mFile.audioProperties(), metadata);
        }
    }
    else if (format == AudioMatorTagFileFormatIT) {
        TagLib::IT::File itFile(filePath);
        if (itFile.isValid()) {
            openedSpecificFile = true;
            metadata.codec = @"IT";

            ApplyBasicTagMetadata(itFile.tag(), metadata);
            ApplyGenericPropertyMapMetadata(itFile.properties(), metadata);
            ApplyAudioPropertiesMetadata(itFile.audioProperties(), metadata);
        }
    }
    else if (format == AudioMatorTagFileFormatXM) {
        TagLib::XM::File xmFile(filePath);
        if (xmFile.isValid()) {
            openedSpecificFile = true;
            metadata.codec = @"XM";

            ApplyBasicTagMetadata(xmFile.tag(), metadata);
            ApplyGenericPropertyMapMetadata(xmFile.properties(), metadata);
            ApplyAudioPropertiesMetadata(xmFile.audioProperties(), metadata);
        }
    }

    // Fallback path: only pay the generic FileRef cost if the format-specific
    // opener could not read the file at all.
    if (!openedSpecificFile) {
        TagLib::FileRef fileRef(filePath);
        if (!fileRef.isNull()) {
            ApplyBasicTagMetadata(fileRef.tag(), metadata);
            if (fileRef.file()) {
                ApplyGenericPropertyMapMetadata(fileRef.file()->properties(), metadata);
            }
            ApplyAudioPropertiesMetadata(fileRef.audioProperties(), metadata);
        }
    }

    TLog(@"Basic tag for '%@': title=%@ artist=%@ album=%@ genre=%@ comment=%@ year=%@ track=%ld",
         fileURL.lastPathComponent,
         metadata.title ?: @"<nil>",
         metadata.artist ?: @"<nil>",
         metadata.album ?: @"<nil>",
         metadata.genre ?: @"<nil>",
         metadata.comment ?: @"<nil>",
         metadata.year ?: @"<nil>",
         (long)metadata.trackNumber);

    TLog(@"Audio props for '%@': duration=%.1f s, bitrate=%ld kbps, sampleRate=%ld Hz, channels=%ld",
         fileURL.lastPathComponent,
         metadata.duration,
         (long)metadata.bitrate,
         (long)metadata.sampleRate,
         (long)metadata.channels);

    TLog(@"[READ-OUT] '%@' explicitContent=%@",
         fileURL.lastPathComponent,
         metadata.explicitContent ? @"YES" : @"NO");

    if (!openedSpecificFile || !HasCredibleAudioProperties(metadata)) {
        if (error) {
            *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                         code:2
                                     userInfo:@{NSLocalizedDescriptionKey: @"Unable to read credible audio properties from file"}];
        }
        return nil;
    }

    return metadata;
    TAGLIB_BRIDGE_CATCH_WITH_ERROR(error, @"Metadata extraction", nil)
}

static BOOL ValidateReadableAudioURL(NSURL *fileURL, NSError **error)
{
    NSError *validationError = nil;
    TagLibAudioMetadata *metadata = [TagLibMetadataExtractor extractMetadataFromURL:fileURL
                                                                               error:&validationError];
    if (metadata) {
        return YES;
    }
    if (error) {
        *error = validationError ?: [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                                       code:244
                                                   userInfo:@{ NSLocalizedDescriptionKey : @"Unable to read audio file" }];
    }
    return NO;
}



// Build an ID3v2 TRCK text string.
// - If padWidth > 0, the track number is left-padded with zeros to that width (e.g. 1 -> "01").
// - The total track count is written as-is (no padding).
static NSString * _Nullable BuildTRCKString(NSInteger trackNumber, NSInteger totalTracks, NSInteger padWidth) {
    if (trackNumber <= 0 && totalTracks <= 0) {
        return nil;
    }

    NSString *trackPart = nil;
    if (trackNumber > 0) {
        if (padWidth > 0) {
            trackPart = [NSString stringWithFormat:@"%0*ld", (int)padWidth, (long)trackNumber];
        } else {
            trackPart = [NSString stringWithFormat:@"%ld", (long)trackNumber];
        }
    } else {
        trackPart = @"0";
    }

    if (totalTracks > 0) {
        return [NSString stringWithFormat:@"%@/%ld", trackPart, (long)totalTracks];
    }

    return trackPart;
}

static NSString * _Nullable BuildNumberTextPreservingFormatting(NSString * _Nullable existingText,
                                                                NSInteger number,
                                                                NSInteger total)
{
    NSString *trimmedExistingText = TrimmedStringOrNil(existingText);
    NSInteger ignoredNumber = 0;
    NSInteger ignoredTotal = 0;
    NSInteger padWidth = 0;
    ParseNumberPairFromNSString(trimmedExistingText, ignoredNumber, ignoredTotal, padWidth);
    return BuildTRCKString(number, total, padWidth);
}

static NSString * _Nullable BuildPropertyMapNumberTextPreservingFormatting(NSString * _Nullable existingText,
                                                                           NSInteger number)
{
    NSString *trimmedExistingText = TrimmedStringOrNil(existingText);
    NSInteger ignoredNumber = 0;
    NSInteger ignoredTotal = 0;
    NSInteger padWidth = 0;
    ParseNumberPairFromNSString(trimmedExistingText, ignoredNumber, ignoredTotal, padWidth);
    return BuildTRCKString(number, 0, padWidth);
}

template <typename FileType>
static BOOL WriteGenericPropertyMapOnlyFile(const char *filePath,
                                            TagLibAudioMetadata *metadata,
                                            NSError **error,
                                            NSInteger openErrorCode,
                                            NSString *openErrorMessage,
                                            NSInteger saveErrorCode,
                                            NSString *saveErrorMessage,
                                            NSString *debugLabel)
{
    FileType file(filePath);
    if (!file.isValid()) {
        if (error) {
            *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                         code:openErrorCode
                                     userInfo:@{ NSLocalizedDescriptionKey : openErrorMessage }];
        }
        TLog(@"Failed to open %@ for writing", debugLabel);
        return NO;
    }

    ApplyGenericPropertyMapToFile(file, metadata);

    if (!file.save()) {
        if (error) {
            *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                         code:saveErrorCode
                                     userInfo:@{ NSLocalizedDescriptionKey : saveErrorMessage }];
        }
        TLog(@"TagLib save() failed for %@", debugLabel);
        return NO;
    }

    return YES;
}

template <typename FileType>
static BOOL StripAllTagsAndSave(FileType &file,
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
        TLog(@"Failed to open %@ for wiping", logContext);
        return NO;
    }

    file.strip();

    if (!file.save()) {
        if (error) {
            *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                         code:saveErrorCode
                                     userInfo:@{ NSLocalizedDescriptionKey : saveErrorMessage }];
        }
        TLog(@"TagLib save() failed after wiping for %@", logContext);
        return NO;
    }

    TLog(@"Successfully wiped metadata for %@", logContext);
    return YES;
}

// Write only track numbering (TRCK + TagLib::Tag::setTrack) to a file.
+ (BOOL)writeTrackNumber:(NSInteger)trackNumber
             totalTracks:(NSInteger)totalTracks
                padWidth:(NSInteger)padWidth
                   toURL:(NSURL *)fileURL
                   error:(NSError **)error
{
    try {
    if (TagLibAtomicMutationDepth == 0) {
        return PerformAtomicTagLibMutation(fileURL, error, @"Track-number write", ^BOOL(NSURL *temporaryURL, NSError **mutationError) {
            return [self writeTrackNumber:trackNumber
                              totalTracks:totalTracks
                                 padWidth:padWidth
                                    toURL:temporaryURL
                                    error:mutationError];
        });
    }
    if (!fileURL || ![fileURL isFileURL]) {
        if (error) {
            *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                         code:40
                                     userInfo:@{ NSLocalizedDescriptionKey : @"Invalid file URL" }];
        }
        return NO;
    }

    NSString *ext = fileURL.pathExtension.lowercaseString;
    AudioMatorTagFileFormat format = DetectTagFileFormat(ext);
    if (!IsWritableTagFileFormat(format)) {
        if (error) {
            *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                         code:41
                                     userInfo:@{ NSLocalizedDescriptionKey : @"Writing track numbers is currently supported for every format that AudioMator can edit metadata for" }];
        }
        TLog(@"Track renumber skipped for '%@' (extension '%@' not supported)", fileURL.lastPathComponent, ext);
        return NO;
    }

    const char *filePath = fileURL.path.UTF8String;
    if (format == AudioMatorTagFileFormatMPEGID3 || format == AudioMatorTagFileFormatMPEGAAC) {
        TagLib::MPEG::File mpegFile(filePath);

        if (format == AudioMatorTagFileFormatMPEGAAC) {
            if (!WritePropertyMapNumberTextToFile(mpegFile,
                                                  BuildTRCKString(trackNumber, totalTracks, padWidth),
                                                  nil,
                                                  error,
                                                  42,
                                                  @"Unable to open AAC file for writing track numbers",
                                                  44,
                                                  @"TagLib failed to save AAC track numbers",
                                                  [NSString stringWithFormat:@"AAC '%@'", fileURL.lastPathComponent])) {
                return NO;
            }
        } else {
            if (!mpegFile.isValid()) {
                if (error) {
                    *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                                 code:42
                                             userInfo:@{ NSLocalizedDescriptionKey : @"Unable to open file for writing track numbers" }];
                }
                TLog(@"Failed to open '%@' for track renumbering", fileURL.lastPathComponent);
                return NO;
            }

            TagLib::Tag *tag = mpegFile.tag();
            if (!tag) {
                if (error) {
                    *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                                 code:43
                                             userInfo:@{ NSLocalizedDescriptionKey : @"No tag found to write track numbers into" }];
                }
                TLog(@"No tag object available for '%@' (track renumbering)", fileURL.lastPathComponent);
                return NO;
            }

            if (trackNumber > 0) {
                tag->setTrack((unsigned int)trackNumber);
            }

            TagLib::ID3v2::Tag *id3v2Tag = mpegFile.ID3v2Tag(true);
            SetID3v2TextFrame(id3v2Tag, "TRCK", BuildTRCKString(trackNumber, totalTracks, padWidth));

            if (!mpegFile.save()) {
                if (error) {
                    *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                                 code:44
                                             userInfo:@{ NSLocalizedDescriptionKey : @"TagLib failed to save after writing track numbers" }];
                }
                TLog(@"TagLib save() failed after track renumbering for '%@'", fileURL.lastPathComponent);
                return NO;
            }
        }
    } else if (format == AudioMatorTagFileFormatMP4) {
        TagLib::MP4::File mp4File(filePath);

        if (!mp4File.isValid()) {
            if (error) {
                *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                             code:45
                                         userInfo:@{ NSLocalizedDescriptionKey : @"Unable to open MP4/M4A file for writing track numbers" }];
            }
            TLog(@"Failed to open MP4 '%@' for track renumbering", fileURL.lastPathComponent);
            return NO;
        }

        TagLib::MP4::Tag *mp4Tag = mp4File.tag();
        if (!mp4Tag) {
            if (error) {
                *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                             code:46
                                         userInfo:@{ NSLocalizedDescriptionKey : @"No MP4 tag found to write track numbers into" }];
            }
            TLog(@"No MP4 tag object available for '%@' (track renumbering)", fileURL.lastPathComponent);
            return NO;
        }

        if (trackNumber > 0) {
            mp4Tag->setTrack((unsigned int)trackNumber);
        } else {
            mp4Tag->setTrack(0);
        }

        SetMP4IntPairItem(mp4Tag, "trkn", trackNumber, totalTracks);

        if (!mp4File.save()) {
            if (error) {
                *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                             code:47
                                         userInfo:@{ NSLocalizedDescriptionKey : @"TagLib failed to save MP4/M4A track numbers" }];
            }
            TLog(@"TagLib save() failed after MP4 track renumbering for '%@'", fileURL.lastPathComponent);
            return NO;
        }
    } else if (format == AudioMatorTagFileFormatFLAC) {
        TagLib::FLAC::File flacFile(filePath);
        if (!WritePropertyMapNumberTextToFile(flacFile,
                                              BuildTRCKString(trackNumber, totalTracks, padWidth),
                                              nil,
                                              error,
                                              48,
                                              @"Unable to open FLAC file for writing track numbers",
                                              49,
                                              @"TagLib failed to save FLAC track numbers",
                                              [NSString stringWithFormat:@"FLAC '%@'", fileURL.lastPathComponent])) {
            return NO;
        }
    } else if (format == AudioMatorTagFileFormatOggVorbis) {
        TagLib::Ogg::Vorbis::File vorbisFile(filePath);
        if (!WritePropertyMapNumberTextToFile(vorbisFile,
                                              BuildTRCKString(trackNumber, totalTracks, padWidth),
                                              nil,
                                              error,
                                              74,
                                              @"Unable to open Ogg Vorbis file for writing track numbers",
                                              75,
                                              @"TagLib failed to save Ogg Vorbis track numbers",
                                              [NSString stringWithFormat:@"Ogg Vorbis '%@'", fileURL.lastPathComponent])) {
            return NO;
        }
    } else if (format == AudioMatorTagFileFormatOggOpus) {
        TagLib::Ogg::Opus::File opusFile(filePath);
        if (!WritePropertyMapNumberTextToFile(opusFile,
                                              BuildTRCKString(trackNumber, totalTracks, padWidth),
                                              nil,
                                              error,
                                              76,
                                              @"Unable to open Opus file for writing track numbers",
                                              77,
                                              @"TagLib failed to save Opus track numbers",
                                              [NSString stringWithFormat:@"Opus '%@'", fileURL.lastPathComponent])) {
            return NO;
        }
    } else if (format == AudioMatorTagFileFormatOggFlac) {
        TagLib::Ogg::FLAC::File oggFlacFile(filePath);
        if (!WritePropertyMapNumberTextToFile(oggFlacFile,
                                              BuildTRCKString(trackNumber, totalTracks, padWidth),
                                              nil,
                                              error,
                                              78,
                                              @"Unable to open Ogg FLAC file for writing track numbers",
                                              79,
                                              @"TagLib failed to save Ogg FLAC track numbers",
                                              [NSString stringWithFormat:@"Ogg FLAC '%@'", fileURL.lastPathComponent])) {
            return NO;
        }
    } else if (format == AudioMatorTagFileFormatOggSpeex) {
        TagLib::Ogg::Speex::File speexFile(filePath);
        if (!WritePropertyMapNumberTextToFile(speexFile,
                                              BuildTRCKString(trackNumber, totalTracks, padWidth),
                                              nil,
                                              error,
                                              80,
                                              @"Unable to open Speex file for writing track numbers",
                                              81,
                                              @"TagLib failed to save Speex track numbers",
                                              [NSString stringWithFormat:@"Speex '%@'", fileURL.lastPathComponent])) {
            return NO;
        }
    } else if (format == AudioMatorTagFileFormatAPE) {
        TagLib::APE::File apeFile(filePath);
        if (!WritePropertyMapNumberTextToFile(apeFile,
                                              BuildTRCKString(trackNumber, totalTracks, padWidth),
                                              nil,
                                              error,
                                              82,
                                              @"Unable to open APE file for writing track numbers",
                                              83,
                                              @"TagLib failed to save APE track numbers",
                                              [NSString stringWithFormat:@"APE '%@'", fileURL.lastPathComponent])) {
            return NO;
        }
    } else if (format == AudioMatorTagFileFormatWavPack) {
        TagLib::WavPack::File wavPackFile(filePath);
        if (!WritePropertyMapNumberTextToFile(wavPackFile,
                                              BuildTRCKString(trackNumber, totalTracks, padWidth),
                                              nil,
                                              error,
                                              84,
                                              @"Unable to open WavPack file for writing track numbers",
                                              85,
                                              @"TagLib failed to save WavPack track numbers",
                                              [NSString stringWithFormat:@"WavPack '%@'", fileURL.lastPathComponent])) {
            return NO;
        }
    } else if (format == AudioMatorTagFileFormatMPC) {
        TagLib::MPC::File mpcFile(filePath);
        if (!WritePropertyMapNumberTextToFile(mpcFile,
                                              BuildTRCKString(trackNumber, totalTracks, padWidth),
                                              nil,
                                              error,
                                              86,
                                              @"Unable to open Musepack file for writing track numbers",
                                              87,
                                              @"TagLib failed to save Musepack track numbers",
                                              [NSString stringWithFormat:@"Musepack '%@'", fileURL.lastPathComponent])) {
            return NO;
        }
    } else if (format == AudioMatorTagFileFormatWAV) {
        TagLib::RIFF::WAV::File wavFile(filePath);
        if (!WritePropertyMapNumberTextToFile(wavFile,
                                              BuildTRCKString(trackNumber, totalTracks, padWidth),
                                              nil,
                                              error,
                                              60,
                                              @"Unable to open WAV file for writing track numbers",
                                              61,
                                              @"TagLib failed to save WAV track numbers",
                                              [NSString stringWithFormat:@"WAV '%@'", fileURL.lastPathComponent])) {
            return NO;
        }
    } else if (format == AudioMatorTagFileFormatAIFF) {
        TagLib::RIFF::AIFF::File aiffFile(filePath);
        if (!WritePropertyMapNumberTextToFile(aiffFile,
                                              BuildTRCKString(trackNumber, totalTracks, padWidth),
                                              nil,
                                              error,
                                              62,
                                              @"Unable to open AIFF file for writing track numbers",
                                              63,
                                              @"TagLib failed to save AIFF track numbers",
                                              [NSString stringWithFormat:@"AIFF '%@'", fileURL.lastPathComponent])) {
            return NO;
        }
    } else if (format == AudioMatorTagFileFormatTTA) {
        TagLib::TrueAudio::File ttaFile(filePath);
        if (!WritePropertyMapNumberTextToFile(ttaFile,
                                              BuildTRCKString(trackNumber, totalTracks, padWidth),
                                              nil,
                                              error,
                                              88,
                                              @"Unable to open TrueAudio file for writing track numbers",
                                              89,
                                              @"TagLib failed to save TrueAudio track numbers",
                                              [NSString stringWithFormat:@"TrueAudio '%@'", fileURL.lastPathComponent])) {
            return NO;
        }
    } else if (format == AudioMatorTagFileFormatASF) {
        TagLib::ASF::File asfFile(filePath);
        if (!WritePropertyMapNumberTextToFile(asfFile,
                                              BuildTRCKString(trackNumber, totalTracks, padWidth),
                                              nil,
                                              error,
                                              90,
                                              @"Unable to open ASF/WMA file for writing track numbers",
                                              91,
                                              @"TagLib failed to save ASF/WMA track numbers",
                                              [NSString stringWithFormat:@"ASF/WMA '%@'", fileURL.lastPathComponent])) {
            return NO;
        }
    } else if (format == AudioMatorTagFileFormatDSF) {
        TagLib::DSF::File dsfFile(filePath);
        if (!WritePropertyMapNumberTextToFile(dsfFile,
                                              BuildTRCKString(trackNumber, totalTracks, padWidth),
                                              nil,
                                              error,
                                              92,
                                              @"Unable to open DSF file for writing track numbers",
                                              93,
                                              @"TagLib failed to save DSF track numbers",
                                              [NSString stringWithFormat:@"DSF '%@'", fileURL.lastPathComponent])) {
            return NO;
        }
    } else if (format == AudioMatorTagFileFormatDSDIFF) {
        TagLib::DSDIFF::File dsdiffFile(filePath);
        if (!WritePropertyMapNumberTextToFile(dsdiffFile,
                                              BuildTRCKString(trackNumber, totalTracks, padWidth),
                                              nil,
                                              error,
                                              94,
                                              @"Unable to open DSDIFF file for writing track numbers",
                                              95,
                                              @"TagLib failed to save DSDIFF track numbers",
                                              [NSString stringWithFormat:@"DSDIFF '%@'", fileURL.lastPathComponent])) {
            return NO;
        }
    } else if (format == AudioMatorTagFileFormatMOD) {
        TagLib::Mod::File modFile(filePath);
        if (!WritePropertyMapNumberTextToFile(modFile,
                                              BuildTRCKString(trackNumber, totalTracks, padWidth),
                                              nil,
                                              error,
                                              198,
                                              @"Unable to open MOD file for writing track numbers",
                                              199,
                                              @"TagLib failed to save MOD track numbers",
                                              [NSString stringWithFormat:@"MOD '%@'", fileURL.lastPathComponent])) {
            return NO;
        }
    } else if (format == AudioMatorTagFileFormatS3M) {
        TagLib::S3M::File s3mFile(filePath);
        if (!WritePropertyMapNumberTextToFile(s3mFile,
                                              BuildTRCKString(trackNumber, totalTracks, padWidth),
                                              nil,
                                              error,
                                              200,
                                              @"Unable to open S3M file for writing track numbers",
                                              201,
                                              @"TagLib failed to save S3M track numbers",
                                              [NSString stringWithFormat:@"S3M '%@'", fileURL.lastPathComponent])) {
            return NO;
        }
    } else if (format == AudioMatorTagFileFormatIT) {
        TagLib::IT::File itFile(filePath);
        if (!WritePropertyMapNumberTextToFile(itFile,
                                              BuildTRCKString(trackNumber, totalTracks, padWidth),
                                              nil,
                                              error,
                                              202,
                                              @"Unable to open IT file for writing track numbers",
                                              203,
                                              @"TagLib failed to save IT track numbers",
                                              [NSString stringWithFormat:@"IT '%@'", fileURL.lastPathComponent])) {
            return NO;
        }
    } else if (format == AudioMatorTagFileFormatXM) {
        TagLib::XM::File xmFile(filePath);
        if (!WritePropertyMapNumberTextToFile(xmFile,
                                              BuildTRCKString(trackNumber, totalTracks, padWidth),
                                              nil,
                                              error,
                                              204,
                                              @"Unable to open XM file for writing track numbers",
                                              205,
                                              @"TagLib failed to save XM track numbers",
                                              [NSString stringWithFormat:@"XM '%@'", fileURL.lastPathComponent])) {
            return NO;
        }
    } else {
        if (error) {
            *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                         code:41
                                     userInfo:@{ NSLocalizedDescriptionKey : @"Writing track numbers is currently supported for every format that AudioMator can edit metadata for" }];
        }
        return NO;
    }

    TLog(@"Successfully wrote track numbers to '%@' (track=%ld, total=%ld, padWidth=%ld)",
         fileURL.lastPathComponent,
         (long)trackNumber,
         (long)totalTracks,
         (long)padWidth);

    return YES;
    TAGLIB_BRIDGE_CATCH_WITH_ERROR(error, @"Track-number write", NO)
}
