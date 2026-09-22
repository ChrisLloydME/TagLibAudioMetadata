+ (nullable NSDictionary<NSString *, NSObject *> *)rawMetadataForURL:(NSURL *)fileURL
                                                              error:(NSError *_Nullable *_Nullable)error
{
    try {
    NSDictionary<NSString *, NSObject *> *projections = [self metadataProjectionsForURL:fileURL error:error];
    return projections ? (NSDictionary<NSString *, NSObject *> *)projections[@"raw"] : nil;
    TAGLIB_BRIDGE_CATCH_WITH_ERROR(error, @"Raw metadata extraction", nil)
}

+ (nullable NSString *)dumpMetadataTextFromURL:(NSURL *)fileURL
                                       error:(NSError **)error
{
    try {
    TAGLIB_BRIDGE_SERIAL_GUARD();
    if (!fileURL || !fileURL.isFileURL) {
        if (error) {
            *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                         code:20
                                     userInfo:@{ NSLocalizedDescriptionKey: @"Invalid file URL" }];
        }
        return nil;
    }

    const char *filePath = fileURL.path.UTF8String;
    if (!filePath) {
        if (error) {
            *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                         code:21
                                     userInfo:@{ NSLocalizedDescriptionKey: @"Invalid file path" }];
        }
        return nil;
    }

    NSMutableString *out = [NSMutableString string];
    AppendLine(out, [NSString stringWithFormat:@"File: %@", NonNil(fileURL.lastPathComponent)]);
    AppendLine(out, [NSString stringWithFormat:@"Path: %@", NonNil(fileURL.path)]);

    NSString *ext = fileURL.pathExtension.lowercaseString;
    TLTagFileFormat format = DetectTagFileFormat(fileURL);
    TagLib::FileRef fileRef(filePath);

    // 1) Unified properties (as TagLib sees them)
    AppendSectionHeader(out, @"[TagLib Properties]");

    bool anyProperties = false;

    if (format == TLTagFileFormatMPEGID3 || format == TLTagFileFormatMPEGAAC) {
        TagLib::MPEG::File f(filePath);
        if (f.isValid()) {
            TagLib::PropertyMap pm = f.properties();
            anyProperties = !pm.isEmpty();
            AppendPropertyMap(out, pm);
        } else {
            AppendLine(out, @"(unable to open as MPEG)");
        }
    } else if (format == TLTagFileFormatMP4) {
        TagLib::MP4::File f(filePath);
        if (f.isValid()) {
            TagLib::PropertyMap pm = f.properties();
            anyProperties = !pm.isEmpty();
            AppendPropertyMap(out, pm);
        } else {
            AppendLine(out, @"(unable to open as MP4)");
        }
    } else if (format == TLTagFileFormatOggVorbis) {
        TagLib::Ogg::Vorbis::File f(filePath);
        if (f.isValid()) {
            TagLib::PropertyMap pm = f.properties();
            anyProperties = !pm.isEmpty();
            AppendPropertyMap(out, pm);
        } else {
            AppendLine(out, @"(unable to open as Ogg Vorbis)");
        }
    } else if (format == TLTagFileFormatOggOpus) {
        TagLib::Ogg::Opus::File f(filePath);
        if (f.isValid()) {
            TagLib::PropertyMap pm = f.properties();
            anyProperties = !pm.isEmpty();
            AppendPropertyMap(out, pm);
        } else {
            AppendLine(out, @"(unable to open as Ogg Opus)");
        }
    } else if (format == TLTagFileFormatOggFlac) {
        TagLib::Ogg::FLAC::File f(filePath);
        if (f.isValid()) {
            TagLib::PropertyMap pm = f.properties();
            anyProperties = !pm.isEmpty();
            AppendPropertyMap(out, pm);
        } else {
            AppendLine(out, @"(unable to open as Ogg FLAC)");
        }
    } else if (format == TLTagFileFormatOggSpeex) {
        TagLib::Ogg::Speex::File f(filePath);
        if (f.isValid()) {
            TagLib::PropertyMap pm = f.properties();
            anyProperties = !pm.isEmpty();
            AppendPropertyMap(out, pm);
        } else {
            AppendLine(out, @"(unable to open as Ogg Speex)");
        }
    } else if (format == TLTagFileFormatShorten) {
        TagLib::Shorten::File f(filePath);
        if (f.isValid()) {
            TagLib::PropertyMap pm = f.properties();
            anyProperties = !pm.isEmpty();
            AppendPropertyMap(out, pm);
        } else {
            AppendLine(out, @"(unable to open as Shorten)");
        }
    } else if (format == TLTagFileFormatMOD) {
        TagLib::Mod::File f(filePath);
        if (f.isValid()) {
            TagLib::PropertyMap pm = f.properties();
            anyProperties = !pm.isEmpty();
            AppendPropertyMap(out, pm);
        } else {
            AppendLine(out, @"(unable to open as MOD)");
        }
    } else if (format == TLTagFileFormatS3M) {
        TagLib::S3M::File f(filePath);
        if (f.isValid()) {
            TagLib::PropertyMap pm = f.properties();
            anyProperties = !pm.isEmpty();
            AppendPropertyMap(out, pm);
        } else {
            AppendLine(out, @"(unable to open as S3M)");
        }
    } else if (format == TLTagFileFormatIT) {
        TagLib::IT::File f(filePath);
        if (f.isValid()) {
            TagLib::PropertyMap pm = f.properties();
            anyProperties = !pm.isEmpty();
            AppendPropertyMap(out, pm);
        } else {
            AppendLine(out, @"(unable to open as IT)");
        }
    } else if (format == TLTagFileFormatXM) {
        TagLib::XM::File f(filePath);
        if (f.isValid()) {
            TagLib::PropertyMap pm = f.properties();
            anyProperties = !pm.isEmpty();
            AppendPropertyMap(out, pm);
        } else {
            AppendLine(out, @"(unable to open as XM)");
        }
    } else {
        if (!fileRef.isNull() && fileRef.file()) {
            TagLib::PropertyMap pm = VisibleMetadataProperties(fileRef.file());
            anyProperties = !pm.isEmpty();
            AppendPropertyMap(out, pm);
        } else {
            AppendLine(out, @"(unable to open)");
        }
    }

    // 2) Format-specific raw structures (these are what helps with "same field, different names")

    if (format == TLTagFileFormatMPEGID3) {
        TagLib::MPEG::File f(filePath);
        if (f.isValid()) {
            AppendID3v2FramesSection(out, f.hasID3v2Tag() ? f.ID3v2Tag() : nullptr, @"[ID3v2 Frames]");
            AppendAPEItemsSection(out, f.hasAPETag() ? f.APETag() : nullptr, @"[APE Items]");
            AppendSimpleTagSection(out, @"[ID3v1 Tag]", f.hasID3v1Tag() ? f.ID3v1Tag() : nullptr);
        } else {
            AppendID3v2FramesSection(out, nullptr, @"[ID3v2 Frames]");
            AppendAPEItemsSection(out, nullptr, @"[APE Items]");
            AppendSimpleTagSection(out, @"[ID3v1 Tag]", nullptr);
        }
    }

    if (format == TLTagFileFormatMP4) {
        AppendSectionHeader(out, @"[MP4 ItemMap]");

        TagLib::MP4::File f(filePath);
        if (f.isValid() && f.tag()) {
            const TagLib::MP4::ItemMap &items = f.tag()->itemMap();
            if (items.isEmpty()) {
                AppendLine(out, @"(none)");
            } else {
                bool appendedAnyItem = false;
                for (auto it = items.begin(); it != items.end(); ++it) {
                    NSString *k = TagStringToNSString(it->first) ?: @"";
                    if (IsHiddenInternalMetadataFieldKey(k)) {
                        continue;
                    }
                    NSString *v = MP4ItemToDisplayString(it->second);
                    AppendLine(out, [NSString stringWithFormat:@"%@ = %@", k, v]);
                    appendedAnyItem = true;
                }
                if (!appendedAnyItem) {
                    AppendLine(out, @"(none)");
                }
            }
        } else {
            AppendLine(out, @"(unable to read MP4 tag)");
        }
    }

    if (format == TLTagFileFormatFLAC) {
        TagLib::FLAC::File f(filePath);
        if (f.isValid()) {
            AppendXiphCommentSection(out, f.hasXiphComment() ? f.xiphComment() : nullptr, @"[Xiph Comment]");
            AppendID3v2FramesSection(out, f.hasID3v2Tag() ? f.ID3v2Tag() : nullptr, @"[ID3v2 Frames]");
            AppendSimpleTagSection(out, @"[ID3v1 Tag]", f.hasID3v1Tag() ? f.ID3v1Tag() : nullptr);
        } else {
            AppendXiphCommentSection(out, nullptr, @"[Xiph Comment]");
            AppendID3v2FramesSection(out, nullptr, @"[ID3v2 Frames]");
            AppendSimpleTagSection(out, @"[ID3v1 Tag]", nullptr);
        }
    }

    if (format == TLTagFileFormatOggVorbis) {
        TagLib::Ogg::Vorbis::File f(filePath);
        AppendXiphCommentSection(out, f.isValid() ? f.tag() : nullptr, @"[Xiph Comment]");
    }

    if (format == TLTagFileFormatOggFlac) {
        TagLib::Ogg::FLAC::File f(filePath);
        AppendXiphCommentSection(out, f.isValid() ? f.tag() : nullptr, @"[Xiph Comment]");
    }

    if (format == TLTagFileFormatOggOpus) {
        TagLib::Ogg::Opus::File f(filePath);
        AppendXiphCommentSection(out, f.isValid() ? f.tag() : nullptr, @"[Xiph Comment]");
    }

    if (format == TLTagFileFormatOggSpeex) {
        TagLib::Ogg::Speex::File f(filePath);
        AppendXiphCommentSection(out, f.isValid() ? f.tag() : nullptr, @"[Xiph Comment]");
    }

    if (format == TLTagFileFormatAPE) {
        TagLib::APE::File f(filePath);
        AppendAPEItemsSection(out, (f.isValid() && f.hasAPETag()) ? f.APETag() : nullptr, @"[APE Items]");
    }

    if (format == TLTagFileFormatWAV) {
        TagLib::RIFF::WAV::File f(filePath);
        if (f.isValid()) {
            AppendRIFFInfoSection(out, f.hasInfoTag() ? f.InfoTag() : nullptr, @"[RIFF INFO]");
            AppendID3v2FramesSection(out, f.hasID3v2Tag() ? f.ID3v2Tag() : nullptr, @"[ID3v2 Frames]");
        } else {
            AppendRIFFInfoSection(out, nullptr, @"[RIFF INFO]");
            AppendID3v2FramesSection(out, nullptr, @"[ID3v2 Frames]");
        }
    }

    if (format == TLTagFileFormatAIFF) {
        TagLib::RIFF::AIFF::File f(filePath);
        AppendID3v2FramesSection(out, (f.isValid() && f.hasID3v2Tag()) ? f.tag() : nullptr, @"[ID3v2 Frames]");
    }

    if (format == TLTagFileFormatWavPack) {
        TagLib::WavPack::File f(filePath);
        if (f.isValid()) {
            AppendAPEItemsSection(out, f.hasAPETag() ? f.APETag() : nullptr, @"[APE Items]");
            AppendSimpleTagSection(out, @"[ID3v1 Tag]", f.hasID3v1Tag() ? f.ID3v1Tag() : nullptr);
        } else {
            AppendAPEItemsSection(out, nullptr, @"[APE Items]");
            AppendSimpleTagSection(out, @"[ID3v1 Tag]", nullptr);
        }
    }

    if (format == TLTagFileFormatMPC) {
        TagLib::MPC::File f(filePath);
        if (f.isValid()) {
            AppendAPEItemsSection(out, f.hasAPETag() ? f.APETag() : nullptr, @"[APE Items]");
            AppendSimpleTagSection(out, @"[ID3v1 Tag]", f.hasID3v1Tag() ? f.ID3v1Tag() : nullptr);
        } else {
            AppendAPEItemsSection(out, nullptr, @"[APE Items]");
            AppendSimpleTagSection(out, @"[ID3v1 Tag]", nullptr);
        }
    }

    if (format == TLTagFileFormatTTA) {
        TagLib::TrueAudio::File f(filePath);
        if (f.isValid()) {
            AppendID3v2FramesSection(out, f.hasID3v2Tag() ? f.ID3v2Tag() : nullptr, @"[ID3v2 Frames]");
            AppendSimpleTagSection(out, @"[ID3v1 Tag]", f.hasID3v1Tag() ? f.ID3v1Tag() : nullptr);
        } else {
            AppendID3v2FramesSection(out, nullptr, @"[ID3v2 Frames]");
            AppendSimpleTagSection(out, @"[ID3v1 Tag]", nullptr);
        }
    }

    // If absolutely nothing useful could be printed, provide a clear message.
    // (Avoid returning nil so the GUI always has something to show.)
    if (!anyProperties && out.length > 0) {
        // Keep as-is; the sections above already printed (none/unable...).
    }

    return out;
    TAGLIB_BRIDGE_CATCH_WITH_ERROR(error, @"Metadata text dump", nil)
}

