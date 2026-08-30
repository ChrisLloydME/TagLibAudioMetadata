@implementation TagLibAudioMetadata

- (instancetype)init {
    if (self = [super init]) {
        _trackNumber = 0;
        _totalTracks = 0;
        _discNumber = 0;
        _totalDiscs = 0;
        _duration = 0.0;
        _bitrate = 0;
        _sampleRate = 0;
        _channels = 0;
        _bitDepth = 0;
        _bpm = 0;
        _compilation = NO;
        _explicitAdvisory = TagLibExplicitAdvisoryUnspecified;
        _removeArtwork = NO;
        _movementNumber = 0;
        _movementCount = 0;
    }
    return self;
}

- (BOOL)explicitContent {
    return self.explicitAdvisory == TagLibExplicitAdvisoryExplicit;
}

- (void)setExplicitContent:(BOOL)explicitContent {
    self.explicitAdvisory = explicitContent
        ? TagLibExplicitAdvisoryExplicit
        : TagLibExplicitAdvisoryClean;
}

@end

// Simple logging helper for TagLib debugging
static bool TagLibDebugLoggingEnabled() {
    static bool enabled = [] {
        NSString *value = [NSProcessInfo processInfo].environment[@"AUDIOMATOR_TAGLIB_DEBUG"] ?: @"";
        NSString *normalized = value.lowercaseString;
        return [normalized isEqualToString:@"1"] ||
               [normalized isEqualToString:@"true"] ||
               [normalized isEqualToString:@"yes"] ||
               [normalized isEqualToString:@"on"];
    }();
    return enabled;
}

static inline void TLog(NSString *format, ...) {
    if (!TagLibDebugLoggingEnabled()) {
        return;
    }

    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    NSLog(@"[TagLib] %@", message);
}

// TagLib 2.1.1 has unsynchronized process-wide and function-static mutable
// state in multiple format handlers (including MP4, ID3v2, RIFF, and ASF).
// Keep the lock in the bridge so callers of both the Swift facade and the public
// Objective-C API receive the same safety guarantee. A recursive mutex is
// required because atomic mutations validate their temporary file by calling
// back into the read API on the same thread.
static std::recursive_mutex &TagLibBridgeMutex()
{
    static std::recursive_mutex mutex;
    return mutex;
}

#define TAGLIB_BRIDGE_SERIAL_GUARD() \
    std::lock_guard<std::recursive_mutex> tagLibBridgeSerialGuard(TagLibBridgeMutex())

static void SetTagLibBridgeExceptionError(NSError **error,
                                          NSString *operation,
                                          const char * _Nullable detail,
                                          NSInteger code)
{
    if (!error) {
        return;
    }

    NSString *detailText = detail ? [NSString stringWithUTF8String:detail] : nil;
    NSString *description = detailText.length > 0
        ? [NSString stringWithFormat:@"%@ failed: %@", operation, detailText]
        : [NSString stringWithFormat:@"%@ failed because TagLib raised an unknown C++ exception", operation];
    *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                 code:code
                             userInfo:@{ NSLocalizedDescriptionKey : description }];
}

#define TAGLIB_BRIDGE_CATCH_WITH_ERROR(ERROR_POINTER, OPERATION, FALLBACK) \
    } catch (const std::exception &exception) { \
        SetTagLibBridgeExceptionError(ERROR_POINTER, OPERATION, exception.what(), 9000); \
        return FALLBACK; \
    } catch (...) { \
        SetTagLibBridgeExceptionError(ERROR_POINTER, OPERATION, nullptr, 9001); \
        return FALLBACK; \
    }

#define TAGLIB_BRIDGE_CATCH_SAFE(OPERATION, FALLBACK) \
    } catch (const std::exception &exception) { \
        TLog(@"%@ failed with a C++ exception: %s", OPERATION, exception.what()); \
        return FALLBACK; \
    } catch (...) { \
        TLog(@"%@ failed with an unknown C++ exception", OPERATION); \
        return FALLBACK; \
    }

typedef BOOL (^TagLibAtomicMutationBlock)(NSURL *temporaryURL, NSError **error);

static thread_local NSUInteger TagLibAtomicMutationDepth = 0;

class TagLibAtomicMutationScope {
public:
    TagLibAtomicMutationScope() { ++TagLibAtomicMutationDepth; }
    ~TagLibAtomicMutationScope() { --TagLibAtomicMutationDepth; }
};

