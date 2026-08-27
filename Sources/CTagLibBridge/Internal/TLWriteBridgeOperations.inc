+ (BOOL)writeMetadata:(TagLibAudioMetadata *)metadata
                toURL:(NSURL *)fileURL
                error:(NSError **)error
{
    try {
    TAGLIB_BRIDGE_SERIAL_GUARD();
    if (metadata.artworkData.length > std::numeric_limits<unsigned int>::max()) {
        if (error) {
            *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                         code:244
                                     userInfo:@{ NSLocalizedDescriptionKey : @"Artwork data exceeds TagLib's supported buffer length" }];
        }
        return NO;
    }
    if (TagLibAtomicMutationDepth == 0) {
        return PerformAtomicTagLibMutation(fileURL, error, @"Metadata write", ^BOOL(NSURL *temporaryURL, NSError **mutationError) {
            return [self writeMetadata:metadata toURL:temporaryURL error:mutationError];
        });
    }
    if (!fileURL || ![fileURL isFileURL]) {
        if (error) {
            *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                         code:10
                                     userInfo:@{ NSLocalizedDescriptionKey : @"Invalid file URL" }];
        }
        return NO;
    }

    NSString *ext = fileURL.pathExtension.lowercaseString;
    AudioMatorTagFileFormat format = DetectTagFileFormat(ext);
    AudioMatorMetadataContainerMask containers = ContainerMaskForFormat(format);
    bool isMPEG = format == AudioMatorTagFileFormatMPEGID3 || format == AudioMatorTagFileFormatMPEGAAC;
    bool isAAC = format == AudioMatorTagFileFormatMPEGAAC;
    bool isMP4Like = format == AudioMatorTagFileFormatMP4;

    if (!IsWritableTagFileFormat(format) || containers == AudioMatorMetadataContainerNone) {
        if (error) {
            *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                         code:11
                                     userInfo:@{ NSLocalizedDescriptionKey : @"Writing metadata is currently supported for every format that AudioMator can edit metadata for" }];
        }
        TLog(@"Write skipped for '%@' (extension '%@' not supported for writing)", fileURL.lastPathComponent, ext);
        return NO;
    }

    // Log the incoming values so we can verify the bridge from Swift is correct
    TLog(@"[WRITE-IN] '%@' title=%@ artist=%@ album=%@ composer=%@ genre=%@ comment=%@ albumArtist=%@ year=%@ track=%ld/%ld disc=%ld/%ld",
         fileURL.lastPathComponent,
         metadata.title ?: @"<nil>",
         metadata.artist ?: @"<nil>",
         metadata.album ?: @"<nil>",
         metadata.composer ?: @"<nil>",
         metadata.genre ?: @"<nil>",
         metadata.comment ?: @"<nil>",
         metadata.albumArtist ?: @"<nil>",
         metadata.year ?: @"<nil>",
         (long)metadata.trackNumber,
         (long)metadata.totalTracks,
         (long)metadata.discNumber,
         (long)metadata.totalDiscs);

    const char *filePath = fileURL.path.UTF8String;
    if (isMPEG) {
        TagLib::MPEG::File mpegFile(filePath);

        if (!mpegFile.isValid()) {
            if (error) {
                *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                             code:12
                                         userInfo:@{ NSLocalizedDescriptionKey : @"Unable to open file for writing metadata" }];
            }
            TLog(@"Failed to open '%@' for writing", fileURL.lastPathComponent);
            return NO;
        }

        if (isAAC) {
            ApplyGenericPropertyMapToFile(mpegFile, metadata);
            if (!ApplyPictureComplexProperties(&mpegFile,
                                               metadata,
                                               error,
                                               68,
                                               @"Unable to clear artwork from AAC metadata",
                                               69,
                                               @"Unable to write artwork into AAC metadata",
                                               [NSString stringWithFormat:@"AAC '%@'", fileURL.lastPathComponent])) {
                return NO;
            }

            if (!mpegFile.save()) {
                if (error) {
                    *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                                 code:14
                                             userInfo:@{ NSLocalizedDescriptionKey : @"TagLib failed to save metadata to AAC file" }];
                }
                TLog(@"TagLib save() failed for AAC '%@'", fileURL.lastPathComponent);
                return NO;
            }
        } else {
            TagLib::Tag *tag = mpegFile.tag();
            if (!tag) {
                if (error) {
                    *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                                 code:13
                                             userInfo:@{ NSLocalizedDescriptionKey : @"No tag found to write metadata into" }];
                }
                TLog(@"No tag object available for '%@'", fileURL.lastPathComponent);
                return NO;
            }

            // --- Basic fields via TagLib::Tag ---
            // nil/empty means clear; callers that need preservation should read-modify-write.
            tag->setTitle(NSStringToTagString(metadata.title));
            tag->setArtist(NSStringToTagString(metadata.artist));
            tag->setAlbum(NSStringToTagString(metadata.album));
            tag->setGenre(NSStringToTagString(metadata.genre));
            tag->setComment(NSStringToTagString(metadata.comment));

            if (metadata.year.length > 0) {
                tag->setYear((unsigned int)metadata.year.integerValue);
            } else {
                tag->setYear(0);
            }

            if (metadata.trackNumber > 0) {
                tag->setTrack((unsigned int)metadata.trackNumber);
            } else {
                tag->setTrack(0);
            }

            // --- ID3v2-specific extended fields ---
            TagLib::ID3v2::Tag *id3v2Tag = mpegFile.ID3v2Tag(true); // create if missing
            if (id3v2Tag) {
                ApplyWritableTextMappingsToID3v2Tag(id3v2Tag, metadata);
                SetID3v2LyricsFrame(id3v2Tag, metadata.lyrics);

                NSString *trackString = BuildNumberTextPreservingFormatting(
                    metadata.trackNumberText,
                    metadata.trackNumber,
                    metadata.totalTracks
                );
                SetID3v2TextFrame(id3v2Tag, "TRCK", trackString);

                NSString *discString = BuildNumberTextPreservingFormatting(
                    metadata.discNumberText,
                    metadata.discNumber,
                    metadata.totalDiscs
                );
                SetID3v2TextFrame(id3v2Tag, "TPOS", discString);

                NSString *releaseDate = metadata.releaseDate.length > 0 ? metadata.releaseDate : metadata.year;
                NSString *id3v2Year = metadata.year.length > 0
                    ? metadata.year
                    : (releaseDate.length >= 4 ? [releaseDate substringToIndex:4] : nil);
                SetID3v2TextFrame(id3v2Tag, "TYER", id3v2Year);

                // Explicit advisory (TXXX:ITUNESADVISORY, 0 = none, 1 = explicit, 2 = clean)
                // Here we treat `explicitContent == YES` as advisory = 1, otherwise 0.
                if (metadata.explicitContent) {
                    SetID3v2UserTextFrame(id3v2Tag, "ITUNESADVISORY", @"1");
                } else {
                    // If you prefer to completely remove the advisory when non-explicit,
                    // you can change @"0" to nil.
                    SetID3v2UserTextFrame(id3v2Tag, "ITUNESADVISORY", @"0");
                }
                ApplyCustomFieldsToID3v2Tag(id3v2Tag, metadata.customFields);

                if (!ApplyPictureComplexProperties(id3v2Tag,
                                                   metadata,
                                                   error,
                                                   68,
                                                   @"Unable to clear artwork from the ID3v2 tag",
                                                   69,
                                                   @"Unable to write artwork into the ID3v2 tag",
                                                   [NSString stringWithFormat:@"MPEG '%@'", fileURL.lastPathComponent])) {
                    return NO;
                }
            }

            // --- Save ---
            if (!mpegFile.save()) {
                if (error) {
                    *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                                 code:14
                                             userInfo:@{ NSLocalizedDescriptionKey : @"TagLib failed to save metadata to file" }];
                }
                TLog(@"TagLib save() failed for '%@'", fileURL.lastPathComponent);
                return NO;
            }
        }
    } else if (isMP4Like) {
        TagLib::MP4::File mp4File(filePath);

        if (!mp4File.isValid()) {
            if (error) {
                *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                             code:15
                                         userInfo:@{ NSLocalizedDescriptionKey : @"Unable to open MP4/M4A file for writing metadata" }];
            }
            TLog(@"Failed to open MP4 '%@' for writing", fileURL.lastPathComponent);
            return NO;
        }

        TagLib::MP4::Tag *tag = mp4File.tag();
        if (!tag) {
            if (error) {
                *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                             code:16
                                         userInfo:@{ NSLocalizedDescriptionKey : @"No MP4 tag found to write metadata into" }];
            }
            TLog(@"No MP4 tag object available for '%@'", fileURL.lastPathComponent);
            return NO;
        }

        // Basic fields: nil/empty means clear; callers that need preservation should read-modify-write.
        tag->setTitle(NSStringToTagString(metadata.title));
        tag->setArtist(NSStringToTagString(metadata.artist));
        tag->setAlbum(NSStringToTagString(metadata.album));
        tag->setGenre(NSStringToTagString(metadata.genre));
        tag->setComment(NSStringToTagString(metadata.comment));

        if (metadata.year.length > 0) {
            tag->setYear((unsigned int)metadata.year.integerValue);
        } else {
            tag->setYear(0);
        }

        if (metadata.trackNumber > 0) {
            tag->setTrack((unsigned int)metadata.trackNumber);
        } else {
            tag->setTrack(0);
        }

        // Extended MP4 items. The schema table above owns the atom/freeform
        // names so new formats and editor UIs can share the same mapping vocabulary.
        ApplyWritableTextMappingsToMP4Tag(tag, metadata);
        SetMP4TextItem(tag, "\xA9" "lyr", metadata.lyrics);

        // Publisher/label convention for MP4 freeform atoms.
        SetMP4TextItem(tag, "----:com.apple.iTunes:ITUNESADVISORY", metadata.explicitContent ? @"1" : @"0");
        SetMP4TextItem(tag, kAudioMatorMP4TrackNumberTextKey, metadata.trackNumberText);
        SetMP4TextItem(tag, kAudioMatorMP4DiscNumberTextKey, metadata.discNumberText);

        SetMP4IntPairItem(tag, "trkn", metadata.trackNumber, metadata.totalTracks);
        SetMP4IntPairItem(tag, "disk", metadata.discNumber, metadata.totalDiscs);
        if (metadata.bpm > 0) {
            tag->setItem("tmpo", TagLib::MP4::Item((int)metadata.bpm));
        } else {
            tag->removeItem("tmpo");
        }
        if (metadata.compilation) {
            tag->setItem("cpil", TagLib::MP4::Item(true));
        } else {
            tag->removeItem("cpil");
        }

        // iTunes-style explicit rating: 4 = explicit. Remove atom when not explicit.
        if (metadata.explicitContent) {
            tag->setItem("rtng", TagLib::MP4::Item(4));
        } else {
            tag->removeItem("rtng");
        }
        ApplyCustomFieldsToMP4Tag(tag, metadata.customFields);

        if (!ApplyPictureComplexProperties(tag,
                                           metadata,
                                           error,
                                           70,
                                           @"Unable to clear artwork from the MP4 tag",
                                           71,
                                           @"Unable to write artwork into the MP4 tag",
                                           [NSString stringWithFormat:@"MP4 '%@'", fileURL.lastPathComponent])) {
            return NO;
        }

        if (!mp4File.save()) {
            if (error) {
                *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                             code:17
                                         userInfo:@{ NSLocalizedDescriptionKey : @"TagLib failed to save metadata to MP4/M4A file" }];
            }
            TLog(@"TagLib save() failed for MP4 '%@'", fileURL.lastPathComponent);
            return NO;
        }
    } else if (format == AudioMatorTagFileFormatFLAC) {
        TagLib::FLAC::File flacFile(filePath);

        if (!flacFile.isValid()) {
            if (error) {
                *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                             code:18
                                         userInfo:@{ NSLocalizedDescriptionKey : @"Unable to open FLAC file for writing metadata" }];
            }
            TLog(@"Failed to open FLAC '%@' for writing", fileURL.lastPathComponent);
            return NO;
        }

        ApplyGenericPropertyMapToFile(flacFile, metadata);
        if (!ApplyPictureComplexProperties(&flacFile,
                                           metadata,
                                           error,
                                           72,
                                           @"Unable to clear artwork from the FLAC metadata blocks",
                                           73,
                                           @"Unable to write artwork into the FLAC metadata blocks",
                                           [NSString stringWithFormat:@"FLAC '%@'", fileURL.lastPathComponent])) {
            return NO;
        }

        if (!flacFile.save()) {
            if (error) {
                *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                             code:19
                                         userInfo:@{ NSLocalizedDescriptionKey : @"TagLib failed to save metadata to FLAC file" }];
            }
            TLog(@"TagLib save() failed for FLAC '%@'", fileURL.lastPathComponent);
            return NO;
        }
    } else if (format == AudioMatorTagFileFormatOggVorbis) {
        TagLib::Ogg::Vorbis::File vorbisFile(filePath);

        if (!vorbisFile.isValid()) {
            if (error) {
                *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                             code:118
                                         userInfo:@{ NSLocalizedDescriptionKey : @"Unable to open Ogg Vorbis file for writing metadata" }];
            }
            TLog(@"Failed to open Ogg Vorbis '%@' for writing", fileURL.lastPathComponent);
            return NO;
        }

        ApplyGenericPropertyMapToFile(vorbisFile, metadata);
        if (!ApplyPictureComplexProperties(vorbisFile.tag(),
                                           metadata,
                                           error,
                                           120,
                                           @"Unable to clear artwork from the Ogg Vorbis comments",
                                           121,
                                           @"Unable to write artwork into the Ogg Vorbis comments",
                                           [NSString stringWithFormat:@"Ogg Vorbis '%@'", fileURL.lastPathComponent])) {
            return NO;
        }

        if (!vorbisFile.save()) {
            if (error) {
                *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                             code:119
                                         userInfo:@{ NSLocalizedDescriptionKey : @"TagLib failed to save metadata to Ogg Vorbis file" }];
            }
            TLog(@"TagLib save() failed for Ogg Vorbis '%@'", fileURL.lastPathComponent);
            return NO;
        }
    } else if (format == AudioMatorTagFileFormatOggOpus) {
        TagLib::Ogg::Opus::File opusFile(filePath);

        if (!opusFile.isValid()) {
            if (error) {
                *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                             code:122
                                         userInfo:@{ NSLocalizedDescriptionKey : @"Unable to open Opus file for writing metadata" }];
            }
            TLog(@"Failed to open Opus '%@' for writing", fileURL.lastPathComponent);
            return NO;
        }

        ApplyGenericPropertyMapToFile(opusFile, metadata);
        if (!ApplyPictureComplexProperties(opusFile.tag(),
                                           metadata,
                                           error,
                                           124,
                                           @"Unable to clear artwork from the Opus comments",
                                           125,
                                           @"Unable to write artwork into the Opus comments",
                                           [NSString stringWithFormat:@"Opus '%@'", fileURL.lastPathComponent])) {
            return NO;
        }

        if (!opusFile.save()) {
            if (error) {
                *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                             code:123
                                         userInfo:@{ NSLocalizedDescriptionKey : @"TagLib failed to save metadata to Opus file" }];
            }
            TLog(@"TagLib save() failed for Opus '%@'", fileURL.lastPathComponent);
            return NO;
        }
    } else if (format == AudioMatorTagFileFormatOggFlac) {
        TagLib::Ogg::FLAC::File oggFlacFile(filePath);

        if (!oggFlacFile.isValid()) {
            if (error) {
                *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                             code:126
                                         userInfo:@{ NSLocalizedDescriptionKey : @"Unable to open Ogg FLAC file for writing metadata" }];
            }
            TLog(@"Failed to open Ogg FLAC '%@' for writing", fileURL.lastPathComponent);
            return NO;
        }

        ApplyGenericPropertyMapToFile(oggFlacFile, metadata);
        if (!ApplyPictureComplexProperties(oggFlacFile.tag(),
                                           metadata,
                                           error,
                                           128,
                                           @"Unable to clear artwork from the Ogg FLAC comments",
                                           129,
                                           @"Unable to write artwork into the Ogg FLAC comments",
                                           [NSString stringWithFormat:@"Ogg FLAC '%@'", fileURL.lastPathComponent])) {
            return NO;
        }

        if (!oggFlacFile.save()) {
            if (error) {
                *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                             code:127
                                         userInfo:@{ NSLocalizedDescriptionKey : @"TagLib failed to save metadata to Ogg FLAC file" }];
            }
            TLog(@"TagLib save() failed for Ogg FLAC '%@'", fileURL.lastPathComponent);
            return NO;
        }
    } else if (format == AudioMatorTagFileFormatOggSpeex) {
        TagLib::Ogg::Speex::File speexFile(filePath);

        if (!speexFile.isValid()) {
            if (error) {
                *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                             code:130
                                         userInfo:@{ NSLocalizedDescriptionKey : @"Unable to open Speex file for writing metadata" }];
            }
            TLog(@"Failed to open Speex '%@' for writing", fileURL.lastPathComponent);
            return NO;
        }

        ApplyGenericPropertyMapToFile(speexFile, metadata);
        if (!ApplyPictureComplexProperties(speexFile.tag(),
                                           metadata,
                                           error,
                                           132,
                                           @"Unable to clear artwork from the Speex comments",
                                           133,
                                           @"Unable to write artwork into the Speex comments",
                                           [NSString stringWithFormat:@"Speex '%@'", fileURL.lastPathComponent])) {
            return NO;
        }

        if (!speexFile.save()) {
            if (error) {
                *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                             code:131
                                         userInfo:@{ NSLocalizedDescriptionKey : @"TagLib failed to save metadata to Speex file" }];
            }
            TLog(@"TagLib save() failed for Speex '%@'", fileURL.lastPathComponent);
            return NO;
        }
    } else if (format == AudioMatorTagFileFormatAPE) {
        TagLib::APE::File apeFile(filePath);

        if (!apeFile.isValid()) {
            if (error) {
                *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                             code:134
                                         userInfo:@{ NSLocalizedDescriptionKey : @"Unable to open APE file for writing metadata" }];
            }
            TLog(@"Failed to open APE '%@' for writing", fileURL.lastPathComponent);
            return NO;
        }

        ApplyGenericPropertyMapToFile(apeFile, metadata);
        if (!ApplyPictureComplexProperties(apeFile.APETag(true),
                                           metadata,
                                           error,
                                           136,
                                           @"Unable to clear artwork from the APE tag",
                                           137,
                                           @"Unable to write artwork into the APE tag",
                                           [NSString stringWithFormat:@"APE '%@'", fileURL.lastPathComponent])) {
            return NO;
        }

        if (!apeFile.save()) {
            if (error) {
                *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                             code:135
                                         userInfo:@{ NSLocalizedDescriptionKey : @"TagLib failed to save metadata to APE file" }];
            }
            TLog(@"TagLib save() failed for APE '%@'", fileURL.lastPathComponent);
            return NO;
        }
    } else if (format == AudioMatorTagFileFormatWavPack) {
        TagLib::WavPack::File wavPackFile(filePath);

        if (!wavPackFile.isValid()) {
            if (error) {
                *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                             code:138
                                         userInfo:@{ NSLocalizedDescriptionKey : @"Unable to open WavPack file for writing metadata" }];
            }
            TLog(@"Failed to open WavPack '%@' for writing", fileURL.lastPathComponent);
            return NO;
        }

        ApplyGenericPropertyMapToFile(wavPackFile, metadata);
        if (!ApplyPictureComplexProperties(wavPackFile.APETag(true),
                                           metadata,
                                           error,
                                           140,
                                           @"Unable to clear artwork from the WavPack tag",
                                           141,
                                           @"Unable to write artwork into the WavPack tag",
                                           [NSString stringWithFormat:@"WavPack '%@'", fileURL.lastPathComponent])) {
            return NO;
        }

        if (!wavPackFile.save()) {
            if (error) {
                *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                             code:139
                                         userInfo:@{ NSLocalizedDescriptionKey : @"TagLib failed to save metadata to WavPack file" }];
            }
            TLog(@"TagLib save() failed for WavPack '%@'", fileURL.lastPathComponent);
            return NO;
        }
    } else if (format == AudioMatorTagFileFormatMPC) {
        TagLib::MPC::File mpcFile(filePath);

        if (!mpcFile.isValid()) {
            if (error) {
                *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                             code:142
                                         userInfo:@{ NSLocalizedDescriptionKey : @"Unable to open Musepack file for writing metadata" }];
            }
            TLog(@"Failed to open Musepack '%@' for writing", fileURL.lastPathComponent);
            return NO;
        }

        ApplyGenericPropertyMapToFile(mpcFile, metadata);
        if (!ApplyPictureComplexProperties(mpcFile.APETag(true),
                                           metadata,
                                           error,
                                           144,
                                           @"Unable to clear artwork from the Musepack tag",
                                           145,
                                           @"Unable to write artwork into the Musepack tag",
                                           [NSString stringWithFormat:@"Musepack '%@'", fileURL.lastPathComponent])) {
            return NO;
        }

        if (!mpcFile.save()) {
            if (error) {
                *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                             code:143
                                         userInfo:@{ NSLocalizedDescriptionKey : @"TagLib failed to save metadata to Musepack file" }];
            }
            TLog(@"TagLib save() failed for Musepack '%@'", fileURL.lastPathComponent);
            return NO;
        }
    } else if (format == AudioMatorTagFileFormatWAV) {
        TagLib::RIFF::WAV::File wavFile(filePath);

        if (!wavFile.isValid()) {
            if (error) {
                *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                             code:20
                                         userInfo:@{ NSLocalizedDescriptionKey : @"Unable to open WAV file for writing metadata" }];
            }
            TLog(@"Failed to open WAV '%@' for writing", fileURL.lastPathComponent);
            return NO;
        }

        ApplyGenericPropertyMapToFile(wavFile, metadata);
        if (!ApplyPictureComplexProperties(wavFile.ID3v2Tag(),
                                           metadata,
                                           error,
                                           146,
                                           @"Unable to clear artwork from the WAV ID3v2 tag",
                                           147,
                                           @"Unable to write artwork into the WAV ID3v2 tag",
                                           [NSString stringWithFormat:@"WAV '%@'", fileURL.lastPathComponent])) {
            return NO;
        }

        if (!wavFile.save(TagLib::RIFF::WAV::File::ID3v2, TagLib::File::StripNone)) {
            if (error) {
                *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                             code:21
                                         userInfo:@{ NSLocalizedDescriptionKey : @"TagLib failed to save metadata to WAV file" }];
            }
            TLog(@"TagLib save() failed for WAV '%@'", fileURL.lastPathComponent);
            return NO;
        }
    } else if (format == AudioMatorTagFileFormatAIFF) {
        TagLib::RIFF::AIFF::File aiffFile(filePath);

        if (!aiffFile.isValid()) {
            if (error) {
                *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                             code:22
                                         userInfo:@{ NSLocalizedDescriptionKey : @"Unable to open AIFF file for writing metadata" }];
            }
            TLog(@"Failed to open AIFF '%@' for writing", fileURL.lastPathComponent);
            return NO;
        }

        ApplyGenericPropertyMapToFile(aiffFile, metadata);
        if (!ApplyPictureComplexProperties(aiffFile.tag(),
                                           metadata,
                                           error,
                                           148,
                                           @"Unable to clear artwork from the AIFF ID3v2 tag",
                                           149,
                                           @"Unable to write artwork into the AIFF ID3v2 tag",
                                           [NSString stringWithFormat:@"AIFF '%@'", fileURL.lastPathComponent])) {
            return NO;
        }

        if (!aiffFile.save()) {
            if (error) {
                *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                             code:23
                                         userInfo:@{ NSLocalizedDescriptionKey : @"TagLib failed to save metadata to AIFF file" }];
            }
            TLog(@"TagLib save() failed for AIFF '%@'", fileURL.lastPathComponent);
            return NO;
        }
    } else if (format == AudioMatorTagFileFormatTTA) {
        TagLib::TrueAudio::File ttaFile(filePath);

        if (!ttaFile.isValid()) {
            if (error) {
                *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                             code:150
                                         userInfo:@{ NSLocalizedDescriptionKey : @"Unable to open TrueAudio file for writing metadata" }];
            }
            TLog(@"Failed to open TrueAudio '%@' for writing", fileURL.lastPathComponent);
            return NO;
        }

        ApplyGenericPropertyMapToFile(ttaFile, metadata);
        if (!ApplyPictureComplexProperties(ttaFile.ID3v2Tag(true),
                                           metadata,
                                           error,
                                           152,
                                           @"Unable to clear artwork from the TrueAudio ID3v2 tag",
                                           153,
                                           @"Unable to write artwork into the TrueAudio ID3v2 tag",
                                           [NSString stringWithFormat:@"TrueAudio '%@'", fileURL.lastPathComponent])) {
            return NO;
        }

        if (!ttaFile.save()) {
            if (error) {
                *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                             code:151
                                         userInfo:@{ NSLocalizedDescriptionKey : @"TagLib failed to save metadata to TrueAudio file" }];
            }
            TLog(@"TagLib save() failed for TrueAudio '%@'", fileURL.lastPathComponent);
            return NO;
        }
    } else if (format == AudioMatorTagFileFormatASF) {
        TagLib::ASF::File asfFile(filePath);

        if (!asfFile.isValid()) {
            if (error) {
                *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                             code:154
                                         userInfo:@{ NSLocalizedDescriptionKey : @"Unable to open ASF/WMA file for writing metadata" }];
            }
            TLog(@"Failed to open ASF/WMA '%@' for writing", fileURL.lastPathComponent);
            return NO;
        }

        ApplyGenericPropertyMapToFile(asfFile, metadata);
        if (!ApplyPictureComplexProperties(asfFile.tag(),
                                           metadata,
                                           error,
                                           156,
                                           @"Unable to clear artwork from the ASF/WMA tag",
                                           157,
                                           @"Unable to write artwork into the ASF/WMA tag",
                                           [NSString stringWithFormat:@"ASF/WMA '%@'", fileURL.lastPathComponent])) {
            return NO;
        }

        if (!asfFile.save()) {
            if (error) {
                *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                             code:155
                                         userInfo:@{ NSLocalizedDescriptionKey : @"TagLib failed to save metadata to ASF/WMA file" }];
            }
            TLog(@"TagLib save() failed for ASF/WMA '%@'", fileURL.lastPathComponent);
            return NO;
        }
    } else if (format == AudioMatorTagFileFormatDSF) {
        TagLib::DSF::File dsfFile(filePath);

        if (!dsfFile.isValid()) {
            if (error) {
                *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                             code:158
                                         userInfo:@{ NSLocalizedDescriptionKey : @"Unable to open DSF file for writing metadata" }];
            }
            TLog(@"Failed to open DSF '%@' for writing", fileURL.lastPathComponent);
            return NO;
        }

        ApplyGenericPropertyMapToFile(dsfFile, metadata);
        if (!ApplyPictureComplexProperties(dsfFile.tag(),
                                           metadata,
                                           error,
                                           160,
                                           @"Unable to clear artwork from the DSF ID3v2 tag",
                                           161,
                                           @"Unable to write artwork into the DSF ID3v2 tag",
                                           [NSString stringWithFormat:@"DSF '%@'", fileURL.lastPathComponent])) {
            return NO;
        }

        if (!dsfFile.save()) {
            if (error) {
                *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                             code:159
                                         userInfo:@{ NSLocalizedDescriptionKey : @"TagLib failed to save metadata to DSF file" }];
            }
            TLog(@"TagLib save() failed for DSF '%@'", fileURL.lastPathComponent);
            return NO;
        }
    } else if (format == AudioMatorTagFileFormatDSDIFF) {
        TagLib::DSDIFF::File dsdiffFile(filePath);

        if (!dsdiffFile.isValid()) {
            if (error) {
                *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                             code:162
                                         userInfo:@{ NSLocalizedDescriptionKey : @"Unable to open DSDIFF file for writing metadata" }];
            }
            TLog(@"Failed to open DSDIFF '%@' for writing", fileURL.lastPathComponent);
            return NO;
        }

        ApplyGenericPropertyMapToFile(dsdiffFile, metadata);
        if (!ApplyPictureComplexProperties(dsdiffFile.ID3v2Tag(true),
                                           metadata,
                                           error,
                                           164,
                                           @"Unable to clear artwork from the DSDIFF ID3v2 tag",
                                           165,
                                           @"Unable to write artwork into the DSDIFF ID3v2 tag",
                                           [NSString stringWithFormat:@"DSDIFF '%@'", fileURL.lastPathComponent])) {
            return NO;
        }

        if (!dsdiffFile.save()) {
            if (error) {
                *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                             code:163
                                         userInfo:@{ NSLocalizedDescriptionKey : @"TagLib failed to save metadata to DSDIFF file" }];
            }
            TLog(@"TagLib save() failed for DSDIFF '%@'", fileURL.lastPathComponent);
            return NO;
        }
    } else if (format == AudioMatorTagFileFormatMOD) {
        return WriteGenericPropertyMapOnlyFile<TagLib::Mod::File>(
            filePath, metadata, error,
            222, @"Unable to open MOD file for writing metadata",
            223, @"TagLib failed to save metadata to MOD file",
            [NSString stringWithFormat:@"MOD '%@'", fileURL.lastPathComponent]
        );
    } else if (format == AudioMatorTagFileFormatS3M) {
        return WriteGenericPropertyMapOnlyFile<TagLib::S3M::File>(
            filePath, metadata, error,
            224, @"Unable to open S3M file for writing metadata",
            225, @"TagLib failed to save metadata to S3M file",
            [NSString stringWithFormat:@"S3M '%@'", fileURL.lastPathComponent]
        );
    } else if (format == AudioMatorTagFileFormatIT) {
        return WriteGenericPropertyMapOnlyFile<TagLib::IT::File>(
            filePath, metadata, error,
            226, @"Unable to open IT file for writing metadata",
            227, @"TagLib failed to save metadata to IT file",
            [NSString stringWithFormat:@"IT '%@'", fileURL.lastPathComponent]
        );
    } else if (format == AudioMatorTagFileFormatXM) {
        return WriteGenericPropertyMapOnlyFile<TagLib::XM::File>(
            filePath, metadata, error,
            228, @"Unable to open XM file for writing metadata",
            229, @"TagLib failed to save metadata to XM file",
            [NSString stringWithFormat:@"XM '%@'", fileURL.lastPathComponent]
        );
    } else {
        if (error) {
            *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                         code:11
                                     userInfo:@{ NSLocalizedDescriptionKey : @"Writing metadata is currently supported for every format that AudioMator can edit metadata for" }];
        }
        return NO;
    }



    TLog(@"Successfully wrote metadata to '%@'", fileURL.lastPathComponent);
    return YES;
    TAGLIB_BRIDGE_CATCH_WITH_ERROR(error, @"Metadata write", NO)
}