#pragma mark - Format Support

static NSString * _Nullable MetadataMappingString(const char * _Nullable value)
{
    if (!value) return nil;
    return [[NSString alloc] initWithBytes:value
                                   length:strlen(value)
                                 encoding:NSISOLatin1StringEncoding];
}

+ (NSArray<NSString *> *)knownMetadataPropertyKeys
{
    return [KnownMetadataFieldKeys().allObjects sortedArrayUsingSelector:@selector(compare:)];
}

+ (NSArray<NSDictionary<NSString *, NSObject *> *> *)metadataFieldMappings
{
    NSMutableArray<NSDictionary<NSString *, NSObject *> *> *result = [NSMutableArray array];
    for (const auto &mapping : kMetadataFieldMappings) {
        NSMutableArray<NSString *> *aliases = [NSMutableArray array];
        for (const char *alias : mapping.propertyAliases) {
            if (NSString *value = MetadataMappingString(alias)) {
                [aliases addObject:value];
            }
        }

        NSMutableDictionary<NSString *, NSObject *> *entry = [@{
            @"canonicalPropertyKey": MetadataMappingString(mapping.canonicalPropertyKey) ?: @"",
            @"propertyAliases": [aliases copy],
            @"multiValue": @(mapping.multiValue),
            @"peopleField": @(mapping.peopleField),
            @"roleQualified": @(mapping.roleQualified),
        } mutableCopy];
        if (NSString *value = MetadataMappingString(mapping.id3v2TextFrame)) entry[@"id3v2TextFrame"] = value;
        if (NSString *value = MetadataMappingString(mapping.id3v2UserTextDescription)) entry[@"id3v2UserTextDescription"] = value;
        if (NSString *value = MetadataMappingString(mapping.mp4Atom)) entry[@"mp4Atom"] = value;
        if (NSString *value = MetadataMappingString(mapping.mp4FreeformDescription)) entry[@"mp4FreeformDescription"] = value;
        [result addObject:[entry copy]];
    }
    return [result copy];
}

