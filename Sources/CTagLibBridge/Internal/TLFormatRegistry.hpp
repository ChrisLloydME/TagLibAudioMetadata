#pragma once

#import <Foundation/Foundation.h>
#include <span>

typedef NS_ENUM(NSInteger, TLTagFileFormat) {
    TLTagFileFormatUnknown = 0,
    TLTagFileFormatMPEGID3,
    TLTagFileFormatMPEGAAC,
    TLTagFileFormatMP4,
    TLTagFileFormatFLAC,
    TLTagFileFormatOggVorbis,
    TLTagFileFormatOggOpus,
    TLTagFileFormatOggFlac,
    TLTagFileFormatOggSpeex,
    TLTagFileFormatAPE,
    TLTagFileFormatWavPack,
    TLTagFileFormatMPC,
    TLTagFileFormatWAV,
    TLTagFileFormatAIFF,
    TLTagFileFormatTTA,
    TLTagFileFormatASF,
    TLTagFileFormatDSF,
    TLTagFileFormatDSDIFF,
    TLTagFileFormatShorten,
    TLTagFileFormatMOD,
    TLTagFileFormatS3M,
    TLTagFileFormatIT,
    TLTagFileFormatXM,
};

typedef NS_OPTIONS(NSUInteger, TLMetadataContainerMask) {
    TLMetadataContainerNone = 0,
    TLMetadataContainerTag = 1 << 0,
    TLMetadataContainerPropertyMap = 1 << 1,
    TLMetadataContainerID3v1 = 1 << 2,
    TLMetadataContainerID3v2 = 1 << 3,
    TLMetadataContainerAPE = 1 << 4,
    TLMetadataContainerMP4ItemMap = 1 << 5,
    TLMetadataContainerXiph = 1 << 6,
    TLMetadataContainerASF = 1 << 7,
    TLMetadataContainerRIFFInfo = 1 << 8,
};

struct TLFormatCapabilityDescriptor {
    TLTagFileFormat format;
    const char * _Nonnull identifier;
    const char * _Nonnull displayName;
    const char * _Nonnull codecName;
    const char * _Nonnull const * _Nonnull extensions;
    const char * _Nonnull structuredReadSupport;
    const char * _Nonnull structuredWriteSupport;
    bool canReadArtwork;
    bool canWriteArtwork;
    bool preservesMultiValueProperties;
    const char * _Nullable readOnlyReason;
    const char * _Nullable notes;
};

std::span<const TLFormatCapabilityDescriptor> TLFormatCapabilityDescriptors();
const TLFormatCapabilityDescriptor * _Nullable DescriptorForFormat(TLTagFileFormat format);
const TLFormatCapabilityDescriptor * _Nullable DescriptorForExtension(NSString * _Nullable extension);
