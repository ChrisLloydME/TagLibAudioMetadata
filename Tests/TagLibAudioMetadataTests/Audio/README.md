# Audio test fixtures

`testAudioFile.oga` is TagLib 2.3.1's `tests/data/empty_flac.oga` fixture,
copied from upstream commit `54ae7d8ac45755e286a5c574280f48d5bef93aef`.
Its SHA-256 is `5bd4dabaea093e00c451dd0b7466d4c0433206f06420a956e2bfc1994a6fe04d`.

`testAudioFile.xm` is TagLib 2.3.1's `tests/data/test.xm` fixture, copied from
upstream commit `54ae7d8ac45755e286a5c574280f48d5bef93aef`. It is redistributed under
TagLib's LGPL 2.1 or MPL 1.1 terms; the corresponding license texts are in
`ThirdParty/TagLib`.
Its SHA-256 is `e2a41fdeb527c273ab1dd8e360bc763f696b1c24804bc1c541176845992db54a`.

The AAC, FLAC, M4A, MP3, Ogg Vorbis, and WAV fixtures are locally generated
440 Hz test tones without third-party recordings. Their hashes are:

| Fixture | SHA-256 |
| --- | --- |
| `testAudioFile.aac` | `535f95dfc0d1feca89a2a80d60f4279ed15b4d057a784c5f181cb02a6881a7d3` |
| `testAudioFile.flac` | `01fbdf57907e9c799d0c98f641ec3b543b2ed91473a5a4e15df8ed072bd786f2` |
| `testAudioFile.m4a` | `af2171faed73cc10f21feefa980073b62a0d086ea390c2af3455127cfed3fb24` |
| `testAudioFile.mp3` | `9db9e5033b1c6d4fea48dc2b13e606f0b70625f86391bcbf0b9044f72f2012dc` |
| `testAudioFile.ogg` | `9901df8170531d790f421c69a864e57b53cfc921cf760cc267c46de25bcca6ad` |
| `testAudioFile.wav` | `fce6f158bdc9bdd9a0f9e2092da3c5d4686540076177d20227b5059e9b2cf218` |
| `testAudioFile-alac.m4a` | `e6e3917bbf65c13bcc52d711bb70465a99583556a3ee3f383f64d6db24e3422b` |
| `testAudioFile.wma` | `91dcf4eeac98e5f5f129f9acc2dd52c3fb15a2abb43f5598e435b630b6d29e47` |
| `testAudioFile.tta` | `a1eea3b528bbf5d37285b8fd7b4cf2bc089746c0b20a538cbefcb427bfb3eae3` |
| `testAudioFile.wv` | `56c7cb56ebefd3411efadc4af2fc6904268e406f43c6dd9d1ab7eadf59def1b7` |

`synthetic.opus` is a locally generated 0.1-second 440 Hz tone, with no
third-party recording. Generated using FFmpeg's `sine` source at 48 kHz and
`libopus`, with title `Synthetic Opus fixture`. SHA-256:
`df6216e78674e2c98206a744abbdd34c39aadf29425a4b92a7d8bcc8e9cbf3cd`.
It covers identification and title/custom-property preservation when renamed to
`.ogg`, `.oga`, and `.spx`; it is not a general Opus conformance corpus.

The ALAC M4A, ASF/WMA, TrueAudio, and WavPack fixtures were generated locally
from `testAudioFile.flac` with FFmpeg (ALAC, `wmav2`, `tta`, and `wavpack`
encoders). They are short test tones without third-party recordings and exist
only to exercise codec/artwork/attribute paths.

`info-only.wav` is a locally generated 0.1-second 440 Hz tone at 8 kHz,
encoded as PCM s16le by FFmpeg. It starts with RIFF INFO encoder metadata and
no ID3v2 tag. SHA-256:
`73d5b6b95bf833e72711907be6d5d1d0d5bb80ed420396348af6d6bf4ae2109b`.
It protects against INFO fields becoming invisible after adding ID3v2, and
against targeted text writes stripping unrelated INFO chunks.

## Verification-hardening fixtures

The following genuine audio files are copied unchanged from [TagLib 2.3.1,
commit 54ae7d8ac45755e286a5c574280f48d5bef93aef](https://github.com/taglib/taglib/tree/54ae7d8ac45755e286a5c574280f48d5bef93aef/tests/data).
They use the same upstream LGPL 2.1 / MPL 1.1 distribution terms as the existing
TagLib fixtures; license texts are retained in `ThirdParty/TagLib`.

| Local name | Upstream name | SHA-256 |
| --- | --- | --- |
| `hardening.dsf` | `empty10ms.dsf` | `f3b2de2c2e783e887771a95aa302496eb3a82fcb606c3276d40650e887a6f9aa` |
| `hardening.dff` | `empty10ms.dff` | `d7be2c9f3d539dffd49e73a9462a5daba3645ca4b20636f4518c8182ded8f8b5` |
| `hardening.ape` | `mac-399.ape` | `8c851b4f52bbbd822262040ae8961b8c27f8f702d1be3fa50cca283d009aadea` |
| `hardening.mpc` | `click.mpc` | `178f44eb55353512ef611ccca4d10557af7c2d329a6078a019a5d66d522d25ad` |

All four were recognized by FFprobe and decoded to completion by FFmpeg without
errors during acquisition. The upstream tests expect stereo DSD64 (2,822,400
one-bit samples/s) for DSF/DSDIFF, and stereo 44,100 Hz for APE/Musepack. FFmpeg
reports the packed DSD byte rate as 352,800 Hz; this is not a disagreement about
the DSD64 bit rate. The Musepack duration differs between FFmpeg and TagLib
because of decoder delay accounting; tests avoid claiming sample-exact agreement
between those readers.

These are small upstream test signals, not a codec conformance corpus.
Tests copy them before independently seeding metadata. Native expected values
and payload invariants are defined in the hardening tests rather than inferred
from a same-library round trip.

- `clean-room.aiff`: generated locally for clean-room remediation tests; AIFF COMM specifies 4,410 stereo 16-bit silent PCM frames at 44,100 Hz, with one SSND chunk. No external audio source or license applies.
