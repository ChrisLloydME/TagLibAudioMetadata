static NSArray<NSDictionary<NSString *, NSObject *> *> *StructuredArray(NSDictionary<NSString *, NSObject *> *metadata,
                                                                        NSString *key)
{
    NSObject *value = metadata[key];
    if (![value isKindOfClass:[NSArray class]]) {
        return nil;
    }
    return (NSArray<NSDictionary<NSString *, NSObject *> *> *)value;
}

static BOOL SetStructuredPayloadValidationError(NSError **error, NSString *description)
{
    if (error) {
        *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                     code:243
                                 userInfo:@{ NSLocalizedDescriptionKey : description }];
    }
    return NO;
}

static BOOL StructuredOptionalValueHasClass(NSDictionary *entry, NSString *key, Class expectedClass)
{
    NSObject *value = entry[key];
    return !value || [value isKindOfClass:expectedClass];
}

static BOOL StructuredOptionalValueIsNumberLike(NSDictionary *entry, NSString *key)
{
    NSObject *value = entry[key];
    return !value || [value isKindOfClass:[NSNumber class]] || [value isKindOfClass:[NSString class]];
}

static BOOL StructuredOptionalDataFitsTagLib(NSDictionary *entry, NSString *key)
{
    NSObject *value = entry[key];
    if (!value) {
        return YES;
    }
    return [value isKindOfClass:[NSData class]] &&
        ((NSData *)value).length <= std::numeric_limits<unsigned int>::max();
}

static BOOL StructuredOptionalValueFitsInt(NSDictionary *entry, NSString *key)
{
    NSObject *value = entry[key];
    if (!value) {
        return YES;
    }
    if (![value isKindOfClass:[NSNumber class]] && ![value isKindOfClass:[NSString class]]) {
        return NO;
    }
    long long number = [(id)value longLongValue];
    return number >= std::numeric_limits<int>::min() && number <= std::numeric_limits<int>::max();
}

static BOOL StructuredOptionalValueFitsUInt32(NSDictionary *entry, NSString *key)
{
    NSObject *value = entry[key];
    if (!value) return YES;

    unsigned long long parsed = 0;
    if ([value isKindOfClass:[NSNumber class]]) {
        NSNumber *number = (NSNumber *)value;
        if (number.longLongValue < 0) return NO;
        parsed = number.unsignedLongLongValue;
    } else if ([value isKindOfClass:[NSString class]]) {
        NSString *string = TrimmedStringOrNil((NSString *)value);
        if (!string || [string hasPrefix:@"-"]) return NO;
        errno = 0;
        char *end = nullptr;
        parsed = std::strtoull(string.UTF8String, &end, 10);
        if (errno == ERANGE || !end || *end != '\0') return NO;
    } else {
        return NO;
    }

    return parsed <= std::numeric_limits<unsigned int>::max();
}

static BOOL StructuredOptionalValueIsBooleanLike(NSDictionary *entry, NSString *key)
{
    NSObject *value = entry[key];
    return !value || [value isKindOfClass:[NSNumber class]] || [value isKindOfClass:[NSString class]];
}

static bool UnsignedLongLongValueFromObject(NSObject *value, unsigned long long &result)
{
    if ([value isKindOfClass:[NSNumber class]]) {
        value = (NSObject *)((NSNumber *)value).stringValue;
    }
    if ([value isKindOfClass:[NSString class]]) {
        NSString *string = TrimmedStringOrNil((NSString *)value);
        if (!string || [string hasPrefix:@"-"]) return false;
        errno = 0;
        char *end = nullptr;
        unsigned long long parsed = std::strtoull(string.UTF8String, &end, 10);
        if (errno == ERANGE || !end || *end != '\0') return false;
        result = parsed;
        return true;
    }
    return false;
}

static BOOL StructuredValueIsStringArray(NSObject *value)
{
    if (![value isKindOfClass:[NSArray class]]) {
        return NO;
    }
    for (NSObject *element in (NSArray *)value) {
        if (![element isKindOfClass:[NSString class]]) {
            return NO;
        }
    }
    return YES;
}

