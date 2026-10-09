# Changelog

Versions follow [semantic versioning](https://semver.org). The version in
`mach.toml` is the release; each release is the git tag `vX.Y.Z`, which is
also what a Mach project depending on Ramjet pins (`ref = "tag/vX.Y.Z"`).

## Unreleased

- Checksums (CRC32, BLAKE2sp) and file writes run on a second thread for
  files of 1 MB and more, overlapping with decompression.
- BLAKE2s compression is unrolled: archives with BLAKE2 checksums test
  about 1.4x faster.

- Fix: RAR 3.x and 4.x archives with passwords of 29 or more characters
  did not decrypt. RAR hashes the password with a SHA-1 quirk that
  overwrites the password buffer once it passes 64 bytes; checked against
  archives made by RAR 3.00, 3.41, 3.50 and 4.20. (This is what the 0.3.0
  note about "RAR 3.0-3.4 encryption" actually was.)

## 0.3.1 — 2026-10-09

Speed.

- RAR 2.9-4.x LZ decoding is about 2.3x faster: a 64 KB scratch buffer for
  rare filter code sat in the stack frame of the per-symbol function.
- PPMd decoding is about 1.4x faster (inlined model access, direct loads).
- RAR 5 and RAR 4 matches are copied 8 bytes at a time.

## 0.3.0 — 2026-10-09

Older archives.

- RAR 2.0 archives (unpack versions 20 and 26): every method, solid
  archives, multimedia audio compression, the RAR 2.0 cipher, old-style
  archive comments. Checked against archives made by RAR 2.50.
- RAR 1.5 archives (unpack version 15) and the RAR 1.5 cipher: implemented,
  but untested against real archives.
- Fix: a main header with an old-style comment was reported as damaged.

Known limitation: encrypted archives made by RAR 3.0–3.4 may not decrypt
(those versions derived keys slightly differently); RAR 3.5 and later work.

## 0.2.0 — 2026-10-09

Command line.

- Asks for a missing or wrong password on the terminal, without echo (`-p`
  asks up front, `-p-` never asks); up to three tries.
- Asks before overwriting: yes, no, all, never, rename, quit. `-o+`, `-o-`,
  `-or` (rename to `name (1).ext`) and `-y` decide up front. Without a
  terminal nothing waits for input and existing files are kept.
- Progress percentage for files over 4 MB on a terminal (`-idp` turns it off).
- Exit status by kind of failure: 3 damaged data, 6 open error, 7 bad command
  line, 10 no files matched, 11 password, and more (see `--help`).
- `-x<mask>` and `-x@<file>` excludes, `@<file>` name lists, `-op<path>`,
  `-ad`, `-kb`, `-idq`, `-inul`, `lb` bare listing, `--help`, `--version`.
- A summary line after testing or extracting; listings show local time.

Fixes:

- A single name after the archive selected nothing and became the
  destination; only an argument ending in `/` is a destination now.
- Skipping an existing file in a solid archive broke every later file; the
  skipped file is still decoded, into nothing.

## 0.1.0 — 2026-10-09

First release: a clean-room RAR reader.

- RAR 5.0: every compression method, solid archives, delta and x86 filters,
  multi-volume sets, AES-256 for data and headers, CRC32 and BLAKE2sp.
- RAR 2.9–4.x: LZ, PPMd, the standard VM filters (x86, Itanium, delta, RGB,
  audio), solid archives, old and new volume naming, AES-128 for data and
  headers.
- Symbolic and hard links, file references, file versions, SFX archives,
  comments; times and permissions restored; extraction confined to the
  destination directory.
