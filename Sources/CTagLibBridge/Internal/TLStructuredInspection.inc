static inline void AppendLine(NSMutableString *out, NSString *line) {
    if (!out || !line) return;
    [out appendString:line];
    [out appendString:@"\n"];
}

static inline NSString *NonNil(NSString *s) {
    return s ?: @"";
}

static inline void AppendSectionHeader(NSMutableString *out, NSString *title) {
    if (!out || !title) return;
    if (out.length > 0) {
        AppendLine(out, @"");
    }
    AppendLine(out, title);
}

static NSString *ByteVectorToNSString(const TagLib::ByteVector &data) {
    if (data.isEmpty()) {
        return @"";
    }

    NSString *text = [[NSString alloc] initWithBytes:data.data()
                                              length:data.size()
                                            encoding:NSUTF8StringEncoding];
    if (text.length > 0) {
        return text;
    }

    text = [[NSString alloc] initWithBytes:data.data()
                                    length:data.size()
                                  encoding:NSASCIIStringEncoding];
    if (text.length > 0) {
        return text;
    }

    return [NSString stringWithFormat:@"<%d bytes>", data.size()];
}

static void AppendPropertyMap(NSMutableString *out, const TagLib::PropertyMap &pm) {
    if (!out) return;

    if (pm.isEmpty()) {
        AppendLine(out, @"(none)");
        return;
    }

    bool appendedAnyEntry = false;

    // Iterate PropertyMap directly (portable across TagLib versions).
    for (auto it = pm.begin(); it != pm.end(); ++it) {
        const TagLib::String &k = it->first;
        const TagLib::StringList &vals = it->second;

        NSString *nsKey = TagStringToNSString(k);
        if (!nsKey) nsKey = @"";
        if (IsHiddenInternalMetadataFieldKey(nsKey)) {
            continue;
        }

        NSMutableArray<NSString *> *valueStrings = [NSMutableArray array];
        for (auto vit = vals.begin(); vit != vals.end(); ++vit) {
            NSString *v = TagStringToNSString(*vit);
            [valueStrings addObject:(v ?: @"")];
        }

        NSString *joined = valueStrings.count ? [valueStrings componentsJoinedByString:@"; "] : @"";
        AppendLine(out, [NSString stringWithFormat:@"%@ = %@", nsKey, joined]);
        appendedAnyEntry = true;
    }

    if (!appendedAnyEntry) {
        AppendLine(out, @"(none)");
    }
}

static NSString *MP4ItemToDisplayString(const TagLib::MP4::Item &item) {
    // Prefer string list (many atoms map cleanly here).
    TagLib::StringList sl = item.toStringList();
    if (!sl.isEmpty()) {
        return TagStringToNSString(sl.toString("; ")) ?: @"";
    }

    // Try common scalar representations.
    // Note: We intentionally avoid calling `isEmpty()` on MP4::Item (not available in some TagLib versions).
    // Also avoid throwing conversions by keeping them simple.
    @try {
        int v = item.toInt();
        return [NSString stringWithFormat:@"%d", v];
    } @catch (...) {
        // ignore
    }

    @try {
        TagLib::MP4::Item::IntPair p = item.toIntPair();
        return [NSString stringWithFormat:@"%d/%d", p.first, p.second];
    } @catch (...) {
        // ignore
    }

    @try {
        bool b = item.toBool();
        return b ? @"true" : @"false";
    } @catch (...) {
        // ignore
    }

    // Binary-like / artwork atoms: show a placeholder.
    @try {
        TagLib::MP4::CoverArtList arts = item.toCoverArtList();
        if (!arts.isEmpty()) {
            return [NSString stringWithFormat:@"<CoverArtList: %lu item(s)>", (unsigned long)arts.size()];
        }
    } @catch (...) {
        // ignore
    }

    return @"<unavailable>";
}

