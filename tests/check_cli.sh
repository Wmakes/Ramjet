#!/usr/bin/env bash
# Command-line behavior: switches, file selection, destinations, existing
# files and exit codes. Runs without a terminal, so nothing prompts.
#
# usage: tests/check_cli.sh [ramjet-binary]
set -uo pipefail

root="$(cd "$(dirname "$0")" && pwd)"
ramjet="${1:-$root/../out/linux-x86_64/debug/bin/ramjet}"
ramjet="$(cd "$(dirname "$ramjet")" && pwd)/$(basename "$ramjet")"
s="$root/samples"
in="$s/input"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
pass=0
fail=0

ok()  { echo "ok   $1"; pass=$((pass + 1)); }
bad() { echo "FAIL $1"; fail=$((fail + 1)); }

# expect <name> <exit status> <command...>
expect() {
    local name="$1" want="$2"; shift 2
    "$@" >"$work/out" 2>&1 </dev/null
    local got=$?
    if [ "$got" = "$want" ]; then ok "$name (exit $got)"; else bad "$name: exit $got, wanted $want"; sed 's/^/     /' "$work/out" | head -5; fi
}

expect "help"                 0  "$ramjet" --help
expect "version"              0  "$ramjet" --version
expect "no arguments"         7  "$ramjet"
expect "unknown command"      7  "$ramjet" z "$s/all_m3.rar"
expect "unknown switch"       7  "$ramjet" t -zz "$s/all_m3.rar"
expect "v command alias"       0  "$ramjet" v "$s/all_m3.rar"
expect "lta command alias"     0  "$ramjet" lta "$s/all_m3.rar"
expect "missing archive"      6  "$ramjet" t "$work/none.rar"
expect "not a rar"            2  "$ramjet" t "$in/hello.txt"
expect "damaged data"         3  "$ramjet" t "$s/broken_crc.rar"
expect "truncated"            3  "$ramjet" t "$s/broken_truncated.rar"
expect "no password"          11 "$ramjet" t -p- "$s/all_encrypted.rar"
expect "wrong password"       11 "$ramjet" t -pwrong "$s/all_encrypted.rar"
expect "no match"             10 "$ramjet" t "$s/all_m3.rar" nothing.here
expect "test all"             0  "$ramjet" t "$s/all_m3.rar"

# a single file name after the archive selects, it is not a destination
d="$work/sel"; mkdir -p "$d"
(cd "$d" && "$ramjet" x -inul "$s/all_m3.rar" hello.txt)
if [ -f "$d/hello.txt" ] && [ "$(ls "$d" | wc -l)" = 1 ]; then ok "name selects one file"; else bad "name selects one file"; ls "$d"; fi

# masks, excludes and list files
d="$work/mask"
"$ramjet" x -inul "$s/all_m3.rar" '*.txt' -x'dir/*' -x'z*' "$d/"
got=$(cd "$d" && find . -type f | sort | tr '\n' ' ')
want="./empty.txt ./hardlink_hello.txt ./hello.txt ./text.txt "
[ "$got" = "$want" ] && ok "masks and excludes" || bad "masks and excludes: $got"
printf 'code.exe\ndir/other.txt\n' > "$work/list.txt"
d="$work/list"
"$ramjet" x -inul "$s/all_m3.rar" @"$work/list.txt" "$d/"
got=$(cd "$d" && find . -type f | sort | tr '\n' ' ')
[ "$got" = "./code.exe ./dir/other.txt " ] && ok "@listfile" || bad "@listfile: $got"

d="$work/include"
"$ramjet" x -inul -n'*.txt' -x'dir/*' -x'z*' "$s/all_m3.rar" "$d/"
got=$(cd "$d" && find . -type f | sort | tr '\n' ' ')
[ "$got" = "./empty.txt ./hardlink_hello.txt ./hello.txt ./text.txt " ] && ok "-n include mask" || bad "-n include mask: $got"

d="$work/include_list"
"$ramjet" x -inul -n@"$work/list.txt" "$s/all_m3.rar" "$d/"
got=$(cd "$d" && find . -type f | sort | tr '\n' ' ')
[ "$got" = "./code.exe ./dir/other.txt " ] && ok "-n@ include list" || bad "-n@ include list: $got"

got=$("$ramjet" lb -n'*.txt' -x'dir/*' -x'z*' "$s/all_m3.rar" | sort | tr '\n' ' ')
want="empty.txt hardlink_hello.txt hello.txt text.txt "
[ "$got" = "$want" ] && ok "list commands honor filters" || bad "list commands honor filters: $got"

d="$work/include_stdin"
printf 'hello.txt\n' | "$ramjet" x -inul -n@ "$s/all_m3.rar" "$d/"
[ -f "$d/hello.txt" ] && [ "$(find "$d" -type f | wc -l)" = 1 ] && ok "-n@ stdin list" || bad "-n@ stdin list"

