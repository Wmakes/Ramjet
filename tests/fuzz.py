#!/usr/bin/env python3
"""Mutation fuzzing: corrupt sample archives and make sure ramjet never
crashes or hangs on them (a clean error exit is fine).

usage: tests/fuzz.py [iterations] [ramjet-binary]
"""
import os
import pathlib
import random
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent
ITER = int(sys.argv[1]) if len(sys.argv) > 1 else 300
RAMJET = sys.argv[2] if len(sys.argv) > 2 else str(ROOT.parent / "out/linux-x86_64/release/bin/ramjet")
SEEDS = [p for p in sorted((ROOT / "samples").glob("*.rar")) + sorted((ROOT / "samples" / "rar4").glob("*.rar")) + sorted((ROOT / "samples" / "rar2").glob("*.rar"))
         if ".part" not in p.name and os.path.getsize(p) < 400000]


def mutate(data, rng):
    data = bytearray(data)
    for _ in range(rng.randint(1, 8)):
        kind = rng.random()
        pos = rng.randrange(len(data))
        if kind < 0.6:
            data[pos] = rng.randrange(256)
        elif kind < 0.8:
            data[pos] ^= 1 << rng.randrange(8)
        elif kind < 0.9:
            del data[pos:pos + rng.randint(1, 64)]
        else:
            data[pos:pos] = rng.randbytes(rng.randint(1, 16))
    return bytes(data)


def main():
    rng = random.Random(int(os.environ.get("FUZZ_SEED", "1")))
    crashes = 0
    with tempfile.TemporaryDirectory() as tmp:
        target = pathlib.Path(tmp) / "fuzz.rar"
        for i in range(ITER):
            seed = rng.choice(SEEDS)
            target.write_bytes(mutate(seed.read_bytes(), rng))
            try:
                r = subprocess.run([RAMJET, "t", "-pramjet", str(target)], capture_output=True, timeout=20)
                bad = r.returncode < 0 or r.returncode >= 128
                why = f"signal/exit {r.returncode}"
            except subprocess.TimeoutExpired:
                bad, why = True, "timeout"
            if bad:
                crashes += 1
                keep = ROOT / f"fuzz_crash_{i}.rar"
                keep.write_bytes(target.read_bytes())
                print(f"CRASH {why} from {seed.name}: saved {keep.name}")
    print(f"{ITER} runs, {crashes} crashes")
    sys.exit(1 if crashes else 0)


main()