static bool SameTagLibFileVersion(const struct stat &lhs, const struct stat &rhs)
{
    return lhs.st_dev == rhs.st_dev &&
        lhs.st_ino == rhs.st_ino &&
        lhs.st_size == rhs.st_size &&
        lhs.st_mtimespec.tv_sec == rhs.st_mtimespec.tv_sec &&
        lhs.st_mtimespec.tv_nsec == rhs.st_mtimespec.tv_nsec &&
        lhs.st_ctimespec.tv_sec == rhs.st_ctimespec.tv_sec &&
        lhs.st_ctimespec.tv_nsec == rhs.st_ctimespec.tv_nsec;
}

static BOOL PerformAtomicTagLibMutation(NSURL *fileURL,
                                        NSError **error,
                                        NSString *operation,
                                        TagLibAtomicMutationBlock mutation)
{
    if (!fileURL || !fileURL.isFileURL || !mutation) {
        if (error) {
            *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                         code:9100
                                     userInfo:@{ NSLocalizedDescriptionKey : @"Metadata mutations require a file URL" }];
        }
        return NO;
    }

    NSURL *targetURL = fileURL.URLByStandardizingPath;
    struct stat originalIdentity = {};
    if (lstat(targetURL.path.fileSystemRepresentation, &originalIdentity) != 0 ||
        !S_ISREG(originalIdentity.st_mode)) {
        if (error) {
            *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                         code:9101
                                     userInfo:@{ NSLocalizedDescriptionKey : @"Metadata mutations require an existing regular file and do not follow symbolic links" }];
        }
        return NO;
    }

    NSError *resourceError = nil;
    NSNumber *isRegularFile = nil;
    if (![targetURL getResourceValue:&isRegularFile
                              forKey:NSURLIsRegularFileKey
                               error:&resourceError] || !isRegularFile.boolValue) {
        if (error) {
            NSMutableDictionary *userInfo = [@{
                NSLocalizedDescriptionKey : @"Metadata mutations require an existing regular file",
            } mutableCopy];
            if (resourceError) {
                userInfo[NSUnderlyingErrorKey] = resourceError;
            }
            *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                         code:9101
                                     userInfo:userInfo];
        }
        return NO;
    }

    NSError *validationError = nil;
    if (![TagLibMetadataExtractor extractMetadataFromURL:targetURL error:&validationError]) {
        if (error) {
            NSMutableDictionary *userInfo = [@{
                NSLocalizedDescriptionKey : @"The metadata destination is not a readable, valid audio file",
            } mutableCopy];
            if (validationError) {
                userInfo[NSUnderlyingErrorKey] = validationError;
            }
            *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                         code:9102
                                     userInfo:userInfo];
        }
        return NO;
    }

    NSString *extension = targetURL.pathExtension;
    NSString *baseName = targetURL.URLByDeletingPathExtension.lastPathComponent;
    NSString *temporaryName = extension.length > 0
        ? [NSString stringWithFormat:@".%@.taglib-%@.%@", baseName, NSUUID.UUID.UUIDString, extension]
        : [NSString stringWithFormat:@".%@.taglib-%@", baseName, NSUUID.UUID.UUIDString];
    NSURL *temporaryURL = [targetURL.URLByDeletingLastPathComponent URLByAppendingPathComponent:temporaryName];

    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSError *copyError = nil;
    if (![fileManager copyItemAtURL:targetURL toURL:temporaryURL error:&copyError]) {
        if (error) {
            *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                         code:9103
                                     userInfo:@{
                                         NSLocalizedDescriptionKey : @"Could not create a transactional copy of the metadata destination",
                                         NSUnderlyingErrorKey : copyError,
                                     }];
        }
        return NO;
    }

    struct stat temporaryIdentity = {};
    if (lstat(temporaryURL.path.fileSystemRepresentation, &temporaryIdentity) != 0 ||
        !S_ISREG(temporaryIdentity.st_mode)) {
        [fileManager removeItemAtURL:temporaryURL error:nil];
        if (error) {
            *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                         code:9103
                                     userInfo:@{ NSLocalizedDescriptionKey : @"Transactional metadata copies must remain regular files" }];
        }
        return NO;
    }

    NSError *mutationError = nil;
    BOOL mutationSucceeded = NO;
    {
        TagLibAtomicMutationScope scope;
        mutationSucceeded = mutation(temporaryURL, &mutationError);
    }

    if (!mutationSucceeded) {
        [fileManager removeItemAtURL:temporaryURL error:nil];
        if (error) {
            *error = mutationError ?: [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                                           code:9104
                                                       userInfo:@{ NSLocalizedDescriptionKey : [NSString stringWithFormat:@"%@ failed", operation] }];
        }
        return NO;
    }

    NSError *postMutationValidationError = nil;
    if (![TagLibMetadataExtractor extractMetadataFromURL:temporaryURL error:&postMutationValidationError]) {
        [fileManager removeItemAtURL:temporaryURL error:nil];
        if (error) {
            NSMutableDictionary *userInfo = [@{
                NSLocalizedDescriptionKey : @"The metadata mutation produced an unreadable audio file",
            } mutableCopy];
            if (postMutationValidationError) {
                userInfo[NSUnderlyingErrorKey] = postMutationValidationError;
            }
            *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                         code:9106
                                     userInfo:userInfo];
        }
        return NO;
    }

    int temporaryDescriptor = open(temporaryURL.path.fileSystemRepresentation, O_RDONLY);
    if (temporaryDescriptor < 0 || fsync(temporaryDescriptor) != 0) {
        int syncErrorCode = errno;
        if (temporaryDescriptor >= 0) {
            close(temporaryDescriptor);
        }
        [fileManager removeItemAtURL:temporaryURL error:nil];
        if (error) {
            NSError *underlying = [NSError errorWithDomain:NSPOSIXErrorDomain code:syncErrorCode userInfo:nil];
            *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                         code:9107
                                     userInfo:@{
                                         NSLocalizedDescriptionKey : @"Could not flush the metadata mutation before commit",
                                         NSUnderlyingErrorKey : underlying,
                                     }];
        }
        return NO;
    }
    close(temporaryDescriptor);

    struct stat currentIdentity = {};
    if (lstat(targetURL.path.fileSystemRepresentation, &currentIdentity) != 0 ||
        !S_ISREG(currentIdentity.st_mode) ||
        !SameTagLibFileVersion(currentIdentity, originalIdentity)) {
        [fileManager removeItemAtURL:temporaryURL error:nil];
        if (error) {
            *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                         code:9108
                                     userInfo:@{ NSLocalizedDescriptionKey : @"The metadata destination changed before the transaction could commit" }];
        }
        return NO;
    }

    NSURL *parentURL = targetURL.URLByDeletingLastPathComponent;
    int parentDescriptor = open(parentURL.path.fileSystemRepresentation, O_RDONLY | O_DIRECTORY);
    if (parentDescriptor < 0) {
        int openErrorCode = errno;
        [fileManager removeItemAtURL:temporaryURL error:nil];
        if (error) {
            NSError *underlying = [NSError errorWithDomain:NSPOSIXErrorDomain code:openErrorCode userInfo:nil];
            *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                         code:9109
                                     userInfo:@{
                                         NSLocalizedDescriptionKey : @"Could not open the metadata destination directory for flushing",
                                         NSUnderlyingErrorKey : underlying,
                                     }];
        }
        return NO;
    }

    if (std::rename(temporaryURL.path.fileSystemRepresentation, targetURL.path.fileSystemRepresentation) != 0) {
        int renameErrorCode = errno;
        close(parentDescriptor);
        [fileManager removeItemAtURL:temporaryURL error:nil];
        if (error) {
            NSError *underlying = [NSError errorWithDomain:NSPOSIXErrorDomain code:renameErrorCode userInfo:nil];
            *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                         code:9105
                                     userInfo:@{
                                         NSLocalizedDescriptionKey : @"Could not atomically commit the metadata mutation",
                                         NSUnderlyingErrorKey : underlying,
                                     }];
        }
        return NO;
    }

    if (fsync(parentDescriptor) != 0) {
        int syncErrorCode = errno;
        close(parentDescriptor);
        if (error) {
            NSError *underlying = [NSError errorWithDomain:NSPOSIXErrorDomain code:syncErrorCode userInfo:nil];
            *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                         code:9110
                                     userInfo:@{
                                         NSLocalizedDescriptionKey : @"The metadata mutation was committed, but its directory entry could not be flushed",
                                         NSUnderlyingErrorKey : underlying,
                                     }];
        }
        return NO;
    }
    close(parentDescriptor);

    return YES;
}