d="$work/exclude_stdin"
printf 'dir/*\nz*\n' | "$ramjet" x -inul -n'*.txt' -x@ "$s/all_m3.rar" "$d/"
got=$(cd "$d" && find . -type f | sort | tr '\n' ' ')
[ "$got" = "./empty.txt ./hardlink_hello.txt ./hello.txt ./text.txt " ] && ok "-x@ stdin list" || bad "-x@ stdin list: $got"

# disabling @list expansion makes the argument an ordinary file name
expect "-@ disables lists"     10 "$ramjet" t -@ "$s/all_m3.rar" @"$work/list.txt"

# a single dash ends switch scanning, so a dash-prefixed archive is accepted
cp "$s/single_store.rar" "$work/-sample.rar"
(cd "$work" && "$ramjet" t - -sample.rar >/dev/null 2>&1)
[ $? = 0 ] && ok "single dash ends switches" || bad "single dash ends switches"

# destinations
d="$work/op"
"$ramjet" x -inul -op"$d" "$s/single_store.rar"
[ -f "$d/hello.txt" ] && ok "-op" || bad "-op"
d="$work/ad"; mkdir -p "$d"
"$ramjet" x -inul -ad "$s/volumes.part1.rar" "$d/"
cmp -s "$in/big_random.bin" "$d/volumes/big_random.bin" && ok "-ad names the folder after the archive" || bad "-ad"
d="$work/flat"
"$ramjet" e -inul "$s/all_m3.rar" "dir/*" "$d/"
got=$(cd "$d" && find . -type f | sort | tr '\n' ' ')
[ "$got" = "./deep.txt ./other.txt " ] && ok "e drops paths" || bad "e drops paths: $got"
d="$work/ep"
"$ramjet" x -ep -inul "$s/all_m3.rar" "dir/*" "$d/"
got=$(cd "$d" && find . -type f | sort | tr '\n' ' ')
[ "$got" = "./deep.txt ./other.txt " ] && ok "-ep drops paths" || bad "-ep drops paths: $got"

# existing files
d="$work/exist"; mkdir -p "$d"
echo old > "$d/hello.txt"
"$ramjet" x -inul -o- "$s/single_store.rar" "$d/"
[ "$(cat "$d/hello.txt")" = old ] && ok "-o- keeps existing" || bad "-o- keeps existing"
"$ramjet" x -inul "$s/single_store.rar" "$d/"
[ "$(cat "$d/hello.txt")" = old ] && ok "no terminal: existing kept" || bad "no terminal: existing kept"
"$ramjet" x -inul -or "$s/single_store.rar" "$d/"
cmp -s "$in/hello.txt" "$d/hello (1).txt" && ok "-or renames" || bad "-or renames"
"$ramjet" x -inul -o+ "$s/single_store.rar" "$d/"
cmp -s "$in/hello.txt" "$d/hello.txt" && ok "-o+ overwrites" || bad "-o+ overwrites"

# skipping an existing file in a solid archive must not break later files
d="$work/solid"; mkdir -p "$d"
echo keep > "$d/text.txt"
"$ramjet" x -o- "$s/all_solid.rar" "$d/" >"$work/out" 2>&1
st=$?
if [ $st = 0 ] && [ "$(cat "$d/text.txt")" = keep ] && cmp -s "$in/zeros.bin" "$d/zeros.bin" && cmp -s "$in/tone.wav" "$d/tone.wav"; then
    ok "solid: skipped file keeps the stream"
else
    bad "solid: skipped file keeps the stream (exit $st)"; grep -v ' OK$' "$work/out" | head -5
fi

# damaged files are removed, or kept with -kb
d="$work/broken"
"$ramjet" x -inul "$s/broken_crc.rar" "$d/"
n1=$(find "$d" -type f 2>/dev/null | wc -l)
d="$work/broken_kb"
"$ramjet" x -inul -kb "$s/broken_crc.rar" "$d/"
n2=$(find "$d" -type f 2>/dev/null | wc -l)
[ "$n2" -gt "$n1" ] && ok "-kb keeps broken files" || bad "-kb keeps broken files ($n1 vs $n2)"

# quiet modes and bare listing
out=$("$ramjet" t -inul "$s/all_m3.rar" 2>&1)
[ -z "$out" ] && ok "-inul prints nothing" || bad "-inul prints nothing"
out=$("$ramjet" t -idq "$s/all_m3.rar" 2>&1)
[ "$(echo "$out" | grep -c Testing)" = 0 ] && ok "-idq hides file lines" || bad "-idq hides file lines"
[ "$("$ramjet" lb "$s/all_m3.rar" | wc -l)" = 17 ] && ok "lb lists bare names" || bad "lb lists bare names"
out=$("$ramjet" l -c- "$s/all_comment.rar")
! echo "$out" | grep -q '^Comment:$' && ok "-c- hides archive comment" || bad "-c- hides archive comment"
"$ramjet" p "$s/single_store.rar" > "$work/p.out" 2>/dev/null
cmp -s "$in/hello.txt" "$work/p.out" && ok "p prints only file data" || bad "p prints only file data"

echo "$pass passed, $fail failed"
[ $fail = 0 ]