static NSArray<NSString *> *ExtensionsForDescriptor(const TLFormatCapabilityDescriptor &descriptor)
{
    NSMutableArray<NSString *> *extensions = [NSMutableArray array];
    for (const char * const *extension = descriptor.extensions; *extension; ++extension) {
        [extensions addObject:@(*extension)];
    }
    return [extensions copy];
}

static NSArray<NSString *> *ContainerNamesForMask(TLMetadataContainerMask containers)
{
    NSMutableArray<NSString *> *names = [NSMutableArray array];
    if (containers & TLMetadataContainerTag) [names addObject:@"tag"];
    if (containers & TLMetadataContainerPropertyMap) [names addObject:@"propertyMap"];
    if (containers & TLMetadataContainerID3v1) [names addObject:@"id3v1"];
    if (containers & TLMetadataContainerID3v2) [names addObject:@"id3v2"];
    if (containers & TLMetadataContainerAPE) [names addObject:@"ape"];
    if (containers & TLMetadataContainerMP4ItemMap) [names addObject:@"mp4"];
    if (containers & TLMetadataContainerXiph) [names addObject:@"xiph"];
    if (containers & TLMetadataContainerASF) [names addObject:@"asf"];
    if (containers & TLMetadataContainerRIFFInfo) [names addObject:@"riffInfo"];
    return [names copy];
}

