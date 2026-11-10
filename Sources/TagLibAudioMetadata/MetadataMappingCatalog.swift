//
//  MetadataMappingCatalog.swift
//  TagLibAudioMetadata
//
//  Declarative semantic-to-native target table for the public field registry.
//  This Swift catalog is the package-side source of truth. The generated
//  documentation matrix is derived from it by
//  scripts/generate-mapping-matrix.py; no production code is generated from
//  Markdown.
//

import Foundation

public enum MetadataMappingCatalog {
    /// The mapping contract this catalog implements, independent of the
    /// package release version.
    public static let contractVersion = "AM-TLAM-MAPPING-2.2"
    public static let decisionDate = "2026-11-09"

    public static let profiles: [MetadataTargetProfile] = [

        MetadataTargetProfile(
            semanticKey: "TITLE",
            shape: .text,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .textFrame, nativeIdentity: "TIT2", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .id3v24, storage: .textFrame, nativeIdentity: "TIT2", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Atom, nativeIdentity: "©nam", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "TITLE", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "TITLE", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .asf, storage: .asfAttribute, nativeIdentity: "Title", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .riffInfo, storage: .riffInfoKey, nativeIdentity: "INAM", shape: .text, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "ARTIST",
            shape: .textArray,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .textFrame, nativeIdentity: "TPE1", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .id3v24, storage: .textFrame, nativeIdentity: "TPE1", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Atom, nativeIdentity: "©ART", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "ARTIST", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "ARTIST", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .asf, storage: .asfAttribute, nativeIdentity: "Author", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .riffInfo, storage: .riffInfoKey, nativeIdentity: "IART", shape: .textArray, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "ALBUM",
            shape: .text,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .textFrame, nativeIdentity: "TALB", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .id3v24, storage: .textFrame, nativeIdentity: "TALB", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Atom, nativeIdentity: "©alb", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "ALBUM", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "ALBUM", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .asf, storage: .asfAttribute, nativeIdentity: "WM/AlbumTitle", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .riffInfo, storage: .riffInfoKey, nativeIdentity: "IPRD", shape: .text, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "ALBUMARTIST",
            shape: .textArray,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .textFrame, nativeIdentity: "TPE2", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .id3v24, storage: .textFrame, nativeIdentity: "TPE2", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Atom, nativeIdentity: "aART", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "ALBUMARTIST", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "ALBUM ARTIST", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .asf, storage: .asfAttribute, nativeIdentity: "WM/AlbumArtist", shape: .textArray, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "YEAR",
            shape: .text,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .textFrame, nativeIdentity: "TYER", shape: .text, preferredWrite: false, note: "read-only: independent v2.3 date codec is not verified"),
                MetadataNativeTarget(family: .id3v24, storage: .textFrame, nativeIdentity: "TDRC", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Atom, nativeIdentity: "©day", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "YEAR", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "YEAR", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .asf, storage: .asfAttribute, nativeIdentity: "WM/Year", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .riffInfo, storage: .riffInfoKey, nativeIdentity: "ICRD", shape: .text, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "DATE",
            shape: .text,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .textFrame, nativeIdentity: "TDAT", shape: .text, preferredWrite: false, note: "read-only: legacy DDMM codec is not independently verified"),
                MetadataNativeTarget(family: .id3v24, storage: .userTextFrame, nativeIdentity: "DATE", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Freeform, nativeIdentity: "DATE", shape: .text, preferredWrite: true, note: "explicit conventional extension"),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "DATE", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "DATE", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .asf, storage: .extensionTextKey, nativeIdentity: "DATE", shape: .text, preferredWrite: true, note: "explicit registered text extension"),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "RELEASEDATE",
            shape: .text,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .extensionFrame, nativeIdentity: "TDRL", shape: .text, preferredWrite: false, note: "read-only: v2.3 extension codec is not independently verified"),
                MetadataNativeTarget(family: .id3v24, storage: .textFrame, nativeIdentity: "TDRL", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Freeform, nativeIdentity: "RELEASEDATE", shape: .text, preferredWrite: true, note: "explicit conventional extension"),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "RELEASEDATE", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "RELEASEDATE", shape: .text, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "ORIGINALDATE",
            shape: .text,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .textFrame, nativeIdentity: "TORY", shape: .text, preferredWrite: false, note: "read-only: year-precision v2.3 original date codec is not verified"),
                MetadataNativeTarget(family: .id3v24, storage: .textFrame, nativeIdentity: "TDOR", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Freeform, nativeIdentity: "ORIGINALDATE", shape: .text, preferredWrite: true, note: "explicit conventional extension"),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "ORIGINALDATE", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "ORIGINALDATE", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .asf, storage: .asfAttribute, nativeIdentity: "WM/OriginalReleaseYear", shape: .text, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "TRACKNUMBER",
            shape: .integer,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .textFrame, nativeIdentity: "TRCK", shape: .integer, preferredWrite: true, numberComponent: .number),
                MetadataNativeTarget(family: .id3v24, storage: .textFrame, nativeIdentity: "TRCK", shape: .integer, preferredWrite: true, numberComponent: .number),
                MetadataNativeTarget(family: .mp4, storage: .intPair, nativeIdentity: "trkn", shape: .intPair, preferredWrite: true, numberComponent: .number),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "TRACKNUMBER", shape: .integer, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "TRACK", shape: .integer, preferredWrite: true),
                MetadataNativeTarget(family: .asf, storage: .asfAttribute, nativeIdentity: "WM/TrackNumber", shape: .integer, preferredWrite: true, numberComponent: .number),
                MetadataNativeTarget(family: .riffInfo, storage: .riffInfoKey, nativeIdentity: "ITRK", shape: .integer, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "TRACKTOTAL",
            shape: .integer,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .textFrame, nativeIdentity: "TRCK", shape: .integer, preferredWrite: true, numberComponent: .total),
                MetadataNativeTarget(family: .id3v24, storage: .textFrame, nativeIdentity: "TRCK", shape: .integer, preferredWrite: true, numberComponent: .total),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "TRACKTOTAL", shape: .integer, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "TRACKTOTAL", shape: .integer, preferredWrite: true),
                MetadataNativeTarget(family: .asf, storage: .asfAttribute, nativeIdentity: "WM/TrackNumber", shape: .integer, preferredWrite: true, numberComponent: .total),
                MetadataNativeTarget(family: .mp4, storage: .mp4Integer, nativeIdentity: "trkn", shape: .integer, preferredWrite: true, numberComponent: .total),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "DISCNUMBER",
            shape: .integer,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .textFrame, nativeIdentity: "TPOS", shape: .integer, preferredWrite: true, numberComponent: .number),
                MetadataNativeTarget(family: .id3v24, storage: .textFrame, nativeIdentity: "TPOS", shape: .integer, preferredWrite: true, numberComponent: .number),
                MetadataNativeTarget(family: .mp4, storage: .intPair, nativeIdentity: "disk", shape: .intPair, preferredWrite: true, numberComponent: .number),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "DISCNUMBER", shape: .integer, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "DISC", shape: .integer, preferredWrite: true),
                MetadataNativeTarget(family: .asf, storage: .asfAttribute, nativeIdentity: "WM/PartOfSet", shape: .integer, preferredWrite: true, numberComponent: .number),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "DISCTOTAL",
            shape: .integer,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .textFrame, nativeIdentity: "TPOS", shape: .integer, preferredWrite: true, numberComponent: .total),
                MetadataNativeTarget(family: .id3v24, storage: .textFrame, nativeIdentity: "TPOS", shape: .integer, preferredWrite: true, numberComponent: .total),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "DISCTOTAL", shape: .integer, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "DISCTOTAL", shape: .integer, preferredWrite: true),
                MetadataNativeTarget(family: .asf, storage: .asfAttribute, nativeIdentity: "WM/PartOfSet", shape: .integer, preferredWrite: true, numberComponent: .total),
                MetadataNativeTarget(family: .mp4, storage: .mp4Integer, nativeIdentity: "disk", shape: .integer, preferredWrite: true, numberComponent: .total),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "PICTURE",
            shape: .pictureCollection,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .binaryFrame, nativeIdentity: "APIC", shape: .pictureCollection, preferredWrite: true),
                MetadataNativeTarget(family: .id3v24, storage: .binaryFrame, nativeIdentity: "APIC", shape: .pictureCollection, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Atom, nativeIdentity: "covr", shape: .pictureCollection, preferredWrite: true),
                MetadataNativeTarget(family: .vorbisComment, storage: .complexProperty, nativeIdentity: "PICTURE", shape: .pictureCollection, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .complexProperty, nativeIdentity: "COVER ART", shape: .pictureCollection, preferredWrite: true),
                MetadataNativeTarget(family: .asf, storage: .asfAttribute, nativeIdentity: "WM/Picture", shape: .pictureCollection, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "LYRICS",
            shape: .textArray,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .qualifiedTextFrame, nativeIdentity: "USLT", shape: .textArray, preferredWrite: true, note: "entry identity includes language and description"),
                MetadataNativeTarget(family: .id3v24, storage: .qualifiedTextFrame, nativeIdentity: "USLT", shape: .textArray, preferredWrite: true, note: "entry identity includes language and description"),
                MetadataNativeTarget(family: .mp4, storage: .mp4Atom, nativeIdentity: "©lyr", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "LYRICS", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "LYRICS", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .asf, storage: .asfAttribute, nativeIdentity: "WM/Lyrics", shape: .textArray, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "COMMENT",
            shape: .textArray,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .qualifiedTextFrame, nativeIdentity: "COMM", shape: .textArray, preferredWrite: true, note: "entry identity includes language and description"),
                MetadataNativeTarget(family: .id3v24, storage: .qualifiedTextFrame, nativeIdentity: "COMM", shape: .textArray, preferredWrite: true, note: "entry identity includes language and description"),
                MetadataNativeTarget(family: .mp4, storage: .mp4Atom, nativeIdentity: "©cmt", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "COMMENT", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "COMMENT", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .asf, storage: .asfAttribute, nativeIdentity: "Description", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .riffInfo, storage: .riffInfoKey, nativeIdentity: "ICMT", shape: .textArray, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "GENRE",
            shape: .textArray,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .textFrame, nativeIdentity: "TCON", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .id3v24, storage: .textFrame, nativeIdentity: "TCON", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Atom, nativeIdentity: "©gen", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "GENRE", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "GENRE", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .asf, storage: .asfAttribute, nativeIdentity: "WM/Genre", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .riffInfo, storage: .riffInfoKey, nativeIdentity: "IGNR", shape: .textArray, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "COMPOSER",
            shape: .textArray,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .textFrame, nativeIdentity: "TCOM", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .id3v24, storage: .textFrame, nativeIdentity: "TCOM", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Atom, nativeIdentity: "©wrt", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "COMPOSER", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "COMPOSER", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .asf, storage: .asfAttribute, nativeIdentity: "WM/Composer", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .riffInfo, storage: .riffInfoKey, nativeIdentity: "IMUS", shape: .textArray, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "CONDUCTOR",
            shape: .textArray,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .textFrame, nativeIdentity: "TPE3", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .id3v24, storage: .textFrame, nativeIdentity: "TPE3", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Atom, nativeIdentity: "©con", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "CONDUCTOR", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "CONDUCTOR", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .asf, storage: .asfAttribute, nativeIdentity: "WM/Conductor", shape: .textArray, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "REMIXER",
            shape: .textArray,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .textFrame, nativeIdentity: "TPE4", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .id3v24, storage: .textFrame, nativeIdentity: "TPE4", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Freeform, nativeIdentity: "REMIXER", shape: .textArray, preferredWrite: true, note: "explicit conventional extension"),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "REMIXER", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "MIXARTIST", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .asf, storage: .asfAttribute, nativeIdentity: "WM/ModifiedBy", shape: .textArray, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "PERFORMER",
            shape: .roleText,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .roleFrame, nativeIdentity: "IPLS", shape: .roleText, preferredWrite: true, note: "shared role collection"),
                MetadataNativeTarget(family: .id3v24, storage: .roleFrame, nativeIdentity: "TMCL", shape: .roleText, preferredWrite: true, note: "shared role collection"),
                MetadataNativeTarget(family: .mp4, storage: .mp4Freeform, nativeIdentity: "PERFORMER", shape: .roleText, preferredWrite: true, note: "explicit conventional extension"),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "PERFORMER", shape: .roleText, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "PERFORMER", shape: .roleText, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "PRODUCER",
            shape: .textArray,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .userTextFrame, nativeIdentity: "PRODUCER", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .id3v24, storage: .userTextFrame, nativeIdentity: "PRODUCER", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Freeform, nativeIdentity: "PRODUCER", shape: .textArray, preferredWrite: true, note: "explicit conventional extension"),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "PRODUCER", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "PRODUCER", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .asf, storage: .asfAttribute, nativeIdentity: "WM/Producer", shape: .textArray, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "ENGINEER",
            shape: .textArray,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .userTextFrame, nativeIdentity: "ENGINEER", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .id3v24, storage: .userTextFrame, nativeIdentity: "ENGINEER", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Freeform, nativeIdentity: "ENGINEER", shape: .textArray, preferredWrite: true, note: "explicit conventional extension"),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "ENGINEER", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "ENGINEER", shape: .textArray, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "LYRICIST",
            shape: .textArray,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .textFrame, nativeIdentity: "TEXT", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .id3v24, storage: .textFrame, nativeIdentity: "TEXT", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Freeform, nativeIdentity: "LYRICIST", shape: .textArray, preferredWrite: true, note: "explicit conventional extension"),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "LYRICIST", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "LYRICIST", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .asf, storage: .asfAttribute, nativeIdentity: "WM/Writer", shape: .textArray, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "INVOLVEDPEOPLE",
            shape: .roleText,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .roleFrame, nativeIdentity: "IPLS", shape: .roleText, preferredWrite: true, note: "shared role collection"),
                MetadataNativeTarget(family: .id3v24, storage: .roleFrame, nativeIdentity: "TIPL", shape: .roleText, preferredWrite: true, note: "shared role collection"),
                MetadataNativeTarget(family: .mp4, storage: .mp4Freeform, nativeIdentity: "INVOLVEDPEOPLE", shape: .roleText, preferredWrite: true, note: "explicit conventional extension"),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "INVOLVEDPEOPLE", shape: .roleText, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "INVOLVEDPEOPLE", shape: .roleText, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "MUSICIANCREDITS",
            shape: .roleText,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .roleFrame, nativeIdentity: "IPLS", shape: .roleText, preferredWrite: true, note: "shared role collection"),
                MetadataNativeTarget(family: .id3v24, storage: .roleFrame, nativeIdentity: "TMCL", shape: .roleText, preferredWrite: true, note: "shared role collection"),
                MetadataNativeTarget(family: .mp4, storage: .mp4Freeform, nativeIdentity: "MUSICIANCREDITS", shape: .roleText, preferredWrite: true, note: "explicit conventional extension"),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "MUSICIANCREDITS", shape: .roleText, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "MUSICIANCREDITS", shape: .roleText, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "LABEL",
            shape: .text,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .textFrame, nativeIdentity: "TPUB", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .id3v24, storage: .textFrame, nativeIdentity: "TPUB", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Atom, nativeIdentity: "©pub", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "LABEL", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "LABEL", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .asf, storage: .asfAttribute, nativeIdentity: "WM/Publisher", shape: .text, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "COPYRIGHT",
            shape: .text,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .textFrame, nativeIdentity: "TCOP", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .id3v24, storage: .textFrame, nativeIdentity: "TCOP", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Atom, nativeIdentity: "cprt", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "COPYRIGHT", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "COPYRIGHT", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .asf, storage: .asfAttribute, nativeIdentity: "Copyright", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .riffInfo, storage: .riffInfoKey, nativeIdentity: "ICOP", shape: .text, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "ENCODEDBY",
            shape: .text,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .textFrame, nativeIdentity: "TENC", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .id3v24, storage: .textFrame, nativeIdentity: "TENC", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Atom, nativeIdentity: "©enc", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "ENCODEDBY", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "ENCODEDBY", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .asf, storage: .asfAttribute, nativeIdentity: "WM/EncodedBy", shape: .text, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "ENCODING",
            shape: .text,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .textFrame, nativeIdentity: "TSSE", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .id3v24, storage: .textFrame, nativeIdentity: "TSSE", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Atom, nativeIdentity: "©too", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "ENCODING", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "ENCODING", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .asf, storage: .asfAttribute, nativeIdentity: "WM/EncodingSettings", shape: .text, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "ISRC",
            shape: .text,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .textFrame, nativeIdentity: "TSRC", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .id3v24, storage: .textFrame, nativeIdentity: "TSRC", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Freeform, nativeIdentity: "ISRC", shape: .text, preferredWrite: true, note: "explicit conventional extension"),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "ISRC", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "ISRC", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .asf, storage: .asfAttribute, nativeIdentity: "WM/ISRC", shape: .text, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "BARCODE",
            shape: .text,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .userTextFrame, nativeIdentity: "BARCODE", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .id3v24, storage: .userTextFrame, nativeIdentity: "BARCODE", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Freeform, nativeIdentity: "BARCODE", shape: .text, preferredWrite: true, note: "explicit conventional extension"),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "BARCODE", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "BARCODE", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .asf, storage: .asfAttribute, nativeIdentity: "WM/Barcode", shape: .text, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "CATALOGNUMBER",
            shape: .text,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .userTextFrame, nativeIdentity: "CATALOGNUMBER", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .id3v24, storage: .userTextFrame, nativeIdentity: "CATALOGNUMBER", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Freeform, nativeIdentity: "CATALOGNUMBER", shape: .text, preferredWrite: true, note: "explicit conventional extension"),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "CATALOGNUMBER", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "CATALOGNUMBER", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .asf, storage: .asfAttribute, nativeIdentity: "WM/CatalogNo", shape: .text, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "ASIN",
            shape: .text,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .userTextFrame, nativeIdentity: "ASIN", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .id3v24, storage: .userTextFrame, nativeIdentity: "ASIN", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Freeform, nativeIdentity: "ASIN", shape: .text, preferredWrite: true, note: "explicit conventional extension"),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "ASIN", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "ASIN", shape: .text, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "RELEASETYPE",
            shape: .textArray,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .userTextFrame, nativeIdentity: "MusicBrainz Album Type", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .id3v24, storage: .userTextFrame, nativeIdentity: "MusicBrainz Album Type", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Freeform, nativeIdentity: "MusicBrainz Album Type", shape: .textArray, preferredWrite: true, note: "explicit conventional extension"),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "RELEASETYPE", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "MUSICBRAINZ_ALBUMTYPE", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .asf, storage: .asfAttribute, nativeIdentity: "MusicBrainz/Album Type", shape: .textArray, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "RELEASESTATUS",
            shape: .text,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .userTextFrame, nativeIdentity: "MusicBrainz Album Status", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .id3v24, storage: .userTextFrame, nativeIdentity: "MusicBrainz Album Status", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Freeform, nativeIdentity: "MusicBrainz Album Status", shape: .text, preferredWrite: true, note: "explicit conventional extension"),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "RELEASESTATUS", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "MUSICBRAINZ_ALBUMSTATUS", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .asf, storage: .asfAttribute, nativeIdentity: "MusicBrainz/Album Status", shape: .text, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "RELEASECOUNTRY",
            shape: .text,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .userTextFrame, nativeIdentity: "MusicBrainz Album Release Country", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .id3v24, storage: .userTextFrame, nativeIdentity: "MusicBrainz Album Release Country", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Freeform, nativeIdentity: "MusicBrainz Album Release Country", shape: .text, preferredWrite: true, note: "explicit conventional extension"),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "RELEASECOUNTRY", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "RELEASECOUNTRY", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .asf, storage: .asfAttribute, nativeIdentity: "MusicBrainz/Album Release Country", shape: .text, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "MEDIA",
            shape: .text,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .textFrame, nativeIdentity: "TMED", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .id3v24, storage: .textFrame, nativeIdentity: "TMED", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Freeform, nativeIdentity: "MEDIA", shape: .text, preferredWrite: true, note: "explicit conventional extension"),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "MEDIA", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "MEDIA", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .asf, storage: .asfAttribute, nativeIdentity: "WM/Media", shape: .text, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "WORK",
            shape: .text,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .userTextFrame, nativeIdentity: "WORK", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .id3v24, storage: .userTextFrame, nativeIdentity: "WORK", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "WORK", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "WORK", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Atom, nativeIdentity: "©wrk", shape: .text, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "MOVEMENTNAME",
            shape: .text,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .extensionFrame, nativeIdentity: "MVNM", shape: .text, preferredWrite: true, note: "version-extension frame"),
                MetadataNativeTarget(family: .id3v24, storage: .extensionFrame, nativeIdentity: "MVNM", shape: .text, preferredWrite: true, note: "version-extension frame"),
                MetadataNativeTarget(family: .mp4, storage: .mp4Atom, nativeIdentity: "©mvn", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "MOVEMENTNAME", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "MOVEMENTNAME", shape: .text, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "MOVEMENTNUMBER",
            shape: .integer,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .extensionFrame, nativeIdentity: "MVIN", shape: .integer, preferredWrite: true, numberComponent: .number, note: "version-extension frame"),
                MetadataNativeTarget(family: .id3v24, storage: .extensionFrame, nativeIdentity: "MVIN", shape: .integer, preferredWrite: true, numberComponent: .number, note: "version-extension frame"),
                MetadataNativeTarget(family: .mp4, storage: .mp4Atom, nativeIdentity: "©mvi", shape: .integer, preferredWrite: true),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "MOVEMENTNUMBER", shape: .integer, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "MOVEMENTNUMBER", shape: .integer, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "MOVEMENTCOUNT",
            shape: .integer,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .extensionFrame, nativeIdentity: "MVIN", shape: .integer, preferredWrite: true, numberComponent: .total, note: "version-extension frame"),
                MetadataNativeTarget(family: .id3v24, storage: .extensionFrame, nativeIdentity: "MVIN", shape: .integer, preferredWrite: true, numberComponent: .total, note: "version-extension frame"),
                MetadataNativeTarget(family: .mp4, storage: .mp4Atom, nativeIdentity: "©mvc", shape: .integer, preferredWrite: true),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "MOVEMENTCOUNT", shape: .integer, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "MOVEMENTCOUNT", shape: .integer, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "DISCSUBTITLE",
            shape: .text,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .userTextFrame, nativeIdentity: "DISCSUBTITLE", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .id3v24, storage: .textFrame, nativeIdentity: "TSST", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Freeform, nativeIdentity: "DISCSUBTITLE", shape: .text, preferredWrite: true, note: "explicit conventional extension"),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "DISCSUBTITLE", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "DISCSUBTITLE", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .asf, storage: .asfAttribute, nativeIdentity: "WM/SetSubTitle", shape: .text, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "SUBTITLE",
            shape: .text,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .textFrame, nativeIdentity: "TIT3", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .id3v24, storage: .textFrame, nativeIdentity: "TIT3", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Freeform, nativeIdentity: "SUBTITLE", shape: .text, preferredWrite: true, note: "explicit conventional extension"),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "SUBTITLE", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "SUBTITLE", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .asf, storage: .asfAttribute, nativeIdentity: "WM/SubTitle", shape: .text, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "GROUPING",
            shape: .textArray,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .extensionFrame, nativeIdentity: "GRP1", shape: .textArray, preferredWrite: true, note: "version-extension frame"),
                MetadataNativeTarget(family: .id3v24, storage: .extensionFrame, nativeIdentity: "GRP1", shape: .textArray, preferredWrite: true, note: "version-extension frame"),
                MetadataNativeTarget(family: .mp4, storage: .mp4Freeform, nativeIdentity: "GROUPING", shape: .textArray, preferredWrite: true, note: "explicit conventional extension"),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "GROUPING", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "GROUPING", shape: .textArray, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "MOOD",
            shape: .textArray,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .userTextFrame, nativeIdentity: "MOOD", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .id3v24, storage: .textFrame, nativeIdentity: "TMOO", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Freeform, nativeIdentity: "MOOD", shape: .textArray, preferredWrite: true, note: "explicit conventional extension"),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "MOOD", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "MOOD", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .asf, storage: .asfAttribute, nativeIdentity: "WM/Mood", shape: .textArray, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "LANGUAGE",
            shape: .textArray,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .textFrame, nativeIdentity: "TLAN", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .id3v24, storage: .textFrame, nativeIdentity: "TLAN", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Freeform, nativeIdentity: "LANGUAGE", shape: .textArray, preferredWrite: true, note: "explicit conventional extension"),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "LANGUAGE", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "LANGUAGE", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .asf, storage: .asfAttribute, nativeIdentity: "WM/Language", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .riffInfo, storage: .riffInfoKey, nativeIdentity: "ILNG", shape: .textArray, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "INITIALKEY",
            shape: .text,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .textFrame, nativeIdentity: "TKEY", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .id3v24, storage: .textFrame, nativeIdentity: "TKEY", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Freeform, nativeIdentity: "INITIALKEY", shape: .text, preferredWrite: true, note: "explicit conventional extension"),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "INITIALKEY", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "INITIALKEY", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .asf, storage: .asfAttribute, nativeIdentity: "WM/InitialKey", shape: .text, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "BPM",
            shape: .integer,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .textFrame, nativeIdentity: "TBPM", shape: .integer, preferredWrite: true),
                MetadataNativeTarget(family: .id3v24, storage: .textFrame, nativeIdentity: "TBPM", shape: .integer, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Integer, nativeIdentity: "tmpo", shape: .integer, preferredWrite: true),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "BPM", shape: .integer, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "BPM", shape: .integer, preferredWrite: true),
                MetadataNativeTarget(family: .asf, storage: .asfAttribute, nativeIdentity: "WM/BeatsPerMinute", shape: .integer, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "COMPILATION",
            shape: .boolean,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .extensionFrame, nativeIdentity: "TCMP", shape: .boolean, preferredWrite: true, note: "version-extension frame"),
                MetadataNativeTarget(family: .id3v24, storage: .extensionFrame, nativeIdentity: "TCMP", shape: .boolean, preferredWrite: true, note: "version-extension frame"),
                MetadataNativeTarget(family: .mp4, storage: .mp4Integer, nativeIdentity: "cpil", shape: .boolean, preferredWrite: true),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "COMPILATION", shape: .boolean, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "COMPILATION", shape: .boolean, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "ITUNESADVISORY",
            shape: .advisory,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .userTextFrame, nativeIdentity: "ITUNESADVISORY", shape: .advisory, preferredWrite: true),
                MetadataNativeTarget(family: .id3v24, storage: .userTextFrame, nativeIdentity: "ITUNESADVISORY", shape: .advisory, preferredWrite: true),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "ITUNESADVISORY", shape: .advisory, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "ITUNESADVISORY", shape: .advisory, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Integer, nativeIdentity: "rtng", shape: .advisory, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "TITLESORT",
            shape: .text,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .extensionFrame, nativeIdentity: "TSOT", shape: .text, preferredWrite: true, note: "version-extension frame"),
                MetadataNativeTarget(family: .id3v24, storage: .textFrame, nativeIdentity: "TSOT", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Atom, nativeIdentity: "sonm", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "TITLESORT", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "TITLESORT", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .asf, storage: .asfAttribute, nativeIdentity: "WM/TitleSortOrder", shape: .text, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "ARTISTSORT",
            shape: .text,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .extensionFrame, nativeIdentity: "TSOP", shape: .text, preferredWrite: true, note: "version-extension frame"),
                MetadataNativeTarget(family: .id3v24, storage: .textFrame, nativeIdentity: "TSOP", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Atom, nativeIdentity: "soar", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "ARTISTSORT", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "ARTISTSORT", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .asf, storage: .asfAttribute, nativeIdentity: "WM/ArtistSortOrder", shape: .text, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "ALBUMSORT",
            shape: .text,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .extensionFrame, nativeIdentity: "TSOA", shape: .text, preferredWrite: true, note: "version-extension frame"),
                MetadataNativeTarget(family: .id3v24, storage: .textFrame, nativeIdentity: "TSOA", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Atom, nativeIdentity: "soal", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "ALBUMSORT", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "ALBUMSORT", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .asf, storage: .asfAttribute, nativeIdentity: "WM/AlbumSortOrder", shape: .text, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "ALBUMARTISTSORT",
            shape: .text,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .extensionFrame, nativeIdentity: "TSO2", shape: .text, preferredWrite: true, note: "version-extension frame"),
                MetadataNativeTarget(family: .id3v24, storage: .extensionFrame, nativeIdentity: "TSO2", shape: .text, preferredWrite: true, note: "version-extension frame"),
                MetadataNativeTarget(family: .mp4, storage: .mp4Atom, nativeIdentity: "soaa", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "ALBUMARTISTSORT", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "ALBUMARTISTSORT", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .asf, storage: .asfAttribute, nativeIdentity: "WM/AlbumArtistSortOrder", shape: .text, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "COMPOSERSORT",
            shape: .text,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .extensionFrame, nativeIdentity: "TSOC", shape: .text, preferredWrite: true, note: "version-extension frame"),
                MetadataNativeTarget(family: .id3v24, storage: .extensionFrame, nativeIdentity: "TSOC", shape: .text, preferredWrite: true, note: "version-extension frame"),
                MetadataNativeTarget(family: .mp4, storage: .mp4Atom, nativeIdentity: "soco", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "COMPOSERSORT", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "COMPOSERSORT", shape: .text, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "MUSICBRAINZ_ARTISTID",
            shape: .textArray,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .userTextFrame, nativeIdentity: "MusicBrainz Artist Id", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .id3v24, storage: .userTextFrame, nativeIdentity: "MusicBrainz Artist Id", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Freeform, nativeIdentity: "MusicBrainz Artist Id", shape: .textArray, preferredWrite: true, note: "explicit conventional extension"),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "MUSICBRAINZ_ARTISTID", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "MUSICBRAINZ_ARTISTID", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .asf, storage: .asfAttribute, nativeIdentity: "MusicBrainz/Artist Id", shape: .textArray, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "MUSICBRAINZ_ALBUMID",
            shape: .text,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .userTextFrame, nativeIdentity: "MusicBrainz Album Id", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .id3v24, storage: .userTextFrame, nativeIdentity: "MusicBrainz Album Id", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Freeform, nativeIdentity: "MusicBrainz Album Id", shape: .text, preferredWrite: true, note: "explicit conventional extension"),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "MUSICBRAINZ_ALBUMID", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "MUSICBRAINZ_ALBUMID", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .asf, storage: .asfAttribute, nativeIdentity: "MusicBrainz/Album Id", shape: .text, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "MUSICBRAINZ_ALBUMARTISTID",
            shape: .textArray,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .userTextFrame, nativeIdentity: "MusicBrainz Album Artist Id", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .id3v24, storage: .userTextFrame, nativeIdentity: "MusicBrainz Album Artist Id", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Freeform, nativeIdentity: "MusicBrainz Album Artist Id", shape: .textArray, preferredWrite: true, note: "explicit conventional extension"),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "MUSICBRAINZ_ALBUMARTISTID", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "MUSICBRAINZ_ALBUMARTISTID", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .asf, storage: .asfAttribute, nativeIdentity: "MusicBrainz/Album Artist Id", shape: .textArray, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "MUSICBRAINZ_TRACKID",
            shape: .text,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .identifierFrame, nativeIdentity: "http://musicbrainz.org", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .id3v24, storage: .identifierFrame, nativeIdentity: "http://musicbrainz.org", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Freeform, nativeIdentity: "MusicBrainz Track Id", shape: .text, preferredWrite: true, note: "explicit conventional extension"),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "MUSICBRAINZ_TRACKID", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "MUSICBRAINZ_TRACKID", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .asf, storage: .asfAttribute, nativeIdentity: "MusicBrainz/Track Id", shape: .text, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "MUSICBRAINZ_RELEASEGROUPID",
            shape: .text,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .userTextFrame, nativeIdentity: "MusicBrainz Release Group Id", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .id3v24, storage: .userTextFrame, nativeIdentity: "MusicBrainz Release Group Id", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Freeform, nativeIdentity: "MusicBrainz Release Group Id", shape: .text, preferredWrite: true, note: "explicit conventional extension"),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "MUSICBRAINZ_RELEASEGROUPID", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "MUSICBRAINZ_RELEASEGROUPID", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .asf, storage: .asfAttribute, nativeIdentity: "MusicBrainz/Release Group Id", shape: .text, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "MUSICBRAINZ_RELEASETRACKID",
            shape: .text,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .userTextFrame, nativeIdentity: "MusicBrainz Release Track Id", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .id3v24, storage: .userTextFrame, nativeIdentity: "MusicBrainz Release Track Id", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Freeform, nativeIdentity: "MusicBrainz Release Track Id", shape: .text, preferredWrite: true, note: "explicit conventional extension"),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "MUSICBRAINZ_RELEASETRACKID", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "MUSICBRAINZ_RELEASETRACKID", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .asf, storage: .asfAttribute, nativeIdentity: "MusicBrainz/Release Track Id", shape: .text, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "MUSICBRAINZ_WORKID",
            shape: .textArray,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .userTextFrame, nativeIdentity: "MusicBrainz Work Id", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .id3v24, storage: .userTextFrame, nativeIdentity: "MusicBrainz Work Id", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Freeform, nativeIdentity: "MusicBrainz Work Id", shape: .textArray, preferredWrite: true, note: "explicit conventional extension"),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "MUSICBRAINZ_WORKID", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "MUSICBRAINZ_WORKID", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .asf, storage: .asfAttribute, nativeIdentity: "MusicBrainz/Work Id", shape: .textArray, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "ACOUSTID_ID",
            shape: .text,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .userTextFrame, nativeIdentity: "Acoustid Id", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .id3v24, storage: .userTextFrame, nativeIdentity: "Acoustid Id", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Freeform, nativeIdentity: "Acoustid Id", shape: .text, preferredWrite: true, note: "explicit conventional extension"),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "ACOUSTID_ID", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "ACOUSTID_ID", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .asf, storage: .asfAttribute, nativeIdentity: "Acoustid/Id", shape: .text, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "ACOUSTID_FINGERPRINT",
            shape: .text,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .userTextFrame, nativeIdentity: "Acoustid Fingerprint", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .id3v24, storage: .userTextFrame, nativeIdentity: "Acoustid Fingerprint", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Freeform, nativeIdentity: "Acoustid Fingerprint", shape: .text, preferredWrite: true, note: "explicit conventional extension"),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "ACOUSTID_FINGERPRINT", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "ACOUSTID_FINGERPRINT", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .asf, storage: .asfAttribute, nativeIdentity: "Acoustid/Fingerprint", shape: .text, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "MUSICIP_PUID",
            shape: .text,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .userTextFrame, nativeIdentity: "MusicIP PUID", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .id3v24, storage: .userTextFrame, nativeIdentity: "MusicIP PUID", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Freeform, nativeIdentity: "MusicIP PUID", shape: .text, preferredWrite: true, note: "explicit conventional extension"),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "MUSICIP_PUID", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "MUSICIP_PUID", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .asf, storage: .asfAttribute, nativeIdentity: "MusicIP/PUID", shape: .text, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "REPLAYGAIN_TRACK_GAIN",
            shape: .text,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .userTextFrame, nativeIdentity: "REPLAYGAIN_TRACK_GAIN", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .id3v24, storage: .userTextFrame, nativeIdentity: "REPLAYGAIN_TRACK_GAIN", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Freeform, nativeIdentity: "REPLAYGAIN_TRACK_GAIN", shape: .text, preferredWrite: true, note: "explicit conventional extension"),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "REPLAYGAIN_TRACK_GAIN", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "REPLAYGAIN_TRACK_GAIN", shape: .text, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "REPLAYGAIN_ALBUM_GAIN",
            shape: .text,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .userTextFrame, nativeIdentity: "REPLAYGAIN_ALBUM_GAIN", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .id3v24, storage: .userTextFrame, nativeIdentity: "REPLAYGAIN_ALBUM_GAIN", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Freeform, nativeIdentity: "REPLAYGAIN_ALBUM_GAIN", shape: .text, preferredWrite: true, note: "explicit conventional extension"),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "REPLAYGAIN_ALBUM_GAIN", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "REPLAYGAIN_ALBUM_GAIN", shape: .text, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "ITUNESALBUMID",
            shape: .text,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .userTextFrame, nativeIdentity: "ITUNESALBUMID", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .id3v24, storage: .userTextFrame, nativeIdentity: "ITUNESALBUMID", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "ITUNESALBUMID", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "ITUNESALBUMID", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Integer, nativeIdentity: "plID", shape: .integer, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "ITUNESARTISTID",
            shape: .text,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .userTextFrame, nativeIdentity: "ITUNESARTISTID", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .id3v24, storage: .userTextFrame, nativeIdentity: "ITUNESARTISTID", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "ITUNESARTISTID", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "ITUNESARTISTID", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Integer, nativeIdentity: "atID", shape: .integer, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "ITUNESCATALOGID",
            shape: .text,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .userTextFrame, nativeIdentity: "ITUNESCATALOGID", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .id3v24, storage: .userTextFrame, nativeIdentity: "ITUNESCATALOGID", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "ITUNESCATALOGID", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "ITUNESCATALOGID", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Integer, nativeIdentity: "cnID", shape: .integer, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "ITUNESGENREID",
            shape: .text,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .userTextFrame, nativeIdentity: "ITUNESGENREID", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .id3v24, storage: .userTextFrame, nativeIdentity: "ITUNESGENREID", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "ITUNESGENREID", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "ITUNESGENREID", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Integer, nativeIdentity: "geID", shape: .integer, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "ITUNESMEDIATYPE",
            shape: .text,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .userTextFrame, nativeIdentity: "ITUNESMEDIATYPE", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .id3v24, storage: .userTextFrame, nativeIdentity: "ITUNESMEDIATYPE", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "ITUNESMEDIATYPE", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "ITUNESMEDIATYPE", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Integer, nativeIdentity: "stik", shape: .integer, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "ITUNESPURCHASEDATE",
            shape: .text,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .userTextFrame, nativeIdentity: "ITUNESPURCHASEDATE", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .id3v24, storage: .userTextFrame, nativeIdentity: "ITUNESPURCHASEDATE", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "ITUNESPURCHASEDATE", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "ITUNESPURCHASEDATE", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Atom, nativeIdentity: "purd", shape: .text, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "ITUNNORM",
            shape: .text,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .userTextFrame, nativeIdentity: "iTunNORM", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .id3v24, storage: .userTextFrame, nativeIdentity: "iTunNORM", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Freeform, nativeIdentity: "iTunNORM", shape: .text, preferredWrite: true, note: "explicit conventional extension"),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "ITUNNORM", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "ITUNNORM", shape: .text, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "ITUNSMPB",
            shape: .text,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .userTextFrame, nativeIdentity: "iTunSMPB", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .id3v24, storage: .userTextFrame, nativeIdentity: "iTunSMPB", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Freeform, nativeIdentity: "iTunSMPB", shape: .text, preferredWrite: true, note: "explicit conventional extension"),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "ITUNSMPB", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "ITUNSMPB", shape: .text, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "ORIGINALALBUM",
            shape: .text,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .textFrame, nativeIdentity: "TOAL", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .id3v24, storage: .textFrame, nativeIdentity: "TOAL", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Freeform, nativeIdentity: "ORIGINALALBUM", shape: .text, preferredWrite: true, note: "explicit conventional extension"),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "ORIGINALALBUM", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "ORIGINALALBUM", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .asf, storage: .asfAttribute, nativeIdentity: "WM/OriginalAlbumTitle", shape: .text, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "ORIGINALARTIST",
            shape: .textArray,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .textFrame, nativeIdentity: "TOPE", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .id3v24, storage: .textFrame, nativeIdentity: "TOPE", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Freeform, nativeIdentity: "ORIGINALARTIST", shape: .textArray, preferredWrite: true, note: "explicit conventional extension"),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "ORIGINALARTIST", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "ORIGINALARTIST", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .asf, storage: .asfAttribute, nativeIdentity: "WM/OriginalArtist", shape: .textArray, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "MUSICBRAINZ_ARTISTTYPE",
            shape: .text,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .userTextFrame, nativeIdentity: "MusicBrainz Artist Type", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .id3v24, storage: .userTextFrame, nativeIdentity: "MusicBrainz Artist Type", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Freeform, nativeIdentity: "MusicBrainz Artist Type", shape: .text, preferredWrite: true, note: "explicit conventional extension"),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "MUSICBRAINZ_ARTISTTYPE", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "MUSICBRAINZ_ARTISTTYPE", shape: .text, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "TRACKERNAME",
            shape: .text,
            targets: [
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "<explicit key>",
            shape: .textArray,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .userTextFrame, nativeIdentity: "<description>", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .id3v24, storage: .userTextFrame, nativeIdentity: "<description>", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Freeform, nativeIdentity: "<description>", shape: .textArray, preferredWrite: true, note: "explicit conventional extension"),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "<explicit key>", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "<explicit key>", shape: .textArray, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "CONTENTGROUP",
            shape: .text,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .textFrame, nativeIdentity: "TIT1", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .id3v24, storage: .textFrame, nativeIdentity: "TIT1", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Atom, nativeIdentity: "©grp", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "CONTENTGROUP", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "CONTENTGROUP", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .asf, storage: .asfAttribute, nativeIdentity: "WM/ContentGroupDescription", shape: .text, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "ARTISTS",
            shape: .textArray,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .userTextFrame, nativeIdentity: "ARTISTS", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .id3v24, storage: .userTextFrame, nativeIdentity: "ARTISTS", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Freeform, nativeIdentity: "ARTISTS", shape: .textArray, preferredWrite: true, note: "explicit conventional extension"),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "ARTISTS", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "ARTISTS", shape: .textArray, preferredWrite: true),
                MetadataNativeTarget(family: .asf, storage: .asfAttribute, nativeIdentity: "WM/ARTISTS", shape: .textArray, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "REPLAYGAIN_TRACK_PEAK",
            shape: .text,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .userTextFrame, nativeIdentity: "REPLAYGAIN_TRACK_PEAK", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .id3v24, storage: .userTextFrame, nativeIdentity: "REPLAYGAIN_TRACK_PEAK", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Freeform, nativeIdentity: "REPLAYGAIN_TRACK_PEAK", shape: .text, preferredWrite: true, note: "explicit conventional extension"),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "REPLAYGAIN_TRACK_PEAK", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "REPLAYGAIN_TRACK_PEAK", shape: .text, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "REPLAYGAIN_ALBUM_PEAK",
            shape: .text,
            targets: [
                MetadataNativeTarget(family: .id3v23, storage: .userTextFrame, nativeIdentity: "REPLAYGAIN_ALBUM_PEAK", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .id3v24, storage: .userTextFrame, nativeIdentity: "REPLAYGAIN_ALBUM_PEAK", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .mp4, storage: .mp4Freeform, nativeIdentity: "REPLAYGAIN_ALBUM_PEAK", shape: .text, preferredWrite: true, note: "explicit conventional extension"),
                MetadataNativeTarget(family: .vorbisComment, storage: .textKey, nativeIdentity: "REPLAYGAIN_ALBUM_PEAK", shape: .text, preferredWrite: true),
                MetadataNativeTarget(family: .apev2, storage: .textKey, nativeIdentity: "REPLAYGAIN_ALBUM_PEAK", shape: .text, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "DIRECTOR",
            shape: .textArray,
            targets: [
                MetadataNativeTarget(family: .mp4, storage: .mp4Atom, nativeIdentity: "©dir", shape: .textArray, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "ITUNESACCOUNT",
            shape: .text,
            targets: [
                MetadataNativeTarget(family: .mp4, storage: .mp4Atom, nativeIdentity: "apID", shape: .text, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "ITUNESCOMPOSERID",
            shape: .integer,
            targets: [
                MetadataNativeTarget(family: .mp4, storage: .mp4Integer, nativeIdentity: "cmID", shape: .integer, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "ITUNESCOUNTRYID",
            shape: .integer,
            targets: [
                MetadataNativeTarget(family: .mp4, storage: .mp4Integer, nativeIdentity: "sfID", shape: .integer, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "ITUNESGAPLESS",
            shape: .boolean,
            targets: [
                MetadataNativeTarget(family: .mp4, storage: .mp4Integer, nativeIdentity: "pgap", shape: .boolean, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "ITUNESHDVIDEO",
            shape: .boolean,
            targets: [
                MetadataNativeTarget(family: .mp4, storage: .mp4Integer, nativeIdentity: "hdvd", shape: .boolean, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "OWNER",
            shape: .text,
            targets: [
                MetadataNativeTarget(family: .mp4, storage: .mp4Atom, nativeIdentity: "ownr", shape: .text, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "RATE",
            shape: .integer,
            targets: [
                MetadataNativeTarget(family: .mp4, storage: .mp4Integer, nativeIdentity: "rate", shape: .integer, preferredWrite: false, note: "no verified native rating type or scale in this profile"),
            ],
            writeUnsupportedReason: "no verified native rating type or scale in this profile"
        ),
        MetadataTargetProfile(
            semanticKey: "SHOWMOVEMENT",
            shape: .boolean,
            targets: [
                MetadataNativeTarget(family: .mp4, storage: .mp4Integer, nativeIdentity: "shwm", shape: .boolean, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "STOREDESCRIPTION",
            shape: .text,
            targets: [
                MetadataNativeTarget(family: .mp4, storage: .mp4Atom, nativeIdentity: "sdes", shape: .text, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "TVEPISODE",
            shape: .integer,
            targets: [
                MetadataNativeTarget(family: .mp4, storage: .mp4Integer, nativeIdentity: "tves", shape: .integer, preferredWrite: true),
                MetadataNativeTarget(family: .matroska, storage: .matroskaSimpleTag, nativeIdentity: "PART_NUMBER@TargetTypeValue=50", shape: .integer, preferredWrite: false, note: "target registration only; native implementation pending"),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "TVEPISODEID",
            shape: .text,
            targets: [
                MetadataNativeTarget(family: .mp4, storage: .mp4Atom, nativeIdentity: "tven", shape: .text, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "TVNETWORK",
            shape: .text,
            targets: [
                MetadataNativeTarget(family: .mp4, storage: .mp4Atom, nativeIdentity: "tvnn", shape: .text, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "TVSEASON",
            shape: .integer,
            targets: [
                MetadataNativeTarget(family: .mp4, storage: .mp4Integer, nativeIdentity: "tvsn", shape: .integer, preferredWrite: true),
                MetadataNativeTarget(family: .matroska, storage: .matroskaSimpleTag, nativeIdentity: "PART_NUMBER@TargetTypeValue=60", shape: .integer, preferredWrite: false, note: "target registration only; native implementation pending"),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "TVSHOW",
            shape: .text,
            targets: [
                MetadataNativeTarget(family: .mp4, storage: .mp4Atom, nativeIdentity: "tvsh", shape: .text, preferredWrite: true),
            ],
        ),
        MetadataTargetProfile(
            semanticKey: "SHOWSORT",
            shape: .text,
            targets: [
                MetadataNativeTarget(family: .mp4, storage: .mp4Atom, nativeIdentity: "sosn", shape: .text, preferredWrite: true),
            ],
        ),
    ]

    private static let bySemanticKey: [String: MetadataTargetProfile] =
        Dictionary(uniqueKeysWithValues: profiles.map { ($0.semanticKey, $0) })

    public static func profile(forSemanticKey key: String) -> MetadataTargetProfile? {
        bySemanticKey[key.uppercased()]
    }

    /// Every semantic key with an explicit registration, sorted for stable
    /// coverage reporting.
    public static let semanticKeys: [String] =
        profiles.map(\.semanticKey).sorted()
}