// Wipe (remove) native metadata containers from a file.
+ (BOOL)wipeMetadataFromURL:(NSURL *)fileURL
                      error:(NSError **)error
{
    try {
    TAGLIB_BRIDGE_SERIAL_GUARD();
    if (TagLibAtomicMutationDepth == 0) {
        return PerformAtomicTagLibMutation(fileURL, error, @"Metadata wipe", ^BOOL(NSURL *temporaryURL, NSError **mutationError) {
            return [self wipeMetadataFromURL:temporaryURL error:mutationError];
        });
    }
    if (!fileURL || ![fileURL isFileURL]) {
        if (error) {
            *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                         code:30
                                     userInfo:@{ NSLocalizedDescriptionKey : @"Invalid file URL" }];
        }
        return NO;
    }

    const char *filePath = fileURL.path.UTF8String;
    if (!filePath) {
        if (error) {
            *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                         code:31
                                     userInfo:@{ NSLocalizedDescriptionKey : @"Invalid file path" }];
        }
        return NO;
    }

    NSString *ext = fileURL.pathExtension.lowercaseString;
    AudioMatorTagFileFormat format = DetectTagFileFormat(ext);

    // Metadata wipe has a full implementation for MP3, where we can strip all supported tag types.
    if (format == AudioMatorTagFileFormatMPEGID3) {
        TagLib::MPEG::File mpegFile(filePath);
        if (!mpegFile.isValid()) {
            if (error) {
                *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                             code:33
                                         userInfo:@{ NSLocalizedDescriptionKey : @"Unable to open file for wiping metadata" }];
            }
            TLog(@"Failed to open '%@' for wiping", fileURL.lastPathComponent);
            return NO;
        }

        // Remove all tag containers that TagLib can strip from MPEG files.
        // This typically removes ID3v1, ID3v2 and APE tags.
        mpegFile.strip(TagLib::MPEG::File::AllTags, true);

        if (!mpegFile.save()) {
            if (error) {
                *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                             code:34
                                         userInfo:@{ NSLocalizedDescriptionKey : @"TagLib failed to save after wiping metadata" }];
            }
            TLog(@"TagLib save() failed after wiping for '%@'", fileURL.lastPathComponent);
            return NO;
        }

        TLog(@"Successfully wiped metadata for '%@'", fileURL.lastPathComponent);
        return YES;
    }

    if (format == AudioMatorTagFileFormatMP4) {
        TagLib::MP4::File mp4File(filePath);
        if (!mp4File.isValid()) {
            if (error) {
                *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                             code:35
                                         userInfo:@{ NSLocalizedDescriptionKey : @"Unable to open MP4/M4A file for wiping metadata" }];
            }
            TLog(@"Failed to open MP4 '%@' for wiping", fileURL.lastPathComponent);
            return NO;
        }

        if (!mp4File.strip(TagLib::MP4::File::MP4)) {
            if (error) {
                *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                             code:36
                                         userInfo:@{ NSLocalizedDescriptionKey : @"TagLib failed to strip MP4/M4A metadata" }];
            }
            TLog(@"TagLib strip() failed while wiping MP4 '%@'", fileURL.lastPathComponent);
            return NO;
        }

        TLog(@"Successfully wiped metadata for MP4 '%@'", fileURL.lastPathComponent);
        return YES;
    }

    if (format == AudioMatorTagFileFormatFLAC) {
        TagLib::FLAC::File flacFile(filePath);
        return StripAllTagsAndSave(flacFile,
                                   error,
                                   37,
                                   @"Unable to open FLAC file for wiping metadata",
                                   38,
                                   @"TagLib failed to save FLAC after wiping metadata",
                                   [NSString stringWithFormat:@"FLAC '%@'", fileURL.lastPathComponent]);
    }

    if (format == AudioMatorTagFileFormatAPE) {
        TagLib::APE::File apeFile(filePath);
        return StripAllTagsAndSave(apeFile,
                                   error,
                                   39,
                                   @"Unable to open APE file for wiping metadata",
                                   72,
                                   @"TagLib failed to save APE after wiping metadata",
                                   [NSString stringWithFormat:@"APE '%@'", fileURL.lastPathComponent]);
    }

    if (format == AudioMatorTagFileFormatWavPack) {
        TagLib::WavPack::File wavPackFile(filePath);
        return StripAllTagsAndSave(wavPackFile,
                                   error,
                                   73,
                                   @"Unable to open WavPack file for wiping metadata",
                                   118,
                                   @"TagLib failed to save WavPack after wiping metadata",
                                   [NSString stringWithFormat:@"WavPack '%@'", fileURL.lastPathComponent]);
    }

    if (format == AudioMatorTagFileFormatMPC) {
        TagLib::MPC::File mpcFile(filePath);
        return StripAllTagsAndSave(mpcFile,
                                   error,
                                   119,
                                   @"Unable to open Musepack file for wiping metadata",
                                   120,
                                   @"TagLib failed to save Musepack after wiping metadata",
                                   [NSString stringWithFormat:@"Musepack '%@'", fileURL.lastPathComponent]);
    }

    if (format == AudioMatorTagFileFormatWAV) {
        TagLib::RIFF::WAV::File wavFile(filePath);
        return StripAllTagsAndSave(wavFile,
                                   error,
                                   121,
                                   @"Unable to open WAV file for wiping metadata",
                                   122,
                                   @"TagLib failed to save WAV after wiping metadata",
                                   [NSString stringWithFormat:@"WAV '%@'", fileURL.lastPathComponent]);
    }

    if (format == AudioMatorTagFileFormatTTA) {
        TagLib::TrueAudio::File ttaFile(filePath);
        return StripAllTagsAndSave(ttaFile,
                                   error,
                                   123,
                                   @"Unable to open TrueAudio file for wiping metadata",
                                   124,
                                   @"TagLib failed to save TrueAudio after wiping metadata",
                                   [NSString stringWithFormat:@"TrueAudio '%@'", fileURL.lastPathComponent]);
    }

    if (format == AudioMatorTagFileFormatDSDIFF) {
        TagLib::DSDIFF::File dsdiffFile(filePath);
        return StripAllTagsAndSave(dsdiffFile,
                                   error,
                                   125,
                                   @"Unable to open DSDIFF file for wiping metadata",
                                   126,
                                   @"TagLib failed to save DSDIFF after wiping metadata",
                                   [NSString stringWithFormat:@"DSDIFF '%@'", fileURL.lastPathComponent]);
    }

    if (error) {
        NSString *message = @"Wiping metadata is not implemented for this format; clear uses the generic property-map path instead";
        *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                     code:32
                                 userInfo:@{ NSLocalizedDescriptionKey : message }];
    }
    TLog(@"Wipe skipped for '%@' (extension '%@' not supported)", fileURL.lastPathComponent, ext);
    return NO;
    TAGLIB_BRIDGE_CATCH_WITH_ERROR(error, @"Metadata wipe", NO)
}

#pragma mark - Raw Metadata Dump (GUI feature)

// Helpers for building a stable, user-facing dump.