static void AppendID3v2FramesSection(NSMutableString *out,
                                     TagLib::ID3v2::Tag *tag,
                                     NSString *title)
{
    AppendSectionHeader(out, title);

    if (!tag) {
        AppendLine(out, @"(none)");
        return;
    }

    TagLib::ID3v2::FrameList frames = tag->frameList();
    if (frames.isEmpty()) {
        AppendLine(out, @"(none)");
        return;
    }

    for (auto fit = frames.begin(); fit != frames.end(); ++fit) {
        TagLib::ID3v2::Frame *frame = *fit;
        if (!frame) continue;

        TagLib::ByteVector frameIdBytes = frame->frameID();
        std::string idStr(frameIdBytes.data(), frameIdBytes.size());
        NSString *fid = idStr.empty() ? @"" : [NSString stringWithUTF8String:idStr.c_str()];
        NSString *val = TagStringToNSString(frame->toString()) ?: @"";

        if (auto userFrame = dynamic_cast<TagLib::ID3v2::UserTextIdentificationFrame *>(frame)) {
            NSString *desc = TagStringToNSString(userFrame->description()) ?: @"";
            if (desc.length > 0) {
                AppendLine(out, [NSString stringWithFormat:@"%@ (TXXX:%@) = %@", fid, desc, val]);
                continue;
            }
        }

        if (auto commFrame = dynamic_cast<TagLib::ID3v2::CommentsFrame *>(frame)) {
            NSString *desc = TagStringToNSString(commFrame->description()) ?: @"";
            NSString *lang = TagStringToNSString(commFrame->language()) ?: @"";
            if (desc.length > 0 || lang.length > 0) {
                AppendLine(out, [NSString stringWithFormat:@"%@ (COMM:%@ %@) = %@", fid, desc, lang, val]);
                continue;
            }
        }

        AppendLine(out, [NSString stringWithFormat:@"%@ = %@", fid, val]);
    }
}

static void AppendSimpleTagSection(NSMutableString *out,
                                   NSString *title,
                                   TagLib::Tag *tag)
{
    AppendSectionHeader(out, title);

    if (!tag || tag->isEmpty()) {
        AppendLine(out, @"(none)");
        return;
    }

    bool appended = false;

    NSString *value = TagStringToNSString(tag->title());
    if (value.length > 0) {
        AppendLine(out, [NSString stringWithFormat:@"Title = %@", value]);
        appended = true;
    }

    value = TagStringToNSString(tag->artist());
    if (value.length > 0) {
        AppendLine(out, [NSString stringWithFormat:@"Artist = %@", value]);
        appended = true;
    }

    value = TagStringToNSString(tag->album());
    if (value.length > 0) {
        AppendLine(out, [NSString stringWithFormat:@"Album = %@", value]);
        appended = true;
    }

    value = TagStringToNSString(tag->comment());
    if (value.length > 0) {
        AppendLine(out, [NSString stringWithFormat:@"Comment = %@", value]);
        appended = true;
    }

    value = TagStringToNSString(tag->genre());
    if (value.length > 0) {
        AppendLine(out, [NSString stringWithFormat:@"Genre = %@", value]);
        appended = true;
    }

    if (tag->year() > 0) {
        AppendLine(out, [NSString stringWithFormat:@"Year = %u", tag->year()]);
        appended = true;
    }

    if (tag->track() > 0) {
        AppendLine(out, [NSString stringWithFormat:@"Track = %u", tag->track()]);
        appended = true;
    }

    if (!appended) {
        AppendLine(out, @"(present but empty)");
    }
}

static NSString *APEItemTypeToString(TagLib::APE::Item::ItemTypes type)
{
    switch (type) {
        case TagLib::APE::Item::Text: return @"text";
        case TagLib::APE::Item::Binary: return @"binary";
        case TagLib::APE::Item::Locator: return @"locator";
    }
}

