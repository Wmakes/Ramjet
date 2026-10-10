#!/usr/bin/env bash
# Generate RAR sample archives for the Ramjet reader.
#
# Samples come from running the installed `rar` binary as a normal user tool.
# The binary is never decompiled or disassembled. Every archive is built from
# the deterministic input tree in tests/samples/input, so a reader test can
# compare what it extracts against those files.
#
# Usage: tests/gen_samples.sh
set -euo pipefail

root="$(cd "$(dirname "$0")" && pwd)"
out="$root/samples"
in="$out/input"
pw="ramjet"

rm -rf "$out"
mkdir -p "$in"

# ---------------------------------------------------------------- inputs
python3 -I - "$in" <<'EOF'
import math, os, random, struct, sys
d = sys.argv[1]
rng = random.Random(1337)
def w(name, data):
    p = os.path.join(d, name)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    open(p, "wb").write(data)

w("empty.txt", b"")
w("hello.txt", b"Hello, Ramjet!\n")
words = b"ramjet compresses with nothing but speed and a clean room ".split()
w("text.txt", b" ".join(rng.choice(words) for _ in range(40000)) + b"\n")
w("zeros.bin", bytes(256 * 1024))
w("random.bin", rng.randbytes(64 * 1024))
w("big_random.bin", rng.randbytes(300 * 1024))          # for volumes
# x86-like code: many E8/E9 call/jmp opcodes (triggers the x86 filter)
code = bytearray()
while len(code) < 128 * 1024:
    code += bytes([0xE8]) + struct.pack("<i", rng.randint(-4096, 4096))
    code += rng.randbytes(rng.randint(1, 6))
w("code.exe", b"MZ" + bytes(code))
# 16-bit stereo PCM sine (triggers the delta filter)
pcm = b"".join(struct.pack("<hh", int(12000 * math.sin(i / 20)),
                           int(9000 * math.sin(i / 33))) for i in range(65536))
w("tone.wav", b"RIFF" + struct.pack("<I", 36 + len(pcm)) + b"WAVEfmt " +
  struct.pack("<IHHIIHH", 16, 1, 2, 44100, 44100 * 4, 4, 16) +
  b"data" + struct.pack("<I", len(pcm)) + pcm)
w("dir/sub/deep.txt", b"deep file\n")
w("dir/other.txt", b"other file\n")
w("zażółć_łódź_日本.txt", "unicode name\n".encode())
w("dup_a.bin", rng.randbytes(32 * 1024))
w("dup_b.bin", open(os.path.join(d, "dup_a.bin"), "rb").read())
os.makedirs(os.path.join(d, "empty_dir"), exist_ok=True)
EOF
ln -s hello.txt "$in/link_to_hello"
ln "$in/hello.txt" "$in/hardlink_hello.txt"
printf 'Ramjet sample archive comment\n' > "$out/comment.txt"
touch -d '2001-02-03 04:05:06' "$in"/* "$in"/dir/* "$in"/dir/sub/*

# ---------------------------------------------------------------- archives
cd "$in"
rr() { local name="$1"; shift; rar a -idq "$@" "$out/$name.rar" "${files[@]}"; }
nobig=(-x"big_random.bin" -x"./big_random.bin")

files=(hello.txt)
rr single_store       -m0
rr single_default
files=(empty.txt)
rr empty_file

files=(.)
for m in 0 1 2 3 4 5; do rr "all_m$m" -m$m -r "${nobig[@]}"; done
rr all_solid          -s -r "${nobig[@]}"
rr all_solid_m5       -s -m5 -r "${nobig[@]}"
rr all_md128k         -md128k -r "${nobig[@]}"
rr all_md1g           -md1g -m5 -r "${nobig[@]}"
rr all_times          -tsm -tsc -tsa -r "${nobig[@]}"
rr all_blake2         -htb -r "${nobig[@]}"
rr all_comment        -z"$out/comment.txt" -r "${nobig[@]}"
rr all_recovery       -rr5% -r "${nobig[@]}"
rr all_locked         -k -r "${nobig[@]}"
rr all_qo             -qo+ -r "${nobig[@]}"
rr all_noqo           -qo- -r "${nobig[@]}"
rr all_symlinks       -ol -r "${nobig[@]}"
rr all_dedup          -oi -r "${nobig[@]}"
rr all_encrypted      -p"$pw" -r "${nobig[@]}"
rr all_hdr_encrypted  -hp"$pw" -r "${nobig[@]}"
rr all_hardlinks      -oh -r "${nobig[@]}"
rr all_owner          -ow -r "${nobig[@]}"
rr all_blake2_enc     -htb -p"$pw" -r "${nobig[@]}"
rr all_sfx            -sfx -r "${nobig[@]}"
mv "$out/all_sfx.sfx" "$out/all_sfx.rar" 2>/dev/null || mv "$out/all_sfx" "$out/all_sfx.rar"

files=(code.exe);  rr filter_x86     -m5
files=(code.exe);  rr filter_e8      -m5 -mce+
files=(text.txt);  rr filter_delta3  -m3 -mc3d+
files=(tone.wav);  rr filter_delta   -m5
files=(text.txt);  rr text_m5        -m5
files=(zeros.bin); rr zeros_m5       -m5

files=(dir empty_dir); rr dirs_only -r

files=(big_random.bin)
rr volumes            -m0 -v100k
files=(text.txt random.bin)
rr volumes_solid      -s -m3 -v20k
# data-only encryption: only the last part's checksum is tweaked
files=(big_random.bin)
rr volumes_enc        -p"$pw" -m0 -v100k
files=(text.txt random.bin)
rr volumes_enc_blake2 -p"$pw" -htb -s -m3 -v20k

files=(.)
rr volumes_solid_enc  -s -hp"$pw" -htb -m3 -v60k -r "${nobig[@]}"

# file versions: the same name archived twice with -ver
files=(hello.txt)
rr versions           -ver
printf 'Hello again, Ramjet!\n' > "$out/hello_v2.txt"
(cd "$out" && cp hello_v2.txt "$in/hello.txt" && cd "$in" && rar u -idq -ver "$out/versions.rar" hello.txt)
printf 'Hello, Ramjet!\n' > "$in/hello.txt"
touch -d '2001-02-03 04:05:06' "$in/hello.txt"
rm -f "$out/hello_v2.txt"

# unknown sizes: stdin split across volumes
head -c 150000 "$in/random.bin" "$in/text.txt" | rar a -idq -m3 -v40k -si"piped.bin" "$out/stdin_volumes.rar"

# Archive passed through a pipe (stdin input, no file metadata)
printf 'from stdin\n' | rar a -idq -si"stdin.txt" "$out/stdin.rar"

# Damaged copies for error-path tests
cp "$out/all_m3.rar" "$out/broken_truncated.rar"
truncate -s -100 "$out/broken_truncated.rar"
cp "$out/all_m3.rar" "$out/broken_crc.rar"
printf '\xff' | dd of="$out/broken_crc.rar" bs=1 seek=200 conv=notrunc status=none

echo "password for encrypted samples: $pw" > "$out/PASSWORD.txt"
rar 2>&1 | grep -m1 "^RAR" > "$out/GENERATED_BY.txt" || true
ls -1 "$out"/*.rar | wc -l | xargs echo "archives written:"
