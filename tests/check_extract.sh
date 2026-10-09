#!/usr/bin/env bash
# Extract every sample archive with ramjet and compare the result with the
# input tree the samples were made from (tests/samples/input).
#
# usage: tests/check_extract.sh [ramjet-binary]
set -uo pipefail

root="$(cd "$(dirname "$0")" && pwd)"
ramjet="${1:-$root/../out/linux-x86_64/debug/bin/ramjet}"
ramjet="$(cd "$(dirname "$ramjet")" && pwd)/$(basename "$ramjet")"
samples="$root/samples"
input="$samples/input"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

pass=0
fail=0

# compare one extracted path with its source; regular files by content,
# symlinks by target
same() {
    local want="$input/$1" got="$2/$1"
    if [ -L "$want" ] && [ "$3" = "links" ]; then
        [ -L "$got" ] && [ "$(readlink "$want")" = "$(readlink "$got")" ]
    elif [ -d "$want" ]; then
        [ -d "$got" ]
    else
        cmp -s "$want" "$got"
    fi
}

check() {
    local arc="$1" links="$2"; shift 2
    local out="$work/${arc%.rar}"
    mkdir -p "$out"
    if ! "$ramjet" x -o+ -pramjet "$samples/$arc" "$out/" >"$out.log" 2>&1; then
        echo "FAIL $arc (ramjet exit status)"; sed 's/^/     /' "$out.log" | grep -v ' OK$' | head -5
        fail=$((fail + 1)); return
    fi
    local f bad=0
    for f in "$@"; do
        if ! same "$f" "$out" "$links"; then
            echo "FAIL $arc: $f differs"; bad=1
        fi
    done
    if [ $bad = 0 ]; then pass=$((pass + 1)); echo "ok   $arc"; else fail=$((fail + 1)); fi
}

all=(code.exe dup_a.bin dup_b.bin empty.txt hello.txt hardlink_hello.txt random.bin text.txt tone.wav
     zeros.bin dir/sub/deep.txt dir/other.txt "zażółć_łódź_日本.txt" empty_dir link_to_hello)

for a in all_m0 all_m1 all_m2 all_m3 all_m4 all_m5 all_solid all_solid_m5 all_md128k all_md1g \
         all_times all_blake2 all_comment all_recovery all_locked all_qo all_noqo all_dedup \
         all_encrypted all_hdr_encrypted; do
    check "$a.rar" files "${all[@]}"
done
for a in all_hardlinks all_owner all_blake2_enc all_sfx; do
    check "$a.rar" files "${all[@]}"
done
check all_symlinks.rar links "${all[@]}"
check volumes_solid_enc.part01.rar files "${all[@]}"
check filter_e8.rar files code.exe
check filter_delta3.rar files text.txt
# versions.rar holds hello.txt twice; plain extraction gives the newest
out="$work/versions"; mkdir -p "$out"
if "$ramjet" x -o+ "$samples/versions.rar" "$out/" >/dev/null 2>&1 &&
   [ "$(cat "$out/hello.txt")" = "Hello again, Ramjet!" ] && [ ! -e "$out/hello.txt;1" ]; then
    echo "ok   versions.rar"; pass=$((pass + 1))
else
    echo "FAIL versions.rar"; fail=$((fail + 1))
fi
check single_store.rar files hello.txt
check single_default.rar files hello.txt
check empty_file.rar files empty.txt
check filter_x86.rar files code.exe
check filter_delta.rar files tone.wav
check text_m5.rar files text.txt
check zeros_m5.rar files zeros.bin
check dirs_only.rar files dir/sub/deep.txt dir/other.txt empty_dir
check volumes.part1.rar files big_random.bin
check volumes_solid.part01.rar files text.txt random.bin

# unknown sizes in volumes: compare with the bytes that were piped in
out="$work/stdin_volumes"; mkdir -p "$out"
if "$ramjet" x -o+ "$samples/stdin_volumes.part1.rar" "$out/" >/dev/null 2>&1 &&
   cmp -s <(head -c 150000 "$input/random.bin" "$input/text.txt") "$out/piped.bin"; then
    echo "ok   stdin_volumes.part1.rar"; pass=$((pass + 1))
else
    echo "FAIL stdin_volumes.part1.rar"; fail=$((fail + 1))
fi

# the damaged samples must be reported, not extracted silently
for a in broken_crc.rar broken_truncated.rar; do
    if "$ramjet" t "$samples/$a" >/dev/null 2>&1; then
        echo "FAIL $a: damage not detected"; fail=$((fail + 1))
    else
        echo "ok   $a (damage detected)"; pass=$((pass + 1))
    fi
done
if "$ramjet" t -pwrong "$samples/all_encrypted.rar" >/dev/null 2>&1; then
    echo "FAIL wrong password accepted"; fail=$((fail + 1))
else
    echo "ok   wrong password refused"; pass=$((pass + 1))
fi

