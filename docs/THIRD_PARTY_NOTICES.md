# Third-Party Notices

This document identifies the third-party libraries included in the `TagLibAudioMetadata` Swift Package and summarizes their licensing requirements.

---

## TagLib

**Version vendored:** 2.1.1  
**Source location in this repository:** `Sources/CTagLibBridge/taglib/`  
**Project homepage:** https://taglib.org  
**Source repository:** https://github.com/taglib/taglib

TagLib is an audio metadata reading and writing library. It is used by this package as the underlying engine for all audio file metadata operations.

### License

TagLib is dual-licensed. You may choose either of the following licenses:

- **GNU Lesser General Public License version 2.1** (LGPL-2.1)  
  Full text: `Sources/CTagLibBridge/taglib/COPYING.LGPL`

- **Mozilla Public License version 1.1** (MPL-1.1)  
  Full text: `Sources/CTagLibBridge/taglib/COPYING.MPL`

Both license files are included in this repository at the paths above.

### LGPL-2.1 summary (not a substitute for the full license text)

Under the LGPL-2.1, you may:
- Use TagLib in proprietary (closed-source) applications.
- Distribute applications that include TagLib in compiled form.

You must:
- Preserve the copyright notice and license text (the full LGPL text).
- Make the TagLib source code available to recipients, or ensure that recipients can obtain it. One acceptable method is to point to the upstream TagLib source repository.
- Allow recipients to relink the application against a modified version of TagLib (the "reverse engineering" clause).

When distributing compiled binaries that include TagLib, review the LGPL-2.1 requirements carefully. Dynamic linking can simplify compliance; static linking requires additional steps such as providing object files or ensuring recipients can relink. The specifics depend on your distribution method and legal jurisdiction. Consult legal counsel if you are uncertain.

### MPL-1.1 summary (not a substitute for the full license text)

Under the MPL-1.1, you may:
- Use TagLib in proprietary applications.
- Distribute combined works that include TagLib source.

You must:
- Preserve the MPL-1.1 notice in any file that contains covered code.
- Make modifications to covered code (TagLib source files) available under the MPL-1.1.
- Provide access to the source of any covered files you distribute.

---

## utfcpp (UTF-8 CPP)

TagLib bundles a copy of the `utfcpp` library for UTF-8 string handling.

**Source location:** `Sources/CTagLibBridge/taglib/3rdparty/utfcpp/`  
**Project homepage:** https://github.com/nemtrif/utfcpp

utfcpp is released under the **Boost Software License 1.0**, which permits use in proprietary software. The license header is included in the source files at the path above.

---

## This package (TagLibAudioMetadata bridge and Swift facade)

**License:** MIT License  
**Full text:** `LICENSE` (in the repository root)

```
MIT License

Copyright (c) 2026 Christopher Lloyd

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## Summary table

| Component | Version | License | Source path |
| --- | --- | --- | --- |
| TagLib | 2.1.1 | LGPL-2.1 or MPL-1.1 (your choice) | `Sources/CTagLibBridge/taglib/` |
| utfcpp | bundled with TagLib 2.1.1 | Boost Software License 1.0 | `Sources/CTagLibBridge/taglib/3rdparty/utfcpp/` |
| TagLibAudioMetadata (this package) | see CHANGELOG | MIT | `LICENSE` |

---

## Upstream license files

The TagLib upstream license files that are relevant to distribution are included at:

- `Sources/CTagLibBridge/taglib/COPYING.LGPL` — GNU Lesser General Public License v2.1
- `Sources/CTagLibBridge/taglib/COPYING.MPL` — Mozilla Public License v1.1

These files are excluded from the Swift Package Manager build (see `Package.swift` `exclude:` entries) but are present in the repository for compliance purposes.

---

## Disclaimer

This document is provided as an informational summary to assist with license compliance. It is not a legal opinion and does not constitute legal advice. For definitive guidance on license obligations, consult the full license texts and, if necessary, legal counsel.