static void AppendAPEItemsSection(NSMutableString *out,
                                  TagLib::APE::Tag *tag,
                                  NSString *title)
{
    AppendSectionHeader(out, title);

    if (!tag) {
        AppendLine(out, @"(none)");
        return;
    }

    const TagLib::APE::ItemListMap &items = tag->itemListMap();
    if (items.isEmpty()) {
        AppendLine(out, @"(none)");
        return;
    }

    for (auto it = items.begin(); it != items.end(); ++it) {
        NSString *key = TagStringToNSString(it->first) ?: @"";
        const TagLib::APE::Item &item = it->second;

        if (item.type() == TagLib::APE::Item::Text) {
            NSMutableArray<NSString *> *values = [NSMutableArray array];
            TagLib::StringList textValues = item.values();
            for (auto vit = textValues.begin(); vit != textValues.end(); ++vit) {
                [values addObject:(TagStringToNSString(*vit) ?: @"")];
            }
            NSString *joined = values.count ? [values componentsJoinedByString:@"; "] : @"";
            AppendLine(out, [NSString stringWithFormat:@"%@ [%@] = %@",
                             key,
                             APEItemTypeToString(item.type()),
                             joined]);
        } else {
            AppendLine(out, [NSString stringWithFormat:@"%@ [%@] = <%d bytes>",
                             key,
                             APEItemTypeToString(item.type()),
                             item.binaryData().size()]);
        }
    }
}

static void AppendXiphCommentSection(NSMutableString *out,
                                     TagLib::Ogg::XiphComment *tag,
                                     NSString *title)
{
    AppendSectionHeader(out, title);

    if (!tag) {
        AppendLine(out, @"(none)");
        return;
    }

    NSString *vendor = TagStringToNSString(tag->vendorID()) ?: @"";
    if (vendor.length > 0) {
        AppendLine(out, [NSString stringWithFormat:@"VENDOR = %@", vendor]);
    }

    const TagLib::Ogg::FieldListMap &fields = tag->fieldListMap();
    if (fields.isEmpty()) {
        AppendLine(out, @"(none)");
        return;
    }

    for (auto it = fields.begin(); it != fields.end(); ++it) {
        NSString *key = TagStringToNSString(it->first) ?: @"";
        NSMutableArray<NSString *> *values = [NSMutableArray array];
        for (auto vit = it->second.begin(); vit != it->second.end(); ++vit) {
            [values addObject:(TagStringToNSString(*vit) ?: @"")];
        }
        NSString *joined = values.count ? [values componentsJoinedByString:@"; "] : @"";
        AppendLine(out, [NSString stringWithFormat:@"%@ = %@", key, joined]);
    }
}

static void AppendRIFFInfoSection(NSMutableString *out,
                                  TagLib::RIFF::Info::Tag *tag,
                                  NSString *title)
{
    AppendSectionHeader(out, title);

    if (!tag) {
        AppendLine(out, @"(none)");
        return;
    }

    TagLib::RIFF::Info::FieldListMap fields = tag->fieldListMap();
    if (fields.isEmpty()) {
        AppendLine(out, @"(none)");
        return;
    }

    for (auto it = fields.begin(); it != fields.end(); ++it) {
        NSString *key = ByteVectorToNSString(it->first);
        NSString *value = TagStringToNSString(it->second) ?: @"";
        AppendLine(out, [NSString stringWithFormat:@"%@ = %@", key, value]);
    }
}

static NSData *DataFromByteVector(const TagLib::ByteVector &data)
{
    if (data.isEmpty()) {
        return [NSData data];
    }
    return [NSData dataWithBytes:data.data() length:data.size()];
}

static NSString *StringFromByteVector(const TagLib::ByteVector &data)
{
    if (data.isEmpty()) {
        return @"";
    }
    std::string value(data.data(), data.size());
    return [NSString stringWithUTF8String:value.c_str()] ?: @"";
}

static NSString *MP4ItemTypeName(TagLib::MP4::Item::Type type)
{
    switch (type) {
        case TagLib::MP4::Item::Type::Void: return @"void";
        case TagLib::MP4::Item::Type::Bool: return @"bool";
        case TagLib::MP4::Item::Type::Int: return @"int";
        case TagLib::MP4::Item::Type::IntPair: return @"intPair";
        case TagLib::MP4::Item::Type::Byte: return @"byte";
        case TagLib::MP4::Item::Type::UInt: return @"uint";
        case TagLib::MP4::Item::Type::LongLong: return @"longLong";
        case TagLib::MP4::Item::Type::StringList: return @"stringList";
        case TagLib::MP4::Item::Type::ByteVectorList: return @"byteVectorList";
        case TagLib::MP4::Item::Type::CoverArtList: return @"coverArtList";
#if TAGLIB_MAJOR_VERSION > 2 || (TAGLIB_MAJOR_VERSION == 2 && TAGLIB_MINOR_VERSION >= 3)
        case TagLib::MP4::Item::Type::Stem: return @"stem";
#endif
    }
}

