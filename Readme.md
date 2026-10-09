# Ramjet

**Ramjet** is a fast, clean-room, RAR-compatible archiver written entirely in [Mach](https://machlang.org/). Like its namesake engine, it compresses with nothing but speed.

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

## Clean-Room Implementation

Ramjet is developed as a **clean-room implementation**.

This project does **not** use, include, copy, translate, or derive source code from:

* RAR
* WinRAR
* UnRAR
* proprietary RAR/WinRAR libraries
* decompiled or disassembled source code
* proprietary implementation details obtained from non-public sources

The implementation is developed independently from publicly observable behavior, publicly available format information, interoperability testing, and independently produced specifications.

The intention is to keep the Ramjet implementation independent from proprietary source code while providing interoperability with the RAR ecosystem where technically and legally possible.
## Non-Goals

Ramjet is not intended to:

* reproduce or redistribute proprietary RAR/WinRAR source code
* modify or redistribute WinRAR
* provide a copy of WinRAR under an open-source license
* claim ownership of the RAR format or technology developed by its original authors

Ramjet is an independent implementation.

## Status

Ramjet is being built reader first; the writer comes after the reader is complete.

Reading works for **RAR 5.0** and **RAR 2.9–4.x** archives (what RAR 3.x, 4.x, 5.x, 6.x and 7.x create):

* listing (`l`, `lt`), testing (`t`), extraction (`x`, `e`) and printing (`p`)
* every compression method, solid archives, dictionaries up to 4 GB (RAR 5) and 4 MB (RAR 4)
* RAR 5 filters (delta, x86 E8/E8E9; ARM implemented but untested) and RAR 4 filters (delta, x86, Itanium, RGB, audio)
* RAR 4 PPMd text compression
* multi-volume archives (`.partN.rar` and `.rar`/`.r00` naming), including split solid and encrypted sets
* encryption: AES-256 (RAR 5) and AES-128 (RAR 4), of file data and of headers
* CRC32 and BLAKE2sp checksums, including per-volume checksums of split files
* symbolic links, hard links, file references (`-oi`), file versions (`-ver`), SFX archives, archive comments
* file times and Unix permissions (Linux) or attributes (Windows) are restored; set-id bits never are
* builds for Linux, Windows and macOS (Windows tested under Wine)

Not yet: the RAR 1.5 and 2.x compression algorithms, the RAR 7 version 1 algorithm (dictionaries over 4 GB), the writer.

See [`docs/clean-room-notes.md`](docs/clean-room-notes.md) for where every piece of format knowledge came from.

## Building

Ramjet needs the [Mach](https://machlang.org/) compiler (6.x).

```
git submodule update --init
mach build .                 # debug: out/linux-x86_64/debug/bin/ramjet
mach build . -p release      # release: out/linux-x86_64/release/bin/ramjet
```

## Usage

```
ramjet l  archive.rar                list contents
ramjet lt archive.rar                list with technical details
ramjet t  archive.rar                test integrity
ramjet x  archive.rar [dest/]        extract with paths
ramjet e  archive.rar [dest/]        extract without paths
ramjet p  archive.rar [name]         print a file to stdout

switches: -p<password>   -o+ overwrite   -o- skip existing   -ver extract older versions
```

Extraction never writes outside the destination: names with `..` are refused, absolute names are made relative, symbolic links are created only after all files are written, and on Windows backslashes, drive letters, trailing dots and device names (`CON`, `NUL`, ...) are neutralized too.

## Testing

```
mach test .                          unit tests
tests/gen_samples.sh                 rebuild the RAR 5 samples (needs the rar tool)
tests/get_rar4.sh                    download RAR 4.20 (git-ignored) for the RAR 4 samples
tests/gen_samples_rar4.sh            rebuild the RAR 4 samples
tests/check_extract.sh               extract every sample and compare with its source files
tests/compare_list.py [bin] [dir]    compare `ramjet lt` with `rar lt` (dir: tests/samples/rar4 for RAR 4)
tests/fuzz.py 1000                   corrupted archives must never crash ramjet
```

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

See [`LICENSE`](LICENSE) for the complete license text.

This license applies to the original Ramjet source code.


## Disclaimer

Ramjet is an independent open-source project.

**Ramjet is not affiliated with, endorsed by, or sponsored by RARLAB, win.rar GmbH, Alexander Roshal, or the WinRAR project.**

RAR and WinRAR are trademarks and/or products associated with their respective owners.

This project does not distribute WinRAR or proprietary RAR source code.