# RAR 1.5-4.x samples (tests/gen_samples_rar4.sh)
if [ -d "$samples/rar4" ]; then
    r4="$samples/rar4"
    check4() { local saved="$samples"; samples="$r4"; check "$@"; samples="$saved"; }
    for a in all_m0 all_m1 all_m2 all_m3 all_m4 all_m5 all_solid all_md64k all_md4m all_times all_comment \
             all_recovery all_locked all_owner all_encrypted all_hdr_encrypted all_solid_enc all_sfx ppmd_solid; do
        check4 "$a.rar" files "${all[@]}"
    done
    check4 volumes_enc.part01.rar files "${all[@]}"
    check4 all_symlinks.rar links "${all[@]}"
    check4 single_store.rar files hello.txt
    check4 single_default.rar files hello.txt
    check4 empty_file.rar files empty.txt
    check4 ppmd_text.rar files text.txt
    check4 ppmd_order.rar files text.txt
    check4 filter_e8.rar files code.exe
    check4 filter_itanium.rar files code.exe
    check4 filter_audio.rar files tone.wav
    check4 filter_rgb.rar files tone.wav
    check4 filter_delta.rar files text.txt
    check4 incompressible.rar files random.bin
    check4 volumes.part1.rar files big_random.bin
    check4 volumes_old_names.rar files big_random.bin
    check4 volumes_solid.part01.rar files text.txt random.bin
    for a in broken_crc.rar broken_truncated.rar; do
        if "$ramjet" t "$r4/$a" >/dev/null 2>&1; then
            echo "FAIL rar4/$a: damage not detected"; fail=$((fail + 1))
        else
            echo "ok   rar4/$a (damage detected)"; pass=$((pass + 1))
        fi
    done
fi

# RAR 2.0 samples (tests/gen_samples_rar2.sh), compared with the 8.3-named
# copies of the inputs that RAR 2.50 archived
if [ -d "$samples/rar2" ] && [ -d "$root/rar2/dos/in" ]; then
    r2="$samples/rar2"
    din="$root/rar2/dos/in"
    check2() {
        local arc="$1"; shift
        local out="$work/rar2_${arc%.rar}"
        mkdir -p "$out"
        if ! "$ramjet" x -o+ -pramjet "$r2/$arc" "$out/" >"$out.log" 2>&1; then
            echo "FAIL rar2/$arc (ramjet exit status)"; grep -v ' OK$' "$out.log" | head -5 | sed 's/^/     /'
            fail=$((fail + 1)); return
        fi
        local f bad=0
        for f in "$@"; do
            cmp -s "$din/$f" "$out/$f" || { echo "FAIL rar2/$arc: $f differs"; bad=1; }
        done
        if [ $bad = 0 ]; then echo "ok   rar2/$arc"; pass=$((pass + 1)); else fail=$((fail + 1)); fi
    }
    every=(HELLO.TXT TEXT.TXT CODE.EXE ZEROS.BIN RANDOM.BIN TONE.WAV EMPTY.TXT DIR/SUB/DEEP.TXT DIR/OTHER.TXT)
    for a in allm0 allm1 allm2 allm3 allm4 allm5 solid solidm5 enc encsolid; do
        check2 "$a.rar" "${every[@]}"
    done
    check2 mm.rar TONE.WAV
    check2 mmf.rar TONE.WAV TEXT.TXT
    check2 mmsolid.rar TONE.WAV TEXT.TXT CODE.EXE
    check2 encstore.rar HELLO.TXT TEXT.TXT
    check2 comment.rar HELLO.TXT TEXT.TXT
    check2 single.rar HELLO.TXT
    check2 vol.rar BIG.BIN
    check2 volsolid.rar TEXT.TXT RANDOM.BIN
    if "$ramjet" t -pwrong "$r2/enc.rar" >/dev/null 2>&1; then
        echo "FAIL rar2: wrong password accepted"; fail=$((fail + 1))
    else
        echo "ok   rar2: wrong password refused"; pass=$((pass + 1))
    fi
fi

# hostile archives: nothing may land outside the destination
hostile="$work/hostile"
python3 -I "$root/make_hostile.py" "$hostile"
for a in dotdot dotdot_deep absolute symlink_escape hardlink_escape setuid backslash trailing_dot drive device; do
    box="$hostile/box_$a"
    mkdir -p "$box/dest"
    (cd "$box" && "$ramjet" x -o+ "$hostile/$a.rar" dest/ >/dev/null 2>&1)
    escaped=$(find "$box" -mindepth 1 -not -path "$box/dest" -not -path "$box/dest/*" | head -1)
    if [ -n "$escaped" ] || [ -e /tmp/ramjet_through_link.txt ] || [ -e /tmp/ramjet_absolute.txt ]; then
        echo "FAIL hostile $a: wrote $escaped"; fail=$((fail + 1))
    elif [ -n "$(find "$box/dest" -perm -4000)" ]; then
        echo "FAIL hostile $a: kept a set-id bit"; fail=$((fail + 1))
    else
        echo "ok   hostile $a"; pass=$((pass + 1))
    fi
done

echo "$pass passed, $fail failed"
[ $fail = 0 ]
