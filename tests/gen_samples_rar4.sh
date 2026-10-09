#!/usr/bin/env bash
# Generate RAR 4.x sample archives with the RAR 4.20 binary fetched by
# tests/get_rar4.sh. Inputs are the files tests/gen_samples.sh made in
# tests/samples/input, so run that first.
#
# The binary is run as an ordinary program; it is never decompiled.
#
# Usage: tests/gen_samples_rar4.sh
set -euo pipefail

root="$(cd "$(dirname "$0")" && pwd)"
rar4="$root/rar4/rar/rar"
in="$root/samples/input"
out="$root/samples/rar4"
pw="ramjet"

[ -x "$rar4" ] || { echo "run tests/get_rar4.sh first" >&2; exit 1; }
[ -d "$in" ] || { echo "run tests/gen_samples.sh first" >&2; exit 1; }
rm -rf "$out"
mkdir -p "$out"

cd "$in"
rr() { local name="$1"; shift; "$rar4" a -idq "$@" "$out/$name.rar" "${files[@]}"; }
nobig=(-x"big_random.bin" -x"./big_random.bin")

files=(hello.txt)
rr single_store       -m0
rr single_default
files=(empty.txt)
rr empty_file

files=(.)
for m in 0 1 2 3 4 5; do rr "all_m$m" -m$m -r "${nobig[@]}"; done
rr all_solid          -s -r "${nobig[@]}"
rr all_md64k          -md64 -r "${nobig[@]}"
rr all_md4m           -md4096 -m5 -r "${nobig[@]}"
rr all_times          -tsm4 -tsc4 -tsa4 -r "${nobig[@]}"
printf 'Ramjet RAR4 sample comment\n' > "$out/comment.txt"
rr all_comment        -z"$out/comment.txt" -r "${nobig[@]}"
rm -f "$out/comment.txt"
rr all_recovery       -rr5% -r "${nobig[@]}"
rr all_locked         -k -r "${nobig[@]}"
rr all_owner          -ow -r "${nobig[@]}"
rr all_symlinks       -ol -r "${nobig[@]}"
rr all_encrypted      -p"$pw" -r "${nobig[@]}"
rr all_hdr_encrypted  -hp"$pw" -r "${nobig[@]}"
rr all_solid_enc      -s -p"$pw" -r "${nobig[@]}"
rr all_sfx            -sfx -r "${nobig[@]}"
[ -f "$out/all_sfx.sfx" ] && mv "$out/all_sfx.sfx" "$out/all_sfx.rar"
[ -f "$out/all_sfx" ] && mv "$out/all_sfx" "$out/all_sfx.rar"

# PPMd text compression and every RAR 2.9 filter, forced
files=(text.txt);  rr ppmd_text       -mct+ -m5
files=(.);         rr ppmd_solid      -mct+ -s -r "${nobig[@]}"
files=(text.txt);  rr ppmd_order      -mc32:64t+ -m5
files=(code.exe);  rr filter_e8       -mce+ -m5
files=(code.exe);  rr filter_itanium  -mci+ -m5
files=(tone.wav);  rr filter_audio    -mc4a+ -m5
files=(tone.wav);  rr filter_rgb      -mcc+ -m5
files=(text.txt);  rr filter_delta    -mc3d+ -m5
files=(random.bin); rr incompressible -m5

files=(big_random.bin)
rr volumes            -m0 -v100k
rr volumes_old_names  -m0 -v100k -vn
files=(text.txt random.bin)
rr volumes_solid      -s -m3 -v20k
files=(.)
rr volumes_enc        -s -hp"$pw" -m3 -v60k -r "${nobig[@]}"

files=(hello.txt)
rr versions -ver
printf 'Hello again, Ramjet!\n' > "$in/hello.txt"
"$rar4" u -idq -ver "$out/versions.rar" hello.txt
printf 'Hello, Ramjet!\n' > "$in/hello.txt"
touch -d '2001-02-03 04:05:06' "$in/hello.txt"

head -c 150000 "$in/random.bin" "$in/text.txt" | "$rar4" a -idq -m3 -si"piped.bin" "$out/stdin.rar"

cp "$out/all_m3.rar" "$out/broken_truncated.rar"
truncate -s -100 "$out/broken_truncated.rar"
cp "$out/all_m3.rar" "$out/broken_crc.rar"
printf '\xff' | dd of="$out/broken_crc.rar" bs=1 seek=300 conv=notrunc status=none

echo "password for encrypted samples: $pw" > "$out/PASSWORD.txt"
("$rar4" 2>&1 || true) | grep -m1 "^RAR" > "$out/GENERATED_BY.txt" || true
ls -1 "$out"/*.rar | wc -l | xargs echo "archives written:"