static NSString *ASFPictureTypeName(TagLib::ASF::Picture::Type type)
{
    return TagStringToNSString(TagLib::ASF::Picture::typeToString(type)) ?: @"Other";
}

static NSString *ASFAttributeTypeName(TagLib::ASF::Attribute::AttributeTypes type)
{
    switch (type) {
        case TagLib::ASF::Attribute::UnicodeType: return @"string";
        case TagLib::ASF::Attribute::BytesType: return @"binary";
        case TagLib::ASF::Attribute::BoolType: return @"bool";
        case TagLib::ASF::Attribute::DWordType: return @"int";
        case TagLib::ASF::Attribute::QWordType: return @"int64";
        case TagLib::ASF::Attribute::WordType: return @"int";
        case TagLib::ASF::Attribute::GuidType: return @"guid";
    }
}

static NSDictionary<NSString *, NSObject *> *StructuredASFAttribute(NSString *key,
                                                                    const TagLib::ASF::Attribute &attribute)
{
    NSMutableDictionary<NSString *, NSObject *> *item = [@{
        @"key": key ?: @"",
        @"type": ASFAttributeTypeName(attribute.type()),
        @"language": @(attribute.language()),
        @"stream": @(attribute.stream())
    } mutableCopy];

    if (attribute.type() == TagLib::ASF::Attribute::UnicodeType) {
        item[@"value"] = TagStringToNSString(attribute.toString()) ?: @"";
    } else if (attribute.type() == TagLib::ASF::Attribute::BoolType) {
        item[@"value"] = @(attribute.toBool() != 0);
    } else if (attribute.type() == TagLib::ASF::Attribute::DWordType) {
        item[@"value"] = @(attribute.toUInt());
    } else if (attribute.type() == TagLib::ASF::Attribute::QWordType) {
        item[@"value"] = @(attribute.toULongLong());
    } else if (attribute.type() == TagLib::ASF::Attribute::WordType) {
        item[@"value"] = @(attribute.toUShort());
    } else if (attribute.type() == TagLib::ASF::Attribute::BytesType) {
        item[@"data"] = DataFromByteVector(attribute.toByteVector());
        item[@"byteCount"] = @(attribute.toByteVector().size());
    } else {
        item[@"data"] = DataFromByteVector(attribute.toByteVector());
        item[@"byteCount"] = @(attribute.toByteVector().size());
    }

    if ([key isEqualToString:@"WM/Picture"]) {
        TagLib::ASF::Picture picture = attribute.toPicture();
        if (picture.isValid()) {
            item[@"pictureType"] = ASFPictureTypeName(picture.type());
            item[@"mimeType"] = TagStringToNSString(picture.mimeType()) ?: @"";
            item[@"description"] = TagStringToNSString(picture.description()) ?: @"";
            item[@"data"] = DataFromByteVector(picture.picture());
            item[@"byteCount"] = @(picture.picture().size());
        }
    }

    return item;
}