static const char *SupportLevelForExtension(const TLFormatCapabilityDescriptor &descriptor,
                                            NSString *extension)
{
    static NSSet<NSString *> *fixtureCoveredExtensions = [NSSet setWithArray:@[
        @"mp3", @"m4a", @"flac", @"ogg", @"oga", @"wav", @"aac", @"xm"
    ]];
    if ([fixtureCoveredExtensions containsObject:extension.lowercaseString]) {
        return "fixtureCovered";
    }
    if (descriptor.format == TLTagFileFormatShorten ||
        descriptor.format == TLTagFileFormatMOD) {
        return "readOnly";
    }
    switch (descriptor.format) {
        case TLTagFileFormatS3M:
        case TLTagFileFormatIT:
            return "experimental";
        default:
            return "upstreamSupported";
    }
}

static NSArray<NSString *> * _Nullable ExplicitReadableFieldsForFormat(TLTagFileFormat format)
{
    switch (format) {
        case TLTagFileFormatMOD:
        case TLTagFileFormatS3M:
        case TLTagFileFormatIT:
        case TLTagFileFormatXM:
            return @[ @"title", @"comment", @"trackerName" ];
        default:
            return nil;
    }
}

static NSArray<NSString *> * _Nullable ExplicitWritableFieldsForFormat(TLTagFileFormat format)
{
    switch (format) {
        case TLTagFileFormatMOD:
            return @[];
        case TLTagFileFormatS3M:
        case TLTagFileFormatIT:
            return @[ @"title", @"comment" ];
        case TLTagFileFormatXM:
            return @[ @"title", @"comment", @"trackerName" ];
        default:
            return nil;
    }
}

