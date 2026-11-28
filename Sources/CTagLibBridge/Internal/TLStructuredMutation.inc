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
    NSString *string = [value isKindOfClass:[NSNumber class]]
        ? ((NSNumber *)value).stringValue
        : TrimmedStringOrNil((NSString *)value);
    if (!string) return NO;

    const char *utf8 = string.UTF8String;
    if (!utf8) return NO;
    errno = 0;
    char *end = nullptr;
    long long number = std::strtoll(utf8, &end, 10);
    return errno != ERANGE && end && end != utf8 && *end == '\0' &&
        number >= std::numeric_limits<int>::min() && number <= std::numeric_limits<int>::max();
}

static NSInteger IntegerValueFromObject(NSObject *value);

static BOOL StructuredOptionalPictureTypeCodeIsValid(NSDictionary *entry, NSString *key)
{
    if (!entry[key]) return YES;
    if (!StructuredOptionalValueFitsInt(entry, key)) return NO;
    const NSInteger value = IntegerValueFromObject(entry[key]);
    return value >= TagLib::ID3v2::AttachedPictureFrame::Other &&
        value <= TagLib::ID3v2::AttachedPictureFrame::PublisherLogo;
}

static BOOL StructuredOptionalValueFitsUInt32(NSDictionary *entry, NSString *key)
{
    NSObject *value = entry[key];
    if (!value) return YES;
    if (![value isKindOfClass:[NSNumber class]] && ![value isKindOfClass:[NSString class]]) return NO;
    NSString *string = [value isKindOfClass:[NSNumber class]]
        ? ((NSNumber *)value).stringValue
        : (NSString *)value;
    unsigned long long parsed = 0;
    return ParseUnsignedDecimalString(string, std::numeric_limits<unsigned int>::max(), parsed);
}

static BOOL StructuredOptionalValueFitsUInt8(NSDictionary *entry, NSString *key)
{
    NSObject *value = entry[key];
    if (!value) return YES;
    if (![value isKindOfClass:[NSNumber class]] && ![value isKindOfClass:[NSString class]]) return NO;
    NSString *string = [value isKindOfClass:[NSNumber class]]
        ? ((NSNumber *)value).stringValue
        : (NSString *)value;
    unsigned long long parsed = 0;
    return ParseUnsignedDecimalString(string, std::numeric_limits<unsigned char>::max(), parsed);
}

static BOOL StructuredOptionalValueFitsInt64(NSDictionary *entry, NSString *key)
{
    NSObject *value = entry[key];
    if (!value) return YES;
    if (![value isKindOfClass:[NSNumber class]] && ![value isKindOfClass:[NSString class]]) return NO;

    NSString *string = [value isKindOfClass:[NSNumber class]]
        ? ((NSNumber *)value).stringValue
        : TrimmedStringOrNil((NSString *)value);
    if (!string) return NO;
    const char *utf8 = string.UTF8String;
    if (!utf8) return NO;
    errno = 0;
    char *end = nullptr;
    (void)std::strtoll(utf8, &end, 10);
    return errno != ERANGE && end && end != utf8 && *end == '\0';
}

static BOOL StructuredOptionalValueIsBooleanLike(NSDictionary *entry, NSString *key)
{
    NSObject *value = entry[key];
    return !value || [value isKindOfClass:[NSNumber class]] || [value isKindOfClass:[NSString class]];
}

static BOOL StructuredIntegerValueWithinRange(NSDictionary *entry,
                                              NSString *key,
                                              long long minimum,
                                              long long maximum)
{
    NSObject *value = entry[key];
    if (!value) return NO;
    NSString *string = [value isKindOfClass:[NSNumber class]]
        ? ((NSNumber *)value).stringValue
        : TrimmedStringOrNil((NSString *)value);
    if (!string) return NO;
    const char *utf8 = string.UTF8String;
    if (!utf8) return NO;
    errno = 0;
    char *end = nullptr;
    long long parsed = std::strtoll(utf8, &end, 10);
    return errno != ERANGE && end && end != utf8 && *end == '\0' &&
        parsed >= minimum && parsed <= maximum;
}

// Structured inspection emits these exact type tokens. Callers may use them
// verbatim; anything else is an unsupported encoding, not an implicit default.
static NSString * _Nullable CanonicalMP4AtomType(NSString * _Nullable type)
{
    NSString *normalized = UppercaseTrimmedString(type);
    if (!normalized) return nil;
    NSDictionary<NSString *, NSString *> *known = @{
        @"STRINGLIST": @"stringList",
        @"INT": @"int",
        @"UINT": @"uint",
        @"BYTE": @"byte",
        @"LONGLONG": @"longLong",
        @"BOOL": @"bool",
        @"INTPAIR": @"intPair",
    };
    return known[normalized];
}

static NSString * _Nullable CanonicalASFAttributeType(NSString * _Nullable type)
{
    NSString *normalized = UppercaseTrimmedString(type);
    if (!normalized) return nil;
    NSDictionary<NSString *, NSString *> *known = @{
        @"STRING": @"string",
        @"BOOL": @"bool",
        @"INT": @"int",
        @"INT64": @"int64",
        @"BINARY": @"binary",
        @"GUID": @"guid",
    };
    return known[normalized];
}

static BOOL StructuredBooleanIsValid(NSObject *value)
{
    if ([value isKindOfClass:[NSNumber class]]) {
        return [(NSNumber *)value isEqualToNumber:@0] || [(NSNumber *)value isEqualToNumber:@1];
    }
    if (![value isKindOfClass:[NSString class]]) return NO;
    NSString *text = [TrimmedStringOrNil((NSString *)value) lowercaseString];
    return [@[ @"0", @"1", @"true", @"false", @"yes", @"no", @"on", @"off" ] containsObject:text ?: @""];
}

static bool BooleanValueFromObject(NSObject *value);

