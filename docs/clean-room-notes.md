# Clean-room notes

Where every piece of format knowledge in Ramjet came from. The rule: nothing
is taken from RAR, WinRAR or UnRAR source or binaries (no decompiling, no
disassembly), and nothing is copied or translated from other implementations.

## Sources allowed

| Source | License | How it is used |
|---|---|---|
| [RARLAB RAR 5.0 technote](https://www.rarlab.com/technote.htm), copy in `docs/rar5-technote.html` | no license stated; read for interoperability | the RAR5 container: signature, every header and extra record |
| `technote.txt` from the RAR 4.20 package (`tests/get_rar4.sh` downloads it; **not** in the repo, the RAR license forbids distributing parts of the package) | RAR EULA | the RAR 1.5-4.x container: block layout, main and file headers |
| `rar` 7.23 and `rar` 4.20 (trial), run as ordinary programs | RAR EULA | create the sample archives in `tests/samples` and `tests/samples/rar4`; `rar lt` output is the expected listing |
| libarchive `archive_read_support_format_rar5.c` and `archive_read_support_format_rar.c` | BSD-2-Clause, (c) Grzegorz Antoniak, Tim Kientzle, Andres Mejia | **read only**, to understand the compressed bitstreams and the standard VM filters; no code copied or translated |
| The Unarchiver's XADMaster `XADRAR15Handle.m`, `XADRAR20Handle.m`, `RARAudioDecoder.c`, `XADRAR15CryptHandle.m`, `XADRAR20CryptHandle.m`, `XADRARParser.m` | LGPL-2.1, (c) MacPaw; no mention of UnRAR, RARLAB or Roshal in any of them | **read only**, for the RAR 1.5 and 2.0 algorithms, their ciphers and old-style comments; no code copied or translated |
| `rar` 2.50 for DOS (`rar250.exe` from rarlab.com, git-ignored in `tests/rar2/`), run in DOSBox | RAR 2.50 license | creates the RAR 2.0 sample archives in `tests/samples/rar2` |
| PPMd var.H (Dmitry Shkarin, 2001) and Igor Pavlov's Ppmd7 | public domain | the PPMd model used by RAR 2.9 text compression |
| FIPS-180-4, FIPS-197, RFC 2104, RFC 4231, RFC 7693, RFC 8018, RFC 8536 | public standards | SHA-1, AES-128/256, HMAC-SHA256, BLAKE2s, PBKDF2, TZif |
| BLAKE2 paper / blake2.net | public; reference code CC0 | BLAKE2sp tree parameters |
| Intel IA-64 instruction format | public ISA documentation | the Itanium branch filter |

Never used: UnRAR source (its license forbids re-creating the compressor
from it), 7-Zip's RAR code (derived from UnRAR).

## RAR 5: confirmed black-box against `rar` 7.23 output

These are not in the technote. Each was guessed, then confirmed only by
checking Ramjet's results against archives `rar` made (`tests/samples`):

- **Key derivation** (`src/rar5/crypt.mach`): AES key = PBKDF2-HMAC-SHA256
  over 2^kdf_count iterations; the hash key and the password check value
  come from the same PBKDF2 block run 16 and 32 iterations further, and the
  check is XOR-folded to 8 bytes. Confirmed: correct passwords pass the check
  and decrypt (`all_encrypted`, `all_hdr_encrypted`, `volumes_solid_enc`),
  wrong ones are refused.
- **Tweaked checksums** (encryption flag 0x2): CRC32 becomes
  HMAC-SHA256(hash key, CRC as 4 LE bytes) XOR-folded to 4 bytes; BLAKE2sp
  becomes HMAC-SHA256(hash key, digest). Confirmed on `all_encrypted` and
  `all_blake2_enc`.
- **Per-volume hashes**: a part that continues in the next volume carries a
  CRC32 or BLAKE2sp of its *packed* bytes, not tweaked even when encrypted
  (`volumes`, `volumes_solid_enc`).
- **Header encryption across volumes**: every volume begins with its own
  plaintext archive encryption header.
- **File versions** (`-ver`): older versions are listed as `name;N` and are
  not extracted by default (`versions`).
- **Quick open records** appear in every volume after the file data, so a
  split file's continuation is matched by name, not by position.

## RAR 4: confirmed black-box against `rar` 4.20 output

- **Extended time record**: a 16-bit field with four 4-bit groups (mtime,
  ctime, atime, archive time from the top): bit 3 present, bit 2 one second
  more, bits 0-1 the count of 100 ns fraction bytes; times other than mtime
  start with their own DOS time (`all_times`).
- **DOS times are local wall-clock time**; Ramjet converts them through the
  system zone (`/etc/localtime`, TZif with its POSIX rule), confirmed for
  both winter and summer time in `all_times`.
- **Unicode names**: the byte name, a NUL, then a high byte and 2-bit
  opcodes (byte with high 0, byte with the stored high byte, a full 16-bit
  unit, or a run copied from the byte name with a correction byte)
  (`all_m3`, the Polish/Japanese file name).
- **Symbolic links** (`-ol`): an entry with a Unix link mode whose data is
  the target (`all_symlinks`).
- **Comments**: a `CMT` service block whose data is compressed like a file
  (`all_comment`).
- **Solid PPMd**: every solid file starts with a table block; the PPMd
  end-of-file escape (2) means the next file reads tables again, and decoding
  it is required to keep the model in step; the escape byte persists into
  later PPMd blocks that do not set it again (`ppmd_solid`).
- **Itanium filter fingerprint** `0x78_3769893F` (program length 120,
  CRC32 0x3769893F), read from `filter_itanium`; the filter itself is the
  IA-64 branch conversion, confirmed by the file's CRC.
- **Key derivation** (`src/rar4/crypt.mach`): SHA-1 over 2^18 rounds of
  UTF-16LE password + salt + 3-byte round counter; IV bytes from byte 19 of
  the running digest every 2^14 rounds; key = the final digest's first 16
  bytes, byte-reversed per 32-bit word (`all_encrypted`, `all_solid_enc`).
- **Header encryption**: every block after the main header is 8 bytes of
  salt followed by the header in AES-128-CBC, padded to 16 bytes
  (`all_hdr_encrypted`, `volumes_enc`).

## RAR 2.0: confirmed black-box against `rar` 2.50 output

- **Decoder** (`src/rar4/unpack20.mach`): every method `-m0` to `-m5`,
  solid archives, multimedia audio blocks (`-mm`, `-mmf`, solid), `.rar` /
  `.r00` volumes (`tests/samples/rar2`).
- **Cipher** (`src/rar4/crypt_old.mach`): the RAR 2.0 block cipher decrypts
  compressed, solid and stored files correctly; a wrong password fails the
  CRC (`enc`, `encsolid`, `encstore`).
- **Old-style comments**: a 0x75 block inside the main header, compressed
  like a file; the main header's CRC then covers only its own fields, not
  the comment (`comment`).

## Implemented from the format description but not confirmed

- **RAR 1.5 decoder and cipher** (`src/rar4/unpack15.mach`): no RAR 1.5x
  binary is available any more to make samples. The fixed code tables are
  checked to be complete prefix codes, and fuzzing (RAR 2.0 data relabeled
  as version 15) shows it rejects bad data without crashing, but it has
  never decoded a real RAR 1.5 file.
- **RAR 2.6 encryption** (unpack version 26): treated as the RAR 2.0 cipher
  when no salt is present; no sample exists.
- **RAR 1.3 cipher and the pre-1.5 `RE~^` container**: not supported.

- **RAR 5 ARM filter** (type 3): `rar` 7.23 never emitted it, even for real
  ARMv7 binaries, so no sample exercises it.
- **RAR 5 compression algorithm version 1** (RAR 7 dictionaries over 4 GB):
  not decoded; such files report "unsupported feature". `-md1g` still
  produces version 0 data.
- **RAR 4 passwords of 28+ characters**: hashed as described; some old RAR
  versions are said to differ there, untested.
- **Windows-only metadata** (NTFS ACL and stream service headers): parsed
  and skipped.
