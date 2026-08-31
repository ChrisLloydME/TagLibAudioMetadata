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
