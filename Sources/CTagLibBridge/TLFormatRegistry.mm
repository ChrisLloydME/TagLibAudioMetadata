#include "Internal/TLFormatRegistry.hpp"

namespace {

const char *kMPEGID3Extensions[] = { "mp3", "mp2", nullptr };
const char *kMPEGAACExtensions[] = { "aac", nullptr };
const char *kMP4Extensions[] = { "m4a", "m4r", "m4b", "m4p", "mp4", "m4v", "3g2", nullptr };
const char *kFLACExtensions[] = { "flac", nullptr };
const char *kOggVorbisExtensions[] = { "ogg", nullptr };
const char *kOggOpusExtensions[] = { "opus", nullptr };
const char *kOggFlacExtensions[] = { "oga", nullptr };
const char *kOggSpeexExtensions[] = { "spx", nullptr };
const char *kAPEExtensions[] = { "ape", nullptr };
const char *kWavPackExtensions[] = { "wv", nullptr };
const char *kMPCExtensions[] = { "mpc", nullptr };
const char *kWAVExtensions[] = { "wav", nullptr };
const char *kAIFFExtensions[] = { "aiff", "aif", "aifc", "afc", nullptr };
const char *kTTAExtensions[] = { "tta", nullptr };
const char *kASFExtensions[] = { "wma", "asf", nullptr };
const char *kDSFExtensions[] = { "dsf", nullptr };
const char *kDSDIFFExtensions[] = { "dff", "dsdiff", nullptr };
const char *kShortenExtensions[] = { "shn", nullptr };
const char *kMODExtensions[] = { "mod", "module", "nst", "wow", nullptr };
const char *kS3MExtensions[] = { "s3m", nullptr };
const char *kITExtensions[] = { "it", nullptr };
const char *kXMExtensions[] = { "xm", nullptr };

const TLFormatCapabilityDescriptor kDescriptors[] = {
    { TLTagFileFormatMPEGID3, "mpeg-id3", "MPEG Audio / ID3", "MP3/MP2", kMPEGID3Extensions, "container", "container", true, true, false, nullptr, "ID3v2 is the preferred rich metadata container; ID3v1 is treated as a low-fidelity fallback." },
    { TLTagFileFormatMPEGAAC, "mpeg-aac", "Raw AAC", "AAC", kMPEGAACExtensions, "propertyMap", "propertyMap", true, true, false, nullptr, "Raw AAC uses the generic TagLib PropertyMap path for textual metadata." },
    { TLTagFileFormatMP4, "mp4", "MP4 / MPEG-4 Audio", "AAC/MP4", kMP4Extensions, "container", "container", true, true, false, nullptr, "MP4 atoms and iTunes freeform atoms are exposed for structured editing." },
    { TLTagFileFormatFLAC, "flac", "FLAC", "FLAC", kFLACExtensions, "container", "propertyMap", true, true, true, nullptr, "Structured reads expose FLAC pictures; structured writes fall back to PropertyMap values unless artwork is written through the basic API." },
    { TLTagFileFormatOggVorbis, "ogg-vorbis", "Ogg Vorbis", "Vorbis", kOggVorbisExtensions, "container", "propertyMap", true, true, true, nullptr, "Xiph comments preserve repeated PropertyMap values." },
    { TLTagFileFormatOggOpus, "ogg-opus", "Ogg Opus", "Opus", kOggOpusExtensions, "container", "propertyMap", true, true, true, nullptr, "Xiph comments preserve repeated PropertyMap values." },
    { TLTagFileFormatOggFlac, "ogg-flac", "Ogg FLAC", "Ogg FLAC", kOggFlacExtensions, "container", "propertyMap", true, true, true, nullptr, "Xiph comments preserve repeated PropertyMap values." },
    { TLTagFileFormatOggSpeex, "ogg-speex", "Ogg Speex", "Speex", kOggSpeexExtensions, "container", "propertyMap", true, true, true, nullptr, "Xiph comments preserve repeated PropertyMap values." },
    { TLTagFileFormatAPE, "ape", "Monkey's Audio", "APE", kAPEExtensions, "propertyMap", "propertyMap", true, true, true, nullptr, "APE item metadata is currently surfaced through PropertyMap values." },
    { TLTagFileFormatWavPack, "wavpack", "WavPack", "WavPack", kWavPackExtensions, "propertyMap", "propertyMap", true, true, true, nullptr, "APE item metadata is currently surfaced through PropertyMap values." },
    { TLTagFileFormatMPC, "musepack", "Musepack", "Musepack", kMPCExtensions, "propertyMap", "propertyMap", true, true, true, nullptr, "APE item metadata is currently surfaced through PropertyMap values." },
    { TLTagFileFormatWAV, "wav", "WAV / RIFF", "WAV", kWAVExtensions, "container", "container", true, true, false, nullptr, "Structured writes use ID3v2 and preserve existing RIFF INFO fields." },
    { TLTagFileFormatAIFF, "aiff", "AIFF", "AIFF", kAIFFExtensions, "container", "container", true, true, false, nullptr, "Structured writes use ID3v2." },
    { TLTagFileFormatTTA, "trueaudio", "TrueAudio", "TrueAudio", kTTAExtensions, "container", "propertyMap", true, true, false, nullptr, "Structured reads expose the ID3v2 tag; structured writes are currently limited to PropertyMap values." },
    { TLTagFileFormatASF, "asf", "ASF / WMA", "WMA", kASFExtensions, "container", "container", true, true, false, nullptr, "ASF attributes are exposed for structured editing." },
    { TLTagFileFormatDSF, "dsf", "DSF", "DSF", kDSFExtensions, "propertyMap", "propertyMap", true, true, false, nullptr, "DSF uses ID3v2 tags internally, but structured editing is currently limited to PropertyMap values." },
    { TLTagFileFormatDSDIFF, "dsdiff", "DSDIFF", "DSDIFF", kDSDIFFExtensions, "propertyMap", "propertyMap", true, true, false, nullptr, "DSDIFF uses ID3v2 tags internally, but structured editing is currently limited to PropertyMap values." },
    { TLTagFileFormatShorten, "shorten", "Shorten", "Shorten", kShortenExtensions, "propertyMap", "none", false, false, true, "TagLib 2.3.1 exposes Shorten metadata for reading but does not support saving it.", "Read-only format." },
    { TLTagFileFormatMOD, "mod", "MOD Tracker Module", "MOD", kMODExtensions, "propertyMap", "none", false, false, false, "TagLib exposes MOD metadata for reading but does not support saving it.", "MOD metadata is limited to title, comment, and a format-derived tracker name." },
    { TLTagFileFormatS3M, "s3m", "Scream Tracker 3 Module", "S3M", kS3MExtensions, "propertyMap", "propertyMap", false, false, false, nullptr, "Writes are limited to title and comment; fixed-width tracker storage may normalize text." },
    { TLTagFileFormatIT, "it", "Impulse Tracker Module", "IT", kITExtensions, "propertyMap", "propertyMap", false, false, false, nullptr, "Writes are limited to title and comment; fixed-width tracker storage may normalize text." },
    { TLTagFileFormatXM, "xm", "FastTracker Module", "XM", kXMExtensions, "propertyMap", "propertyMap", false, false, false, nullptr, "Writes are limited to title, comment, and tracker name; fixed-width instrument/sample fields normalize comment text and may pad the tracker name." },
};

bool DescriptorContainsExtension(const TLFormatCapabilityDescriptor &descriptor,
                                 NSString *lowerExtension)
{
    for (const char * const *extension = descriptor.extensions; *extension; ++extension) {
        if ([lowerExtension isEqualToString:@(*extension)]) return true;
    }
    return false;
}

} // namespace

std::span<const TLFormatCapabilityDescriptor> TLFormatCapabilityDescriptors()
{
    return kDescriptors;
}

const TLFormatCapabilityDescriptor *DescriptorForFormat(TLTagFileFormat format)
{
    for (const auto &descriptor : kDescriptors) {
        if (descriptor.format == format) return &descriptor;
    }
    return nullptr;
}

const TLFormatCapabilityDescriptor *DescriptorForExtension(NSString * _Nullable extension)
{
    if (!extension) return nullptr;
    NSString *lowerExtension = extension.lowercaseString;
    for (const auto &descriptor : kDescriptors) {
        if (DescriptorContainsExtension(descriptor, lowerExtension)) return &descriptor;
    }
    return nullptr;
}