static void AppendStructuredID3v2(TagLib::ID3v2::Tag *tag,
                                  NSMutableArray<NSDictionary<NSString *, NSObject *> *> *framesOut,
                                  NSMutableArray<NSDictionary<NSString *, NSObject *> *> *artworkOut,
                                  NSMutableArray<NSDictionary<NSString *, NSObject *> *> *lyricsOut,
                                  NSMutableArray<NSDictionary<NSString *, NSObject *> *> *commentsOut)
{
    if (!tag) return;

    TagLib::ID3v2::FrameList frames = tag->frameList();
    for (auto fit = frames.begin(); fit != frames.end(); ++fit) {
        TagLib::ID3v2::Frame *frame = *fit;
        if (!frame) continue;

        TagLib::ByteVector frameIdBytes = frame->frameID();
        std::string idStr(frameIdBytes.data(), frameIdBytes.size());
        NSString *frameID = idStr.empty() ? @"" : [NSString stringWithUTF8String:idStr.c_str()];
        NSMutableDictionary<NSString *, NSObject *> *item = [@{
            @"id": frameID ?: @"",
            @"value": TagStringToNSString(frame->toString()) ?: @""
        } mutableCopy];

        if (auto *ufid = dynamic_cast<TagLib::ID3v2::UniqueFileIdentifierFrame *>(frame)) {
            item[@"type"] = @"ufid";
            item[@"owner"] = TagStringToNSString(ufid->owner()) ?: @"";
            item[@"data"] = DataFromByteVector(ufid->identifier());
            item[@"byteCount"] = @(ufid->identifier().size());
        } else if (auto *userUrl = dynamic_cast<TagLib::ID3v2::UserUrlLinkFrame *>(frame)) {
            item[@"type"] = @"url";
            item[@"description"] = TagStringToNSString(userUrl->description()) ?: @"";
            item[@"url"] = TagStringToNSString(userUrl->url()) ?: @"";
        } else if (auto *url = dynamic_cast<TagLib::ID3v2::UrlLinkFrame *>(frame)) {
            item[@"type"] = @"url";
            item[@"url"] = TagStringToNSString(url->url()) ?: @"";
        } else if (auto *comm = dynamic_cast<TagLib::ID3v2::CommentsFrame *>(frame)) {
            item[@"type"] = @"comment";
            item[@"description"] = TagStringToNSString(comm->description()) ?: @"";
            item[@"language"] = TagStringToNSString(comm->language()) ?: @"";
            item[@"text"] = TagStringToNSString(comm->text()) ?: @"";
            [commentsOut addObject:item];
        } else if (auto *uslt = dynamic_cast<TagLib::ID3v2::UnsynchronizedLyricsFrame *>(frame)) {
            item[@"type"] = @"lyrics";
            item[@"description"] = TagStringToNSString(uslt->description()) ?: @"";
            item[@"language"] = TagStringToNSString(uslt->language()) ?: @"";
            item[@"text"] = TagStringToNSString(uslt->text()) ?: @"";
            [lyricsOut addObject:item];
        } else if (auto *pic = dynamic_cast<TagLib::ID3v2::AttachedPictureFrame *>(frame)) {
            item[@"type"] = @"artwork";
            item[@"pictureType"] = TagStringToNSString(TagLib::ID3v2::AttachedPictureFrame::typeToString(pic->type())) ?: @"";
            item[@"pictureTypeCode"] = @((int)pic->type());
            item[@"mimeType"] = TagStringToNSString(pic->mimeType()) ?: @"";
            item[@"description"] = TagStringToNSString(pic->description()) ?: @"";
            item[@"data"] = DataFromByteVector(pic->picture());
            item[@"byteCount"] = @(pic->picture().size());
            [artworkOut addObject:item];
        } else if (auto *chapter = dynamic_cast<TagLib::ID3v2::ChapterFrame *>(frame)) {
            item[@"type"] = @"chapter";
            item[@"elementID"] = StringFromByteVector(chapter->elementID());
            item[@"startTimeMilliseconds"] = @(chapter->startTime());
            item[@"endTimeMilliseconds"] = @(chapter->endTime());
            item[@"startOffset"] = @(chapter->startOffset());
            item[@"endOffset"] = @(chapter->endOffset());
            item[@"embeddedFrameCount"] = @(chapter->embeddedFrameList().size());
        } else if (auto *toc = dynamic_cast<TagLib::ID3v2::TableOfContentsFrame *>(frame)) {
            item[@"type"] = @"tableOfContents";
            item[@"elementID"] = StringFromByteVector(toc->elementID());
            item[@"isTopLevel"] = @(toc->isTopLevel());
            item[@"isOrdered"] = @(toc->isOrdered());
            NSMutableArray<NSString *> *children = [NSMutableArray array];
            TagLib::ByteVectorList childElements = toc->childElements();
            for (auto it = childElements.begin(); it != childElements.end(); ++it) {
                [children addObject:StringFromByteVector(*it)];
            }
            item[@"children"] = children;
            item[@"embeddedFrameCount"] = @(toc->embeddedFrameList().size());
        } else if (dynamic_cast<TagLib::ID3v2::PodcastFrame *>(frame)) {
            item[@"type"] = @"podcast";
        } else if (auto *userText = dynamic_cast<TagLib::ID3v2::UserTextIdentificationFrame *>(frame)) {
            item[@"type"] = @"userText";
            item[@"description"] = TagStringToNSString(userText->description()) ?: @"";
            NSMutableArray<NSString *> *values = [NSMutableArray array];
            TagLib::StringList fields = userText->fieldList();
            for (auto it = fields.begin(); it != fields.end(); ++it) {
                [values addObject:TagStringToNSString(*it) ?: @""];
            }
            item[@"values"] = values;
        } else if (auto *text = dynamic_cast<TagLib::ID3v2::TextIdentificationFrame *>(frame)) {
            item[@"type"] = @"text";
            NSMutableArray<NSString *> *values = [NSMutableArray array];
            TagLib::StringList fields = text->fieldList();
            for (auto it = fields.begin(); it != fields.end(); ++it) {
                [values addObject:TagStringToNSString(*it) ?: @""];
            }
            item[@"values"] = values;
        } else {
            item[@"type"] = @"unknown";
        }

        [framesOut addObject:item];
    }
}