static BOOL IsValidID3v2FrameID(NSString *frameID)
{
    if (![frameID isKindOfClass:[NSString class]]) {
        return NO;
    }

    NSData *utf8 = [frameID dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
    if (utf8.length != 4) {
        return NO;
    }

    const unsigned char *bytes = static_cast<const unsigned char *>(utf8.bytes);
    for (NSUInteger index = 0; index < utf8.length; ++index) {
        unsigned char byte = bytes[index];
        if (!((byte >= 'A' && byte <= 'Z') || (byte >= '0' && byte <= '9'))) {
            return NO;
        }
    }
    return YES;
}

static BOOL ValidateStructuredMetadataPayload(NSDictionary<NSString *, NSObject *> *metadata,
                                              NSError **error)
{
    if (![metadata isKindOfClass:[NSDictionary class]]) {
        return SetStructuredPayloadValidationError(error, @"Structured metadata payload must be a dictionary");
    }

    NSArray<NSString *> *collectionKeys = @[
        @"properties", @"id3v2Frames", @"mp4Atoms", @"asfAttributes",
        @"artwork", @"lyrics", @"comments"
    ];
    for (NSString *collectionKey in collectionKeys) {
        NSObject *value = metadata[collectionKey];
        if (!value) {
            continue;
        }
        if (![value isKindOfClass:[NSArray class]]) {
            return SetStructuredPayloadValidationError(
                error,
                [NSString stringWithFormat:@"Structured metadata field '%@' must be an array", collectionKey]
            );
        }
        NSUInteger index = 0;
        for (NSObject *element in (NSArray *)value) {
            if (![element isKindOfClass:[NSDictionary class]]) {
                return SetStructuredPayloadValidationError(
                    error,
                    [NSString stringWithFormat:@"Structured metadata field '%@' contains a non-dictionary element at index %lu",
                     collectionKey, (unsigned long)index]
                );
            }
            ++index;
        }
    }

    for (NSDictionary *entry in StructuredArray(metadata, @"properties") ?: @[]) {
        if (![entry[@"key"] isKindOfClass:[NSString class]] ||
            !StructuredOptionalValueHasClass(entry, @"value", [NSString class]) ||
            (entry[@"values"] && !StructuredValueIsStringArray(entry[@"values"]))) {
            return SetStructuredPayloadValidationError(error, @"Each structured property requires a string key and string value(s)");
        }
    }

    for (NSDictionary *entry in StructuredArray(metadata, @"id3v2Frames") ?: @[]) {
        NSString *frameID = [entry[@"id"] isKindOfClass:[NSString class]] ? (NSString *)entry[@"id"] : nil;
        NSString *type = [entry[@"type"] isKindOfClass:[NSString class]] ? (NSString *)entry[@"type"] : nil;
        if (!IsValidID3v2FrameID(frameID)) {
            return SetStructuredPayloadValidationError(error, @"Each ID3v2 frame ID must be exactly four uppercase ASCII letters or digits");
        }
        if (!type ||
            !StructuredOptionalValueHasClass(entry, @"value", [NSString class]) ||
            (entry[@"values"] && !StructuredValueIsStringArray(entry[@"values"])) ||
            !StructuredOptionalValueHasClass(entry, @"description", [NSString class]) ||
            !StructuredOptionalValueHasClass(entry, @"language", [NSString class]) ||
            !StructuredOptionalValueHasClass(entry, @"url", [NSString class]) ||
            !StructuredOptionalValueHasClass(entry, @"owner", [NSString class]) ||
            !StructuredOptionalDataFitsTagLib(entry, @"data") ||
            !StructuredOptionalValueHasClass(entry, @"elementID", [NSString class]) ||
            !StructuredOptionalValueFitsUInt32(entry, @"startTimeMilliseconds") ||
            !StructuredOptionalValueFitsUInt32(entry, @"endTimeMilliseconds") ||
            !StructuredOptionalValueFitsUInt32(entry, @"startOffset") ||
            !StructuredOptionalValueFitsUInt32(entry, @"endOffset") ||
            !StructuredOptionalValueIsBooleanLike(entry, @"isTopLevel") ||
            !StructuredOptionalValueIsBooleanLike(entry, @"isOrdered") ||
            (entry[@"children"] && !StructuredValueIsStringArray(entry[@"children"]))) {
            return SetStructuredPayloadValidationError(error, @"ID3v2 frame fields have invalid value types");
        }
        if (([type isEqualToString:@"chapter"] && ![frameID isEqualToString:@"CHAP"]) ||
            ([type isEqualToString:@"tableOfContents"] && ![frameID isEqualToString:@"CTOC"]) ||
            ([type isEqualToString:@"podcast"] && ![frameID isEqualToString:@"PCST"])) {
            return SetStructuredPayloadValidationError(error, @"Structured ID3v2 frame type does not match its frame ID");
        }
        if (([type isEqualToString:@"chapter"] || [type isEqualToString:@"tableOfContents"]) &&
            !TrimmedStringOrNil((NSString *)entry[@"elementID"])) {
            return SetStructuredPayloadValidationError(error, @"CHAP and CTOC frames require a non-empty elementID");
        }
    }

    for (NSDictionary *entry in StructuredArray(metadata, @"mp4Atoms") ?: @[]) {
        if (![entry[@"key"] isKindOfClass:[NSString class]] ||
            ![entry[@"type"] isKindOfClass:[NSString class]] ||
            (entry[@"value"] && ![entry[@"value"] isKindOfClass:[NSString class]] && ![entry[@"value"] isKindOfClass:[NSNumber class]]) ||
            (entry[@"values"] && !StructuredValueIsStringArray(entry[@"values"])) ||
            !StructuredOptionalValueFitsInt(entry, @"first") ||
            !StructuredOptionalValueFitsInt(entry, @"second") ||
            !StructuredOptionalValueHasClass(entry, @"freeformDescription", [NSString class])) {
            return SetStructuredPayloadValidationError(error, @"MP4 atom fields have invalid value types");
        }
    }

    for (NSDictionary *entry in StructuredArray(metadata, @"asfAttributes") ?: @[]) {
        if (![entry[@"key"] isKindOfClass:[NSString class]] ||
            ![entry[@"type"] isKindOfClass:[NSString class]] ||
            (entry[@"value"] && ![entry[@"value"] isKindOfClass:[NSString class]] && ![entry[@"value"] isKindOfClass:[NSNumber class]]) ||
            !StructuredOptionalDataFitsTagLib(entry, @"data") ||
            !StructuredOptionalValueHasClass(entry, @"pictureType", [NSString class]) ||
            !StructuredOptionalValueHasClass(entry, @"mimeType", [NSString class]) ||
            !StructuredOptionalValueHasClass(entry, @"description", [NSString class]) ||
            !StructuredOptionalValueIsNumberLike(entry, @"language") ||
            !StructuredOptionalValueIsNumberLike(entry, @"stream")) {
            return SetStructuredPayloadValidationError(error, @"ASF attribute fields have invalid value types");
        }
        if ([(NSString *)entry[@"type"] isEqualToString:@"int64"]) {
            unsigned long long value = 0;
            if (!UnsignedLongLongValueFromObject(entry[@"value"], value)) {
                return SetStructuredPayloadValidationError(error, @"ASF int64 attributes require an unsigned 64-bit value");
            }
        }
    }

    for (NSDictionary *entry in StructuredArray(metadata, @"artwork") ?: @[]) {
        if (![entry[@"data"] isKindOfClass:[NSData class]] ||
            ((NSData *)entry[@"data"]).length == 0 ||
            ((NSData *)entry[@"data"]).length > std::numeric_limits<unsigned int>::max() ||
            !StructuredOptionalValueHasClass(entry, @"container", [NSString class]) ||
            !StructuredOptionalValueHasClass(entry, @"mimeType", [NSString class]) ||
            !StructuredOptionalValueHasClass(entry, @"pictureType", [NSString class]) ||
            !StructuredOptionalValueHasClass(entry, @"description", [NSString class]) ||
            !StructuredOptionalValueIsNumberLike(entry, @"pictureTypeCode")) {
            return SetStructuredPayloadValidationError(error, @"Artwork entries require NSData and string/number metadata fields");
        }
    }

    for (NSString *collectionKey in @[ @"lyrics", @"comments" ]) {
        for (NSDictionary *entry in StructuredArray(metadata, collectionKey) ?: @[]) {
            if (![entry[@"text"] isKindOfClass:[NSString class]] ||
                !StructuredOptionalValueHasClass(entry, @"language", [NSString class]) ||
                !StructuredOptionalValueHasClass(entry, @"description", [NSString class])) {
                return SetStructuredPayloadValidationError(
                    error,
                    [NSString stringWithFormat:@"Each %@ entry requires string text, language, and description fields", collectionKey]
                );
            }
        }
    }

    return YES;
}

static NSInteger IntegerValueFromObject(NSObject *value)
{
    if ([value isKindOfClass:[NSNumber class]]) {
        return [(NSNumber *)value integerValue];
    }
    if ([value isKindOfClass:[NSString class]]) {
        return [(NSString *)value integerValue];
    }
    return 0;
}

static bool BooleanValueFromObject(NSObject *value)
{
    if ([value isKindOfClass:[NSNumber class]]) {
        return [(NSNumber *)value boolValue];
    }
    if ([value isKindOfClass:[NSString class]]) {
        NSString *normalized = [(NSString *)value stringByTrimmingCharactersInSet:
            NSCharacterSet.whitespaceAndNewlineCharacterSet].lowercaseString;
        return [normalized isEqualToString:@"true"] ||
            [normalized isEqualToString:@"yes"] ||
            [normalized isEqualToString:@"on"] ||
            normalized.integerValue != 0;
    }
    return false;
}

static NSData *DataValueFromObject(NSObject *value)
{
    if ([value isKindOfClass:[NSData class]]) {
        return (NSData *)value;
    }
    return nil;
}

static void ReplaceID3v2Comments(TagLib::ID3v2::Tag *tag, NSArray<NSDictionary<NSString *, NSObject *> *> *comments)
{
    if (!tag || !comments) return;
    TagLib::ID3v2::FrameList existing = tag->frameList("COMM");
    for (auto it = existing.begin(); it != existing.end(); ++it) tag->removeFrame(*it);

    for (NSDictionary<NSString *, NSObject *> *entry in comments) {
        NSString *text = TrimmedStringOrNil((NSString *)entry[@"text"]);
        if (!text) continue;
        auto *frame = new TagLib::ID3v2::CommentsFrame(TagLib::String::UTF8);
        frame->setDescription(NSStringToTagString((NSString *)entry[@"description"]));
        NSString *language = TrimmedStringOrNil((NSString *)entry[@"language"]) ?: @"eng";
        std::string lang = language.UTF8String ? language.UTF8String : "eng";
        if (lang.size() < 3) lang = "eng";
        frame->setLanguage(TagLib::ByteVector(lang.c_str(), 3));
        frame->setText(NSStringToTagString(text));
        tag->addFrame(frame);
    }
}

static void ReplaceID3v2Lyrics(TagLib::ID3v2::Tag *tag, NSArray<NSDictionary<NSString *, NSObject *> *> *lyrics)
{
    if (!tag || !lyrics) return;
    TagLib::ID3v2::FrameList existing = tag->frameList("USLT");
    for (auto it = existing.begin(); it != existing.end(); ++it) tag->removeFrame(*it);

    for (NSDictionary<NSString *, NSObject *> *entry in lyrics) {
        NSString *text = TrimmedStringOrNil((NSString *)entry[@"text"]);
        if (!text) continue;
        auto *frame = new TagLib::ID3v2::UnsynchronizedLyricsFrame(TagLib::String::UTF8);
        frame->setDescription(NSStringToTagString((NSString *)entry[@"description"]));
        NSString *language = TrimmedStringOrNil((NSString *)entry[@"language"]) ?: @"eng";
        std::string lang = language.UTF8String ? language.UTF8String : "eng";
        if (lang.size() < 3) lang = "eng";
        frame->setLanguage(TagLib::ByteVector(lang.c_str(), 3));
        frame->setText(NSStringToTagString(text));
        tag->addFrame(frame);
    }
}

static void ReplaceID3v2Artwork(TagLib::ID3v2::Tag *tag, NSArray<NSDictionary<NSString *, NSObject *> *> *artwork)
{
    if (!tag || !artwork) return;
    TagLib::ID3v2::FrameList existing = tag->frameList("APIC");
    for (auto it = existing.begin(); it != existing.end(); ++it) tag->removeFrame(*it);

    for (NSDictionary<NSString *, NSObject *> *entry in artwork) {
        NSData *data = DataValueFromObject(entry[@"data"]);
        if (data.length == 0) continue;
        auto *frame = new TagLib::ID3v2::AttachedPictureFrame();
        frame->setMimeType(NSStringToTagString((NSString *)entry[@"mimeType"] ?: @"image/jpeg"));
        frame->setDescription(NSStringToTagString((NSString *)entry[@"description"]));
        NSInteger typeCode = IntegerValueFromObject(entry[@"pictureTypeCode"]);
        if (typeCode <= 0 && [entry[@"pictureType"] isKindOfClass:[NSString class]]) {
            typeCode = TagLib::ID3v2::AttachedPictureFrame::typeFromString(
                NSStringToTagString((NSString *)entry[@"pictureType"])
            );
        }
        if (typeCode <= 0) typeCode = TagLib::ID3v2::AttachedPictureFrame::FrontCover;
        frame->setType((TagLib::ID3v2::AttachedPictureFrame::Type)typeCode);
        frame->setPicture(TagLib::ByteVector((const char *)data.bytes, (unsigned int)data.length));
        tag->addFrame(frame);
    }
}

static TagLib::List<TagLib::VariantMap> StructuredPictureComplexProperties(
    NSArray<NSDictionary<NSString *, NSObject *> *> *artwork)
{
    TagLib::List<TagLib::VariantMap> pictures;
    for (NSDictionary<NSString *, NSObject *> *entry in artwork ?: @[]) {
        NSData *data = DataValueFromObject(entry[@"data"]);
        if (data.length == 0) continue;

        TagLib::VariantMap picture;
        picture.insert("data", TagLib::ByteVector((const char *)data.bytes, (unsigned int)data.length));
        picture.insert(
            "mimeType",
            NSStringToTagString(NormalizedArtworkMimeType((NSString *)entry[@"mimeType"], data))
        );
        NSString *pictureType = TrimmedStringOrNil((NSString *)entry[@"pictureType"]) ?: @"Front Cover";
        picture.insert("pictureType", NSStringToTagString(pictureType));
        NSString *description = TrimmedStringOrNil((NSString *)entry[@"description"]);
        if (description) {
            picture.insert("description", NSStringToTagString(description));
        }
        pictures.append(picture);
    }
    return pictures;
}

template <typename ComplexPropertyTarget>
static bool ReplaceStructuredComplexArtwork(ComplexPropertyTarget *target,
                                             NSArray<NSDictionary<NSString *, NSObject *> *> *artwork)
{
    return !target || !artwork ||
        target->setComplexProperties("PICTURE", StructuredPictureComplexProperties(artwork));
}

static void UpsertID3v2StructuredFrames(TagLib::ID3v2::Tag *tag,
                                        NSArray<NSDictionary<NSString *, NSObject *> *> *frames)
{
    if (!tag || !frames) return;

    for (NSDictionary<NSString *, NSObject *> *entry in frames) {
        NSString *frameID = TrimmedStringOrNil((NSString *)entry[@"id"]);
        NSString *type = TrimmedStringOrNil((NSString *)entry[@"type"]);
        if (!frameID || !type) continue;

        if ([type isEqualToString:@"ufid"]) {
            NSString *owner = TrimmedStringOrNil((NSString *)entry[@"owner"]);
            NSData *data = DataValueFromObject(entry[@"data"]);
            if (!owner || data.length == 0) continue;
            TagLib::ID3v2::UniqueFileIdentifierFrame *existing =
                TagLib::ID3v2::UniqueFileIdentifierFrame::findByOwner(tag, NSStringToTagString(owner));
            if (existing) tag->removeFrame(existing);
            tag->addFrame(new TagLib::ID3v2::UniqueFileIdentifierFrame(
                NSStringToTagString(owner),
                TagLib::ByteVector((const char *)data.bytes, (unsigned int)data.length)
            ));
        } else if ([type isEqualToString:@"url"]) {
            NSString *url = TrimmedStringOrNil((NSString *)entry[@"url"]);
            if (!url) continue;
            if ([frameID isEqualToString:@"WXXX"]) {
                NSString *description = TrimmedStringOrNil((NSString *)entry[@"description"]) ?: @"";
                TagLib::ID3v2::UserUrlLinkFrame *existing =
                    TagLib::ID3v2::UserUrlLinkFrame::find(tag, NSStringToTagString(description));
                if (existing) tag->removeFrame(existing);
                auto *frame = new TagLib::ID3v2::UserUrlLinkFrame(TagLib::String::UTF8);
                frame->setDescription(NSStringToTagString(description));
                frame->setUrl(NSStringToTagString(url));
                tag->addFrame(frame);
            } else {
                const char *frameIDBytes = frameID.UTF8String;
                if (!frameIDBytes || std::strlen(frameIDBytes) != 4) continue;
                TagLib::ID3v2::FrameList existing = tag->frameList(frameIDBytes);
                for (auto it = existing.begin(); it != existing.end(); ++it) tag->removeFrame(*it);
                auto *frame = new TagLib::ID3v2::UrlLinkFrame(TagLib::ByteVector(frameIDBytes, 4));
                frame->setUrl(NSStringToTagString(url));
                tag->addFrame(frame);
            }
        } else if ([type isEqualToString:@"text"]) {
            NSArray<NSString *> *values = (NSArray<NSString *> *)entry[@"values"];
            NSString *joined = values.count ? [values componentsJoinedByString:@"; "] : (NSString *)entry[@"value"];
            SetID3v2TextFrame(tag, frameID.UTF8String, joined);
        } else if ([type isEqualToString:@"userText"]) {
            NSArray<NSString *> *values = (NSArray<NSString *> *)entry[@"values"];
            NSString *joined = values.count ? [values componentsJoinedByString:@"; "] : (NSString *)entry[@"value"];
            SetID3v2UserTextFrame(tag, ((NSString *)entry[@"description"]).UTF8String, joined);
        } else if ([type isEqualToString:@"chapter"]) {
            NSString *elementID = TrimmedStringOrNil((NSString *)entry[@"elementID"]);
            TagLib::ByteVector elementIDBytes(elementID.UTF8String, (unsigned int)strlen(elementID.UTF8String));
            auto *frame = TagLib::ID3v2::ChapterFrame::findByElementID(tag, elementIDBytes);
            if (!frame) {
                frame = new TagLib::ID3v2::ChapterFrame(elementIDBytes, 0, 0, 0, 0);
                tag->addFrame(frame);
            }
            frame->setStartTime((unsigned int)IntegerValueFromObject(entry[@"startTimeMilliseconds"]));
            frame->setEndTime((unsigned int)IntegerValueFromObject(entry[@"endTimeMilliseconds"]));
            frame->setStartOffset((unsigned int)IntegerValueFromObject(entry[@"startOffset"]));
            frame->setEndOffset((unsigned int)IntegerValueFromObject(entry[@"endOffset"]));
        } else if ([type isEqualToString:@"tableOfContents"]) {
            NSString *elementID = TrimmedStringOrNil((NSString *)entry[@"elementID"]);
            TagLib::ByteVector elementIDBytes(elementID.UTF8String, (unsigned int)strlen(elementID.UTF8String));
            auto *frame = TagLib::ID3v2::TableOfContentsFrame::findByElementID(tag, elementIDBytes);
            if (!frame) {
                frame = new TagLib::ID3v2::TableOfContentsFrame(elementIDBytes);
                tag->addFrame(frame);
            }
            frame->setIsTopLevel(BooleanValueFromObject(entry[@"isTopLevel"]));
            frame->setIsOrdered(BooleanValueFromObject(entry[@"isOrdered"]));
            TagLib::ByteVectorList children;
            for (NSString *child in (NSArray<NSString *> *)entry[@"children"] ?: @[]) {
                NSData *utf8 = [child dataUsingEncoding:NSUTF8StringEncoding];
                if (utf8.length > 0) {
                    children.append(TagLib::ByteVector((const char *)utf8.bytes, (unsigned int)utf8.length));
                }
            }
            frame->setChildElements(children);
        } else if ([type isEqualToString:@"podcast"]) {
            TagLib::ID3v2::FrameList existing = tag->frameList("PCST");
            for (auto it = existing.begin(); it != existing.end(); ++it) tag->removeFrame(*it);
            tag->addFrame(new TagLib::ID3v2::PodcastFrame());
        }
    }
}

static void ApplyStructuredMP4Atoms(TagLib::MP4::Tag *tag,
                                    NSArray<NSDictionary<NSString *, NSObject *> *> *atoms)
{
    if (!tag || !atoms) return;
    for (NSDictionary<NSString *, NSObject *> *entry in atoms) {
        NSString *key = TrimmedStringOrNil((NSString *)entry[@"key"]);
        NSString *type = TrimmedStringOrNil((NSString *)entry[@"type"]);
        if (!key || !type) continue;

        if ([type isEqualToString:@"stringList"]) {
            TagLib::StringList list;
            NSArray<NSString *> *values = (NSArray<NSString *> *)entry[@"values"];
            for (NSString *value in values ?: @[]) {
                NSString *trimmed = TrimmedStringOrNil(value);
                if (trimmed) list.append(NSStringToTagString(trimmed));
            }
            if (list.isEmpty()) tag->removeItem(NSStringToTagString(key));
            else tag->setItem(NSStringToTagString(key), TagLib::MP4::Item(list));
        } else if ([type isEqualToString:@"bool"]) {
            const bool boolValue = BooleanValueFromObject(entry[@"value"]);
            tag->setItem(NSStringToTagString(key), TagLib::MP4::Item(boolValue));
        } else if ([type isEqualToString:@"int"]) {
            tag->setItem(NSStringToTagString(key), TagLib::MP4::Item((int)IntegerValueFromObject(entry[@"value"])));
        } else if ([type isEqualToString:@"uint"]) {
            tag->setItem(NSStringToTagString(key), TagLib::MP4::Item((unsigned int)IntegerValueFromObject(entry[@"value"])));
        } else if ([type isEqualToString:@"byte"]) {
            tag->setItem(NSStringToTagString(key), TagLib::MP4::Item((unsigned char)IntegerValueFromObject(entry[@"value"])));
        } else if ([type isEqualToString:@"longLong"]) {
            tag->setItem(NSStringToTagString(key), TagLib::MP4::Item((long long)IntegerValueFromObject(entry[@"value"])));
        } else if ([type isEqualToString:@"intPair"]) {
            tag->setItem(NSStringToTagString(key), TagLib::MP4::Item(
                (int)IntegerValueFromObject(entry[@"first"]),
                (int)IntegerValueFromObject(entry[@"second"])
            ));
        }
    }
}

static void ApplyStructuredASFAttributes(TagLib::ASF::Tag *tag,
                                         NSArray<NSDictionary<NSString *, NSObject *> *> *attributes)
{
    if (!tag || !attributes) return;
    NSMutableSet<NSString *> *cleared = [NSMutableSet set];
    for (NSDictionary<NSString *, NSObject *> *entry in attributes) {
        NSString *key = TrimmedStringOrNil((NSString *)entry[@"key"]);
        NSString *type = TrimmedStringOrNil((NSString *)entry[@"type"]);
        if (!key || !type) continue;
        if (![cleared containsObject:key]) {
            tag->removeItem(NSStringToTagString(key));
            [cleared addObject:key];
        }

        TagLib::ASF::Attribute attribute;
        if ([key isEqualToString:@"WM/Picture"]) {
            NSData *data = DataValueFromObject(entry[@"data"]);
            if (data.length == 0) continue;
            TagLib::ASF::Picture picture;
            picture.setMimeType(NSStringToTagString((NSString *)entry[@"mimeType"] ?: @"image/jpeg"));
            picture.setDescription(NSStringToTagString((NSString *)entry[@"description"]));
            NSInteger typeCode = IntegerValueFromObject(entry[@"pictureTypeCode"]);
            if (typeCode <= 0 && [entry[@"pictureType"] isKindOfClass:[NSString class]]) {
                typeCode = TagLib::ASF::Picture::typeFromString(NSStringToTagString((NSString *)entry[@"pictureType"]));
            }
            if (typeCode <= 0) typeCode = TagLib::ASF::Picture::FrontCover;
            picture.setType((TagLib::ASF::Picture::Type)typeCode);
            picture.setPicture(TagLib::ByteVector((const char *)data.bytes, (unsigned int)data.length));
            attribute = TagLib::ASF::Attribute(picture);
        } else if ([type isEqualToString:@"string"]) {
            attribute = TagLib::ASF::Attribute(NSStringToTagString((NSString *)entry[@"value"]));
        } else if ([type isEqualToString:@"bool"]) {
            const bool boolValue = BooleanValueFromObject(entry[@"value"]);
            attribute = TagLib::ASF::Attribute(boolValue);
        } else if ([type isEqualToString:@"int64"]) {
            unsigned long long value = 0;
            UnsignedLongLongValueFromObject(entry[@"value"], value);
            attribute = TagLib::ASF::Attribute(value);
        } else if ([type isEqualToString:@"binary"] || [type isEqualToString:@"guid"]) {
            NSData *data = DataValueFromObject(entry[@"data"]);
            attribute = TagLib::ASF::Attribute(TagLib::ByteVector((const char *)data.bytes, (unsigned int)data.length));
        } else {
            attribute = TagLib::ASF::Attribute((unsigned int)IntegerValueFromObject(entry[@"value"]));
        }
        attribute.setLanguage((int)IntegerValueFromObject(entry[@"language"]));
        attribute.setStream((int)IntegerValueFromObject(entry[@"stream"]));
        tag->addAttribute(NSStringToTagString(key), attribute);
    }
}

+ (BOOL)writeStructuredMetadata:(NSDictionary<NSString *, NSObject *> *)metadata
                          toURL:(NSURL *)fileURL
                          error:(NSError **)error
{
    try {
    TAGLIB_BRIDGE_SERIAL_GUARD();
    if (TagLibAtomicMutationDepth == 0) {
        return PerformAtomicTagLibMutation(fileURL, error, @"Structured metadata write", ^BOOL(NSURL *temporaryURL, NSError **mutationError) {
            return [self writeStructuredMetadata:metadata toURL:temporaryURL error:mutationError];
        });
    }
    if (!fileURL || !fileURL.isFileURL) {
        if (error) {
            *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                         code:229
                                     userInfo:@{ NSLocalizedDescriptionKey : @"Invalid file URL" }];
        }
        return NO;
    }

    if (!ValidateStructuredMetadataPayload(metadata, error)) {
        return NO;
    }

    NSString *ext = fileURL.pathExtension.lowercaseString;
    AudioMatorTagFileFormat format = DetectTagFileFormat(ext);
    if (!IsWritableTagFileFormat(format)) {
        if (error) {
            *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                         code:230
                                     userInfo:@{ NSLocalizedDescriptionKey : @"Unsupported audio format" }];
        }
        return NO;
    }

    const char *filePath = fileURL.path.UTF8String;
    if (!filePath) {
        if (error) {
            *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                         code:231
                                     userInfo:@{ NSLocalizedDescriptionKey : @"Invalid file path" }];
        }
        return NO;
    }

    NSArray<NSDictionary<NSString *, NSObject *> *> *properties = StructuredArray(metadata, @"properties");
    NSMutableDictionary<NSString *, NSArray<NSString *> *> *propertyValues = nil;
    if (properties) {
        propertyValues = [NSMutableDictionary dictionary];
        for (NSDictionary<NSString *, NSObject *> *entry in properties) {
            NSString *key = TrimmedStringOrNil((NSString *)entry[@"key"]);
            if (!key) continue;
            if ([entry[@"values"] isKindOfClass:[NSArray class]]) {
                propertyValues[key] = (NSArray<NSString *> *)entry[@"values"];
            } else if ([entry[@"value"] isKindOfClass:[NSString class]]) {
                propertyValues[key] = @[ (NSString *)entry[@"value"] ];
            }
        }
    }

    NSArray<NSDictionary<NSString *, NSObject *> *> *frames = StructuredArray(metadata, @"id3v2Frames");
    NSArray<NSDictionary<NSString *, NSObject *> *> *artwork = StructuredArray(metadata, @"artwork");
    NSArray<NSDictionary<NSString *, NSObject *> *> *lyrics = StructuredArray(metadata, @"lyrics");
    NSArray<NSDictionary<NSString *, NSObject *> *> *comments = StructuredArray(metadata, @"comments");
    NSArray<NSDictionary<NSString *, NSObject *> *> *mp4Atoms = StructuredArray(metadata, @"mp4Atoms");
    NSArray<NSDictionary<NSString *, NSObject *> *> *asfAttributes = StructuredArray(metadata, @"asfAttributes");

    if (format == AudioMatorTagFileFormatMPEGID3) {
        TagLib::MPEG::File file(filePath);
        if (!file.isValid()) {
            if (error) *error = [NSError errorWithDomain:@"TagLibMetadataExtractor" code:232 userInfo:@{ NSLocalizedDescriptionKey : @"Unable to open MPEG file for structured metadata editing" }];
            return NO;
        }
        if (propertyValues) {
            file.setProperties(BuildRawPropertyMapValues(propertyValues));
        }
        TagLib::ID3v2::Tag *tag = file.ID3v2Tag(true);
        UpsertID3v2StructuredFrames(tag, frames);
        ReplaceID3v2Comments(tag, comments);
        ReplaceID3v2Lyrics(tag, lyrics);
        ReplaceID3v2Artwork(tag, artwork);
        if (!file.save(TagLib::MPEG::File::ID3v2,
                       TagLib::File::StripNone,
                       TagLib::ID3v2::v4,
                       TagLib::File::DoNotDuplicate)) {
            if (error) *error = [NSError errorWithDomain:@"TagLibMetadataExtractor" code:233 userInfo:@{ NSLocalizedDescriptionKey : @"TagLib failed to save structured MPEG metadata" }];
            return NO;
        }
        return YES;
    }

    if (format == AudioMatorTagFileFormatWAV) {
        TagLib::RIFF::WAV::File file(filePath);
        if (!file.isValid()) {
            if (error) *error = [NSError errorWithDomain:@"TagLibMetadataExtractor" code:234 userInfo:@{ NSLocalizedDescriptionKey : @"Unable to open WAV file for structured metadata editing" }];
            return NO;
        }
        if (propertyValues) {
            file.setProperties(BuildRawPropertyMapValues(propertyValues));
        }
        TagLib::ID3v2::Tag *tag = file.ID3v2Tag();
        UpsertID3v2StructuredFrames(tag, frames);
        ReplaceID3v2Comments(tag, comments);
        ReplaceID3v2Lyrics(tag, lyrics);
        ReplaceID3v2Artwork(tag, artwork);
        if (!file.save()) {
            if (error) *error = [NSError errorWithDomain:@"TagLibMetadataExtractor" code:235 userInfo:@{ NSLocalizedDescriptionKey : @"TagLib failed to save structured WAV metadata" }];
            return NO;
        }
        return YES;
    }

    if (format == AudioMatorTagFileFormatAIFF) {
        TagLib::RIFF::AIFF::File file(filePath);
        if (!file.isValid()) {
            if (error) *error = [NSError errorWithDomain:@"TagLibMetadataExtractor" code:236 userInfo:@{ NSLocalizedDescriptionKey : @"Unable to open AIFF file for structured metadata editing" }];
            return NO;
        }
        if (propertyValues) {
            file.setProperties(BuildRawPropertyMapValues(propertyValues));
        }
        TagLib::ID3v2::Tag *tag = file.tag();
        UpsertID3v2StructuredFrames(tag, frames);
        ReplaceID3v2Comments(tag, comments);
        ReplaceID3v2Lyrics(tag, lyrics);
        ReplaceID3v2Artwork(tag, artwork);
        if (!file.save()) {
            if (error) *error = [NSError errorWithDomain:@"TagLibMetadataExtractor" code:237 userInfo:@{ NSLocalizedDescriptionKey : @"TagLib failed to save structured AIFF metadata" }];
            return NO;
        }
        return YES;
    }

    if (format == AudioMatorTagFileFormatMP4) {
        TagLib::MP4::File file(filePath);
        if (!file.isValid() || !file.tag()) {
            if (error) *error = [NSError errorWithDomain:@"TagLibMetadataExtractor" code:238 userInfo:@{ NSLocalizedDescriptionKey : @"Unable to open MP4 file for structured metadata editing" }];
            return NO;
        }
        if (propertyValues) {
            file.setProperties(BuildRawPropertyMapValues(propertyValues));
        }
        ApplyStructuredMP4Atoms(file.tag(), mp4Atoms);
        if (!ReplaceStructuredComplexArtwork(file.tag(), artwork)) {
            if (error) *error = [NSError errorWithDomain:@"TagLibMetadataExtractor" code:243 userInfo:@{ NSLocalizedDescriptionKey : @"TagLib failed to apply structured MP4 artwork" }];
            return NO;
        }
        if (!file.save()) {
            if (error) *error = [NSError errorWithDomain:@"TagLibMetadataExtractor" code:239 userInfo:@{ NSLocalizedDescriptionKey : @"TagLib failed to save structured MP4 metadata" }];
            return NO;
        }
        return YES;
    }

    if (format == AudioMatorTagFileFormatASF) {
        TagLib::ASF::File file(filePath);
        if (!file.isValid() || !file.tag()) {
            if (error) *error = [NSError errorWithDomain:@"TagLibMetadataExtractor" code:240 userInfo:@{ NSLocalizedDescriptionKey : @"Unable to open ASF/WMA file for structured metadata editing" }];
            return NO;
        }
        if (propertyValues) {
            file.setProperties(BuildRawPropertyMapValues(propertyValues));
        }
        ApplyStructuredASFAttributes(file.tag(), asfAttributes);
        if (!ReplaceStructuredComplexArtwork(file.tag(), artwork)) {
            if (error) *error = [NSError errorWithDomain:@"TagLibMetadataExtractor" code:244 userInfo:@{ NSLocalizedDescriptionKey : @"TagLib failed to apply structured ASF artwork" }];
            return NO;
        }
        if (!file.save()) {
            if (error) *error = [NSError errorWithDomain:@"TagLibMetadataExtractor" code:241 userInfo:@{ NSLocalizedDescriptionKey : @"TagLib failed to save structured ASF/WMA metadata" }];
            return NO;
        }
        return YES;
    }

    if (propertyValues) {
        return [self writeRawPropertyMapValues:propertyValues toURL:fileURL error:error];
    }

    if (error) {
        *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                     code:242
                                 userInfo:@{ NSLocalizedDescriptionKey : @"Structured metadata writing for this format is limited to raw PropertyMap values" }];
    }
    return NO;
    TAGLIB_BRIDGE_CATCH_WITH_ERROR(error, @"Structured metadata write", NO)
}

// Return a best-effort, "raw" view of metadata as TagLib sees it.
// This is intended for displaying to users in a GUI, not for programmatic editing.
