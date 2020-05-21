#!/bin/sh
set -eu
awk_bin=/usr/bin/awk
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
script="$here/queue-tue.awk"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/queue-tue.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
printf '0\t5\tA\n1\t2\tA\n2\t3\tB\n4\t1\tA\n' >"$tmp/in.tsv"
"$awk_bin" -f "$script" "$tmp/in.tsv" >"$tmp/out.tsv"
test "$(sed -n '2p' "$tmp/out.tsv")" = '0	5	A	0	0	5'
test "$(sed -n '3p' "$tmp/out.tsv")" = '1	2	A	4	5	7'
test "$(sed -n '4p' "$tmp/out.tsv")" = '2	3	B	0	2	5'
test "$(sed -n '5p' "$tmp/out.tsv")" = '4	1	A	3	7	8'
if printf '0\t1\tA\n-1\t2\tA\n' | "$awk_bin" -f "$script" >/dev/null 2>&1; then exit 1; fi
if printf '3\t1\tA\n2\t2\tA\n' | "$awk_bin" -f "$script" >/dev/null 2>&1; then exit 1; fi
if printf 'x\t1\tA\n' | "$awk_bin" -f "$script" >/dev/null 2>&1; then exit 1; fi
if printf '0\t1\n' | "$awk_bin" -f "$script" >/dev/null 2>&1; then exit 1; fi
if printf '0\t1\t   \n' | "$awk_bin" -f "$script" >/dev/null 2>&1; then exit 1; fi
if printf '1000001\t1\tA\n' | "$awk_bin" -f "$script" >/dev/null 2>&1; then exit 1; fi
same=$(printf '0\t2\tA\n0\t3\tA\n' | "$awk_bin" -f "$script")
test "$(printf '%s\n' "$same" | sed -n '2p')" = '0	2	A	0	0	2'
test "$(printf '%s\n' "$same" | sed -n '3p')" = '0	3	A	2	2	5'
echo 'queue-tue CLI tests: deterministic scheduling and 4 invalid-input checks passed'