static void AppendStructuredMP4(TagLib::MP4::Tag *tag,
                                NSMutableArray<NSDictionary<NSString *, NSObject *> *> *atomsOut,
                                NSMutableArray<NSDictionary<NSString *, NSObject *> *> *artworkOut)
{
    if (!tag) return;
    const TagLib::MP4::ItemMap &items = tag->itemMap();
    for (auto it = items.begin(); it != items.end(); ++it) {
        NSString *key = TagStringToNSString(it->first) ?: @"";
        const TagLib::MP4::Item &item = it->second;
        NSMutableDictionary<NSString *, NSObject *> *out = [@{
            @"key": key,
            @"type": MP4ItemTypeName(item.type())
        } mutableCopy];

        switch (item.type()) {
            case TagLib::MP4::Item::Type::Bool:
                out[@"value"] = @(item.toBool());
                break;
            case TagLib::MP4::Item::Type::Int:
                out[@"value"] = @(item.toInt());
                break;
            case TagLib::MP4::Item::Type::Byte:
                out[@"value"] = @(item.toByte());
                break;
            case TagLib::MP4::Item::Type::UInt:
                out[@"value"] = @(item.toUInt());
                break;
            case TagLib::MP4::Item::Type::LongLong:
                out[@"value"] = @(item.toLongLong());
                break;
            case TagLib::MP4::Item::Type::IntPair: {
                TagLib::MP4::Item::IntPair pair = item.toIntPair();
                out[@"first"] = @(pair.first);
                out[@"second"] = @(pair.second);
                out[@"value"] = [NSString stringWithFormat:@"%d/%d", pair.first, pair.second];
                break;
            }
            case TagLib::MP4::Item::Type::StringList: {
                NSMutableArray<NSString *> *values = [NSMutableArray array];
                TagLib::StringList strings = item.toStringList();
                for (auto vit = strings.begin(); vit != strings.end(); ++vit) {
                    [values addObject:TagStringToNSString(*vit) ?: @""];
                }
                out[@"values"] = values;
                out[@"value"] = values.count ? [values componentsJoinedByString:@"; "] : @"";
                break;
            }
            case TagLib::MP4::Item::Type::CoverArtList: {
                NSMutableArray<NSDictionary<NSString *, NSObject *> *> *covers = [NSMutableArray array];
                TagLib::MP4::CoverArtList coverArts = item.toCoverArtList();
                for (auto cit = coverArts.begin(); cit != coverArts.end(); ++cit) {
                    NSString *mime = @"image/jpeg";
                    switch (cit->format()) {
                        case TagLib::MP4::CoverArt::PNG: mime = @"image/png"; break;
                        case TagLib::MP4::CoverArt::BMP: mime = @"image/bmp"; break;
                        case TagLib::MP4::CoverArt::GIF: mime = @"image/gif"; break;
                        case TagLib::MP4::CoverArt::JPEG:
                        default: mime = @"image/jpeg"; break;
                    }
                    NSDictionary<NSString *, NSObject *> *cover = @{
                        @"container": @"mp4",
                        @"mimeType": mime,
                        @"data": DataFromByteVector(cit->data()),
                        @"byteCount": @(cit->data().size())
                    };
                    [covers addObject:cover];
                    [artworkOut addObject:cover];
                }
                out[@"covers"] = covers;
                out[@"value"] = [NSString stringWithFormat:@"%lu artwork item(s)", (unsigned long)covers.count];
                break;
            }
            default:
                out[@"value"] = MP4ItemToDisplayString(item);
                break;
        }

        NSString *freeformDescription = MP4FreeformDescriptionForItemKey(it->first);
        if (freeformDescription.length > 0) {
            out[@"freeformDescription"] = freeformDescription;
        }
        [atomsOut addObject:out];
    }
}

