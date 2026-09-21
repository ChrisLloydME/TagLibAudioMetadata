#import "Internal/TLBridgeTransactions.hpp"

#include <cerrno>
#include <copyfile.h>
#include <cstdio>
#include <cstdlib>
#include <fcntl.h>
#include <map>
#include <memory>
#include <stdarg.h>
#include <string>
#include <sys/stat.h>
#include <unistd.h>

NSErrorDomain const TagLibMetadataErrorDomain = @"TagLibMetadataExtractor";

// Simple logging helper for TagLib debugging
static bool TagLibDebugLoggingEnabled() {
    static bool enabled = [] {
        NSDictionary<NSString *, NSString *> *environment = NSProcessInfo.processInfo.environment;
        NSString *value = environment[@"TAGLIBAUDIOMETADATA_DEBUG"] ?: @"";
        NSString *normalized = value.lowercaseString;
        return [normalized isEqualToString:@"1"] ||
               [normalized isEqualToString:@"true"] ||
               [normalized isEqualToString:@"yes"] ||
               [normalized isEqualToString:@"on"];
    }();
    return enabled;
}

void TLog(NSString *format, ...) {
    if (!TagLibDebugLoggingEnabled()) {
        return;
    }

    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    NSLog(@"[TagLib] %@", message);
}

// TagLib exposes process-wide registries and some format handlers retain shared
// state. Keep TagLib entry points serialized so callers of both the Swift facade
// and the public Objective-C API receive the same safety guarantee. File copies,
// fsync, rename, and other transaction work remain outside this lock. A recursive
// mutex is required because bridge transactions validate through the read API on
// the same thread.
std::recursive_mutex &TagLibBridgeMutex()
{
    static std::recursive_mutex mutex;
    return mutex;
}

void SetTagLibBridgeExceptionError(NSError * _Nullable * _Nullable error,
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

thread_local NSUInteger TagLibAtomicMutationDepth = 0;

TagLibAtomicMutationScope::TagLibAtomicMutationScope() { ++TagLibAtomicMutationDepth; }
TagLibAtomicMutationScope::~TagLibAtomicMutationScope() { --TagLibAtomicMutationDepth; }

static std::mutex &TagLibMutationLockRegistryMutex()
{
    static std::mutex mutex;
    return mutex;
}

static std::map<std::string, std::weak_ptr<std::recursive_mutex>> &TagLibMutationLockRegistry()
{
    static std::map<std::string, std::weak_ptr<std::recursive_mutex>> registry;
    return registry;
}

static std::string TagLibMutationLockKey(NSURL *fileURL)
{
    // Lock the directory entry, not the file inode: rename replaces the inode
    // while existing waiters still hold the old lock. Parent identity also
    // converges paths through symlinked directories. Hard-linked files are
    // rejected by the transaction before mutation; they need no alias lock.
    NSURL *target = fileURL.URLByStandardizingPath;
    NSURL *parent = target.URLByDeletingLastPathComponent;
    struct stat directory = {};
    if (stat(parent.path.fileSystemRepresentation, &directory) == 0) {
        // Conservative folding can serialize distinct names on case-sensitive
        // volumes, but never weakens exclusion on case-insensitive volumes.
        NSString *name = target.lastPathComponent.precomposedStringWithCanonicalMapping.lowercaseString;
        return "entry:" + std::to_string(static_cast<unsigned long long>(directory.st_dev)) +
            ":" + std::to_string(static_cast<unsigned long long>(directory.st_ino)) +
            ":" + std::string(name.UTF8String ?: "");
    }
    return "path:" + std::string(target.path.fileSystemRepresentation ?: "");
}

static std::shared_ptr<std::recursive_mutex> TagLibMutationLockForURL(NSURL *fileURL)
{
    std::string key = TagLibMutationLockKey(fileURL);
    std::lock_guard<std::mutex> registryGuard(TagLibMutationLockRegistryMutex());
    auto &registry = TagLibMutationLockRegistry();
    for (auto iterator = registry.begin(); iterator != registry.end();) {
        if (iterator->second.expired()) {
            iterator = registry.erase(iterator);
        } else {
            ++iterator;
        }
    }
    auto &entry = registry[key];
    std::shared_ptr<std::recursive_mutex> mutex = entry.lock();
    if (!mutex) {
        mutex = std::make_shared<std::recursive_mutex>();
        entry = mutex;
    }
    return mutex;
}

BOOL CoordinateTagLibFileMutation(NSURL * _Nullable fileURL,
                                  NSError * _Nullable * _Nullable error,
                                  NSString *operation,
                                  TagLibFileMutationCoordinationBlock _Nullable mutation)
{
    if (!fileURL || !fileURL.isFileURL || !mutation) {
        if (error) {
            *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                         code:9112
                                     userInfo:@{ NSLocalizedDescriptionKey : @"Metadata mutation coordination requires a file URL and operation" }];
        }
        return NO;
    }

    std::shared_ptr<std::recursive_mutex> mutex = TagLibMutationLockForURL(fileURL);
    std::lock_guard<std::recursive_mutex> mutationGuard(*mutex);
    @try {
        return mutation(error);
    } @catch (NSException *exception) {
        if (error) {
            *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                         code:9113
                                     userInfo:@{
                                         NSLocalizedDescriptionKey : [NSString stringWithFormat:@"%@ raised an Objective-C exception", operation],
                                         @"exceptionName" : exception.name ?: @"",
                                         @"exceptionReason" : exception.reason ?: @"",
                                     }];
        }
        return NO;
    }
}

