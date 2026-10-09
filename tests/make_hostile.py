#!/usr/bin/env python3
"""Build hostile RAR5 archives (stored data only) for the extraction safety tests.

The rar tool refuses to create these, so they are assembled here from the
container layout in docs/rar5-technote.html: signature, main header, file
headers with optional redirection records, end header.

usage: tests/make_hostile.py <output-dir>
"""
import pathlib
import sys
import zlib

SIG = b"Rar!\x1a\x07\x01\x00"


def vint(n):
    out = bytearray()
    while True:
        b = n & 0x7F
        n >>= 7
        if n:
            out.append(b | 0x80)
        else:
            out.append(b)
            return bytes(out)


def block(htype, hflags, body, extra=b"", data=b""):
    fields = vint(htype)
    if extra:
        hflags |= 0x0001
    if data:
        hflags |= 0x0002
    fields += vint(hflags)
    if extra:
        fields += vint(len(extra))
    if data:
        fields += vint(len(data))
    head = fields + body + extra
    sized = vint(len(head)) + head
    return zlib.crc32(sized).to_bytes(4, "little") + sized + data


def file_entry(name, data=b"", attr=0o100644, redir=None, directory=False):
    flags = 0x0004 | (0x0001 if directory else 0)
    body = vint(flags) + vint(len(data)) + vint(attr)
    body += zlib.crc32(data).to_bytes(4, "little")
    body += vint(0) + vint(1)  # stored, Unix host
    raw = name.encode()
    body += vint(len(raw)) + raw
    extra = b""
    if redir:
        kind, target = redir
        t = target.encode()
        rec = vint(5) + vint(kind) + vint(0) + vint(len(t)) + t
        extra = vint(len(rec)) + rec
    return block(2, 0, body, extra, data)


def archive(entries):
    out = SIG + block(1, 0, vint(0))
    for e in entries:
        out += e
    return out + block(5, 0, vint(0))


def main():
    outdir = pathlib.Path(sys.argv[1])
    outdir.mkdir(parents=True, exist_ok=True)
    cases = {
        "dotdot.rar": [file_entry("../escaped.txt", b"escaped\n")],
        "dotdot_deep.rar": [file_entry("a/../../escaped.txt", b"escaped\n")],
        "absolute.rar": [file_entry("/tmp/ramjet_absolute.txt", b"absolute\n")],
        # a symlink to outside, then a file written "through" it
        "symlink_escape.rar": [
            file_entry("lnk", attr=0o120777, redir=(1, "/tmp")),
            file_entry("lnk/ramjet_through_link.txt", b"through\n"),
        ],
        "hardlink_escape.rar": [file_entry("hl", attr=0o100644, redir=(4, "../../../etc/hostname"))],
        "setuid.rar": [file_entry("suid.sh", b"#!/bin/sh\n", attr=0o104755)],
        # separators and names that only mean something on Windows
        "backslash.rar": [file_entry("..\\..\\escaped_backslash.txt", b"escaped\n")],
        "trailing_dot.rar": [file_entry(".. /.. /escaped_dots.txt", b"escaped\n")],
        "drive.rar": [file_entry("C:/escaped_drive.txt", b"escaped\n"), file_entry("a:b.txt", b"stream\n")],
        "device.rar": [file_entry("NUL.txt", b"device\n"), file_entry("dir/con", b"device\n")],
    }
    for name, entries in cases.items():
        (outdir / name).write_bytes(archive(entries))


main()