static BOOL ValidateMP4NativeEncoding(NSString *key, NSString *type, NSDictionary *entry, NSError **error)
{
    using Kind = NativeMP4Codec::Kind;
    auto reject = [&]() -> BOOL {
        return SetStructuredPayloadValidationError(error,
            [NSString stringWithFormat:@"MP4 atom %@ has an incompatible codec, value or native range", key]);
    };
    const bool removing = BooleanValueFromObject(entry[@"remove"]);
    const auto kind = NativeMP4Codec::forKey(key);
    if (removing) {
        NSArray *parts = [key componentsSeparatedByString:@":"];
        if ([key hasPrefix:@"----:"]) {
            return parts.count == 3 && [parts[1] length] && [parts[2] length] ? YES : reject();
        }
        return [key lengthOfBytesUsingEncoding:NSISOLatin1StringEncoding] == 4 ? YES : reject();
    }
    if ([type isEqual:@"stringList"] && ![entry[@"values"] isKindOfClass:[NSArray class]]) return reject();
    const bool numeric = [@[ @"int", @"uint", @"byte", @"longLong" ] containsObject:type];
    const bool text = [type isEqualToString:@"stringList"];
    auto ranged = [&](long long maximum) -> BOOL {
        return numeric && (removing || StructuredIntegerValueWithinRange(entry, @"value", 0, maximum));
    };
    switch (kind) {
        case Kind::IntPair:
        case Kind::IntPairNoTrailing:
            return [type isEqualToString:@"intPair"] && (removing ||
                (StructuredIntegerValueWithinRange(entry, @"first", 0, 65535) &&
                 StructuredIntegerValueWithinRange(entry, @"second", 0, 65535))) ? YES : reject();
        case Kind::Bool:
            return [type isEqualToString:@"bool"] && (removing || StructuredBooleanIsValid(entry[@"value"])) ? YES : reject();
        case Kind::Int:
            if ([key isEqual:@"hdvd"] && [type isEqual:@"bool"]) {
                return removing || StructuredBooleanIsValid(entry[@"value"]) ? YES : reject();
            }
            return ranged(32767) ? YES : reject();
        case Kind::Gnre:
            return ranged(255) ? YES : reject();
        case Kind::Byte:
            return ranged(255) ? YES : reject();
        case Kind::UInt:
            return ranged(std::numeric_limits<unsigned int>::max()) ? YES : reject();
        case Kind::LongLong:
            return ranged(std::numeric_limits<long long>::max()) ? YES : reject();
        case Kind::TextOrInt:
            return text || ranged(32767) ? YES : reject();
        case Kind::FreeForm: {
            NSArray *parts = [key componentsSeparatedByString:@":"];
            return text && parts.count == 3 && [parts[0] isEqual:@"----"] &&
                [parts[1] length] && [parts[2] length] ? YES : reject();
        }
        case Kind::Text:
        case Kind::TextImplicit:
            return text && [key lengthOfBytesUsingEncoding:NSISOLatin1StringEncoding] == 4 ? YES : reject();
        default:
            // Binary artwork/stem encoders are not represented by atom scalars.
            return reject();
    }
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
        if (type) {
            const bool supportedType =
                [type isEqualToString:@"text"] ||
                [type isEqualToString:@"versionedText"] ||
                [type isEqualToString:@"userText"] ||
                [type isEqualToString:@"url"] ||
                [type isEqualToString:@"ufid"] ||
                [type isEqualToString:@"chapter"] ||
                [type isEqualToString:@"tableOfContents"] ||
                [type isEqualToString:@"podcast"];
            if (!supportedType) {
                if ([type isEqualToString:@"artwork"] || [type isEqualToString:@"comment"] || [type isEqualToString:@"lyrics"]) {
                    return SetStructuredPayloadValidationError(
                        error,
                        [NSString stringWithFormat:@"ID3v2 frame type '%@' must be edited through the dedicated artwork, comments, or lyrics collection", type]
                    );
                }
                return SetStructuredPayloadValidationError(
                    error,
                    [NSString stringWithFormat:@"Unsupported structured ID3v2 frame type '%@'", type]
                );
            }
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
        if ([type isEqualToString:@"versionedText"] &&
            (!StructuredOptionalValueHasClass(entry, @"v23Id", [NSString class]) ||
             !StructuredOptionalValueHasClass(entry, @"v24Id", [NSString class]) ||
             !StructuredOptionalValueHasClass(entry, @"v23Description", [NSString class]) ||
             !StructuredOptionalValueHasClass(entry, @"v24Description", [NSString class]) ||
             !TrimmedStringOrNil((NSString *)(entry[@"v23Id"] ?: entry[@"v23Description"] ?: @"")) ||
             !TrimmedStringOrNil((NSString *)(entry[@"v24Id"] ?: entry[@"v24Description"] ?: @"")))) {
            return SetStructuredPayloadValidationError(error, @"Versioned text frames require a v2.3 and a v2.4 identity");
        }
        if ([type isEqualToString:@"url"] &&
            (![frameID hasPrefix:@"W"] || !TrimmedStringOrNil((NSString *)entry[@"url"]))) {
            return SetStructuredPayloadValidationError(error, @"URL frames require a W-prefixed frame ID and a non-empty URL; empty payloads are not removal operations");
        }
        if ([type isEqualToString:@"ufid"] &&
            (![frameID isEqualToString:@"UFID"] || !TrimmedStringOrNil((NSString *)entry[@"owner"]) ||
             DataValueFromObject(entry[@"data"]).length == 0)) {
            return SetStructuredPayloadValidationError(error, @"UFID requires an owner and non-empty identifier; empty payloads are not removal operations");
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
        NSString *rawType = [entry[@"type"] isKindOfClass:[NSString class]] ? (NSString *)entry[@"type"] : nil;
        NSString *type = CanonicalMP4AtomType(rawType);
        NSString *key = [entry[@"key"] isKindOfClass:[NSString class]] ? TrimmedStringOrNil((NSString *)entry[@"key"]) : nil;
        if (!key || !type ||
            (entry[@"value"] && ![entry[@"value"] isKindOfClass:[NSString class]] && ![entry[@"value"] isKindOfClass:[NSNumber class]]) ||
            (entry[@"values"] && !StructuredValueIsStringArray(entry[@"values"])) ||
            !StructuredOptionalValueHasClass(entry, @"freeformDescription", [NSString class]) ||
            (entry[@"remove"] && !StructuredOptionalValueIsBooleanLike(entry, @"remove"))) {
            return SetStructuredPayloadValidationError(
                error,
                rawType
                    ? [NSString stringWithFormat:@"Unsupported MP4 atom type '%@'", rawType]
                    : @"MP4 atom fields have invalid value types"
            );
        }
        if (entry[@"remove"] && !StructuredBooleanIsValid(entry[@"remove"])) {
            return SetStructuredPayloadValidationError(error, @"MP4 removal requires an explicit Boolean");
        }
        if (!ValidateMP4NativeEncoding(key, type, entry, error)) return NO;
        const BOOL removing = BooleanValueFromObject(entry[@"remove"]);
        if (([key isEqualToString:@"trkn"] || [key isEqualToString:@"disk"]) && !removing) {
            // trkn/disk components are unsigned 16-bit values in the native
            // intPair. A wider value would be truncated by TagLib on write.
            if (!StructuredIntegerValueWithinRange(entry, @"first", 0, 65535) ||
                !StructuredIntegerValueWithinRange(entry, @"second", 0, 65535)) {
                return SetStructuredPayloadValidationError(
                    error,
                    @"MP4 track/disc intPair components must be unsigned 16-bit values between 0 and 65535"
                );
            }
        }
        if (([key isEqualToString:@"©mvi"] || [key isEqualToString:@"©mvc"]) && !removing) {
            if (!StructuredIntegerValueWithinRange(entry, @"value", 0, 32767)) {
                return SetStructuredPayloadValidationError(error, @"MP4 movement integers must be between 0 and 32767");
            }
        }
        if (([type isEqualToString:@"int"] && !removing && !StructuredOptionalValueFitsInt(entry, @"value")) ||
            ([type isEqualToString:@"uint"] && !removing && !StructuredOptionalValueFitsUInt32(entry, @"value")) ||
            ([type isEqualToString:@"byte"] && !removing && !StructuredOptionalValueFitsUInt8(entry, @"value")) ||
            ([type isEqualToString:@"longLong"] && !removing && !StructuredOptionalValueFitsInt64(entry, @"value")) ||
            ([type isEqualToString:@"intPair"] && !removing &&
             (!StructuredOptionalValueFitsInt(entry, @"first") || !StructuredOptionalValueFitsInt(entry, @"second")))) {
            return SetStructuredPayloadValidationError(error, @"MP4 atom numeric value is outside its declared type range");
        }
    }

    for (NSDictionary *entry in StructuredArray(metadata, @"asfAttributes") ?: @[]) {
        NSString *rawType = [entry[@"type"] isKindOfClass:[NSString class]] ? (NSString *)entry[@"type"] : nil;
        NSString *type = CanonicalASFAttributeType(rawType);
        if (![entry[@"key"] isKindOfClass:[NSString class]] || !TrimmedStringOrNil((NSString *)entry[@"key"]) || !type ||
            (entry[@"value"] && ![entry[@"value"] isKindOfClass:[NSString class]] && ![entry[@"value"] isKindOfClass:[NSNumber class]]) ||
            !StructuredOptionalDataFitsTagLib(entry, @"data") ||
            !StructuredOptionalValueHasClass(entry, @"pictureType", [NSString class]) ||
            !StructuredOptionalValueHasClass(entry, @"mimeType", [NSString class]) ||
            !StructuredOptionalValueHasClass(entry, @"description", [NSString class]) ||
            !StructuredOptionalValueFitsInt(entry, @"language") ||
            !StructuredOptionalValueFitsInt(entry, @"stream")) {
            return SetStructuredPayloadValidationError(
                error,
                rawType
                    ? [NSString stringWithFormat:@"Unsupported ASF attribute type '%@'", rawType]
                    : @"ASF attribute fields have invalid value types"
            );
        }
        if ([type isEqualToString:@"guid"]) {
            // The pinned public Attribute API cannot construct GuidType.
            // Encoding as BytesType would silently change native identity.
            return SetStructuredPayloadValidationError(error,
                @"ASF GUID attributes are inspection-only with the pinned TagLib encoder");
        }
        if ([type isEqualToString:@"string"] && ![entry[@"value"] isKindOfClass:[NSString class]]) {
            return SetStructuredPayloadValidationError(error, @"ASF string attributes require string text");
        }
        if ([type isEqualToString:@"binary"] && ![entry[@"data"] isKindOfClass:[NSData class]]) {
            return SetStructuredPayloadValidationError(error, @"ASF binary attributes require NSData");
        }
        if ([type isEqualToString:@"bool"] && !StructuredBooleanIsValid(entry[@"value"])) {
            return SetStructuredPayloadValidationError(error, @"ASF Boolean attributes require a Boolean value");
        }
        if ([type isEqualToString:@"int64"]) {
            unsigned long long value = 0;
            if (!UnsignedLongLongValueFromObject(entry[@"value"], value)) {
                return SetStructuredPayloadValidationError(error, @"ASF int64 attributes require an unsigned 64-bit value");
            }
        } else if ([type isEqualToString:@"int"] && (!entry[@"value"] || !StructuredOptionalValueFitsUInt32(entry, @"value"))) {
            return SetStructuredPayloadValidationError(error, @"ASF integer attributes require an unsigned 32-bit value");
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
            !StructuredOptionalPictureTypeCodeIsValid(entry, @"pictureTypeCode")) {
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

static TagLib::StringList StructuredID3v2TextValues(NSDictionary<NSString *, NSObject *> *entry)
{
    TagLib::StringList values;
    NSArray<NSString *> *suppliedValues = [entry[@"values"] isKindOfClass:[NSArray class]]
        ? (NSArray<NSString *> *)entry[@"values"]
        : nil;
    if (suppliedValues.count > 0) {
        for (NSString *value in suppliedValues) {
            values.append(NSStringToTagString(value));
        }
    } else if ([entry[@"value"] isKindOfClass:[NSString class]] && ((NSString *)entry[@"value"]).length > 0) {
        values.append(NSStringToTagString((NSString *)entry[@"value"]));
    }
    return values;
}

template <typename Picture>
static typename Picture::Type StructuredPictureType(NSDictionary<NSString *, NSObject *> *entry)
{
    if (entry[@"pictureTypeCode"]) {
        return static_cast<typename Picture::Type>(IntegerValueFromObject(entry[@"pictureTypeCode"]));
    }
    NSString *name = TrimmedStringOrNil((NSString *)entry[@"pictureType"]);
    if (name) {
        const typename Picture::Type parsed = Picture::typeFromString(NSStringToTagString(name));
        NSString *canonical = TagStringToNSString(Picture::typeToString(parsed));
        if ([canonical caseInsensitiveCompare:name] == NSOrderedSame) return parsed;
    }
    return Picture::FrontCover;
}

static void SetStructuredID3v2TextFrame(TagLib::ID3v2::Tag *tag,
                                        NSString *frameID,
                                        const TagLib::StringList &values)
{
    const char *frameIDBytes = frameID.UTF8String;
    if (!tag || !frameIDBytes || std::strlen(frameIDBytes) != 4) return;

    TagLib::ID3v2::FrameList frames = tag->frameList(frameIDBytes);
    if (values.isEmpty()) {
        for (auto it = frames.begin(); it != frames.end(); ++it) tag->removeFrame(*it);
        return;
    }

    auto *textFrame = frames.isEmpty()
        ? nullptr
        : dynamic_cast<TagLib::ID3v2::TextIdentificationFrame *>(frames.front());
    if (!textFrame) {
        textFrame = new TagLib::ID3v2::TextIdentificationFrame(
            TagLib::ByteVector(frameIDBytes, 4),
            TagLib::String::UTF8
        );
        tag->addFrame(textFrame);
    }
    textFrame->setText(values);
}

static void SetStructuredID3v2UserTextFrame(TagLib::ID3v2::Tag *tag,
                                            NSString *description,
                                            const TagLib::StringList &values)
{
    if (!tag || !description) return;
    const TagLib::String tagDescription = NSStringToTagString(description);
    auto *userFrame = TagLib::ID3v2::UserTextIdentificationFrame::find(tag, tagDescription);
    if (values.isEmpty()) {
        if (userFrame) tag->removeFrame(userFrame);
        return;
    }
    if (!userFrame) {
        userFrame = new TagLib::ID3v2::UserTextIdentificationFrame(TagLib::String::UTF8);
        userFrame->setDescription(tagDescription);
        tag->addFrame(userFrame);
    }
    userFrame->setText(values);
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
        frame->setType(StructuredPictureType<TagLib::ID3v2::AttachedPictureFrame>(entry));
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
        NSString *pictureType = TrimmedStringOrNil((NSString *)entry[@"pictureType"]);
        if (!pictureType && entry[@"pictureTypeCode"]) {
            const auto type = static_cast<TagLib::ID3v2::AttachedPictureFrame::Type>(
                IntegerValueFromObject(entry[@"pictureTypeCode"])
            );
            pictureType = TagStringToNSString(TagLib::ID3v2::AttachedPictureFrame::typeToString(type));
        }
        if (!pictureType) pictureType = @"Front Cover";
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
            if (!owner) continue;
            TagLib::ID3v2::UniqueFileIdentifierFrame *existing =
                TagLib::ID3v2::UniqueFileIdentifierFrame::findByOwner(tag, NSStringToTagString(owner));
            if (existing) tag->removeFrame(existing);
            if (data.length == 0) continue;
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
            SetStructuredID3v2TextFrame(tag, frameID, StructuredID3v2TextValues(entry));
        } else if ([type isEqualToString:@"versionedText"]) {
            NSString *v23Id = TrimmedStringOrNil((NSString *)entry[@"v23Id"]);
            NSString *v24Id = TrimmedStringOrNil((NSString *)entry[@"v24Id"]);
            NSString *v23Description = TrimmedStringOrNil((NSString *)entry[@"v23Description"]);
            NSString *v24Description = TrimmedStringOrNil((NSString *)entry[@"v24Description"]);
            for (NSString *identifier in @[ v23Id ?: @"", v24Id ?: @"" ]) {
                if (identifier.length == 4) {
                    SetStructuredID3v2TextFrame(tag, identifier, TagLib::StringList());
                }
            }
            for (NSString *description in @[ v23Description ?: @"", v24Description ?: @"" ]) {
                if (description.length > 0) {
                    SetStructuredID3v2UserTextFrame(tag, description, TagLib::StringList());
                }
            }
            const bool version3 = tag->header() && tag->header()->majorVersion() == 3;
            NSString *chosenId = version3 ? v23Id : v24Id;
            NSString *chosenDescription = version3 ? v23Description : v24Description;
            TagLib::StringList values = StructuredID3v2TextValues(entry);
            if (chosenDescription.length > 0) {
                SetStructuredID3v2UserTextFrame(tag, chosenDescription, values);
            } else if (chosenId.length == 4) {
                SetStructuredID3v2TextFrame(tag, chosenId, values);
            }
        } else if ([type isEqualToString:@"userText"]) {
            SetStructuredID3v2UserTextFrame(
                tag,
                (NSString *)entry[@"description"] ?: @"",
                StructuredID3v2TextValues(entry)
            );
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
        NSString *type = CanonicalMP4AtomType((NSString *)entry[@"type"]);
        if (!key || !type) continue;

        if (BooleanValueFromObject(entry[@"remove"])) {
            tag->removeItem(NSStringToTagString(key));
            continue;
        }
        if ([type isEqualToString:@"stringList"]) {
            TagLib::StringList list;
            NSArray<NSString *> *values = (NSArray<NSString *> *)entry[@"values"];
            for (NSString *value in values ?: @[]) {
                // Structured arrays are exact values, not display text.
                // Semantic callers already normalize their own text intent.
                list.append(NSStringToTagString(value));
            }
            if (list.isEmpty()) tag->removeItem(NSStringToTagString(key));
            else tag->setItem(NSStringToTagString(key), TagLib::MP4::Item(list));
        } else if ([type isEqualToString:@"bool"]) {
            const bool boolValue = BooleanValueFromObject(entry[@"value"]);
            const bool integerCodec = NativeMP4Codec::forKey(key) == NativeMP4Codec::Kind::Int;
            tag->setItem(NSStringToTagString(key), integerCodec ? TagLib::MP4::Item((int)boolValue) : TagLib::MP4::Item(boolValue));
        } else if ([type isEqualToString:@"int"] || [type isEqualToString:@"uint"] ||
                   [type isEqualToString:@"byte"] || [type isEqualToString:@"longLong"]) {
            using Kind = NativeMP4Codec::Kind;
            const auto kind = NativeMP4Codec::forKey(key);
            const NSInteger value = IntegerValueFromObject(entry[@"value"]);
            TagLib::MP4::Item item = kind == Kind::Byte ? TagLib::MP4::Item((unsigned char)value)
                : kind == Kind::UInt ? TagLib::MP4::Item((unsigned int)value)
                : kind == Kind::LongLong ? TagLib::MP4::Item((long long)value)
                : TagLib::MP4::Item((int)value);
            tag->setItem(NSStringToTagString(key), item);
        } else if ([type isEqualToString:@"intPair"]) {
            tag->setItem(NSStringToTagString(key), TagLib::MP4::Item(
                (int)IntegerValueFromObject(entry[@"first"]),
                (int)IntegerValueFromObject(entry[@"second"])
            ));
        }
    }
}

static bool ReplaceStructuredAPEFrontArtwork(TagLib::APE::Tag *tag,
                                                NSArray<NSDictionary<NSString *, NSObject *> *> *artwork)
{
    if (!tag) return false;
    if (!artwork) return true;
    if (artwork.count > 1) return false;
    TagLibAudioMetadata *temporary = [[TagLibAudioMetadata alloc] init];
    if (artwork.count == 0) {
        temporary.removeArtwork = true;
    } else {
        NSData *data = DataValueFromObject(artwork.firstObject[@"data"]);
        if (data.length == 0) return false;
        temporary.artworkData = data;
        temporary.artworkMimeType = (NSString *)artwork.firstObject[@"mimeType"] ?: @"image/jpeg";
    }
    NSError *artworkError = nil;
    const bool ok = ApplyPictureComplexProperties(
        tag,
        temporary,
        &artworkError,
        252,
        @"Unable to clear artwork from the APE tag",
        253,
        @"Unable to write artwork into the APE tag",
        @"APE-family structured artwork"
    );
    return ok;
}

static void ReplaceStructuredASFArtwork(TagLib::ASF::Tag *tag,
                                         NSArray<NSDictionary<NSString *, NSObject *> *> *artwork)
{
    if (!tag || !artwork) return;
    tag->removeItem("WM/Picture");
    for (NSDictionary<NSString *, NSObject *> *entry in artwork ?: @[]) {
        NSData *data = DataValueFromObject(entry[@"data"]);
        if (data.length == 0) continue;
        TagLib::ASF::Picture picture;
        picture.setMimeType(NSStringToTagString((NSString *)entry[@"mimeType"] ?: @"image/jpeg"));
        picture.setDescription(NSStringToTagString((NSString *)entry[@"description"]));
        picture.setType(StructuredPictureType<TagLib::ASF::Picture>(entry));
        picture.setPicture(TagLib::ByteVector((const char *)data.bytes, (unsigned int)data.length));
        tag->addAttribute("WM/Picture", TagLib::ASF::Attribute(picture));
    }
}

static BOOL ApplyStructuredASFAttributes(TagLib::ASF::Tag *tag,
                                         NSArray<NSDictionary<NSString *, NSObject *> *> *attributes,
                                         NSError **error)
{
    if (!tag || !attributes) return YES;
    for (NSDictionary<NSString *, NSObject *> *entry in attributes) {
        NSString *key = TrimmedStringOrNil((NSString *)entry[@"key"]);
        // Validation canonicalizes with the same helper. Unknown tokens never
        // reach this dispatch; "String" cannot silently fall into the int path.
        NSString *type = CanonicalASFAttributeType((NSString *)entry[@"type"]);
        if (!key || !type) continue;

        TagLib::ASF::Attribute attribute;
        if ([key isEqualToString:@"WM/Picture"]) {
            NSData *data = DataValueFromObject(entry[@"data"]);
            if (data.length == 0) continue;
            TagLib::ASF::Picture picture;
            picture.setMimeType(NSStringToTagString((NSString *)entry[@"mimeType"] ?: @"image/jpeg"));
            picture.setDescription(NSStringToTagString((NSString *)entry[@"description"]));
            picture.setType(StructuredPictureType<TagLib::ASF::Picture>(entry));
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
            // The public "int" projection represents both WORD and DWORD.
            // Retain an existing WORD's width instead of adding a DWORD sibling.
            bool hasWord = false;
            bool hasDWord = false;
            for (const auto &existing : tag->attribute(NSStringToTagString(key))) {
                if (existing.language() == IntegerValueFromObject(entry[@"language"]) &&
                    existing.stream() == IntegerValueFromObject(entry[@"stream"])) {
                    hasWord |= existing.type() == TagLib::ASF::Attribute::WordType;
                    hasDWord |= existing.type() == TagLib::ASF::Attribute::DWordType;
                }
            }
            if (hasWord && hasDWord) {
                return SetStructuredPayloadValidationError(error,
                    @"ASF int update is ambiguous between existing WORD and DWORD attributes");
            }
            const unsigned int value = (unsigned int)IntegerValueFromObject(entry[@"value"]);
            if (hasWord) {
                if (value > std::numeric_limits<unsigned short>::max()) {
                    return SetStructuredPayloadValidationError(error,
                        @"ASF WORD update requires an unsigned 16-bit value");
                }
                attribute = TagLib::ASF::Attribute((unsigned short)value);
            } else {
                attribute = TagLib::ASF::Attribute(value);
            }
        }
        attribute.setLanguage((int)IntegerValueFromObject(entry[@"language"]));
        attribute.setStream((int)IntegerValueFromObject(entry[@"stream"]));

        TagLib::String tagKey = NSStringToTagString(key);
        TagLib::ASF::AttributeList values = tag->attribute(tagKey);
        bool replaced = false;
        for (auto iterator = values.begin(); iterator != values.end(); ++iterator) {
            if (iterator->language() == attribute.language() &&
                iterator->stream() == attribute.stream() &&
                iterator->type() == attribute.type()) {
                *iterator = attribute;
                replaced = true;
                break;
            }
        }
        if (!replaced) {
            values.append(attribute);
        }
        tag->setAttribute(tagKey, values);
    }
    return YES;
}

// A structured payload must not carry a collection the selected format does
// not consume. Silently discarding a populated collection is a false success;
// fail before opening or saving the destination.
static BOOL ValidateStructuredCollectionsForFormat(TLTagFileFormat format,
                                                   NSDictionary<NSString *, NSObject *> *metadata,
                                                   NSError **error)
{
    NSArray *frames = StructuredArray(metadata, @"id3v2Frames");
    NSArray *mp4Atoms = StructuredArray(metadata, @"mp4Atoms");
    NSArray *asfAttributes = StructuredArray(metadata, @"asfAttributes");
    NSArray *lyrics = StructuredArray(metadata, @"lyrics");
    NSArray *comments = StructuredArray(metadata, @"comments");

    auto reject = [&](NSString *message) -> BOOL {
        return SetStructuredPayloadValidationError(error, message);
    };
    // Presence is explicit intent: an empty collection still names a
    // destination surface this format does not implement.
    auto present = [&](NSString *key) -> bool { return metadata[key] != nil; };

    switch (format) {
        case TLTagFileFormatMPEGID3:
        case TLTagFileFormatMPEGAAC:
            if (present(@"mp4Atoms") || present(@"asfAttributes")) {
                return reject(@"MPEG ID3 containers accept ID3v2 frames, comments, lyrics, artwork and PropertyMap values; MP4/ASF collections are not consumed");
            }
            break;
        case TLTagFileFormatMP4:
            if (present(@"id3v2Frames") || present(@"asfAttributes") || present(@"lyrics") || present(@"comments")) {
                return reject(@"MP4 accepts MP4 atoms, PropertyMap values and structured artwork; ID3/ASF/comment/lyric collections are not consumed");
            }
            break;
        case TLTagFileFormatASF:
            if (present(@"id3v2Frames") || present(@"mp4Atoms") || present(@"lyrics") || present(@"comments")) {
                return reject(@"ASF accepts ASF attributes, PropertyMap values and structured artwork; ID3/MP4/comment/lyric collections are not consumed");
            }
            break;
        case TLTagFileFormatWAV:
        case TLTagFileFormatAIFF:
            if (present(@"mp4Atoms") || present(@"asfAttributes")) {
                return reject(@"WAV/AIFF accept ID3v2 frames, comments, lyrics, artwork and PropertyMap values; MP4/ASF collections are not consumed");
            }
            break;
        default:
            break;
    }
    return YES;
}

+ (BOOL)writeStructuredMetadata:(NSDictionary<NSString *, NSObject *> *)metadata
                          toURL:(NSURL *)fileURL
                          error:(NSError **)error
{
    try {
    if (!ValidateMetadataObjectStrings(metadata, error)) return NO;
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
    TLTagFileFormat format = DetectTagFileFormat(fileURL);
    if (!IsWritableTagFileFormat(format)) {
        if (error) {
            *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                         code:230
                                     userInfo:@{ NSLocalizedDescriptionKey : @"Unsupported audio format" }];
        }
        return NO;
    }
    if (!ValidateStructuredCollectionsForFormat(format, metadata, error)) {
        return NO;
    }

    if (TagLibAtomicMutationDepth == 0) {
        if (!RejectDirectID3v23Write(fileURL, @"structured metadata", error)) return NO;
        return PerformAtomicTagLibMutation(fileURL, error, @"Structured metadata write", ^BOOL(NSURL *temporaryURL, NSError **mutationError) {
            if (!RejectDirectID3v23Write(temporaryURL, @"structured metadata", mutationError)) return NO;
            return [self writeStructuredMetadata:metadata toURL:temporaryURL error:mutationError];
        });
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

    TAGLIB_BRIDGE_SERIAL_GUARD();
    if (format == TLTagFileFormatMP4 && propertyValues &&
        !ValidateMP4RequestedProperties(BuildRawPropertyMapValues(propertyValues), error)) return NO;

    if (format == TLTagFileFormatMPEGID3 || format == TLTagFileFormatMPEGAAC) {
        TagLib::MPEG::File file(filePath);
        if (!file.isValid()) {
            if (error) *error = [NSError errorWithDomain:@"TagLibMetadataExtractor" code:232 userInfo:@{ NSLocalizedDescriptionKey : @"Unable to open MPEG file for structured metadata editing" }];
            return NO;
        }
        if (propertyValues) {
            SetPropertiesPreservingNativeDates(&file, MergedRawPropertyMapValues(file.properties(), propertyValues));
        }
        TagLib::ID3v2::Tag *tag = PrepareMPEGID3v2Tag(file);
        UpsertID3v2StructuredFrames(tag, frames);
        ReplaceID3v2Comments(tag, comments);
        ReplaceID3v2Lyrics(tag, lyrics);
        ReplaceID3v2Artwork(tag, artwork);
        if (!file.save(TagLib::MPEG::File::ID3v2,
                       TagLib::File::StripNone,
                       ID3v2SaveVersion(tag),
                       TagLib::File::DoNotDuplicate)) {
            if (error) *error = [NSError errorWithDomain:@"TagLibMetadataExtractor" code:233 userInfo:@{ NSLocalizedDescriptionKey : @"TagLib failed to save structured MPEG metadata" }];
            return NO;
        }
        return YES;
    }

    if (format == TLTagFileFormatTTA) {
        if (mp4Atoms || asfAttributes) {
            return SetStructuredPayloadValidationError(error, @"TrueAudio supports ID3v2 collections only");
        }
        TagLib::TrueAudio::File file(filePath);
        if (!file.isValid()) {
            return SetStructuredPayloadValidationError(error, @"Unable to open TrueAudio file for structured metadata editing");
        }
        if (propertyValues) {
            SetPropertiesPreservingNativeDates(&file, MergedRawPropertyMapValues(file.properties(), propertyValues));
        }
        TagLib::ID3v2::Tag *tag = NativeID3v2TagForWrite(&file);
        UpsertID3v2StructuredFrames(tag, frames);
        ReplaceID3v2Comments(tag, comments);
        ReplaceID3v2Lyrics(tag, lyrics);
        ReplaceID3v2Artwork(tag, artwork);
        if (!file.save()) {
            return SetStructuredPayloadValidationError(error, @"TagLib failed to save structured TrueAudio metadata");
        }
        return YES;
    }

    if (format == TLTagFileFormatDSF || format == TLTagFileFormatDSDIFF) {
        // DSD tags expose native ID3 frames. Keep collection replacement for
        // comments/lyrics unsupported, but permit exact text-frame replay.
        if (mp4Atoms || asfAttributes || lyrics || comments) {
            return SetStructuredPayloadValidationError(error, @"DSD supports ID3 frames, PropertyMap values and artwork only");
        }
        TagLib::FileRef reference(filePath, true, TagLib::AudioProperties::Fast);
        auto *file = reference.file();
        if (!file || !file->isValid()) {
            return SetStructuredPayloadValidationError(error, @"Unable to open DSD file for structured metadata editing");
        }
        if (propertyValues) SetPropertiesPreservingNativeDates(file, MergedRawPropertyMapValues(file->properties(), propertyValues));
        auto *tag = NativeID3v2TagForWrite(file);
        UpsertID3v2StructuredFrames(tag, frames);
        ReplaceID3v2Artwork(tag, artwork);
        if (!SaveMetadataPreservingOtherTagSurfaces(file)) {
            return SetStructuredPayloadValidationError(error, @"TagLib failed to save structured DSD metadata");
        }
        return YES;
    }

    if (format == TLTagFileFormatAPE ||
        format == TLTagFileFormatWavPack ||
        format == TLTagFileFormatMPC) {
        if (frames || mp4Atoms || asfAttributes || lyrics || comments) {
            return SetStructuredPayloadValidationError(
                error,
                @"APE-family formats support structured PropertyMap values and artwork only"
            );
        }
        auto writeAPE = [&](auto &file) -> BOOL {
            if (!file.isValid()) {
                if (error) *error = [NSError errorWithDomain:@"TagLibMetadataExtractor" code:249 userInfo:@{ NSLocalizedDescriptionKey : @"Unable to open APE-family file for structured metadata editing" }];
                return NO;
            }
            if (propertyValues) {
                SetPropertiesPreservingNativeDates(&file, MergedRawPropertyMapValues(file.properties(), propertyValues));
            }
            if (!ReplaceStructuredAPEFrontArtwork(file.APETag(true), artwork)) {
                if (error) *error = [NSError errorWithDomain:@"TagLibMetadataExtractor" code:250 userInfo:@{ NSLocalizedDescriptionKey : @"TagLib failed to apply structured APE-family artwork" }];
                return NO;
            }
            if (!file.save()) {
                if (error) *error = [NSError errorWithDomain:@"TagLibMetadataExtractor" code:251 userInfo:@{ NSLocalizedDescriptionKey : @"TagLib failed to save structured APE-family metadata" }];
                return NO;
            }
            return YES;
        };
        if (format == TLTagFileFormatAPE) {
            TagLib::APE::File file(filePath);
            return writeAPE(file);
        }
        if (format == TLTagFileFormatWavPack) {
            TagLib::WavPack::File file(filePath);
            return writeAPE(file);
        }
        TagLib::MPC::File file(filePath);
        return writeAPE(file);
    }

    if (format == TLTagFileFormatWAV) {
        TagLib::RIFF::WAV::File file(filePath);
        if (!file.isValid()) {
            if (error) *error = [NSError errorWithDomain:@"TagLibMetadataExtractor" code:234 userInfo:@{ NSLocalizedDescriptionKey : @"Unable to open WAV file for structured metadata editing" }];
            return NO;
        }
        TagLib::ID3v2::Tag *tag = file.ID3v2Tag();
        if (propertyValues) {
            // WAV's file-level PropertyMap also exposes RIFF INFO. Merge into
            // the ID3v2 tag only so preserveInfo does not duplicate INFO into
            // ID3 and id3v2Only does not carry INFO values into the new tag.
            SetID3PropertiesPreservingNativeDates(tag, MergedRawPropertyMapValues(tag->properties(), propertyValues));
        }
        UpsertID3v2StructuredFrames(tag, frames);
        ReplaceID3v2Comments(tag, comments);
        ReplaceID3v2Lyrics(tag, lyrics);
        ReplaceID3v2Artwork(tag, artwork);
        if (!SaveWAVPreservingID3Version(&file, TagLib::RIFF::WAV::File::ID3v2, TagLib::File::StripNone)) {
            if (error) *error = [NSError errorWithDomain:@"TagLibMetadataExtractor" code:235 userInfo:@{ NSLocalizedDescriptionKey : @"TagLib failed to save structured WAV metadata" }];
            return NO;
        }
        NSString *riffPolicy = [metadata[@"riffPolicy"] isKindOfClass:[NSString class]]
            ? (NSString *)metadata[@"riffPolicy"] : nil;
        if ([riffPolicy isEqualToString:@"id3v2Only"] && file.hasInfoTag()) {
            file.strip(TagLib::RIFF::WAV::File::Info);
            if (!SaveWAVPreservingID3Version(&file, TagLib::RIFF::WAV::File::AllTags, TagLib::File::StripNone)) {
                if (error) *error = [NSError errorWithDomain:@"TagLibMetadataExtractor" code:235 userInfo:@{ NSLocalizedDescriptionKey : @"TagLib failed to save the RIFF INFO removal" }];
                return NO;
            }
            // strip() has no return value. Reopen to confirm its on-disk
            // policy effect rather than trusting the in-memory tag state.
            TagLib::RIFF::WAV::File saved(filePath);
            if (!saved.isValid() || saved.hasInfoTag()) {
                if (error) *error = [NSError errorWithDomain:@"TagLibMetadataExtractor" code:235 userInfo:@{ NSLocalizedDescriptionKey : @"RIFF INFO removal could not be confirmed after save" }];
                return NO;
            }
        }
        return YES;
    }

    if (format == TLTagFileFormatAIFF) {
        TagLib::RIFF::AIFF::File file(filePath);
        if (!file.isValid()) {
            if (error) *error = [NSError errorWithDomain:@"TagLibMetadataExtractor" code:236 userInfo:@{ NSLocalizedDescriptionKey : @"Unable to open AIFF file for structured metadata editing" }];
            return NO;
        }
        if (propertyValues) {
            SetPropertiesPreservingNativeDates(&file, MergedRawPropertyMapValues(file.properties(), propertyValues));
        }
        TagLib::ID3v2::Tag *tag = file.tag();
        UpsertID3v2StructuredFrames(tag, frames);
        ReplaceID3v2Comments(tag, comments);
        ReplaceID3v2Lyrics(tag, lyrics);
        ReplaceID3v2Artwork(tag, artwork);
        if (!SaveAIFFPreservingID3Version(&file)) {
            if (error) *error = [NSError errorWithDomain:@"TagLibMetadataExtractor" code:237 userInfo:@{ NSLocalizedDescriptionKey : @"TagLib failed to save structured AIFF metadata" }];
            return NO;
        }
        return YES;
    }

    if (format == TLTagFileFormatMP4) {
        PreservingMP4ItemFactory mp4ItemFactory;
        TagLib::MP4::File file(filePath, true, TagLib::AudioProperties::Fast, &mp4ItemFactory);
        if (!file.isValid() || !file.tag()) {
            if (error) *error = [NSError errorWithDomain:@"TagLibMetadataExtractor" code:238 userInfo:@{ NSLocalizedDescriptionKey : @"Unable to open MP4 file for structured metadata editing" }];
            return NO;
        }
        std::vector<TagLib::String> targetedKeys;
        if (propertyValues) {
            const TagLib::MP4::ItemMap originalMP4Items = file.tag()->itemMap();
            NSMutableDictionary<NSString *, NSArray<NSString *> *> *upperPropertyValues = [NSMutableDictionary dictionary];
            for (NSString *key in propertyValues) {
                NSString *upper = UppercaseTrimmedString(key);
                if (upper.length) {
                    upperPropertyValues[upper] = propertyValues[key];
                    const TagLib::String nativeKey = MP4NativeFourCCAtomForPropertyKey(upper);
                    if (!nativeKey.isEmpty()) targetedKeys.push_back(nativeKey);
                }
            }
            SetPropertiesPreservingNativeDates(&file, MergedRawPropertyMapValues(file.properties(), propertyValues));
            // Preserve shadowed iTunes freeforms whose 4-char native atom owns
            // the PropertyMap key, and keep freeform-only owners from
            // synthesizing a duplicate 4-char atom.
            for (const auto &[key, item] : originalMP4Items) {
                NSString *description = MP4FreeformDescriptionForItemKey(key);
                if (!description) continue;
                NSString *upper = description.uppercaseString;
                const TagLib::String nativeKey = MP4NativeFourCCAtomForPropertyKey(upper);
                if (nativeKey.isEmpty()) continue;
                if (originalMP4Items.contains(nativeKey)) {
                    file.tag()->setItem(key, item);
                } else {
                    file.tag()->removeItem(nativeKey);
                    NSArray<NSString *> *updated = upperPropertyValues[upper];
                    if (updated) {
                        if (updated.count == 0) {
                            file.tag()->removeItem(key);
                        } else {
                            TagLib::StringList list;
                            for (NSString *val in updated) list.append(NSStringToTagString(val));
                            file.tag()->setItem(key, TagLib::MP4::Item(list));
                        }
                    } else {
                        file.tag()->setItem(key, item);
                    }
                }
            }
        }
        for (NSDictionary<NSString *, NSObject *> *entry in mp4Atoms ?: @[]) {
            NSString *key = TrimmedStringOrNil((NSString *)entry[@"key"]);
            if (key.length) targetedKeys.push_back(NSStringToTagString(key));
        }
        ApplyStructuredMP4Atoms(file.tag(), mp4Atoms);
        if (!ReplaceStructuredComplexArtwork(file.tag(), artwork)) {
            if (error) *error = [NSError errorWithDomain:@"TagLibMetadataExtractor" code:243 userInfo:@{ NSLocalizedDescriptionKey : @"TagLib failed to apply structured MP4 artwork" }];
            return NO;
        }
        if (artwork) {
            targetedKeys.push_back("covr");
            if (artwork.count == 0) file.tag()->removeItem("covr");
        }
        if (!mp4ItemFactory.prepareForSave(file.tag(), targetedKeys, error)) return NO;
        if (!file.save()) {
            if (error) *error = [NSError errorWithDomain:@"TagLibMetadataExtractor" code:239 userInfo:@{ NSLocalizedDescriptionKey : @"TagLib failed to save structured MP4 metadata" }];
            return NO;
        }
        return YES;
    }

    if (format == TLTagFileFormatASF) {
        TagLib::ASF::File file(filePath);
        if (!file.isValid() || !file.tag()) {
            if (error) *error = [NSError errorWithDomain:@"TagLibMetadataExtractor" code:240 userInfo:@{ NSLocalizedDescriptionKey : @"Unable to open ASF/WMA file for structured metadata editing" }];
            return NO;
        }
        if (propertyValues) {
            SetPropertiesPreservingNativeDates(&file, MergedRawPropertyMapValues(file.properties(), propertyValues));
        }
        if (!ApplyStructuredASFAttributes(file.tag(), asfAttributes, error)) return NO;
        ReplaceStructuredASFArtwork(file.tag(), artwork);
        if (artwork.count > 0 && file.tag()->attribute("WM/Picture").isEmpty()) {
            if (error) *error = [NSError errorWithDomain:@"TagLibMetadataExtractor" code:299 userInfo:@{ NSLocalizedDescriptionKey : @"ASF picture attribute was not added" }];
            return NO;
        }
        if (!file.save()) {
            if (error) *error = [NSError errorWithDomain:@"TagLibMetadataExtractor" code:241 userInfo:@{ NSLocalizedDescriptionKey : @"TagLib failed to save structured ASF/WMA metadata" }];
            return NO;
        }
        return YES;
    }

    if (format == TLTagFileFormatFLAC ||
        format == TLTagFileFormatOggVorbis || format == TLTagFileFormatOggOpus ||
        format == TLTagFileFormatOggFlac || format == TLTagFileFormatOggSpeex) {
        if (frames || mp4Atoms || asfAttributes || lyrics || comments) {
            return SetStructuredPayloadValidationError(error, @"This format supports structured properties and artwork, not ID3/MP4/ASF collections");
        }
        TagLib::FileRef reference(filePath, true, TagLib::AudioProperties::Fast);
        TagLib::File *file = reference.file();
        if (!file || !file->isValid()) {
            return SetStructuredPayloadValidationError(error, @"Unable to open audio file for structured artwork editing");
        }
        if (propertyValues) SetPropertiesPreservingNativeDates(file, MergedRawPropertyMapValues(file->properties(), propertyValues));
        if (!ReplaceStructuredComplexArtwork(file, artwork) || !file->save()) {
            return SetStructuredPayloadValidationError(error, @"TagLib could not save structured artwork");
        }
        return YES;
    }

    if (frames || mp4Atoms || asfAttributes || lyrics || comments) {
        return SetStructuredPayloadValidationError(
            error,
            @"This format supports structured PropertyMap values and artwork, not ID3/MP4/ASF collections"
        );
    }

    // Formats without a dedicated structured branch still support a native
    // PropertyMap delta and complex-property artwork. Use merge semantics so
    // omitted properties/native structures are preserved.
    {
        TagLib::FileRef reference(filePath, true, TagLib::AudioProperties::Fast);
        TagLib::File *file = reference.file();
        if (!file || !file->isValid()) {
            return SetStructuredPayloadValidationError(error, @"Unable to open audio file for structured metadata editing");
        }
        if (propertyValues) {
            SetPropertiesPreservingNativeDates(file, MergedRawPropertyMapValues(file->properties(), propertyValues));
        }
        if (!ReplaceStructuredComplexArtwork(file, artwork) || !file->save()) {
            return SetStructuredPayloadValidationError(error, @"TagLib could not save structured metadata");
        }
        return YES;
    }
    TAGLIB_BRIDGE_CATCH_WITH_ERROR(error, @"Structured metadata write", NO)
}

// Return a best-effort, "raw" view of metadata as TagLib sees it.
// This is intended for displaying to users in a GUI, not for programmatic editing.
