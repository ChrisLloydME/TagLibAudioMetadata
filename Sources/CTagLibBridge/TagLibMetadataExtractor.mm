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
#include <cstdlib>
#include <fcntl.h>
#include <initializer_list>
#include <limits>
#include <mutex>
#include <sys/stat.h>
#include <unistd.h>
#include <stdarg.h>

#include "Internal/TLTagLibHeaders.hpp"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnullability-completeness"

#include "Internal/TLBridgeTransactions.hpp"

@implementation TagLibMetadataExtractor

#pragma mark - Helper Functions


// Convert TagLib::String to NSString
#include "Internal/TLMetadataCore.inc"
#include "Internal/TLPropertyMapCodec.inc"
#include "Internal/TLPropertyMapWrites.inc"
#include "Internal/TLPropertyMapDelta.inc"
#include "Internal/TLContainerExtractors.inc"
#include "Internal/TLBasicBridgeOperations.inc"
#include "Internal/TLRawBridgeOperations.inc"
#include "Internal/TLWriteBridgeOperations.inc"
#include "Internal/TLStructuredInspection.inc"
#include "Internal/TLUnifiedExtraction.inc"
#include "Internal/TLStructuredMutation.inc"
#include "Internal/TLInPlaceBridgeOperations.inc"
#include "Internal/TLRawInspection.inc"

#pragma clang diagnostic pop

@end