static void AppendStructuredASF(TagLib::ASF::Tag *tag,
                                NSMutableArray<NSDictionary<NSString *, NSObject *> *> *attributesOut,
                                NSMutableArray<NSDictionary<NSString *, NSObject *> *> *artworkOut)
{
    if (!tag) return;
    const TagLib::ASF::AttributeListMap &attributes = tag->attributeListMap();
    for (auto it = attributes.begin(); it != attributes.end(); ++it) {
        NSString *key = TagStringToNSString(it->first) ?: @"";
        for (auto ait = it->second.begin(); ait != it->second.end(); ++ait) {
            NSDictionary<NSString *, NSObject *> *item = StructuredASFAttribute(key, *ait);
            [attributesOut addObject:item];
            if ([key isEqualToString:@"WM/Picture"]) {
                [artworkOut addObject:item];
            }
        }
    }
}

template <typename ComplexPropertyTarget>
static void AppendStructuredComplexPictures(ComplexPropertyTarget *target,
                                            NSString *container,
                                            NSMutableArray<NSDictionary<NSString *, NSObject *> *> *artworkOut)
{
    if (!target || !artworkOut) return;

    TagLib::List<TagLib::VariantMap> pictures = target->complexProperties("PICTURE");
    for (const auto &picture : pictures) {
        TagLib::ByteVector imageData = picture.value("data").value<TagLib::ByteVector>();
        if (imageData.isEmpty()) continue;

        NSString *mimeType = TagStringToNSString(picture.value("mimeType").value<TagLib::String>()) ?: @"";
        NSString *pictureType = TagStringToNSString(picture.value("pictureType").value<TagLib::String>()) ?: @"";
        NSString *description = TagStringToNSString(picture.value("description").value<TagLib::String>()) ?: @"";

        NSMutableDictionary<NSString *, NSObject *> *item = [@{
            @"container": container ?: @"",
            @"mimeType": mimeType,
            @"pictureType": pictureType,
            @"data": DataFromByteVector(imageData),
            @"byteCount": @(imageData.size())
        } mutableCopy];
        if (description.length > 0) {
            item[@"description"] = description;
        }
        [artworkOut addObject:item];
    }
}

+ (nullable NSDictionary<NSString *, NSObject *> *)structuredMetadataForURL:(NSURL *)fileURL
                                                                      error:(NSError **)error
{
    try {
    NSDictionary<NSString *, NSObject *> *projections = [self metadataProjectionsForURL:fileURL error:error];
    return projections ? (NSDictionary<NSString *, NSObject *> *)projections[@"structured"] : nil;
    TAGLIB_BRIDGE_CATCH_WITH_ERROR(error, @"Structured metadata extraction", nil)
}
