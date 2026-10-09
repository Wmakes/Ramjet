#!/usr/bin/env python3
"""Compare `ramjet lt` with `rar lt` for every sample archive.

Only fields both tools print the same way are compared: name, type, size,
packed size, CRC32 and link target. Times are skipped (rar prints local
time, ramjet prints UTC).

usage: tests/compare_list.py [ramjet-binary] [samples-dir]
"""
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent
SAMPLES = pathlib.Path(sys.argv[2]) if len(sys.argv) > 2 else ROOT / "samples"
RAMJET = sys.argv[1] if len(sys.argv) > 1 else str(ROOT.parent / "out/linux-x86_64/debug/bin/ramjet")
FIELDS = ("Name", "Type", "Size", "Packed size", "CRC32", "Target")


def entries(text):
    out, cur = [], {}
    for line in text.splitlines():
        key, sep, value = line.strip().partition(": ")
        if not sep:
            if cur:
                out.append(cur)
                cur = {}
            continue
        if key == "Name" and cur:
            out.append(cur)
            cur = {}
        if key in FIELDS:
            cur[key] = value.strip()
        if key == "Ratio" and value.strip() in ("-->", "<->"):
            cur["_split"] = True
    if cur:
        out.append(cur)
    # rar lists service headers only in some cases; compare files only
    return [e for e in out if "Name" in e and e.get("Type") != "Service header"]


def merge_parts(items):
    """join `rar lt -v` per-volume parts of one file into a single entry"""
    out = []
    for e in items:
        if out and out[-1].get("_split") and out[-1]["Name"] == e["Name"]:
            prev = out[-1]
            prev["Packed size"] = str(int(prev["Packed size"]) + int(e["Packed size"]))
            prev["_split"] = e.get("_split", False)
            if "CRC32" in e:
                prev["CRC32"] = e["CRC32"]
            prev["Size"] = e["Size"]
            continue
        out.append(e)
    for e in out:
        e.pop("_split", None)
    return out


def run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True, errors="replace").stdout


def main():
    failures = 0
    for arc in sorted(SAMPLES.glob("*.rar")):
        name = arc.name
        if ".part" in name and not (name.endswith("part1.rar") or name.endswith("part01.rar")):
            continue
        if name.startswith("broken_"):
            continue
        want = merge_parts(entries(run(["rar", "lt", "-v", "-pramjet", "-idc", str(arc)])))
        got = entries(run([RAMJET, "lt", "-pramjet", str(arc)]))
        if want != got:
            failures += 1
            print(f"MISMATCH {name}")
            for w, g in zip(want, got):
                if w != g:
                    print(f"  rar:    {w}\n  ramjet: {g}")
                    break
            if len(want) != len(got):
                print(f"  entry count rar={len(want)} ramjet={len(got)}")
        else:
            print(f"ok       {name} ({len(got)} entries)")
    sys.exit(1 if failures else 0)


main()