static NSDictionary<NSString *, NSObject *> *CapabilityDictionaryForDescriptor(
    const TLFormatCapabilityDescriptor &descriptor,
    NSString * _Nullable requestedExtension = nil
)
{
    TLMetadataContainerMask containers = ContainerMaskForFormat(descriptor.format);
    BOOL writable = IsWritableTagFileFormat(descriptor.format);
    NSArray<NSString *> *extensions = ExtensionsForDescriptor(descriptor);
    NSString *primaryExtension = extensions.firstObject ?: @"";
    NSMutableDictionary<NSString *, NSString *> *extensionSupportLevels = [NSMutableDictionary dictionary];
    for (NSString *extension in extensions) {
        extensionSupportLevels[extension] = @(SupportLevelForExtension(descriptor, extension));
    }
    NSString *supportExtension = requestedExtension.lowercaseString ?: primaryExtension;
    NSMutableDictionary<NSString *, NSObject *> *capability = [NSMutableDictionary dictionaryWithDictionary:@{
        @"identifier": @(descriptor.identifier),
        @"displayName": @(descriptor.displayName),
        @"codecName": @(descriptor.codecName),
        @"primaryExtension": primaryExtension,
        @"extensions": extensions,
        @"containers": ContainerNamesForMask(containers),
        @"isReadable": @YES,
        @"isWritable": @(writable),
        @"canReadArtwork": @(descriptor.canReadArtwork),
        @"canWriteArtwork": @(descriptor.canWriteArtwork && writable),
        @"preservesMultiValueProperties": @(descriptor.preservesMultiValueProperties),
        @"structuredReadSupport": @(descriptor.structuredReadSupport),
        @"structuredWriteSupport": @(writable ? descriptor.structuredWriteSupport : "none"),
        @"supportLevel": @(SupportLevelForExtension(descriptor, supportExtension)),
        @"extensionSupportLevels": [extensionSupportLevels copy],
    }];

    if (descriptor.readOnlyReason) {
        capability[@"readOnlyReason"] = @(descriptor.readOnlyReason);
    }
    if (descriptor.notes) {
        capability[@"notes"] = @(descriptor.notes);
    }
    if (NSArray<NSString *> *readableFields = ExplicitReadableFieldsForFormat(descriptor.format)) {
        capability[@"readableFields"] = readableFields;
    }
    if (NSArray<NSString *> *writableFields = ExplicitWritableFieldsForFormat(descriptor.format)) {
        capability[@"writableFields"] = writableFields;
    }
    return [capability copy];
}

