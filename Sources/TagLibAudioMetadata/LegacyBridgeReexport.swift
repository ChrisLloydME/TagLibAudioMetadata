//
//  LegacyBridgeReexport.swift
//  TagLibAudioMetadata
//

// Source compatibility for clients that historically received CTagLibBridge
// by importing TagLibAudioMetadata. New low-level clients should depend on the
// TagLibAudioMetadataLowLevel product and import CTagLibBridge explicitly. This
// shim can be removed at the next source-breaking major version.
@_exported import CTagLibBridge
