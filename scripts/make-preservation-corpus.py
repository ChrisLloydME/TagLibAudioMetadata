#!/usr/bin/env python3
"""Create a disposable, generated-tone corpus for the opt-in preservation test.

Requires FFmpeg on PATH. Output is a NEW directory supplied by the caller.
No input music or repository fixture is modified. Encoded hashes may vary with
FFmpeg versions; the deterministic source and explicit metadata are the oracle.
"""
import argparse
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("directory", type=Path)
args = parser.parse_args()
args.directory.mkdir(parents=True, exist_ok=False)
formats = {"flac": "flac", "mp3": "libmp3lame", "m4a": "aac", "ogg": "vorbis",
           "opus": "opus", "wma": "wmav2", "wv": "wavpack", "tta": "tta"}
for extension, codec in formats.items():
    command = ["ffmpeg", "-hide_banner", "-loglevel", "error", "-f", "lavfi",
               "-i", "sine=frequency=731:sample_rate=48000:duration=0.15",
               "-map_metadata", "-1", "-ac", "2", "-c:a", codec, "-strict", "-2"]
    for key, value in {"title": "Generated corpus tone", "artist": "Hardening fixture",
                       "album": "Preservation corpus", "comment": "Unrelated comment",
                       "date": "2021-07-15", "track": "1/9", "disc": "1/2",
                       "HARDEN_KEEP": "Unrelated custom value"}.items():
        command.extend(["-metadata", f"{key}={value}"])
    command.append(str(args.directory / f"tone.{extension}"))
    subprocess.run(command, check=True)
    if extension == "tta":
        # FFmpeg's TTA muxer writes APEv2, whereas the pinned TagLib TTA
        # handler projects ID3. Seed valid ID3v2.4 independently so preservation
        # assertions have visible metadata to protect on this handler. Remove
        # the muxer's APEv2 surface first: mixed APEv2/ID3 TTA writes reject safely.
        def syncsafe(length):
            return bytes((length >> shift) & 127 for shift in (21, 14, 7, 0))
        def frame(key, value):
            payload = b"\x03" + value.encode("utf-8")
            return key.encode("ascii") + syncsafe(len(payload)) + b"\0\0" + payload
        frames = b"".join(frame(key, value) for key, value in {
            "TIT2": "Generated corpus tone", "TPE1": "Hardening fixture",
            "TALB": "Preservation corpus", "TDRC": "2021-07-15",
            "TRCK": "1/9", "TPOS": "1/2", "TXXX": "HARDEN_KEEP\0Unrelated custom value"
        }.items())
        target = args.directory / "tone.tta"
        audio = target.read_bytes()
        if audio[-32:-24] == b"APETAGEX":
            size = int.from_bytes(audio[-20:-16], "little")
            start = len(audio) - size
            if start >= 32 and audio[start - 32:start - 24] == b"APETAGEX":
                start -= 32
            if not 0 <= start <= len(audio) - 32:
                raise ValueError("Invalid generated APEv2 footer")
            audio = audio[:start]
        target.write_bytes(b"ID3\x04\0\0" + syncsafe(len(frames)) + frames + audio)
print(f"Generated {len(formats)} tone files in {args.directory}")