+ (BOOL)isSupportedFormat:(NSString *)fileExtension {
    try {
    return DescriptorForExtension(fileExtension) != nullptr;
    TAGLIB_BRIDGE_CATCH_SAFE(@"Supported-format lookup", NO)
}

+ (BOOL)isWritableFormat:(NSString *)fileExtension {
    try {
    const TLFormatCapabilityDescriptor *descriptor = DescriptorForExtension(fileExtension);
    return descriptor ? IsWritableTagFileFormat(descriptor->format) : NO;
    TAGLIB_BRIDGE_CATCH_SAFE(@"Writable-format lookup", NO)
}

+ (NSArray<NSString *> *)supportedExtensions {
    try {
    NSMutableArray<NSString *> *extensions = [NSMutableArray array];
    for (const auto &descriptor : TLFormatCapabilityDescriptors()) {
        [extensions addObjectsFromArray:ExtensionsForDescriptor(descriptor)];
    }
    return [extensions copy];
    TAGLIB_BRIDGE_CATCH_SAFE(@"Supported-extension enumeration", @[])
}

+ (NSArray<NSString *> *)writableExtensions {
    try {
    NSMutableArray<NSString *> *extensions = [NSMutableArray array];
    for (const auto &descriptor : TLFormatCapabilityDescriptors()) {
        if (IsWritableTagFileFormat(descriptor.format)) {
            [extensions addObjectsFromArray:ExtensionsForDescriptor(descriptor)];
        }
    }
    return [extensions copy];
    TAGLIB_BRIDGE_CATCH_SAFE(@"Writable-extension enumeration", @[])
}

+ (nullable NSDictionary<NSString *, NSObject *> *)formatCapabilityForExtension:(NSString *)fileExtension {
    try {
    const TLFormatCapabilityDescriptor *descriptor = DescriptorForExtension(fileExtension);
    if (!descriptor) {
        return nil;
    }
    return CapabilityDictionaryForDescriptor(*descriptor, fileExtension);
    TAGLIB_BRIDGE_CATCH_SAFE(@"Format-capability lookup", nil)
}

+ (NSArray<NSDictionary<NSString *, NSObject *> *> *)formatCapabilities {
    try {
    NSMutableArray<NSDictionary<NSString *, NSObject *> *> *capabilities = [NSMutableArray array];
    for (const auto &descriptor : TLFormatCapabilityDescriptors()) {
        [capabilities addObject:CapabilityDictionaryForDescriptor(descriptor)];
    }
    return [capabilities copy];
    TAGLIB_BRIDGE_CATCH_SAFE(@"Format-capability enumeration", @[])
}
