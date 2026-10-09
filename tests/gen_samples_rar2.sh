#!/usr/bin/env bash
# Generate RAR 2.0 sample archives with RAR 2.50 for DOS, run headless in
# DOSBox. RAR 2.50 is not downloaded automatically: put rar250.exe from
# https://www.rarlab.com/rar/rar250.exe into tests/rar2/ (git-ignored).
# It is run as an ordinary program to make samples; it is never decompiled.
#
# DOS needs 8.3 names, so the inputs are copied under short names into
# tests/rar2/dos/in; tests/check_extract.sh compares against that tree.
#
# Usage: tests/gen_samples_rar2.sh       (needs dosbox and unrar)
set -euo pipefail

root="$(cd "$(dirname "$0")" && pwd)"
r2="$root/rar2"
in="$root/samples/input"
dos="$r2/dos"
out="$root/samples/rar2"

[ -f "$r2/rar250.exe" ] || { echo "put rar250.exe into $r2 first" >&2; exit 1; }
[ -d "$in" ] || { echo "run tests/gen_samples.sh first" >&2; exit 1; }
command -v dosbox >/dev/null || { echo "dosbox is needed" >&2; exit 1; }

# unpack RAR.EXE from the self-extracting package
mkdir -p "$r2/pkg"
[ -f "$r2/pkg/RAR.EXE" ] || unrar x -idq -o+ "$r2/rar250.exe" "$r2/pkg/"

rm -rf "$dos" "$out"
mkdir -p "$dos/in/DIR/SUB" "$dos/OUT" "$out"
cp "$in/hello.txt" "$dos/in/HELLO.TXT"
cp "$in/text.txt" "$dos/in/TEXT.TXT"
cp "$in/code.exe" "$dos/in/CODE.EXE"
cp "$in/zeros.bin" "$dos/in/ZEROS.BIN"
cp "$in/random.bin" "$dos/in/RANDOM.BIN"
cp "$in/tone.wav" "$dos/in/TONE.WAV"
cp "$in/empty.txt" "$dos/in/EMPTY.TXT"
cp "$in/big_random.bin" "$dos/in/BIG.BIN"
cp "$in/dir/sub/deep.txt" "$dos/in/DIR/SUB/DEEP.TXT"
cp "$in/dir/other.txt" "$dos/in/DIR/OTHER.TXT"
printf 'Ramjet RAR 2.0 sample comment\r\n' > "$dos/in/CMT.TXT"
cp "$r2/pkg/RAR.EXE" "$dos/"

# one batch file for every archive; -x keeps the comment and the big file
# out of the general archives, -y answers RAR's questions (next volume)
cat > "$dos/MAKE.BAT" <<'EOF'
cd \in
..\RAR.EXE a -y -r -m0 -xCMT.TXT -xBIG.BIN ..\OUT\ALLM0.RAR *.*
..\RAR.EXE a -y -r -m1 -xCMT.TXT -xBIG.BIN ..\OUT\ALLM1.RAR *.*
..\RAR.EXE a -y -r -m2 -xCMT.TXT -xBIG.BIN ..\OUT\ALLM2.RAR *.*
..\RAR.EXE a -y -r -m3 -xCMT.TXT -xBIG.BIN ..\OUT\ALLM3.RAR *.*
..\RAR.EXE a -y -r -m4 -xCMT.TXT -xBIG.BIN ..\OUT\ALLM4.RAR *.*
..\RAR.EXE a -y -r -m5 -xCMT.TXT -xBIG.BIN ..\OUT\ALLM5.RAR *.*
..\RAR.EXE a -y -r -s -m3 -xCMT.TXT -xBIG.BIN ..\OUT\SOLID.RAR *.*
..\RAR.EXE a -y -r -s -m5 -xCMT.TXT -xBIG.BIN ..\OUT\SOLIDM5.RAR *.*
..\RAR.EXE a -y -mm -m5 ..\OUT\MM.RAR TONE.WAV
..\RAR.EXE a -y -mmf -m5 ..\OUT\MMF.RAR TONE.WAV TEXT.TXT
..\RAR.EXE a -y -mmf -s -m5 ..\OUT\MMSOLID.RAR TONE.WAV TEXT.TXT CODE.EXE
..\RAR.EXE a -y -r -pramjet -m3 -xCMT.TXT -xBIG.BIN ..\OUT\ENC.RAR *.*
..\RAR.EXE a -y -r -s -pramjet -m3 -xCMT.TXT -xBIG.BIN ..\OUT\ENCSOLID.RAR *.*
..\RAR.EXE a -y -pramjet -m0 ..\OUT\ENCSTORE.RAR HELLO.TXT TEXT.TXT
..\RAR.EXE a -y -zCMT.TXT -m3 ..\OUT\COMMENT.RAR HELLO.TXT TEXT.TXT
..\RAR.EXE a -y -m3 ..\OUT\SINGLE.RAR HELLO.TXT
..\RAR.EXE a -y -m0 -v100 ..\OUT\VOL.RAR BIG.BIN
..\RAR.EXE a -y -m3 -s -v20 ..\OUT\VOLSOLID.RAR TEXT.TXT RANDOM.BIN
exit
EOF
# run the emulated CPU as fast as the host allows; the batch file ends with
# "exit" so DOSBox closes when it is done
printf '[cpu]\ncore=dynamic\ncycles=max\n' > "$dos/dosbox.conf"
cd "$dos"
SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy timeout 3600 dosbox -conf dosbox.conf -c "mount c ." -c "c:" -c "MAKE.BAT" -c "exit" >/dev/null 2>&1 || true

for f in "$dos"/OUT/*; do
    base="$(basename "$f")"
    lower="$(echo "$base" | tr 'A-Z' 'a-z')"
    case "$lower" in log.txt) continue ;; esac
    cp "$f" "$out/$lower"
done
echo "password for encrypted samples: ramjet" > "$out/PASSWORD.txt"
echo "RAR 2.50 (DOS), run in DOSBox" > "$out/GENERATED_BY.txt"
ls -1 "$out" | grep -c -i -E '\.(rar|r[0-9][0-9])$' | xargs echo "archives written:"
