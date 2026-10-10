# Ramjet

**Ramjet** is a fast, independent RAR-compatible archiver written entirely in [Mach](https://machlang.org/). Like its namesake engine, it compresses with nothing but speed.

The goal of Ramjet is to provide a modern, portable and fully open implementation of RAR-compatible archiving without relying on proprietary RAR/WinRAR source code.
## About

Ramjet is an independent implementation focused on:

* RAR-compatible archive creation and extraction
* portability across platforms supported by Mach
* predictable and explicit systems-level code
* performance
* a clean and maintainable codebase
* fully open-source development

The project is written in **Mach**, a systems programming language designed around explicit control flow, explicit memory management and a small toolchain.

## Independent implementation

Ramjet is an independent implementation. It does not use, include, copy or
translate source code from RAR, WinRAR, UnRAR or 7-Zip's RAR code, and uses
no decompiled or disassembled code. Format knowledge comes from the public
RARLAB technotes, from running `rar` as an ordinary program and checking its
output, and from reading (without copying) the BSD-licensed libarchive and
LGPL-licensed XADMaster RAR readers. `docs/provenance-notes.md` lists the
source of each piece.
## Non-Goals

Ramjet is not intended to:

* reproduce or redistribute proprietary RAR/WinRAR source code
* modify or redistribute WinRAR
* provide a copy of WinRAR under an open-source license
* claim ownership of the RAR format or technology developed by its original authors

Ramjet is an independent implementation.

## Status

Ramjet is being built reader first; the writer comes after the reader is complete.
The aarch64 and macOS targets (darwin-x86_64 ,darwin-aarch64, linux-arm64) are built but not tested.

Reading works for **RAR 5.0**, **RAR 2.9–4.x** and **RAR 2.0** archives (what RAR 2.x through 7.x create):

* listing (`l`, `lt`), testing (`t`), extraction (`x`, `e`) and printing (`p`)
* every compression method, solid archives, dictionaries up to 4 GB (RAR 5) and 4 MB (RAR 4)
* RAR 5 filters (delta, x86 E8/E8E9; ARM implemented but untested) and RAR 4 filters (delta, x86, Itanium, RGB, audio)
* RAR 4 PPMd text compression, RAR 2.0 multimedia (audio) compression
* RAR 1.5 compression is implemented but untested (no RAR 1.5 archives to test with)
* multi-volume archives (`.partN.rar` and `.rar`/`.r00` naming), including split solid and encrypted sets
* encryption: AES-256 (RAR 5) and AES-128 (RAR 4), of file data and of headers, and the RAR 2.0 cipher
* CRC32 and BLAKE2sp checksums, including per-volume checksums of split files
* symbolic links, hard links, file references (`-oi`), file versions (`-ver`), SFX archives, archive comments
* file times and Unix permissions (Linux) or attributes (Windows) are restored; set-id bits never are
* builds for Linux, Windows and macOS (Windows tested under Wine)

Not yet: verified RAR 1.5 support, archives older than RAR 1.5, the RAR 7 version 1 algorithm (dictionaries over 4 GB), the writer.

See [`docs/provenance-notes.md`](docs/provenance-notes.md) for where every piece of format knowledge came from.

## Building

Ramjet needs the [Mach](https://machlang.org/) compiler (6.x).

```
git submodule update --init
mach build .                 # debug: out/linux-x86_64/debug/bin/ramjet
mach build . -p release      # release: out/linux-x86_64/release/bin/ramjet
```

## Usage

```
ramjet <command> [switches] <archive> [files...] [@listfile] [dest/]

commands:
  l   list           lt  list with technical details     lb  bare names
  t   test           x   extract with paths               e   extract without paths
  p   print a file to stdout

switches:
  -p<password>   set the password (-p asks, -p- never asks)
  -o+ / -o- / -or   overwrite / skip / rename existing files   (-y = yes to all)
  -x<mask>       exclude files (repeatable, -x@<file> for a list)
  -op<path>      extract into this directory      -ad  into a folder named after the archive
  -kb            keep files that failed their checksum
  -ver           also extract older file versions as name;N
  -idq / -inul   quiet / silent                    -idp  no progress display
```

Switches can go anywhere on the line (until `--`). A last argument ending in `/` is the destination; other arguments select files by name or `*`/`?` mask, and a directory name selects everything under it.

On a terminal Ramjet asks for missing passwords (input is not echoed) and asks before overwriting files; without one it never waits for input and keeps existing files. Large files show a progress percentage.

Exit status: 0 ok, 1 warning, 2 fatal error, 3 damaged data, 5 write error, 6 open error, 7 bad command line, 8 out of memory, 9 cannot create a file, 10 no files matched, 11 wrong or missing password, 255 stopped.

Extraction never writes outside the destination: names with `..` are refused, absolute names are made relative, symbolic links are created only after all files are written, and on Windows backslashes, drive letters, trailing dots and device names (`CON`, `NUL`, ...) are neutralized too.

## Testing

The sample archives are not part of the repository: they are made on your machine by the archivers themselves (RAR 7.x, RAR 4.20 and RAR 2.50, run as ordinary programs), so first run the generators below.

```
mach test .                          unit tests
tests/gen_samples.sh                 rebuild the RAR 5 samples (needs the rar tool)
tests/get_rar4.sh                    download RAR 4.20 (git-ignored) for the RAR 4 samples
tests/gen_samples_rar4.sh            rebuild the RAR 4 samples
tests/gen_samples_rar2.sh            rebuild the RAR 2.0 samples (needs rar250.exe and dosbox)
tests/gen_samples_rar3.sh            rebuild the RAR 3.x encryption samples (downloads pinned RAR 3.x packages)
tests/check_extract.sh               extract every sample and compare with its source files
tests/check_cli.sh                   command-line behavior and exit codes
tests/compare_list.py [bin] [dir]    compare `ramjet lt` with `rar lt` (dir: tests/samples/rar4 for RAR 4)
tests/fuzz.py 1000                   corrupted archives must never crash ramjet
```

## Releases

The version lives in `mach.toml` (`ramjet --version` reads it at build time) and follows semantic versioning. A release is:

1. bump `version` in `mach.toml` and add a section to [`CHANGELOG.md`](CHANGELOG.md)
2. commit, then tag it: `git tag -a vX.Y.Z -m "Ramjet X.Y.Z"`
3. `git push origin main vX.Y.Z`
4. build `mach build . -t <target> -p release` for each target and attach the binaries to a GitHub release for the tag

Another Mach project can depend on a release with `ref = "tag/vX.Y.Z"`.

## Contributing

Contributions are welcome.

Before contributing code, please make sure that your contribution does not contain:

* proprietary RAR/WinRAR/UnRAR source code
* code copied from proprietary implementations
* decompiled or disassembled proprietary code
* confidential or non-public implementation information

When adding a new feature, prefer:

* independently written code
* documented behavioral observations
* reproducible tests
* clear technical reasoning
* references to publicly available specifications where applicable


## Licensing

Ramjet is licensed under the **GNU General Public License v3.0 (GPL-3.0)**.

See [`LICENSE`](LICENSE) for the complete license text. Binaries include the Mach standard library (MIT); see [`THIRD_PARTY_NOTICES.txt`](THIRD_PARTY_NOTICES.txt).

This license applies to the original Ramjet source code.


## Disclaimer

Ramjet is an independent open-source project.

**Ramjet is not affiliated with, endorsed by, or sponsored by RARLAB, win.rar GmbH, Alexander Roshal, or the WinRAR project.**

RAR and WinRAR are trademarks and/or products associated with their respective owners.

This project does not distribute WinRAR or proprietary RAR source code.


