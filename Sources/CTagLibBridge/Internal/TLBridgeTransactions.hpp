#pragma once

#import "TagLibMetadataExtractor.h"

#include <exception>
#include <mutex>

NS_ASSUME_NONNULL_BEGIN

void TLog(NSString *format, ...);
std::recursive_mutex &TagLibBridgeMutex();
void SetTagLibBridgeExceptionError(NSError * _Nullable * _Nullable error,
                                   NSString *operation,
                                   const char * _Nullable detail,
                                   NSInteger code);

#define TAGLIB_BRIDGE_SERIAL_GUARD() \
    std::lock_guard<std::recursive_mutex> tagLibBridgeSerialGuard(TagLibBridgeMutex())

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

typedef BOOL (^TagLibAtomicMutationBlock)(NSURL *temporaryURL,
                                          NSError * _Nullable * _Nullable error);

extern thread_local NSUInteger TagLibAtomicMutationDepth;

class TagLibAtomicMutationScope {
public:
    TagLibAtomicMutationScope();
    ~TagLibAtomicMutationScope();
    TagLibAtomicMutationScope(const TagLibAtomicMutationScope &) = delete;
    TagLibAtomicMutationScope &operator=(const TagLibAtomicMutationScope &) = delete;
};

BOOL PerformAtomicTagLibMutation(NSURL * _Nullable fileURL,
                                 NSError * _Nullable * _Nullable error,
                                 NSString *operation,
                                 TagLibAtomicMutationBlock _Nullable mutation);

NS_ASSUME_NONNULL_END
