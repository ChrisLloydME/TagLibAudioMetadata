+ (nullable TagLibAudioMetadata *)extractMetadataFromURL:(NSURL *)fileURL
                                                   error:(NSError **)error {
    try {
    NSDictionary<NSString *, NSObject *> *projections = [self metadataProjectionsForURL:fileURL error:error];
    return projections ? (TagLibAudioMetadata *)projections[@"basic"] : nil;
    TAGLIB_BRIDGE_CATCH_WITH_ERROR(error, @"Metadata extraction", nil)
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

static NSString * _Nullable BuildSynchronizedNumberTextPreservingFormatting(
    NSString * _Nullable existingText,
    NSInteger number,
    NSInteger total
)
{
    NSString *trimmedExistingText = TrimmedStringOrNil(existingText);
    NSInteger existingNumber = 0;
    NSInteger existingTotal = 0;
    NSInteger ignoredPadWidth = 0;
    ParseNumberPairFromNSString(
        trimmedExistingText,
        existingNumber,
        existingTotal,
        ignoredPadWidth
    );
    if (existingNumber == number && existingTotal == total) {
        return trimmedExistingText;
    }
    return BuildNumberTextPreservingFormatting(trimmedExistingText, number, total);
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
    if (!ValidateNonnegativeIntValue(trackNumber, @"Track number", error) ||
        !ValidateNonnegativeIntValue(totalTracks, @"Total tracks", error) ||
        !ValidateNonnegativeIntValue(padWidth, @"Track-number padding width", error)) {
        return NO;
    }
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

    TAGLIB_BRIDGE_SERIAL_GUARD();
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