static bool SameTagLibFileVersion(const struct stat &lhs, const struct stat &rhs)
{
    return lhs.st_dev == rhs.st_dev &&
        lhs.st_ino == rhs.st_ino &&
        lhs.st_size == rhs.st_size &&
        lhs.st_nlink == rhs.st_nlink &&
        lhs.st_mtimespec.tv_sec == rhs.st_mtimespec.tv_sec &&
        lhs.st_mtimespec.tv_nsec == rhs.st_mtimespec.tv_nsec &&
        lhs.st_ctimespec.tv_sec == rhs.st_ctimespec.tv_sec &&
        lhs.st_ctimespec.tv_nsec == rhs.st_ctimespec.tv_nsec;
}

static BOOL PerformAtomicTagLibMutationUncoordinated(NSURL * _Nullable fileURL,
                                                      NSError * _Nullable * _Nullable error,
                                                      NSString *operation,
                                                      TagLibAtomicMutationBlock _Nullable mutation)
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
    if (originalIdentity.st_nlink > 1) {
        if (error) {
            *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                         code:9111
                                     userInfo:@{ NSLocalizedDescriptionKey : @"Metadata mutation was refused because atomic replacement would split a hard-linked file" }];
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
    copyfile_flags_t copyFlags = COPYFILE_CLONE | COPYFILE_ACL;
    if (copyfile(targetURL.path.fileSystemRepresentation,
                 temporaryURL.path.fileSystemRepresentation,
                 nullptr,
                 copyFlags) != 0) {
        int copyErrorCode = errno;
        [fileManager removeItemAtURL:temporaryURL error:nil];
        if (error) {
            *error = [NSError errorWithDomain:@"TagLibMetadataExtractor"
                                         code:9103
                                     userInfo:@{
                                         NSLocalizedDescriptionKey : @"Could not create a transactional copy of the metadata destination",
                                         NSUnderlyingErrorKey : [NSError errorWithDomain:NSPOSIXErrorDomain
                                                                                    code:copyErrorCode
                                                                                userInfo:nil],
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
        currentIdentity.st_nlink != 1 ||
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
            *error = [NSError errorWithDomain:TagLibMetadataErrorDomain
                                         code:TagLibMetadataTransactionErrorCodeCommittedButDurabilityUncertain
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

BOOL PerformAtomicTagLibMutation(NSURL * _Nullable fileURL,
                                 NSError * _Nullable * _Nullable error,
                                 NSString *operation,
                                 TagLibAtomicMutationBlock _Nullable mutation)
{
    return CoordinateTagLibFileMutation(fileURL, error, operation, ^BOOL(NSError **coordinationError) {
        return PerformAtomicTagLibMutationUncoordinated(fileURL, coordinationError, operation, mutation);
    });
}

@implementation TagLibMetadataExtractor (TransactionCoordination)

+ (BOOL)coordinateMutationAtURL:(NSURL *)fileURL
                          error:(NSError **)error
                       mutation:(TagLibFileMutationCoordinationBlock)mutation
{
    return CoordinateTagLibFileMutation(fileURL, error, @"Metadata transaction", mutation);
}

@end
