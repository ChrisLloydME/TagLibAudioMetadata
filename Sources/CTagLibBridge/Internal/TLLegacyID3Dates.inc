// Literal legacy date evidence, before TagLib's TYER+TDAT normalization.
static NSArray<NSDictionary<NSString *, NSObject *> *> *LiteralV23DateFrames(NSURL *url, NSError **error)
{
    NSData *data = [NSData dataWithContentsOfURL:url options:NSDataReadingMappedIfSafe error:error];
    if (!data) return nil;
    const auto *bytes = static_cast<const unsigned char *>(data.bytes);
    size_t count = data.length;
    auto fail = [&]() -> NSArray<NSDictionary<NSString *, NSObject *> *> * {
        if (error) *error = [NSError errorWithDomain:@"TagLibMetadataExtractor" code:9281
            userInfo:@{NSLocalizedDescriptionKey: @"Unsupported or malformed literal ID3v2.3 date evidence"}];
        return nil;
    };
    auto magic = [&](size_t offset, const char *value, size_t length) {
        return offset <= count && length <= count - offset && std::memcmp(bytes + offset, value, length) == 0;
    };
    auto integer = [&](size_t offset, size_t length, bool little = false) -> uint64_t {
        if (offset > count || length > count - offset) return UINT64_MAX;
        uint64_t value = 0;
        for (size_t i = 0; i < length; ++i) value = (value << 8) | bytes[offset + (little ? length - i - 1 : i)];
        return value;
    };
    size_t offset = 0;
    if (magic(0, "RIFF", 4) || magic(0, "FORM", 4) || magic(0, "FRM8", 4)) {
        const bool little = magic(0, "RIFF", 4);
        const size_t header = magic(0, "FRM8", 4) ? 12 : 8;
        offset = header == 12 ? 16 : 12;
        while (offset <= count && header <= count - offset) {
            const uint64_t size = integer(offset + 4, header - 4, little);
            if (size > count - offset - header) return fail();
            if (magic(offset, "ID3 ", 4) || magic(offset, "id3 ", 4)) { offset += header; break; }
            offset += header + static_cast<size_t>(size);
            if (size & 1) { if (offset == count) return fail(); ++offset; }
        }
    } else if (magic(0, "DSD ", 4)) {
        const uint64_t location = integer(20, 8, true);
        if (location > count) return fail();
        offset = static_cast<size_t>(location);
    }
    if (!magic(offset, "ID3", 3) || count - offset < 10 || bytes[offset + 3] != 3 || (bytes[offset + 5] & 0x1f) != 0) return fail();
    size_t size = 0;
    for (size_t i = 6; i < 10; ++i) {
        if (bytes[offset + i] > 127) return fail();
        size = (size << 7) | bytes[offset + i];
    }
    if (size > count - offset - 10) return fail();
    const unsigned char flags = bytes[offset + 5];
    std::vector<unsigned char> logical;
    if (flags & 0x80) {
        logical.reserve(size);
        for (size_t i = offset + 10; i < offset + 10 + size; ++i) {
            logical.push_back(bytes[i]);
            if (bytes[i] == 0xff && i + 1 < offset + 10 + size && bytes[i + 1] == 0) ++i;
        }
        bytes = logical.data();
        count = logical.size();
    } else {
        bytes += offset + 10;
        count = size;
    }
    offset = 0;
    if (flags & 0x40) {
        const uint64_t extendedSize = integer(0, 4);
        if (extendedSize < 6 || count < 4 || extendedSize > count - 4) return fail();
        offset = 4 + static_cast<size_t>(extendedSize);
    }
    const size_t end = count;
    NSMutableArray *dates = [NSMutableArray array];
    NSSet *owners = [NSSet setWithArray:@[@"TYER", @"TDAT", @"TORY", @"TDRC", @"TDRL", @"TDOR"]];
    while (offset <= end && end - offset >= 10 && bytes[offset] != 0) {
        NSString *identifier = [[NSString alloc] initWithBytes:bytes + offset length:4 encoding:NSASCIIStringEncoding];
        const uint64_t length = integer(offset + 4, 4);
        if (length > end - offset - 10) return fail();
        if ([owners containsObject:identifier]) {
            if (length < 1 || bytes[offset + 8] || bytes[offset + 9]) return fail();
            NSStringEncoding encoding;
            if (bytes[offset + 10] == 0) encoding = NSISOLatin1StringEncoding;
            else if (bytes[offset + 10] == 1) encoding = NSUTF16StringEncoding;
            else return fail();
            NSString *text = [[NSString alloc] initWithBytes:bytes + offset + 11 length:static_cast<size_t>(length) - 1 encoding:encoding];
            if (!text) return fail();
            const unichar zero = 0;
            NSArray *values = [text componentsSeparatedByString:[NSString stringWithCharacters:&zero length:1]];
            [dates addObject:@{@"id":identifier, @"type":@"text", @"value":[values componentsJoinedByString:@"; "], @"values":values}];
        }
        offset += 10 + static_cast<size_t>(length);
    }
    return dates;
}
