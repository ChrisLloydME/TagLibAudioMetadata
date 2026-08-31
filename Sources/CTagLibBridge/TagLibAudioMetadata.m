#import "TagLibMetadataExtractor.h"

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
