//
//  TagLibMetadataExtractor.mm
//  AudioMator
//
//  Objective-C++ implementation using TagLib
//

#import "TagLibMetadataExtractor.h"
#include <exception>
#include <cstring>
#include <cerrno>
#include <cstdio>
#include <fcntl.h>
#include <initializer_list>
#include <limits>
#include <sys/stat.h>
#include <unistd.h>
#include <stdarg.h>

// TagLib C++ headers
#include <TagLib/fileref.h>
#include <TagLib/tag.h>
#include <TagLib/audioproperties.h>
#include <TagLib/tpropertymap.h>

// Format-specific headers
#include <TagLib/mpegfile.h>
#include <TagLib/id3v1tag.h>
#include <TagLib/id3v2tag.h>
#include <TagLib/id3v2frame.h>
#include <TagLib/attachedpictureframe.h>
#include <TagLib/textidentificationframe.h>
#include <TagLib/commentsframe.h>
#include <TagLib/unsynchronizedlyricsframe.h>
#include <TagLib/popularimeterframe.h>
#include <TagLib/urllinkframe.h>
#include <TagLib/uniquefileidentifierframe.h>
#include <TagLib/chapterframe.h>
#include <TagLib/tableofcontentsframe.h>
#include <TagLib/podcastframe.h>

#include <TagLib/mp4file.h>
#include <TagLib/mp4tag.h>
#include <TagLib/mp4item.h>
#include <TagLib/mp4coverart.h>

#include <TagLib/flacfile.h>
#include <TagLib/flacpicture.h>
#include <TagLib/xiphcomment.h>
#include <TagLib/asftag.h>
#include <TagLib/asfattribute.h>
#include <TagLib/asfpicture.h>

#include <TagLib/vorbisfile.h>
#include <TagLib/opusfile.h>
#include <TagLib/oggflacfile.h>

#include <TagLib/apefile.h>
#include <TagLib/apetag.h>

#include <TagLib/wavfile.h>
#include <TagLib/aifffile.h>
#include <TagLib/wavpackfile.h>
#include <TagLib/trueaudiofile.h>

#include <TagLib/mpcfile.h>
#include <TagLib/speexfile.h>
#include <TagLib/asffile.h>

#include <TagLib/dsffile.h>
#include <TagLib/dsdifffile.h>
#include <TagLib/shortenfile.h>
#include <TagLib/modfile.h>
#include <TagLib/s3mfile.h>
#include <TagLib/itfile.h>
#include <TagLib/xmfile.h>

#include <TagLib/tstring.h>
#include <TagLib/tstringlist.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnullability-completeness"

#include "Internal/TLBridgeTransactions.inc"

@implementation TagLibMetadataExtractor

#pragma mark - Helper Functions


// Convert TagLib::String to NSString
#include "Internal/TLMetadataCore.inc"
#include "Internal/TLPropertyMapCodec.inc"
#include "Internal/TLPropertyMapWrites.inc"
#include "Internal/TLContainerExtractors.inc"
#include "Internal/TLBasicBridgeOperations.inc"
#include "Internal/TLRawBridgeOperations.inc"
#include "Internal/TLWriteBridgeOperations.inc"
#include "Internal/TLStructuredInspection.inc"
#include "Internal/TLStructuredMutation.inc"
#include "Internal/TLRawInspection.inc"

#pragma clang diagnostic pop

@end
